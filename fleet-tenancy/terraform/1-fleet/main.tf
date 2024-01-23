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

terraform {
  required_providers {
    google-beta = {
      source = "hashicorp/google-beta"
      version = "5.13.0"
    }
  }
}

provider "google" {
  # project variable must be provided at runtime
  project = var.project
}

# Declare a fleet in the project
resource "google_gke_hub_fleet" "default" {
  display_name = "my test fleet"
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

# Declare a service account
resource "google_service_account" "gcp_sa" {
  account_id   = var.gcp_sa_id
  display_name = var.gcp_sa_display_name
  description = var.gcp_sa_description
}

resource "google_project_iam_member" "gcp_sa_roles" {
  for_each = toset([
    "roles/gkehub.admin",
    "roles/container.admin",
    "roles/iam.serviceAccountUser",
    "roles/compute.viewer",
  ])
  role    = each.value
  member  = "serviceAccount:${google_service_account.gcp_sa.email}"
  project = var.project
}
