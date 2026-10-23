import socket
import time

from fastapi import FastAPI
from pydantic import BaseModel, Field
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI(
    title="NETOPS Network Diagnostics API",
    description="Container networking and troubleshooting lab",
    version="1.0.0",
)

Instrumentator().instrument(app).expose(app)


class DiagnosticRequest(BaseModel):
    host: str = Field(min_length=1, max_length=253)
    port: int = Field(ge=1, le=65535)


@app.get("/")
def home():
    return {
        "project": "NETOPS",
        "status": "running",
        "version": "1.0.0",
    }


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.get("/dns/{hostname}")
def dns_lookup(hostname: str):
    start = time.monotonic()

    try:
        addresses = sorted({
            result[4][0]
            for result in socket.getaddrinfo(
                hostname, None, type=socket.SOCK_STREAM
            )
        })

        return {
            "hostname": hostname,
            "addresses": addresses,
            "status": "resolved",
            "duration_ms": round(
                (time.monotonic() - start) * 1000, 2
            ),
        }
    except socket.gaierror as exc:
        return {
            "hostname": hostname,
            "status": "dns_failed",
            "error": str(exc),
        }


@app.post("/tcp-check")
def tcp_check(request: DiagnosticRequest):
    start = time.monotonic()

    try:
        with socket.create_connection(
            (request.host, request.port), timeout=3
        ):
            return {
                "host": request.host,
                "port": request.port,
                "status": "connected",
                "duration_ms": round(
                    (time.monotonic() - start) * 1000, 2
                ),
            }
    except OSError as exc:
        return {
            "host": request.host,
            "port": request.port,
            "status": "failed",
            "error": str(exc),
        }
