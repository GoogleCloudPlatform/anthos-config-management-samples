#!/bin/bash

# Render kustomizations

set -o errexit -o nounset -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "${REPO_ROOT}"

cd config/
for tenant in tenant-*; do
    mkdir -p ../deploy/${tenant}
    if [[ -f ${tenant}/kustomization.yaml ]]; then
        echo "Rendering ${tenant}"
        kustomize build ${tenant} > ../deploy/${tenant}/manifest.yaml
    fi
done
