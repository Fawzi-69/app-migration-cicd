terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Le bootstrap utilise volontairement un state LOCAL : il crée lui-même le
  # bucket S3 et la table DynamoDB qui serviront de backend aux environnements
  # (problème de l'œuf et de la poule). On applique cette racine une seule fois,
  # puis on conserve son state localement / en lieu sûr.
}

provider "aws" {
  region = var.aws_region

  # Tags appliqués automatiquement à toutes les ressources de cette racine.
  default_tags {
    tags = {
      Project   = var.project
      Env       = "shared"
      Owner     = var.owner
      ManagedBy = "terraform"
    }
  }
}
