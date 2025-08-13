# RDS PostgreSQL 16 Free Tier eligible, publicly accessible
resource "aws_db_subnet_group" "postgres" {
	name       = "postgres-subnet-group"
	subnet_ids = module.vpc.private_subnets
	tags = {
		Name = "postgres-subnet-group"
	}
}

resource "aws_security_group" "postgres" {
	name        = "postgres-sg"
	description = "Allow PostgreSQL access from my IP and private network"
	vpc_id      = module.vpc.vpc_id

	ingress {
		description      = "Postgres from my IP"
		from_port        = 5432
		to_port          = 5432
		protocol         = "tcp"
		cidr_blocks      = var.allowed_ips
	}
	ingress {
		description      = "Postgres from private network"
		from_port        = 5432
		to_port          = 5432
		protocol         = "tcp"
		cidr_blocks      = [module.vpc.vpc_cidr_block]
	}
	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
	tags = {
		Name = "postgres-sg"
	}
}

resource "aws_db_instance" "postgres" {
	identifier              = "anythingllm-postgres"
	allocated_storage       = 20
	engine                  = "postgres"
	engine_version          = "16"
	instance_class          = "db.t3.micro"
	db_name  = var.database_name
    username = var.master_username
    password = var.master_password
	db_subnet_group_name    = aws_db_subnet_group.postgres.name
	vpc_security_group_ids  = [aws_security_group.postgres.id]
	publicly_accessible     = true
	skip_final_snapshot     = true
	deletion_protection     = false
	multi_az                = false
	auto_minor_version_upgrade = true
	backup_retention_period = 7
	tags = {
		Name = "anythingllm-postgres"
	}
}
