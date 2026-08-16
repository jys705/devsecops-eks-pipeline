# 버킷 껍데기만 만든다. 
# AWS provider 4.0부터 버저닝과 암호화, 수명 주기 같은 설정이 전부 별도 리소스로 분리됐다.
# 즉, versioning { enabled = true }과 같이 쓰면 에러가 난다
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id  # 이 참조 한 줄이 생성 순서를 만든다

  versioning_configuration {
    status = "Enabled"   # 기본은 비활성이다. S3 네이티브 lock을 사용할 목적이다. 한 번 켜면 Suspended까지만 되고 완전히 못 끈다는 특징이 있다.
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"                 # 기본 값은 AES256(SSE-S3). 그러면, SSE-S3라 KMS를 안 거치고 누가 state를 읽었는지 CloudTrail에 안 남는다.
      kms_master_key_id = aws_kms_key.tfstate.arn
    }

    # S3 Bucket Key를 켜면 KMS 호출이 버킷 단위로 되어 apply마다 CloudTrail에 적게 남는다.
    # KMS를 택한 근거가 접근 기록이라 명시적으로 끈다. 콘솔 기본값은 켜짐이다.
    bucket_key_enabled = false
  }
}

# 2023년 4월 이후 새 버킷은 이 네 개가 기본으로 켜져 있다.
# 그래도 코드에 쓰는 이유는, 누가 콘솔에서 끄면 다음 apply가 되돌리기 때문.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true  # 새 퍼블릭 ACL 차단
  block_public_policy     = true  # 새 퍼블릭 버킷 정책 차단
  ignore_public_acls      = true  # 이미 있는 퍼블릭 ACL 무시
  restrict_public_buckets = true  # 퍼블릭 정책이 있어도 계정 밖 접근 차단

}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-noncurrent-state"
    status = "Enabled"

    filter {}   # 빈 블록이 "버킷 전체"를 뜻한다. 빼면 규칙 범위가 없어 실패한다

    noncurrent_version_expiration {
      noncurrent_days = 90   # apply마다 쌓이는 옛 버전을 90일 뒤 삭제
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "tfstate_bucket" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    
    # ARN을 두 개 써야한다.
    resources = [
        aws_s3_bucket.tfstate.arn,           # 1. 버킷 대상 액션 (s3:ListBucket 등)
        "${aws_s3_bucket.tfstate.arn}/*"     # 2. 버킷 안 객체 대상 액션 (s3:GetObject 등)
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate_bucket.json
}