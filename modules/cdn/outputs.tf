output "cdn_bucket_arn" {
  description = "ARN of the CDN S3 bucket"
  value       = aws_s3_bucket.cdn_bucket.arn
}

output "cdn_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.cdn_distribution.arn
}