# network 모듈, main.tf
# 새 VPC 생성
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"  # 기본 VPC와 다른 CIDR 블록 사용
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name = "main-vpc"
  }
}

# 서울 리전의 모든 AZ 가져오기
data "aws_availability_zones" "available" {
  state = "available"
}

# 현재 리전 정보 가져오기
data "aws_region" "current" {}

# AZ별 서브넷 생성 - ALB 사용 az 단위로 존재
resource "aws_subnet" "public" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public-subnet-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# 인터넷 게이트 웨이
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "main-igw"
  }
}

# 퍼블릭 라우팅 테이블 생성
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name = "public-route-table"
  }
}

# 퍼블릭 라우팅 테이블 연결
resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 기본 VPC의 기본 라우팅 테이블 가져오기
data "aws_route_table" "default" {
  vpc_id = aws_vpc.main.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

locals {
  az_count = min(length(data.aws_availability_zones.available.names), 4)  # 최대 4개 AZ 사용
}

# 프라이빗 서브넷 (ECS - business)
resource "aws_subnet" "private-business" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + local.az_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "private-business-subnet-${data.aws_availability_zones.available.names[count.index]}"
  }
}


# 프라이빗 서브넷 (ECS - recommend)
resource "aws_subnet" "private-recommend" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + (local.az_count * 2))
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "private-recommend-subnet-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# 프라이빗 서브넷 (RDS)
resource "aws_subnet" "private-rds" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + (local.az_count * 3))
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "private-rds-subnet-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# NAT 게이트웨이 생성 (프라이빗 서브넷용)
resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  
  tags = {
    Name = "main-nat-gateway"
  }
  
  depends_on = [aws_internet_gateway.igw]
}

# 프라이빗 라우팅 테이블
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  
  tags = {
    Name = "private-route-table"
  }
}

# 프라이빗 서브넷에 라우팅 테이블 연결
resource "aws_route_table_association" "private-business" {
  count          = local.az_count
  subnet_id      = aws_subnet.private-business[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private-recommend" {
  count          = local.az_count
  subnet_id      = aws_subnet.private-recommend[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private-rds" {
  count          = local.az_count
  subnet_id      = aws_subnet.private-rds[count.index].id
  route_table_id = aws_route_table.private.id
}

# S3 VPC 엔드포인트 생성
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id, aws_route_table.private.id]
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowAll"
        Effect = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.cdn_bucket_name}",
          "arn:aws:s3:::${var.cdn_bucket_name}/*"
        ]
      }
    ]
  })
  
  tags = {
    Name = "s3-endpoint"
  }
}