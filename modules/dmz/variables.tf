variable "resource_group_name" {
  description = "Resource Group existant (fourni par l'environnement)."
  type        = string
}

variable "location" {
  description = "Région Azure."
  type        = string
}

variable "name_prefix" {
  description = "Préfixe de nommage (ex: dmz-dev)."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "subnet_id" {
  description = "Subnet cible, fourni par le module network."
  type        = string
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
  description = "Clé SSH PUBLIQUE (jamais la clé privée)."
  type        = string
}

variable "private_ip_address" {
  description = "IP privée statique prévue dans le plan d'adressage (null = dynamique)."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Variables ADDED by M4 (all with a default value, as the README requires)
# ---------------------------------------------------------------------------

variable "backend_ip" {
  description = "IP de vm-app (M5), vers laquelle Nginx transmet les requêtes (flux F02)."
  type        = string
  default     = "10.10.2.4"
}

variable "backend_port" {
  description = "Port de l'API sur vm-app (flux F02). À confirmer avec M5."
  type        = number
  default     = 8080
}

variable "bastion_ip" {
  description = "IP du bastion, seule source autorisée en SSH sur vm-web (flux F07)."
  type        = string
  default     = "10.10.3.4"
}
