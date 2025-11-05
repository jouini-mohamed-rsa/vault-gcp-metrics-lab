# Outputs for Vault Infrastructure

output "instance_name" {
  description = "Name of the Vault instance"
  value       = google_compute_instance.vault.name
}

output "instance_zone" {
  description = "Zone where Vault instance is deployed"
  value       = google_compute_instance.vault.zone
}

output "instance_external_ip" {
  description = "External IP address of the Vault instance"
  value       = google_compute_instance.vault.network_interface[0].access_config[0].nat_ip
}

output "vault_ui_url" {
  description = "URL to access Vault UI"
  value       = "http://${google_compute_instance.vault.network_interface[0].access_config[0].nat_ip}:8200"
}

output "service_account_email" {
  description = "Service account email used by Vault"
  value       = google_service_account.vault.email
}

output "ssh_command" {
  description = "Command to SSH into the Vault instance"
  value       = "gcloud compute ssh ${google_compute_instance.vault.name} --zone=${google_compute_instance.vault.zone} --project=${var.project_id}"
}

output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value       = <<-EOT

    ========================================
    ✅ Infrastructure Deployed Successfully!
    ========================================

    📋 NEXT STEPS:

    1. Wait 3-5 minutes for Vault installation to complete

    2. SSH into the instance:
       gcloud compute ssh ${google_compute_instance.vault.name} --zone=${google_compute_instance.vault.zone} --project=${var.project_id}

    3. Initialize Vault:
       sudo /root/initialize-vault.sh
       ⚠️  SAVE THE UNSEAL KEY AND ROOT TOKEN!

    4. Unseal Vault:
       export VAULT_ADDR="http://127.0.0.1:8200"
       vault operator unseal <YOUR_UNSEAL_KEY>

    5. Login to Vault:
       vault login <YOUR_ROOT_TOKEN>

    6. Configure monitoring:
       export VAULT_TOKEN=<YOUR_ROOT_TOKEN>
       sudo -E bash /root/configure-monitoring.sh
       ⚠️  SAVE THE PROMETHEUS TOKEN!

    7. Run demo use cases (generates metrics):
       sudo bash /root/demo-use-cases.sh

    8. Wait 5-10 minutes for metrics to appear in GCP

    9. Deploy monitoring (alerts & dashboards):
       cd ../2-monitoring
       # Update terraform.tfvars with the instance details from this output
       terraform init
       terraform apply

    ========================================
    📊 VAULT ACCESS:
    ========================================

    • Vault UI: http://${google_compute_instance.vault.network_interface[0].access_config[0].nat_ip}:8200
    • SSH Command: gcloud compute ssh ${google_compute_instance.vault.name} --zone=${google_compute_instance.vault.zone}
    • External IP: ${google_compute_instance.vault.network_interface[0].access_config[0].nat_ip}

    ========================================
  EOT
}

