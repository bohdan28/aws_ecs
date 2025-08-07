provider "aws" {
  region = "eu-central-1"
}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  name               = "llm-vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["eu-central-1a", "eu-central-1b"]
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.11.0/24", "10.0.12.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true
}

# Application Load Balancer for public access to AnythingLLM
resource "aws_lb" "anythingllm" {
  name               = "anythingllm-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "anythingllm" {
  name        = "anythingllm-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.anythingllm.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.anythingllm.arn
  }
}

resource "aws_security_group" "ecs" {
  name        = "ecs-sg"
  description = "Allow inbound traffic for ECS services"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 11434
    to_port     = 11434
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Ollama API
  }
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # AnythingLLM Web
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecr_repository" "ollama" {
  name                 = "ollama"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecr_repository" "anythingllm" {
  name                 = "anythingllm"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_ecs_cluster" "llm" {
  name = "llm-cluster"
}

resource "aws_service_discovery_private_dns_namespace" "llm" {
  name        = "llm.local"
  description = "Service discovery for LLM"
  vpc         = module.vpc.vpc_id
}

resource "aws_service_discovery_service" "ollama" {
  name = "ollama"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.llm.id
    dns_records {
      type = "A"
      ttl  = 10
    }
    routing_policy = "MULTIVALUE"
  }
}

resource "aws_service_discovery_service" "anythingllm" {
  name = "anythingllm"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.llm.id
    dns_records {
      type = "A"
      ttl  = 10
    }
    routing_policy = "MULTIVALUE"
  }
}