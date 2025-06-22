#!/bin/bash
# =============================================================================
# CLEANUP-TERRAFORM.SH - Nettoyage Ressources Terraform
# =============================================================================
# Description : Nettoyage des ressources temporaires et mode récupération
# Usage       : ./cleanup-terraform.sh [--recovery]
# Exemple     : ./cleanup-terraform.sh
#               ./cleanup-terraform.sh --recovery
# Auteur      : Infrastructure Team
# Version     : 1.0.0
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly RECOVERY_MODE="${1:-${RECOVERY_MODE:-false}}"
readonly TF_ROOT="${TF_ROOT:-terraform/environments}"
readonly ENVIRONMENTS=("dev" "prod")

# =============================================================================
# FONCTIONS DE NETTOYAGE
# =============================================================================

cleanup_environment_files() {
    local env="$1"
    local env_dir="$PROJECT_ROOT/$TF_ROOT/$env"
    
    log_step "🧹 Nettoyage environnement: $env"
    
    if [[ ! -d "$env_dir" ]]; then
        log_warning "Environnement $env non trouvé: $env_dir"
        return 0
    fi
    
    cd "$env_dir" || {
        log_error "Impossible d'accéder à: $env_dir"
        return 1
    }
    
    # Nettoyage des plans anciens (> 7 jours)
    log_info "🗑️  Nettoyage des anciens plans..."
    find . -name "tfplan*" -type f -mtime +7 -delete 2>/dev/null || true
    
    # Nettoyage des sauvegardes anciennes (> 30 jours)
    log_info "🗑️  Nettoyage des anciennes sauvegardes..."
    find . -name "terraform.tfstate.backup.*" -type f -mtime +30 -delete 2>/dev/null || true
    
    # Nettoyage des outputs temporaires
    log_info "🗑️  Nettoyage des outputs temporaires..."
    find . -name "plan_output.txt" -type f -mtime +7 -delete 2>/dev/null || true
    
    # Nettoyage des rapports de validation anciens
    log_info "🗑️  Nettoyage des rapports anciens..."
    find . -name "version_validation_report.json" -type f -mtime +7 -delete 2>/dev/null || true
    find . -name "version-constraints.json" -type f -mtime +30 -delete 2>/dev/null || true
    find . -name "diagnostic_report_*.json" -type f -mtime +7 -delete 2>/dev/null || true
    
    cd "$PROJECT_ROOT" || return 1
    
    log_success "Nettoyage de $env terminé"
}

cleanup_global_temp_files() {
    log_step "🧹 Nettoyage des fichiers temporaires globaux..."
    
    # Nettoyage des logs temporaires
    find /tmp -name "*.log" -type f -mtime +1 -delete 2>/dev/null || true
    find /tmp -name "error_logs_*" -type d -mtime +3 -exec rm -rf {} + 2>/dev/null || true
    
    # Nettoyage des caches Terraform anciens
    find /tmp -name "terraform-cache-*" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    
    log_success "Nettoyage global terminé"
}

recovery_mode_cleanup() {
    print_header "Mode Récupération Activé"
    
    log_warning "⚠️  Mode récupération: nettoyage approfondi activé"
    
    for env in "${ENVIRONMENTS[@]}"; do
        local env_dir="$PROJECT_ROOT/$TF_ROOT/$env"
        
        log_step "🔧 Récupération environnement: $env"
        
        if [[ ! -d "$env_dir" ]]; then
            log_warning "Environnement $env non trouvé"
            continue
        fi
        
        cd "$env_dir" || continue
        
        # Sauvegarde des fichiers importants avant nettoyage
        if [[ -f "terraform.tfstate" ]]; then
            local backup_name="recovery_backup_$(date +%Y%m%d_%H%M%S).tfstate"
            cp "terraform.tfstate" "$backup_name"
            log_success "État sauvegardé: $backup_name"
        fi
        
        # Nettoyage des verrous Terraform
        log_info "🔓 Suppression des verrous Terraform..."
        rm -f ".terraform.tfstate.lock.info" 2>/dev/null || true
        
        # Nettoyage des plans corrompus
        log_info "🗑️  Suppression des plans potentiellement corrompus..."
        rm -f "tfplan" "tfplan.*" 2>/dev/null || true
        
        # Nettoyage des outputs corrompus
        log_info "🗑️  Suppression des outputs corrompus..."
        if [[ -f "terraform_outputs.json" ]]; then
            if ! jq '.' "terraform_outputs.json" >/dev/null 2>&1; then
                log_warning "Output JSON corrompu, suppression..."
                rm -f "terraform_outputs.json"
            fi
        fi
        
        # Réinitialisation forcée si demandée
        if [[ "${FORCE_REINIT:-false}" == "true" ]]; then
            log_warning "🔄 Réinitialisation forcée de Terraform..."
            rm -rf ".terraform" ".terraform.lock.hcl" 2>/dev/null || true
        fi
        
        cd "$PROJECT_ROOT" || return 1
        
        log_success "Récupération de $env terminée"
    done
}

generate_cleanup_report() {
    log_step "📊 Génération du rapport de nettoyage..."
    
    local report_file="cleanup_report_$(date +%Y%m%d_%H%M%S).json"
    
    # Collecte des statistiques
    local total_tf_files temp_files_count cache_dirs_count
    total_tf_files=$(find "$PROJECT_ROOT" -name "*.tf" -type f | wc -l)
    temp_files_count=$(find /tmp -name "*terraform*" -o -name "*gitlab*" | wc -l)
    cache_dirs_count=$(find /tmp -name "terraform-cache-*" -type d | wc -l)
    
    cat > "$report_file" << EOF
{
  "cleanup_date": "$(date -Iseconds)",
  "recovery_mode": "$RECOVERY_MODE",
  "project_statistics": {
    "terraform_files": $total_tf_files,
    "temp_files_remaining": $temp_files_count,
    "cache_directories": $cache_dirs_count
  },
  "environments_processed": $(printf '%s\n' "${ENVIRONMENTS[@]}" | jq -R . | jq -s .),
  "cleanup_actions": {
    "old_plans_removed": true,
    "old_backups_removed": true,
    "temp_logs_removed": true,
    "cache_cleaned": true
  }
}
EOF
    
    if command -v jq >/dev/null 2>&1; then
        log_info "📄 Rapport de nettoyage:"
        jq '.' "$report_file"
    else
        log_info "📄 Rapport généré: $report_file"
    fi
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    if [[ "$RECOVERY_MODE" == "--recovery" ]] || [[ "$RECOVERY_MODE" == "true" ]]; then
        recovery_mode_cleanup
    else
        print_header "Nettoyage Standard Terraform"
        
        for env in "${ENVIRONMENTS[@]}"; do
            cleanup_environment_files "$env"
        done
        
        cleanup_global_temp_files
    fi
    
    generate_cleanup_report
    
    print_summary "Nettoyage Terminé" \
        "Mode: $([ "$RECOVERY_MODE" == "true" ] && echo "Récupération" || echo "Standard")" \
        "Environnements: ${ENVIRONMENTS[*]}" \
        "Fichiers temporaires: nettoyés" \
        "Cache: optimisé"
    
    log_success "🎉 Nettoyage terminé avec succès"
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi