variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "subnet_id" {
  description = "Subnet MGMT."
  type        = string
}

variable "vm_size" {
  type    = string
  default = "Standard_B1s"
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
  description = "IP privée statique (null = dynamique)."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
