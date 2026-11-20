# One small network of its own, so removing the cluster removes everything it created.
# 10.0.0.0/16 stays clear of K3s's pod (10.42.0.0/16) and service (10.43.0.0/16) ranges.

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "cycloid-academy-${var.name}" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "cycloid-academy-${var.name}" }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = { Name = "cycloid-academy-${var.name}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "cycloid-academy-${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Web ports for the apps, and the Kubernetes API for Cycloid's runners, which reach public
# addresses only. Nothing else: no SSH, no key pair.
resource "aws_security_group" "node" {
  name        = "cycloid-academy-${var.name}-node"
  description = "Academy cluster: web ports and Kubernetes API"
  vpc_id      = aws_vpc.this.id

  tags = { Name = "cycloid-academy-${var.name}-node" }
}

resource "aws_vpc_security_group_ingress_rule" "node" {
  for_each = { http = 80, https = 443, kubernetes-api = 6443 }

  security_group_id = aws_security_group.node.id
  description       = each.key
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "node" {
  security_group_id = aws_security_group.node.id
  description       = "all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# The fixed public address, known before the machine starts so K3s puts it in its certificate.
resource "aws_eip" "node" {
  domain = "vpc"

  tags = { Name = "cycloid-academy-${var.name}" }

  depends_on = [aws_internet_gateway.this]
}
