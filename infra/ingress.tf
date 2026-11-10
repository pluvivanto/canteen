resource "aws_acm_certificate" "wildcard" {
  domain_name       = "*.${var.domain}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "wildcard_validation" {
  for_each = {
    for o in aws_acm_certificate.wildcard.domain_validation_options : o.domain_name => o
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "wildcard" {
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for r in aws_route53_record.wildcard_validation : r.fqdn]
}

resource "aws_security_group" "alb" {
  name   = "hackathon-alb"
  vpc_id = module.vpc.vpc_id

  tags = {
    Name = "hackathon-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  ip_protocol       = "-1"
}

variable "venue_cidrs" {
  type = list(string)
}

resource "aws_security_group" "alb_public" {
  name   = "hackathon-alb-public"
  vpc_id = module.vpc.vpc_id

  tags = {
    Name = "hackathon-alb-public"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_public_http" {
  for_each = toset(concat(var.admin_cidrs, var.venue_cidrs))

  security_group_id = aws_security_group.alb_public.id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_public_https" {
  for_each = toset(concat(var.admin_cidrs, var.venue_cidrs))

  security_group_id = aws_security_group.alb_public.id
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_public" {
  security_group_id = aws_security_group.alb_public.id
  cidr_ipv4         = module.vpc.vpc_cidr_block
  ip_protocol       = "-1"
}

module "lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name                            = "aws-load-balancer-controller"
  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }
}

module "external_dns_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name                          = "external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [data.aws_route53_zone.main.arn]

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-dns"
      service_account = "external-dns"
    }
  }
}
