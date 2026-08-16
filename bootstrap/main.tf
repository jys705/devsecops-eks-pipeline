terraform {
  # 1.11 미만에서는 use_lockfile이 실험 기능이라 backend가 다르게 동작한다.
  # 버전을 명시하지 않으면 낮은 버전으로 apply했을 때 잠금 없이 state가 덮어써진다.
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"          # 6.x는 받고 7.0은 안 받는다
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"

  # 이 provider로 만드는 모든 리소스에 자동으로 붙게 된다.
  # 리소스마다 tags를 쓰지 않아도 되면서, destroy 후 잔여 확인에 쓴다.
  # Resource Groups의 태그 편집기에서 Project = p2-devsecops로 조회하면 남은 게 실시간으로 나오는데, 태그가 없으면 그 조회가 안 된다.
  default_tags {
    tags = {
      Project   = "p2-devsecops"
      ManagedBy = "terraform"
      Root      = "bootstrap"   # infra/와 구분하는 값이다.
    }
  }
}

# 지금 이 자격 증명이 누구인지 AWS에 물어본다. 만들지 않고 읽기만 한다.
# data와 resource를 구분하는게 Terraform의 기본 구문이다.
# data는 읽기만 하고 state에 관리 대상으로 안 들어간다. 
# resource는 만들고 관리하고 destroy 때 지운다.
data "aws_caller_identity" "current" {}

locals {
  # locals는 계산된 값에 이름을 붙이는 것이라 버킷 이름처럼 규칙이 정해진 값에 어울린다.
  # S3 버킷 이름은 전 세계에서 유일해야 하므로 계정 ID를 붙인다.
  # 계정 ID를 코드에 직접 쓰지 않는 게 해당 실습용 Public 저장소에 맞으며 하드코딩을 안하는 방식이다.
  bucket_name = "tfstate-${data.aws_caller_identity.current.account_id}-apne2"
}