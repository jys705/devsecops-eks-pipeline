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