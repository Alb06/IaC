#!/bin/bash
# =============================================================================
# APPLY-ENVIRONMENT.SH - Application Plans Terraform (CORRIGÉ)
# =============================================================================
# Description : Application sécurisée des plans Terraform
# Usage       : ./apply-environment.sh <environment>
# Exemple     : ./apply-environment.sh prod
# Auteur      : Infrastructure Team
# Version     : 1.0.1 - Correction validation fichier plan
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
# FONCTIONS LOCALES
# =============================================================================

validate_plan_file_exists() {
    local plan_file="$1"
    local current_dir="$(pwd)"
    
    log_step "🔍 Vérification du fichier de plan..."
    log_debug "Répertoire courant: $current_dir"
    log_debug "Fichier de plan attendu: $plan_file"
    
    if [[ ! -f "$plan_file" ]]; then
        log_error "Fichier de plan non trouvé: $plan_file"
        log_error "Répertoire courant: $current_dir"
        log_info "📋 Contenu du répertoire courant:"
        ls -la . 2>/dev/null || log_error "Impossible de lister le contenu du répertoire"
        
        # Recherche du fichier dans les répertoires parents/enfants
        log_info "🔍 Recherche du fichier de plan dans l'arborescence..."
        find . -name "$plan_file" -type f 2>/dev/null | head -5 | while read -r found_file; do
            log_info "   Trouvé: $found_file"
        done
        
        # Vérification des artefacts potentiels
        if [[ -d "../.." ]]; then
            log_info "🔍 Recherche dans la racine du projet..."
            find ../.. -name "$plan_file" -type f 2>/dev/null | head -3 | while read -r found_file; do
                log_info "   Trouvé: $found_file"
            done
        fi
        
        return 1
    fi
    
    # Validation de la taille du fichier
    local file_size
    file_size=$(stat -f%z "$plan_file" 2>/dev/null || stat -c%s "$plan_file" 2>/dev/null || echo "0")
    
    if [[ "$file_size" -eq 0 ]]; then
        log_warning "Fichier de plan vide: $plan_file"
    else
        log_success "Fichier de plan trouvé: $plan_file (${file_size} bytes)"
    fi
    
    return 0
}

validate_terraform_state() {
    log_step "🔍 Validation de l'état Terraform..."
    
    # Vérification de l'initialisation Terraform
    if [[ ! -d ".terraform" ]]; then
        log_warning "Répertoire .terraform non trouvé, initialisation requise"
        terraform init
    else
        log_success "Répertoire .terraform présent"
    fi
    
    # Test de connectivité des providers
    log_step "🔌 Test de connectivité des providers..."
    terraform providers 2>/dev/null || log_warning "Impossible de lister les providers"
    
    return 0
}

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
        
        # Pause de sécurité pour la production
        log_info "⏱️  Pause de sécurité de 3 secondes..."
        sleep 3
    fi
}

backup_current_state() {
    local env_dir="$1"
    
    if [[ -f "terraform.tfstate" ]]; then
        log_step "💾 Sauvegarde de l'état actuel..."
        local backup_file="terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)"
        cp "terraform.tfstate" "$backup_file"
        log_success "État sauvegardé: $backup_file"
    else
        log_info "ℹ️  Aucun état Terraform existant à sauvegarder"
    fi
}

apply_terraform_plan() {
    local plan_file="$1"
    
    log_step "🚀 Application du plan Terraform..."
    log_info "Plan à appliquer: $plan_file"
    
    # Application avec logging détaillé
    if terraform apply -auto-approve "$plan_file"; then
        log_success "Plan appliqué avec succès"
        return 0
    else
        log_error "Échec de l'application du plan"
        
        # Diagnostic en cas d'échec
        log_info "🔍 Diagnostic post-échec..."
        terraform show "$plan_file" 2>/dev/null | head -20 || log_warning "Impossible d'afficher le plan"
        
        return 1
    fi
}

collect_outputs_and_artifacts() {
    log_step "📊 Collecte des outputs et artefacts..."
    
    # Récupération des outputs Terraform
    if terraform output -json > terraform_outputs.json 2>/dev/null; then
        local output_count
        output_count=$(jq -r 'keys | length' terraform_outputs.json 2>/dev/null || echo "0")
        log_success "Outputs Terraform collectés: $output_count variables"
    else
        log_warning "Aucun output Terraform disponible"
        echo "{}" > terraform_outputs.json
    fi
    
    # Génération des métadonnées de déploiement
    cat > deployment_metadata.json << EOF
{
  "deployment_date": "$(date -Iseconds)",
  "environment": "$TARGET_ENV",
  "commit": "${CI_COMMIT_SHA:-unknown}",
  "branch": "${CI_COMMIT_BRANCH:-unknown}",
  "user": "${GITLAB_USER_NAME:-unknown}",
  "pipeline_id": "${CI_PIPELINE_ID:-unknown}",
  "job_id": "${CI_JOB_ID:-unknown}",
  "plan_file": "$PLAN_FILE",
  "terraform_version": "$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo 'unknown')"
}
EOF
    
    log_success "Métadonnées de déploiement générées: deployment_metadata.json"
}

post_deployment_validation() {
    log_step "✅ Validation post-déploiement..."
    
    # Validation Terraform
    if terraform validate; then
        log_success "Configuration Terraform validée"
    else
        log_warning "Validation Terraform post-déploiement échouée"
    fi
    
    # Test de l'état
    if terraform show >/dev/null 2>&1; then
        log_success "État Terraform accessible"
    else
        log_warning "État Terraform inaccessible"
    fi
    
    # Vérification des ressources créées
    local resource_count
    resource_count=$(terraform show -json 2>/dev/null | jq -r '.values.root_module.resources | length' 2>/dev/null || echo "0")
    log_info "📊 Ressources dans l'état: $resource_count"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

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
    
    log_info "📂 Répertoire de travail: $(pwd)"
    
    # Validation de l'état Terraform
    validate_terraform_state
    
    # Vérification de l'existence du plan (fonction corrigée)
    validate_plan_file_exists "$PLAN_FILE"
    
    # Sauvegarde de l'état actuel
    backup_current_state "$env_dir"
    
    # Application du plan
    apply_terraform_plan "$PLAN_FILE"
    
    # Collecte des artefacts
    collect_outputs_and_artifacts
    
    # Validation post-déploiement
    post_deployment_validation
    
    print_summary "Application Terraform Terminée" \
        "Environnement: $TARGET_ENV" \
        "Plan appliqué: $PLAN_FILE" \
        "Outputs: terraform_outputs.json" \
        "Métadonnées: deployment_metadata.json" \
        "État sauvegardé: ✅"
    
    log_success "🎉 Application $TARGET_ENV terminée avec succès"
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi