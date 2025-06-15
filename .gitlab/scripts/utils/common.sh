#!/bin/bash
# =============================================================================
# COMMON.SH - Fonctions Utilitaires Partagées CI/CD (AMÉLIORÉ)
# =============================================================================
# Description : Bibliothèque de fonctions communes pour tous les scripts
# Usage       : source .gitlab/scripts/utils/common.sh
# Auteur      : Infrastructure Team
# Version     : 1.0.1 - Amélioration gestion des chemins
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION GLOBALE
# =============================================================================

# Couleurs pour les logs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Configuration par défaut
readonly DEFAULT_TIMEOUT=${REQUEST_TIMEOUT:-30}
readonly DEFAULT_RETRY_ATTEMPTS=${RETRY_ATTEMPTS:-3}
readonly DEFAULT_RETRY_DELAY=${RETRY_DELAY:-2}

# Détection du répertoire racine du projet
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# =============================================================================
# FONCTIONS DE NAVIGATION PROJET
# =============================================================================

find_project_root() {
    local current_dir="${SCRIPT_DIR:-$(pwd)}"
    
    # Validation de départ
    if [[ -z "$current_dir" ]]; then
        log_error "SCRIPT_DIR non défini"
        return 1
    fi
    
    log_debug "Recherche de la racine depuis: $current_dir"
    
    while [[ "$current_dir" != "/" ]]; do
        if [[ -f "$current_dir/.gitlab-ci.yml" ]] && [[ -d "$current_dir/terraform" ]]; then
            echo "$current_dir"
            return 0  # ✅ Succès explicite
        fi
        current_dir="$(dirname "$current_dir")"
    done
    
    # ❌ Échec explicite (sans exit pour permettre la gestion par l'appelant)
    log_error "Racine du projet IaC non trouvée"
    return 1
}

# Fonction utilitaire pour initialiser PROJECT_ROOT
init_project_root() {
    PROJECT_ROOT="$(find_project_root)" || {
        log_error "Impossible de déterminer PROJECT_ROOT"
        log_error "Vérifiez la structure du projet IaC"
        exit 1
    }

    if [[ -z "$PROJECT_ROOT" ]]; then
        log_error "PROJECT_ROOT est vide"
        exit 1
    fi

    readonly PROJECT_ROOT
    log_debug "PROJECT_ROOT validé: $PROJECT_ROOT"
}

init_project_root

# =============================================================================
# FONCTIONS DE LOGGING
# =============================================================================

log_info() {
    echo -e "${BLUE}ℹ️  [INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}✅ [SUCCESS]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠️  [WARNING]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}❌ [ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${PURPLE}🔍 [DEBUG]${NC} $*" >&2
    fi
}

log_step() {
    echo -e "${CYAN}🔄 [STEP]${NC} $*" >&2
}

# =============================================================================
# FONCTIONS DE VALIDATION
# =============================================================================

validate_required_var() {
    local var_name="$1"
    local var_value="${!var_name:-}"
    
    if [[ -z "$var_value" ]]; then
        log_error "Variable requise manquante: $var_name"
        return 1
    fi
    
    log_debug "Variable validée: $var_name=$var_value"
    return 0
}

validate_file_exists() {
    local file_path="$1"
    
    # Gestion des chemins relatifs et absolus
    local full_path
    if [[ "$file_path" = /* ]]; then
        full_path="$file_path"
    else
        full_path="$PROJECT_ROOT/$file_path"
    fi
    
    if [[ ! -f "$full_path" ]]; then
        log_error "Fichier non trouvé: $file_path"
        log_debug "Chemin complet testé: $full_path"
        log_debug "Répertoire courant: $(pwd)"
        log_debug "Contenu du répertoire parent:"
        ls -la "$(dirname "$full_path")" 2>/dev/null || log_debug "Répertoire parent inaccessible"
        return 1
    fi
    
    log_debug "Fichier validé: $file_path ($full_path)"
    return 0
}

validate_directory_exists() {
    local dir_path="$1"
    
    # Gestion des chemins relatifs et absolus
    local full_path
    if [[ "$dir_path" = /* ]]; then
        full_path="$dir_path"
    else
        full_path="$PROJECT_ROOT/$dir_path"
    fi
    
    if [[ ! -d "$full_path" ]]; then
        log_error "Répertoire non trouvé: $dir_path"
        log_debug "Chemin complet testé: $full_path"
        log_debug "Répertoire courant: $(pwd)"
        log_debug "Répertoire racine projet: $PROJECT_ROOT"
        
        # Diagnostic supplémentaire
        local parent_dir
        parent_dir="$(dirname "$full_path")"
        if [[ -d "$parent_dir" ]]; then
            log_debug "Contenu du répertoire parent ($parent_dir):"
            ls -la "$parent_dir" 2>/dev/null || log_debug "Impossible de lister le contenu"
        else
            log_debug "Répertoire parent inexistant: $parent_dir"
        fi
        
        return 1
    fi
    
    log_debug "Répertoire validé: $dir_path ($full_path)"
    return 0
}

validate_environment() {
    local env="$1"
    local valid_envs="${AVAILABLE_ENVIRONMENTS:-dev prod}"
    
    if [[ -z "$env" ]]; then
        log_error "Variable ENV non définie"
        return 1
    fi
    
    if ! echo "$valid_envs" | grep -q "$env"; then
        log_error "Environnement $env non supporté"
        log_info "Environnements disponibles: $valid_envs"
        return 1
    fi
    
    log_success "Environnement $env validé"
    return 0
}

# =============================================================================
# FONCTIONS DE RETRY
# =============================================================================

retry_command() {
    local max_attempts="${1:-$DEFAULT_RETRY_ATTEMPTS}"
    local delay="${2:-$DEFAULT_RETRY_DELAY}"
    shift 2
    local command=("$@")
    
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_step "Tentative $attempt/$max_attempts: ${command[*]}"
        
        if "${command[@]}"; then
            log_success "Commande réussie après $attempt tentative(s)"
            return 0
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Échec après $max_attempts tentatives: ${command[*]}"
            return 1
        fi
        
        log_warning "Tentative $attempt échouée, retry dans ${delay}s..."
        sleep "$delay"
        ((attempt++))
    done
}

# =============================================================================
# FONCTIONS D'INSTALLATION
# =============================================================================

install_package() {
    local package="$1"
    
    log_step "Installation du package: $package"
    
    if command -v "$package" >/dev/null 2>&1; then
        log_info "Package déjà installé: $package"
        return 0
    fi
    
    if command -v apk >/dev/null 2>&1; then
        retry_command 3 2 apk add --no-cache "$package"
    elif command -v apt-get >/dev/null 2>&1; then
        retry_command 3 2 apt-get update && apt-get install -y "$package"
    else
        log_error "Gestionnaire de paquets non supporté"
        return 1
    fi
    
    log_success "Package installé: $package"
}

# =============================================================================
# FONCTIONS DE NETTOYAGE
# =============================================================================

cleanup_on_exit() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script terminé avec le code d'erreur: $exit_code"
        
        # Diagnostic supplémentaire
        log_debug "=== DIAGNOSTIC ==="
        log_debug "Répertoire courant: $(pwd)"
        log_debug "Répertoire racine projet: $PROJECT_ROOT"
        log_debug "Variables d'environnement importantes:"
        log_debug "  TF_ROOT: ${TF_ROOT:-non défini}"
        log_debug "  CI_PROJECT_DIR: ${CI_PROJECT_DIR:-non défini}"
        log_debug "  ENV: ${ENV:-non défini}"
        
        # Sauvegarde des logs d'erreur
        if [[ "${SAVE_ERROR_LOGS:-true}" == "true" ]]; then
            local error_dir="/tmp/error_logs_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$error_dir" 2>/dev/null || true
            find . -name "*.log" -type f -exec cp {} "$error_dir/" \; 2>/dev/null || true
            log_info "Logs d'erreur sauvegardés dans: $error_dir"
        fi
    fi
    
    return $exit_code
}

# Configuration du trap pour le nettoyage automatique
trap cleanup_on_exit EXIT

# =============================================================================
# FONCTIONS D'AFFICHAGE
# =============================================================================

print_header() {
    local title="$1"
    local width=80
    local padding=$(( (width - ${#title} - 4) / 2 ))
    
    echo ""
    echo "$(printf '=%.0s' $(seq 1 $width))"
    echo "$(printf '%*s' $padding '')🚀 $title $(printf '%*s' $padding '')"
    echo "$(printf '=%.0s' $(seq 1 $width))"
    echo ""
}

print_summary() {
    local title="$1"
    shift
    
    echo ""
    echo -e "${CYAN}📋 $title${NC}"
    echo "$(printf -- '-%.0s' $(seq 1 ${#title}))"
    
    for item in "$@"; do
        echo "  • $item"
    done
    echo ""
}

# =============================================================================
# FONCTIONS DE VALIDATION SPÉCIFIQUES
# =============================================================================

validate_terraform_version() {
    local required_version="${TF_VERSION:-1.12.1}"
    
    if ! command -v terraform >/dev/null 2>&1; then
        log_error "Terraform non installé"
        return 1
    fi
    
    local current_version
    current_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1 | awk '{print $2}' | sed 's/v//')
    
    log_info "Version Terraform détectée: $current_version"
    log_info "Version requise: $required_version"
    
    # Validation basique (peut être améliorée avec une comparaison sémantique)
    if [[ "$current_version" == "$required_version"* ]]; then
        log_success "Version Terraform validée"
        return 0
    else
        log_warning "Version Terraform différente de celle attendue"
        return 0  # Warning seulement, pas d'erreur bloquante
    fi
}

# =============================================================================
# EXPORT DES FONCTIONS ET INITIALISATION
# =============================================================================

# Information de débogage
log_debug "Bibliothèque common.sh chargée"
log_debug "Répertoire racine projet: $PROJECT_ROOT"
log_debug "Répertoire du script: $SCRIPT_DIR"