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