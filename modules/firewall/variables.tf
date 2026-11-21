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

  validation {
    condition     = var.private_ip_address == null || can(cidrnetmask("${var.private_ip_address}/32"))
    error_message = "private_ip_address doit être une IPv4 valide (ex: 10.10.0.4) ou null."
  }
}

# ---------------------------------------------------------------------------
# Variables ajoutées par M2 (toutes avec une valeur par défaut = plan figé)
# ---------------------------------------------------------------------------

variable "enable_trust_nic" {
  description = "Crée la 2e NIC (trust, eth1) qui porte le trafic vers les subnets internes. false = NVA mono-NIC."
  type        = bool
  default     = true
}

variable "trust_subnet_id" {
  description = "Subnet de la NIC trust (null = même subnet que subnet_id)."
  type        = string
  default     = null
}

variable "trust_subnet_cidr" {
  description = "CIDR du subnet de la NIC trust (null = firewall_subnet_cidr). Sert à calculer la passerelle Azure (.1)."
  type        = string
  default     = null
}

variable "trust_private_ip_address" {
  description = "IP privée statique de la NIC trust (null = dynamique)."
  type        = string
  default     = null

  validation {
    condition     = var.trust_private_ip_address == null || can(cidrnetmask("${var.trust_private_ip_address}/32"))
    error_message = "trust_private_ip_address doit être une IPv4 valide ou null."
  }
}

variable "allow_extension_operations" {
  description = "Autorise les extensions de VM Azure (désactivé par défaut : surface d'attaque réduite)."
  type        = bool
  default     = false
}

# --- Plan d'adressage (utilisé pour générer nftables.conf) ---

variable "vnet_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "firewall_subnet_cidr" {
  description = "CIDR du subnet firewall (sert à calculer la passerelle Azure .1 pour eth1)."
  type        = string
  default     = "10.10.0.0/24"
}

variable "dmz_subnet_cidr" {
  type    = string
  default = "10.10.1.0/24"
}

variable "lan_subnet_cidr" {
  type    = string
  default = "10.10.2.0/24"
}

variable "mgmt_subnet_cidr" {
  description = "Subnet du bastion : SEULE source autorisée en SSH vers la NVA (anti-lockout)."
  type        = string
  default     = "10.10.3.0/24"
}

variable "monitoring_subnet_cidr" {
  type    = string
  default = "10.10.4.0/24"
}

variable "web_private_ip" {
  description = "vm-web (cible du DNAT)."
  type        = string
  default     = "10.10.1.4"
}

variable "app_private_ip" {
  type    = string
  default = "10.10.2.4"
}

variable "monitoring_private_ip" {
  type    = string
  default = "10.10.4.4"
}

# --- Ports / flux autorisés ---

variable "dnat_tcp_ports" {
  description = "Ports publiés sur l'IP publique de la NVA et redirigés (DNAT) vers vm-web."
  type        = list(number)
  default     = [80, 443]
}

variable "app_tcp_ports" {
  description = "Ports de vm-app joignables depuis vm-web (DMZ -> LAN)."
  type        = list(number)
  default     = [8080]
}

variable "monitoring_scrape_tcp_ports" {
  description = "Ports que vm-monitor peut interroger sur toutes les VMs (ex: node_exporter)."
  type        = list(number)
  default     = [9100]
}

variable "monitoring_ingest_tcp_ports" {
  description = "Ports de vm-monitor joignables par toutes les VMs (ex: Loki)."
  type        = list(number)
  default     = [3100]
}

variable "egress_tcp_ports" {
  description = "Ports TCP sortants vers Internet autorisés depuis le VNet (mises à jour apt...)."
  type        = list(number)
  default     = [80, 443]
}

variable "egress_udp_ports" {
  description = "Ports UDP sortants vers Internet autorisés depuis le VNet."
  type        = list(number)
  default     = [53, 123]
}
