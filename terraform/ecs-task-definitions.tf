data "aws_ecr_repository" "ollama" {
  name = aws_ecr_repository.ollama.name
}
data "aws_ecr_repository" "anythingllm" {
  name = aws_ecr_repository.anythingllm.name
}

resource "aws_ecs_task_definition" "ollama" {
  family                   = "ollama-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "2048" # 1 vCPU
  memory                   = "8192" # 8 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name         = "ollama"
      image        = "362695547144.dkr.ecr.eu-central-1.amazonaws.com/training/llm:latest"
      portMappings = [{ containerPort = 11434, hostPort = 11434 }]
      essential    = true
      environment  = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/ollama"
          awslogs-region        = "eu-central-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_task_definition" "anythingllm" {
  family                   = "anythingllm-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name         = "anythingllm"
      image        = "mintplexlabs/anythingllm:latest"
      portMappings = [{ containerPort = 3001, hostPort = 3001 }]
      essential    = true
      environment = [
        { name = "STORAGE_DIR", value = "/app/server/storage" },
        { name = "JWT_SECRET", value = "REPLACE_WITH_SECRET" },
        { name = "LLM_PROVIDER", value = "ollama" },
        { name = "OLLAMA_BASE_PATH", value = "http://ollama:11434" },
        { name = "OLLAMA_MODEL_PREF", value = "llama2:latest" },
        { name = "OLLAMA_MODEL_TOKEN_LIMIT", value = "4096" },
        { name = "EMBEDDING_ENGINE", value = "ollama" },
        { name = "EMBEDDING_BASE_PATH", value = "http://ollama:11434" },
        { name = "EMBEDDING_MODEL_PREF", value = "nomic-embed-text:latest" },
        { name = "EMBEDDING_MODEL_MAX_CHUNK_LENGTH", value = "8192" },
        { name = "WHISPER_PROVIDER", value = "local" },
        { name = "TTS_PROVIDER", value = "native" },
        { name = "PASSWORDMINCHAR", value = "8" }
      ]
      mountPoints = [
        {
          sourceVolume  = "anythingllm-storage"
          containerPath = "/app/server/storage"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/anythingllm"
          awslogs-region        = "eu-central-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  volume {
    name = "anythingllm-storage"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.anythingllm.id
      root_directory     = "/"
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = null
        iam             = "DISABLED"
      }
    }
  }
}

resource "aws_cloudwatch_log_group" "anythingllm" {
  name              = "/ecs/anythingllm"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "ollama" {
  name              = "/ecs/ollama"
  retention_in_days = 14
}

resource "aws_security_group" "efs" {
  name        = "efs-sg"
  description = "Allow NFS access from ECS tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_mount_target" "anythingllm_a" {
  file_system_id  = aws_efs_file_system.anythingllm.id
  subnet_id       = module.vpc.private_subnets[0]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "anythingllm_b" {
  file_system_id  = aws_efs_file_system.anythingllm.id
  subnet_id       = module.vpc.private_subnets[1]
  security_groups = [aws_security_group.efs.id]
}