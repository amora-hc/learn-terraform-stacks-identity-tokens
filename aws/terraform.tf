terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0.0"
    }
  }
  cloud {
    organization = "amora-hc"
    workspaces {
      name = "learn-terraform-stacks-identity-tokens-aws"
    }
  }
  required_version = ">= 1.2"
}
