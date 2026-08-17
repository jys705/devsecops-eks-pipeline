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