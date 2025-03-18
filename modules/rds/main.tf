###########################
# RDS 서브넷 그룹
###########################
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = var.rds_private_subnets_ids

  tags = {
    Name = "rds-subnet-group"
  }
}

###########################
# RDS 보안 그룹 (예: Spring ECS 서비스에서만 접근 허용)
###########################
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow access to RDS"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    security_groups = [
      var.business_service_sg_id, var.recommend_service_sg_id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

###########################
# RDS 인스턴스 생성 (MySQL, db.t3.small, Multi-AZ, 50GB gp2)
###########################
resource "aws_db_instance" "my_db" {
  allocated_storage      = var.db_allocated_storage
  storage_type           = var.storage_type
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  identifier             = "mydb-instance"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.mysql8.0"
  multi_az               = var.multi_az
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true # 스냅샷 나중 설정

  deletion_protection = true

  tags = {
    Name = "My RDS Instance"
  }
}

###########################
# RDS 프록시 구성
###########################

# RDS 프록시용 IAM 역할 생성
resource "aws_iam_role" "rds_proxy_role" {
  name = "rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "rds.amazonaws.com"
      }
    }]
  })
}

# RDS 프록시 생성 (MySQL 엔진 패밀리)
resource "aws_db_proxy" "rds_proxy" {
  name                   = "my-rds-proxy"
  debug_logging          = true
  engine_family          = "MYSQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy_role.arn
  vpc_subnet_ids         = var.rds_private_subnets_ids
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  auth {
    auth_scheme = "SECRETS"
    description = "RDS proxy authentication using Secrets Manager"
    iam_auth    = "DISABLED"
    secret_arn  = "" # 연결할 Secrets Manager ARN을 입력하세요
  }

  tags = {
    Name = "My RDS Proxy"
  }
}

resource "aws_db_proxy_default_target_group" "rds_proxy_default_target_group" {
  db_proxy_name = aws_db_proxy.rds_proxy.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    init_query                   = "SET x=1, y=2"
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    session_pinning_filters      = ["EXCLUDE_VARIABLE_SETS"]
  }
}

# RDS 프록시 대상: 위에서 생성한 RDS 인스턴스를 프록시 타겟으로 등록
resource "aws_db_proxy_target" "rds_proxy_target" {
  db_proxy_name          = aws_db_proxy.rds_proxy.name
  db_instance_identifier = aws_db_instance.my_db.id
  target_group_name      = aws_db_proxy_default_target_group.rds_proxy_default_target_group.name
}