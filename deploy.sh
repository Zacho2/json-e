#!/bin/bash

set -o errexit -o nounset

SOURCE_BRANCH="refs/heads/main"
TARGET_BRANCH="gh-pages"
BUILD_DIR="docs"

if [ "$GITHUB_BRANCH" != "$SOURCE_BRANCH" ]; then
    echo "Non-$SOURCE_BRANCH branch build; skipping deployment."
    exit 0
fi

SHA=`git rev-parse --short HEAD`
GITHUB_PROJECT=$(echo $GITHUB_BASE_REPO_URL | sed 's/^https:\/\/github.com\///' | sed 's/.git$//')
SECRETS_URL="$TASKCLUSTER_PROXY_URL/api/secrets/v1/secret/project/json-e/json-e-deploy"

echo "Using project: $GITHUB_PROJECT"
echo "Using secrets: $SECRETS_URL"

mkdir ~/.ssh
curl "${SECRETS_URL}" | python -c 'import json, sys; a = json.load(sys.stdin); print a["secret"]["githubPubKey"]' >> ~/.ssh/known_hosts

BASE64_DEPLOY_KEY=$(curl ${SECRETS_URL} | python -c 'import json, sys; a = json.load(sys.stdin); print a["secret"]["base64DeployKey"]')
echo "$BASE64_DEPLOY_KEY" | base64 -d > /deploy_key
chmod 600 /deploy_key
eval `ssh-agent -s`
ssh-add /deploy_key

cd $BUILD_DIR
git init
git config user.name "Taskcluster Github"
git config user.email "taskcluster-notifications+jsone-demo@mozilla.com"

git remote add upstream "git@github.com:$GITHUB_PROJECT.git"
git fetch upstream
git reset "upstream/$TARGET_BRANCH"

echo 'json-e.js.org' > CNAME
touch .

git add -A .
git commit --allow-empty -m "Rebuilding $TARGET_BRANCH from $SHA"
git push -q upstream "HEAD:$TARGET_BRANCH"
