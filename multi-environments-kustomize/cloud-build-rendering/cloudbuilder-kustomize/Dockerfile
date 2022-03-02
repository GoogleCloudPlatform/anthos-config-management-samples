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

# [START anthosconfig_multi_environments_kustomize_dockerfile] 
FROM gcr.io/cloud-builders/kubectl:latest 
RUN apt-get update && apt-get install -y wget 

RUN wget https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.0.5/kustomize_v4.0.5_linux_amd64.tar.gz 

RUN tar xf kustomize_v4.0.5_linux_amd64.tar.gz -C /usr/local/bin 
# [END anthosconfig_multi_environments_kustomize_dockerfile] 
