variable "subscription_id" {
  type = string
}

variable "location" {
  type    = string
  default = "germanywestcentral"
}

variable "name_prefix" {
  type    = string
  default = "dmz-dev"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
  description = "Clé SSH publique commune de déploiement."
  type        = string
}

variable "tags" {
  type = map(string)
  default = {
    project = "dmz"
    env     = "dev"
  }
}
