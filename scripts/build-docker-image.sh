#!/usr/bin/env bash
# Build da imagem Docker para produção (GS2 Next Connecta).
# Uso: ./scripts/build-docker-image.sh [IMAGE_NAME] [IMAGE_TAG]
# Exemplo: ./scripts/build-docker-image.sh
# Exemplo: ./scripts/build-docker-image.sh meu-registry/gs2-next-connecta v1.0.0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_NAME="${1:-gs2-next-connecta}"
IMAGE_TAG="${2:-latest}"

echo "Building Docker image: $IMAGE_NAME:$IMAGE_TAG"
echo "Context: $ROOT_DIR"
echo ""

cd "$ROOT_DIR"
docker build -t "$IMAGE_NAME:$IMAGE_TAG" -f ./docker/Dockerfile .

echo ""
echo "Done. Image: $IMAGE_NAME:$IMAGE_TAG"
