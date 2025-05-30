resource "aws_db_subnet_group" "postgres" {
  name       = "postgres-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "postgres" {
  vpc_id = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "postgres_allow_all_out" {
  security_group_id = aws_security_group.postgres.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "postgres_allow_psql_in" {
  security_group_id = aws_security_group.postgres.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}

resource "aws_db_instance" "postgres" {
  identifier             = "nb-pg-db"
  engine                 = "postgres"
  instance_class         = "db.t3.medium"
  username               = "netbox"
  password               = var.postgres_password
  db_name                = "netbox"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  skip_final_snapshot    = true
}

output "postgres_host" {
  value = aws_db_instance.postgres.address
}

output "postgres_password" {
  value     = var.postgres_password
  sensitive = true
}