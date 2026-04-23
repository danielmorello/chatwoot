#!/usr/bin/env bash
# Publica a imagem local no GitHub Container Registry (ghcr.io).
# Pré-requisito: bash scripts/build-image.sh e login no ghcr.io:
#   echo $GITHUB_TOKEN | docker login ghcr.io -u SEU_USER --password-stdin
set -e
cd "$(dirname "$0")/.."

IMAGE_NAME="gs2-next-connecta"
VERSION=$(grep 'version:' config/app.yml | head -1 | sed "s/.*version: *['\"]//;s/['\"]//")
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
FULL_COMMIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
RELEASE_TAG="v${VERSION}"
GIT_REPO=$(git remote get-url origin 2>/dev/null || true)
OWNER=$(echo "$GIT_REPO" | sed -E 's|.*github\.com[:/]([^/]+)/.*|\1|' || echo "unknown")
REGISTRY_IMAGE="ghcr.io/${OWNER}/${IMAGE_NAME}"

if [ -z "$GIT_REPO" ]; then
  echo "Remote 'origin' não encontrado. Configure o remote antes de publicar."
  exit 1
fi

if [ "$FULL_COMMIT_SHA" = "unknown" ]; then
  echo "Não foi possível obter o commit atual do Git."
  exit 1
fi

if git rev-parse -q --verify "refs/tags/${RELEASE_TAG}" >/dev/null; then
  TAG_COMMIT=$(git rev-list -n 1 "${RELEASE_TAG}")
  if [ "$TAG_COMMIT" != "$FULL_COMMIT_SHA" ]; then
    echo "Conflito: a tag ${RELEASE_TAG} já existe e aponta para outro commit (${TAG_COMMIT})."
    echo "Abortando para evitar release inconsistente."
    exit 1
  fi
  echo "Tag ${RELEASE_TAG} já existe localmente no commit atual."
else
  git tag "${RELEASE_TAG}"
  echo "Tag ${RELEASE_TAG} criada localmente."
fi

if git ls-remote --exit-code --tags origin "refs/tags/${RELEASE_TAG}" >/dev/null 2>&1; then
  REMOTE_TAG_COMMIT=$(git ls-remote --tags origin "refs/tags/${RELEASE_TAG}" | awk '{print $1}')
  if [ "$REMOTE_TAG_COMMIT" != "$FULL_COMMIT_SHA" ]; then
    echo "Conflito: a tag remota ${RELEASE_TAG} já existe e aponta para outro commit (${REMOTE_TAG_COMMIT})."
    echo "Abortando para evitar sobrescrever histórico."
    exit 1
  fi
  echo "Tag ${RELEASE_TAG} já existe no remoto."
else
  git push origin "${RELEASE_TAG}"
  echo "Tag ${RELEASE_TAG} publicada no remoto."
fi

if ! docker image inspect "${IMAGE_NAME}:${VERSION}" >/dev/null 2>&1; then
  echo "Imagem local ${IMAGE_NAME}:${VERSION} não encontrada. Rode antes: bash scripts/build-image.sh"
  exit 1
fi

echo "Enviando ${REGISTRY_IMAGE} (${VERSION}, ${VERSION}-${COMMIT_SHA}, latest)..."

docker tag "${IMAGE_NAME}:${VERSION}" "${REGISTRY_IMAGE}:${VERSION}"
docker tag "${IMAGE_NAME}:${VERSION}" "${REGISTRY_IMAGE}:${VERSION}-${COMMIT_SHA}"
docker tag "${IMAGE_NAME}:${VERSION}" "${REGISTRY_IMAGE}:latest"

docker push "${REGISTRY_IMAGE}:${VERSION}"
docker push "${REGISTRY_IMAGE}:${VERSION}-${COMMIT_SHA}"
docker push "${REGISTRY_IMAGE}:latest"

echo "Pronto. Imagem disponível em: ${REGISTRY_IMAGE}:${VERSION}"
