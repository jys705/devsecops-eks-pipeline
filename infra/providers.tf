provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project   = "p2-devsecops"
      ManagedBy = "terraform"
    }
  }
}