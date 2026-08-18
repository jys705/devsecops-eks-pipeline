data "aws_region" "current" {}

locals {
  interface_endpoints = [
    "ec2",
    "ecr.api",
    "ecr.dkr",
    "ssm",
    "ssmmessages",
    "ec2messages",
    "sts",
    "logs",
    "eks",
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_endpoints)

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = true
  # 가장 중요한 한 줄이다. 기본값은 false인데, 끄면 엔엔드포인트는 만들어지지만 ssm.ap-northeast-2.amazonaws.com이 여전히 공인 IP로 풀려서 아무 데도 못 닿는다.

  tags = {
    Name = "${var.project}-${each.key}"
  }
}

# S3 엔드포인트 정책이 보안 판단. 정책을 안 주면 AWS가 전체 허용 정책을 붙인다. 
# 여기서는 ECR 이미지 레이어 버킷만 s3:GetObject로 허용.
data "aws_iam_policy_document" "s3_endpoint" {
  statement {
    sid       = "AllowEcrLayerPull"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::prod-${data.aws_region.current.region}-starport-layer-bucket/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  # 이 정책의 값은 관리자 자격 증명을 들고 있어도 이 VPC 안에서는 두 버킷 말고 다른 S3 버킷에 닿을 수 없다는 것
  statement {
    sid       = "AllowSessionLogPut"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.session_logs.arn}/session-logs/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {
    sid       = "AllowSessionLogEncryptionCheck"
    effect    = "Allow"
    actions   = ["s3:GetEncryptionConfiguration"]
    resources = [aws_s3_bucket.session_logs.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  policy            = data.aws_iam_policy_document.s3_endpoint.json

  tags = {
    Name = "${var.project}-s3"
  }
}