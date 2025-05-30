import os
import requests

GITLAB_TOKEN = os.environ['GITLAB_TOKEN']
GITHUB_TOKEN = os.environ['GITHUB_TOKEN']
GITLAB_PROJECT_ID = os.environ['GITLAB_PROJECT_ID']
GITHUB_REPO = os.environ['GITHUB_REPO']

headers_gitlab = {'PRIVATE-TOKEN': GITLAB_TOKEN}
headers_github = {'Authorization': f'token {GITHUB_TOKEN}'}

# Fetch GitLab issues
gitlab_issues = requests.get(
    f'https://gitlab.com/api/v4/projects/{GITLAB_PROJECT_ID}/issues',
    headers=headers_gitlab
).json()

# Fetch existing GitHub issues
github_issues = []
page = 1
while True:
    response = requests.get(
        f'https://api.github.com/repos/{GITHUB_REPO}/issues',
        headers=headers_github,
        params={'state': 'all', 'per_page': 100, 'page': page}
    )
    data = response.json()
    if not data:
        break
    github_issues.extend(data)
    page += 1

# Build a mapping of GitHub issues by title
github_issues_map = {issue['title']: issue for issue in github_issues}

# Create or update issues on GitHub based on GitLab issues
for issue in gitlab_issues:
    title = issue['title']
    state = issue['state']  # 'opened' or 'closed'
    body = f"Imported from GitLab:\n\n{issue['description']}"

    if title in github_issues_map:
        github_issue = github_issues_map[title]
        gh_number = github_issue['number']
        needs_state_update = (
            (state == 'closed' and github_issue['state'] != 'closed') or
            (state == 'opened' and github_issue['state'] != 'open')
        )
        if needs_state_update:
            update_payload = {"state": "closed" if state == "closed" else "open"}
            response = requests.patch(
                f'https://api.github.com/repos/{GITHUB_REPO}/issues/{gh_number}',
                headers=headers_github,
                json=update_payload
            )
            print(f"Updated state of issue: {title} → {update_payload['state']}")
        else:
            print(f"Issue already up-to-date: {title}")
        continue

    # Create new issue if it doesn't exist
    payload = {
        'title': title,
        'body': body,
        'labels': ['imported-from-gitlab'],
        'state': 'closed' if state == 'closed' else 'open'
    }
    response = requests.post(
        f'https://api.github.com/repos/{GITHUB_REPO}/issues',
        headers=headers_github,
        json=payload
    )
    if response.status_code == 201:
        print(f"Issue created: {title} (state: {payload['state']})")
    else:
        print(f"Failed to create issue: {title} → {response.status_code} → {response.text}")
