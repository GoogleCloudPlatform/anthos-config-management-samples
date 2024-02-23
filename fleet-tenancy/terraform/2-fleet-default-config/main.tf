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
# [START fleet_default_config_example]
terraform {
  required_providers {
    google-beta = {
      source = "hashicorp/google-beta"
      version = "5.16.0"
    }
  }
}

provider "google-beta" {
  credentials = var.sa_key_file
  project = var.project
}

resource "google_gke_hub_feature" "feature" {
  name = "configmanagement"
  location = "global"
  provider = google-beta
  fleet_default_member_config {
    configmanagement {
      # version = "1.17.0" # Use the default latest version instead of 1.17.0 because the version field is mislocated: b/314995011
      config_sync {
        source_format = "unstructured"
        git {
          sync_repo = "https://github.com/GoogleCloudPlatform/anthos-config-management-samples"
          sync_branch = "main"
          policy_dir = "fleet-tenancy/config"
          secret_type = "none"
        }
      }
    }
  }
}
# [END fleet_default_config_example] 
