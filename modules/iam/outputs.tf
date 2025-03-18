# outputs.tf in IAM module
output "ecs_rds_task_role_arn" {
  description = "The ARN of the ECS task role for RDS access"
  value       = aws_iam_role.ecs_rds_task_role.arn
}

output "ecs_rds_s3_task_role_arn" {
  description = "The ARN of the ECS task role for RDS and S3 access"
  value       = aws_iam_role.ecs_rds_s3_task_role.arn
}