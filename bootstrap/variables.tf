variable "subscription_id" { type = string }
variable "location" {
  type    = string
  default = "canadacentral"
}
variable "storage_account_name" {
  type        = string
  description = "Nombre global único: 3-24 minúsculas o números."
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Nombre no válido para Storage."
  }
}
variable "operator_ip" {
  type        = string
  description = "IPv4 pública del operador SIN /32 (formato de las reglas de Storage)."
  validation {
    condition     = can(cidrnetmask("${var.operator_ip}/32"))
    error_message = "Usa una IPv4 sin máscara."
  }
}
