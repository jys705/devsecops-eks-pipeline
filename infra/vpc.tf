data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  private_subnets = zipmap(
    slice(data.aws_availability_zones.available.names, 0, 2),
    var.private_subnet_cidrs
  )
}


resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # 둘이 함께 켜져 있어야 인터페이스 엔드포인트의 Private DNS가 동작하고,
  # EKS가 만드는 프라이빗 호스팅 영역도 같은 조건을 요구한다.
  # enable_dns_support는 기본값이 true지만 짝을 이루는 값이라 함께 명시한다.
  # enable_dns_hostnames는 기본값이 false다.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-vpc"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project}-private-${each.key}"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-default-locked"
  }
}