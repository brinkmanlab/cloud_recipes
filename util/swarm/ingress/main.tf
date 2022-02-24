# https://www.haproxy.com/blog/haproxy-on-docker-swarm-load-balancing-and-dns-service-discovery/
# https://www.exavault.com/blog/haproxy-load-balancing

data "docker_network" "ingress" {
  name = "ingress"
}

# Reload config with `sudo docker kill --signal USR2 $(docker container ls --filter name=loadbalancer --quiet)` on all nodes
resource "docker_config" "haproxy" {
  name = "haproxy"
  data = base64encode(<<EOF
global
    log          fd@2 local2
    chroot       /var/lib/haproxy
    pidfile      /var/run/haproxy.pid
    maxconn      4000
    user         haproxy
    group        haproxy
    stats socket /var/lib/haproxy/stats expose-fd listeners
    master-worker
resolvers docker
    nameserver dns1 127.0.0.11:53
    resolve_retries 3
    timeout resolve 1s
    timeout retry   1s
    hold other      10s
    hold refused    10s
    hold nx         10s
    hold timeout    10s
    hold valid      10s
    hold obsolete   10s
defaults
    timeout connect 10s
    timeout client 30s
    timeout server 30s
    log global
    mode http
    option httplog
backend be_apache_service
    balance roundrobin
    server-template apache- 6 apache-Service:80 check resolvers docker init-addr libc,none
EOF
  )
}

resource "docker_service" "lb" {
  name = "loadbalancer"
  task_spec {
    container_spec {
      image = "haproxy"
      dns_config {
        nameservers = ["127.0.0.11"]
      }
      configs {
        config_name = docker_config.haproxy.name
        config_id   = docker_config.haproxy.id
        file_name   = "/usr/local/etc/haproxy"
      }
    }
    #networks = ["ingress"]
    placement {
      constraints = ["node.labels.ingress==true"]
    }
  }
  endpoint_spec {
    ports {
      name           = "http"
      target_port    = 80
      published_port = 80
      protocol       = "tcp"
      publish_mode   = "host"
    }
    ports {
      name           = "https"
      target_port    = 443
      published_port = 443
      protocol       = "tcp"
      publish_mode   = "host"
    }
  }
  mode {
    global = true
  }
  rollback_config {
    # TODO
  }
  update_config {
    # TODO
  }
}