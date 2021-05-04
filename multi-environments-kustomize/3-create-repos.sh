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
# !/bin/bash

if [[ -z "$GITHUB_USERNAME" ]]; then
    echo "Must provide GITHUB_USERNAME in environment" 1>&2
    exit 1
fi

echo "😸 Creating foo-config-source repo..."
curl -u ${GITHUB_USERNAME}:${GITHUB_TOKEN} https://api.github.com/user/repos -d '{"name":"foo-config-source"}'
git clone "https://github.com/${GITHUB_USERNAME}/foo-config-source.git" 
cp -r config-source/* foo-config-source 
cd foo-config-source 
git add .; git commit -m "Initialize"; git push origin main 
cd .. 

echo "😸 Creating foo-config-dev repo..."
curl -u ${GITHUB_USERNAME}:${GITHUB_TOKEN} https://api.github.com/user/repos -d '{"name":"foo-config-dev"}'
git clone "https://github.com/${GITHUB_USERNAME}/foo-config-dev.git" 
cd foo-config-dev; touch README.md
git add .; git commit -m "Initialize"; git push origin main 
cd .. 

echo "😸 Creating foo-config-prod repo..."
curl -u ${GITHUB_USERNAME}:${GITHUB_TOKEN} https://api.github.com/user/repos -d '{"name":"foo-config-prod"}'
git clone "https://github.com/${GITHUB_USERNAME}/foo-config-prod.git" 
cd foo-config-prod; touch README.md
git add .; git commit -m "Initialize"; git push origin main 
cd ..  