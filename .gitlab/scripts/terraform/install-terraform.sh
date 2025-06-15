#!/bin/bash
# =============================================================================
# INSTALL-TERRAFORM.SH - Installation Terraform avec Cache Optimisé
# =============================================================================
# Description : Installation de Terraform avec gestion de cache pour shared runners
# Usage       : ./install-terraform.sh [version]
# Exemple     : ./install-terraform.sh 1.12.1
# Auteur      : Infrastructure Team
# Version     : 1.0.0
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly TERRAFORM_VERSION="${1:-${TF_VERSION:-1.12.1}}"
readonly TERRAFORM_CACHE_DIR="/tmp/terraform-cache-${TERRAFORM_VERSION}"
readonly TERRAFORM_DOWNLOAD_URL="https://releases.hashicorp.com/terraform"

# =============================================================================
# FONCTIONS PRINCIPALES
# =============================================================================

install_dependencies() {
    print_header "Installation des Dépendances"
    
    local packages=("curl" "unzip" "bash" "git" "openssh" "ca-certificates" "jq")
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

setup_terraform_cache() {
    log_step "Configuration du cache Terraform..."
    
    mkdir -p "$TERRAFORM_CACHE_DIR"
    
    log_info "Variables d'environnement Terraform:"
    log_info "  TF_ROOT: ${TF_ROOT:-non défini}"
    log_info "  CI_PROJECT_DIR: ${CI_PROJECT_DIR:-non défini}"
    log_info "  Cache Dir: $TERRAFORM_CACHE_DIR"
}

download_terraform() {
    local terraform_binary="$TERRAFORM_CACHE_DIR/terraform"
    
    if [[ -f "$terraform_binary" ]]; then
        log_info "♻️  Terraform trouvé dans le cache: $terraform_binary"
        return 0
    fi
    
    log_step "📥 Téléchargement de Terraform v$TERRAFORM_VERSION..."
    
    local download_url="$TERRAFORM_DOWNLOAD_URL/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    local zip_file="/tmp/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    
    retry_command 3 2 curl -SLo "$zip_file" "$download_url"
    
    log_step "📦 Extraction de Terraform..."
    unzip -o "$zip_file" -d "$TERRAFORM_CACHE_DIR/"
    chmod +x "$terraform_binary"
    
    # Nettoyage du fichier temporaire
    rm -f "$zip_file"
    
    log_success "Terraform téléchargé et mis en cache"
}

install_terraform_binary() {
    local terraform_binary="$TERRAFORM_CACHE_DIR/terraform"
    
    validate_file_exists "$terraform_binary"
    
    log_step "📋 Installation de Terraform dans le PATH..."
    cp "$terraform_binary" /usr/local/bin/terraform
    chmod +x /usr/local/bin/terraform
    
    log_success "Terraform installé dans /usr/local/bin/terraform"
}

validate_installation() {
    log_step "🔍 Validation de l'installation..."
    
    if ! command -v terraform >/dev/null 2>&1; then
        log_error "Terraform non trouvé dans le PATH"
        return 1
    fi
    
    local installed_version
    installed_version=$(terraform version | head -1 | awk '{print $2}' | sed 's/v//')
    
    log_info "Version installée: $installed_version"
    log_info "Version demandée: $TERRAFORM_VERSION"
    
    if [[ "$installed_version" == "$TERRAFORM_VERSION" ]]; then
        log_success "Version Terraform validée"
    else
        log_warning "Version différente installée (peut être acceptable)"
    fi
    
    # Test de fonctionnement basique
    terraform version
    terraform --help >/dev/null
    
    log_success "Installation Terraform validée avec succès"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    print_header "Installation Terraform v$TERRAFORM_VERSION"
    
    validate_required_var "TERRAFORM_VERSION"
    
    install_dependencies
    setup_terraform_cache
    download_terraform
    install_terraform_binary
    validate_installation
    
    print_summary "Installation Terraform Terminée" \
        "Version: $TERRAFORM_VERSION" \
        "Cache: $TERRAFORM_CACHE_DIR" \
        "Binaire: /usr/local/bin/terraform"
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi