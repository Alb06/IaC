#!/bin/bash
# =============================================================================
# VALIDATE-MANIFESTS.SH - Validation Manifests Kubernetes (CORRIGÉ OFFLINE)
# =============================================================================
# Description : Validation syntaxique offline des manifests K8s
# Usage       : ./validate-manifests.sh [manifest_path]
# Exemple     : ./validate-manifests.sh kubernetes/manifests
# Auteur      : Infrastructure Team
# Version     : 1.0.1 - Support validation offline
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly MANIFEST_PATH="${1:-${MANIFEST_PATH:-kubernetes/manifests}}"
readonly VALIDATION_REPORT="manifest_validation_report.json"
readonly CLUSTER_ACCESSIBLE="${CLUSTER_ACCESSIBLE:-auto}"

# =============================================================================
# FONCTIONS DE DÉTECTION
# =============================================================================

detect_cluster_connectivity() {
    log_step "🔌 Détection de la connectivité cluster..."
    
    # Si forcé via variable d'environnement
    if [[ "$CLUSTER_ACCESSIBLE" == "true" ]]; then
        log_info "Connectivité cluster forcée à true"
        echo "true"
        return 0
    elif [[ "$CLUSTER_ACCESSIBLE" == "false" ]]; then
        log_info "Connectivité cluster forcée à false"
        echo "false"
        return 0
    fi
    
    # Détection automatique
    if kubectl cluster-info >/dev/null 2>&1; then
        log_success "Cluster Kubernetes accessible - validation online"
        echo "true"
        return 0
    else
        log_warning "Cluster Kubernetes non accessible - validation offline"
        echo "false"
        return 0
    fi
}

install_validation_tools() {
    log_step "🔧 Installation des outils de validation..."
    
    # Installation de yq pour validation YAML
    if ! command -v yq >/dev/null 2>&1; then
        log_info "Installation de yq..."
        local yq_version="v4.44.3"
        local yq_binary="/usr/local/bin/yq"
        
        curl -SL "https://github.com/mikefarah/yq/releases/download/${yq_version}/yq_linux_amd64" -o "$yq_binary"
        chmod +x "$yq_binary"
        
        if command -v yq >/dev/null 2>&1; then
            log_success "yq installé: $(yq --version)"
        else
            log_warning "Installation yq échouée, fallback sur validation basique"
        fi
    else
        log_success "yq déjà disponible: $(yq --version)"
    fi
}

# =============================================================================
# FONCTIONS DE VALIDATION
# =============================================================================

validate_yaml_syntax_basic() {
    local manifest_file="$1"
    
    log_debug "Validation YAML basique: $(basename "$manifest_file")"
    
    # Validation avec yq si disponible
    if command -v yq >/dev/null 2>&1; then
        if yq eval '.' "$manifest_file" >/dev/null 2>&1; then
            log_debug "  ✅ YAML valide (yq)"
            return 0
        else
            log_error "YAML invalide (yq): $manifest_file"
            yq eval '.' "$manifest_file" 2>&1 | head -3
            return 1
        fi
    fi
    
    # Fallback avec python si disponible
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "
import yaml
import sys
try:
    with open('$manifest_file', 'r') as f:
        yaml.safe_load_all(f)
    print('YAML valide')
except Exception as e:
    print(f'YAML invalide: {e}')
    sys.exit(1)
" >/dev/null 2>&1; then
            log_debug "  ✅ YAML valide (python)"
            return 0
        else
            log_error "YAML invalide (python): $manifest_file"
            return 1
        fi
    fi
    
    # Fallback basique - vérification de structure minimale
    log_debug "Validation YAML basique (fallback)"
    if grep -q "apiVersion:" "$manifest_file" && \
       grep -q "kind:" "$manifest_file" && \
       grep -q "metadata:" "$manifest_file"; then
        log_debug "  ✅ Structure YAML basique valide"
        return 0
    else
        log_error "Structure YAML invalide: $manifest_file"
        return 1
    fi
}

validate_yaml_syntax_online() {
    local manifest_file="$1"
    
    log_debug "Validation Kubernetes online: $(basename "$manifest_file")"
    
    # Validation avec cluster accessible
    if kubectl apply --dry-run=client -f "$manifest_file" >/dev/null 2>&1; then
        log_debug "  ✅ Kubernetes valide (online)"
        return 0
    else
        log_error "Kubernetes invalide: $manifest_file"
        log_info "Détails de l'erreur:"
        kubectl apply --dry-run=client -f "$manifest_file" 2>&1 | head -3
        return 1
    fi
}

validate_yaml_syntax_offline() {
    local manifest_file="$1"
    
    log_debug "Validation Kubernetes offline: $(basename "$manifest_file")"
    
    # Validation offline avec --validate=false
    if kubectl apply --dry-run=client --validate=false -f "$manifest_file" >/dev/null 2>&1; then
        log_debug "  ✅ Structure Kubernetes valide (offline)"
        return 0
    else
        # Fallback sur validation YAML basique
        log_debug "Fallback sur validation YAML basique"
        validate_yaml_syntax_basic "$manifest_file"
        return $?
    fi
}

validate_yaml_syntax() {
    local manifest_file="$1"
    local cluster_accessible="$2"
    
    log_debug "Validation syntaxe: $(basename "$manifest_file") (cluster: $cluster_accessible)"
    
    # Choix de la méthode de validation
    if [[ "$cluster_accessible" == "true" ]]; then
        validate_yaml_syntax_online "$manifest_file"
    else
        validate_yaml_syntax_offline "$manifest_file"
    fi
}

validate_manifest_structure() {
    local manifest_file="$1"
    
    log_debug "Validation structure: $(basename "$manifest_file")"
    
    # Vérifications basiques de structure
    local has_apiversion has_kind has_metadata
    
    has_apiversion=$(grep -c "apiVersion:" "$manifest_file" 2>/dev/null || echo "0")
    has_kind=$(grep -c "kind:" "$manifest_file" 2>/dev/null || echo "0")
    has_metadata=$(grep -c "metadata:" "$manifest_file" 2>/dev/null || echo "0")
    
    if [[ $has_apiversion -eq 0 ]]; then
        log_error "apiVersion manquant dans: $manifest_file"
        return 1
    fi
    
    if [[ $has_kind -eq 0 ]]; then
        log_error "kind manquant dans: $manifest_file"
        return 1
    fi
    
    if [[ $has_metadata -eq 0 ]]; then
        log_error "metadata manquant dans: $manifest_file"
        return 1
    fi
    
    return 0
}

validate_kubernetes_best_practices() {
    local manifest_file="$1"
    
    log_debug "Validation best practices: $(basename "$manifest_file")"
    
    # Vérifications de bonnes pratiques
    local warnings=0
    
    # Vérification des labels recommandés
    if ! grep -q "app.kubernetes.io/" "$manifest_file"; then
        log_debug "  ⚠️  Labels recommandés manquants (app.kubernetes.io/*)"
        warnings=$((warnings + 1))
    fi
    
    # Vérification des limites de ressources pour les Deployments
    if grep -q "kind: Deployment" "$manifest_file"; then
        if ! grep -q "resources:" "$manifest_file"; then
            log_debug "  ⚠️  Deployment sans limites de ressources"
            warnings=$((warnings + 1))
        fi
    fi
    
    # Vérification des NetworkPolicies
    if grep -q "kind: NetworkPolicy" "$manifest_file"; then
        if ! grep -q "policyTypes:" "$manifest_file"; then
            log_warning "NetworkPolicy sans policyTypes: $manifest_file"
            warnings=$((warnings + 1))
        fi
    fi
    
    # Vérification des RBAC
    if grep -q "kind: Role\|kind: ClusterRole" "$manifest_file"; then
        if ! grep -q "rules:" "$manifest_file"; then
            log_error "Role/ClusterRole sans règles: $manifest_file"
            return 1
        fi
    fi
    
    if [[ $warnings -gt 0 ]]; then
        log_debug "  ⚠️  $warnings avertissements best practices"
    fi
    
    return 0
}

scan_manifest_directory() {
    local dir_path="$1"
    local cluster_accessible="$2"
    local validation_errors=0
    local total_files=0
    local validated_files=()
    local error_files=()
    
    log_step "📁 Scan du répertoire: $dir_path (mode: $([ "$cluster_accessible" == "true" ] && echo "online" || echo "offline"))"
    
    if [[ ! -d "$dir_path" ]]; then
        log_error "Répertoire non trouvé: $dir_path"
        return 1
    fi
    
    # Recherche récursive des fichiers YAML/YML
    local yaml_files
    mapfile -t yaml_files < <(find "$dir_path" -type f \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null)
    
    if [[ ${#yaml_files[@]} -eq 0 ]]; then
        log_warning "Aucun fichier YAML trouvé dans: $dir_path"
        return 0
    fi
    
    log_info "📊 ${#yaml_files[@]} fichiers YAML trouvés"
    
    for yaml_file in "${yaml_files[@]}"; do
        local relative_path
        relative_path=${yaml_file#$PROJECT_ROOT/}
        
        log_step "🔍 Validation: $relative_path"
        total_files=$((total_files + 1))
        
        # Validation syntaxique
        if ! validate_yaml_syntax "$yaml_file" "$cluster_accessible"; then
            validation_errors=$((validation_errors + 1))
            error_files+=("$relative_path")
            continue
        fi
        
        # Validation structure
        if ! validate_manifest_structure "$yaml_file"; then
            validation_errors=$((validation_errors + 1))
            error_files+=("$relative_path")
            continue
        fi
        
        # Validation best practices
        if ! validate_kubernetes_best_practices "$yaml_file"; then
            validation_errors=$((validation_errors + 1))
            error_files+=("$relative_path")
            continue
        fi
        
        validated_files+=("$relative_path")
        log_success "  ✅ $(basename "$yaml_file")"
    done
    
    # Résumé de la validation
    log_info "📊 Résultats de validation:"
    log_info "  Total files: $total_files"
    log_info "  Validated: ${#validated_files[@]}"
    log_info "  Errors: $validation_errors"
    
    if [[ $validation_errors -gt 0 ]]; then
        log_error "Fichiers avec erreurs:"
        for error_file in "${error_files[@]}"; do
            log_error "  ❌ $error_file"
        done
        return 1
    fi
    
    log_success "Tous les manifests sont valides"
    return 0
}

validate_namespace_manifests() {
    local namespaces_dir="$PROJECT_ROOT/kubernetes/namespaces"
    
    log_step "🏗️  Validation des manifests de namespaces..."
    
    if [[ ! -d "$namespaces_dir" ]]; then
        log_error "Répertoire namespaces non trouvé: $namespaces_dir"
        return 1
    fi
    
    local expected_namespaces=("automation" "databases" "cache" "monitoring")
    local missing_namespaces=()
    
    for namespace in "${expected_namespaces[@]}"; do
        local namespace_file="$namespaces_dir/${namespace}.yaml"
        if [[ -f "$namespace_file" ]]; then
            log_success "  ✅ $namespace.yaml"
            
            # Validation basique du contenu
            if validate_yaml_syntax_basic "$namespace_file"; then
                log_debug "    YAML valide"
            else
                log_warning "    YAML invalide: $namespace.yaml"
            fi
            
            # Validation spécifique namespace
            if ! grep -q "kind: Namespace\|kind: ResourceQuota\|kind: LimitRange" "$namespace_file"; then
                log_warning "Manifest $namespace incomplet (manque Namespace/ResourceQuota/LimitRange)"
            fi
        else
            log_error "  ❌ $namespace.yaml (manquant)"
            missing_namespaces+=("$namespace")
        fi
    done
    
    if [[ ${#missing_namespaces[@]} -gt 0 ]]; then
        log_error "Namespaces manquants: ${missing_namespaces[*]}"
        return 1
    fi
    
    return 0
}

check_kubectl_connectivity() {
    log_step "🔌 Test de connectivité kubectl..."
    
    # Test basique sans cluster
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl non disponible"
        return 1
    fi
    
    log_success "kubectl disponible"
    
    # Détection de la connectivité
    local cluster_accessible
    cluster_accessible=$(detect_cluster_connectivity)
    
    if [[ "$cluster_accessible" == "true" ]]; then
        log_success "Cluster Kubernetes accessible"
        
        # Informations cluster
        log_info "📊 Informations cluster:"
        kubectl cluster-info 2>/dev/null | head -3 || true
    else
        log_warning "Cluster Kubernetes non accessible (normal pour la validation locale)"
        log_info "La validation utilisera le mode offline"
    fi
    
    echo "$cluster_accessible"
}

generate_validation_report() {
    local manifest_path="$1"
    local validation_status="$2"
    local cluster_accessible="$3"
    
    log_step "📊 Génération du rapport de validation..."
    
    # Collecte des statistiques
    local total_yamls namespace_yamls rbac_yamls network_policy_yamls storage_yamls
    
    total_yamls=$(find "$PROJECT_ROOT/$manifest_path" -name "*.yaml" -type f 2>/dev/null | wc -l)
    namespace_yamls=$(find "$PROJECT_ROOT/kubernetes/namespaces" -name "*.yaml" -type f 2>/dev/null | wc -l)
    rbac_yamls=$(find "$PROJECT_ROOT/kubernetes/manifests/rbac" -name "*.yaml" -type f 2>/dev/null | wc -l)
    network_policy_yamls=$(find "$PROJECT_ROOT/kubernetes/manifests/network-policies" -name "*.yaml" -type f 2>/dev/null | wc -l)
    storage_yamls=$(find "$PROJECT_ROOT/kubernetes/manifests/storage-classes" -name "*.yaml" -type f 2>/dev/null | wc -l)
    
    cat > "$VALIDATION_REPORT" << EOF
{
  "validation_date": "$(date -Iseconds)",
  "manifest_path": "$manifest_path",
  "validation_status": "$validation_status",
  "validation_mode": "$([ "$cluster_accessible" == "true" ] && echo "online" || echo "offline")",
  "kubectl_available": $(command -v kubectl >/dev/null 2>&1 && echo "true" || echo "false"),
  "cluster_accessible": $cluster_accessible,
  "yq_available": $(command -v yq >/dev/null 2>&1 && echo "true" || echo "false"),
  "statistics": {
    "total_yaml_files": $total_yamls,
    "namespace_manifests": $namespace_yamls,
    "rbac_manifests": $rbac_yamls,
    "network_policy_manifests": $network_policy_yamls,
    "storage_class_manifests": $storage_yamls
  },
  "expected_namespaces": ["automation", "databases", "cache", "monitoring"],
  "validation_checks": {
    "yaml_syntax": true,
    "manifest_structure": true,
    "kubernetes_best_practices": true,
    "namespace_completeness": true
  },
  "tools_used": {
    "kubectl": "$(kubectl version --client 2>/dev/null | head -1 || echo 'unknown')",
    "yq": "$(yq --version 2>/dev/null || echo 'not available')"
  }
}
EOF
    
    if command -v jq >/dev/null 2>&1; then
        log_info "📄 Rapport de validation généré:"
        jq '.' "$VALIDATION_REPORT"
    else
        log_info "📄 Rapport généré: $VALIDATION_REPORT"
    fi
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    print_header "Validation Manifests Kubernetes"
    
    log_info "Path des manifests: $MANIFEST_PATH"
    log_info "Répertoire de travail: $PROJECT_ROOT"
    
    # Installation des outils de validation
    install_validation_tools
    
    # Vérification de l'installation kubectl et détection connectivité
    local cluster_accessible
    cluster_accessible=$(check_kubectl_connectivity)
    
    # Validation des manifests généraux
    local validation_success=true
    
    if ! scan_manifest_directory "$PROJECT_ROOT/$MANIFEST_PATH" "$cluster_accessible"; then
        validation_success=false
    fi
    
    # Validation spécifique des namespaces
    if ! validate_namespace_manifests; then
        validation_success=false
    fi
    
    # Génération du rapport
    local status
    if [[ "$validation_success" == "true" ]]; then
        status="SUCCESS"
    else
        status="FAILED"
    fi
    
    generate_validation_report "$MANIFEST_PATH" "$status" "$cluster_accessible"
    
    if [[ "$validation_success" == "true" ]]; then
        print_summary "Validation Manifests Terminée" \
            "Status: SUCCESS" \
            "Mode: $([ "$cluster_accessible" == "true" ] && echo "online" || echo "offline")" \
            "Path: $MANIFEST_PATH" \
            "Rapport: $VALIDATION_REPORT"
        
        log_success "🎉 Validation des manifests terminée avec succès"
        return 0
    else
        print_summary "Validation Manifests Échouée" \
            "Status: FAILED" \
            "Mode: $([ "$cluster_accessible" == "true" ] && echo "online" || echo "offline")" \
            "Path: $MANIFEST_PATH" \
            "Rapport: $VALIDATION_REPORT"
        
        log_error "❌ Validation des manifests échouée"
        return 1
    fi
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi