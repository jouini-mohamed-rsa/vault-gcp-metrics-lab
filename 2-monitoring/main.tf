# Vault PoC Monitoring
# This Terraform configuration creates monitoring dashboards, alerts, and uptime checks

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

# Data source to get the Vault instance details
data "google_compute_instance" "vault" {
  name = var.instance_name
  zone = var.instance_zone
}

# Alert Policy: High Memory Usage
resource "google_monitoring_alert_policy" "vault_high_memory" {
  display_name = "Vault - High Memory Usage"
  combiner     = "OR"
  
  conditions {
    display_name = "Memory usage above 80%"
    
    condition_threshold {
      filter          = "resource.type = \"prometheus_target\" AND metric.type = \"prometheus.googleapis.com/vault_runtime_alloc_bytes/gauge\" AND resource.labels.job = \"vault\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 3355443200  # 3.2 GB (80% of 4GB)
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content = <<-EOT
      Vault memory usage has exceeded 80% of available memory.
      
      **Action Required:**
      1. Check Vault logs: `journalctl -u vault -n 100`
      2. Review active connections: `vault status`
      3. Consider scaling up the instance size
      
      **SSH Command:**
      gcloud compute ssh ${var.instance_name} --zone=${var.instance_zone}
    EOT
  }
}

# Alert Policy: Vault Sealed
resource "google_monitoring_alert_policy" "vault_sealed" {
  display_name = "Vault - Instance is Sealed"
  combiner     = "OR"
  
  conditions {
    display_name = "Vault sealed state detected"
    
    condition_threshold {
      filter          = "resource.type = \"prometheus_target\" AND metric.type = \"prometheus.googleapis.com/vault_core_unsealed/gauge\" AND resource.labels.job = \"vault\""
      duration        = "60s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"  # 30 minutes (minimum allowed)
  }

  documentation {
    content = <<-EOT
      Vault instance is in a sealed state and cannot serve requests.
      
      **Action Required:**
      1. SSH into the instance
      2. Unseal Vault: `vault operator unseal`
      3. Check logs: `journalctl -u vault -f`
      
      **SSH Command:**
      gcloud compute ssh ${var.instance_name} --zone=${var.instance_zone}
    EOT
  }
}

# Alert Policy: High Request Rate
resource "google_monitoring_alert_policy" "vault_high_requests" {
  display_name = "Vault - High Request Rate"
  combiner     = "OR"
  
  conditions {
    display_name = "Request rate above 1000 req/min"
    
    condition_threshold {
      filter          = "resource.type = \"prometheus_target\" AND metric.type = \"prometheus.googleapis.com/vault_core_handle_request_sum/summary:counter\" AND resource.labels.job = \"vault\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 1000
      
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content = <<-EOT
      Vault is experiencing unusually high request rates.
      
      **Possible Causes:**
      - Legitimate traffic spike
      - Application misconfiguration causing request loops
      - Potential DoS attack
      
      **Action Required:**
      1. Review audit logs in Cloud Logging
      2. Check client application behavior
      3. Review active token count: `vault token lookup`
    EOT
  }
}

# Alert Policy: Instance Down
resource "google_monitoring_alert_policy" "vault_instance_down" {
  display_name = "Vault - Instance Not Responding"
  combiner     = "OR"
  
  conditions {
    display_name = "Vault instance is down"
    
    condition_absent {
      filter   = "resource.type = \"prometheus_target\" AND metric.type = \"prometheus.googleapis.com/vault_runtime_num_goroutines/gauge\" AND resource.labels.job = \"vault\""
      duration = "300s"
      
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"  # GAUGE metrics require ALIGN_MEAN, not ALIGN_RATE
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"  # 30 minutes (minimum allowed)
  }

  documentation {
    content = <<-EOT
      Vault instance is not reporting metrics - it may be down.
      
      **Action Required:**
      1. Check instance status: `gcloud compute instances describe ${var.instance_name} --zone=${var.instance_zone}`
      2. Check Vault service: `gcloud compute ssh ${var.instance_name} --zone=${var.instance_zone} --command="sudo systemctl status vault"`
      3. Review system logs in Cloud Logging
    EOT
  }
}

# Monitoring Dashboard
resource "google_monitoring_dashboard" "vault_dashboard" {
  dashboard_json = jsonencode({
    displayName = "Vault Production Monitoring"
    
    mosaicLayout = {
      columns = 12
      
      tiles = [
        # Vault Status
        {
          width  = 4
          height = 4
          widget = {
            title = "Vault Sealed Status"
            scorecard = {
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type = \"prometheus_target\" AND metric.type = \"prometheus.googleapis.com/vault_core_unsealed/gauge\" AND resource.labels.job = \"vault\""
                  aggregation = {
                    alignmentPeriod  = "60s"
                    perSeriesAligner = "ALIGN_MEAN"
                  }
                }
              }
            }
          }
        },
        
        # Memory Usage
        {
          width  = 8
          height = 4
          xPos   = 4
          widget = {
            title = "Memory Usage (Bytes)"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"prometheus_target\" AND metric.type = \"prometheus.googleapis.com/vault_runtime_alloc_bytes/gauge\" AND resource.labels.job = \"vault\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_MEAN"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
              yAxis = {
                scale = "LINEAR"
              }
            }
          }
        },
        
        # Request Rate
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Request Rate (req/sec)"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"prometheus_target\" AND metric.type = \"prometheus.googleapis.com/vault_core_handle_request_sum/summary:counter\" AND resource.labels.job = \"vault\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
            }
          }
        },
        
        # Total System Memory
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Total System Memory (Bytes)"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"prometheus_target\" AND metric.type = \"prometheus.googleapis.com/vault_runtime_sys_bytes/gauge\" AND resource.labels.job = \"vault\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_MEAN"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
            }
          }
        },
        
        # Goroutines (System Health)
        {
          width  = 6
          height = 4
          yPos   = 8
          widget = {
            title = "Active Goroutines (System Load)"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"prometheus_target\" AND metric.type = \"prometheus.googleapis.com/vault_runtime_num_goroutines/gauge\" AND resource.labels.job = \"vault\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_MEAN"
                      }
                    }
                  }
                  plotType = "LINE"
                }
              ]
            }
          }
        },
        
        # Storage Operations
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 8
          widget = {
            title = "Storage Backend Operations"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"prometheus_target\" AND metric.type = \"prometheus.googleapis.com/vault_barrier_put_sum/summary:counter\" AND resource.labels.job = \"vault\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type = \"prometheus_target\" AND metric.type = \"prometheus.googleapis.com/vault_barrier_get_sum/summary:counter\" AND resource.labels.job = \"vault\""
                      aggregation = {
                        alignmentPeriod  = "60s"
                        perSeriesAligner = "ALIGN_RATE"
                      }
                    }
                  }
                  plotType   = "LINE"
                  targetAxis = "Y1"
                }
              ]
            }
          }
        }
      ]
    }
  })
}

# Create uptime check for Vault
resource "google_monitoring_uptime_check_config" "vault_uptime" {
  display_name = "Vault Health Check"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/v1/sys/health"
    port         = 8200
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = data.google_compute_instance.vault.network_interface[0].access_config[0].nat_ip
    }
  }

  content_matchers {
    content = "initialized"
    matcher = "CONTAINS_STRING"
  }
}

# Alert for uptime check failure
resource "google_monitoring_alert_policy" "vault_uptime_alert" {
  display_name = "Vault - Health Check Failed"
  combiner     = "OR"

  conditions {
    display_name = "Vault health endpoint not responding"

    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.vault_uptime.uptime_check_id}\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period     = "60s"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        group_by_fields      = ["resource.label.*"]
      }

      trigger {
        count = 1
      }
    }
  }

  documentation {
    content = <<-EOT
      Vault health check is failing. The instance may be down, sealed, or unreachable.
      
      **Action Required:**
      1. Check instance status: gcloud compute instances describe ${var.instance_name}
      2. Check Vault status: vault status
      3. Review logs: journalctl -u vault -f
    EOT
  }
}

