# ---------------------------------------------------------------------------
# Module ECR : dépôt d'images conteneur de l'application.
# Tags immuables (traçabilité), scan de vulnérabilités au push, purge auto.
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    # KMS si une clé est fournie, sinon chiffrement AES256 géré par AWS.
    encryption_type = var.kms_key_arn == null ? "AES256" : "KMS"
    kms_key         = var.kms_key_arn
  }
}

# Purge automatique : ne garder que les N dernières images.
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Conserver les ${var.keep_last_n_images} images les plus récentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_last_n_images
      }
      action = { type = "expire" }
    }]
  })
}
