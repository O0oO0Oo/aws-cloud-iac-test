# rds 모듈의 output 정의
output "rds_proxy_endpoint" {
  description = "RDS Proxy 엔드포인트"
  value       = aws_db_proxy.rds_proxy.endpoint
}

output "rds_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.my_db.arn
}