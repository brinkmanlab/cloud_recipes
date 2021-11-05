output "storageclasses" {
  value       = kubernetes_storage_class.repos
  description = "Map of kubernetes_storage_class instances, keyed on repo key"
}