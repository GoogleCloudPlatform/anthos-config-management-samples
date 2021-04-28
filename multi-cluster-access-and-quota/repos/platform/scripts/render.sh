#!/usr/bin/env bash

# Render kustomizations

set -o errexit -o nounset -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "${REPO_ROOT}"

cd config/
for CLUSTER_PATH in clusters/*/; do
    mkdir -p ../deploy/${CLUSTER_PATH}
    if [[ -f ${CLUSTER_PATH}/kustomization.yaml ]]; then
        echo "Rendering ${CLUSTER_PATH}"
        kustomize build ${CLUSTER_PATH} > ../deploy/${CLUSTER_PATH}manifest.yaml
    fi
    if [[ -d ${CLUSTER_PATH}namespaces/ ]]; then
        for NAMESPACE_PATH in ${CLUSTER_PATH}namespaces/*/ ; do
            if [[ -f ${NAMESPACE_PATH}/kustomization.yaml ]]; then
                mkdir -p ../deploy/${NAMESPACE_PATH}
                echo "Rendering ${NAMESPACE_PATH}"
                kustomize build ${NAMESPACE_PATH} > ../deploy/${NAMESPACE_PATH}manifest.yaml
            fi
        done
    fi
done
