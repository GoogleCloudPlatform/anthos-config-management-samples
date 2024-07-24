#!/bin/bash

# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# [START anthosconfig_scripts_render]
# Render kustomizations

set -o errexit -o nounset -o pipefail

declare -a teams=("team-a" "team-b" "team-c" "external-team")

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "${REPO_ROOT}"

cd configsync-src/example
if [[ -f kustomization.yaml ]]; then
    kustomize build --load-restrictor=LoadRestrictionsNone -o ../../manual-rendering/configsync
fi

cd "${REPO_ROOT}/manual-rendering/configsync"

for team in "${teams[@]}"
do
    echo "Rendering ${team}"
    for file in ${team}*.yaml *${team}.yaml; do
        mv "$file" ${team}/
    done
done
# [END anthosconfig_scripts_render]