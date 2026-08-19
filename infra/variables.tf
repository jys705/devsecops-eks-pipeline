variable "project" {
  description = "리소스 이름 접두어"
  type        = string
  default     = "p2-devsecops"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "AZ 하나당 하나. 2개"
  type        = list(string)
  default     = ["10.0.0.0/20", "10.0.16.0/20"]
}

variable "node_instance_type" {
  description = "워커 노드 인스턴스 타입"
  type        = string
  default     = "t3.medium"
}

# 워커 노드는 2대이다.
# 노드 SG 인바운드가 0인 환경에서 만약 워커 노드가 2대 이상라면 노드 간 통신이 전부 막히고, 파드가 다른 노드의 CoreDNS로 보내는 DNS 질의가 실패한다. 
variable "node_desired_size" {
  description = "워커 노드 수"
  type        = number
  default     = 2
}

variable "audit_log_retention_days" {
  description = "EKS audit 로그 보관 기간"
  type        = number
  default     = 1
}

# audit_log_retention_days를 재사용하지 않은 이유는 두 로그의 수명 판단이 다르기 때문이다. 
# audit 로그는 클러스터 API 요청을 남기고 Flow Logs는 패킷 헤더를 남긴다. 
# 보존 기간을 한 변수로 묶어버리면, 나중에 한쪽만 늘릴 때 다른 쪽이 따라서 늘어난다.
variable "flow_log_retention_days" {
  description = "VPC Flow Logs 로그 그룹 보존 기간"
  type        = number
  default     = 1
}

variable "github_repository" {
  description = "OIDC trust policy의 sub 조건에 들어가는 저장소 식별자"
  type        = string
  default     = "jys705/devsecops-eks-pipeline"
}

variable "github_default_branch" {
  description = "push 이벤트에서 신뢰할 브랜치"
  type        = string
  default     = "main"
}