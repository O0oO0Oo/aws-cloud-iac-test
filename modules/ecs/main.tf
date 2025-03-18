# ecs module main.tf
# ECS 인스턴스 프로필
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

# ECS 인스턴스를 위한 보안 그룹
resource "aws_security_group" "ecs_instances" {
  name        = "ecs-instances-sg"
  description = "Security Group for ECS instances"
  vpc_id      = var.vpc_id

  # 컨테이너 간 통신을 위한 인바운드 규칙 (8080 포트만 허용)
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    self        = true
    description = "Allow traffic on port 8080 between ECS instances"
  }

  # ALB에서 ECS 인스턴스로의 트래픽 허용
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.alb_sg_id]
    description     = "Allow inbound traffic from ALB"
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "ECS-Instances-SG"
  }
}

# ECS 인스턴스 역할
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# 필요한 정책 연결
resource "aws_iam_role_policy_attachment" "ecs_instance_role_attachment" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# 시작 템플릿
resource "aws_launch_template" "ecs_launch_template" {
  name_prefix   = "ecs-launch-template"
  image_id      = "ami-0c55b159cbfafe1f0"  # ECS 최적화 AMI ID (리전별로 다름)
  instance_type = "t3.small"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
  EOF
  )

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ecs_instances.id]
  }
}

# AZ별 ASG 생성 (Business 서비스)
resource "aws_autoscaling_group" "business_asg" {
  count              = length(var.ecs_business_subnet_ids)
  name               = "business-asg-${count.index}"
  vpc_zone_identifier = [var.ecs_business_subnet_ids[count.index]]
  desired_capacity   = 1
  min_size           = 1
  max_size           = 4

  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ECS-Business-Instance-AZ${count.index}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "business-service"
    propagate_at_launch = true
  }
}

# AZ별 ASG 생성 (Recommend 서비스)
resource "aws_autoscaling_group" "recommend_asg" {
  count               = length(var.ecs_recommend_subnet_ids)
  name                = "recommend-asg-${count.index}"
  vpc_zone_identifier = [var.ecs_recommend_subnet_ids[count.index]]
  desired_capacity    = 1
  min_size            = 1
  max_size            = 4

  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ECS-Recommend-Instance-AZ${count.index}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "recommend-service"
    propagate_at_launch = true
  }
}


# Cloud Map 네임스페이스 생성
resource "aws_service_discovery_private_dns_namespace" "private_dns" {
  name        = "lets-leave.local"
  description = "Private DNS Namespace for ECS"
  vpc         = var.vpc_id
}

# Spring 메인 비즈니스 서버를 위한 Cloud Map 서비스 생성
resource "aws_service_discovery_service" "business_service" {
  name         = "business-service"
  namespace_id = aws_service_discovery_private_dns_namespace.private_dns.id
  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.private_dns.id
    routing_policy = "MULTIVALUE"
    dns_records {
      ttl  = 60
      type = "A"
    }
  }

  # The number of 30-second intervals that you want service discovery to wait before it changes the health status of a service instance.
  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "Spring ECS Business Service for Cloud Map"
  }
}

# Python 추천 서버를 위한 Cloud Map 서비스 생성
resource "aws_service_discovery_service" "recommend_service" {
  name         = "recommend-service"
  namespace_id = aws_service_discovery_private_dns_namespace.private_dns.id
  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.private_dns.id
    routing_policy = "MULTIVALUE"
    dns_records {
      ttl  = 60
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "Python ECS Recommend Service for Cloud Map"
  }
}

# ECS 클러스터 생성
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "lets-leave-cluster"
}

# Execution Role 설정
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Effect = "Allow"
      Sid    = ""
    }]
  })
}

# ECR에서 이미지를 가져올 수 있도록 필요한 정책 추가
resource "aws_iam_policy_attachment" "ecs_execution_role_policy_attachment" {
  name       = "ecs-task-execution-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  roles      = [aws_iam_role.ecs_execution_role.name]
}

resource "aws_iam_policy_attachment" "ecs_ecr_policy_attachment" {
  name       = "ecs-ecr-policy-attachment"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  roles      = [aws_iam_role.ecs_execution_role.name]
}

# Spring 메인 비즈니스 서비스 태스트
resource "aws_ecs_task_definition" "business_service_task" {
  family                   = "business-service-task"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn # Execution Role 지정
  task_role_arn            = var.business_service_task_role_arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]


  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "business-service"
    image     = var.ecr_business_repository_url
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    }]
    environment = [
      {
        name  = "S3_BUCKET_NAME",
        value = var.cdn_bucket_name  # 변수 추가 필요
      }
    ]
  }])
}

# Spring 비즈니스 서버 보안그룹
resource "aws_security_group" "business_sg" {
  name        = "spring-service-sg"
  description = "Security Group for Spring Service"
  vpc_id      = var.vpc_id

  # ALB가 Spring 서비스로 접근할 수 있도록 설정
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [var.alb_sg_id]  # ALB 보안 그룹에서만 접근 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Spring business Service SG"
  }
}

# Spring ECS 메인 비즈니스 서비스 생성
resource "aws_ecs_service" "business_service" {
  name            = "business-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.business_service_task.arn
  desired_count   = 2
  launch_type = "EC2"

  service_registries {
    registry_arn = aws_service_discovery_service.business_service.arn
  }

  load_balancer {
    target_group_arn = var.business_tg_arn  // ALB 모듈에서 전달받은 Target Group ARN
    container_name   = "business-service"    // Task 정의의 container name과 동일해야 함
    container_port   = 8080
  }
  
  deployment_maximum_percent = 100 // 배포과정에서 최대 desired_count 만큼 동시에 실행 가능, 현재는 순차적으로 바꿈
  deployment_minimum_healthy_percent = 50 // 최소 정상 유지 태스크 

  network_configuration {
    subnets          = var.ecs_business_subnet_ids
    security_groups  = [aws_security_group.business_sg.id]
    assign_public_ip = true
  }
  tags = {
    Name = "Spring ECS Service"
  }
}

# python 추천 서비스 태스트
resource "aws_ecs_task_definition" "recommend_service_task" {
  family                   = "recommend-service-task"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn # Execution Role 지정
  task_role_arn            = var.recommend_service_task_role_arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "recommend-service"
    image     = var.ecr_recommend_repository_url
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
      protocol      = "tcp"
    }]
  }])
}

resource "aws_security_group" "recommend_sg" {
  name        = "python-service-sg"
  description = "Security Group for Python Service"
  vpc_id      = var.vpc_id

  # Spring 서비스에서만 접근 허용
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.business_sg.id]  # Spring 서비스에서만 접근 허용
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Python recommend Service SG"
  }
}


# recommend 서비스도 마찬가지로 퍼블릭 IP 비활성화
resource "aws_ecs_service" "recommend_service" {
  name            = "recommend-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.recommend_service_task.arn
  desired_count   = 2
  launch_type     = "EC2"
  
  service_registries {
    registry_arn = aws_service_discovery_service.recommend_service.arn
  }
  
  network_configuration {
    subnets          = var.ecs_recommend_subnet_ids
    security_groups  = [aws_security_group.recommend_sg.id]
    assign_public_ip = false  # 내부 서비스이므로 퍼블릭 IP 필요 없음
  }
  
  deployment_maximum_percent = 100
  deployment_minimum_healthy_percent = 50
}

# 오토스케일링 설정
resource "aws_appautoscaling_target" "business_service_autoscale" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.business_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_target" "recommend_service_autoscale" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.recommend_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "business_service_scale_up" {
  name               = "business-service-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.business_service_autoscale.resource_id
  scalable_dimension = aws_appautoscaling_target.business_service_autoscale.scalable_dimension
  service_namespace  = aws_appautoscaling_target.business_service_autoscale.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_appautoscaling_policy" "recommend_service_scale_up" {
  name               = "recommend-service-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.recommend_service_autoscale.resource_id
  scalable_dimension = aws_appautoscaling_target.recommend_service_autoscale.scalable_dimension
  service_namespace  = aws_appautoscaling_target.recommend_service_autoscale.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}