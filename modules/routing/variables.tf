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

# ----- M3: Variables facultatives (noms du contrat M1 ci-dessus conserves) -----
variable "hosts" {
  description = "IP fixes des VMs (valeurs par defaut du README du depot)."
  type = object({
    web     = string
    app     = string
    db      = string
    bastion = string
    monitor = string
  })
  default = {
    web     = "10.10.1.4"
    app     = "10.10.2.4"
    db      = "10.10.2.5"
    bastion = "10.10.3.4"
    monitor = "10.10.4.4"
  }
}

variable "admin_source_ips" {
  description = "IPs publiques autorisees a acceder au bastion (CIDR /32). Vide = bloque."
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for ip in var.admin_source_ips : can(cidrhost(ip, 0)) && endswith(ip, "/32")
    ])
    error_message = "Utiliser des CIDR /32 valides pour les IP d'administration."
  }
}

variable "app_port" {
  description = "Port de l'API autorise depuis le reverse proxy (F02)."
  type        = number
  default     = 8080
}

variable "db_port" {
  description = "Port PostgreSQL autorise depuis l'application (F03)."
  type        = number
  default     = 5432
}

variable "monitoring_ports" {
  description = "Ports TCP de collecte, a confirmer avec M6 avant le deploiement."
  type        = list(string)
  default     = ["1514", "1515", "3100"]
}

variable "monitor_ui_port" {
  description = "Port TCP de l'interface de monitoring (F14, a confirmer avec M6)."
  type        = number
  default     = 3000
}
