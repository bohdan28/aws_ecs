output "ollama_service_discovery" {
  value = aws_service_discovery_service.ollama.name
}
output "anythingllm_service_discovery" {
  value = aws_service_discovery_service.anythingllm.name
}
output "ecr_ollama_url" {
  value = aws_ecr_repository.ollama.repository_url
}
output "ecr_anythingllm_url" {
  value = aws_ecr_repository.anythingllm.repository_url
}