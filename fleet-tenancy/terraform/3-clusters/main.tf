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

module "us-west-cluster" {
  source = "./cluster"
  cluster_name = "us-west-cluster"
  location="us-west1-a"
}

module "us-east-cluster" {
  source = "./cluster"
  cluster_name = "us-east-cluster"
  location="us-east1-b"
}

module "us-central-cluster" {
  source = "./cluster"
  cluster_name = "us-central-cluster"
  location="us-central1-c"
}
