# CDN 모듈, main.tf
# S3 버킷 생성
resource "aws_s3_bucket" "cdn_bucket" {
  bucket        = var.bucket_name
  force_destroy = false

  # lifecycle { # 디스트로이 방지
  #   prevent_destroy = true
  # }

  tags = {
    Name = "CDN Bucket"
  }
}

# block public access 설정
resource "aws_s3_bucket_public_access_block" "cdn_bucket_access" {
  bucket = aws_s3_bucket.cdn_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# OAC 생성 (CloudFront에서 S3에 접근)
resource "aws_cloudfront_origin_access_control" "cdn_oac" {
  name                              = "cdn-oac"
  description                       = "OAC for cdn.lets-leave.com"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 버킷 정책 (OAC를 통한 CloudFront 접근만 허용)
resource "aws_s3_bucket_policy" "cdn_bucket_policy" {
  bucket = aws_s3_bucket.cdn_bucket.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowCloudFrontAccess",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudfront.amazonaws.com"
        },
        "Action" : "s3:GetObject",
        "Resource" : "${aws_s3_bucket.cdn_bucket.arn}/*",
        "Condition" : {
          "StringEquals" : {
            "AWS:SourceArn" : aws_cloudfront_distribution.cdn_distribution.arn
          }
        }
      }
    ]
  })
}

# CloudFront 배포 (OAC를 사용한 S3 오리진)
resource "aws_cloudfront_distribution" "cdn_distribution" {
  enabled             = true
  default_root_object = "index.html"

  # lifecycle { # 삭제 방지
  #   prevent_destroy = true
  # }

  origin {
    domain_name              = aws_s3_bucket.cdn_bucket.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.cdn_bucket.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.cdn_oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.cdn_bucket.id}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
      headers = ["Host"] # CORS를 방지하려면 CORS 관련 헤더를 전달하지 않도록 설정
    }
  }

  # CloudFront에서 사용할 ACM 인증서 연결
  viewer_certificate {
    acm_certificate_arn = var.ssl_certificate_arn # ACM 인증서 연결
    ssl_support_method  = "sni-only" # SSL, TLS Cerfifiation Option
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = ["cdn.lets-leave.com"]

  tags = {
    Name = "CloudFront CDN"
  }
}