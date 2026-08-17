data "aws_iam_policy_document" "eks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# 정책 4개 중 셋은 EKS가 요구하는 최소이고 하나는 이 프로젝트의 판단이다. 
# AmazonEKSWorkerNodePolicy는 kubelet이 노드 자신을 조회하는 권한, 
# AmazonEKS_CNI_Policy는 VPC CNI가 파드에 IP를 붙이는 권한, 
# AmazonSSMManagedInstanceCore는 Session Manager 접속이다. 
# 셋 중 하나라도 빠지면 노드가 NotReady로 남거나 SSM 목록에 안 나타난다.
# 마지막으로, AmazonEC2ContainerRegistryReadOnly에서 AmazonEC2ContainerRegistryPullOnly로 바꿨다.
# EKS Auto Mode의 기본 노드 역할이 이 정책을 쓰고, AWS가 노드 역할 권장값으로 바꿨다.

resource "aws_iam_role" "cluster" {
  name               = "${var.project}-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.project}-node"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}