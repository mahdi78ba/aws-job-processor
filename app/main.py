"""Job Processor API: stores jobs in PostgreSQL and queues them on SQS for the worker."""
import json
import logging
import os
from contextlib import asynccontextmanager
from uuid import UUID

import boto3
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

import db

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("api")

QUEUE_URL = os.environ["QUEUE_URL"]
sqs = boto3.client("sqs")


@asynccontextmanager
async def lifespan(app: FastAPI):
    db.init_schema()
    yield


app = FastAPI(title="Job Processor API", lifespan=lifespan)


class JobRequest(BaseModel):
    payload: dict = Field(
        default_factory=dict,
        examples=[{"report": "monthly-sales", "duration_seconds": 5}],
    )


@app.get("/health")
def health():
    # Shallow on purpose: if this checked the database, a DB outage would make the ALB
    # mark every instance unhealthy and the ASG would start replacing healthy instances.
    return {"status": "ok"}


@app.post("/jobs", status_code=202)
def create_job(request: JobRequest):
    job = db.create_job(request.payload)
    try:
        sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps({"job_id": str(job["id"])}))
    except Exception:
        log.exception("could not enqueue job %s", job["id"])
        db.mark_failed(job["id"], "could not enqueue job")
        raise HTTPException(status_code=503, detail="Job could not be queued, retry later")
    log.info("job %s queued", job["id"])
    return {"id": job["id"], "status": job["status"]}


@app.get("/jobs/{job_id}")
def get_job(job_id: UUID):
    job = db.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")
    return job
