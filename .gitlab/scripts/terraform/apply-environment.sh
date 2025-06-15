#!/bin/bash
# =============================================================================
# APPLY-ENVIRONMENT.SH - Application Plans Terraform
# =============================================================================
# Description : Application sécurisée des plans Terraform
# Usage       : ./apply-environment.sh <environment>
# Exemple     : ./apply-environment.sh prod
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

validate_production_requirements() {
    if [[ "$TARGET_ENV" == "prod" ]]; then
        log_step "🔐 Validations supplémentaires pour la production..."
        
        if [[ "$CI_COMMIT_BRANCH" != "${PRODUCTION_BRANCH:-main}" ]]; then
            log_error "Déploiement production autorisé uniquement depuis ${PRODUCTION_BRANCH:-main}"
            return 1
        fi
        
        log_info "👤 Déploiement par: ${GITLAB_USER_NAME:-unknown} (${GITLAB_USER_EMAIL:-unknown})"
        log_warning "⚠️  ATTENTION: Déploiement en environnement de PRODUCTION"
    fi
}

backup_current_state() {
    local env_dir="$1"
    
    if [[ -f "$env_dir/terraform.tfstate" ]]; then
        log_step "💾 Sauvegarde de l'état actuel..."
        local backup_file="terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$env_dir/terraform.tfstate" "$env_dir/$backup_file"
        log_success "État sauvegardé: $backup_file"
    fi
}

main() {
    print_header "Application Terraform - Environnement: $TARGET_ENV"
    
    validate_required_var "TARGET_ENV"
    validate_environment "$TARGET_ENV"
    validate_production_requirements
    
    local env_dir="$TF_ROOT/$TARGET_ENV"
    validate_directory_exists "$env_dir"
    
    cd "$env_dir" || {
        log_error "Impossible d'accéder à: $env_dir"
        return 1
    }
    
    # Vérification de l'existence du plan
    validate_file_exists "$PLAN_FILE"
    
    # Sauvegarde de l'état actuel
    backup_current_state "$env_dir"
    
    # Application du plan
    log_step "🚀 Application du plan Terraform..."
    terraform apply -auto-approve "$PLAN_FILE"
    
    # Récupération des outputs
    log_step "📊 Récupération des outputs..."
    terraform output -json > terraform_outputs.json || {
        log_warning "Aucun output disponible"
        echo "{}" > terraform_outputs.json
    }
    
    # Validation post-déploiement
    log_step "✅ Validation post-déploiement..."
    terraform validate || log_warning "Validation post-déploiement échouée"
    
    print_summary "Application Terraform Terminée" \
        "Environnement: $TARGET_ENV" \
        "Plan appliqué: $PLAN_FILE" \
        "Outputs: terraform_outputs.json" \
        "État sauvegardé: ✅"
    
    log_success "🎉 Application $TARGET_ENV terminée avec succès"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi