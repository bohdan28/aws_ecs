variable "region" {
  default = "eu-central-1"
}

variable "database_name" {
  description = "The name of the database to create"
  type        = string
  default     = "anythingllm"
}

variable "master_username" {
  description = "The username for the database master user"
  type        = string
  default     = "postgres"
}

variable "master_password" {
  description = "The password for the database master user"
  type        = string
  default     = "REPLACE_WITH_STRONG_PASSWORD"
}

variable "ollama_image" {
  description = "Docker image for the Ollama service"
  type        = string
  default     = "362695547144.dkr.ecr.eu-central-1.amazonaws.com/training/llm:latest"
}

variable "anythingllm_image" {
  description = "Docker image for the AnythingLLM service"
  type        = string
  default     = "362695547144.dkr.ecr.eu-central-1.amazonaws.com/training/anythingllm-webui:latest"
}

variable "allowed_ips" {
  description = "List of allowed IP addresses for database access"
  type        = list(string)
  default     = []
}