output "ecr_business_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.business_service_repository.repository_url
}

output "ecr_recommend_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.recommend_service_repository.repository_url
}
