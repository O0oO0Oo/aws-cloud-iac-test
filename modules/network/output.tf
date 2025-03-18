# network 모듈의 output 정의
# 퍼블릭 서브넷 ID 출력
output "public_subnet_ids" {
  description = "Public subnet IDs for ALB and CloudFront connections"
  value       = aws_subnet.public[*].id
}

output "ecs_business_subnet_ids" {
  description = "Private subnet IDs for ECS Business in each Availability Zone"
  value       = aws_subnet.private-business[*].id
}

output "ecs_recommend_subnet_ids" {
  description = "Private subnet IDs for ECS Recommend in each Availability Zone"
  value       = aws_subnet.private-recommend[*].id
}

output "rds_subnet_ids" {
  description = "Private subnet IDs for RDS in each Availability Zone"
  value       = aws_subnet.private-rds[*].id
}

# VPC ID 출력
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

# S3 VPC 엔드포인트 ID 출력
output "s3_vpc_endpoint_id" {
  description = "S3 VPC Endpoint ID"
  value       = aws_vpc_endpoint.s3_endpoint.id
}

# 가용성 영역 목록 출력
output "availability_zones" {
  description = "List of availability zones"
  value       = data.aws_availability_zones.available.names
}