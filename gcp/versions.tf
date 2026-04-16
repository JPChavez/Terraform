terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # State stored in a GCS bucket native to GCP.
  # Bucket must be created before first init (see setup commands below).
  # Prefix is passed at init time via -backend-config to support multiple environments:
  #   terraform init -reconfigure -backend-config="prefix=gcp/dev"
  #   terraform init -reconfigure -backend-config="prefix=gcp/uat"
  #   terraform init -reconfigure -backend-config="prefix=gcp/prod"
  #
  # Setup (one-time):
  #   gcloud storage buckets create gs://jproject-tfstate --location=us-central1 \
  #     --uniform-bucket-level-access --public-access-prevention
  #   gcloud storage buckets update gs://jproject-tfstate --versioning
  backend "gcs" {
    bucket = "jproject-tfstate"
  }
}
