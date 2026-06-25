# Configuration tflint — appliquée récursivement (tflint --recursive).
# Plugin AWS : détecte les attributs invalides, types d'instances inexistants, etc.

config {
  call_module_type = "local"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.44.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Convention de nommage des ressources en snake_case.
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Chaque variable et output doit être documenté (description obligatoire).
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

# Versions de providers épinglées.
rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}
