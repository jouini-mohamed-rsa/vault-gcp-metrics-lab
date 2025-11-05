# Outputs for Vault Monitoring

output "dashboard_url" {
  description = "URL to Vault Production Monitoring Dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards?project=${var.project_id}"
}

output "metrics_explorer_url" {
  description = "URL to Cloud Monitoring Metrics Explorer"
  value       = "https://console.cloud.google.com/monitoring/metrics-explorer?project=${var.project_id}"
}

output "uptime_check_url" {
  description = "URL to Uptime Check monitoring"
  value       = "https://console.cloud.google.com/monitoring/uptime?project=${var.project_id}"
}

output "alert_policies_url" {
  description = "URL to Alert Policies"
  value       = "https://console.cloud.google.com/monitoring/alerting/policies?project=${var.project_id}"
}

output "logs_url" {
  description = "URL to Vault audit logs"
  value       = "https://console.cloud.google.com/logs/query?project=${var.project_id}"
}

output "alert_policies" {
  description = "Alert policies created for Vault monitoring"
  value = {
    high_memory    = google_monitoring_alert_policy.vault_high_memory.name
    sealed         = google_monitoring_alert_policy.vault_sealed.name
    high_requests  = google_monitoring_alert_policy.vault_high_requests.name
    instance_down  = google_monitoring_alert_policy.vault_instance_down.name
    uptime_check   = google_monitoring_alert_policy.vault_uptime_alert.name
  }
}

output "next_steps" {
  description = "What to do after monitoring deployment"
  value       = <<-EOT

    ========================================
    ✅ Monitoring Deployed Successfully!
    ========================================

    📊 DASHBOARDS & MONITORING:

    • Production Dashboard:
      https://console.cloud.google.com/monitoring/dashboards?project=${var.project_id}
      Search for: "Vault Production Monitoring"

    • Metrics Explorer:
      https://console.cloud.google.com/monitoring/metrics-explorer?project=${var.project_id}

    • Uptime Checks:
      https://console.cloud.google.com/monitoring/uptime?project=${var.project_id}

    • Alert Policies:
      https://console.cloud.google.com/monitoring/alerting/policies?project=${var.project_id}

    • Audit Logs:
      https://console.cloud.google.com/logs/query?project=${var.project_id}
      Query: resource.type="gce_instance" log_id("vault_audit")

    ========================================
    🔔 ALERT POLICIES:
    ========================================

    ✅ ACTIVE - 5 alert policies are monitoring Vault:

    1. High Memory Usage (>80%)
    2. Vault Sealed State
    3. High Request Rate (>1000 req/min)
    4. Instance Down/Not Responding
    5. Health Check Failures

    Note: Alert policies are created but no notification channels configured.
    You can manually add notification channels in the GCP Console if needed.

    ========================================
    ✅ MONITORING IS NOW COMPLETE!
    ========================================

    Your Vault PoC is fully operational with:
    ✅ Infrastructure deployed
    ✅ Vault running and configured
    ✅ Metrics flowing to Cloud Monitoring
    ✅ Dashboards visualizing data
    ✅ Alert policies monitoring health
    ✅ Uptime checks active

    ========================================
  EOT
}

