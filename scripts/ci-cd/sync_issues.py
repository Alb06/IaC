import os
import requests
import sys
import time
from datetime import datetime

# Configuration des timeouts et limites
REQUEST_TIMEOUT = 30  # secondes
MAX_GITHUB_PAGES = 100  # Limite de sécurité pour éviter les boucles infinies
RETRY_ATTEMPTS = 3
RETRY_DELAY = 2  # secondes

def log_with_timestamp(message):
    """Affiche un message avec timestamp"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")

def make_request_with_retry(method, url, headers, params=None, json_data=None):
    """Effectue une requête HTTP avec retry et timeout"""
    for attempt in range(RETRY_ATTEMPTS):
        try:
            log_with_timestamp(f"🌐 Requête {method} vers: {url}")
            if params:
                log_with_timestamp(f"   Paramètres: {params}")
            
            if method.upper() == 'GET':
                response = requests.get(url, headers=headers, params=params, timeout=REQUEST_TIMEOUT)
            elif method.upper() == 'POST':
                response = requests.post(url, headers=headers, json=json_data, timeout=REQUEST_TIMEOUT)
            elif method.upper() == 'PATCH':
                response = requests.patch(url, headers=headers, json=json_data, timeout=REQUEST_TIMEOUT)
            else:
                raise ValueError(f"Méthode HTTP non supportée: {method}")
            
            log_with_timestamp(f"   Status: {response.status_code}")
            log_with_timestamp(f"   Taille réponse: {len(response.content)} bytes")
            
            response.raise_for_status()
            return response
            
        except requests.exceptions.Timeout:
            log_with_timestamp(f"⏰ Timeout (tentative {attempt + 1}/{RETRY_ATTEMPTS})")
            if attempt < RETRY_ATTEMPTS - 1:
                time.sleep(RETRY_DELAY)
        except requests.exceptions.ConnectionError as e:
            log_with_timestamp(f"🔌 Erreur de connexion (tentative {attempt + 1}/{RETRY_ATTEMPTS}): {e}")
            if attempt < RETRY_ATTEMPTS - 1:
                time.sleep(RETRY_DELAY)
        except requests.exceptions.HTTPError as e:
            log_with_timestamp(f"❌ Erreur HTTP: {e}")
            log_with_timestamp(f"   Contenu réponse: {response.text[:500]}...")
            raise
        except Exception as e:
            log_with_timestamp(f"❌ Erreur inattendue: {e}")
            if attempt < RETRY_ATTEMPTS - 1:
                time.sleep(RETRY_DELAY)
            else:
                raise
    
    raise Exception(f"Échec après {RETRY_ATTEMPTS} tentatives")

def main():
    """Synchronise les issues GitLab vers GitHub"""
    log_with_timestamp("🚀 Démarrage de la synchronisation des issues")
    
    try:
        # Vérification des variables d'environnement requises
        log_with_timestamp("🔍 Vérification des variables d'environnement...")
        required_vars = ['GITLAB_TOKEN', 'GITHUB_TOKEN', 'GITLAB_PROJECT_ID', 'GITHUB_REPO']
        missing_vars = [var for var in required_vars if not os.environ.get(var)]
        
        if missing_vars:
            log_with_timestamp(f"❌ Variables d'environnement manquantes: {', '.join(missing_vars)}")
            sys.exit(1)

        GITLAB_TOKEN = os.environ['GITLAB_TOKEN']
        GITHUB_TOKEN = os.environ['GITHUB_TOKEN']
        GITLAB_PROJECT_ID = os.environ['GITLAB_PROJECT_ID']
        GITHUB_REPO = os.environ['GITHUB_REPO']

        log_with_timestamp(f"✅ Variables trouvées - Projet GitLab: {GITLAB_PROJECT_ID}, Repo GitHub: {GITHUB_REPO}")

        headers_gitlab = {'PRIVATE-TOKEN': GITLAB_TOKEN}
        headers_github = {'Authorization': f'token {GITHUB_TOKEN}'}

        # Fetch GitLab issues
        log_with_timestamp("🔄 Récupération des issues GitLab...")
        gitlab_url = f'https://gitlab.com/api/v4/projects/{GITLAB_PROJECT_ID}/issues'
        
        gitlab_response = make_request_with_retry('GET', gitlab_url, headers_gitlab)
        gitlab_issues = gitlab_response.json()
        
        log_with_timestamp(f"✅ {len(gitlab_issues)} issues trouvées sur GitLab")
        
        # Affichage des titres des issues GitLab pour debug
        for i, issue in enumerate(gitlab_issues[:5]):  # Limiter à 5 pour éviter le spam
            log_with_timestamp(f"   Issue GitLab {i+1}: '{issue.get('title', 'N/A')}' (état: {issue.get('state', 'N/A')})")
        if len(gitlab_issues) > 5:
            log_with_timestamp(f"   ... et {len(gitlab_issues) - 5} autres issues")

        # Fetch existing GitHub issues avec pagination sécurisée
        log_with_timestamp("🔄 Récupération des issues GitHub...")
        github_issues = []
        page = 1
        
        while page <= MAX_GITHUB_PAGES:
            log_with_timestamp(f"📄 Récupération page GitHub {page}/{MAX_GITHUB_PAGES}...")
            
            github_url = f'https://api.github.com/repos/{GITHUB_REPO}/issues'
            params = {'state': 'all', 'per_page': 100, 'page': page}
            
            response = make_request_with_retry('GET', github_url, headers_github, params=params)
            data = response.json()
            
            log_with_timestamp(f"   Page {page}: {len(data)} issues récupérées")
            
            if not data:
                log_with_timestamp("   ✅ Fin de pagination (page vide)")
                break
                
            github_issues.extend(data)
            page += 1
            
            # Petit délai pour éviter le rate limiting
            time.sleep(0.5)

        if page > MAX_GITHUB_PAGES:
            log_with_timestamp(f"⚠️  Limite de pagination atteinte ({MAX_GITHUB_PAGES} pages)")

        log_with_timestamp(f"✅ {len(github_issues)} issues totales trouvées sur GitHub")

        # Build a mapping of GitHub issues by title
        log_with_timestamp("🔄 Construction du mapping des issues GitHub...")
        github_issues_map = {}
        for issue in github_issues:
            title = issue.get('title', '')
            if title:
                github_issues_map[title] = issue
            else:
                log_with_timestamp(f"⚠️  Issue GitHub sans titre trouvée: {issue.get('number', 'N/A')}")

        log_with_timestamp(f"✅ Mapping créé avec {len(github_issues_map)} issues")

        # Create or update issues on GitHub based on GitLab issues
        log_with_timestamp("🔄 Synchronisation des issues...")
        created_count = 0
        updated_count = 0
        skipped_count = 0
        
        for i, issue in enumerate(gitlab_issues):
            log_with_timestamp(f"📝 Traitement issue {i+1}/{len(gitlab_issues)}: '{issue.get('title', 'N/A')}'")
            
            title = issue.get('title', '')
            state = issue.get('state', 'opened')
            description = issue.get('description', '')
            
            if not title:
                log_with_timestamp(f"   ⚠️  Issue sans titre, ignorée")
                skipped_count += 1
                continue
            
            body = f"Imported from GitLab:\n\n{description}"

            if title in github_issues_map:
                log_with_timestamp(f"   🔍 Issue existante trouvée sur GitHub")
                github_issue = github_issues_map[title]
                gh_number = github_issue.get('number')
                current_gh_state = github_issue.get('state')
                
                log_with_timestamp(f"   État GitLab: {state}, État GitHub: {current_gh_state}")
                
                needs_state_update = (
                    (state == 'closed' and current_gh_state != 'closed') or
                    (state == 'opened' and current_gh_state != 'open')
                )
                
                if needs_state_update:
                    log_with_timestamp(f"   🔄 Mise à jour nécessaire de {current_gh_state} vers {state}")
                    update_payload = {"state": "closed" if state == "closed" else "open"}
                    update_url = f'https://api.github.com/repos/{GITHUB_REPO}/issues/{gh_number}'
                    
                    response = make_request_with_retry('PATCH', update_url, headers_github, json_data=update_payload)
                    log_with_timestamp(f"   ✅ Issue mise à jour: {title} → {update_payload['state']}")
                    updated_count += 1
                else:
                    log_with_timestamp(f"   ℹ️  Issue déjà à jour: {title}")
                continue

            # Create new issue if it doesn't exist
            log_with_timestamp(f"   🆕 Création d'une nouvelle issue")
            payload = {
                'title': title,
                'body': body,
                'labels': ['imported-from-gitlab'],
                'state': 'closed' if state == 'closed' else 'open'
            }
            
            create_url = f'https://api.github.com/repos/{GITHUB_REPO}/issues'
            response = make_request_with_retry('POST', create_url, headers_github, json_data=payload)
            
            log_with_timestamp(f"   ✅ Issue créée: {title} (état: {payload['state']})")
            created_count += 1
            
            # Petit délai entre les créations pour éviter le rate limiting
            time.sleep(1)

        log_with_timestamp(f"\n🎉 Synchronisation terminée:")
        log_with_timestamp(f"  - Issues créées: {created_count}")
        log_with_timestamp(f"  - Issues mises à jour: {updated_count}")
        log_with_timestamp(f"  - Issues ignorées: {skipped_count}")
        log_with_timestamp(f"  - Total traitées: {len(gitlab_issues)}")

    except Exception as e:
        log_with_timestamp(f"❌ Erreur inattendue: {e}")
        import traceback
        log_with_timestamp(f"📋 Stack trace: {traceback.format_exc()}")
        sys.exit(1)

if __name__ == "__main__":
    main()
