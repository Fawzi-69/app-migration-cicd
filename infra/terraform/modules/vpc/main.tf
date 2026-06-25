# ---------------------------------------------------------------------------
# Module VPC : réseau multi-AZ avec sous-réseaux publics (ALB) et privés
# (tâches Fargate, RDS), NAT pour l'accès sortant, et VPC Flow Logs.
# ---------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.name }
}

# --- Passerelle Internet (trafic entrant/sortant des sous-réseaux publics) --
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

# --- Sous-réseaux publics ---------------------------------------------------
resource "aws_subnet" "public" {
  count             = length(var.public_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.public_subnets[count.index]
  availability_zone = var.azs[count.index]

  # Pas d'IP publique automatique : seul l'ALB est exposé, via sa propre IP.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-public-${var.azs[count.index]}"
    Tier = "public"
  }
}

# --- Sous-réseaux privés ----------------------------------------------------
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.name}-private-${var.azs[count.index]}"
    Tier = "private"
  }
}

# --- NAT Gateway(s) ---------------------------------------------------------
# Nombre de NAT : 1 (partagée) ou autant que d'AZ (haute dispo).
locals {
  nat_count = var.single_nat_gateway ? 1 : length(var.public_subnets)
}

resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"
  tags   = { Name = "${var.name}-nat-eip-${count.index}" }
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "${var.name}-nat-${count.index}" }

  depends_on = [aws_internet_gateway.this]
}

# --- Table de routage publique ---------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public-rt" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Tables de routage privées (une par NAT) --------------------------------
resource "aws_route_table" "private" {
  count  = local.nat_count
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private-rt-${count.index}" }
}

resource "aws_route" "private_nat" {
  count                  = local.nat_count
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count     = length(aws_subnet.private)
  subnet_id = aws_subnet.private[count.index].id
  # En mode NAT unique, toutes les privées pointent sur l'unique table.
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}

# --- Security group par défaut verrouillé -----------------------------------
# Bonne pratique : on neutralise le SG par défaut (aucune règle entrante/sortante).
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-default-locked" }
  # Aucun ingress/egress : tout est refusé par ce SG.
}

# --- VPC Flow Logs vers CloudWatch ------------------------------------------
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_logs_retention_days
  # Chiffrement géré par CloudWatch (clé AWS). Une CMK pourrait être ajoutée
  # en prod ; non requis pour des logs réseau de démonstration.
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow.arn
  iam_role_arn    = aws_iam_role.flow.arn
}

resource "aws_iam_role" "flow" {
  name               = "${var.name}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_assume.json
}

data "aws_iam_policy_document" "flow_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "flow" {
  name   = "${var.name}-vpc-flow-logs"
  role   = aws_iam_role.flow.id
  policy = data.aws_iam_policy_document.flow_permissions.json
}

data "aws_iam_policy_document" "flow_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    # Restreint au groupe de logs de cette VPC (et ses flux).
    resources = ["${aws_cloudwatch_log_group.flow.arn}:*"]
  }
}
