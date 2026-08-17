terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }

    backend "s3" {
        bucket = "my-terraform-state-amar-thool-external"
        key = "dev/vpc/terraform.tfstate"
        region = "us-east-1"
        dynamodb_table = "my-terraform-lock"
        encrypt = true

    }
}

provider "aws" {
    region = "us-east-1"
}