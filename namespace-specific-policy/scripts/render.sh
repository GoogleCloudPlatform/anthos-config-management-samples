#!/bin/bash

# Render kustomizations

set -o errexit -o nounset -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "${REPO_ROOT}"

cd configsync-src/
for tenant in tenant-*; do
    if [[ -f ${tenant}/kustomization.yaml ]]; then
        echo "Rendering ${tenant}"
        kustomize build ${tenant} -o ../configsync/${tenant}/
    fi
done
