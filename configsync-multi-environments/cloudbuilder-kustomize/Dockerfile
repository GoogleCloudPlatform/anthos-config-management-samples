FROM gcr.io/cloud-builders/kubectl:latest 
RUN apt-get update && apt-get install -y wget 

RUN wget https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.0.5/kustomize_v4.0.5_linux_amd64.tar.gz 

RUN tar xf kustomize_v4.0.5_linux_amd64.tar.gz -C /usr/local/bin 
