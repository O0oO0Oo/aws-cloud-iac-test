variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2" # seoul
}

variable "db_username" {
  description = "RDS username"
  type        = string
  sensitive = true
}

variable "db_password" {
  description = "RDS password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  sensitive = true
}

variable "db_allocated_storage" {
  description = "RDS storage size in GB"
  type        = number
  default     = 50
}