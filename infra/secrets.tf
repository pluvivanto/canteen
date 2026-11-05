resource "random_password" "litellm_masterkey" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "litellm_masterkey" {
  name                    = "hackathon/litellm-masterkey"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "litellm_masterkey" {
  secret_id = aws_secretsmanager_secret.litellm_masterkey.id
  secret_string = jsonencode({
    masterkey = "sk-${random_password.litellm_masterkey.result}"
  })
}

resource "random_password" "grafana_admin" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "grafana_admin" {
  name                    = "hackathon/grafana-admin"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "grafana_admin" {
  secret_id = aws_secretsmanager_secret.grafana_admin.id
  secret_string = jsonencode({
    admin-user     = "admin"
    admin-password = random_password.grafana_admin.result
  })
}

module "external_secrets_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name                                  = "external-secrets"
  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = ["arn:aws:secretsmanager:*:*:secret:hackathon/*"]
  external_secrets_create_permission    = false

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
  }
}
