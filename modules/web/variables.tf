# web module, variables.tf
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ssl_certificate_arn" {
  description = "The ARN of the SSL certificate to be used with the HTTPS listener"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "cdn_alias_name" {
  description = "CloudFront Distribution 도메인 이름"
  type        = string
}

variable "cdn_alias_zone_id" {
  description = "CloudFront Distribution의 Hosted Zone ID"
  type        = string
}
