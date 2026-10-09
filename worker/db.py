"""Database access for the worker: job status transitions."""
import json
import os

import boto3
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
from psycopg_pool import ConnectionPool

_pool = None


def _credentials():
    """Username/password from the RDS-managed secret, read with the instance's IAM role."""
    secret = boto3.client("secretsmanager").get_secret_value(SecretId=os.environ["DB_SECRET_ARN"])
    return json.loads(secret["SecretString"])


def pool():
    global _pool
    if _pool is None:
        creds = _credentials()
        _pool = ConnectionPool(
            kwargs={
                "host": os.environ["DB_HOST"],
                "port": os.environ.get("DB_PORT", "5432"),
                "dbname": os.environ["DB_NAME"],
                "user": creds["username"],
                "password": creds["password"],
                "sslmode": os.environ.get("DB_SSLMODE", "require"),
                "row_factory": dict_row,
            },
            min_size=1,
            max_size=2,
            open=True,
        )
    return _pool


def claim_job(job_id) -> dict | None:
    """Move a job to PROCESSING and return its payload; None if it is unknown or already COMPLETED.

    The WHERE clause makes redelivery safe: SQS delivers at least once, so a duplicate
    message for a completed job must not run it again.
    """
    with pool().connection() as conn:
        row = conn.execute(
            "UPDATE jobs SET status = 'PROCESSING', updated_at = now() "
            "WHERE id = %s AND status <> 'COMPLETED' RETURNING payload",
            [job_id],
        ).fetchone()
    return None if row is None else row["payload"]


def complete_job(job_id, result: dict) -> None:
    with pool().connection() as conn:
        conn.execute(
            "UPDATE jobs SET status = 'COMPLETED', result = %s, error = NULL, updated_at = now() WHERE id = %s",
            [Jsonb(result), job_id],
        )


def fail_job(job_id, error: str, final: bool) -> None:
    """Record a failed attempt: back to PENDING (SQS redelivers it) or FAILED on the last attempt."""
    with pool().connection() as conn:
        conn.execute(
            "UPDATE jobs SET status = %s, error = %s, updated_at = now() WHERE id = %s",
            ["FAILED" if final else "PENDING", error, job_id],
        )
