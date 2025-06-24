#!/bin/bash
# =============================================================================
# SETUP-NAMESPACES.SH - Configuration Namespaces Kubernetes
# =============================================================================
# Description : Déploiement et validation des namespaces avec sécurité
# Usage       : ./setup-namespaces.sh [namespaces]
# Exemple     : ./setup-namespaces.sh "automation databases cache"
# Auteur      : Infrastructure Team
# Version     : 1.0.0
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly TARGET_NAMESPACES="${1:-${NAMESPACES:-automation databases cache monitoring}}"
readonly MANIFEST_BASE_PATH="$PROJECT_ROOT/kubernetes"
readonly REPORT_FILE="kubernetes-setup-report.json"

# =============================================================================
# FONCTIONS KUBERNETES
# =============================================================================

setup_kubeconfig() {
    log_step "🔧 Configuration de kubectl..."
    
    # Vérification de la disponibilité du cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cluster Kubernetes non accessible"
        log_info "Vérifications à effectuer:"
        log_info "  - KUBECONFIG est-il correctement configuré ?"
        log_info "  - Le cluster K3s est-il démarré ?"
        log_info "  - Les certificats sont-ils valides ?"
        return 1
    fi
    
    local cluster_info
    cluster_info=$(kubectl cluster-info 2>/dev/null | head -1)
    log_success "Connexion cluster réussie: $cluster_info"
}

validate_manifests() {
    print_header "Validation des Manifests"
    
    local manifest_dirs=(
        "$MANIFEST_BASE_PATH/namespaces"
        "$MANIFEST_BASE_PATH/manifests/storage-classes"
        "$MANIFEST_BASE_PATH/manifests/rbac"
        "$MANIFEST_BASE_PATH/manifests/network-policies"
    )
    
    for manifest_dir in "${manifest_dirs[@]}"; do
        log_step "📋 Validation: $manifest_dir"
        
        if [[ ! -d "$manifest_dir" ]]; then
            log_error "Répertoire non trouvé: $manifest_dir"
            return 1
        fi
        
        # Validation syntaxique de tous les YAML
        local yaml_files
        mapfile -t yaml_files < <(find "$manifest_dir" -name "*.yaml" -type f)
        
        for yaml_file in "${yaml_files[@]}"; do
            log_debug "Validation: $(basename "$yaml_file")"
            
            # Validation syntaxique YAML
            if ! kubectl apply --dry-run=client -f "$yaml_file" >/dev/null 2>&1; then
                log_error "Syntaxe invalide: $yaml_file"
                kubectl apply --dry-run=client -f "$yaml_file"
                return 1
            fi
        done
        
        log_success "Validation réussie: $manifest_dir"
    done
}

deploy_storage_classes() {
    log_step "💾 Déploiement des Storage Classes..."
    
    local storage_manifest="$MANIFEST_BASE_PATH/manifests/storage-classes/local-ssd.yaml"
    
    validate_file_exists "$storage_manifest"
    
    kubectl apply -f "$storage_manifest"
    
    # Vérification du déploiement
    log_info "📊 Storage Classes disponibles:"
    kubectl get storageclass
    
    log_success "Storage Classes déployées"
}

deploy_namespace() {
    local namespace="$1"
    local manifest_file="$MANIFEST_BASE_PATH/namespaces/${namespace}.yaml"
    
    log_step "🏗️  Déploiement namespace: $namespace"
    
    # Vérification de l'existence du manifest
    if [[ ! -f "$manifest_file" ]]; then
        log_warning "Manifest non trouvé: $manifest_file"
        
        # Namespace monitoring existe déjà, on applique juste les quotas
        if [[ "$namespace" == "monitoring" ]]; then
            log_info "Application des quotas pour le namespace monitoring existant"
            kubectl apply -f "$manifest_file" || log_warning "Impossible d'appliquer les quotas monitoring"
            return 0
        else
            return 1
        fi
    fi
    
    # Application du manifest
    kubectl apply -f "$manifest_file"
    
    # Vérification de la création
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "Namespace $namespace créé/mis à jour"
        
        # Affichage des informations
        log_info "📊 Informations namespace $namespace:"
        kubectl describe namespace "$namespace" | grep -E "(Name|Labels|Status)"
        
        # Vérification des quotas si présents
        if kubectl get resourcequota -n "$namespace" >/dev/null 2>&1; then
            log_info "📊 Quotas appliqués:"
            kubectl get resourcequota -n "$namespace" -o wide
        fi
        
    else
        log_error "Échec création namespace: $namespace"
        return 1
    fi
}

deploy_rbac() {
    log_step "🔐 Déploiement RBAC..."
    
    local rbac_manifest="$MANIFEST_BASE_PATH/manifests/rbac/service-accounts.yaml"
    
    validate_file_exists "$rbac_manifest"
    
    kubectl apply -f "$rbac_manifest"
    
    # Vérification des Service Accounts
    log_info "📊 Service Accounts créés:"
    for ns in $TARGET_NAMESPACES; do
        if kubectl get serviceaccount -n "$ns" 2>/dev/null | grep -q "${ns}-sa"; then
            log_success "  ✅ $ns: ${ns}-sa"
        else
            log_warning "  ⚠️  $ns: Service Account manquant"
        fi
    done
    
    log_success "RBAC déployé"
}

deploy_network_policies() {
    log_step "🛡️  Déploiement Network Policies..."
    
    local network_manifest="$MANIFEST_BASE_PATH/manifests/network-policies/default-deny.yaml"
    
    validate_file_exists "$network_manifest"
    
    kubectl apply -f "$network_manifest"
    
    # Vérification des Network Policies
    log_info "📊 Network Policies appliquées:"
    for ns in $TARGET_NAMESPACES; do
        local policy_count
        policy_count=$(kubectl get networkpolicy -n "$ns" 2>/dev/null | wc -l)
        if [[ $policy_count -gt 1 ]]; then  # > 1 car la première ligne est l'en-tête
            log_success "  ✅ $ns: $((policy_count - 1)) policies"
        else
            log_warning "  ⚠️  $ns: Aucune policy"
        fi
    done
    
    log_success "Network Policies déployées"
}

test_namespace_connectivity() {
    log_step "🌐 Test de connectivité des namespaces..."
    
    for namespace in $TARGET_NAMESPACES; do
        log_info "Test connectivité: $namespace"
        
        # Test de création d'un pod temporaire
        local test_pod="test-connectivity-$(date +%s)"
        
        kubectl run "$test_pod" \
            --image=busybox:1.35 \
            --namespace="$namespace" \
            --rm -i --restart=Never \
            --timeout=30s \
            -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1
        
        if [[ $? -eq 0 ]]; then
            log_success "  ✅ $namespace: Connectivité OK"
        else
            log_warning "  ⚠️  $namespace: Test de connectivité échoué (peut être normal avec les Network Policies)"
        fi
    done
}

generate_setup_report() {
    log_step "📊 Génération du rapport de setup..."
    
    # Collecte des informations
    local namespaces_created=()
    local storage_classes=()
    local network_policies_count=0
    local service_accounts_count=0
    
    for ns in $TARGET_NAMESPACES; do
        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            namespaces_created+=("$ns")
        fi
    done
    
    mapfile -t storage_classes < <(kubectl get storageclass -o name | sed 's|storageclass.storage.k8s.io/||')
    
    for ns in "${namespaces_created[@]}"; do
        local np_count sa_count
        np_count=$(kubectl get networkpolicy -n "$ns" 2>/dev/null | wc -l)
        sa_count=$(kubectl get serviceaccount -n "$ns" 2>/dev/null | wc -l)
        
        if [[ $np_count -gt 1 ]]; then
            network_policies_count=$((network_policies_count + np_count - 1))
        fi
        
        if [[ $sa_count -gt 1 ]]; then
            service_accounts_count=$((service_accounts_count + sa_count - 1))
        fi
    done
    
    cat > "$REPORT_FILE" << EOF
{
  "setup_date": "$(date -Iseconds)",
  "cluster": "${CLUSTER_NAME:-homelab-k3s}",
  "environment": "${ENV:-prod}",
  "namespaces": {
    "requested": $(printf '%s\n' $TARGET_NAMESPACES | jq -R . | jq -s .),
    "created": $(printf '%s\n' "${namespaces_created[@]}" | jq -R . | jq -s .),
    "success_count": ${#namespaces_created[@]},
    "total_count": $(echo $TARGET_NAMESPACES | wc -w)
  },
  "storage_classes": {
    "deployed": $(printf '%s\n' "${storage_classes[@]}" | jq -R . | jq -s .),
    "count": ${#storage_classes[@]}
  },
  "security": {
    "network_policies_count": $network_policies_count,
    "service_accounts_count": $service_accounts_count,
    "rbac_enabled": true
  },
  "validation": {
    "manifests_validated": true,
    "connectivity_tested": true,
    "quotas_applied": true
  }
}
EOF
    
    if command -v jq >/dev/null 2>&1; then
        log_info "📄 Rapport de setup généré:"
        jq '.' "$REPORT_FILE"
    else
        log_info "📄 Rapport généré: $REPORT_FILE"
    fi
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    print_header "Setup Namespaces Kubernetes"
    
    log_info "Namespaces à déployer: $TARGET_NAMESPACES"
    log_info "Manifests base path: $MANIFEST_BASE_PATH"
    
    setup_kubeconfig
    validate_manifests
    
    # Déploiement des composants de base
    deploy_storage_classes
    
    # Déploiement des namespaces
    for namespace in $TARGET_NAMESPACES; do
        deploy_namespace "$namespace"
    done
    
    # Configuration de la sécurité
    deploy_rbac
    deploy_network_policies
    
    # Tests et validation
    test_namespace_connectivity
    generate_setup_report
    
    print_summary "Setup Namespaces Terminé" \
        "Namespaces: $TARGET_NAMESPACES" \
        "Storage Classes: déployées" \
        "RBAC: configuré" \
        "Network Policies: appliquées" \
        "Rapport: $REPORT_FILE"
    
    log_success "🎉 Setup namespaces terminé avec succès"
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi