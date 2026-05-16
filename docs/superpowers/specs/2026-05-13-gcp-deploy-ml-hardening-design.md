# GCP Deploy and ML Hardening Design

## Goal

Make ApexRun deployable on Google Cloud Platform with the smallest credible production path: backend and ML service on Cloud Run, static legal/product website on Firebase Hosting, and a hardened ML-service runtime contract.

## Scope

This pass covers deploy-readiness infrastructure and a focused ML service hardening slice. It does not retrain a medically validated injury model, build Apple Watch support, or finish all app localization work.

## Architecture

The Go API remains the main authenticated backend service and deploys to Cloud Run from `backend/Dockerfile`. The FastAPI ML service deploys separately to Cloud Run from `ml-service/Dockerfile`; it exposes `/health` and `/ready`, reads Cloud Run's `PORT`, and uses environment-configured CORS. The static `website/` directory deploys with Firebase Hosting for `apexrun.app`, including extensionless legal/support routes and well-known app association files.

Cloud Build builds both containers, pushes them to Artifact Registry, then deploys Cloud Run revisions using Secret Manager references. Runtime services receive public non-secret configuration as env vars and sensitive values through `--set-secrets`.

## ML Positioning

The current model pipeline uses synthetic data and rule-based fallbacks, so the product should describe ML output as gait/form signals, readiness guidance, and coaching recommendations, not medical injury diagnosis. The next ML-strength pass should add model version metadata, confidence calibration, real user consent for model data collection, and an evaluation set before stronger claims.

## Testing

The ML service gets runtime-contract tests for `/health`, `/ready`, Cloud Run port parsing, and CORS parsing. Deployment config is verified through static inspection and local service tests; real deployment verification requires a GCP project, Artifact Registry repository, Secret Manager secrets, and Firebase project access.
