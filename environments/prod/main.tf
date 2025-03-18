terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.region
}

# 네트워크 모듈 기본 VPC, 서브넷 정보 제공
module "network" {
  source = "../../modules/network"
}

# SSL 인증
module "acm" {
  source = "../../modules/acm"
}

# 웹 모듈 ALB, Route 53 등 웹 리소스
module "web" {
  source              = "../../modules/web"
  vpc_id              = module.network.vpc_id
  ssl_certificate_arn = module.acm.ssl_certificate_arn # ACM 인증서 ARN 전달
  public_subnet_ids   = module.network.public_subnet_ids
}

# CDN 모듈: S3, CloudFront, OAC, Route 53 등
module "cdn" {
  source              = "../../modules/cdn"
  bucket_name         = "lets-leave-cdn-bucket"
  ssl_certificate_arn = module.acm.ssl_certificate_arn # ACM 인증서 ARN 전달
}

# 보안
module "iam" {
  source           = "../../modules/iam"
  rds_instance_arn = module.rds.rds_instance_arn
  cdn_bucket_arn   = module.cdn.cdn_bucket_arn
}

# 이미지
module "ecr" {
  source          = "../../modules/ecr"
  repository_name = "ecr-repository"
}

# 관리
module "ecs" {
  source                          = "../../modules/ecs"
  cluster_name                    = "lets-leave-ecs"
  vpc_id                          = module.network.vpc_id
  business_service_task_role_arn  = module.iam.ecs_rds_s3_task_role_arn
  recommend_service_task_role_arn = module.iam.ecs_rds_task_role_arn

  ecs_business_subnet_ids  = module.network.ecs_business_subnet_ids
  ecs_recommend_subnet_ids = module.network.ecs_recommend_subnet_ids

  ecr_business_repository_url  = module.ecr.ecr_business_repository_url
  ecr_recommend_repository_url = module.ecr.ecr_recommend_repository_url

  business_tg_arn = module.web.business_tg_arn
  alb_sg_id       = module.web.alb_sg_id
}

# RDS 모듈: MySQL RDS 및 RDS Proxy
module "rds" {
  source                  = "../../modules/rds"
  vpc_id                  = module.network.vpc_id
  rds_private_subnets_ids = module.network.rds_subnet_ids
  db_username             = var.db_username
  db_password             = var.db_password
  db_name                 = var.db_name
  db_allocated_storage    = var.db_allocated_storage
  business_service_sg_id  = module.ecs.business_service_sg_id
  recommend_service_sg_id = module.ecs.recommend_service_sg_id
}
