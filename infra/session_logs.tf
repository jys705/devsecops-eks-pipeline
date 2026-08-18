data "aws_caller_identity" "current" {}

# 버킷 이름은 전 세계에서 유일해야 하므로 계정 ID를 넣는다.
locals {
  session_log_bucket = "${var.project}-session-logs-${data.aws_caller_identity.current.account_id}-apne2"
}

resource "aws_s3_bucket" "session_logs" {
  bucket        = local.session_log_bucket
  force_destroy = true # [실습 편의]: force_destroy의 기본값은 false. 버저닝을 켜면 객체 버전이 남아 있는 버킷을 삭제할 수 없어 destroy가 BucketNotEmpty로 실패하므로 true로 바꾼다. force_destroy가 없으면 세션마다 콘솔에서 버전을 손으로 비우게 된다.

  tags = {
    Name = local.session_log_bucket
  }
}

resource "aws_s3_bucket_versioning" "session_logs" {
  bucket = aws_s3_bucket.session_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# sse_algorithm에 aws:kms만 쓰고 kms_master_key_id를 비운다
# 그러면 S3가 AWS 관리형 aws/s3 키를 쓴다
resource "aws_s3_bucket_server_side_encryption_configuration" "session_logs" {
  bucket = aws_s3_bucket.session_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }

    # bucket_key_enabled의 기본값은 false이고 그대로 둔다. 
    # 켜면 데이터 키가 재사용되어 KMS 호출이 줄어드는데, 
    # 이 선택의 유일한 소득이 CloudTrail의 객체 단위 기록이라 켜면 SSE-KMS를 쓸 이유가 사라진다.
    # 명시적으로 적은 것은 콘솔에서 이 버킷을 만들면 기본으로 켜지기 때문.
    bucket_key_enabled = false
  }
}

# 삭제 방지 정책
resource "aws_s3_bucket_public_access_block" "session_logs" {
  bucket = aws_s3_bucket.session_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 대상이 노드 역할 하나이다. 
# 세션 셸에 들어간 운영자는 IMDS를 쳐서 노드 역할 자격 증명을 얻을 수 있다. 
# 홉 제한 1이 막는 것은 파드지 노드 운영체제가 아니다. 
# 그 자격 증명으로 자기가 방금 친 명령의 기록을 지울 수 있으면 그건 증거가 아니게 된다.
data "aws_iam_policy_document" "session_logs" {
  statement {
    sid    = "DenyLogDeletionByNode"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.node.arn]
    }

    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:PutBucketVersioning",
    ]

    resources = [
      aws_s3_bucket.session_logs.arn,
      "${aws_s3_bucket.session_logs.arn}/*",
    ]
  }
}

# Systems Manager 콘솔 → Session Manager → 기본 설정 탭에서 보이는 값 전부
resource "aws_s3_bucket_policy" "session_logs" {
  bucket = aws_s3_bucket.session_logs.id
  policy = data.aws_iam_policy_document.session_logs.json

  depends_on = [aws_s3_bucket_public_access_block.session_logs]
}

resource "aws_ssm_document" "session_preferences" {
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Session Manager preferences"
    sessionType   = "Standard_Stream"
    inputs = {
      s3BucketName                = aws_s3_bucket.session_logs.id
      s3KeyPrefix                 = "session-logs"
      s3EncryptionEnabled         = true
      cloudWatchLogGroupName      = ""
      cloudWatchEncryptionEnabled = false
      cloudWatchStreamingEnabled  = false # 로깅
      kmsKeyId                    = ""
      runAsEnabled                = false
      runAsDefaultUser            = ""
      idleSessionTimeout          = "20"
      maxSessionDuration          = ""
      shellProfile = {
        windows = ""
        linux   = ""
      }
    }
  })
}