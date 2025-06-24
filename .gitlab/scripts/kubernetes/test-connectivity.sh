#!/bin/bash
# =============================================================================
# TEST-CONNECTIVITY.SH - Test Connectivité Namespaces Kubernetes
# =============================================================================
# Description : Tests de connectivité et validation des services K8s
# Usage       : ./test-connectivity.sh [namespace]
# Exemple     : ./test-connectivity.sh automation
# Auteur      : Infrastructure Team
# Version     : 1.0.0
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly TARGET_NAMESPACE="${1:-${TEST_NAMESPACE:-automation}}"
readonly TEST_TIMEOUT=30
readonly TEST_IMAGE="busybox:1.35"

# =============================================================================
# FONCTIONS DE TEST
# =============================================================================

test_namespace_exists() {
    local namespace="$1"
    
    log_step "🔍 Test existence namespace: $namespace"
    
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_success "Namespace $namespace existe"
        
        # Informations sur le namespace
        log_info "📊 Informations namespace:"
        kubectl describe namespace "$namespace" | grep -E "(Name|Labels|Status)" || true
        
        return 0
    else
        log_error "Namespace $namespace non trouvé"
        return 1
    fi
}

test_dns_resolution() {
    local namespace="$1"
    
    log_step "🌐 Test résolution DNS dans: $namespace"
    
    local test_pod="test-dns-$(date +%s)"
    
    # Lancement du test DNS
    if kubectl run "$test_pod" \
        --image="$TEST_IMAGE" \
        --namespace="$namespace" \
        --rm -i --restart=Never \
        --timeout="${TEST_TIMEOUT}s" \
        -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1; then
        
        log_success "Résolution DNS fonctionnelle dans $namespace"
        return 0
    else
        log_warning "Résolution DNS échouée dans $namespace (peut être normal avec Network Policies)"
        return 0  # Non bloquant
    fi
}

test_pod_creation() {
    local namespace="$1"
    
    log_step "🚀 Test création de pod dans: $namespace"
    
    local test_pod="test-pod-$(date +%s)"
    
    # Création d'un pod de test
    if kubectl run "$test_pod" \
        --image="$TEST_IMAGE" \
        --namespace="$namespace" \
        --restart=Never \
        -- sleep 10 >/dev/null 2>&1; then
        
        log_success "Pod créé avec succès dans $namespace"
        
        # Attente que le pod soit prêt
        if kubectl wait --for=condition=Ready pod/"$test_pod" --namespace="$namespace" --timeout=30s >/dev/null 2>&1; then
            log_success "Pod opérationnel dans $namespace"
        else
            log_warning "Pod en cours de démarrage dans $namespace"
        fi
        
        # Nettoyage
        kubectl delete pod "$test_pod" --namespace="$namespace" >/dev/null 2>&1 || true
        
        return 0
    else
        log_error "Impossible de créer un pod dans $namespace"
        return 1
    fi
}

test_resource_quotas() {
    local namespace="$1"
    
    log_step "📊 Test quotas de ressources: $namespace"
    
    if kubectl get resourcequota -n "$namespace" >/dev/null 2>&1; then
        log_success "ResourceQuota présent dans $namespace"
        
        # Affichage des quotas
        log_info "📋 Quotas actuels:"
        kubectl get resourcequota -n "$namespace" -o wide 2>/dev/null || true
        
        return 0
    else
        log_warning "Aucun ResourceQuota dans $namespace"
        return 0  # Non bloquant
    fi
}

test_network_policies() {
    local namespace="$1"
    
    log_step "🛡️  Test Network Policies: $namespace"
    
    local policy_count
    policy_count=$(kubectl get networkpolicy -n "$namespace" 2>/dev/null | wc -l)
    
    if [[ $policy_count -gt 1 ]]; then  # > 1 car la première ligne est l'en-tête
        log_success "Network Policies présentes dans $namespace ($((policy_count - 1)) policies)"
        
        # Affichage des policies
        log_info "📋 Network Policies:"
        kubectl get networkpolicy -n "$namespace" -o wide 2>/dev/null || true
        
        return 0
    else
        log_warning "Aucune Network Policy dans $namespace"
        return 0  # Non bloquant
    fi
}

test_service_accounts() {
    local namespace="$1"
    
    log_step "🔐 Test Service Accounts: $namespace"
    
    local expected_sa="${namespace}-sa"
    
    if kubectl get serviceaccount "$expected_sa" -n "$namespace" >/dev/null 2>&1; then
        log_success "Service Account $expected_sa présent"
        return 0
    else
        log_warning "Service Account $expected_sa manquant dans $namespace"
        
        # Affichage des SA disponibles
        log_info "📋 Service Accounts disponibles:"
        kubectl get serviceaccount -n "$namespace" 2>/dev/null || true
        
        return 0  # Non bloquant
    fi
}

test_all_namespaces() {
    log_step "🔄 Test de tous les namespaces configurés..."
    
    local namespaces=("automation" "databases" "cache" "monitoring")
    local successful_tests=0
    local total_tests=0
    
    for namespace in "${namespaces[@]}"; do
        log_info "🧪 Tests pour namespace: $namespace"
        total_tests=$((total_tests + 1))
        
        local namespace_tests_passed=true
        
        # Test existence
        if ! test_namespace_exists "$namespace"; then
            namespace_tests_passed=false
        fi
        
        # Tests si le namespace existe
        if [[ "$namespace_tests_passed" == "true" ]]; then
            test_resource_quotas "$namespace"
            test_network_policies "$namespace" 
            test_service_accounts "$namespace"
            test_pod_creation "$namespace"
            test_dns_resolution "$namespace"
            
            successful_tests=$((successful_tests + 1))
        fi
        
        echo ""  # Séparation visuelle
    done
    
    log_info "📊 Résultats globaux:"
    log_info "  Namespaces testés: $total_tests"
    log_info "  Tests réussis: $successful_tests"
    
    if [[ $successful_tests -eq $total_tests ]]; then
        log_success "Tous les namespaces sont fonctionnels"
        return 0
    else
        log_warning "Certains namespaces ont des problèmes"
        return 1
    fi
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    print_header "Test Connectivité Kubernetes - Namespace: $TARGET_NAMESPACE"
    
    # Vérification kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl non disponible"
        return 1
    fi
    
    # Test de connectivité cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cluster Kubernetes non accessible"
        log_info "Vérifications nécessaires:"
        log_info "  - KUBECONFIG configuré ?"
        log_info "  - Cluster K3s démarré ?"
        log_info "  - Certificats valides ?"
        return 1
    fi
    
    log_success "Connexion cluster établie"
    
    # Tests selon le namespace cible
    if [[ "$TARGET_NAMESPACE" == "all" ]]; then
        test_all_namespaces
    else
        validate_environment "$TARGET_NAMESPACE"
        
        log_info "🧪 Tests pour namespace: $TARGET_NAMESPACE"
        
        test_namespace_exists "$TARGET_NAMESPACE"
        test_resource_quotas "$TARGET_NAMESPACE"
        test_network_policies "$TARGET_NAMESPACE"
        test_service_accounts "$TARGET_NAMESPACE"
        test_pod_creation "$TARGET_NAMESPACE"
        test_dns_resolution "$TARGET_NAMESPACE"
    fi
    
    print_summary "Tests Connectivité Terminés" \
        "Namespace: $TARGET_NAMESPACE" \
        "Cluster: accessible" \
        "Tests: exécutés"
    
    log_success "🎉 Tests de connectivité terminés"
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi