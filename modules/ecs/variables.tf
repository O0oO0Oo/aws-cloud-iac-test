# ecs module variables
variable "cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "business_service_task_role_arn" {
  description = "The ARN of the ECS task role for the business service"
  type        = string
}

variable "recommend_service_task_role_arn" {
  description = "The ARN of the ECS task role for the recommend service"
  type        = string
}

# alb tg
variable "business_tg_arn" {
  description = "TG for Alb to Internal Business Server"
  type        = string
}

# alb sg
variable "alb_sg_id" {
  description = "alb sg id"
  type        = string
}


variable "ecs_business_subnet_ids" {
  description = "List of ecs_business_subnet_ids"
  type        = list(string)
}

variable "ecs_recommend_subnet_ids" {
  description = "List of ecs_recommend_subnet_ids"
  type        = list(string)
}

# Below are the variables for ecr name
variable "ecr_recommend_repository_url" {
  description = "ecr_recommend_repository_url"
  type        = string
}

variable "ecr_business_repository_url" {
  description = "ecr_business_repository_url"
  type        = string
}

variable "cdn_bucket_name" {
  description = "cdn_bucket_name"
  type        = string
}