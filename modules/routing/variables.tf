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

variable "vnet_name" {
  type = string
}

variable "subnet_ids" {
  description = "Map nom => ID : firewall, dmz, lan, mgmt, monitoring."
  type        = map(string)
}

variable "subnet_cidrs" {
  description = "Map nom => CIDR : firewall, dmz, lan, mgmt, monitoring."
  type        = map(string)
}

variable "nva_private_ip" {
  description = "IP privée de la NVA (next hop des UDR)."
  type        = string
}
