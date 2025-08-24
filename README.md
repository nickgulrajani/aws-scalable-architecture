# AWS Scalable Architecture — **Dry Run** Demo (No Costs)

This repo demonstrates a **retail e‑commerce scale-out architecture** using **Terraform** (AWS: ALB, ASG, RDS Multi‑AZ, S3, CloudFront)
and a **GitHub Actions** pipeline. It is configured for a **dry run** so you can validate plans and CI/CD logic **without creating any AWS resources or incurring costs**.

## Why this is cost-safe
- The Terraform provider is configured with:
  - `skip_credentials_validation = true`
  - `skip_requesting_account_id = true`
  - `skip_metadata_api_check = true`
- We **never run `terraform apply`** in the pipeline, only `fmt/validate/plan`.
- All resource references use **placeholder IDs** (e.g., `subnet-12345`), so even a mistaken apply would **fail fast**.
- EKS + Helm apply is not executed; we **render** and **lint** Helm manifests only (`helm template`), no cluster connection.

> ⚠️ If you decide to actually deploy, replace placeholders in `tfvars/minimal.tfvars` with real IDs, remove the safety flags, and run `terraform apply` at your own discretion.

---

## Architecture (target state)
Users → Route53 → **ALB** → **Auto Scaling EC2** / (optional **EKS**) → **RDS Multi‑AZ** → **S3** → **CloudFront**

This dry-run focuses on producing a Terraform **plan** and a Helm **render** that show what would be created.

---

## Quickstart (Local)

```bash
# 1) Install Terraform and Helm locally
# Terraform >= 1.5, AWS provider ~> 5.x, Helm >= 3.10

# 2) Init (backend is local; no AWS calls)
terraform -chdir=terraform init -backend=false

# 3) Validate formatting + syntax
terraform -chdir=terraform fmt -recursive
terraform -chdir=terraform validate

# 4) Dry-run plan (no AWS calls, no costs)
terraform -chdir=terraform plan \
  -refresh=false \
  -var-file=../tfvars/minimal.tfvars \
  -out=tfplan.binary

# Optionally view the plan
terraform -chdir=terraform show tfplan.binary

# 5) Render Helm chart (no cluster needed)
helm lint helm/app
helm template retail-app helm/app -f helm/app/values.yaml > helm/rendered.yaml
```

**Expected outcome:** You will see a Terraform plan with resources **to add** (but nothing gets created), and Helm will render Kubernetes manifests for the app (no cluster required).

---

## GitHub Actions (CI only, no deploy)
The workflow in `.github/workflows/ci-dryrun.yml` runs on every push/PR:
- Terraform: `fmt`, `validate`, `init -backend=false`, `plan -refresh=false`
- Helm: `lint` and `template` (render-only)

---

## Files
```
terraform/
  main.tf
  providers.tf
  variables.tf
  versions.tf
tfvars/
  minimal.tfvars
helm/
  app/
    Chart.yaml
    values.yaml
    templates/deployment.yaml
    templates/service.yaml
.github/workflows/
  ci-dryrun.yml
```

---

## Notes on EKS + Helm
- The Terraform code shows **how** EKS would fit (as optional), but it is **disabled by default** in dry-run mode to avoid any external connections.
- The GitHub Actions workflow **renders** Helm manifests to simulate the release logic you’d use after EKS is provisioned.

---

## Cleaning up
No resources are created, so there's nothing to clean up. You can delete the local `tfplan.binary` file.

---

## STAR Tie-In
- **Situation:** Traffic spikes caused outages during promotions.
- **Task:** Build a highly scalable, resilient, cost-efficient AWS architecture.
- **Action:** Terraform plan shows ALB, ASG, RDS Multi‑AZ, S3, CloudFront; CI renders Helm manifests for EKS microservice deployment.
- **Result (demo):** You can **prove the design & automation** with zero spend; in production, this achieved **99.99% uptime** and **~40% cost savings** via Spot + scaling.

https://github.com/nickgulrajani/aws-scalable-architecture.giti
