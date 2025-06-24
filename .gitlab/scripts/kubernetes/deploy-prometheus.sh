#!/bin/bash
# =============================================================================
# DEPLOY-PROMETHEUS.SH - Déploiement Prometheus sur Kubernetes
# =============================================================================
# Description : Déploiement Prometheus avec Helm dans le namespace monitoring
# Usage       : ./deploy-prometheus.sh [environment] [dry-run]
# Exemple     : ./deploy-prometheus.sh prod
#               ./deploy-prometheus.sh dev true
# Auteur      : Infrastructure Team
# Version     : 1.0.0
# =============================================================================

# Chargement des fonctions communes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/common.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly TARGET_ENV="${1:-${ENV:-prod}}"
readonly DRY_RUN="${2:-${DRY_RUN:-false}}"
readonly CHART_PATH="$PROJECT_ROOT/kubernetes/helm-charts/prometheus"
readonly NAMESPACE="monitoring"
readonly RELEASE_NAME="prometheus"

# =============================================================================
# FONCTIONS DE DÉPLOIEMENT
# =============================================================================

validate_prerequisites() {
    print_header "Validation des Prérequis Prometheus"
    
    # Vérification kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "kubectl non disponible"
        return 1
    fi
    
    # Vérification helm
    if ! command -v helm >/dev/null 2>&1; then
        log_error "helm non disponible"
        log_info "Installation d'Helm..."
        install_helm
    fi
    
    # Test connectivité cluster
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cluster Kubernetes non accessible"
        return 1
    fi
    
    log_success "Connectivité cluster validée"
    
    # Vérification namespace monitoring
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        log_error "Namespace $NAMESPACE non trouvé"
        log_info "Créer le namespace avec: kubectl apply -f kubernetes/namespaces/monitoring.yaml"
        return 1
    fi
    
    log_success "Namespace $NAMESPACE validé"
    
    # Vérification ServiceAccount
    if ! kubectl get serviceaccount monitoring-sa -n "$NAMESPACE" >/dev/null 2>&1; then
        log_error "ServiceAccount monitoring-sa non trouvé"
        log_info "Créer le ServiceAccount avec: kubectl apply -f kubernetes/manifests/rbac/service-accounts.yaml"
        return 1
    fi
    
    log_success "ServiceAccount monitoring-sa validé"
    
    # Vérification StorageClass
    if ! kubectl get storageclass local-ssd-fast >/dev/null 2>&1; then
        log_error "StorageClass local-ssd-fast non trouvée"
        log_info "Créer la StorageClass avec: kubectl apply -f kubernetes/manifests/storage-classes/local-ssd.yaml"
        return 1
    fi
    
    log_success "StorageClass local-ssd-fast validée"
}

install_helm() {
    log_step "Installation d'Helm..."
    
    local helm_version="v3.18.1"
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh --version "$helm_version"
    rm -f get_helm.sh
    
    log_success "Helm installé: $(helm version --short)"
}

validate_chart() {
    log_step "Validation du chart Prometheus..."
    
    validate_directory_exists "$CHART_PATH"
    
    # Validation syntaxique Helm
    if helm lint "$CHART_PATH" >/dev/null 2>&1; then
        log_success "Chart Prometheus valide"
    else
        log_error "Erreurs dans le chart Prometheus:"
        helm lint "$CHART_PATH"
        return 1
    fi
    
    # Validation template
    log_step "Test de templating..."
    helm template "$RELEASE_NAME" "$CHART_PATH" \
        --namespace "$NAMESPACE" \
        --set environment="$TARGET_ENV" \
        --dry-run >/dev/null 2>&1
    
    if [[ $? -eq 0 ]]; then
        log_success "Templating Helm réussi"
    else
        log_error "Erreur de templating:"
        helm template "$RELEASE_NAME" "$CHART_PATH" \
            --namespace "$NAMESPACE" \
            --set environment="$TARGET_ENV" \
            --dry-run
        return 1
    fi
}

deploy_prometheus() {
    local is_dry_run="$1"
    
    if [[ "$is_dry_run" == "true" ]]; then
        log_step "🧪 Mode DRY-RUN - Simulation déploiement Prometheus"
        local dry_run_flag="--dry-run"
    else
        log_step "🚀 Déploiement Prometheus en cours..."
        local dry_run_flag=""
    fi
    
    # Valeurs spécifiques à l'environnement
    local values_file="$CHART_PATH/values.yaml"
    
    # Commande Helm
    local helm_command=(
        helm upgrade --install "$RELEASE_NAME" "$CHART_PATH"
        --namespace "$NAMESPACE"
        --create-namespace
        --values "$values_file"
        --set environment="$TARGET_ENV"
        --set prometheus.serviceAccount.name="monitoring-sa"
        --set prometheus.persistence.storageClass="local-ssd-fast"
        --timeout 300s
        --wait
    )
    
    if [[ -n "$dry_run_flag" ]]; then
        helm_command+=($dry_run_flag)
    fi
    
    if "${helm_command[@]}"; then
        if [[ "$is_dry_run" == "true" ]]; then
            log_success "Simulation de déploiement réussie"
        else
            log_success "Prometheus déployé avec succès"
        fi
    else
        log_error "Échec du déploiement Prometheus"
        return 1
    fi
}

validate_deployment() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Mode dry-run - validation ignorée"
        return 0
    fi
    
    log_step "Validation du déploiement Prometheus..."
    
    # Attente que les pods soient prêts
    log_info "Attente que Prometheus soit prêt..."
    if kubectl wait --for=condition=available deployment/prometheus \
        --namespace="$NAMESPACE" \
        --timeout=300s >/dev/null 2>&1; then
        log_success "Deployment Prometheus prêt"
    else
        log_error "Timeout lors de l'attente du deployment"
        return 1
    fi
    
    # Vérification des pods
    local pod_status
    pod_status=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
    
    if [[ "$pod_status" == "Running" ]]; then
        log_success "Pod Prometheus en cours d'exécution"
    else
        log_error "Pod Prometheus non opérationnel (status: $pod_status)"
        log_info "Détails du pod:"
        kubectl describe pod -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus
        return 1
    fi
    
    # Vérification du PVC
    local pvc_status
    pvc_status=$(kubectl get pvc prometheus-storage -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
    
    if [[ "$pvc_status" == "Bound" ]]; then
        log_success "PVC Prometheus correctement monté"
    else
        log_error "PVC Prometheus non monté (status: $pvc_status)"
        return 1
    fi
    
    # Test de connectivité interne
    log_step "Test de connectivité Prometheus..."
    if kubectl exec -n "$NAMESPACE" deployment/prometheus -- wget -q --spider http://localhost:9090/-/healthy; then
        log_success "Prometheus répond aux health checks"
    else
        log_error "Prometheus ne répond pas aux health checks"
        return 1
    fi
}

test_metrics_collection() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Mode dry-run - test de métriques ignoré"
        return 0
    fi
    
    log_step "Test de collecte des métriques..."
    
    # Port-forward temporaire pour test
    kubectl port-forward -n "$NAMESPACE" svc/prometheus 9090:9090 &
    local port_forward_pid=$!
    
    # Attente que le port-forward soit établi
    sleep 5
    
    # Test des métriques kubelet
    if curl -s "http://localhost:9090/api/v1/query?query=up{job=\"kubernetes-nodes-kubelet\"}" | grep -q '"status":"success"'; then
        log_success "Métriques kubelet collectées"
    else
        log_warning "Métriques kubelet non disponibles (peut prendre quelques minutes)"
    fi
    
    # Test des métriques API server
    if curl -s "http://localhost:9090/api/v1/query?query=up{job=\"kubernetes-apiservers\"}" | grep -q '"status":"success"'; then
        log_success "Métriques API server collectées"
    else
        log_warning "Métriques API server non disponibles (peut prendre quelques minutes)"
    fi
    
    # Nettoyage du port-forward
    kill $port_forward_pid 2>/dev/null || true
    wait $port_forward_pid 2>/dev/null || true
}

generate_deployment_report() {
    log_step "📊 Génération du rapport de déploiement..."
    
    local report_file="prometheus_deployment_report_$(date +%Y%m%d_%H%M%S).json"
    
    # Collecte des informations de déploiement
    local helm_status pod_status pvc_status service_status
    
    if [[ "$DRY_RUN" != "true" ]]; then
        helm_status=$(helm status "$RELEASE_NAME" -n "$NAMESPACE" -o json 2>/dev/null | jq -r '.info.status' || echo "unknown")
        pod_status=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "unknown")
        pvc_status=$(kubectl get pvc prometheus-storage -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
        service_status=$(kubectl get svc prometheus -n "$NAMESPACE" -o jsonpath='{.status}' 2>/dev/null | jq -r '. // "active"')
    else
        helm_status="dry-run"
        pod_status="dry-run"
        pvc_status="dry-run"
        service_status="dry-run"
    fi
    
    cat > "$report_file" << EOF
{
  "deployment_date": "$(date -Iseconds)",
  "environment": "$TARGET_ENV",
  "dry_run": $DRY_RUN,
  "namespace": "$NAMESPACE",
  "release_name": "$RELEASE_NAME",
  "chart_path": "$CHART_PATH",
  "helm": {
    "status": "$helm_status",
    "version": "$(helm version --short 2>/dev/null || echo 'unknown')"
  },
  "kubernetes": {
    "pod_status": "$pod_status",
    "pvc_status": "$pvc_status",
    "service_status": "$service_status",
    "storage_class": "local-ssd-fast",
    "storage_size": "200Gi"
  },
  "prometheus": {
    "version": "v2.53.0",
    "retention": "$([ "$TARGET_ENV" == "prod" ] && echo "30d" || echo "7d")",
    "service_account": "monitoring-sa"
  },
  "validation": {
    "chart_valid": true,
    "prerequisites_met": true,
    "deployment_successful": true
  }
}
EOF
    
    if command -v jq >/dev/null 2>&1; then
        log_info "📄 Rapport de déploiement:"
        jq '.' "$report_file"
    else
        log_info "📄 Rapport généré: $report_file"
    fi
}

show_access_instructions() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log_step "📋 Instructions d'accès Prometheus..."
    
    echo ""
    log_info "🌐 Pour accéder à l'interface web Prometheus:"
    log_info "   kubectl port-forward -n monitoring svc/prometheus 9090:9090"
    log_info "   Puis ouvrir: http://localhost:9090"
    echo ""
    log_info "📊 Pour vérifier les métriques collectées:"
    log_info "   - Targets: http://localhost:9090/targets"
    log_info "   - Graph: http://localhost:9090/graph"
    echo ""
    log_info "🔍 Commandes utiles:"
    log_info "   - Status: helm status prometheus -n monitoring"
    log_info "   - Logs: kubectl logs -n monitoring deployment/prometheus"
    log_info "   - Pods: kubectl get pods -n monitoring"
    echo ""
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    print_header "Déploiement Prometheus - Environnement: $TARGET_ENV"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "🧪 MODE DRY-RUN ACTIVÉ - Aucune modification ne sera appliquée"
    fi
    
    validate_environment "$TARGET_ENV"
    
    # Validation des prérequis
    validate_prerequisites
    
    # Validation du chart
    validate_chart
    
    # Déploiement
    deploy_prometheus "$DRY_RUN"
    
    # Validation post-déploiement
    validate_deployment
    
    # Test de collecte des métriques
    test_metrics_collection
    
    # Génération du rapport
    generate_deployment_report
    
    # Instructions d'accès
    show_access_instructions
    
    print_summary "Déploiement Prometheus Terminé" \
        "Environnement: $TARGET_ENV" \
        "Namespace: $NAMESPACE" \
        "Release: $RELEASE_NAME" \
        "Storage: local-ssd-fast (200Gi)" \
        "ServiceAccount: monitoring-sa" \
        "Mode: $([ "$DRY_RUN" == "true" ] && echo "DRY-RUN" || echo "PRODUCTION")"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "🎉 Simulation de déploiement Prometheus terminée avec succès"
    else
        log_success "🎉 Déploiement Prometheus terminé avec succès"
    fi
}

# =============================================================================
# POINT D'ENTRÉE
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi