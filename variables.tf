variable "name" {
  description = "Name to give to the vm."
  type        = string
}

variable "image_source" {
  description = "Source of the vm's image"
  type = object({
    image_id = optional(string, "")
    volume_id = optional(string, "")
  })

  validation {
    condition     = var.image_source.image_id != "" || var.image_source.volume_id != ""
    error_message = "Either image_source.image_id or image_source.volume_id need to be defined."
  }
}

variable "flavor_id" {
  description = "ID of the VM flavor"
  type = string
}

variable "network_port" {
  description = "Network port to assign to the node. Should be of type openstack_networking_port_v2"
  type        = any
}

variable "server_group" {
  description = "Server group to assign to the node. Should be of type openstack_compute_servergroup_v2"
  type        = any
}

variable "keypair_name" {
  description = "Name of the keypair that will be used by admins to ssh to the node"
  type = string
}

variable "chrony" {
  description = "Chrony configuration for ntp. If enabled, chrony is installed and configured, else the default image ntp settings are kept"
  type        = object({
    enabled = bool,
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server
    servers = list(object({
      url = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool
    pools = list(object({
      url = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep
    makestep = object({
      threshold = number,
      limit = number
    })
  })
  default = {
    enabled = false
    servers = []
    pools = []
    makestep = {
      threshold = 0,
      limit = 0
    }
  }
}

variable "fluentbit" {
  description = "Fluent-bit configuration"
  sensitive = true
  type = object({
    enabled = bool
    starrocks_tag = string
    starrocks_read_from_head = optional(bool, true),
    node_exporter_tag = string
    metrics = optional(object({
      enabled = bool
      port    = number
    }), {
      enabled = false
      port = 0
    })
    forward = object({
      domain = string
      port = number
      hostname = string
      shared_key = string
      ca_cert = string
    })
  })
  default = {
    enabled = false
    starrocks_tag = ""
    starrocks_read_from_head = true
    node_exporter_tag = ""
    metrics = {
      enabled = false
      port = 0
    }
    forward = {
      domain = ""
      port = 0
      hostname = ""
      shared_key = ""
      ca_cert = ""
    }
  }
}

variable "fluentbit_dynamic_config" {
  description = "Parameters for fluent-bit dynamic config if it is enabled"
  type = object({
    enabled = bool
    source  = string
    etcd    = optional(object({
      key_prefix     = string
      endpoints      = list(string)
      ca_certificate = string
      client         = object({
        certificate = string
        key         = string
        username    = string
        password    = string
      })
      vault_agent_secret_path = optional(string, "")
    }), {
      key_prefix     = ""
      endpoints      = []
      ca_certificate = ""
      client         = {
        certificate = ""
        key         = ""
        username    = ""
        password    = ""
      }
      vault_agent_secret_path = ""
    })
    git     = optional(object({
      repo             = string
      ref              = string
      path             = string
      trusted_gpg_keys = optional(list(string), [])
      auth             = object({
        client_ssh_key         = string
        server_ssh_fingerprint = string
        client_ssh_user        = optional(string, "")
      })
    }), {
      repo             = ""
      ref              = ""
      path             = ""
      trusted_gpg_keys = []
      auth             = {
        client_ssh_key         = ""
        server_ssh_fingerprint = ""
        client_ssh_user        = ""
      }
    })
  })
  default = {
    enabled = false
    source = "etcd"
    etcd = {
      key_prefix     = ""
      endpoints      = []
      ca_certificate = ""
      client         = {
        certificate = ""
        key         = ""
        username    = ""
        password    = ""
      }
      vault_agent_secret_path = ""
    }
    git  = {
      repo             = ""
      ref              = ""
      path             = ""
      trusted_gpg_keys = []
      auth             = {
        client_ssh_key         = ""
        server_ssh_fingerprint = ""
        client_ssh_user        = ""
      }
    }
  }

  validation {
    condition     = contains(["etcd", "git"], var.fluentbit_dynamic_config.source)
    error_message = "fluentbit_dynamic_config.source must be 'etcd' or 'git'."
  }
}

variable "vault_agent" {
  type = object({
    enabled = bool
    auth_method = object({
      config = object({
        role_id   = string
        secret_id = string
      })
    })
    vault_address   = string
    vault_ca_cert   = string
  })
  default = {
    enabled = false
    auth_method = {
      config = {
        role_id   = ""
        secret_id = ""
      }
    }
    vault_address = ""
    vault_ca_cert = ""
  }
}

variable "install_dependencies" {
  description = "Whether to install all dependencies in cloud-init"
  type = bool
  default = true
}

variable "timezone" {
  description = "Timezone"
  type        = string
  default     = "America/Montreal"
}

variable "starrocks" {
  description = "Configuration for the starrocks server"
  type        = object({
    release_version = optional(string, "3.4.1"),
    node_type       = string
    fe_config       = optional(object({
      initial_leader = optional(object({
        enabled           = bool
        fe_follower_fqdns = list(string)
        be_fqdns          = list(string)
        root_password     = string
        users             = optional(list(object({
          name         = string
          password     = string
          default_role = optional(string, "public")
        })), []),
      }), {
        enabled           = false
        fe_follower_fqdns = []
        be_fqdns          = []
        root_password     = ""
        users             = []
      })
      initial_follower = optional(object({
        enabled        = bool
        fe_leader_fqdn = string
      }), {
        enabled        = false
        fe_leader_fqdn = ""
      })
      ssl = optional(object({
        enabled           = bool
        cert              = string
        key               = string
        keystore_password = string
      }), {
        enabled           = false
        cert              = ""
        key               = ""
        keystore_password = ""
      })
      iceberg_rest = optional(object({
        ca_cert  = string
        env_name = string
      }), {
        ca_cert  = ""
        env_name = ""
      })
    }), {
      initial_leader   = null
      initial_follower = null
      ssl              = null
      iceberg_rest     = null
    })
    be_storage_root_path = optional(string, "/opt/starrocks/storage")
  })

  validation {
    condition     = contains(["fe", "be"], var.starrocks.node_type)
    error_message = "starrocks.node_type must be 'fe' or 'be'."
  }

  validation {
    condition = (
      var.starrocks.node_type == "be" ||
      (
        var.starrocks.node_type == "fe" &&
        var.starrocks.fe_config != null &&
        (
          (try(var.starrocks.fe_config.initial_leader.enabled, false) && !try(var.starrocks.fe_config.initial_follower.enabled, false)) ||
          (!try(var.starrocks.fe_config.initial_leader.enabled, false) && try(var.starrocks.fe_config.initial_follower.enabled, false))
        )
      )
    )
    error_message = "When starrocks.node_type is 'fe', starrocks.fe_config must be provided with either initial_leader.enabled or initial_follower.enabled set to true."
  }
}
