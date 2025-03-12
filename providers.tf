terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }

  backend "s3" {
    region = "ca-central-1"
  }
}

provider "aws" {
  region = "ca-central-1"
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}