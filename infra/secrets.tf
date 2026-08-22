# Secrets Manager 콘솔의 시크릿 목록에 항목 하나가 생긴다.
resource "aws_secretsmanager_secret" "app" {
  #checkov:skip=CKV_AWS_149:전용 CMK를 만들면 destroy 뒤 최소 7일 삭제 대기로 계정에 남고 그 동안 과금된다. 이 프로젝트는 구현마다 계정을 0으로 되돌리는 것이 전제라 관리형 aws/secretsmanager 키를 쓴다
  #checkov:skip=CKV2_AWS_57:회전 Lambda를 두지 않는다. 소비자가 없는 증명용 시크릿이고 회전 주기를 판단할 근거가 없다
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