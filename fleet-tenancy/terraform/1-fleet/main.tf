/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# [START config_sync_fleet_resources]
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 5.16.0"
    }
  }
}

provider "google" {
  # project variable must be provided at runtime
  project = var.project
}

# Enable API services
resource "google_project_service" "services" {
  for_each = toset([
    "gkehub.googleapis.com",
    "container.googleapis.com",
    "connectgateway.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "anthos.googleapis.com",
    "anthosconfigmanagement.googleapis.com",
  ])
  service = each.value
  disable_on_destroy = false
}

# Declare a fleet in the project
resource "google_gke_hub_fleet" "default" {
  display_name = "my test fleet"

  depends_on = [google_project_service.services]
}

