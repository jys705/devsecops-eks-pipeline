# ECR → 프라이빗 리포지토리 목록에 p2-devsecops-app이 생긴다. 
# 상세 화면에서 태그 변경 가능성이 변경 불가능, 푸시 시 스캔이 활성화됨, 암호화 유형이 KMS로 보인다.
resource "aws_ecr_repository" "app" {
  name = "${var.project}-app"
  # image_tag_mutability의 기본값은 MUTABLE이다. 
  # IMMUTABLE로 바꾼 이유는 태그를 덮어쓸 수 있으면 Trivy가 스캔한 latest와 나중에 배포되는 latest가 다른 이미지일 수 있고, 
  # "스캔한 이미지와 배포한 이미지가 동일하다"가 거짓이 된다.
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  # 수명주기 정책 유지 개수를 5에서 20으로 올린다.
  # k8s 매니페스트가 커밋 SHA 태그 하나를 고정하는데, main push마다 이미지가 하나씩
  # 늘고 Dependabot PR 머지도 main push다. 5로 두면 고정한 태그가 재현 apply 전에
  # 만료되고, 그 실패는 apply가 아니라 파드 기동에서 ImagePullBackOff로 나타난다.
  # 20은 현재 이미지 4개에 남은 단계의 push와 Dependabot 머지를 더해 잡은 수다.
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}