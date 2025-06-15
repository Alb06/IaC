#!/bin/bash
# =============================================================================
# ERROR-HANDLING.SH - Gestion Standardisée des Erreurs CI/CD
# =============================================================================
# Description : Script de gestion d'erreurs pour after_script GitLab CI
# Usage       : ./error-handling.sh (appelé automatiquement en after_script)
# Auteur      : Infrastructure Team
# Version     : 1.0.0
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly ERROR_REPORTING="${ERROR_REPORTING:-true}"
readonly JOB_STATUS="${CI_JOB_STATUS:-unknown}"
ERROR_LOGS_DIR="/tmp/error_logs_$(date +%Y%m%d_%H%M%S)"
readonly ERROR_LOGS_DIR

# =============================================================================
# FONCTIONS DE GESTION D'ERREURS
# =============================================================================

collect_error_information() {
    log_info "📋 Collecte des informations d'erreur..."
    
    echo "=== INFORMATIONS JOB ==="
    echo "Job: ${CI_JOB_NAME:-unknown}"
    echo "Status: $JOB_STATUS"
    echo "Stage: ${CI_JOB_STAGE:-unknown}"
    echo "Pipeline: ${CI_PIPELINE_ID:-unknown}"
    echo "Commit: ${CI_COMMIT_SHA:-unknown}"
    echo "Branche: ${CI_COMMIT_BRANCH:-unknown}"
    echo "Auteur: ${GITLAB_USER_NAME:-unknown} (${GITLAB_USER_EMAIL:-unknown})"
    echo "Runner: ${CI_RUNNER_DESCRIPTION:-unknown}"
    echo "Timestamp: $(date -Iseconds)"
    echo ""
}

save_error_logs() {
    if [[ "$ERROR_REPORTING" != "true" ]]; then
        log_debug "Sauvegarde des logs désactivée"
        return 0
    fi
    
    log_step "💾 Sauvegarde des logs d'erreur..."
    
    mkdir -p "$ERROR_LOGS_DIR" 2>/dev/null || {
        log_warning "Impossible de créer le répertoire de logs: $ERROR_LOGS_DIR"
        return 1
    }
    
    # Sauvegarde des logs principaux
    local log_files_found=false
    
    # Recherche des fichiers de logs
    find . -maxdepth 3 -name "*.log" -type f 2>/dev/null | while read -r log_file; do
        if [[ -s "$log_file" ]]; then
            cp "$log_file" "$ERROR_LOGS_DIR/" 2>/dev/null && {
                log_debug "Log sauvegardé: $(basename "$log_file")"
                log_files_found=true
            }
        fi
    done
    
    # Sauvegarde des outputs Terraform si présents
    find . -name "plan_output.txt" -o -name "terraform_outputs.json" -type f 2>/dev/null | while read -r tf_file; do
        cp "$tf_file" "$ERROR_LOGS_DIR/" 2>/dev/null && {
            log_debug "Fichier Terraform sauvegardé: $(basename "$tf_file")"
        }
    done
    
    # Sauvegarde des informations système
    {
        echo "=== ENVIRONNEMENT SYSTÈME ==="
        env | grep -E "(CI_|GITLAB_|TF_|ANSIBLE_)" | sort
        echo ""
        echo "=== PROCESSUS ==="
        ps aux 2>/dev/null || ps -ef 2>/dev/null || echo "Impossible de lister les processus"
        echo ""
        echo "=== ESPACE DISQUE ==="
        df -h 2>/dev/null || echo "Impossible d'afficher l'espace disque"
        echo ""
        echo "=== MÉMOIRE ==="
        free -h 2>/dev/null || echo "Impossible d'afficher la mémoire"
    } > "$ERROR_LOGS_DIR/system_info.txt" 2>/dev/null
    
    local logs_count
    logs_count=$(find "$ERROR_LOGS_DIR" -type f | wc -l)
    
    if [[ $logs_count -gt 0 ]]; then
        log_success "Logs d'erreur sauvegardés dans: $ERROR_LOGS_DIR ($logs_count fichiers)"
    else
        log_info "Aucun log d'erreur spécifique trouvé"
    fi
}

generate_error_summary() {
    if [[ "$JOB_STATUS" != "failed" ]]; then
        return 0
    fi
    
    log_error "=== RÉSUMÉ D'ERREUR ==="
    log_error "❌ Job échoué: ${CI_JOB_NAME:-unknown}"
    log_error "📋 Stage: ${CI_JOB_STAGE:-unknown}"
    log_error "🌿 Branche: ${CI_COMMIT_BRANCH:-unknown}"
    log_error "📝 Commit: ${CI_COMMIT_SHA:-unknown}"
    log_error "👤 Auteur: ${GITLAB_USER_NAME:-unknown}"
    log_error "🕐 Timestamp: $(date -Iseconds)"
    
    if [[ -d "$ERROR_LOGS_DIR" ]]; then
        log_error "🔍 Logs d'erreur: $ERROR_LOGS_DIR"
    fi
    
    echo ""
}

provide_troubleshooting_hints() {
    if [[ "$JOB_STATUS" != "failed" ]]; then
        return 0
    fi
    
    case "${CI_JOB_STAGE:-unknown}" in
        "validate")
            log_info "💡 Conseils pour les erreurs de validation:"
            log_info "   - Vérifier la syntaxe Terraform/Ansible"
            log_info "   - Contrôler les versions des outils"
            log_info "   - Valider les contraintes de versions"
            ;;
        "plan")
            log_info "💡 Conseils pour les erreurs de planification:"
            log_info "   - Vérifier les variables d'environnement"
            log_info "   - Contrôler les permissions du state"
            log_info "   - Valider la configuration des providers"
            ;;
        "apply")
            log_info "💡 Conseils pour les erreurs d'application:"
            log_info "   - Vérifier la connectivité aux ressources"
            log_info "   - Contrôler les quotas et limites"
            log_info "   - Examiner les logs des providers"
            ;;
        "deploy")
            log_info "💡 Conseils pour les erreurs de déploiement:"
            log_info "   - Vérifier la connectivité Ansible"
            log_info "   - Contrôler les inventaires"
            log_info "   - Valider les playbooks"
            ;;
        *)
            log_info "💡 Conseils généraux:"
            log_info "   - Examiner les logs détaillés ci-dessus"
            log_info "   - Vérifier les variables d'environnement"
            log_info "   - Contrôler les permissions"
            ;;
    esac
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    # En cas de succès, sortie rapide
    if [[ "$JOB_STATUS" == "success" ]]; then
        log_success "✅ Job terminé avec succès: ${CI_JOB_NAME:-unknown}"
        return 0
    fi
    
    # Gestion des erreurs
    collect_error_information
    save_error_logs
    generate_error_summary
    provide_troubleshooting_hints
    
    # Retour du code d'erreur approprié (non bloquant pour after_script)
    return 0
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi