# 서울 리전의 모든 AZ 가져오기
data "aws_availability_zones" "available" {
  state = "available"
}

# 현재 리전 정보 가져오기
data "aws_region" "current" {}

# 기본 VPC 데이터
data "aws_vpc" "default" {
  default = true
}

# 기본 VPC의 기본 라우팅 테이블 가져오기
data "aws_route_table" "default" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# AZ별 서브넷 생성 - ALB 사용 az 단위로 존재
resource "aws_subnet" "public" {
  count             = 4
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = cidrsubnet(data.aws_vpc.default.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${data.aws_availability_zones.available.names[count.index]}"
  }
}

locals {
  az_count = length(data.aws_availability_zones.available.names)
}

# 프라이빗 서브넷 (ECS - business)
resource "aws_subnet" "private-business" {
  count             = local.az_count
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = cidrsubnet(data.aws_vpc.default.cidr_block, 11, count.index + 4) # /27 서브넷
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# 프라이빗 서브넷 (ECS - recommned)
resource "aws_subnet" "private-recommned" {
  count             = local.az_count
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = cidrsubnet(data.aws_vpc.default.cidr_block, 11, count.index + 8) # /27 서브넷
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# 프라이빗 서브넷 (RDS)
resource "aws_subnet" "private-rds" {
  count             = local.az_count
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = cidrsubnet(data.aws_vpc.default.cidr_block, 11, count.index + 12) # /27 서브넷
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# S3 접근 VPC Endpoint
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = data.aws_vpc.default.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "S3PutObjectAccess",
        "Action" : ["s3:PutObject"],
        "Resource" : ["arn:aws:s3:::your-bucket-name/*"],
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}