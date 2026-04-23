#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

IMAGE_NAME="gs2-next-connecta"
VERSION=$(grep 'version:' config/app.yml | head -1 | sed "s/.*version: *['\"]//;s/['\"]//")
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_REPO=$(git remote get-url origin 2>/dev/null || true)
REPO_SOURCE=$(echo "$GIT_REPO" | sed -E 's|\.git$||' | sed -E 's|^git@github\.com:|https://github.com/|')
[ -n "$REPO_SOURCE" ] || REPO_SOURCE="https://github.com/danielmorello/chatwoot"

echo "Building ${IMAGE_NAME} version ${VERSION} (${COMMIT_SHA})..."

docker build \
  -f docker/Dockerfile \
  --build-arg RAILS_ENV=production \
  -t "${IMAGE_NAME}:${VERSION}" \
  -t "${IMAGE_NAME}:${VERSION}-${COMMIT_SHA}" \
  -t "${IMAGE_NAME}:latest" \
  .

echo "Done. Tags: ${IMAGE_NAME}:${VERSION} | ${IMAGE_NAME}:${VERSION}-${COMMIT_SHA} | ${IMAGE_NAME}:latest"
