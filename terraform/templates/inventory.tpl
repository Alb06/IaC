# =============================================================================
# INVENTAIRE ANSIBLE GÉNÉRÉ AUTOMATIQUEMENT PAR TERRAFORM
# =============================================================================
# ⚠️  NE PAS MODIFIER CE FICHIER MANUELLEMENT
# Ce fichier est généré automatiquement par Terraform
# Source: terraform/templates/inventory.tpl
# Dernière génération: ${timestamp()}
# =============================================================================

# Serveur de l'environnement ${environment}
[${environment}_servers]
${server.name} ansible_host=${server.ip} ansible_user=${ansible_config.user} ansible_ssh_private_key_file=${ansible_config.ssh_key_path}

# Configuration globale pour ${environment}
[${environment}_servers:vars]
ansible_python_interpreter=${ansible_config.python_interpreter}
ansible_host_key_checking=${ansible_config.host_key_checking}
ansible_gather_facts=${ansible_config.gather_facts}
environment=${environment}
server_fqdn=${server.fqdn}

# Variables spécifiques à l'environnement
%{ if environment == "dev" ~}
deployment_type=development
log_level=debug
enable_debug_tools=true
%{ else ~}
deployment_type=production
log_level=info
enable_debug_tools=false
%{ endif ~}

# Configuration réseau
[${environment}_servers:vars]
network_subnet=${network.subnet}
network_gateway=${network.gateway}
domain_name=${network.domain}
dns_primary=${network.dns_primary}
dns_secondary=${network.dns_secondary}

# Ports des services
ssh_port=${ports.ssh}
http_port=${ports.http}
https_port=${ports.https}
k3s_api_port=${ports.k3s_api}
postgresql_port=${ports.postgresql}

# Versions des outils
k3s_version=${versions.k3s}
helm_version=${versions.helm}
docker_version=${versions.docker}
postgresql_version=${versions.postgresql}

# Configuration Docker
docker_network_name=${docker.network_name}
docker_volumes_path=${docker.volumes_path}

# Configuration Kubernetes
k3s_cluster_name=${kubernetes.cluster_name}
k3s_storage_class=${kubernetes.storage_class}
default_namespace=${kubernetes.namespace_default}
monitoring_namespace=${kubernetes.namespace_monitoring}

# Groupes fonctionnels
[k3s_masters]
${server.name}

[docker_hosts]
${server.name}

[postgresql_servers]
${server.name}

[monitoring_servers]
${server.name}

# Tous les serveurs de cet environnement
[${environment}:children]
${environment}_servers

# Groupes globaux (tous environnements)
[homelab_servers:children]
${environment}_servers