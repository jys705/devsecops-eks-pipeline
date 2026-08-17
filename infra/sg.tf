# 노드 SG에 인바운드 규칙을 하나도 안 쓴다. SG는 규칙을 안 쓰면 전부 거부이다. 
resource "aws_security_group" "node" {
  name        = "${var.project}-node"
  description = "EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project}-node"
  }
}

# 노드 아웃바운드를 0.0.0.0/0으로 연다. 
# 443과 53만 열어 더 좁힐 수 있지만, 이 VPC에는 IGW도 NAT도 없어서 0.0.0.0/0이 실제로 닿는 범위는 VPC 안과 엔드포인트뿐이다. 
# 격리를 만드는 건 이 규칙이 아니라 인터넷 게이트웨이의 부재와 엔드포인트 SG이다. 
# 여기서 포트를 좁히면 노드가 조인 안 될 때 원인 후보가 하나 늘어나는데, 얻는 보안은 없다.
resource "aws_vpc_security_group_egress_rule" "node_all" {
  security_group_id = aws_security_group.node.id
  description       = "All outbound within VPC (no internet path exists)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# 엔드포인트 SG에 아웃바운드 규칙이 하나도 없는 게 정상. 
# 그래서 노드 SG에는 아웃바운드를 명시적으로 다시 써 준 것이고, 엔드포인트 SG에는 안 쓴다. 
# 콘솔에서 SG를 만들면 AWS가 전체 허용 아웃바운드를 자동으로 붙인다. Terraform의 aws_security_group은 생성 직후 그 기본 규칙을 제거한다.
# 즉, SG의 상태 추적형을 활용해 443으로 들어온 연결의 응답은 아웃바운드 규칙 없이 나간다.
resource "aws_security_group" "endpoint" {
  name        = "${var.project}-vpce"
  description = "Interface VPC endpoints"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project}-vpce"
  }
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_https_from_node" {
  security_group_id            = aws_security_group.endpoint.id
  description                  = "HTTPS from worker nodes"
  referenced_security_group_id = aws_security_group.node.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# 컨트롤 플레인 ENI에 붙는 SG. 시작 템플릿에 노드 SG를 지정하면 EKS가 클러스터 SG를
# 노드에 붙이지 않으므로, 클러스터 SG의 Self 규칙에 노드가 들어가지 않는다.
# 이 규칙이 없으면 노드가 API 서버 443에 닿지 못해 조인 자체가 실패한다.

# EKS가 만드는 eks-cluster-sg-p2-devsecops-*를 직접 고치는 방법도 있다. 
# 다만, 안 하는 이유는 그게 AWS 관리 리소스이고, 클러스터를 업데이트하면 EKS가 기본 규칙을 되살린다. 
# SG를 하나 더 붙이면 같은 ENI에서 규칙이 합쳐지므로 결과는 같고, 소유권이 코드에 남는다.
resource "aws_security_group" "control_plane" {
  name        = "${var.project}-control-plane"
  description = "EKS control plane ENIs"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project}-control-plane"
  }
}

resource "aws_vpc_security_group_ingress_rule" "control_plane_https_from_node" {
  security_group_id            = aws_security_group.control_plane.id
  description                  = "Kubelet and pods to Kubernetes API"
  referenced_security_group_id = aws_security_group.node.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}