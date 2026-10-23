from unittest.mock import patch
import socket

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_home():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["project"] == "NETOPS"


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_dns():
    fake_results = [
        (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("192.0.2.10", 0))
    ]

    with patch("app.main.socket.getaddrinfo", return_value=fake_results):
        response = client.get("/dns/example.com")

    assert response.status_code == 200
    assert response.json()["status"] == "resolved"
    assert "192.0.2.10" in response.json()["addresses"]


def test_tcp_failure():
    with patch(
        "app.main.socket.create_connection",
        side_effect=ConnectionRefusedError("Connection refused"),
    ):
        response = client.post(
            "/tcp-check",
            json={"host": "example.com", "port": 443},
        )

    assert response.status_code == 200
    assert response.json()["status"] == "failed"


def test_invalid_port():
    response = client.post(
        "/tcp-check",
        json={"host": "example.com", "port": 99999},
    )
    assert response.status_code == 422