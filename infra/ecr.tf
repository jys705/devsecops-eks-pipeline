# ECR → 프라이빗 리포지토리 목록에 p2-devsecops-app이 생긴다. 
# 상세 화면에서 태그 변경 가능성이 변경 불가능, 푸시 시 스캔이 활성화됨, 암호화 유형이 KMS로 보인다.
resource "aws_ecr_repository" "app" {
  name                 = "${var.project}-app"
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

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}