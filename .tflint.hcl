plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Désactivé tant que les modules sont des squelettes (variables pas encore utilisées).
# A RE-ACTIVER quand votre module est terminé.
rule "terraform_unused_declarations" {
  enabled = false
}
