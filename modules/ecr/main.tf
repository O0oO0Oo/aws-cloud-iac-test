# ecr module, main.tf
resource "aws_ecr_repository" "business_service_repository" {
  name = "business-service"
  
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "business Server ECR Repository"
  }
}

resource "aws_ecr_repository" "recommend_service_repository" {
  name = "recommend-service"
  
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "recommend Server ECR Repository"
  }
}