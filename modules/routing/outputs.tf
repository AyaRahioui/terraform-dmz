output "route_table_ids" {
  value = {
    dmz  = ""
    lan  = ""
    mgmt = ""
  } # TODO M3 : références réelles
}

output "nsg_ids" {
  value = {
    dmz        = ""
    lan        = ""
    mgmt       = ""
    monitoring = ""
  } # TODO M3 : références réelles
}
