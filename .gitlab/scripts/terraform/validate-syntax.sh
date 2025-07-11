#!/bin/bash
# =============================================================================
# VALIDATE-SYNTAX.SH - Validation Syntaxique Terraform (CORRIGÉ)
# =============================================================================
# Description : Validation syntaxique complète de tous les environnements
# Usage       : ./validate-syntax.sh [environment]
# Exemple     : ./validate-syntax.sh dev
#               ./validate-syntax.sh (tous les environnements)
# Auteur      : Infrastructure Team
# Version     : 1.0.1 - Correction navigation répertoires
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly TARGET_ENV="${1:-all}"
readonly ENVIRONMENTS=("dev" "prod")
init_project_root

# =============================================================================
# FONCTIONS DE VALIDATION
# =============================================================================

validate_globals_module() {
    print_header "Validation du Module Globals"
    
    local globals_dir="$PROJECT_ROOT/terraform/globals"
    
    validate_directory_exists "$globals_dir"
    
    cd "$globals_dir" || {
        log_error "Impossible d'accéder au module globals"
        return 1
    }
    
    log_step "Initialisation du module globals..."
    terraform init -backend=false
    
    log_step "Validation syntaxique du module globals..."
    terraform validate
    
    cd "$PROJECT_ROOT" || return 1
    
    log_success "Module globals validé avec succès"
}

validate_environment() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/terraform/environments/$env"
    
    log_step "📋 Validation environnement: $env"
    
    validate_directory_exists "$env_dir"
    
    cd "$env_dir" || {
        log_error "Impossible d'accéder à l'environnement: $env"
        return 1
    }
    
    # Vérification de la présence de versions.tf
    if [[ ! -f "versions.tf" ]]; then
        log_error "Fichier versions.tf manquant dans $env"
        return 1
    fi
    
    log_step "Initialisation de l'environnement $env..."
    terraform init -backend=false
    
    log_step "Validation syntaxique de l'environnement $env..."
    terraform validate
    
    cd "$PROJECT_ROOT" || return 1
    
    log_success "$env validé avec succès (main.tf + versions.tf)"
}

validate_all_environments() {
    print_header "Validation de Tous les Environnements"
    
    local environments_dir="$PROJECT_ROOT/terraform/environments"
    
    validate_directory_exists "$environments_dir"
    
    log_info "Validation depuis le répertoire: $environments_dir"
    log_info "Environnements à valider: ${ENVIRONMENTS[*]}"
    
    for env in "${ENVIRONMENTS[@]}"; do
        local env_path="$environments_dir/$env"
        if [[ ! -d "$env_path" ]]; then
            log_error "Dossier $env inexistant dans $environments_dir"
            log_info "Contenu du répertoire environments:"
            ls -la "$environments_dir" || true
            return 1
        fi
        
        validate_environment "$env"
    done
    
    log_success "Tous les environnements validés avec succès"
}

validate_single_environment() {
    local env="$1"
    
    print_header "Validation de l'Environnement: $env"
    
    # Validation que l'environnement existe
    local valid_envs="${ENVIRONMENTS[*]}"
    if [[ ! " $valid_envs " =~ " $env " ]]; then
        log_error "Environnement non supporté: $env"
        log_info "Environnements disponibles: $valid_envs"
        return 1
    fi
    
    validate_environment "$env"
}

perform_additional_checks() {
    print_header "Vérifications Supplémentaires"
    
    # Vérification de la cohérence des fichiers
    log_step "Vérification de la cohérence des fichiers..."
    
    local required_files_globals=(
        "$PROJECT_ROOT/terraform/globals/main.tf"
        "$PROJECT_ROOT/terraform/globals/versions.tf"
        "$PROJECT_ROOT/terraform/globals/outputs.tf"
        "$PROJECT_ROOT/terraform/globals/variables.tf"
    )
    
    for file in "${required_files_globals[@]}"; do
        if [[ -f "$file" ]]; then
            log_success "Fichier trouvé: $(basename "$file")"
        else
            log_warning "Fichier manquant: $(basename "$file")"
        fi
    done
    
    # Vérification des templates
    local templates_dir="$PROJECT_ROOT/terraform/templates"
    if [[ -d "$templates_dir" ]]; then
        log_step "Validation des templates..."
        find "$templates_dir" -name "*.tpl" -type f | while read -r template; do
            log_info "Template trouvé: $(basename "$template")"
        done
    fi
    
    log_success "Vérifications supplémentaires terminées"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    local validation_scope="$TARGET_ENV"
    
    print_header "Validation Syntaxique Terraform"
    log_info "Scope de validation: $validation_scope"
    log_info "Répertoire de travail: $PROJECT_ROOT"
    
    # Vérification de la structure du projet
    if [[ ! -d "$PROJECT_ROOT/terraform" ]]; then
        log_error "Répertoire terraform non trouvé dans: $PROJECT_ROOT"
        log_info "Contenu du répertoire racine:"
        ls -la "$PROJECT_ROOT" || true
        return 1
    fi
    
    # Validation du module globals (toujours requis)
    validate_globals_module
    
    # Validation selon le scope demandé
    case "$validation_scope" in
        "all")
            validate_all_environments
            ;;
        "dev"|"prod")
            validate_single_environment "$validation_scope"
            ;;
        "global")
            log_info "Validation du module globals uniquement"
            ;;
        *)
            log_error "Scope de validation non supporté: $validation_scope"
            log_info "Scopes disponibles: all, dev, prod, global"
            return 1
            ;;
    esac
    
    # Vérifications supplémentaires
    perform_additional_checks
    
    print_summary "Validation Syntaxique Terminée" \
        "Scope: $validation_scope" \
        "Module globals: ✅" \
        "Environnements: ✅" \
        "Vérifications: ✅"
    
    log_success "🎉 Validation syntaxique terminée avec succès"
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi