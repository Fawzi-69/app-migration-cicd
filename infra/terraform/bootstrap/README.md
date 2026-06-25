# Bootstrap — backend distant & OIDC

Cette racine crée les ressources socle, **une seule fois**, avec un state **local**
(elle ne peut pas utiliser le backend S3 qu'elle est en train de créer) :

| Ressource | Rôle |
|-----------|------|
| Bucket S3 (versionné, chiffré KMS, accès public bloqué, TLS obligatoire) | Stockage des states Terraform des environnements |
| Table DynamoDB (`LockID`, PITR, chiffrée) | Verrou anti-applies concurrents |
| Fournisseur OIDC GitLab | Authentification CI → AWS sans clé statique |
| Clé KMS + alias | Chiffrement des states |

## Application (manuelle, hors CI)

> Le nom du bucket S3 doit être **globalement unique**.

```bash
terraform init
terraform apply \
  -var "state_bucket_name=app-migration-cicd-tfstate-<suffixe-unique>"
```

Les sorties (`state_bucket_name`, `lock_table_name`, `gitlab_oidc_provider_arn`)
alimentent ensuite les `-backend-config` des environnements et la variable
`oidc_provider_arn` du module `iam_oidc_role`.

> Tant que le déploiement réel n'est pas demandé, on se limite à la validation
> statique : `terraform init -backend=false`, `validate`, `tflint`, `checkov`.
> **Aucun `apply` n'est lancé.**
