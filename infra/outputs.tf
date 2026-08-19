output "gha_plan_role_arn" {
  value = aws_iam_role.gha_plan.arn
}

output "gha_push_role_arn" {
  value = aws_iam_role.gha_push.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}