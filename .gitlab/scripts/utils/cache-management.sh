#!/bin/bash
# =============================================================================
# GESTION DE CACHE CENTRALISÉE - PIPELINE GITLAB CI/CD
# =============================================================================
# Description : Système de cache pour binaires, modules et artefacts
# Version     : 1.0.0
# Auteur      : Infrastructure Team
# Dépendances : logging.sh, error-management.sh
# =============================================================================

# Répertoire du script pour sourcer les dépendances
SCRIPT_DIR_CACHE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Chargement des dépendances (si pas déjà chargées)
if ! command -v log_info >/dev/null 2>&1; then
    # shellcheck source=logging.sh
    source "${SCRIPT_DIR_CACHE}/logging.sh"
fi

if ! command -v safe_execute >/dev/null 2>&1; then
    # shellcheck source=error-management.sh
    source "${SCRIPT_DIR_CACHE}/error-management.sh"
fi

# =============================================================================
# CONFIGURATION DU CACHE
# =============================================================================

# Répertoires de cache
readonly CACHE_BASE_DIR="${CACHE_BASE_DIR:-/tmp}"
readonly TERRAFORM_CACHE_DIR="${CACHE_BASE_DIR}/terraform-cache"
readonly BINARY_CACHE_DIR="${CACHE_BASE_DIR}/binary-cache"
readonly MODULE_CACHE_DIR="${CACHE_BASE_DIR}/module-cache"

# Tailles limites (en Mo)
readonly MAX_CACHE_SIZE_MB=500
readonly MAX_SINGLE_FILE_MB=100

# TTL du cache (en secondes)
readonly CACHE_TTL_SECONDS=86400  # 24 heures
readonly BINARY_CACHE_TTL_SECONDS=604800  # 7 jours

# Patterns d'exclusion
readonly EXCLUDE_PATTERNS=(
    "*.log"
    "*.tmp"
    "*/.terraform/providers/**"
    "*/terraform.tfstate*"
)

# =============================================================================
# FONCTIONS DE GESTION DU RÉPERTOIRE DE CACHE
# =============================================================================

# Initialise la structure de cache
# Usage: initialize_cache_structure
initialize_cache_structure() {
    log_info "🔧 Initialisation de la structure de cache..."
    
    local cache_dirs=(
        "$TERRAFORM_CACHE_DIR"
        "$BINARY_CACHE_DIR"
        "$MODULE_CACHE_DIR"
    )
    
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ ! -d "$cache_dir" ]]; then
            log_debug "Création du répertoire de cache: $cache_dir"
            mkdir -p "$cache_dir" || {
                log_error "Impossible de créer le répertoire de cache: $cache_dir"
                return 1
            }
        else
            log_debug "Répertoire de cache existant: $cache_dir"
        fi
    done
    
    log_success "Structure de cache initialisée"
    return 0
}

# Nettoie les fichiers de cache expirés
# Usage: cleanup_expired_cache [ttl_seconds]
cleanup_expired_cache() {
    local ttl="${1:-$CACHE_TTL_SECONDS}"
    
    log_info "🧹 Nettoyage du cache expiré (TTL: ${ttl}s)..."
    
    local cache_dirs=(
        "$TERRAFORM_CACHE_DIR"
        "$BINARY_CACHE_DIR"
        "$MODULE_CACHE_DIR"
    )
    
    local total_cleaned=0
    
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ -d "$cache_dir" ]]; then
            log_debug "Nettoyage du répertoire: $cache_dir"
            
            # Recherche des fichiers expirés
            local expired_files
            expired_files=$(find "$cache_dir" -type f -mtime +$((ttl / 86400)) 2>/dev/null || true)
            
            if [[ -n "$expired_files" ]]; then
                local count
                count=$(echo "$expired_files" | wc -l)
                log_info "Suppression de $count fichiers expirés dans $cache_dir"
                
                echo "$expired_files" | xargs rm -f 2>/dev/null || true
                total_cleaned=$((total_cleaned + count))
            else
                log_debug "Aucun fichier expiré dans $cache_dir"
            fi
        fi
    done
    
    log_success "Nettoyage terminé: $total_cleaned fichiers supprimés"
    return 0
}

# Vérifie et limite la taille du cache
# Usage: enforce_cache_size_limit
enforce_cache_size_limit() {
    log_info "📊 Vérification des limites de taille du cache..."
    
    local cache_dirs=(
        "$TERRAFORM_CACHE_DIR"
        "$BINARY_CACHE_DIR"
        "$MODULE_CACHE_DIR"
    )
    
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ -d "$cache_dir" ]]; then
            # Calcul de la taille actuelle en Mo
            local current_size_kb
            current_size_kb=$(du -sk "$cache_dir" 2>/dev/null | cut -f1 || echo "0")
            local current_size_mb=$((current_size_kb / 1024))
            
            log_debug "Taille du cache $cache_dir: ${current_size_mb}Mo"
            
            # Vérification de la limite
            if [[ $current_size_mb -gt $MAX_CACHE_SIZE_MB ]]; then
                log_warning "Cache trop volumineux: ${current_size_mb}Mo > ${MAX_CACHE_SIZE_MB}Mo"
                log_info "Nettoyage des fichiers les plus anciens..."
                
                # Suppression des fichiers les plus anciens
                find "$cache_dir" -type f -printf '%T@ %p\n' 2>/dev/null | \
                sort -n | \
                head -n $((current_size_mb - MAX_CACHE_SIZE_MB + 50)) | \
                cut -d' ' -f2- | \
                xargs rm -f 2>/dev/null || true
                
                log_success "Taille du cache réduite"
            else
                log_debug "Taille du cache dans les limites: ${current_size_mb}Mo"
            fi
        fi
    done
    
    return 0
}

# =============================================================================
# FONCTIONS DE CACHE TERRAFORM
# =============================================================================

# Met en cache les binaires Terraform
# Usage: cache_terraform_binary "1.12.1" "/path/to/terraform"
cache_terraform_binary() {
    local version="${1:-}"
    local binary_path="${2:-}"
    
    if [[ -z "$version" || -z "$binary_path" ]]; then
        log_error "Version ou chemin binaire manquant pour le cache Terraform"
        return 1
    fi
    
    if [[ ! -f "$binary_path" ]]; then
        log_error "Binaire Terraform inexistant: $binary_path"
        return 1
    fi
    
    local cache_path="$BINARY_CACHE_DIR/terraform_${version}"
    
    log_info "💾 Mise en cache du binaire Terraform $version..."
    
    if cp "$binary_path" "$cache_path" && chmod +x "$cache_path"; then
        # Ajout des métadonnées
        echo "version=$version" > "${cache_path}.meta"
        echo "cached_at=$(date -Iseconds)" >> "${cache_path}.meta"
        echo "size=$(stat -f%z "$cache_path" 2>/dev/null || stat -c%s "$cache_path")" >> "${cache_path}.meta"
        
        log_success "Binaire Terraform mis en cache: $cache_path"
        return 0
    else
        log_error "Échec de la mise en cache du binaire Terraform"
        return 1
    fi
}

# Récupère un binaire Terraform depuis le cache
# Usage: get_cached_terraform_binary "1.12.1" "/destination/path"
get_cached_terraform_binary() {
    local version="${1:-}"
    local destination="${2:-}"
    
    if [[ -z "$version" || -z "$destination" ]]; then
        log_error "Version ou destination manquante pour récupération du cache"
        return 1
    fi
    
    local cache_path="$BINARY_CACHE_DIR/terraform_${version}"
    
    if [[ -f "$cache_path" ]]; then
        # Vérification de l'âge du cache
        local file_age
        file_age=$(( $(date +%s) - $(stat -f%m "$cache_path" 2>/dev/null || stat -c%Y "$cache_path") ))
        
        if [[ $file_age -lt $BINARY_CACHE_TTL_SECONDS ]]; then
            log_info "♻️  Récupération de Terraform $version depuis le cache..."
            
            if cp "$cache_path" "$destination" && chmod +x "$destination"; then
                log_success "Binaire Terraform récupéré du cache: $destination"
                return 0
            else
                log_error "Échec de la copie depuis le cache"
                return 1
            fi
        else
            log_info "Cache Terraform expiré (âge: ${file_age}s > ${BINARY_CACHE_TTL_SECONDS}s)"
            rm -f "$cache_path" "${cache_path}.meta" 2>/dev/null || true
        fi
    else
        log_debug "Binaire Terraform $version non trouvé dans le cache"
    fi
    
    return 1
}

# Vérifie si un binaire Terraform est en cache
# Usage: is_terraform_cached "1.12.1"
is_terraform_cached() {
    local version="${1:-}"
    
    if [[ -z "$version" ]]; then
        return 1
    fi
    
    local cache_path="$BINARY_CACHE_DIR/terraform_${version}"
    
    if [[ -f "$cache_path" ]]; then
        # Vérification de l'âge
        local file_age
        file_age=$(( $(date +%s) - $(stat -f%m "$cache_path" 2>/dev/null || stat -c%Y "$cache_path") ))
        
        if [[ $file_age -lt $BINARY_CACHE_TTL_SECONDS ]]; then
            return 0
        else
            # Nettoyage du cache expiré
            rm -f "$cache_path" "${cache_path}.meta" 2>/dev/null || true
        fi
    fi
    
    return 1
}

# =============================================================================
# FONCTIONS DE CACHE GÉNÉRIQUE
# =============================================================================

# Met un fichier en cache avec validation
# Usage: cache_file "/source/path" "cache_key" [cache_subdir]
cache_file() {
    local source_path="${1:-}"
    local cache_key="${2:-}"
    local cache_subdir="${3:-generic}"
    
    if [[ -z "$source_path" || -z "$cache_key" ]]; then
        log_error "Chemin source ou clé de cache manquant"
        return 1
    fi
    
    if [[ ! -f "$source_path" ]]; then
        log_error "Fichier source inexistant: $source_path"
        return 1
    fi
    
    # Validation de la taille du fichier
    local file_size_mb
    file_size_mb=$(( $(stat -f%z "$source_path" 2>/dev/null || stat -c%s "$source_path") / 1024 / 1024 ))
    
    if [[ $file_size_mb -gt $MAX_SINGLE_FILE_MB ]]; then
        log_warning "Fichier trop volumineux pour le cache: ${file_size_mb}Mo > ${MAX_SINGLE_FILE_MB}Mo"
        return 1
    fi
    
    local cache_dir="$MODULE_CACHE_DIR/$cache_subdir"
    local cache_path="$cache_dir/$cache_key"
    
    # Création du répertoire de cache
    mkdir -p "$cache_dir" || {
        log_error "Impossible de créer le répertoire de cache: $cache_dir"
        return 1
    }
    
    log_debug "Mise en cache: $source_path → $cache_path"
    
    if cp "$source_path" "$cache_path"; then
        # Métadonnées
        echo "source=$source_path" > "${cache_path}.meta"
        echo "cached_at=$(date -Iseconds)" >> "${cache_path}.meta"
        echo "size=$file_size_mb" >> "${cache_path}.meta"
        echo "checksum=$(sha256sum "$source_path" | cut -d' ' -f1)" >> "${cache_path}.meta"
        
        log_success "Fichier mis en cache: $cache_key"
        return 0
    else
        log_error "Échec de la mise en cache"
        return 1
    fi
}

# Récupère un fichier depuis le cache
# Usage: get_cached_file "cache_key" "/destination/path" [cache_subdir]
get_cached_file() {
    local cache_key="${1:-}"
    local destination="${2:-}"
    local cache_subdir="${3:-generic}"
    
    if [[ -z "$cache_key" || -z "$destination" ]]; then
        log_error "Clé de cache ou destination manquante"
        return 1
    fi
    
    local cache_dir="$MODULE_CACHE_DIR/$cache_subdir"
    local cache_path="$cache_dir/$cache_key"
    
    if [[ -f "$cache_path" ]]; then
        # Vérification de l'âge
        local file_age
        file_age=$(( $(date +%s) - $(stat -f%m "$cache_path" 2>/dev/null || stat -c%Y "$cache_path") ))
        
        if [[ $file_age -lt $CACHE_TTL_SECONDS ]]; then
            log_debug "Récupération depuis le cache: $cache_key → $destination"
            
            # Création du répertoire de destination
            local dest_dir
            dest_dir="$(dirname "$destination")"
            mkdir -p "$dest_dir" || {
                log_error "Impossible de créer le répertoire de destination: $dest_dir"
                return 1
            }
            
            if cp "$cache_path" "$destination"; then
                log_success "Fichier récupéré du cache: $cache_key"
                return 0
            else
                log_error "Échec de la copie depuis le cache"
                return 1
            fi
        else
            log_debug "Cache expiré pour: $cache_key (âge: ${file_age}s)"
            rm -f "$cache_path" "${cache_path}.meta" 2>/dev/null || true
        fi
    else
        log_debug "Fichier non trouvé dans le cache: $cache_key"
    fi
    
    return 1
}

# =============================================================================
# FONCTIONS D'ADMINISTRATION DU CACHE
# =============================================================================

# Affiche les statistiques du cache
# Usage: show_cache_stats
show_cache_stats() {
    log_section "STATISTIQUES DU CACHE"
    
    local cache_dirs=(
        "$TERRAFORM_CACHE_DIR:Terraform"
        "$BINARY_CACHE_DIR:Binaires"
        "$MODULE_CACHE_DIR:Modules"
    )
    
    local total_size_mb=0
    local total_files=0
    
    for cache_entry in "${cache_dirs[@]}"; do
        local cache_dir="${cache_entry%:*}"
        local cache_name="${cache_entry#*:}"
        
        if [[ -d "$cache_dir" ]]; then
            local size_kb
            size_kb=$(du -sk "$cache_dir" 2>/dev/null | cut -f1 || echo "0")
            local size_mb=$((size_kb / 1024))
            
            local file_count
            file_count=$(find "$cache_dir" -type f 2>/dev/null | wc -l || echo "0")
            
            log_info "Cache $cache_name: ${size_mb}Mo, $file_count fichiers"
            
            total_size_mb=$((total_size_mb + size_mb))
            total_files=$((total_files + file_count))
        else
            log_info "Cache $cache_name: Non initialisé"
        fi
    done
    
    log_info "TOTAL: ${total_size_mb}Mo, $total_files fichiers"
    log_info "Limite: ${MAX_CACHE_SIZE_MB}Mo par répertoire"
    
    return 0
}

# Nettoie complètement le cache
# Usage: clear_all_cache
clear_all_cache() {
    log_warning "🗑️  Nettoyage complet du cache demandé..."
    
    local cache_dirs=(
        "$TERRAFORM_CACHE_DIR"
        "$BINARY_CACHE_DIR"
        "$MODULE_CACHE_DIR"
    )
    
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ -d "$cache_dir" ]]; then
            log_info "Suppression du cache: $cache_dir"
            rm -rf "$cache_dir" || {
                log_error "Échec de la suppression: $cache_dir"
            }
        fi
    done
    
    # Réinitialisation
    initialize_cache_structure
    
    log_success "Cache complètement nettoyé et réinitialisé"
    return 0
}

# =============================================================================
# FONCTIONS D'AIDE ET MAINTENANCE
# =============================================================================

# Maintenance automatique du cache
# Usage: maintain_cache
maintain_cache() {
    log_info "🔧 Maintenance automatique du cache..."
    
    # Initialisation si nécessaire
    initialize_cache_structure
    
    # Nettoyage des fichiers expirés
    cleanup_expired_cache
    
    # Vérification des limites de taille
    enforce_cache_size_limit
    
    log_success "Maintenance du cache terminée"
    return 0
}

# Affiche l'aide du système de cache
# Usage: show_cache_help
show_cache_help() {
    cat << 'EOF'
📚 GESTION DE CACHE - FONCTIONS DISPONIBLES

🔧 Configuration:
  initialize_cache_structure          - Initialise la structure de cache
  maintain_cache                      - Maintenance automatique complète

🏗️  Cache Terraform:
  cache_terraform_binary VER PATH     - Met en cache un binaire Terraform
  get_cached_terraform_binary VER DST - Récupère depuis le cache
  is_terraform_cached VERSION         - Vérifie si une version est en cache

📁 Cache générique:
  cache_file SRC KEY [SUBDIR]         - Met un fichier en cache
  get_cached_file KEY DST [SUBDIR]    - Récupère depuis le cache

🧹 Maintenance:
  cleanup_expired_cache [TTL]         - Nettoie les fichiers expirés
  enforce_cache_size_limit           - Applique les limites de taille
  clear_all_cache                    - Supprime tout le cache

📊 Administration:
  show_cache_stats                   - Affiche les statistiques du cache

Configuration:
  CACHE_BASE_DIR=/tmp                - Répertoire de base du cache
  MAX_CACHE_SIZE_MB=500             - Taille max par répertoire (Mo)
  CACHE_TTL_SECONDS=86400           - TTL des fichiers (24h)
  BINARY_CACHE_TTL_SECONDS=604800   - TTL des binaires (7 jours)

EOF
}

# =============================================================================
# INITIALISATION
# =============================================================================

# Initialisation automatique si en environnement CI
if [[ -n "${CI_PROJECT_DIR:-}" ]]; then
    maintain_cache >/dev/null 2>&1 || {
        log_warning "Échec de la maintenance automatique du cache"
    }
fi

# Si le script est exécuté directement (pas sourcé)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_info "📋 Gestion de cache - Pipeline GitLab CI/CD"
    log_info "Version: 1.0.0"
    echo
    show_cache_help
    echo
    show_cache_stats
    exit 0
fi