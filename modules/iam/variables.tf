# 변수 선언
variable "rds_instance_arn" {
  description = "The ARN of the RDS instance from the RDS module"
  type        = string
}

variable "cdn_bucket_arn" {
  description = "The ARN of the CDN S3 bucket output from the S3 module"
  type        = string
}