# rds module variables
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "rds_private_subnets_ids" {
  description = "RDS 인스턴스가 위치할 private 서브넷 ID 리스트"
  type        = list(string)
}

variable "db_username" {
  description = "데이터베이스 사용자 이름"
  type        = string
  sensitive = true
}

variable "db_password" {
  description = "데이터베이스 비밀번호"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "데이터베이스 이름"
  type        = string
  sensitive = true
}

variable "db_allocated_storage" {
  description = "RDS 인스턴스의 스토리지 GB)"
  type        = number
}

variable "db_instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = "db.t3.micro"
}

variable "storage_type" {
  description = "스토리지 타입"
  type = string
  default = "gp"
}

variable "multi_az" {
  description = "multi-az"
  type = bool
  default = true  
}

variable "business_service_sg_id" {
  description = "ECS 서비스가 사용하는 보안 그룹 (비즈니스 서비스)"
  type        = string
}

variable "recommend_service_sg_id" {
  description = "ECS 서비스가 사용하는 보안 그룹 (추천 서비스)"
  type        = string
}