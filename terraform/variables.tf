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
