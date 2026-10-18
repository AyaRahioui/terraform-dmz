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

variable "app_private_ip_address" {
  type    = string
  default = "10.10.2.4"
}

variable "db_private_ip_address" {
  type    = string
  default = "10.10.2.5"
}

variable "dmz_ip_address" {
  type    = string
  default = "10.10.1.4"
}

variable "bastion_ip_address" {
  type    = string
  default = "10.10.3.4"
}