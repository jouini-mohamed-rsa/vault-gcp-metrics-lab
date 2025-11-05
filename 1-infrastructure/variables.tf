# Variables for Vault Infrastructure

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the Vault instance"
  type        = string
  default     = "us-central1-a"
}

variable "instance_name" {
  description = "Name of the Vault VM instance"
  type        = string
  default     = "vault-poc-instance"
}

variable "machine_type" {
  description = "Machine type for Vault instance"
  type        = string
  default     = "e2-medium"
}

variable "os_image" {
  description = "OS image for the Vault instance"
  type        = string
  default     = "debian-cloud/debian-11"
}

variable "vault_version" {
  description = "Version of Vault to install"
  type        = string
  default     = "1.20.4"
}

variable "allowed_cidrs" {
  description = "List of CIDR blocks allowed to access Vault UI"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # WARNING: Restrict this in production!
}

