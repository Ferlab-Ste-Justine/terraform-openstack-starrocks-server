# About

This package provisions a node to be part of a StarRocks cluster on OpenStack.

# Usage

## Variables

This module takes the following variables as input:

- **name**: Name to give to the vm.

- **fqdn**: FQDN to give to the vm. Will be the hostname as well.

- **image_source**: Source of the image to provision the server on. It takes the following keys (only one of the two fields should be used, the other one should be empty):
  - **image_id**: Id of the image to associate with a vm that has local storage
  - **volume_id**: Id of a volume containing the os to associate with the vm

- **flavor_id**: Id of the vm flavor to assign to the instance. 

- **network_port**: Resource of type **openstack_networking_port_v2** to assign to the vm for network connectivity

- **server_group**: Server group to assign to the node. Should be of type **openstack_compute_servergroup_v2**.

- **keypair_name**: Name of the ssh keypair that will be used to ssh against the vm.

- **chrony**: Optional chrony configuration for when you need a more fine-grained ntp setup on your vm. It is an object with the following fields:
  - **enabled**: If set to false (the default), chrony will not be installed and the vm ntp settings will be left to default.
  - **servers**: List of ntp servers to sync from with each entry containing two properties, **url** and **options** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server)
  - **pools**: A list of ntp server pools to sync from with each entry containing two properties, **url** and **options** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool)
  - **makestep**: An object containing remedial instructions if the clock of the vm is significantly out of sync at startup. It is an object containing two properties, **threshold** and **limit** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep)

- **fluentbit**: Optional fluent-bit configuration to securely route logs to a fluentd/fluent-bit node using the forward plugin. Alternatively, configuration can be 100% dynamic by specifying the parameters of an etcd store to fetch the configuration from. It has the following keys:
  - **enabled**: If set to false (the default), fluent-bit will not be installed.
  - **starrocks_tag** Tag to assign to logs coming from StarRocks log file (`fe.log` for a FE node, otherwise *`node_type`*`.INFO`)
  - **starrocks_read_from_head** If set to true (the default), StarRocks log file will be read from its head instead of tail, when the file is being discovered for the first time
  - **node_exporter_tag** Tag to assign to logs coming from Prometheus Node Exporter systemd service
  - **metrics**: Configuration for metrics fluentbit exposes. It has the following keys:
    - **enabled**: Whether to enable the metrics or not
    - **port**: Port to expose the metrics on
  - **forward**: Configuration for the forward plugin that will talk to the external fluentd/fluent-bit node. It has the following keys:
    - **domain**: Ip or domain name of the remote fluentd node.
    - **port**: Port the remote fluentd node listens on
    - **hostname**: Unique hostname identifier for the vm
    - **shared_key**: Secret shared key with the remote fluentd node to authentify the client
    - **ca_cert**: CA certificate that signed the remote fluentd node's server certificate (used to authentify it)

- **fluentbit_dynamic_config**: Optional configuration to update fluent-bit configuration dynamically either from an etcd key prefix or a path in a git repo.
  - **enabled**: Boolean flag to indicate whether dynamic configuration is enabled at all. If set to true, configurations will be set dynamically. The default configurations can still be referenced as needed by the dynamic configuration. They are at the following paths:
    - **Global Service Configs**: /etc/fluent-bit-customization/default-config/service.conf
    - **Default Variables**: /etc/fluent-bit-customization/default-config/default-variables.conf
    - **Systemd Inputs**: /etc/fluent-bit-customization/default-config/inputs.conf
    - **Forward Output For All Inputs**: /etc/fluent-bit-customization/default-config/output-all.conf
    - **Forward Output For Default Inputs Only**: /etc/fluent-bit-customization/default-config/output-default-sources.conf
  - **source**: Indicates the source of the dynamic config. Can be either **etcd** or **git**.
  - **etcd**: Parameters to fetch fluent-bit configurations dynamically from an etcd cluster. It has the following keys:
    - **key_prefix**: Etcd key prefix to search for fluent-bit configuration
    - **endpoints**: Endpoints of the etcd cluster. Endpoints should have the format `<ip>:<port>`
    - **ca_certificate**: CA certificate against which the server certificates of the etcd cluster will be verified for authenticity
    - **client**: Client authentication. It takes the following keys:
      - **certificate**: Client tls certificate to authentify with. To be used for certificate authentication.
      - **key**: Client private tls key to authentify with. To be used for certificate authentication.
      - **username**: Client's username. To be used for username/password authentication.
      - **password**: Client's password. To be used for username/password authentication.
    - **vault_agent_secret_path**: Optional vault secret path for an optional vault agent to renew the etcd client credentials. The secret in vault is expected to have the **certificate** and **key** keys if certificate authentication is used or the **username** and **password** keys if password authentication is used.
  - **git**: Parameters to fetch fluent-bit configurations dynamically from an git repo. It has the following keys:
    - **repo**: Url of the git repository. It should have the ssh format.
    - **ref**: Git reference (usually branch) to checkout in the repository
    - **path**: Path to sync from in the git repository. If the empty string is passed, syncing will happen from the root of the repository.
    - **trusted_gpg_keys**: List of trusted gpp keys to verify the signature of the top commit. If an empty list is passed, the commit signature will not be verified.
    - **auth**: Authentication to the git server. It should have the following keys:
      - **client_ssh_key** Private client ssh key to authentication to the server.
      - **server_ssh_fingerprint**: Public ssh fingerprint of the server that will be used to authentify it.

- **vault_agent**: Parameters for the optional vault agent that will be used to manage the dynamic secrets in the vm.
  - **enabled**: If set to true, a vault agent service will be setup and will run in the vm.
  - **auth_method**: Auth method the vault agent will use to authenticate with vault. Currently, only approle is supported.
    - **config**: Configuration parameters for the auth method.
      - **role_id**: Id of the app role to us.
      - **secret_id**: Authentication secret to use the app role.
  - **vault_address**: Endpoint to use to talk to vault.
  - **vault_ca_cert**: CA certificate to use to validate vault's certificate.

- **install_dependencies**: Whether cloud-init should install external dependencies (should be set to false if you already provide an image with the external dependencies built-in). Default to **true**.

- **timezone**: Timezone to set on each node. Defaults to **America/Montreal**.

- **fqdn_patch**: Whether to apply patch to add FQDN for localhost in `/etc/hosts`, to fix communication issues with the FE leader. Defaults to **false**.

- **starrocks**: StarRocks configuration. It has the following keys:
  - **release_version**: StarRocks release version to install. Defaults to **3.4.1**.
  - **node_type**: StarRocks node type to configure, either **fe** or **be**.
  - **fe_config**: StarRocks FE-related settings (**initial_leader** + **initial_follower** + **ssl** + **iceberg_rest** + **meta_dir** that defaults to **/opt/starrocks/meta**). Only needed if **node_type** is set to **fe**.
  - **be_storage_root_path**: Starrocks BE storage root path. Defaults to **/opt/starrocks/storage**.
