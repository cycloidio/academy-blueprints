terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }

  # State in the S3 bucket created in C2, given at init (decision D2):
  #   terraform init -backend-config=bucket=<bucket> -backend-config=key=<key> \
  #     -backend-config=region=<region> -backend-config=use_lockfile=true
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      "cycloid-academy"         = "true"
      "cycloid-academy:cluster" = var.name
    }
  }
}
