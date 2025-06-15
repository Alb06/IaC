#!/bin/bash
# =============================================================================
# SSH-SETUP.SH - Configuration SSH Standardisée
# =============================================================================
# Description : Configuration SSH pour accès GitHub et serveurs distants
# Usage       : ./ssh-setup.sh [type]
# Exemple     : ./ssh-setup.sh github
#               ./ssh-setup.sh server
# Auteur      : Infrastructure Team
# Version     : 1.0.0
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SSH_TYPE="${1:-github}"
readonly SSH_DIR="$HOME/.ssh"
readonly KNOWN_HOSTS_FILE="$SSH_DIR/known_hosts"

# =============================================================================
# FONCTIONS DE CONFIGURATION SSH
# =============================================================================

install_ssh_dependencies() {
    log_step "Installation des dépendances SSH..."
    
    local packages=("git" "openssh" "ca-certificates")
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

setup_ssh_directory() {
    log_step "Configuration du répertoire SSH..."
    
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    
    # Création du fichier known_hosts si inexistant
    touch "$KNOWN_HOSTS_FILE"
    chmod 644 "$KNOWN_HOSTS_FILE"
    
    log_success "Répertoire SSH configuré: $SSH_DIR"
}

setup_github_ssh() {
    print_header "Configuration SSH pour GitHub"
    
    validate_required_var "SSH_PRIVATE_KEY"
    
    local key_file="$SSH_DIR/id_ed25519"
    
    log_step "Installation de la clé privée GitHub..."
    echo "$SSH_PRIVATE_KEY" > "$key_file"
    chmod 600 "$key_file"
    
    log_step "Ajout de github.com aux known_hosts..."
    ssh-keyscan github.com >> "$KNOWN_HOSTS_FILE"
    
    # Suppression des doublons dans known_hosts
    sort -u "$KNOWN_HOSTS_FILE" -o "$KNOWN_HOSTS_FILE"
    
    log_step "Test de la connexion GitHub..."
    if ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"; then
        log_success "Connexion GitHub SSH configurée avec succès"
    else
        log_warning "Test de connexion GitHub non concluant (peut être normal)"
    fi
}

setup_server_ssh() {
    print_header "Configuration SSH pour Serveurs"
    
    validate_required_var "SSH_PRIVATE_KEY"
    
    local key_file="$SSH_DIR/id_rsa"
    
    log_step "Installation de la clé privée serveur..."
    echo "$SSH_PRIVATE_KEY" > "$key_file"
    chmod 600 "$key_file"
    
    # Configuration pour les serveurs Ansible
    if [[ -n "${ANSIBLE_HOST:-}" ]]; then
        log_step "Ajout du serveur Ansible aux known_hosts..."
        ssh-keyscan -H "$ANSIBLE_HOST" >> "$KNOWN_HOSTS_FILE" 2>/dev/null || {
            log_warning "Impossible de scanner le serveur: $ANSIBLE_HOST"
        }
    fi
    
    log_success "Configuration SSH serveur terminée"
}

setup_ssh_config() {
    local config_file="$SSH_DIR/config"
    
    log_step "Création de la configuration SSH..."
    
    cat > "$config_file" << 'EOF'
# Configuration SSH générée automatiquement
# Ne pas modifier manuellement

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile ~/.ssh/known_hosts

Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ConnectTimeout 10
    StrictHostKeyChecking no
EOF
    
    chmod 600 "$config_file"
    
    log_success "Configuration SSH créée: $config_file"
}

validate_ssh_setup() {
    log_step "Validation de la configuration SSH..."
    
    # Vérification des permissions
    local ssh_perms
    ssh_perms=$(stat -c %a "$SSH_DIR")
    if [[ "$ssh_perms" == "700" ]]; then
        log_success "Permissions répertoire SSH correctes: $ssh_perms"
    else
        log_warning "Permissions répertoire SSH: $ssh_perms (attendu: 700)"
    fi
    
    # Vérification des clés
    local key_files
    mapfile -t key_files < <(find "$SSH_DIR" -name "id_*" -type f)
    
    for key_file in "${key_files[@]}"; do
        local key_perms
        key_perms=$(stat -c %a "$key_file")
        if [[ "$key_perms" == "600" ]]; then
            log_success "Permissions clé SSH correctes: $(basename "$key_file") ($key_perms)"
        else
            log_warning "Permissions clé SSH: $(basename "$key_file") ($key_perms, attendu: 600)"
        fi
    done
    
    # Test des known_hosts
    if [[ -s "$KNOWN_HOSTS_FILE" ]]; then
        local hosts_count
        hosts_count=$(wc -l < "$KNOWN_HOSTS_FILE")
        log_success "Known hosts configurés: $hosts_count entrées"
    else
        log_warning "Fichier known_hosts vide"
    fi
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    print_header "Configuration SSH - Type: $SSH_TYPE"
    
    install_ssh_dependencies
    setup_ssh_directory
    
    case "$SSH_TYPE" in
        "github")
            setup_github_ssh
            ;;
        "server")
            setup_server_ssh
            ;;
        "both")
            setup_github_ssh
            setup_server_ssh
            ;;
        *)
            log_error "Type SSH non supporté: $SSH_TYPE"
            log_info "Types disponibles: github, server, both"
            return 1
            ;;
    esac
    
    setup_ssh_config
    validate_ssh_setup
    
    print_summary "Configuration SSH Terminée" \
        "Type: $SSH_TYPE" \
        "Répertoire: $SSH_DIR" \
        "Configuration: $SSH_DIR/config" \
        "Known hosts: $KNOWN_HOSTS_FILE"
    
    log_success "✅ Configuration SSH terminée avec succès"
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi