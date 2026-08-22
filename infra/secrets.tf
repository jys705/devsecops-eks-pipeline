# Secrets Manager 콘솔의 시크릿 목록에 항목 하나가 생긴다.
resource "aws_secretsmanager_secret" "app" {
  name                    = "${var.project}/app"
  description             = "write-only 인자 확인용. 소비자 없음"
  recovery_window_in_days = 0
}

# 콘솔에서는 시크릿 상세의 버전 탭에 AWSCURRENT 하나로 보인다.
resource "aws_secretsmanager_secret_version" "app" {
  secret_id                = aws_secretsmanager_secret.app.id
  # _wo 값은 state에 안 박히므로 Terraform은 값이 바뀐 걸 모름.
  secret_string_wo         = var.app_secret
  secret_string_wo_version = 1
}