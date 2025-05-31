# =============================================================================
# FICHIER DE TEST GÉNÉRÉ AUTOMATIQUEMENT - ${environment}
# =============================================================================
# Généré le: ${timestamp}
# Environnement: ${environment}
# =============================================================================

Hello from Terraform in ${environment} environment!

## Configuration Serveur
- Nom: ${server.name}
- IP: ${server.ip}
- FQDN: ${server.fqdn}
- Description: ${server.description}

## Versions des Outils
- Terraform: ${versions.terraform}
- K3s: ${versions.k3s}
- Helm: ${versions.helm}
- Docker: ${versions.docker}

## Configuration Réseau
- Subnet: ${network.subnet}
- Gateway: ${network.gateway}
- Domain: ${network.domain}

## Timestamp de Génération
${timestamp}

# =============================================================================
# Ce fichier prouve que le module globals fonctionne correctement
# =============================================================================