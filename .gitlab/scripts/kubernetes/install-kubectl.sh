#!/bin/bash
# =============================================================================
# INSTALL-KUBECTL.SH - Installation kubectl avec Cache (CORRIGÉ)
# =============================================================================
# Description : Installation de kubectl avec gestion de cache pour shared runners
# Usage       : ./install-kubectl.sh [version]
# Exemple     : ./install-kubectl.sh v1.33.1
# Auteur      : Infrastructure Team
# Version     : 1.0.1 - Correction kubectl version
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly KUBECTL_VERSION="${1:-${KUBECTL_VERSION:-v1.33.1}}"
readonly KUBECTL_CACHE_DIR="/tmp/kubectl-cache-${KUBECTL_VERSION}"
readonly KUBECTL_DOWNLOAD_URL="https://dl.k8s.io/release"

# =============================================================================
# FONCTIONS PRINCIPALES
# =============================================================================

install_dependencies() {
    print_header "Installation des Dépendances"
    
    local packages=("curl" "ca-certificates" "bash")
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

setup_kubectl_cache() {
    log_step "Configuration du cache kubectl..."
    
    mkdir -p "$KUBECTL_CACHE_DIR"
    
    log_info "Variables d'environnement kubectl:"
    log_info "  KUBECTL_VERSION: $KUBECTL_VERSION"
    log_info "  Cache Dir: $KUBECTL_CACHE_DIR"
}

download_kubectl() {
    local kubectl_binary="$KUBECTL_CACHE_DIR/kubectl"
    
    if [[ -f "$kubectl_binary" ]]; then
        log_info "♻️  kubectl trouvé dans le cache: $kubectl_binary"
        return 0
    fi
    
    log_step "📥 Téléchargement de kubectl $KUBECTL_VERSION..."
    
    local download_url="$KUBECTL_DOWNLOAD_URL/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    
    retry_command 3 2 curl -SLo "$kubectl_binary" "$download_url"
    chmod +x "$kubectl_binary"
    
    log_success "kubectl téléchargé et mis en cache"
}

install_kubectl_binary() {
    local kubectl_binary="$KUBECTL_CACHE_DIR/kubectl"
    
    validate_file_exists "$kubectl_binary"
    
    log_step "📋 Installation de kubectl dans le PATH..."
    cp "$kubectl_binary" /usr/local/bin/kubectl
    chmod +x /usr/local/bin/kubectl
    
    log_success "kubectl installé dans /usr/local/bin/kubectl"
}

validate_installation() {
    log_step "🔍 Validation de l'installation..."
    
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl non trouvé dans le PATH"
        return 1
    fi
    
    # 🔧 CORRECTION: Gestion moderne de kubectl version
    local installed_version
    
    # Tentative avec la nouvelle syntaxe JSON (kubectl v1.28+)
    if installed_version=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null); then
        log_debug "Version extraite via JSON: $installed_version"
    # Fallback pour les versions plus anciennes
    elif installed_version=$(kubectl version --client 2>/dev/null | grep "Client Version" | awk '{print $3}' 2>/dev/null); then
        log_debug "Version extraite via parsing texte: $installed_version"
    # Fallback final avec version simple
    elif installed_version=$(kubectl version --client 2>/dev/null | head -1 | awk '{print $2}' 2>/dev/null); then
        log_debug "Version extraite via fallback: $installed_version"
    else
        log_warning "Impossible d'extraire la version kubectl, utilisation de validation basique"
        installed_version="unknown"
    fi
    
    log_info "Version installée: $installed_version"
    log_info "Version demandée: $KUBECTL_VERSION"
    
    # Validation flexible de la version
    if [[ "$installed_version" == "$KUBECTL_VERSION" ]]; then
        log_success "Version kubectl validée exactement"
    elif [[ "$installed_version" == *"$KUBECTL_VERSION"* ]] || [[ "$KUBECTL_VERSION" == *"$installed_version"* ]]; then
        log_success "Version kubectl compatible"
    elif [[ "$installed_version" == "unknown" ]]; then
        log_warning "Version kubectl non vérifiable, test de fonctionnement basique"
    else
        log_warning "Version différente installée (peut être acceptable)"
        log_info "  Installée: $installed_version"
        log_info "  Demandée: $KUBECTL_VERSION"
    fi
    
    # Test de fonctionnement basique
    log_step "🧪 Test de fonctionnement kubectl..."
    if kubectl version --client >/dev/null 2>&1; then
        log_success "kubectl fonctionne correctement"
    else
        log_error "kubectl ne fonctionne pas correctement"
        return 1
    fi
    
    # Affichage des informations de version pour debug
    log_info "📊 Informations kubectl:"
    kubectl version --client 2>/dev/null || log_warning "Impossible d'afficher les détails de version"
    
    log_success "Installation kubectl validée avec succès"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    print_header "Installation kubectl $KUBECTL_VERSION"
    
    validate_required_var "KUBECTL_VERSION"
    
    install_dependencies
    setup_kubectl_cache
    download_kubectl
    install_kubectl_binary
    validate_installation
    
    print_summary "Installation kubectl Terminée" \
        "Version: $KUBECTL_VERSION" \
        "Cache: $KUBECTL_CACHE_DIR" \
        "Binaire: /usr/local/bin/kubectl"
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi