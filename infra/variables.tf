variable "subscription_id" {
  description = "Suscripción de Azure que financiará el laboratorio."
  type        = string
}

variable "name" {
  description = "Prefijo único; también forma parte del nombre global de Key Vault."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{5,17}$", var.name))
    error_message = "Usa de 6 a 18 letras minúsculas o números, comenzando por una letra."
  }
}

variable "location" {
  type        = string
  description = "Región con cuota y soporte para las zonas y SKU elegidas."
  default     = "canadacentral"
}

variable "operator_ip" {
  type        = string
  description = "IPv4 pública del operador en CIDR /32; permite administrar Key Vault."
  validation {
    condition     = can(cidrnetmask(var.operator_ip)) && endswith(var.operator_ip, "/32")
    error_message = "Proporciona una sola IPv4 con máscara /32."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "Clave pública SSH requerida por Azure. No se abre el puerto SSH."
}

variable "alert_email" {
  type        = string
  description = "Correo que recibirá las alertas y notificaciones de autoscale."
}

variable "secret_expiration_date" {
  type        = string
  description = "Expiración futura del secreto en UTC, por ejemplo 2027-02-01T00:00:00Z."
  validation {
    condition     = can(formatdate("YYYY", var.secret_expiration_date))
    error_message = "Usa una fecha RFC3339."
  }
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2pls_v2"
  description = "ARM64 con 2 vCPU y 4 GiB; verificar disponibilidad y créditos CPU antes de medir."
}

variable "zones" {
  type        = list(string)
  default     = ["1", "3"]
  description = "Al menos dos zonas disponibles para el SKU en la región elegida."
  validation {
    condition     = length(distinct(var.zones)) >= 2 && alltrue([for zone in var.zones : contains(["1", "2", "3"], zone)])
    error_message = "Selecciona al menos dos zonas distintas entre 1, 2 y 3."
  }
}

variable "image_sku" {
  type        = string
  default     = "server-arm64"
  description = "server-arm64 para B2pls_v2; server para máquinas x64. Debe coincidir con el SKU."
}

variable "image_version" {
  type        = string
  description = "Versión exacta de Ubuntu 24.04 Gen2 disponible en la región; no usar latest."
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.image_version))
    error_message = "Fija una versión numérica de la imagen para que sea reproducible."
  }
}

variable "max_instances" {
  type        = number
  default     = 3
  description = "Máximo limitado por la cuota regional y de familia de vCPU."
  validation {
    condition     = var.max_instances >= 2 && var.max_instances <= 10 && floor(var.max_instances) == var.max_instances
    error_message = "Usa un entero de 2 a 10; comprueba la cuota antes del despliegue."
  }
}

variable "capacity_test" {
  type        = bool
  default     = false
  description = "Solo para P1: fija min/default/max en 1. Restaurar false antes de las demás pruebas."
}
