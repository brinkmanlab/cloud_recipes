output "records" {
  value = cloudflare_record.record
}

output "acme" {
  value = cloudflare_record.acme_SFU_alias
}