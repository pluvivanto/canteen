provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = {
      Project = "hackops"
    }
  }
}

resource "aws_ecrpublic_repository" "team_manager" {
  provider        = aws.us_east_1
  repository_name = "team-manager"
  force_destroy   = true
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_ci" {
  name = "hackathon-github-ci"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:pluvivanto@140719273/hackops-ai-platform@1441790884:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_ci_push" {
  role = aws_iam_role.github_ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr-public:GetAuthorizationToken", "sts:GetServiceBearerToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr-public:BatchCheckLayerAvailability",
          "ecr-public:InitiateLayerUpload",
          "ecr-public:UploadLayerPart",
          "ecr-public:CompleteLayerUpload",
          "ecr-public:PutImage",
        ]
        Resource = aws_ecrpublic_repository.team_manager.arn
      },
    ]
  })
}

output "team_manager_image" {
  value = aws_ecrpublic_repository.team_manager.repository_uri
}

output "github_ci_role_arn" {
  value = aws_iam_role.github_ci.arn
}
