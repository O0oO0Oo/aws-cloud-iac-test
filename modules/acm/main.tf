# ACM 모듈, min.tf 파일
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_route53_zone" "lets_leave" {
  name = "lets-leave.com."
}

resource "aws_acm_certificate" "ssl_certificate" {
  provider = aws.us_east_1 # us-east-1 리전에서 인증서 생성
  domain_name       = "lets-leave.com"
  validation_method = "DNS"

  subject_alternative_names = ["www.lets-leave.com", "cdn.lets-leave.com"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "lets-leave SSL Certificate"
  }

  # lifecycle {
  #   create_before_destroy = true
  # }
}

# DNS validation을 위한 Route 53 레코드 생성
resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ssl_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.lets_leave.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# 인증서 검증 완료 대기 리소스
resource "aws_acm_certificate_validation" "cert_validation" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.ssl_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

# ACM 인증서 ARN을 출력값으로 반환
output "ssl_certificate_arn" {
  value = aws_acm_certificate.ssl_certificate.arn
}