# Terraform은 backend를 가장 먼저 읽는다.
# state를 어디서 가져올지 모르면 아무것도 못 하기 때문이다.
# 그래서 backend.hcl 파일을 따로 두고, terraform init할 때마다 -backend-config=backend.hcl 옵션을 붙이는 게 유일한 방법이다.
# 빠뜨리면 버킷을 못 찾아 오류가 난다.

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    key          = "infra/terraform.tfstate"   # 버킷 안에서의 경로
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true   # S3 객체를 조건부 쓰기로 만들어, 원격 파일이 이미 있으면 생성이 실패하고, 작업이 끝나면 지운다.
    # bucket과 kms_key_id는 backend.hcl에서 온다 (계정 ID를 코드에 안 적는다)
  }
}