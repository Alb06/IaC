#!/bin/bash
# =============================================================================
# DIAGNOSE-PIPELINE.SH - Diagnostic Pipeline CI/CD
# =============================================================================
# Description : Script de diagnostic pour identifier les problèmes pipeline
# Usage       : ./diagnose-pipeline.sh [environment]
# Exemple     : ./diagnose-pipeline.sh dev
# Auteur      : Infrastructure Team
# Version     : 1.0.0
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly TARGET_ENV="${1:-${ENV:-all}}"
readonly ENVIRONMENTS=("dev" "prod")

# =============================================================================
# FONCTIONS DE DIAGNOSTIC
# =============================================================================

diagnose_environment_structure() {
    print_header "Diagnostic Structure Environnement"
    
    log_info "📂 Structure du projet:"
    log_info "Répertoire courant: $(pwd)"
    log_info "PROJECT_ROOT: $PROJECT_ROOT"
    log_info "TF_ROOT: ${TF_ROOT:-non défini}"
    
    # Vérification de la structure Terraform
    if [[ -d "$PROJECT_ROOT/terraform" ]]; then
        log_success "Répertoire terraform trouvé"
        log_info "Contenu du répertoire terraform:"
        ls -la "$PROJECT_ROOT/terraform/"
        
        # Vérification des environnements
        if [[ -d "$PROJECT_ROOT/terraform/environments" ]]; then
            log_success "Répertoire environments trouvé"
            log_info "Environnements disponibles:"
            ls -la "$PROJECT_ROOT/terraform/environments/"
        else
            log_error "Répertoire environments manquant"
        fi
    else
        log_error "Répertoire terraform manquant"
    fi
}

diagnose_environment_files() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/terraform/environments/$env"
    
    log_step "📋 Diagnostic environnement: $env"
    
    if [[ ! -d "$env_dir" ]]; then
        log_error "Environnement $env non trouvé: $env_dir"
        return 1
    fi
    
    log_info "Contenu de l'environnement $env:"
    ls -la "$env_dir/"
    
    # Vérification des fichiers critiques
    local critical_files=("main.tf" "versions.tf" "variables.tf")
    local optional_files=("outputs.tf" "terraform.tfvars")
    local runtime_files=("tfplan" "terraform.tfstate" "terraform_outputs.json")
    
    log_info "📄 Fichiers critiques:"
    for file in "${critical_files[@]}"; do
        if [[ -f "$env_dir/$file" ]]; then
            log_success "  ✅ $file"
        else
            log_error "  ❌ $file (MANQUANT)"
        fi
    done
    
    log_info "📄 Fichiers optionnels:"
    for file in "${optional_files[@]}"; do
        if [[ -f "$env_dir/$file" ]]; then
            log_success "  ✅ $file"
        else
            log_info "  ℹ️  $file (optionnel)"
        fi
    done
    
    log_info "📄 Fichiers de runtime/artefacts:"
    for file in "${runtime_files[@]}"; do
        if [[ -f "$env_dir/$file" ]]; then
            local size
            size=$(stat -f%z "$env_dir/$file" 2>/dev/null || stat -c%s "$env_dir/$file" 2>/dev/null || echo "0")
            log_success "  ✅ $file (${size} bytes)"
        else
            log_warning "  ⚠️  $file (artefact manquant)"
        fi
    done
}

diagnose_terraform_state() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/terraform/environments/$env"
    
    log_step "🔍 Diagnostic état Terraform: $env"
    
    cd "$env_dir" || {
        log_error "Impossible d'accéder à: $env_dir"
        return 1
    }
    
    # Vérification de l'initialisation
    if [[ -d ".terraform" ]]; then
        log_success "Terraform initialisé"
        log_info "Contenu .terraform:"
        ls -la ".terraform/"
        
        # Vérification du lock file
        if [[ -f ".terraform.lock.hcl" ]]; then
            log_success "Lock file présent"
            log_info "Providers dans le lock file:"
            grep -A 1 "provider" ".terraform.lock.hcl" | head -10 || true
        else
            log_warning "Lock file manquant"
        fi
    else
        log_warning "Terraform non initialisé"
    fi
    
    # Test de validation si possible
    if command -v terraform >/dev/null 2>&1; then
        log_step "Test de validation Terraform..."
        if terraform validate 2>/dev/null; then
            log_success "Configuration Terraform valide"
        else
            log_warning "Configuration Terraform invalide ou non initialisée"
        fi
    fi
    
    cd "$PROJECT_ROOT" || return 1
}

diagnose_artifacts_locations() {
    print_header "Diagnostic Localisation Artefacts"
    
    log_info "🔍 Recherche des artefacts dans l'arborescence..."
    
    # Recherche des plans Terraform
    log_step "Recherche des plans Terraform (tfplan):"
    find "$PROJECT_ROOT" -name "tfplan" -type f 2>/dev/null | while read -r plan_file; do
        local size
        size=$(stat -f%z "$plan_file" 2>/dev/null || stat -c%s "$plan_file" 2>/dev/null || echo "0")
        local relative_path
        relative_path=${plan_file#$PROJECT_ROOT/}
        log_info "  📋 $relative_path (${size} bytes)"
    done
    
    # Recherche des outputs
    log_step "Recherche des outputs Terraform:"
    find "$PROJECT_ROOT" -name "terraform_outputs.json" -type f 2>/dev/null | while read -r output_file; do
        local size
        size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null || echo "0")
        local relative_path
        relative_path=${output_file#$PROJECT_ROOT/}
        log_info "  📊 $relative_path (${size} bytes)"
    done
    
    # Recherche des états
    log_step "Recherche des états Terraform:"
    find "$PROJECT_ROOT" -name "terraform.tfstate*" -type f 2>/dev/null | while read -r state_file; do
        local size
        size=$(stat -f%z "$state_file" 2>/dev/null || stat -c%s "$state_file" 2>/dev/null || echo "0")
        local relative_path
        relative_path=${state_file#$PROJECT_ROOT/}
        log_info "  💾 $relative_path (${size} bytes)"
    done
}

diagnose_ci_variables() {
    print_header "Diagnostic Variables CI/CD"
    
    log_info "🔧 Variables d'environnement CI/CD:"
    
    local ci_vars=(
        "CI_PROJECT_DIR" "CI_COMMIT_BRANCH" "CI_COMMIT_SHA" "CI_PIPELINE_ID" 
        "CI_JOB_ID" "CI_JOB_NAME" "CI_JOB_STAGE" "GITLAB_USER_NAME"
        "TF_ROOT" "TF_VERSION" "ENV" "PLAN_FILE"
    )
    
    for var in "${ci_vars[@]}"; do
        local value="${!var:-NON_DÉFINI}"
        if [[ "$value" != "NON_DÉFINI" ]]; then
            log_success "  ✅ $var=$value"
        else
            log_warning "  ⚠️  $var=NON_DÉFINI"
        fi
    done
}

generate_diagnostic_report() {
    local env="${1:-all}"
    
    log_step "📊 Génération du rapport de diagnostic..."
    
    local report_file="diagnostic_report_${env}_$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "diagnostic_date": "$(date -Iseconds)",
  "environment": "$env",
  "project_root": "$PROJECT_ROOT",
  "current_directory": "$(pwd)",
  "ci_context": {
    "pipeline_id": "${CI_PIPELINE_ID:-unknown}",
    "job_name": "${CI_JOB_NAME:-unknown}",
    "commit": "${CI_COMMIT_SHA:-unknown}",
    "branch": "${CI_COMMIT_BRANCH:-unknown}"
  },
  "terraform_structure": {
    "terraform_dir_exists": $([ -d "$PROJECT_ROOT/terraform" ] && echo "true" || echo "false"),
    "environments_dir_exists": $([ -d "$PROJECT_ROOT/terraform/environments" ] && echo "true" || echo "false"),
    "globals_dir_exists": $([ -d "$PROJECT_ROOT/terraform/globals" ] && echo "true" || echo "false")
  },
  "artifacts_found": {
    "plan_files": $(find "$PROJECT_ROOT" -name "tfplan" -type f 2>/dev/null | wc -l),
    "output_files": $(find "$PROJECT_ROOT" -name "terraform_outputs.json" -type f 2>/dev/null | wc -l),
    "state_files": $(find "$PROJECT_ROOT" -name "terraform.tfstate*" -type f 2>/dev/null | wc -l)
  }
}
EOF
    
    if command -v jq >/dev/null 2>&1; then
        log_info "📄 Rapport de diagnostic généré:"
        jq '.' "$report_file"
    else
        log_info "📄 Rapport généré: $report_file"
    fi
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    print_header "Diagnostic Pipeline CI/CD - Environnement: $TARGET_ENV"
    
    diagnose_environment_structure
    diagnose_ci_variables
    
    if [[ "$TARGET_ENV" == "all" ]]; then
        for env in "${ENVIRONMENTS[@]}"; do
            diagnose_environment_files "$env"
            diagnose_terraform_state "$env"
        done
    else
        validate_environment "$TARGET_ENV"
        diagnose_environment_files "$TARGET_ENV"
        diagnose_terraform_state "$TARGET_ENV"
    fi
    
    diagnose_artifacts_locations
    generate_diagnostic_report "$TARGET_ENV"
    
    print_summary "Diagnostic Terminé" \
        "Environnement: $TARGET_ENV" \
        "Structure: vérifiée" \
        "Artefacts: analysés" \
        "Rapport: généré"
    
    log_success "🎉 Diagnostic terminé avec succès"
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi