"""Job worker: long-polls SQS, processes each job and records its status and result in PostgreSQL."""
import json
import logging
import os
import random
import signal
import socket
import time

import boto3

import db

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("worker")

QUEUE_URL = os.environ["QUEUE_URL"]
MAX_RECEIVE_COUNT = int(os.environ.get("MAX_RECEIVE_COUNT", "3"))
sqs = boto3.client("sqs")
running = True


def stop(signum, frame):
    # systemd sends SIGTERM on stop / instance replacement: finish the current job, then exit.
    global running
    running = False
    log.info("shutdown requested, finishing current job")


def process(payload: dict) -> dict:
    """The actual work, simulated: sleep, then return a fake report summary."""
    if payload.get("simulate_failure"):
        raise RuntimeError("simulated failure (payload.simulate_failure = true)")
    duration = min(int(payload.get("duration_seconds", 5)), 30)  # stays well under the 60 s visibility timeout
    time.sleep(duration)
    return {
        "report": payload.get("report", "default-report"),
        "rows": random.randint(100, 10_000),
        "duration_seconds": duration,
        "processed_by": socket.gethostname(),
    }


def handle(message: dict) -> None:
    receipt = message["ReceiptHandle"]
    attempt = int(message["Attributes"]["ApproximateReceiveCount"])
    job_id = json.loads(message["Body"])["job_id"]

    payload = db.claim_job(job_id)
    if payload is None:
        log.info("job %s unknown or already completed, dropping duplicate message", job_id)
        sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=receipt)
        return

    log.info("job %s PROCESSING (attempt %d/%d)", job_id, attempt, MAX_RECEIVE_COUNT)
    try:
        result = process(payload)
    except Exception as exc:
        final = attempt >= MAX_RECEIVE_COUNT
        db.fail_job(job_id, f"attempt {attempt}: {exc}", final)
        log.warning("job %s failed (attempt %d/%d): %s", job_id, attempt, MAX_RECEIVE_COUNT, exc)
        # Message NOT deleted: SQS redelivers it, and after MAX_RECEIVE_COUNT receives moves it to the DLQ.
        # A short visibility timeout retries soon (linear backoff) instead of waiting the full 60 s.
        sqs.change_message_visibility(QueueUrl=QUEUE_URL, ReceiptHandle=receipt, VisibilityTimeout=5 * attempt)
        return

    # Delete only AFTER the result is committed: a crash in between means a redelivery,
    # which claim_job() then drops because the job is already COMPLETED.
    db.complete_job(job_id, result)
    sqs.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=receipt)
    log.info("job %s COMPLETED", job_id)


def main() -> None:
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    log.info("worker started, polling %s", QUEUE_URL)
    while running:
        response = sqs.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=1,  # one at a time: a message never waits in memory past its visibility timeout
            WaitTimeSeconds=20,  # long polling
            MessageSystemAttributeNames=["ApproximateReceiveCount"],
        )
        for message in response.get("Messages", []):
            try:
                handle(message)
            except Exception:
                # e.g. malformed body or DB unreachable: leave the message, SQS retries and finally DLQs it
                log.exception("unexpected error on message %s", message["MessageId"])
    log.info("worker stopped")


if __name__ == "__main__":
    main()
