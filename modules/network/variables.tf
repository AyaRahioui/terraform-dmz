variable "resource_group_name" {
  description = "Resource Group existant (créé par l'environnement, pas par le module)."
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

variable "address_space" {
  description = "CIDR du VNet."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "subnets" {
  description = "Map nom => CIDR. Les clés firewall, dmz, lan, mgmt, monitoring sont attendues par les autres modules."
  type        = map(string)
  default = {
    firewall   = "10.10.0.0/24"
    dmz        = "10.10.1.0/24"
    lan        = "10.10.2.0/24"
    mgmt       = "10.10.3.0/24"
    monitoring = "10.10.4.0/24"
  }
}

variable "tags" {
  description = "Tags appliqués aux ressources."
  type        = map(string)
  default     = {}
}
