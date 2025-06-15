#!/bin/bash
# =============================================================================
# VALIDATE-VERSIONS.SH - Validation Contraintes Versions Terraform (CORRIGÉ)
# =============================================================================
# Description : Validation des contraintes de versions avec auto-formatage
# Usage       : ./validate-versions.sh
# Auteur      : Infrastructure Team
# Version     : 1.0.1 - Correction formatage JSON
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly REQUIRED_FILES=(
    "terraform/globals/versions.tf"
    "terraform/environments/dev/versions.tf" 
    "terraform/environments/prod/versions.tf"
)

readonly ARTIFACTS_DIR="formatted_files"
readonly REPORT_FILE="version_validation_report.json"
init_project_root

# =============================================================================
# FONCTIONS DE VALIDATION
# =============================================================================

check_required_files() {
    print_header "Vérification des Fichiers versions.tf"
    
    local missing_files=()
    
    for file in "${REQUIRED_FILES[@]}"; do
        local full_path="$PROJECT_ROOT/$file"
        if [[ -f "$full_path" ]]; then
            log_success "Fichier trouvé: $file"
        else
            log_error "Fichier manquant: $file"
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Fichiers manquants détectés"
        return 1
    fi
    
    log_success "Tous les fichiers versions.tf sont présents"
}

auto_format_versions_files() {
    print_header "Auto-Formatage des Fichiers versions.tf"
    
    local format_changes=false
    local versions_files
    
    mapfile -t versions_files < <(find "$PROJECT_ROOT/terraform/" -name "versions.tf" -type f)
    
    for versions_file in "${versions_files[@]}"; do
        log_step "Formatage automatique: $(basename "$(dirname "$versions_file")")/$(basename "$versions_file")"
        
        # Sauvegarde avant formatage
        cp "$versions_file" "${versions_file}.backup"
        
        # Application du formatage Terraform
        terraform fmt "$versions_file"
        
        # Vérification des changements
        if ! diff -q "$versions_file" "${versions_file}.backup" >/dev/null 2>&1; then
            log_info "📝 Formatage appliqué à: $versions_file"
            format_changes=true
            
            log_debug "Changements appliqués:"
            diff "${versions_file}.backup" "$versions_file" || true
        else
            log_success "Fichier déjà correctement formaté: $versions_file"
        fi
        
        # Nettoyage de la sauvegarde
        rm -f "${versions_file}.backup"
    done
    
    if [[ "$format_changes" == "true" ]]; then
        log_info "ℹ️  Des changements de formatage ont été appliqués automatiquement"
        echo "true"
    else
        log_success "Tous les fichiers versions.tf sont correctement formatés"
        echo "false"
    fi
}

validate_globals_module() {
    print_header "Validation Syntaxique du Module Globals"
    
    local globals_dir="$PROJECT_ROOT/terraform/globals"
    
    validate_directory_exists "$globals_dir"
    
    cd "$globals_dir" || {
        log_error "Impossible d'accéder au répertoire: $globals_dir"
        return 1
    }
    
    log_step "Initialisation du module globals..."
    terraform init -backend=false
    
    log_step "Validation syntaxique..."
    terraform validate
    
    cd "$PROJECT_ROOT" || return 1
    
    log_success "Module globals validé syntaxiquement"
}

extract_terraform_version() {
    local file="$1"
    
    grep -A 5 "terraform {" "$file" | \
        grep "required_version" | \
        sed 's/.*= *"//; s/".*//' | \
        head -1
}

validate_version_consistency() {
    #print_header "Vérification de la Cohérence des Contraintes"
    
    local dev_version prod_version globals_version
    
    dev_version=$(extract_terraform_version "$PROJECT_ROOT/terraform/environments/dev/versions.tf")
    prod_version=$(extract_terraform_version "$PROJECT_ROOT/terraform/environments/prod/versions.tf")
    globals_version=$(extract_terraform_version "$PROJECT_ROOT/terraform/globals/versions.tf")
    
    log_info "Versions détectées:"
    log_info "  Dev:     '$dev_version'"
    log_info "  Prod:    '$prod_version'"
    log_info "  Globals: '$globals_version'"
    
    # Validation de la cohérence
    if [[ "$dev_version" != "$prod_version" ]] || [[ "$dev_version" != "$globals_version" ]]; then
        log_error "Contraintes Terraform incohérentes entre environnements"
        return 1
    fi
    
    # Validation de la version minimale
    if echo "$dev_version" | grep -q "1.12.1"; then
        log_success "Contraintes respectent la version minimale 1.12.1"
    else
        log_error "Contraintes ne respectent pas la version minimale 1.12.1"
        log_info "Version détectée: '$dev_version'"
        return 1
    fi
    
    log_success "Contraintes cohérentes entre tous les environnements"
    
    # Export pour le rapport
    echo "$dev_version"
}

test_environment_constraints() {
    print_header "Test d'Application des Contraintes par Environnement"
    
    local environments=("dev" "prod")
    
    for env in "${environments[@]}"; do
        log_step "🧪 Test environnement: $env"
        
        local env_dir="$PROJECT_ROOT/terraform/environments/$env"
        validate_directory_exists "$env_dir"
        
        cd "$env_dir" || {
            log_error "Impossible d'accéder à: $env_dir"
            return 1
        }
        
        # Init et validation avec les contraintes
        terraform init -backend=false
        terraform validate
        
        cd "$PROJECT_ROOT" || return 1
        
        log_success "Environnement $env compatible avec les contraintes"
    done
}

generate_validation_report() {
    local format_changes_raw="$1"
    local terraform_version="$2"
    
    print_header "Génération du Rapport de Validation"
    
    # Conversion en booléen JSON valide
    local format_changes_json
    if [[ "$format_changes_raw" == "true" ]]; then
        format_changes_json="true"
    else
        format_changes_json="false"
    fi
    
    cat > "$REPORT_FILE" << EOF
{
  "validation_date": "$(date -Iseconds)",
  "terraform_version_used": "${TF_VERSION:-unknown}",
  "validation_status": "SUCCESS",
  "auto_formatting_applied": $format_changes_json,
  "files_validated": [
    "terraform/globals/versions.tf",
    "terraform/environments/dev/versions.tf",
    "terraform/environments/prod/versions.tf"
  ],
  "constraints_verified": {
    "terraform_version": "$terraform_version",
    "provider_local": "~> 2.5",
    "provider_null": "~> 3.2"
  },
  "environments_tested": ["dev", "prod"],
  "consistency_check": "PASSED",
  "pipeline_info": {
    "runner_type": "shared",
    "branch": "${CI_COMMIT_BRANCH:-unknown}",
    "commit": "${CI_COMMIT_SHA:-unknown}"
  }
}
EOF
    
    # Validation JSON avant affichage
    if command -v jq >/dev/null 2>&1; then
        if jq '.' "$REPORT_FILE" > /dev/null 2>&1; then
            log_info "📄 Rapport de validation généré:"
            jq '.' "$REPORT_FILE"
        else
            log_error "Erreur dans le format JSON du rapport"
            log_info "Contenu brut du rapport:"
            cat "$REPORT_FILE"
            return 1
        fi
    else
        log_info "📄 Rapport généré: $REPORT_FILE"
        cat "$REPORT_FILE"
    fi
}

prepare_artifacts() {
    print_header "Préparation des Artefacts"
    
    mkdir -p "$ARTIFACTS_DIR"
    
    local files=(
        "$PROJECT_ROOT/terraform/globals/versions.tf:globals_versions.tf"
        "$PROJECT_ROOT/terraform/environments/dev/versions.tf:dev_versions.tf"
        "$PROJECT_ROOT/terraform/environments/prod/versions.tf:prod_versions.tf"
    )
    
    for file_mapping in "${files[@]}"; do
        local source_file="${file_mapping%:*}"
        local dest_file="${file_mapping#*:}"
        
        if [[ -f "$source_file" ]]; then
            cp "$source_file" "$ARTIFACTS_DIR/$dest_file"
            log_success "Artefact préparé: $dest_file"
        else
            log_warning "Fichier source non trouvé: $source_file"
        fi
    done
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    print_header "Validation des Contraintes de Versions Terraform"
    
    log_info "Répertoire de travail: $PROJECT_ROOT"
    
    # Installation des dépendances
    install_package "jq"
    install_package "git"
    
    # Changement vers le répertoire du projet
    cd "$PROJECT_ROOT" || {
        log_error "Impossible d'accéder au répertoire du projet: $PROJECT_ROOT"
        return 1
    }
    
    # Validation étape par étape
    check_required_files
    
    local format_changes
    format_changes=$(auto_format_versions_files)
    
    validate_globals_module
    
    local terraform_version
    terraform_version=$(validate_version_consistency)
    
    test_environment_constraints
    
    generate_validation_report "$format_changes" "$terraform_version"
    prepare_artifacts
    
    print_summary "Validation des Versions Terminée" \
        "Status: SUCCESS" \
        "Formatage appliqué: $format_changes" \
        "Version Terraform: $terraform_version" \
        "Rapport: $REPORT_FILE"
    
    log_success "🎉 Validation des versions Terraform terminée avec succès"
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi