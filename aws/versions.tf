terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State stored in an S3 bucket native to AWS, with DynamoDB state locking.
  # Both resources must be created before first init (see setup commands below).
  # Key is passed at init time via -backend-config to support multiple environments:
  #   terraform init -reconfigure -backend-config="key=aws/dev.terraform.tfstate"
  #   terraform init -reconfigure -backend-config="key=aws/uat.terraform.tfstate"
  #   terraform init -reconfigure -backend-config="key=aws/prod.terraform.tfstate"
  #
  # Setup (one-time):
  #   aws s3api create-bucket --bucket jproject-tfstate --region us-east-1
  #   aws s3api put-bucket-versioning --bucket jproject-tfstate \
  #     --versioning-configuration Status=Enabled
  #   aws s3api put-bucket-encryption --bucket jproject-tfstate \
  #     --server-side-encryption-configuration \
  #     '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  #   aws s3api put-public-access-block --bucket jproject-tfstate \
  #     --public-access-block-configuration \
  #     "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
  #   aws dynamodb create-table --table-name jproject-tfstate-lock \
  #     --attribute-definitions AttributeName=LockID,AttributeType=S \
  #     --key-schema AttributeName=LockID,KeyType=HASH \
  #     --billing-mode PAY_PER_REQUEST --region us-east-1
  backend "s3" {
    bucket         = "jproject-tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "jproject-tfstate-lock"
  }
}
