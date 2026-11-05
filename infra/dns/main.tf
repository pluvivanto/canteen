terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.72"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      Project = "hackops"
    }
  }
}

resource "aws_route53_zone" "main" {
  name = "hackathon.pluvivanto.win"

  lifecycle {
    prevent_destroy = true
  }
}

output "name_servers" {
  value = aws_route53_zone.main.name_servers
}
