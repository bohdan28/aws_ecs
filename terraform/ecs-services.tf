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
  desired_count   = 1
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
  depends_on = [aws_lb_listener.http]
}