"""Database access for the API: connection pool, schema and job queries."""
import json
import os

import boto3
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb
from psycopg_pool import ConnectionPool

SCHEMA = """
CREATE TABLE IF NOT EXISTS jobs (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    status     TEXT NOT NULL DEFAULT 'PENDING'
               CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED')),
    payload    JSONB NOT NULL DEFAULT '{}',
    result     JSONB,
    error      TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
)
"""

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
                "sslmode": os.environ.get("DB_SSLMODE", "require"),  # RDS PostgreSQL 15+ enforces TLS
                "row_factory": dict_row,
            },
            min_size=1,
            max_size=5,
            open=True,
        )
    return _pool


def init_schema():
    """Create the table if needed. The advisory lock stops two API instances booting at once from racing."""
    with pool().connection() as conn:
        conn.execute("SELECT pg_advisory_xact_lock(4242)")
        conn.execute(SCHEMA)


def create_job(payload: dict) -> dict:
    with pool().connection() as conn:
        return conn.execute(
            "INSERT INTO jobs (payload) VALUES (%s) RETURNING id, status",
            [Jsonb(payload)],
        ).fetchone()


def get_job(job_id) -> dict | None:
    with pool().connection() as conn:
        return conn.execute(
            "SELECT id, status, payload, result, error, created_at, updated_at FROM jobs WHERE id = %s",
            [job_id],
        ).fetchone()


def mark_failed(job_id, error: str) -> None:
    with pool().connection() as conn:
        conn.execute(
            "UPDATE jobs SET status = 'FAILED', error = %s, updated_at = now() WHERE id = %s",
            [error, job_id],
        )
