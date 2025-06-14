#!/bin/bash
# =============================================================================
# GESTION D'ERREURS CENTRALISEE - PIPELINE GITLAB CI/CD
# =============================================================================
# Description : Système de gestion d'erreurs avec trap, cleanup et reporting
# Version     : 1.0.0
# Auteur      : Infrastructure Team
# Dependances : logging.sh
# =============================================================================

# Repertoire du script pour sourcer logging.sh
SCRIPT_DIR_ERROR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Chargement du système de logging (si pas dejà charge)
if ! command -v log_error >/dev/null 2>&1; then
    # shellcheck source=logging.sh
    source "${SCRIPT_DIR_ERROR}/logging.sh"
fi

# =============================================================================
# VARIABLES GLOBALES DE GESTION D'ERREURS
# =============================================================================

# Configuration des codes d'erreur
readonly ERR_GENERAL=1
readonly ERR_VALIDATION=2
readonly ERR_NETWORK=3
readonly ERR_PERMISSION=4
readonly ERR_TIMEOUT=5
readonly ERR_DEPENDENCY=6
readonly ERR_CONFIGURATION=7

# Variables de nettoyage
CLEANUP_FUNCTIONS=()
TEMP_FILES=()
TEMP_DIRECTORIES=()
ERROR_CONTEXT=""
SCRIPT_START_TIME=""

# Variables de reporting
ERROR_LOG_FILE=""
ENABLE_ERROR_REPORTING="${ENABLE_ERROR_REPORTING:-true}"

# =============================================================================
# FONCTIONS DE GESTION DES TRAPS
# =============================================================================

# Configure les traps pour gestion d'erreurs automatique
# Usage: setup_error_trap "nom_du_script"
setup_error_trap() {
    local script_name="${1:-unknown_script}"
    ERROR_CONTEXT="$script_name"
    SCRIPT_START_TIME="$(date +%s)"
    
    # Configuration des traps pour differents signaux
    trap 'handle_error $? $LINENO "EXIT"' EXIT
    trap 'handle_error $? $LINENO "ERR"' ERR
    trap 'handle_error 130 $LINENO "INT"' INT
    trap 'handle_error 143 $LINENO "TERM"' TERM
    
    log_debug "Traps d'erreur configures pour: $script_name"
}

# Gestionnaire principal d'erreurs
# Usage: handle_error EXIT_CODE LINE_NUMBER SIGNAL
handle_error() {
    local exit_code="${1:-1}"
    local line_number="${2:-unknown}"
    local signal="${3:-unknown}"
    
    # Eviter les boucles infinies de gestion d'erreur
    trap - EXIT ERR INT TERM
    
    # Si c'est un exit normal (code 0), pas d'erreur à traiter
    if [[ "$signal" == "EXIT" && $exit_code -eq 0 ]]; then
        cleanup_on_exit
        return 0
    fi
    
    # Log de l'erreur
    log_error "Erreur detectee dans le script '$ERROR_CONTEXT'"
    log_error "Code de sortie: $exit_code"
    log_error "Ligne: $line_number"
    log_error "Signal: $signal"
    
    # Collecte du contexte d'erreur
    collect_error_context "$exit_code" "$line_number" "$signal"
    
    # Generation du rapport d'erreur
    if [[ "$ENABLE_ERROR_REPORTING" == "true" ]]; then
        generate_error_report "$exit_code" "$line_number" "$signal"
    fi
    
    # Nettoyage automatique
    cleanup_on_exit
    
    # Sortie avec le code d'erreur original
    exit "$exit_code"
}

# Collecte le contexte d'erreur pour debugging
# Usage: collect_error_context EXIT_CODE LINE_NUMBER SIGNAL
collect_error_context() {
    local exit_code="$1"
    local line_number="$2"
    local signal="$3"
    
    log_debug "=== CONTEXTE D'ERREUR ==="
    log_debug "Repertoire de travail: $(pwd)"
    log_debug "Utilisateur: $(whoami)"
    log_debug "Processus parent: $PPID"
    log_debug "Variables d'environnement critiques:"
    
    # Variables CI/CD importantes
    local critical_vars=(
        "CI_JOB_NAME" "CI_JOB_STAGE" "CI_COMMIT_BRANCH"
        "ENV" "TF_VERSION" "TF_ROOT"
    )
    
    for var in "${critical_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            log_debug "  $var=${!var}"
        fi
    done
    
    # Affichage des derniers processus si possible
    if command -v ps >/dev/null 2>&1; then
        log_debug "Processus en cours:"
        ps aux | head -10 2>/dev/null || true
    fi
    
    # Espace disque si possible
    if command -v df >/dev/null 2>&1; then
        log_debug "Espace disque:"
        df -h . 2>/dev/null || true
    fi
}

# =============================================================================
# FONCTIONS DE NETTOYAGE
# =============================================================================

# Ajoute une fonction de nettoyage à executer en cas d'erreur
# Usage: add_cleanup_function "nom_fonction"
add_cleanup_function() {
    local cleanup_func="${1:-}"
    
    if [[ -z "$cleanup_func" ]]; then
        log_warning "Fonction de nettoyage vide fournie"
        return 1
    fi
    
    CLEANUP_FUNCTIONS+=("$cleanup_func")
    log_debug "Fonction de nettoyage ajoutee: $cleanup_func"
}

# Ajoute un fichier temporaire à nettoyer automatiquement
# Usage: add_temp_file "/path/to/temp/file"
add_temp_file() {
    local temp_file="${1:-}"
    
    if [[ -z "$temp_file" ]]; then
        log_warning "Fichier temporaire vide fourni"
        return 1
    fi
    
    TEMP_FILES+=("$temp_file")
    log_debug "Fichier temporaire ajoute au nettoyage: $temp_file"
}

# Ajoute un repertoire temporaire à nettoyer automatiquement
# Usage: add_temp_directory "/path/to/temp/dir"
add_temp_directory() {
    local temp_dir="${1:-}"
    
    if [[ -z "$temp_dir" ]]; then
        log_warning "Repertoire temporaire vide fourni"
        return 1
    fi
    
    TEMP_DIRECTORIES+=("$temp_dir")
    log_debug "Repertoire temporaire ajoute au nettoyage: $temp_dir"
}

# Execute le nettoyage automatique
# Usage: cleanup_on_exit
cleanup_on_exit() {
    log_debug "🧹 Debut du nettoyage automatique..."
    
    # Execution des fonctions de nettoyage personnalisees
    for cleanup_func in "${CLEANUP_FUNCTIONS[@]}"; do
        if declare -f "$cleanup_func" >/dev/null 2>&1; then
            log_debug "Execution de la fonction de nettoyage: $cleanup_func"
            "$cleanup_func" || log_warning "Echec de la fonction de nettoyage: $cleanup_func"
        else
            log_warning "Fonction de nettoyage introuvable: $cleanup_func"
        fi
    done
    
    # Nettoyage des fichiers temporaires
    for temp_file in "${TEMP_FILES[@]}"; do
        if [[ -f "$temp_file" ]]; then
            log_debug "Suppression du fichier temporaire: $temp_file"
            rm -f "$temp_file" || log_warning "Impossible de supprimer: $temp_file"
        fi
    done
    
    # Nettoyage des repertoires temporaires
    for temp_dir in "${TEMP_DIRECTORIES[@]}"; do
        if [[ -d "$temp_dir" ]]; then
            log_debug "Suppression du repertoire temporaire: $temp_dir"
            rm -rf "$temp_dir" || log_warning "Impossible de supprimer: $temp_dir"
        fi
    done
    
    log_debug "✅ Nettoyage automatique termine"
}

# =============================================================================
# FONCTIONS DE VALIDATION ET GESTION D'ERREURS METIER
# =============================================================================

# Valide qu'une commande existe et termine le script si elle manque
# Usage: require_command "git" "Installez git pour continuer"
require_command() {
    local command_name="${1:-}"
    local error_message="${2:-Commande '$command_name' requise mais non trouvee}"
    
    if [[ -z "$command_name" ]]; then
        log_error "Nom de commande non specifie pour require_command"
        exit $ERR_VALIDATION
    fi
    
    if ! command -v "$command_name" >/dev/null 2>&1; then
        log_error "$error_message"
        exit $ERR_DEPENDENCY
    fi
    
    log_debug "Commande requise trouvee: $command_name"
}

# Valide qu'une variable d'environnement est definie
# Usage: require_env_var "TF_VERSION" "Variable TF_VERSION requise"
require_env_var() {
    local var_name="${1:-}"
    local error_message="${2:-Variable d environnement '$var_name' requise mais non definie}"
    
    if [[ -z "$var_name" ]]; then
        log_error "Nom de variable non specifie pour require_env_var"
        exit $ERR_VALIDATION
    fi
    
    if [[ -z "${!var_name:-}" ]]; then
        log_error "$error_message"
        exit $ERR_CONFIGURATION
    fi
    
    log_debug "Variable d'environnement requise trouvee: $var_name=${!var_name}"
}

# Valide qu'un fichier existe et termine le script si absent
# Usage: require_file "/path/to/file" "Fichier de configuration manquant"
require_file() {
    local file_path="${1:-}"
    local error_message="${2:-Fichier '$file_path' requis mais non trouve}"
    
    if [[ -z "$file_path" ]]; then
        log_error "Chemin de fichier non specifie pour require_file"
        exit $ERR_VALIDATION
    fi
    
    if [[ ! -f "$file_path" ]]; then
        log_error "$error_message"
        exit $ERR_DEPENDENCY
    fi
    
    log_debug "Fichier requis trouve: $file_path"
}

# Valide qu'un repertoire existe et termine le script si absent
# Usage: require_directory "/path/to/dir" "Repertoire de travail manquant"
require_directory() {
    local dir_path="${1:-}"
    local error_message="${2:-Repertoire '$dir_path' requis mais non trouve}"
    
    if [[ -z "$dir_path" ]]; then
        log_error "Chemin de repertoire non specifie pour require_directory"
        exit $ERR_VALIDATION
    fi
    
    if [[ ! -d "$dir_path" ]]; then
        log_error "$error_message"
        exit $ERR_DEPENDENCY
    fi
    
    log_debug "Repertoire requis trouve: $dir_path"
}

# =============================================================================
# FONCTIONS DE REPORTING D'ERREURS
# =============================================================================

# Configure le fichier de log d'erreur
# Usage: setup_error_reporting "/path/to/error.log"
setup_error_reporting() {
    local log_file="${1:-}"
    
    if [[ -n "$log_file" ]]; then
        ERROR_LOG_FILE="$log_file"
        
        # Creation du repertoire parent si necessaire
        local log_dir
        log_dir="$(dirname "$log_file")"
        mkdir -p "$log_dir" 2>/dev/null || {
            log_warning "Impossible de creer le repertoire de log: $log_dir"
            ERROR_LOG_FILE=""
            return 1
        }
        
        log_debug "Reporting d'erreurs configure: $log_file"
    else
        ERROR_LOG_FILE=""
        log_debug "Reporting d'erreurs desactive"
    fi
}

# Genère un rapport d'erreur detaille
# Usage: generate_error_report EXIT_CODE LINE_NUMBER SIGNAL
generate_error_report() {
    local exit_code="$1"
    local line_number="$2"
    local signal="$3"
    local timestamp
    timestamp="$(date -Iseconds)"
    
    # Calcul de la duree d'execution
    local duration="unknown"
    if [[ -n "$SCRIPT_START_TIME" ]]; then
        local end_time
        end_time="$(date +%s)"
        duration="$((end_time - SCRIPT_START_TIME))s"
    fi
    
    # Generation du rapport JSON
    local error_report
    error_report=$(cat << EOF
{
  "error_timestamp": "$timestamp",
  "script_name": "$ERROR_CONTEXT",
  "exit_code": $exit_code,
  "line_number": "$line_number",
  "signal": "$signal",
  "duration": "$duration",
  "environment": {
    "ci_job_name": "${CI_JOB_NAME:-}",
    "ci_job_stage": "${CI_JOB_STAGE:-}",
    "ci_commit_branch": "${CI_COMMIT_BRANCH:-}",
    "ci_commit_sha": "${CI_COMMIT_SHA:-}",
    "ci_pipeline_id": "${CI_PIPELINE_ID:-}",
    "working_directory": "$(pwd)",
    "user": "$(whoami)",
    "tf_version": "${TF_VERSION:-}",
    "env": "${ENV:-}"
  },
  "system_info": {
    "hostname": "$(hostname 2>/dev/null || echo 'unknown')",
    "os": "$(uname -s 2>/dev/null || echo 'unknown')",
    "shell": "$SHELL"
  }
}
EOF
)
    
    # Sauvegarde dans le fichier de log si configure
    if [[ -n "$ERROR_LOG_FILE" ]]; then
        echo "$error_report" >> "$ERROR_LOG_FILE" 2>/dev/null || {
            log_warning "Impossible d'ecrire dans le fichier de log d'erreur: $ERROR_LOG_FILE"
        }
    fi
    
    # Affichage dans les logs pour GitLab CI
    log_debug "Rapport d'erreur genere:"
    log_debug "$error_report"
}

# =============================================================================
# FONCTIONS D'AIDE ET UTILITAIRES
# =============================================================================

# Execute une commande avec gestion d'erreur personnalisee
# Usage: safe_execute "commande" "message d'erreur" [code_sortie]
safe_execute() {
    local command="${1:-}"
    local error_message="${2:-Echec de l execution de la commande}"
    local error_code="${3:-$ERR_GENERAL}"
    
    if [[ -z "$command" ]]; then
        log_error "Commande non specifiee pour safe_execute"
        exit $ERR_VALIDATION
    fi
    
    log_debug "Execution securisee: $command"
    
    if ! eval "$command"; then
        log_error "$error_message"
        log_error "Commande echouee: $command"
        exit "$error_code"
    fi
    
    log_debug "Commande executee avec succès: $command"
}

# Affiche les codes d'erreur disponibles
# Usage: show_error_codes
show_error_codes() {
    cat << 'EOF'
📊 CODES D'ERREUR STANDARDISES

🔢 Codes disponibles:
  0  - SUCCESS          : Execution reussie
  1  - ERR_GENERAL      : Erreur generale
  2  - ERR_VALIDATION   : Erreur de validation des paramètres
  3  - ERR_NETWORK      : Erreur reseau/connectivite
  4  - ERR_PERMISSION   : Erreur de permissions/accès
  5  - ERR_TIMEOUT      : Timeout/delai depasse
  6  - ERR_DEPENDENCY   : Dependance manquante
  7  - ERR_CONFIGURATION: Erreur de configuration

🛠️  Usage recommande:
  - Utilisez ces codes pour une gestion d'erreurs coherente
  - Le système de trap utilise automatiquement ces codes
  - Personnalisez les messages d'erreur selon le contexte

EOF
}

# Affiche l'aide du système de gestion d'erreurs
# Usage: show_error_management_help
show_error_management_help() {
    cat << 'EOF'
📚 GESTION D'ERREURS - FONCTIONS DISPONIBLES

🔧 Configuration:
  setup_error_trap "script_name"      - Configure les traps d'erreur
  setup_error_reporting "/path/log"   - Configure le fichier de log

🧹 Nettoyage:
  add_cleanup_function "func_name"    - Ajoute une fonction de nettoyage
  add_temp_file "/path/file"          - Ajoute un fichier à nettoyer
  add_temp_directory "/path/dir"      - Ajoute un repertoire à nettoyer
  cleanup_on_exit                     - Execute le nettoyage manuel

✅ Validation:
  require_command "cmd" "message"     - Valide qu'une commande existe
  require_env_var "VAR" "message"     - Valide qu'une variable est definie
  require_file "/path" "message"      - Valide qu'un fichier existe
  require_directory "/path" "message" - Valide qu'un repertoire existe

⚡ Execution securisee:
  safe_execute "cmd" "err_msg" [code] - Execute avec gestion d'erreur

📊 Information:
  show_error_codes                    - Affiche les codes d'erreur
  
Variables importantes:
  ENABLE_ERROR_REPORTING=true/false   - Active/desactive le reporting

EOF
}

# =============================================================================
# INITIALISATION
# =============================================================================

# Configuration par defaut du reporting d'erreurs
if [[ "$ENABLE_ERROR_REPORTING" == "true" && -z "$ERROR_LOG_FILE" ]]; then
    # Utilisation d'un fichier de log par defaut si en environnement CI
    if [[ -n "${CI_PROJECT_DIR:-}" ]]; then
        setup_error_reporting "$CI_PROJECT_DIR/error.log"
    fi
fi

# Si le script est execute directement (pas source)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "📋 Gestion d'erreurs - Pipeline GitLab CI/CD"
    log_info "Version: 1.0.0"
    echo
    show_error_management_help
    echo
    show_error_codes
    exit 0
fi