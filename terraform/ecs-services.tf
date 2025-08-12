resource "aws_ecs_service" "ollama" {
  name            = "ollama"
  cluster         = aws_ecs_cluster.llm.id
  task_definition = aws_ecs_task_definition.ollama.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
  service_registries {
    registry_arn = aws_service_discovery_service.ollama.arn
  }
  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_service" "anythingllm" {
  name            = "anythingllm"
  cluster         = aws_ecs_cluster.llm.id
  task_definition = aws_ecs_task_definition.anythingllm.arn
  desired_count   = 2
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.anythingllm.arn
    container_name   = "anythingllm"
    container_port   = 3001
  }
  service_registries {
    registry_arn = aws_service_discovery_service.anythingllm.arn
  }
  depends_on = [aws_lb_listener.http, aws_db_instance.postgres]
}

# Prometheus ECS service
resource "aws_ecs_service" "prometheus" {
  name            = "prometheus"
  cluster         = aws_ecs_cluster.llm.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
  depends_on = [aws_efs_mount_target.prometheus_a, aws_efs_mount_target.prometheus_b]
}

# Grafana ECS service
resource "aws_ecs_service" "grafana" {
  name            = "grafana"
  cluster         = aws_ecs_cluster.llm.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }
}

#####################################################################



resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.llm.name}/${aws_ecs_service.anythingllm.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_policy" {
  name               = "cpu-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 60.0
  }
}

resource "aws_appautoscaling_policy" "memory_policy" {
  name               = "memory-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0
  }
}
