variable "zone" {
  description = "The DNS zone resource"
}

variable "records" {
  type        = any
  description = "List of maps to input values for the cloudflare_record resource"
}

variable "allow_overwrite" {
  type        = bool
  default     = false
  description = "Allow overwriting of existing records"
}