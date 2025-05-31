# =============================================================================
# CONFIGURATION K3S GÉNÉRÉE AUTOMATIQUEMENT
# =============================================================================
# Cluster: ${cluster_name}
# Version: ${version}
# Server: ${server_ip}:${api_port}
# =============================================================================

apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://${server_ip}:${api_port}
    insecure-skip-tls-verify: true
  name: ${cluster_name}
contexts:
- context:
    cluster: ${cluster_name}
    user: default
  name: default
current-context: default
users:
- name: default
  user:
    token: # À remplir après installation K3s

# Configuration supplémentaire
%{~ if ha_enabled ~}
# Mode Haute Disponibilité activé
ha_enabled: true
%{~ endif ~}