import os
from importlib import reload

from fastapi.testclient import TestClient

import main


def test_health_reports_runtime_metadata():
    client = TestClient(main.app)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "ml-service",
        "version": main.APP_VERSION,
        "models_available": 0,
    }


def test_readiness_reports_model_directory_state():
    client = TestClient(main.app)

    response = client.get("/ready")

    assert response.status_code == 200
    assert response.json()["status"] == "ready"
    assert response.json()["models_dir_exists"] is True


def test_runtime_port_uses_cloud_run_port_env(monkeypatch):
    monkeypatch.setenv("PORT", "9090")

    assert main.runtime_port() == 9090


def test_runtime_port_falls_back_when_env_is_invalid(monkeypatch):
    monkeypatch.setenv("PORT", "not-a-port")

    assert main.runtime_port() == 8001


def test_cors_origins_are_parsed_from_env(monkeypatch):
    monkeypatch.setenv(
        "CORS_ALLOW_ORIGINS",
        "https://apexrun.app, https://www.apexrun.app",
    )

    reloaded = reload(main)

    assert reloaded.cors_allow_origins() == [
        "https://apexrun.app",
        "https://www.apexrun.app",
    ]
