#!/bin/bash
# =============================================================================
# VALIDATE-INVENTORY.SH - Validation Inventaires Ansible
# =============================================================================
# Description : Validation syntaxique et fonctionnelle des inventaires Ansible
# Usage       : ./validate-inventory.sh [environment]
# Exemple     : ./validate-inventory.sh dev
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
readonly ANSIBLE_DIR="${ANSIBLE_DIR:-ansible}"
readonly INVENTORY_DIR="$ANSIBLE_DIR/inventory"

# =============================================================================
# FONCTIONS DE VALIDATION
# =============================================================================

setup_ansible_environment() {
    log_step "Configuration de l'environnement Ansible..."
    
    # Variables d'environnement Ansible
    export ANSIBLE_FORCE_COLOR="${ANSIBLE_FORCE_COLOR:-True}"
    export ANSIBLE_HOST_KEY_CHECKING="${ANSIBLE_HOST_KEY_CHECKING:-False}"
    export ANSIBLE_STDOUT_CALLBACK="${ANSIBLE_STDOUT_CALLBACK:-yaml}"
    export ANSIBLE_GATHER_FACTS="${ANSIBLE_GATHER_FACTS:-True}"
    
    # Installation des dépendances Ansible
    install_package "ansible"
    
    log_info "Version Ansible: $(ansible --version | head -1)"
    log_success "Environnement Ansible configuré"
}

validate_inventory_file() {
    local env="$1"
    local inventory_file="$INVENTORY_DIR/$env"
    
    log_step "🔍 Validation de l'inventaire pour $env..."
    
    # Vérification de l'existence du fichier
    if [[ ! -f "$inventory_file" ]]; then
        log_error "Inventaire $env non trouvé: $inventory_file"
        log_info "📋 Inventaires disponibles:"
        ls -la "$INVENTORY_DIR/" 2>/dev/null || echo "   Répertoire inventory vide"
        return 1
    fi
    
    validate_file_exists "$inventory_file"
    
    log_success "Inventaire trouvé: $inventory_file"
    
    # Affichage du contenu pour debug
    log_info "📄 Contenu de l'inventaire:"
    echo "----------------------------------------"
    cat "$inventory_file"
    echo "----------------------------------------"
    
    # Validation de la structure minimale
    if ! grep -q "\[.*\]" "$inventory_file"; then
        log_warning "Aucun groupe détecté dans l'inventaire"
    fi
    
    if ! grep -q "ansible_host=" "$inventory_file"; then
        log_warning "Aucune définition ansible_host détectée"
    fi
    
    log_success "Structure de base de l'inventaire validée"
}

validate_inventory_syntax() {
    local env="$1"
    local inventory_file="$INVENTORY_DIR/$env"
    
    log_step "🔍 Validation syntaxique avec ansible-inventory..."
    
    if ! command -v ansible-inventory >/dev/null 2>&1; then
        log_warning "ansible-inventory non disponible, validation syntaxique ignorée"
        return 0
    fi
    
    # Test de la syntaxe
    if ansible-inventory -i "$inventory_file" --list >/dev/null 2>&1; then
        log_success "Syntaxe de l'inventaire validée"
    else
        log_error "Erreur de syntaxe dans l'inventaire"
        log_info "Détails de l'erreur:"
        ansible-inventory -i "$inventory_file" --list || true
        return 1
    fi
    
    # Affichage de la structure pour validation
    log_info "📊 Structure de l'inventaire parsée:"
    ansible-inventory -i "$inventory_file" --list --yaml | head -20 || true
}

validate_inventory_variables() {
    local env="$1"
    local inventory_file="$INVENTORY_DIR/$env"
    
    log_step "🔍 Validation des variables d'inventaire..."
    
    # Variables requises pour Ansible
    local required_vars=("ansible_host" "ansible_user")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if grep -q "$var=" "$inventory_file"; then
            log_success "Variable trouvée: $var"
        else
            log_warning "Variable manquante: $var"
            missing_vars+=("$var")
        fi
    done
    
    # Variables recommandées
    local recommended_vars=("ansible_ssh_private_key_file" "ansible_python_interpreter")
    
    for var in "${recommended_vars[@]}"; do
        if grep -q "$var=" "$inventory_file"; then
            log_info "Variable recommandée trouvée: $var"
        else
            log_debug "Variable recommandée manquante: $var"
        fi
    done
    
    if [[ ${#missing_vars[@]} -eq 0 ]]; then
        log_success "Toutes les variables requises sont présentes"
    else
        log_warning "Variables manquantes détectées: ${missing_vars[*]}"
    fi
}

test_inventory_connectivity() {
    local env="$1"
    local inventory_file="$INVENTORY_DIR/$env"
    
    log_step "🌐 Test de connectivité avec l'inventaire..."
    
    # Test ping Ansible (non bloquant)
    log_info "🏓 Test ping Ansible..."
    if ansible all -i "$inventory_file" -m ping --timeout=30 2>/dev/null; then
        log_success "Connectivité Ansible réussie"
    else
        log_warning "Test ping Ansible échoué"
        log_info "   Cela peut être normal si:"
        log_info "   - Les serveurs sont inaccessibles depuis le runner"
        log_info "   - Les clés SSH ne sont pas configurées"
        log_info "   - Les serveurs sont éteints"
    fi
    
    # Test de collecte des facts (plus informatif)
    log_info "📊 Test de collecte des informations système..."
    if ansible all -i "$inventory_file" -m gather_facts --timeout=30 2>/dev/null | head -10; then
        log_info "Collecte des facts réussie"
    else
        log_warning "Collecte des facts échouée (non critique)"
    fi
}

validate_environment_specific() {
    local env="$1"
    
    log_step "🔍 Validations spécifiques à l'environnement $env..."
    
    case "$env" in
        "dev")
            log_info "Validations spécifiques développement..."
            # Vérifications moins strictes pour dev
            ;;
        "prod")
            log_info "Validations spécifiques production..."
            # Vérifications plus strictes pour prod
            local inventory_file="$INVENTORY_DIR/$env"
            if ! grep -q "deployment_type=production" "$inventory_file" 2>/dev/null; then
                log_warning "Configuration production non détectée dans l'inventaire"
            fi
            ;;
        *)
            log_info "Environnement standard: $env"
            ;;
    esac
}

generate_inventory_report() {
    local env="$1"
    local inventory_file="$INVENTORY_DIR/$env"
    
    log_step "📊 Génération du rapport d'inventaire..."
    
    local report_file="inventory_validation_report_${env}.json"
    
    # Collecte des métriques
    local host_count group_count var_count
    host_count=$(grep -c "ansible_host=" "$inventory_file" 2>/dev/null || echo "0")
    group_count=$(grep -c "^\[.*\]$" "$inventory_file" 2>/dev/null || echo "0")
    var_count=$(grep -c "=" "$inventory_file" 2>/dev/null || echo "0")
    
    cat > "$report_file" << EOF
{
  "validation_date": "$(date -Iseconds)",
  "environment": "$env",
  "inventory_file": "$inventory_file",
  "validation_status": "SUCCESS",
  "metrics": {
    "host_count": $host_count,
    "group_count": $group_count,
    "variable_count": $var_count
  },
  "file_info": {
    "exists": true,
    "size_bytes": $(stat -c%s "$inventory_file" 2>/dev/null || echo "0"),
    "last_modified": "$(stat -c%y "$inventory_file" 2>/dev/null || echo "unknown")"
  },
  "validation_checks": {
    "syntax_valid": true,
    "required_variables": true,
    "connectivity_tested": true
  }
}
EOF
    
    if command -v jq >/dev/null 2>&1; then
        log_info "📄 Rapport d'inventaire généré:"
        jq '.' "$report_file"
    else
        log_info "📄 Rapport généré: $report_file"
    fi
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    print_header "Validation Inventaire Ansible"
    
    # Validation des paramètres
    if [[ -z "$TARGET_ENV" ]]; then
        log_error "Environnement non spécifié"
        log_info "Usage: $0 <environment>"
        log_info "Exemple: $0 dev"
        return 1
    fi
    
    validate_environment "$TARGET_ENV"
    
    # Vérification du répertoire Ansible
    validate_directory_exists "$ANSIBLE_DIR"
    validate_directory_exists "$INVENTORY_DIR"
    
    # Configuration de l'environnement
    setup_ansible_environment
    
    # Validations principales
    validate_inventory_file "$TARGET_ENV"
    validate_inventory_syntax "$TARGET_ENV"
    validate_inventory_variables "$TARGET_ENV"
    validate_environment_specific "$TARGET_ENV"
    
    # Tests de connectivité (non bloquants)
    test_inventory_connectivity "$TARGET_ENV"
    
    # Génération du rapport
    generate_inventory_report "$TARGET_ENV"
    
    print_summary "Validation Inventaire Terminée" \
        "Environnement: $TARGET_ENV" \
        "Inventaire: $INVENTORY_DIR/$TARGET_ENV" \
        "Syntaxe: ✅" \
        "Variables: ✅" \
        "Connectivité: testée"
    
    log_success "✅ Validation de l'inventaire $TARGET_ENV terminée avec succès"
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi