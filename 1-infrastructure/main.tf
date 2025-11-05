# Vault PoC Infrastructure
# This Terraform configuration deploys the core infrastructure: VM, Service Account, Firewall

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "monitoring" {
  service = "monitoring.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "logging" {
  service = "logging.googleapis.com"
  disable_on_destroy = false
}

# Create a service account for Vault VM
resource "google_service_account" "vault" {
  account_id   = "vault-poc-sa"
  display_name = "Vault PoC Service Account"
  description  = "Service account for Vault VM with monitoring permissions"
}

# Grant monitoring and logging permissions
resource "google_project_iam_member" "vault_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vault.email}"
}

resource "google_project_iam_member" "vault_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vault.email}"
}

# Create firewall rule for Vault access
resource "google_compute_firewall" "vault_ui" {
  name    = "vault-poc-allow-ui"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8200"]
  }

  source_ranges = var.allowed_cidrs
  target_tags   = ["vault-server"]
}

# Create the Vault VM instance
resource "google_compute_instance" "vault" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["vault-server"]

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = 50
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral external IP
    }
  }

  service_account {
    email  = google_service_account.vault.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-osconfig = "TRUE"
  }

  labels = {
    environment = "poc"
    application = "vault"
    goog-ops-agent-policy = "v2-x86-template-1-4-0"
  }

  metadata_startup_script = templatefile("${path.module}/scripts/startup.sh", {
    vault_version = var.vault_version
  })

  depends_on = [
    google_project_service.compute,
    google_service_account.vault
  ]
}

