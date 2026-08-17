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

# 워커 노드는 1대이다.
# 만약 2대 이상에서는 노드 SG 인바운드가 0인 환경에서 노드 간 통신이 전부 막히고, 파드가 다른 노드의 CoreDNS로 보내는 DNS 질의가 실패한다. 
# 같은 노드 안의 파드 사이 통신은 ENI를 나가지 않아 SG 평가를 받지 않으므로 1대에서는 문제가 없다.
# 서브넷은 두 AZ에 그대로 지정하고 노드만 1대를 띄운다.
variable "node_desired_size" {
  description = "워커 노드 수"
  type        = number
  default     = 1
}

variable "audit_log_retention_days" {
  description = "EKS audit 로그 보관 기간"
  type        = number
  default     = 1
}