# GCP Deploy and ML Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare ApexRun's backend, ML service, and website for a first GCP deployment.

**Architecture:** Deploy the Go API and FastAPI ML service as separate Cloud Run services built by Cloud Build and stored in Artifact Registry. Deploy the static website through Firebase Hosting with extensionless route rewrites.

**Tech Stack:** Flutter, Go/Gin, Python FastAPI, Docker, Cloud Run, Cloud Build, Artifact Registry, Secret Manager, Firebase Hosting.

---

### Task 1: ML Service Runtime Contract

**Files:**
- Modify: `ml-service/main.py`
- Modify: `ml-service/Dockerfile`
- Create: `ml-service/tests/test_runtime_contract.py`
- Create: `ml-service/requirements-dev.txt`

- [x] **Step 1: Write failing tests**

Tests assert `/health`, `/ready`, `PORT` parsing, invalid `PORT` fallback, and `CORS_ALLOW_ORIGINS` parsing.

- [x] **Step 2: Verify tests fail before implementation**

Run: `..\.venv\Scripts\python.exe -m pytest tests\test_runtime_contract.py -q` from `ml-service`.

Expected before implementation: missing `APP_VERSION`, `/ready`, `runtime_port`, and `cors_allow_origins`.

- [x] **Step 3: Implement runtime contract**

Add `APP_VERSION`, `MODELS_DIR`, `cors_allow_origins()`, `runtime_port()`, `/ready`, and health model count. Update Docker command to use `${PORT:-8001}`.

- [x] **Step 4: Verify targeted tests pass**

Run: `..\ .venv\Scripts\python.exe -m pytest tests\test_runtime_contract.py -q`.

Expected: `5 passed`.

### Task 2: GCP Deployment Artifacts

**Files:**
- Create: `gcp/cloudbuild.yaml`
- Create: `gcp/README.md`
- Modify: `firebase.json`

- [x] **Step 1: Add Cloud Build pipeline**

Build and push `backend` and `ml-service` containers, deploy both to Cloud Run, and inject secrets from Secret Manager.

- [x] **Step 2: Add Firebase Hosting config**

Serve `website/`, enable clean URLs, route `/privacy`, `/terms`, `/support`, and `/account/delete`, and expose `/.well-known/*` with JSON headers.

- [x] **Step 3: Add deployment runbook**

Document required APIs, Artifact Registry repo, runtime service account, Secret Manager secret names, deploy command, and post-deploy smoke checks.

### Task 3: Verification

**Files:**
- All files above

- [x] **Step 1: Run ML service unit tests**

Run: `..\ .venv\Scripts\python.exe -m pytest tests\test_runtime_contract.py -q` from `ml-service`.

- [x] **Step 2: Run static config checks**

Run: `python -m json.tool firebase.json` and inspect `gcp/cloudbuild.yaml`.

- [ ] **Step 3: Run broader known checks**

Run `flutter analyze` and `flutter test`; report existing failures separately from new deploy changes.
