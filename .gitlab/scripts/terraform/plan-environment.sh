#!/bin/bash
# =============================================================================
# PLAN-ENVIRONMENT.SH - Planification Terraform par Environnement
# =============================================================================
# Description : Génération et validation des plans Terraform
# Usage       : ./plan-environment.sh <environment>
# Exemple     : ./plan-environment.sh dev
# Auteur      : Infrastructure Team
# Version     : 1.0.0
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly TARGET_ENV="${1:-${ENV:-}}"
readonly PLAN_FILE="${PLAN_FILE:-tfplan}"
readonly TF_ROOT="${TF_ROOT:-terraform/environments}"

# =============================================================================
# FONCTIONS PRINCIPALES
# =============================================================================

main() {
    print_header "Planification Terraform - Environnement: $TARGET_ENV"
    
    validate_required_var "TARGET_ENV"
    validate_environment "$TARGET_ENV"
    
    local env_dir="$TF_ROOT/$TARGET_ENV"
    validate_directory_exists "$env_dir"
    
    cd "$env_dir" || {
        log_error "Impossible d'accéder à: $env_dir"
        return 1
    }
    
    # Initialisation Terraform
    log_step "Initialisation Terraform pour $TARGET_ENV..."
    retry_command 3 2 terraform init
    
    # Planification avec gestion des exit codes
    log_step "📋 Planification Terraform pour $TARGET_ENV..."
    
    set +e  # Désactive l'arrêt automatique sur erreur
    terraform plan -out="$PLAN_FILE" -detailed-exitcode
    local plan_exit_code=$?
    set -e  # Réactive l'arrêt automatique sur erreur
    
    log_info "🔍 Code de sortie terraform plan: $plan_exit_code"
    
    case $plan_exit_code in
        0)
            log_success "Aucun changement détecté"
            echo "PLAN_STATUS=no_changes" > ./plan_status.env
            plan_result="success"
            ;;
        1)
            log_error "Erreur lors de la planification"
            echo "PLAN_STATUS=error" > ./plan_status.env
            return 1
            ;;
        2)
            log_info "📝 Changements détectés, plan généré"
            echo "PLAN_STATUS=changes_detected" > ./plan_status.env
            plan_result="success"
            ;;
        *)
            log_error "Code de sortie inattendu: $plan_exit_code"
            echo "PLAN_STATUS=unknown_error" > ./plan_status.env
            return 1
            ;;
    esac
    
    echo "PLAN_RESULT=$plan_result" >> ./plan_status.env
    echo "PLAN_EXIT_CODE=$plan_exit_code" >> ./plan_status.env
    
    # Génération du résumé du plan
    log_step "📊 Génération du résumé du plan..."
    terraform show -no-color "$PLAN_FILE" > plan_output.txt 2>&1 || true
    
    print_summary "Résumé du Plan Terraform ($TARGET_ENV)" \
        "Fichier plan: $PLAN_FILE" \
        "Status: $plan_result" \
        "Code sortie: $plan_exit_code" \
        "Rapport: plan_output.txt"
    
    log_success "✅ Planification $TARGET_ENV terminée avec succès"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi