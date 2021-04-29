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