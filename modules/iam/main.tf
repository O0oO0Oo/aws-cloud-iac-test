# RDS 접근만 허용하는 IAM 정책
resource "aws_iam_policy" "rds_access_policy" {
  name        = "rds-access-policy"
  description = "Policy to allow access to RDS instances"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["rds:DescribeDBInstances", "rds:Connect"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = ["rds:PutItem", "rds:GetItem", "rds:UpdateItem", "rds:DeleteItem"]
        Effect   = "Allow"
        Resource = var.rds_instance_arn
      }
    ]
  })
}

# RDS 접근만을 위한 IAM 역할
resource "aws_iam_role" "ecs_rds_task_role" {
  name = "ecs-rds-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

# S3 접근만 허용하는 IAM 정책
resource "aws_iam_policy" "s3_access_policy" {
  name        = "s3-access-policy"
  description = "Policy to allow access to S3 buckets"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = [
          "${var.cdn_bucket_arn}/*",
          var.cdn_bucket_arn
        ]
      }
    ]
  })
}

# RDS와 S3 접근을 위한 IAM 역할
resource "aws_iam_role" "ecs_rds_s3_task_role" {
  name = "ecs-rds-s3-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

# ecs_rds_s3_task_role 에 S3 정책을 해당 역할에 연결
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.ecs_rds_s3_task_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# ecs_rds_s3_task_role 에 RDS 정책을 해당 역할에 연결
resource "aws_iam_role_policy_attachment" "rds_policy_attachment" {
  role       = aws_iam_role.ecs_rds_s3_task_role.name
  policy_arn = aws_iam_policy.rds_access_policy.arn
}
