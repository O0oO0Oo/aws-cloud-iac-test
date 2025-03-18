# ecs module output.tf
output "business_service_name" {
  description = "The name of the Spring ECS service"
  value       = aws_ecs_service.business_service.name
}

output "recommend_service_name" {
  description = "The name of the Python ECS service"
  value       = aws_ecs_service.recommend_service.name
}

output "business_service_sg_id" {
  description = "Business 서비스에서 사용하는 보안 그룹 ID"
  value       = aws_security_group.business_sg.id
}

output "recommend_service_sg_id" {
  description = "Recommend 서비스에서 사용하는 보안 그룹 ID"
  value       = aws_security_group.recommend_sg.id
}