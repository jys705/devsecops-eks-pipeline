# CloudTrail 로그 버킷
locals {
  cloudtrail_bucket = "${var.project}-cloudtrail-${data.aws_caller_identity.current.account_id}-apne2"
  trail_name        = "${var.project}-trail"
  trail_arn         = "arn:aws:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket        = local.cloudtrail_bucket
  force_destroy = true

  tags = {
    Name = local.cloudtrail_bucket
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# 버킷 정책
# sse_algorithm을 AES256으로 둔다. 세션 로그 버킷의 aws:kms와 반대이다.
# AWS는 로그 전달 대상 버킷에 관해 SSE-KMS를 쓸 경우 고객 관리형 키를 써야 하며 
# AWS 관리형 키는 지원하지 않고, 관리형 키로 설정하면 로그가 읽을 수 없는 형태로 전달된다
data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "AWSCloudTrailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.cloudtrail]
}

# 트레일
resource "aws_cloudtrail" "main" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  tags = {
    Name = local.trail_name
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# Flow Logs 로그 그룹과 전달 역할
# AWS 문서는 logs:CreateLogGroup과 logs:DescribeLogGroups를 포함한 다섯 개를 Resource: "*"로 부여하라고 안내한다.
# 로그 그룹을 Terraform이 미리 만들므로 앞의 둘을 뺐고, 자원도 그 그룹 하나로 좁힌다.
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.project}/flow-logs"
  retention_in_days = var.flow_log_retention_days
}

data "aws_iam_policy_document" "flow_logs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.project}-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume.json
}

# Flow Logs 전달 역할의 권한
# AWS 문서는 다섯 액션을 Resource: "*"로 부여하라고 안내한다.
# 로그 그룹을 Terraform이 미리 만드니 CreateLogGroup과 DescribeLogGroups는 필요 없다고
# 보고 셋으로 줄였는데, 전달이 Access error로 실패했다. 서비스는 로그 그룹이 있어도
# 두 호출을 시도한다. 액션은 문서대로 되돌리되 자원 범위는 좁힌다.
data "aws_iam_policy_document" "flow_logs" {
  statement {
    sid    = "PublishToFlowLogGroup"
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]

    resources = ["${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "${var.project}-flow-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs.json
}

# Flow Logs 리소스
resource "aws_flow_log" "vpc" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn             = aws_iam_role.flow_logs.arn
  max_aggregation_interval = 60

  tags = {
    Name = "${var.project}-flow-logs"
  }

  depends_on = [aws_iam_role_policy.flow_logs]
}