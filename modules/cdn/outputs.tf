# cdn 모듈의 output 정의
output "cdn_bucket_arn" {
  description = "ARN of the CDN S3 bucket"
  value       = aws_s3_bucket.cdn_bucket.arn
}

output "cdn_bucket_name" {
  description = "Name of the CDN S3 bucket"
  value       = aws_s3_bucket.cdn_bucket.bucket
}

output "cdn_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.cdn_distribution.arn
}

# CloudFront 배포 관련 output
output "cdn_distribution_domain_name" {
  description = "CloudFront Distribution의 도메인 이름"
  value       = aws_cloudfront_distribution.cdn_distribution.domain_name
}

output "cdn_distribution_hosted_zone_id" {
  description = "CloudFront Distribution의 Hosted Zone ID"
  value       = aws_cloudfront_distribution.cdn_distribution.hosted_zone_id
}