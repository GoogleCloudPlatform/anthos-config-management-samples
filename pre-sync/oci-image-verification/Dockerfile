# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Build stage
FROM golang:1.23 as builder

WORKDIR /app
COPY . .

RUN go mod init presync-webhook-server || true && go mod tidy

# Set GOPATH since it is not already set.
ENV GOPATH=/go

# Update PATH with go specific locations.
ENV PATH "/go/bin:/usr/local/go/bin:$PATH"

# Build the webhook server binary for Linux
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o webhook-server main.go

# Install Cosign
RUN wget -O cosign https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 && \
    chmod +x cosign && \
    mv cosign /usr/local/bin/cosign

RUN chmod +x /app/webhook-server

# Final stage
FROM gcr.io/google.com/cloudsdktool/google-cloud-cli:449.0.0-slim
WORKDIR /

RUN apt-get update && apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin

# Set GOPATH since it is not already set.
ENV GOPATH=/go

# Update PATH with go specific locations.
ENV PATH "/go/bin:/usr/local/go/bin:$PATH"

# Copy the built webhook server binary
COPY --from=builder /app/webhook-server /webhook-server

# Copy the cosign and crane binaries
COPY --from=builder /usr/local/bin/cosign /usr/local/bin/cosign

# Ensure that the binaries have executable permissions
RUN chmod +x /webhook-server
RUN chmod +x /usr/local/bin/cosign

# Command to run the webhook server
CMD ["/webhook-server"]