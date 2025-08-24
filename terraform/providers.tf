provider "aws" {
  region                      = var.aws_region
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      Owner       = "dry-run-demo"
      CostCenter  = "simulation-only"
    }
  }
}

# NOTE: kubernetes/helm providers are declared but not configured in dry-run.
# They would be configured only when enable_eks = true and after cluster creation.
