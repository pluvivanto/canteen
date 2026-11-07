variable "bedrock_models" {
  type    = list(string)
  default = ["jp.anthropic.claude-haiku-5-5"]
}

module "litellm_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name                 = "litellm"
  attach_custom_policy = true
  policy_statements = [{
    actions = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = flatten([for id in var.bedrock_models : [
      "arn:aws:bedrock:ap-northeast-1:${data.aws_caller_identity.current.account_id}:inference-profile/${id}",
      "arn:aws:bedrock:*::foundation-model/${regex("^[a-z]+\\.(.+)$", id)[0]}",
    ]])
  }]

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "litellm"
      service_account = "litellm"
    }
  }
}
