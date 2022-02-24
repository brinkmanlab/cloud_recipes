locals {
  records = try(values(var.records), var.records) # Convert to list if mapping provided
  acme_candidates = [for r in local.records : r if r["type"] == "CNAME" &&
    lookup(r, "proxied", false) == false &&
    (
      substr(r["value"], -length(".sfu.brinkmanlab.ca"), -1) == ".sfu.brinkmanlab.ca" ||
      substr(r["value"], -length(".sfu.ca"), -1) == ".sfu.ca"
    )
  ]
  acme        = [for r in local.acme_candidates : join(".", concat(["_acme-challenge"], r["name"] == var.zone.zone ? [] : slice(split(".", r["name"]), 1, length(split(".", r["name"])))))]
  acme_target = "_acme-challenge.sfu.brinkmanlab.ca"
}

resource "cloudflare_record" "record" {
  for_each        = var.records
  zone_id         = var.zone.id
  allow_overwrite = var.allow_overwrite
  type            = each.value["type"]
  name            = each.value["name"]
  value           = lookup(each.value, "value", null)
  dynamic "data" {
    for_each = compact([lookup(each.value, "data", null)])
    content {
      service  = lookup(data.value, "service", null)
      proto    = lookup(data.value, "proto", null)
      name     = lookup(data.value, "name", null)
      priority = lookup(data.value, "priority", null)
      weight   = lookup(data.value, "weight", null)
      port     = lookup(data.value, "port", null)
      target   = lookup(data.value, "target", null)
      content  = lookup(data.value, "content", null)
      # TODO add more possible keys, they are not documented
    }
  }
  ttl      = lookup(each.value, "ttl", 1)
  priority = lookup(each.value, "priority", null)
  proxied  = lookup(each.value, "proxied", false)
}

# If CNAME target is *.sfu.brinkmanlab.ca or *.sfu.ca, create an additional _acme-challenge record
# value = "foo.ca" -> _acme-challenge
# value = "subdomain" -> _acme-challenge
# value = "subdomain.sub2" -> _acme-challenge.sub2
resource "cloudflare_record" "acme_SFU_alias" {
  for_each = toset([for r in local.acme : r if r != local.acme_target && join(".", [r, var.zone.zone]) != local.acme_target])
  zone_id  = var.zone.id
  name     = each.value
  value    = local.acme_target
  type     = "CNAME"
  ttl      = 1
  proxied  = false
}
