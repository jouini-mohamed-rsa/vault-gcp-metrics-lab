# Vault + GCP Cloud Monitoring - Production-Grade PoC

A **production-grade** Proof of Concept for deploying HashiCorp Vault on Google Cloud Platform with **Terraform-managed monitoring infrastructure**.

## 🎯 What This Does

Deploys a complete HashiCorp Vault setup on GCP with:
- ✅ **Vault 1.20.4** (Latest stable version with security fixes)
- ✅ **Automated Vault installation** and configuration
- ✅ **Terraform-managed monitoring** (dashboards, alerts, uptime checks)
- ✅ **5 automated alert policies** (memory, sealed state, requests, downtime, health)
- ✅ **Custom Vault dashboard** with 6 metric widgets
- ✅ **Email notifications** for critical events
- ✅ **Uptime monitoring** with health checks
- ✅ **Cloud Logging integration** (complete audit trails)
- ✅ **Demo use case scripts** (generates realistic traffic)
- ✅ **Google Ops Agent** for metrics/logs collection
- ✅ **Service account** with proper IAM permissions
- ✅ **Firewall rules** for secure access
- ✅ **All infrastructure as code** (100% Terraform)

## 📁 Project Structure

```
vault-gcp-metrics-lab/
├── 1-infrastructure/               # Phase 1: Core infrastructure
│   ├── main.tf                     # VM, Service Account, Firewall, APIs
│   ├── variables.tf                # Infrastructure variables
│   ├── outputs.tf                  # VM details, IPs, SSH command
│   ├── terraform.tfvars            # Your configuration
│   └── scripts/
│       └── startup.sh              # VM startup script (installs Vault)
│
├── 2-monitoring/                   # Phase 2: Monitoring & alerts
│   ├── main.tf                     # Dashboards, Alerts, Uptime Checks
│   ├── variables.tf                # Monitoring variables
│   ├── outputs.tf                  # Dashboard & alert URLs
│   └── terraform.tfvars            # Monitoring configuration
│
├── README.md                       # ⭐ This file - project overview (START HERE)
├── DEPLOYMENT.md                   # Complete deployment guide
└── 01-dashboard-overview.png       # Dashboard screenshot
```

## 📖 Documentation

**Start here based on your needs:**

| File | Purpose |
|------|---------|
| **📋 README.md** | Project overview - what this does, quick start |
| **🚀 DEPLOYMENT.md** | Complete step-by-step deployment guide |

**Quick navigation:**
- **Want to deploy?** → Go straight to `DEPLOYMENT.md`
- **Just exploring?** → Read this README

## 🚀 Quick Start

**Complete deployment instructions:** See [`DEPLOYMENT.md`](DEPLOYMENT.md)

### 30-Second Overview

1. **Prerequisites**: GCP account, Terraform, gcloud CLI
2. **Authenticate**: `gcloud auth application-default login`
3. **Deploy Infrastructure**: `cd 1-infrastructure && terraform apply`
4. **Initialize Vault**: SSH and run initialization scripts
5. **Deploy Monitoring**: `cd ../2-monitoring && terraform apply`
6. **Verify**: Check dashboard, metrics, logs, alerts

**Deployment time**: 15-20 minutes  
**Monthly cost**: ~$30-35

### Essential Commands

```bash
# Authenticate to GCP
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

# Phase 1: Deploy infrastructure
cd 1-infrastructure
terraform init
terraform apply

# Phase 2: Configure Vault (manual)
gcloud compute ssh vault-poc-instance --zone=us-central1-a
sudo /root/initialize-vault.sh
vault operator unseal
vault login
sudo -E bash /root/configure-monitoring.sh

# Phase 3: Deploy monitoring
cd ../2-monitoring
terraform init
terraform apply
```

**📖 For detailed steps, see:** [`DEPLOYMENT.md`](DEPLOYMENT.md)

### Configure Vault

After deployment, SSH into the instance and run:

```bash
# SSH to instance (use command from terraform output)
gcloud compute ssh vault-poc-instance --zone=us-central1-a

# Initialize Vault (SAVE THE OUTPUT!)
sudo /root/initialize-vault.sh

# Unseal Vault
export VAULT_ADDR="http://127.0.0.1:8200"
vault operator unseal <PASTE_UNSEAL_KEY>

# Login
vault login <PASTE_ROOT_TOKEN>

# Configure monitoring
sudo bash /root/configure-monitoring.sh
```

### Verify

1. **Metrics**: Go to GCP Console → Monitoring → Metrics Explorer → Search "vault"
2. **Logs**: Go to GCP Console → Logging → Logs Explorer → Query `vault_audit`
3. **Dashboard**: Go to GCP Console → Monitoring → Dashboards → "Vault Production Monitoring"
4. **UI**: Open the Vault UI URL from terraform output

### Dashboard Overview

![Vault Production Monitoring Dashboard](./01-dashboard-overview.png)
*Vault Production Monitoring Dashboard - Real-time metrics visualization*

## 📊 What Gets Deployed

| Resource | Description | Purpose |
|----------|-------------|---------|
| **Compute Instance** | e2-medium VM (2 vCPUs, 4GB RAM) | Runs Vault server |
| **Service Account** | vault-poc-sa | Allows VM to send metrics/logs |
| **Firewall Rule** | Port 8200 access | Access Vault UI and API |
| **Ops Agent** | Monitoring agent | Collects metrics and logs |
| **IAM Bindings** | Monitoring/Logging permissions | Write metrics and logs to GCP |
| **🆕 Custom Dashboard** | Vault Production Monitoring | 6 metric widgets |
| **🆕 Alert Policies (5x)** | Automated monitoring | High memory, sealed, requests, down, health |
| **🆕 Uptime Check** | Health endpoint monitoring | 60-second intervals |

## 🔍 Key Features

### Vault Configuration
- **Storage**: File backend (simple for PoC)
- **UI**: Enabled on port 8200
- **Telemetry**: Prometheus metrics enabled
- **Audit Logging**: File-based audit logs

### Monitoring
- **Metrics collected**: Memory usage, request counts, token counts, goroutines, etc.
- **Logs collected**: Complete audit trail of all Vault operations
- **Collection frequency**: Every 60 seconds
- **Retention**: Configured in GCP Cloud Monitoring

### Security Features
- Dedicated service account with minimal permissions
- Firewall rules restrict access
- Audit logging enabled by default
- Vault sealed by default (requires manual unseal)

## 💰 Cost Estimate

**Monthly cost**: ~$30-35
- Compute Engine (e2-medium): ~$25/month
- Cloud Monitoring: ~$5/month
- Cloud Logging: ~$0-5/month (depends on volume)

**To save costs**:
```bash
# Stop instance when not in use
gcloud compute instances stop vault-poc-instance --zone=us-central1-a

# Destroy everything
terraform destroy
```

## 🔐 Security Notes

**This is a PoC configuration**. For production:

### ❌ Not Production-Ready
- TLS disabled (uses HTTP)
- Single unseal key
- File storage backend
- Public IP address
- Simplified firewall rules

### ✅ Production Requirements
- Enable TLS with valid certificates
- Use GCS storage backend
- Implement auto-unseal with Cloud KMS
- Deploy in HA mode (3-5 nodes)
- Use private networking (VPC, VPN)
- Multiple unseal keys split among team members
- Implement backup and disaster recovery
- Use Vault Enterprise for advanced features

## 📚 External Resources

- **[Vault Documentation](https://developer.hashicorp.com/vault)**
- **[GCP Monitoring Docs](https://cloud.google.com/monitoring/docs)**
- **[Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)**

## 🛠️ Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP Project ID | *required* |
| `region` | GCP region | `us-central1` |
| `zone` | GCP zone | `us-central1-a` |
| `instance_name` | VM instance name | `vault-poc-instance` |
| `machine_type` | VM machine type | `e2-medium` |
| `vault_version` | Vault version to install | `1.17.6` |
| `allowed_cidrs` | IPs allowed to access Vault | `["0.0.0.0/0"]` ⚠️ |

## 🧪 Testing the Setup

Once deployed, try these tests:

```bash
# Enable KV secrets engine
vault secrets enable -version=2 kv

# Create a test secret
vault kv put kv/test username="demo" password="secret123"

# Read it back
vault kv get kv/test

# View in UI
# Navigate to Vault UI → Secrets → kv/ → test
```

Then verify in GCP:
- **Metrics**: See request counts increase in Cloud Monitoring
- **Logs**: See the read/write operations in Cloud Logging

## 🐛 Troubleshooting

### Vault won't start
```bash
sudo systemctl status vault
sudo journalctl -u vault -f
```

### No metrics appearing
```bash
sudo systemctl status google-cloud-ops-agent
sudo journalctl -u google-cloud-ops-agent -n 50
```

### Can't access UI
```bash
# Check firewall
gcloud compute firewall-rules describe vault-poc-allow-ui

# Check if Vault is listening
ss -tlnp | grep 8200
```

### Vault is sealed after restart
```bash
export VAULT_ADDR="http://127.0.0.1:8200"
vault operator unseal <YOUR_UNSEAL_KEY>
```

## 🗑️ Cleanup

When you're done:

```bash
# Destroy all resources
terraform destroy

# Confirm with: yes
```

This removes all resources except:
- Enabled APIs (they remain enabled)
- Cloud Monitoring data (subject to retention policy)

## 📝 License

This is a PoC/demonstration project. Use at your own risk. Not officially supported by HashiCorp or Google.

## 🤝 Contributing

This is a learning/demo project. Feel free to:
- Modify the Terraform configurations
- Add new monitoring widgets
- Adjust alert thresholds
- Create additional use cases
- Adapt it for your own environment

All code is well-commented and organized for easy understanding.

## 📞 Support

For issues with:
- **Vault**: https://discuss.hashicorp.com/
- **GCP**: https://cloud.google.com/support
- **Terraform**: https://discuss.hashicorp.com/c/terraform

---

**Happy Vaulting!** 🔐

