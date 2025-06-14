#!/bin/bash
# =============================================================================
# SYSTÈME DE LOGGING CENTRALISÉ - PIPELINE GITLAB CI/CD
# =============================================================================
# Description : Fonctions de logging avec niveaux, couleurs et timestamps
# Version     : 1.0.0
# Auteur      : Infrastructure Team
# Usage       : source logging.sh; log_info "message"
# =============================================================================

# Configuration des couleurs et formatage
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    # Terminal avec support couleurs
    readonly COLOR_RED=$(tput setaf 1)
    readonly COLOR_GREEN=$(tput setaf 2)
    readonly COLOR_YELLOW=$(tput setaf 3)
    readonly COLOR_BLUE=$(tput setaf 4)
    readonly COLOR_PURPLE=$(tput setaf 5)
    readonly COLOR_CYAN=$(tput setaf 6)
    readonly COLOR_WHITE=$(tput setaf 7)
    readonly COLOR_BOLD=$(tput bold)
    readonly COLOR_RESET=$(tput sgr0)
else
    # Pas de couleurs (CI/CD, redirection, etc.)
    readonly COLOR_RED=""
    readonly COLOR_GREEN=""
    readonly COLOR_YELLOW=""
    readonly COLOR_BLUE=""
    readonly COLOR_PURPLE=""
    readonly COLOR_CYAN=""
    readonly COLOR_WHITE=""
    readonly COLOR_BOLD=""
    readonly COLOR_RESET=""
fi

# Configuration du logging
readonly LOG_LEVEL_ERROR=1
readonly LOG_LEVEL_WARNING=2
readonly LOG_LEVEL_INFO=3
readonly LOG_LEVEL_DEBUG=4

# Niveau de log par défaut (peut être surchargé par LOG_LEVEL env var)
CURRENT_LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"

# Format de timestamp
readonly TIMESTAMP_FORMAT="%Y-%m-%d %H:%M:%S"

# =============================================================================
# FONCTIONS DE LOGGING PRINCIPALES
# =============================================================================

# Génère un timestamp formaté
# Usage: get_timestamp
get_timestamp() {
    date +"$TIMESTAMP_FORMAT"
}

# Affiche un message avec niveau et formatage
# Usage: log_message LEVEL ICON COLOR MESSAGE
log_message() {
    local level="$1"
    local icon="$2"
    local color="$3"
    local message="$4"
    
    # Vérification du niveau de log
    if [[ $level -le $CURRENT_LOG_LEVEL ]]; then
        printf "%s[%s]%s %s%s%s %s\n" \
            "$COLOR_CYAN" "$(get_timestamp)" "$COLOR_RESET" \
            "$color" "$icon" "$COLOR_RESET" \
            "$message"
    fi
}

# Log d'erreur (niveau 1)
# Usage: log_error "message d'erreur"
log_error() {
    local message="${1:-Erreur non spécifiée}"
    log_message $LOG_LEVEL_ERROR "❌" "$COLOR_RED$COLOR_BOLD" "ERROR: $message" >&2
}

# Log d'avertissement (niveau 2)
# Usage: log_warning "message d'avertissement"
log_warning() {
    local message="${1:-Avertissement non spécifié}"
    log_message $LOG_LEVEL_WARNING "⚠️ " "$COLOR_YELLOW" "WARNING: $message"
}

# Log d'information (niveau 3)
# Usage: log_info "message d'information"
log_info() {
    local message="${1:-Information non spécifiée}"
    log_message $LOG_LEVEL_INFO "ℹ️ " "$COLOR_BLUE" "INFO: $message"
}

# Log de succès (niveau 3, variante de info)
# Usage: log_success "message de succès"
log_success() {
    local message="${1:-Succès non spécifié}"
    log_message $LOG_LEVEL_INFO "✅" "$COLOR_GREEN$COLOR_BOLD" "SUCCESS: $message"
}

# Log de debug (niveau 4)
# Usage: log_debug "message de debug"
log_debug() {
    local message="${1:-Debug non spécifié}"
    log_message $LOG_LEVEL_DEBUG "🐛" "$COLOR_PURPLE" "DEBUG: $message"
}

# =============================================================================
# FONCTIONS DE LOGGING SPÉCIALISÉES
# =============================================================================

# Log de début de section avec séparateur
# Usage: log_section "Nom de la section"
log_section() {
    local section_name="${1:-Section}"
    local separator=$(printf "%*s" 60 "" | tr " " "=")
    
    echo
    log_message $LOG_LEVEL_INFO "📋" "$COLOR_CYAN$COLOR_BOLD" "$separator"
    log_message $LOG_LEVEL_INFO "📋" "$COLOR_CYAN$COLOR_BOLD" "$section_name"
    log_message $LOG_LEVEL_INFO "📋" "$COLOR_CYAN$COLOR_BOLD" "$separator"
}

# Log de progression avec pourcentage
# Usage: log_progress "action" 50 100
log_progress() {
    local action="${1:-Action}"
    local current="${2:-0}"
    local total="${3:-100}"
    
    local percentage=$((current * 100 / total))
    local progress_bar=""
    local bar_length=20
    local filled_length=$((percentage * bar_length / 100))
    
    # Création de la barre de progression
    for ((i=0; i<bar_length; i++)); do
        if [[ $i -lt $filled_length ]]; then
            progress_bar+="█"
        else
            progress_bar+="░"
        fi
    done
    
    log_message $LOG_LEVEL_INFO "🔄" "$COLOR_BLUE" "$action: [$progress_bar] $percentage% ($current/$total)"
}

# Log d'exécution de commande
# Usage: log_command "description" "commande"
log_command() {
    local description="${1:-Commande}"
    local command="${2:-}"
    
    log_info "$description"
    if [[ -n "$command" ]]; then
        log_debug "Commande exécutée: $command"
    fi
}

# Log de durée d'exécution
# Usage: start_time=$(date +%s); ...; log_duration "Action" $start_time
log_duration() {
    local action="${1:-Action}"
    local start_time="${2:-$(date +%s)}"
    local end_time="$(date +%s)"
    local duration=$((end_time - start_time))
    
    local duration_formatted
    if [[ $duration -lt 60 ]]; then
        duration_formatted="${duration}s"
    elif [[ $duration -lt 3600 ]]; then
        duration_formatted="$((duration / 60))m $((duration % 60))s"
    else
        duration_formatted="$((duration / 3600))h $(((duration % 3600) / 60))m $((duration % 60))s"
    fi
    
    log_success "$action terminé en $duration_formatted"
}

# =============================================================================
# FONCTIONS DE LOGGING POUR CI/CD
# =============================================================================

# Log des informations de pipeline GitLab
# Usage: log_pipeline_info
log_pipeline_info() {
    log_section "INFORMATIONS PIPELINE GITLAB"
    
    log_info "Pipeline ID: ${CI_PIPELINE_ID:-N/A}"
    log_info "Job ID: ${CI_JOB_ID:-N/A}"
    log_info "Job Name: ${CI_JOB_NAME:-N/A}"
    log_info "Stage: ${CI_JOB_STAGE:-N/A}"
    log_info "Branche: ${CI_COMMIT_BRANCH:-N/A}"
    log_info "Commit SHA: ${CI_COMMIT_SHA:-N/A}"
    log_info "Commit Message: ${CI_COMMIT_MESSAGE:-N/A}"
    log_info "Runner: ${CI_RUNNER_DESCRIPTION:-N/A}"
    log_info "Utilisateur: ${GITLAB_USER_NAME:-N/A} (${GITLAB_USER_EMAIL:-N/A})"
}

# Log de configuration des variables d'environnement importantes
# Usage: log_environment_config
log_environment_config() {
    log_section "CONFIGURATION ENVIRONNEMENT"
    
    # Variables Terraform
    if [[ -n "${TF_VERSION:-}" ]]; then
        log_info "Terraform Version: $TF_VERSION"
        log_info "Terraform Root: ${TF_ROOT:-N/A}"
        log_info "Environment: ${ENV:-N/A}"
    fi
    
    # Variables Ansible
    if [[ -n "${ANSIBLE_VERSION:-}" ]]; then
        log_info "Ansible Version: $ANSIBLE_VERSION"
        log_info "Ansible Host Key Checking: ${ANSIBLE_HOST_KEY_CHECKING:-N/A}"
    fi
    
    # Variables système
    log_info "Répertoire de travail: $(pwd)"
    log_info "Utilisateur: $(whoami)"
    log_info "Shell: $SHELL"
    log_info "Niveau de log: $CURRENT_LOG_LEVEL"
}

# =============================================================================
# FONCTIONS DE CONFIGURATION
# =============================================================================

# Configure le niveau de log dynamiquement
# Usage: set_log_level 4  # ou set_log_level "debug"
set_log_level() {
    local level="${1:-}"
    
    case "$level" in
        "error"|"1"|"$LOG_LEVEL_ERROR")
            CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR
            log_info "Niveau de log défini à: ERROR"
            ;;
        "warning"|"2"|"$LOG_LEVEL_WARNING")
            CURRENT_LOG_LEVEL=$LOG_LEVEL_WARNING
            log_info "Niveau de log défini à: WARNING"
            ;;
        "info"|"3"|"$LOG_LEVEL_INFO")
            CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
            log_info "Niveau de log défini à: INFO"
            ;;
        "debug"|"4"|"$LOG_LEVEL_DEBUG")
            CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
            log_info "Niveau de log défini à: DEBUG"
            ;;
        *)
            log_error "Niveau de log invalide: $level. Valeurs acceptées: error(1), warning(2), info(3), debug(4)"
            return 1
            ;;
    esac
}

# Active le mode verbose (debug)
# Usage: enable_verbose_logging
enable_verbose_logging() {
    set_log_level "debug"
    log_debug "Mode verbose activé"
}

# Active le mode silencieux (erreurs uniquement)
# Usage: enable_quiet_logging
enable_quiet_logging() {
    set_log_level "error"
    log_error "Mode silencieux activé (erreurs uniquement)"
}

# =============================================================================
# FONCTIONS D'AIDE
# =============================================================================

# Affiche l'aide du système de logging
# Usage: show_logging_help
show_logging_help() {
    cat << 'EOF'
📚 SYSTÈME DE LOGGING - FONCTIONS DISPONIBLES

📝 Fonctions de base:
  log_error "message"        - Log d'erreur (niveau 1)
  log_warning "message"      - Log d'avertissement (niveau 2)
  log_info "message"         - Log d'information (niveau 3)
  log_success "message"      - Log de succès (niveau 3)
  log_debug "message"        - Log de debug (niveau 4)

🎨 Fonctions spécialisées:
  log_section "titre"        - Section avec séparateur
  log_progress "action" 50 100 - Barre de progression
  log_command "desc" "cmd"   - Log d'exécution de commande
  log_duration "action" $start - Log de durée d'exécution

🔧 CI/CD:
  log_pipeline_info         - Informations pipeline GitLab
  log_environment_config    - Configuration environnement

⚙️  Configuration:
  set_log_level LEVEL       - Configure le niveau (1-4 ou error/warning/info/debug)
  enable_verbose_logging    - Active le mode debug
  enable_quiet_logging      - Mode silencieux (erreurs uniquement)

📊 Niveaux de log:
  1 - ERROR   : Erreurs uniquement
  2 - WARNING : Erreurs + avertissements
  3 - INFO    : Erreurs + avertissements + informations (défaut)
  4 - DEBUG   : Tous les messages

Configuration via variable d'environnement: export LOG_LEVEL=4

EOF
}

# =============================================================================
# INITIALISATION
# =============================================================================

# Configuration automatique du niveau de log depuis l'environnement
if [[ -n "${LOG_LEVEL:-}" ]]; then
    set_log_level "$LOG_LEVEL" >/dev/null 2>&1 || {
        echo "❌ Niveau de log invalide dans LOG_LEVEL: $LOG_LEVEL" >&2
    }
fi

# Si le script est exécuté directement (pas sourcé)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "📋 Système de logging - Pipeline GitLab CI/CD"
    log_info "Version: 1.0.0"
    echo
    show_logging_help
    exit 0
fi