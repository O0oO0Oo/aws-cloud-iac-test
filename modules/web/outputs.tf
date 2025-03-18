# web module, outputs.tf
output "alb_sg_id" {
  description = "Application LoadBalancer Security Group ID"
  value = aws_security_group.alb_sg.id
}

output "business_tg_arn" {
  description = "Security groups for internal business servers"
  value = aws_lb_target_group.business_tg.arn
}