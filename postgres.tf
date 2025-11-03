resource "aws_db_subnet_group" "postgres" {
  count       = var.enable_postgres ? 1 : 0
  name_prefix = "postgres-subnet-group"
  subnet_ids  = module.vpc.private_subnets
}

resource "aws_security_group" "postgres" {
  count  = var.enable_postgres ? 1 : 0
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "postgres_allow_all_out" {
  count             = var.enable_postgres ? 1 : 0
  security_group_id = aws_security_group.postgres[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "postgres_allow_psql_in" {
  count             = var.enable_postgres ? 1 : 0
  security_group_id = aws_security_group.postgres[0].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}

resource "aws_db_instance" "postgres" {
  count                  = var.enable_postgres ? 1 : 0
  engine                 = "postgres"
  instance_class         = "db.t3.medium"
  username               = "netbox"
  password               = var.postgres_password
  db_name                = "netbox"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.postgres[0].name
  vpc_security_group_ids = [aws_security_group.postgres[0].id]
  skip_final_snapshot    = true
}

output "postgres_host" {
  value = var.enable_postgres ? aws_db_instance.postgres[0].address : null
}

output "postgres_password" {
  value     = var.enable_postgres ? var.postgres_password : null
  sensitive = true
}