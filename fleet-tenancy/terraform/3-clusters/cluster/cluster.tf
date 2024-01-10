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

variable "location" {
  type = string
}

variable "cluster_name" {
  type = string
}

data "google_project" "project" {
  provider = google-beta
}

resource "google_container_cluster" "cluster" {
  provider = google-beta
  name               = var.cluster_name
  location           = var.location
  initial_node_count = 3
  project = data.google_project.project.project_id
  fleet {
    project = data.google_project.project.project_id
  }
  workload_identity_config {
    workload_pool = "${data.google_project.project.project_id}.svc.id.goog"
  }
  deletion_protection = false
}