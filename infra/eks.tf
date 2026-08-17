# ReleaseOperator 권한 세트가 계정에 실체화한 IAM 역할을 찾는다.
# 이름의 접미어가 권한 세트를 다시 만들 때마다 바뀌므로 하드코딩할 수 없다.
data "aws_iam_roles" "release_operator" {
  name_regex  = "AWSReservedSSO_ReleaseOperator_.*"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

locals {
  cluster_name = var.project

  # 경로를 포함한 ARN을 쓴다. Access Entry는 IAM에 존재하는 ARN을 검증하므로
  # /aws-reserved/sso.amazonaws.com/ap-northeast-2/ 를 빼면 없는 역할이 된다.
  # aws-auth ConfigMap이 경로 제거를 요구하는 것과 반대다.
  release_operator_role_arn = one(data.aws_iam_roles.release_operator.arns)
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.audit_log_retention_days
}

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = [for s in aws_subnet.private : s.id]
    endpoint_private_access = true
    endpoint_public_access  = false # 기본값은 true이나, 비공개 클러스터를 위해 false.
    security_group_ids      = [aws_security_group.control_plane.id]
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  # 감사 활성화
  # 다섯 종류를 다 킬 수는 있는데, api와 authenticator가 매우 많은 양을 쏟아내게 된다.
  enabled_cluster_log_types = ["audit"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]

  tags = {
    Name = local.cluster_name
  }
}

resource "aws_eks_access_entry" "release_operator" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.release_operator_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "release_operator" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = local.release_operator_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.release_operator]
}