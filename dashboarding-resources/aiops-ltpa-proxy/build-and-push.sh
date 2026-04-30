#!/bin/bash
set -eo pipefail

# Configuration
# Update these variables for your environment
REGISTRY="${REGISTRY:-your-registry.com}"
IMAGE_NAME="${IMAGE_NAME:-aiops-ltpa-proxy}"
TAG="${TAG:-$(date +"%Y%m%d-%H%M")}"

# Full image reference
IMAGE_REF="${REGISTRY}/${IMAGE_NAME}:${TAG}"
IMAGE_REF_LATEST="${REGISTRY}/${IMAGE_NAME}:latest"

echo "=========================================="
echo "Building AIOps LTPA Proxy Container Image"
echo "=========================================="
echo "Registry: ${REGISTRY}"
echo "Image: ${IMAGE_NAME}"
echo "Tag: ${TAG}"
echo "Full reference: ${IMAGE_REF}"
echo "=========================================="

# Build the image using podman (or docker)
echo "Building image..."
podman build \
  --platform=linux/amd64 \
  -f ./Containerfile \
  -t "${IMAGE_REF}" \
  -t "${IMAGE_REF_LATEST}" \
  .

echo "✓ Build complete"

# Push the image
echo "Pushing image to registry..."
podman push "${IMAGE_REF}"
podman push "${IMAGE_REF_LATEST}"

echo "✓ Push complete"
echo ""
echo "=========================================="
echo "Image pushed successfully!"
echo "=========================================="
echo "Tagged image: ${IMAGE_REF}"
echo "Latest image: ${IMAGE_REF_LATEST}"
echo ""
echo "To use this image in your deployment:"
echo "  Update k8s/deployment.yaml line 25:"
echo "  image: ${IMAGE_REF}"
echo ""
echo "Or use the latest tag:"
echo "  image: ${IMAGE_REF_LATEST}"
echo "=========================================="

# Made with Bob
