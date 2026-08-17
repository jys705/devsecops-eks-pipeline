# EC2를 만든다.
# 노드그룹은 EC2 Auto Scaling 그룹을 자기 이름으로 만들어 인스턴스를 띄운다.

resource "aws_launch_template" "node" {
  name        = "${var.project}-node"
  description = "EKS worker nodes: IMDSv2 required, hop limit 1"

  vpc_security_group_ids = [aws_security_group.node.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # 기본값은 optional (IMDSv1 허용)
    http_put_response_hop_limit = 1          # 기본값은 사실 1이다. 그런데도 명시하는 이유는 EKS가 자동 생성하는 시작 템플릿은 이 값을 2로 둔다. 
  }

  # EBS 암호화를 위해
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project}-node"
    }
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project}-node"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [for s in aws_subnet.private : s.id]

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_desired_size
    max_size     = var.node_desired_size + 1
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.node,
    aws_vpc_security_group_ingress_rule.control_plane_https_from_node,
    aws_vpc_security_group_ingress_rule.node_kubelet_from_control_plane,
    aws_vpc_security_group_ingress_rule.node_all_from_node,
    aws_vpc_endpoint.interface,
    aws_vpc_endpoint.s3,
  ]

  tags = {
    Name = "${var.project}-node"
  }
}