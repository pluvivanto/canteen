resource "aws_security_group" "rds" {
  name   = "hackathon-rds"
  vpc_id = module.vpc.vpc_id

  tags = {
    Name = "hackathon-rds"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_nodes" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_db_subnet_group" "main" {
  name       = "hackathon"
  subnet_ids = module.vpc.private_subnets
}

resource "random_password" "litellm_db" {
  length  = 32
  special = false
}

resource "aws_db_instance" "litellm" {
  identifier     = "hackathon-litellm"
  engine         = "postgres"
  engine_version = "18.3"
  instance_class = "db.t4g.medium"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "litellm"
  username = "litellm"
  password = random_password.litellm_db.result

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot = true
}

resource "aws_secretsmanager_secret" "litellm_db" {
  name                    = "hackathon/litellm-db"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "litellm_db" {
  secret_id = aws_secretsmanager_secret.litellm_db.id
  secret_string = jsonencode({
    username = aws_db_instance.litellm.username
    password = random_password.litellm_db.result
  })
}

resource "aws_route53_zone" "internal" {
  name = "hackathon.internal"

  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

resource "aws_route53_record" "litellm_db" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "litellm-db.hackathon.internal"
  type    = "CNAME"
  ttl     = 60
  records = [aws_db_instance.litellm.address]
}
