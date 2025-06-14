#!/bin/bash
# =============================================================================
# SCRIPT UTILITAIRES COMMUNS - PIPELINE GITLAB CI/CD
# =============================================================================
# Description : Fonctions partagées pour tous les scripts du pipeline IaC
# Version     : 1.0.0
# Auteur      : Infrastructure Team
# Dépendances : error-management.sh, logging.sh, cache-management.sh
# =============================================================================

# Configuration globale
set -euo pipefail  # Mode strict : exit sur erreur, variable non définie, erreur dans pipe

# =============================================================================
# INITIALISATION ET CHARGEMENT DES MODULES
# =============================================================================

# Répertoire du script actuel
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Chargement des modules utilitaires
source "${SCRIPT_DIR}/logging.sh"
source "${SCRIPT_DIR}/error-management.sh"
source "${SCRIPT_DIR}/cache-management.sh"

# =============================================================================
# VARIABLES GLOBALES ET CONSTANTES
# =============================================================================

# Versions et configuration
readonly PIPELINE_VERSION="3.0.0"
readonly SCRIPT_VERSION="1.0.0"

# Timeouts et limites
readonly DEFAULT_TIMEOUT=30
readonly MAX_RETRY_ATTEMPTS=3
readonly RETRY_DELAY=2

# Patterns de validation
readonly IP_REGEX="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
readonly SEMVER_REGEX="^[0-9]+\.[0-9]+\.[0-9]+.*$"
readonly ENV_REGEX="^(dev|prod)$"

# Codes de sortie standardisés
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_VALIDATION_ERROR=2
readonly EXIT_NETWORK_ERROR=3
readonly EXIT_PERMISSION_ERROR=4

# =============================================================================
# FONCTIONS DE VALIDATION D'ENVIRONNEMENT
# =============================================================================

# Valide que l'environnement est correctement configuré
# Usage: validate_ci_environment
validate_ci_environment() {
    log_info "🔍 Validation de l'environnement CI/CD..."
    
    # Variables CI/CD requises
    local required_vars=(
        "CI_PROJECT_DIR"
        "CI_COMMIT_BRANCH"
        "CI_COMMIT_SHA"
        "CI_PIPELINE_ID"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Variable d'environnement manquante: $var"
            return $EXIT_VALIDATION_ERROR
        fi
    done
    
    # Validation du répertoire de travail
    if [[ ! -d "$CI_PROJECT_DIR" ]]; then
        log_error "Répertoire de projet CI inexistant: $CI_PROJECT_DIR"
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_success "Environnement CI/CD validé"
    return $EXIT_SUCCESS
}

# Valide qu'un environnement (dev/prod) est supporté
# Usage: validate_environment "dev"
validate_environment() {
    local env="${1:-}"
    
    if [[ -z "$env" ]]; then
        log_error "Environment non spécifié"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! "$env" =~ $ENV_REGEX ]]; then
        log_error "Environment '$env' non supporté. Valeurs acceptées: dev, prod"
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_info "✅ Environment '$env' validé"
    return $EXIT_SUCCESS
}

# Valide les prérequis pour un script Terraform
# Usage: validate_terraform_prerequisites
validate_terraform_prerequisites() {
    log_info "🔍 Validation des prérequis Terraform..."
    
    # Variables Terraform requises
    local tf_vars=(
        "TF_ROOT"
        "TF_VERSION"
        "ENV"
    )
    
    for var in "${tf_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Variable Terraform manquante: $var"
            return $EXIT_VALIDATION_ERROR
        fi
    done
    
    # Validation du répertoire Terraform
    if [[ ! -d "$TF_ROOT" ]]; then
        log_error "Répertoire Terraform inexistant: $TF_ROOT"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! -d "$TF_ROOT/$ENV" ]]; then
        log_error "Environnement Terraform inexistant: $TF_ROOT/$ENV"
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_success "Prérequis Terraform validés"
    return $EXIT_SUCCESS
}

# =============================================================================
# FONCTIONS DE GESTION DES FICHIERS ET RÉPERTOIRES
# =============================================================================

# Crée un répertoire avec gestion d'erreurs
# Usage: create_directory_safe "/path/to/dir"
create_directory_safe() {
    local dir_path="${1:-}"
    
    if [[ -z "$dir_path" ]]; then
        log_error "Chemin de répertoire non spécifié"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ -d "$dir_path" ]]; then
        log_info "Répertoire existant: $dir_path"
        return $EXIT_SUCCESS
    fi
    
    if mkdir -p "$dir_path" 2>/dev/null; then
        log_success "Répertoire créé: $dir_path"
        return $EXIT_SUCCESS
    else
        log_error "Impossible de créer le répertoire: $dir_path"
        return $EXIT_PERMISSION_ERROR
    fi
}

# Sauvegarde un fichier avec timestamp
# Usage: backup_file "/path/to/file"
backup_file() {
    local file_path="${1:-}"
    
    if [[ -z "$file_path" ]]; then
        log_error "Chemin de fichier non spécifié pour la sauvegarde"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! -f "$file_path" ]]; then
        log_warning "Fichier inexistant, pas de sauvegarde nécessaire: $file_path"
        return $EXIT_SUCCESS
    fi
    
    local backup_path="${file_path}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if cp "$file_path" "$backup_path"; then
        log_success "Sauvegarde créée: $backup_path"
        return $EXIT_SUCCESS
    else
        log_error "Échec de la sauvegarde: $file_path"
        return $EXIT_ERROR
    fi
}

# =============================================================================
# FONCTIONS DE VALIDATION DE SYNTAXE
# =============================================================================

# Valide qu'un fichier respecte le format JSON
# Usage: validate_json_file "/path/to/file.json"
validate_json_file() {
    local file_path="${1:-}"
    
    if [[ -z "$file_path" ]]; then
        log_error "Chemin de fichier JSON non spécifié"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! -f "$file_path" ]]; then
        log_error "Fichier JSON inexistant: $file_path"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if command -v jq >/dev/null 2>&1; then
        if jq empty "$file_path" >/dev/null 2>&1; then
            log_success "Fichier JSON valide: $file_path"
            return $EXIT_SUCCESS
        else
            log_error "Fichier JSON invalide: $file_path"
            return $EXIT_VALIDATION_ERROR
        fi
    else
        log_warning "jq non disponible, validation JSON ignorée"
        return $EXIT_SUCCESS
    fi
}

# Valide la syntaxe d'un fichier de version Terraform
# Usage: validate_version_constraint ">=1.12.1, <2.0.0"
validate_version_constraint() {
    local constraint="${1:-}"
    
    if [[ -z "$constraint" ]]; then
        log_error "Contrainte de version non spécifiée"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Validation basique du format de contrainte Terraform
    if [[ "$constraint" =~ ^(\>=?|~\>|\<\=?|=)[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        log_success "Contrainte de version valide: $constraint"
        return $EXIT_SUCCESS
    else
        log_error "Format de contrainte invalide: $constraint"
        return $EXIT_VALIDATION_ERROR
    fi
}

# =============================================================================
# FONCTIONS D'EXÉCUTION AVEC RETRY
# =============================================================================

# Exécute une commande avec retry automatique
# Usage: execute_with_retry "commande à exécuter" [max_attempts] [delay]
execute_with_retry() {
    local command="${1:-}"
    local max_attempts="${2:-$MAX_RETRY_ATTEMPTS}"
    local delay="${3:-$RETRY_DELAY}"
    
    if [[ -z "$command" ]]; then
        log_error "Commande non spécifiée pour execute_with_retry"
        return $EXIT_VALIDATION_ERROR
    fi
    
    local attempt=1
    local exit_code
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "🔄 Tentative $attempt/$max_attempts: $command"
        
        if eval "$command"; then
            log_success "Commande réussie à la tentative $attempt"
            return $EXIT_SUCCESS
        else
            exit_code=$?
            log_warning "Tentative $attempt échouée (code: $exit_code)"
            
            if [[ $attempt -lt $max_attempts ]]; then
                log_info "⏳ Attente de ${delay}s avant retry..."
                sleep "$delay"
            fi
            
            ((attempt++))
        fi
    done
    
    log_error "Commande échouée après $max_attempts tentatives: $command"
    return $exit_code
}

# Télécharge un fichier avec retry et validation
# Usage: download_with_retry "https://example.com/file" "/path/to/destination"
download_with_retry() {
    local url="${1:-}"
    local destination="${2:-}"
    
    if [[ -z "$url" || -z "$destination" ]]; then
        log_error "URL ou destination manquante pour le téléchargement"
        return $EXIT_VALIDATION_ERROR
    fi
    
    log_info "📥 Téléchargement: $url → $destination"
    
    # Création du répertoire de destination si nécessaire
    local dest_dir
    dest_dir="$(dirname "$destination")"
    create_directory_safe "$dest_dir" || return $?
    
    # Téléchargement avec retry
    if execute_with_retry "curl -fsSL -o '$destination' '$url'"; then
        # Validation que le fichier a été téléchargé
        if [[ -f "$destination" && -s "$destination" ]]; then
            log_success "Téléchargement réussi: $destination"
            return $EXIT_SUCCESS
        else
            log_error "Fichier téléchargé vide ou inexistant"
            return $EXIT_ERROR
        fi
    else
        log_error "Échec du téléchargement: $url"
        return $EXIT_NETWORK_ERROR
    fi
}

# =============================================================================
# FONCTIONS DE GESTION DES ARTEFACTS
# =============================================================================

# Prépare un répertoire pour les artefacts
# Usage: prepare_artifacts_directory "/path/to/artifacts"
prepare_artifacts_directory() {
    local artifacts_dir="${1:-}"
    
    if [[ -z "$artifacts_dir" ]]; then
        log_error "Répertoire d'artefacts non spécifié"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Nettoyage si le répertoire existe déjà
    if [[ -d "$artifacts_dir" ]]; then
        log_info "🧹 Nettoyage du répertoire d'artefacts existant"
        rm -rf "$artifacts_dir" || {
            log_error "Impossible de nettoyer le répertoire d'artefacts"
            return $EXIT_PERMISSION_ERROR
        }
    fi
    
    # Création du répertoire
    create_directory_safe "$artifacts_dir" || return $?
    
    log_success "Répertoire d'artefacts préparé: $artifacts_dir"
    return $EXIT_SUCCESS
}

# Génère un rapport JSON d'exécution
# Usage: generate_execution_report "/path/to/report.json" "job_name" "status" "details"
generate_execution_report() {
    local report_path="${1:-}"
    local job_name="${2:-}"
    local status="${3:-}"
    local details="${4:-}"
    
    if [[ -z "$report_path" || -z "$job_name" || -z "$status" ]]; then
        log_error "Paramètres manquants pour la génération du rapport"
        return $EXIT_VALIDATION_ERROR
    fi
    
    local timestamp
    timestamp="$(date -Iseconds)"
    
    cat > "$report_path" << EOF
{
  "execution_date": "$timestamp",
  "job_name": "$job_name",
  "status": "$status",
  "details": "$details",
  "pipeline_version": "$PIPELINE_VERSION",
  "script_version": "$SCRIPT_VERSION",
  "environment": {
    "ci_commit_branch": "${CI_COMMIT_BRANCH:-}",
    "ci_commit_sha": "${CI_COMMIT_SHA:-}",
    "ci_pipeline_id": "${CI_PIPELINE_ID:-}",
    "runner_type": "${CI_RUNNER_DESCRIPTION:-unknown}"
  }
}
EOF
    
    if validate_json_file "$report_path"; then
        log_success "Rapport d'exécution généré: $report_path"
        return $EXIT_SUCCESS
    else
        log_error "Erreur lors de la génération du rapport JSON"
        return $EXIT_ERROR
    fi
}

# =============================================================================
# FONCTIONS D'INITIALISATION ET NETTOYAGE
# =============================================================================

# Initialise l'environnement de script avec validations
# Usage: initialize_script_environment "script_name"
initialize_script_environment() {
    local script_name="${1:-unknown}"
    
    log_info "🚀 Initialisation du script: $script_name"
    
    # Validation de l'environnement CI/CD
    validate_ci_environment || {
        log_error "Échec de validation de l'environnement CI/CD"
        return $EXIT_VALIDATION_ERROR
    }
    
    # Configuration du piège pour nettoyage automatique en cas d'erreur
    setup_error_trap "$script_name"
    
    log_success "Script initialisé avec succès: $script_name"
    return $EXIT_SUCCESS
}

# Finalise l'exécution du script avec nettoyage
# Usage: finalize_script_execution "script_name" [exit_code]
finalize_script_execution() {
    local script_name="${1:-unknown}"
    local final_exit_code="${2:-$EXIT_SUCCESS}"
    
    if [[ $final_exit_code -eq $EXIT_SUCCESS ]]; then
        log_success "🎉 Script terminé avec succès: $script_name"
    else
        log_error "❌ Script terminé avec erreurs: $script_name (code: $final_exit_code)"
    fi
    
    # Nettoyage automatique via error-management.sh
    cleanup_on_exit
    
    return "$final_exit_code"
}

# =============================================================================
# FONCTIONS D'AIDE ET INFORMATION
# =============================================================================

# Affiche l'aide pour les fonctions communes
# Usage: show_common_help
show_common_help() {
    cat << 'EOF'
📚 FONCTIONS COMMUNES DISPONIBLES

🔍 Validation:
  validate_ci_environment              - Valide l'environnement CI/CD
  validate_environment ENV            - Valide un environnement (dev/prod)
  validate_terraform_prerequisites    - Valide les prérequis Terraform
  validate_json_file FILE             - Valide la syntaxe JSON
  validate_version_constraint CONSTRAINT - Valide une contrainte de version

📁 Gestion de fichiers:
  create_directory_safe DIR           - Crée un répertoire avec sécurité
  backup_file FILE                    - Sauvegarde un fichier avec timestamp

⚡ Exécution:
  execute_with_retry CMD [ATTEMPTS] [DELAY] - Exécute avec retry
  download_with_retry URL DEST        - Télécharge avec retry et validation

📊 Artefacts:
  prepare_artifacts_directory DIR     - Prépare un répertoire d'artefacts
  generate_execution_report PARAMS   - Génère un rapport JSON d'exécution

🔄 Cycle de vie:
  initialize_script_environment NAME - Initialise un script
  finalize_script_execution NAME [CODE] - Finalise un script

Variables globales disponibles:
  SCRIPT_DIR, PIPELINE_VERSION, DEFAULT_TIMEOUT, MAX_RETRY_ATTEMPTS
  EXIT_SUCCESS, EXIT_ERROR, EXIT_VALIDATION_ERROR, etc.

EOF
}

# =============================================================================
# POINT D'ENTRÉE PRINCIPAL
# =============================================================================

# Si le script est exécuté directement (pas sourcé)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "📋 Script utilitaires communs - Pipeline GitLab CI/CD"
    log_info "Version: $SCRIPT_VERSION"
    log_info ""
    show_common_help
    exit $EXIT_SUCCESS
fi