# web module, main.tf
# 외부에서 ALB를 위한 보안 그룹 생성
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  # HTTPS 허용
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }

  # HTTP 허용 (HTTPS로 리다이렉트)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  # 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "ALB-SG"
  }
}

// 내부로의 ALB Target Group (Spring 비즈니스 서버용, 포트 8080)
resource "aws_lb_target_group" "business_tg" {
  name     = "business-service-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"
  
  health_check {
    enabled             = true
    interval            = 30
    path                = "/actuator/health"  # Spring Boot Actuator Health 엔드포인트
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "Business Service TG"
  }
}

# ALB
resource "aws_lb" "application_alb" {
  name               = "lets-leave-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids # 퍼블릭 서브넷 ID 리스트 필요

  enable_deletion_protection = true

  tags = {
    Name = "lets-leave-alb"
  }
}


// HTTPS 리스너 (ACM 인증서를 사용하여 HTTPS 요청을 Target Group으로 포워딩) < 내부 business 서버로
resource "aws_lb_listener" "application_alb_https_listener" {
  load_balancer_arn = aws_lb.application_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.business_tg.arn
  }
}

# HTTP 리스너 80을 443, HTTPS로 리디렉션
resource "aws_lb_listener" "application_alb_http_listener" {
  load_balancer_arn = aws_lb.application_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      protocol    = "HTTPS"
      port        = "443"
      status_code = "HTTP_301"
    }
  }
}

# Route 53에서 lets-leave.com의 호스티드 존 ID를 찾기
data "aws_route53_zone" "lets_leave" {
  name = "lets-leave.com."
}

# ALB의 DNS 이름을 lets-leave.com 도메인에 A 레코드로 추가
resource "aws_route53_record" "lets_leave_record" {
  zone_id = data.aws_route53_zone.lets_leave.zone_id
  name    = "lets-leave.com"
  type    = "A"

  alias {
    name                   = aws_lb.application_alb.dns_name
    zone_id                = aws_lb.application_alb.zone_id
    evaluate_target_health = true
  }
}

# www.lets-leave.com에 대한 CNAME 레코드 추가 (www 서브도 HTTPS로 리디렉션)
resource "aws_route53_record" "www_lets_leave_record" {
    zone_id = data.aws_route53_zone.lets_leave.zone_id
  name    = "www.lets-leave.com"
  type    = "A"

  alias {
    name                   = aws_lb.application_alb.dns_name
    zone_id                = aws_lb.application_alb.zone_id
    evaluate_target_health = true
  }
}

# cdn.lets-leave.com에 대한 CNAME 레코드 추가
resource "aws_route53_record" "cdn_lets_leave_record" {
  zone_id = data.aws_route53_zone.lets_leave.zone_id
  name    = "cdn.lets-leave.com"
  type    = "A"

  alias {
    name                   = var.cdn_alias_name # cdn domain name
    zone_id                = var.cdn_alias_zone_id # cdn zon id
    evaluate_target_health = false
  }
}