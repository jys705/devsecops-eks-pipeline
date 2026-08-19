# IAM 콘솔의 자격 증명 공급자 화면에 항목 하나가 생긴다. 
# data.aws_kms_alias는 만들지 않고 bootstrap이 만든 키의 ARN을 읽어온다.

data "aws_kms_alias" "tfstate" {
  name = "alias/tfstate"
}

# client_id_list는 토큰의 aud 클레임이고, AWS STS에 제시할 토큰은 sts.amazonaws.com이어야 한다.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  gha_sub_main = "repo:${var.github_repository}:ref:refs/heads/${var.github_default_branch}"
  gha_sub_pr   = "repo:${var.github_repository}:pull_request"
}

# IAM → 역할에 p2-devsecops-gha-plan이 생긴다. 
# 권한 탭에 관리형 ReadOnlyAccess 하나와 인라인 tfstate-decrypt 하나, 신뢰 관계 탭에 조건 둘이 붙은 문서가 보인다.
data "aws_iam_policy_document" "gha_plan_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      # push 이벤트는 브랜치까지, pull_request 이벤트는 저장소까지만 고정된다
      values = [local.gha_sub_main, local.gha_sub_pr]
    }
  }
}

resource "aws_iam_role" "gha_plan" {
  name                 = "${var.project}-gha-plan"
  description          = "GitHub Actions terraform plan. read only"
  assume_role_policy   = data.aws_iam_policy_document.gha_plan_assume.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "gha_plan_readonly" {
  role       = aws_iam_role.gha_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# kms:Decrypt가 없으면 terraform init 뒤 첫 state 읽기에서 막힌다. 
# ReadOnlyAccess를 나중에 좁은 정책으로 교체하면 s3:GetObject를 직접 넣어야 한다.
data "aws_iam_policy_document" "gha_plan" {
  statement {
    sid       = "DecryptTfstate"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_alias.tfstate.target_key_arn]
  }
}

resource "aws_iam_role_policy" "gha_plan" {
  name   = "tfstate-decrypt"
  role   = aws_iam_role.gha_plan.id
  policy = data.aws_iam_policy_document.gha_plan.json
}

data "aws_iam_policy_document" "gha_push_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.gha_sub_main]
    }
  }
}

resource "aws_iam_role" "gha_push" {
  name                 = "${var.project}-gha-push"
  description          = "GitHub Actions image push. ECR write only"
  assume_role_policy   = data.aws_iam_policy_document.gha_push_assume.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "gha_push" {
  statement {
    sid       = "GetAuthorizationToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushToAppRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeImages",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "gha_push" {
  name   = "ecr-push"
  role   = aws_iam_role.gha_push.id
  policy = data.aws_iam_policy_document.gha_push.json
}