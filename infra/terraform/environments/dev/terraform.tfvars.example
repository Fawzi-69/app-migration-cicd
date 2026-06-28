# Valeurs de l'environnement DEV.
# Les noms de bucket/table proviennent du bootstrap ; ils restent hors backend
# (fournis ici uniquement pour construire les permissions du rôle CI).

env = "dev"

# Réseau (un /16 découpé en /24, 2 AZ).
vpc_cidr        = "10.10.0.0/16"
azs             = ["eu-west-3a", "eu-west-3b"]
public_subnets  = ["10.10.0.0/24", "10.10.1.0/24"]
private_subnets = ["10.10.10.0/24", "10.10.11.0/24"]

# Dev : NAT unique, peu de capacité, pas de multi-AZ.
single_nat_gateway      = true
desired_count           = 2
min_capacity            = 2
max_capacity            = 4
rds_instance_class      = "db.t4g.micro"
rds_multi_az            = false
rds_deletion_protection = false # dev : on autorise la suppression

# CI/CD : à adapter au chemin réel du projet GitLab.
gitlab_project_path = "fawzi/app-migration-cicd"
gitlab_branch       = "dev"

# Backend (créés par le bootstrap) — remplacer <suffixe-unique>.
state_bucket_name = "app-migration-cicd-tfstate-<suffixe-unique>"
lock_table_name   = "app-migration-cicd-tf-locks"
# state_kms_key_arn = "arn:aws:kms:eu-west-3:<account-id>:key/<id>"  # sortie du bootstrap
