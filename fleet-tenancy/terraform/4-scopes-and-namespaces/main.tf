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
      version = "5.15.0"
    }
  }
}

provider "google-beta" {
  credentials = var.sa_key_file
  project = var.project
}

# Fleet Scopes
resource "google_gke_hub_scope" "scope" {
  provider = google-beta
  for_each = toset([
    "backend",
    "frontend",
  ])
  scope_id = each.value
}

# Fleet Membership Bindings
resource "google_gke_hub_membership_binding" "membership-binding" {
  provider = google-beta
  for_each = {
    us-east-backend = {
      membership_binding_id = "us-east-backend"
      scope = google_gke_hub_scope.scope["backend"].name
      membership_id = "us-east-cluster"
      location = "us-east1"
    }
    us-west-backend = {
      membership_binding_id = "us-west-backend"
      scope = google_gke_hub_scope.scope["backend"].name
      membership_id = "us-west-cluster"
      location = "us-west1"
    }
    us-east-frontend = {
      membership_binding_id = "us-east-frontend"
      scope = google_gke_hub_scope.scope["frontend"].name
      membership_id = "us-east-cluster"
      location = "us-east1"
    }
    us-west-frontend = {
      membership_binding_id = "us-west-frontend"
      scope = google_gke_hub_scope.scope["frontend"].name
      membership_id = "us-west-cluster"
      location = "us-west1"
    }
    us-central-frontend = {
      membership_binding_id = "us-central-frontend"
      scope = google_gke_hub_scope.scope["frontend"].name
      membership_id = "us-central-cluster"
      location = "us-central1"
    }
  }

  membership_binding_id = each.value.membership_binding_id
  scope = each.value.scope
  membership_id = each.value.membership_id
  location = each.value.location

  depends_on = [google_gke_hub_scope.scope]
}

# Fleet Namespaces
resource "google_gke_hub_namespace" "fleet_namespace" {
  provider = google-beta

  for_each = {
    bookstore = {
      scope_id = "backend"
      scope_namespace_id = "bookstore"
      scope = google_gke_hub_scope.scope["backend"].name
    }
    shoestore = {
      scope_id = "backend"
      scope_namespace_id = "shoestore"
      scope = google_gke_hub_scope.scope["backend"].name
    }
    frontend_a = {
      scope_id = "frontend"
      scope_namespace_id = "frontend-a"
      scope = google_gke_hub_scope.scope["frontend"].name
    }
    frontend_b = {
      scope_id = "frontend"
      scope_namespace_id = "frontend-b"
      scope = google_gke_hub_scope.scope["frontend"].name
    }
  }

  scope_namespace_id = each.value.scope_namespace_id
  scope_id = each.value.scope_id
  scope = each.value.scope

  depends_on = [google_gke_hub_scope.scope]
}