resource "aws_kms_key" "tfstate" {
  description             = "tfstate encryption key"
  enable_key_rotation     = true   # 기본값 false. 매년 키 재료를 자동 교체하게 된다.
  deletion_window_in_days = 7      # 기본값 삭제 대기 시간 30일. 대기 중에도 과금되므로 7~30 중 최소값.
  policy                  = data.aws_iam_policy_document.tfstate_key.json
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/tfstate"   # 키 ID가 UUID라 사람이 읽기 좋은 형식을 위해. 참고로 삭제 대기 중인 키에도 별칭이 계속 붙어 있어서, destroy하고 바로 다시 만들면 alias/tfstate가 이미 존재한다는 오류가 날 것이다.
  target_key_id = aws_kms_key.tfstate.key_id
}

data "aws_iam_policy_document" "tfstate_key" {
  #checkov:skip=CKV_AWS_111:KMS 키 정책은 자기 키를 대상으로 하므로 Resource = "*"가 규격이다. 키 ARN을 정책 안에서 참조할 수 없다
  #checkov:skip=CKV_AWS_356:위와 같다. IAM 정책 판정 기준을 키 정책에 적용해서 나온 결과다
  #checkov:skip=CKV_AWS_109:위와 같다
  statement {
    sid       = "DelegateToAccountIAM"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]   # 키 정책은 자기 키에만 붙으므로 *가 그 키를 뜻한다

    principals {
      type        = "AWS"
      # principal을 계정 root로 두는 건 root 사용자에게 권한을 준다는 뜻이 아니고,
      # KMS 키 정책이 "이 계정의 IAM 정책을 권한 결정에 사용할 수 있다"고 문을 열어두는 느낌이다.
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      # 왜냐하면 KMS 키는 다른 AWS 리소스랑은 규칙이 다르기 때문이다.
      # KMS 키 정책 뿐만 아니라 그 다음의 IAM 정책까지 결정되어야 한다.
    }
  }
}