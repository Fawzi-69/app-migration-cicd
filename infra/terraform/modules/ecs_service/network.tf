# ---------------------------------------------------------------------------
# Groupes de sécurité : ALB (exposé) et tâches Fargate (joignables seulement
# depuis l'ALB). Le flux vers RDS est ouvert côté module rds.
# ---------------------------------------------------------------------------

# --- SG de l'ALB ------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "ALB public : entrée HTTP/HTTPS, sortie vers les tâches."
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-alb" }
}

# Entrée HTTP (80). Ouverte au public pour un ALB exposé (CIDR paramétrable).
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  count             = length(var.allowed_ingress_cidrs)
  security_group_id = aws_security_group.alb.id
  description       = "HTTP entrant"
  cidr_ipv4         = var.allowed_ingress_cidrs[count.index]
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

# Entrée HTTPS (443), uniquement si un certificat ACM est fourni.
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count             = var.certificate_arn == null ? 0 : length(var.allowed_ingress_cidrs)
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS entrant"
  cidr_ipv4         = var.allowed_ingress_cidrs[count.index]
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Sortie de l'ALB : uniquement vers le SG des tâches, sur le port conteneur.
resource "aws_vpc_security_group_egress_rule" "alb_to_tasks" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Vers les tâches Fargate"
  referenced_security_group_id = aws_security_group.tasks.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

# --- SG des tâches Fargate --------------------------------------------------
resource "aws_security_group" "tasks" {
  name        = "${var.name}-tasks"
  description = "Tâches Fargate : entrée depuis l'ALB, sortie Internet via NAT."
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-tasks" }
}

# Entrée : seulement depuis l'ALB, sur le port du conteneur.
resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "Trafic applicatif depuis l'ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
}

# Sortie : nécessaire pour tirer l'image (ECR), lire les secrets et joindre RDS.
# Restreinte au trafic HTTPS sortant (443) + le port DB est ouvert côté RDS.
resource "aws_vpc_security_group_egress_rule" "tasks_https" {
  security_group_id = aws_security_group.tasks.id
  description       = "HTTPS sortant (ECR, Secrets Manager, API AWS)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Sortie vers la base de données, restreinte au CIDR de la VPC (port DB).
# On cible le CIDR plutôt que le SG RDS pour éviter une dépendance circulaire
# entre les groupes de sécurité (RDS référence déjà ce SG en entrée).
resource "aws_vpc_security_group_egress_rule" "tasks_to_db" {
  security_group_id = aws_security_group.tasks.id
  description       = "Accès base de données dans la VPC"
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = var.db_port
  to_port           = var.db_port
}
