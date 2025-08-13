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
  cpu                      = "2048" # 2 vCPU
  memory                   = "8192" # 8 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name         = "ollama"
      image        = var.ollama_image
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
        healthCheck = {
          command     = ["CMD-SHELL", "curl -f http://localhost:11434 || exit 1"]
          interval    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 1
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
      image        = vars.anythingllm_image
      portMappings = [{ containerPort = 3001, hostPort = 3001 }]
      essential    = true
      environment = [
        { name = "DATABASE_URL", value = "postgresql://${var.master_username}:${var.master_password}@${aws_db_instance.postgres.endpoint}/${var.database_name}" },
        { name = "VECTOR_DB", value = "pgvector" },
        { name = "PGVECTOR_CONNECTION_STRING", value = "postgresql://${var.master_username}:${var.master_password}@${aws_db_instance.postgres.endpoint}/${var.database_name}" },
        { name = "PGVECTOR_TABLE_NAME", value = "anythingllm_vectors" },
        { name = "STORAGE_DIR", value = "/app/server/storage" },
        { name = "JWT_SECRET", value = "REPLACE_WITH_SECRET" },
        { name = "LLM_PROVIDER", value = "ollama" },
        { name = "OLLAMA_BASE_PATH", value = "http://ollama.llm.local:11434" },
        { name = "OLLAMA_MODEL_PREF", value = "llama3:latest" },
        { name = "OLLAMA_MODEL_TOKEN_LIMIT", value = "4096" },
        { name = "EMBEDDING_ENGINE", value = "ollama" },
        { name = "EMBEDDING_BASE_PATH", value = "http://ollama.llm.local:11434" },
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
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3001 || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 1
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
        access_point_id = aws_efs_access_point.anythingllm-ap.id
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
# EFS for AnythingLLM persistent storage
resource "aws_efs_file_system" "anythingllm" {
  creation_token = "anythingllm-storage"
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = {
    Name = "anythingllm-storage"
  }
}

resource "aws_efs_access_point" "anythingllm-ap" {
  file_system_id = aws_efs_file_system.anythingllm.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/storage"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "anythingllm-access-point"
  }
}

# EFS for Prometheus persistent storage
resource "aws_efs_file_system" "prometheus" {
  creation_token = "prometheus-efs"
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = {
    Name = "prometheus-efs"
  }
}

resource "aws_efs_backup_policy" "prometheus" {
  file_system_id = aws_efs_file_system.prometheus.id
  backup_policy {
    status = "ENABLED"
  }
}


resource "aws_efs_access_point" "prometheus" {
  file_system_id = aws_efs_file_system.prometheus.id
  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/prometheus"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "777"
    }
  }
}

resource "aws_efs_mount_target" "prometheus_a" {
  file_system_id  = aws_efs_file_system.prometheus.id
  subnet_id       = module.vpc.private_subnets[0]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_mount_target" "prometheus_b" {
  file_system_id  = aws_efs_file_system.prometheus.id
  subnet_id       = module.vpc.private_subnets[1]
  security_groups = [aws_security_group.efs.id]
}

# Prometheus task definition
resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    # Init container to write prometheus.yml
    {
      name      = "init-config"
      image     = "public.ecr.aws/docker/library/busybox:latest"
      essential = false
      command = [
        "sh", "-c",
        <<-EOT
        cat <<EOF > /prometheus/prometheus.yml
        global:
          scrape_interval: 15s
        scrape_configs:
          - job_name: 'anythingllm'
            static_configs:
              - targets: ['anythingllm.llm.local:8080']
          - job_name: 'ollama'
            static_configs:
              - targets: ['ollama.llm.local:8080']
        EOF
        echo "Prometheus configuration written to /prometheus/prometheus.yml"
        EOT
      ]
      mountPoints = [{
        sourceVolume  = "prometheus-storage"
        containerPath = "/prometheus"
        readOnly      = false
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/prometheus"
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    },

    # Prometheus container
    {
      name         = "prometheus"
      image        = "prom/prometheus:latest"
      portMappings = [{ containerPort = 9090, hostPort = 9090 }]
      essential    = true
      environment  = []
      command = [
        "--config.file=/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus"
      ]
      mountPoints = [
        {
          sourceVolume  = "prometheus-storage"
          containerPath = "/prometheus"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/prometheus"
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  volume {
    name = "prometheus-storage"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.prometheus.id
      root_directory     = "/"
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.prometheus.id
        iam             = "ENABLED"
      }
    }
  }
}

# Grafana task definition
resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name         = "grafana"
      image        = "grafana/grafana:latest"
      portMappings = [{ containerPort = 3000, hostPort = 3000 }]
      essential    = true
      environment  = []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/grafana"
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# CloudWatch log groups for Prometheus and Grafana
resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/prometheus"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/grafana"
  retention_in_days = 14
}