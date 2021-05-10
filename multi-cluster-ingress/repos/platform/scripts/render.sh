#!/usr/bin/env bash

# Render kustomizations

set -o errexit -o nounset -o pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "${REPO_ROOT}"

SRC="configsync-src/"
DEST="configsync/"

for CLUSTER_PATH in "${SRC}/clusters/"*/; do
    CLUSTER_PATH="${CLUSTER_PATH#"${SRC}/"}" # remove prefix
    CLUSTER_PATH="${CLUSTER_PATH%"/"}" # remove suffix

    # Render cluster-specific cluster-scoped resources
    if [[ -f "${SRC}/${CLUSTER_PATH}/kustomization.yaml" ]]; then
        echo "Rendering ${CLUSTER_PATH}/"
        mkdir -p "${DEST}/${CLUSTER_PATH}/"
        kustomize build "${SRC}/${CLUSTER_PATH}/" -o "${DEST}/${CLUSTER_PATH}/"
    fi
    
    if [[ -d "${SRC}/${CLUSTER_PATH}/namespaces/" ]]; then
        for NAMESPACE_PATH in "${SRC}/${CLUSTER_PATH}/namespaces/"*/ ; do
            NAMESPACE_PATH="${NAMESPACE_PATH#"${SRC}/"}" # remove prefix
            NAMESPACE_PATH="${NAMESPACE_PATH%"/"}" # remove suffix

            # Render cluster-specific namespace-specific namespace-scoped resources
            if [[ -f "${SRC}/${NAMESPACE_PATH}/kustomization.yaml" ]]; then
                echo "Rendering ${NAMESPACE_PATH}/"
                mkdir -p "${DEST}/${NAMESPACE_PATH}/"
                kustomize build "${SRC}/${NAMESPACE_PATH}/" -o "${DEST}/${NAMESPACE_PATH}/"
            fi
        done
    fi
done
