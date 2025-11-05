# Variables for Vault Monitoring

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "instance_name" {
  description = "Name of the Vault VM instance (from infrastructure module)"
  type        = string
  default     = "vault-poc-instance"
}

variable "instance_zone" {
  description = "Zone where Vault instance is deployed (from infrastructure module)"
  type        = string
  default     = "us-central1-a"
}

