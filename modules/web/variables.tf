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