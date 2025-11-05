# Vault + GCP Monitoring - Deployment Guide

Complete step-by-step guide to deploy HashiCorp Vault with GCP Cloud Monitoring using the **two-phase deployment approach**.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [GCP Authentication Setup](#gcp-authentication-setup)
3. [Phase 1: Deploy Infrastructure](#phase-1-deploy-infrastructure)
4. [Phase 2: Configure Vault](#phase-2-configure-vault)
5. [Phase 3: Deploy Monitoring](#phase-3-deploy-monitoring)
6. [Verification & Testing](#verification--testing)
7. [Troubleshooting](#troubleshooting)
8. [Cleanup](#cleanup)

---

## 📌 Prerequisites

### Required Tools

```bash
# Check if tools are installed
gcloud --version     # Google Cloud SDK
terraform --version  # Terraform >= 1.0
git --version        # Git
```

### Install if missing

**macOS**:
```bash
brew install google-cloud-sdk terraform git
```

**Linux**:
```bash
# Google Cloud SDK
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

**Windows**: Use [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) and [Terraform](https://www.terraform.io/downloads) installers

### GCP Requirements

- Active GCP account
- Project with billing enabled
- Owner or Editor role on project

---

## 🔐 GCP Authentication Setup

### Step 1: Login to GCP

```bash
# Login with your Google account
gcloud auth login
```

### Step 2: Set Your Project

```bash
# List your projects
gcloud projects list

# Set active project
gcloud config set project YOUR_PROJECT_ID
```

### Step 3: Enable Application Default Credentials

```bash
# This allows Terraform to authenticate
gcloud auth application-default login
```

### Step 4: Verify Authentication

```bash
# Should show your project ID
gcloud config get-value project

# Should show your email
gcloud auth list
```

---

## 🏗️ Phase 1: Deploy Infrastructure

This phase deploys the core infrastructure: VM, Service Account, Firewall, and Vault installation.

### Step 1: Navigate to Infrastructure Directory

```bash
cd 1-infrastructure
```

### Step 2: Configure Variables

Edit `terraform.tfvars`:

```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"
zone       = "us-central1-a"

instance_name = "vault-poc-instance"
machine_type  = "e2-medium"

vault_version = "1.20.4"

# IMPORTANT: Restrict to your IP for security!
# Find your IP: https://whatismyipaddress.com/
allowed_cidrs = ["YOUR_IP/32"]
```

### Step 3: Initialize Terraform

```bash
terraform init
```

**Expected output:**
```
Initializing provider plugins...
- Installing hashicorp/google v5.x.x...
Terraform has been successfully initialized!
```

### Step 4: Preview Changes

```bash
terraform plan
```

**Review what will be created:**
- ✅ 3 API enablements
- ✅ 1 Service Account
- ✅ 2 IAM bindings
- ✅ 1 Firewall rule
- ✅ 1 VM instance

### Step 5: Deploy Infrastructure

```bash
terraform apply
```

**Type `yes` when prompted**

**Deployment time:** 2-3 minutes

**Expected output:**
```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

instance_external_ip = "34.123.45.67"
instance_name = "vault-poc-instance"
instance_zone = "us-central1-a"
vault_ui_url = "http://34.123.45.67:8200"
ssh_command = "gcloud compute ssh vault-poc-instance --zone=us-central1-a"
```

**💡 IMPORTANT:** Save these outputs! You'll need them for Phase 3.

### Step 6: Wait for Vault Installation

The VM startup script installs Vault automatically. Wait 3-5 minutes.

**Check installation progress:**

```bash
# SSH into the VM
gcloud compute ssh vault-poc-instance --zone=us-central1-a --project=<PROJECT-ID>

# Check Vault installation
vault --version
# Should show: Vault v1.20.4

# Check Vault service
sudo systemctl status vault
# Should show: active (running)

# Exit SSH
exit
```

---

## ⚙️ Phase 2: Configure Vault

This phase initializes Vault, unseals it, and configures monitoring.

### Step 1: SSH to Vault Instance

```bash
gcloud compute ssh vault-poc-instance --zone=us-central1-a
```

### Step 2: Initialize Vault

```bash
sudo /root/initialize-vault.sh
```

**⚠️ CRITICAL: Save this output!**

Example output:
```
Initializing Vault...
Unseal Key: abc123def456ghi789...
Root Token: hvs.CAESIJ8k9L0m1N2...

IMPORTANT: Save these values securely!
Keys saved to: /root/vault-keys.txt
```

**Copy both values to a secure location!**

### Step 3: Unseal Vault

```bash
export VAULT_ADDR="http://127.0.0.1:8200"
vault operator unseal
# Paste your unseal key when prompted
```

**Verify:**
```bash
vault status
```

Should show: `Sealed: false` ✅

### Step 4: Login to Vault

```bash
vault login
# Paste your root token when prompted
```

### Step 5: Configure Monitoring

**⚠️ IMPORTANT:** Export your token first so `sudo` can use it:

```bash
export VAULT_TOKEN=<YOUR_ROOT_TOKEN>
sudo -E bash /root/configure-monitoring.sh
```

**Expected output:**
```
Creating Prometheus token for monitoring...
Success! Token created and saved to /root/prometheus-token.txt
Configuring Ops Agent...
Restarting Ops Agent...
✅ Monitoring configured successfully!
```

### Step 6: Generate Demo Traffic (Optional)

```bash
sudo -E bash /root/demo-use-cases.sh
```

This creates realistic Vault traffic for testing monitoring.

### Step 7: Exit SSH

```bash
exit
```

### Step 8: Wait for Metrics to Propagate

**⏰ IMPORTANT:** Wait 5-10 minutes for metrics to appear in GCP.

During this time:
- Ops Agent scrapes Vault metrics every 60 seconds
- Metrics are sent to Cloud Monitoring API
- GCP processes and indexes the metrics

**Check if metrics are ready:**

1. Go to: https://console.cloud.google.com/monitoring/metrics-explorer
2. Search for: `prometheus.googleapis.com/vault`
3. If you see metrics → Ready for Phase 3! ✅
4. If not → Wait a bit longer ⏰

---

## 📊 Phase 3: Deploy Monitoring

This phase creates dashboards, alert policies, and uptime checks.

### Step 1: Navigate to Monitoring Directory

```bash
cd ../2-monitoring
```

### Step 2: Configure Variables

Edit `terraform.tfvars`:

```hcl
project_id = "your-gcp-project-id"  # Same as Phase 1
region     = "us-central1"

# These must match your Phase 1 deployment
instance_name = "vault-poc-instance"
instance_zone = "us-central1-a"
```

### Step 3: Initialize Terraform

```bash
terraform init
```

### Step 4: Deploy Monitoring

```bash
terraform apply
```

**Type `yes` when prompted**

**Deployment time:** 1-2 minutes

**Expected output:**
```
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:

dashboard_url = "https://console.cloud.google.com/monitoring/dashboards?project=..."
alert_policies = {
  "high_memory" = "projects/.../alertPolicies/..."
  "sealed" = "projects/.../alertPolicies/..."
  "high_requests" = "projects/.../alertPolicies/..."
  "instance_down" = "projects/.../alertPolicies/..."
  "uptime_check" = "projects/.../alertPolicies/..."
}
```

---

## ✅ Verification & Testing

### Test 1: Verify Vault UI Access

```bash
# Get Vault URL from Phase 1 output
# Open in browser: http://YOUR_VM_IP:8200

# Login with root token
# You should see the Vault UI ✅
```

### Test 2: Check Metrics in GCP

1. Go to: https://console.cloud.google.com/monitoring/metrics-explorer
2. Search: `prometheus.googleapis.com/vault_core_unsealed`
3. Should see: Graph with value of 1 ✅

### Test 3: View Dashboard

1. Go to: https://console.cloud.google.com/monitoring/dashboards
2. Find: "Vault Production Monitoring"
3. Should see: 6 widgets with live data ✅

### Test 4: Check Alert Policies

1. Go to: https://console.cloud.google.com/monitoring/alerting/policies
2. Should see: 5 alert policies ✅
   - Vault - High Memory Usage
   - Vault - Instance is Sealed
   - Vault - High Request Rate
   - Vault - Instance Not Responding
   - Vault - Health Check Failed

### Test 5: Verify Uptime Check

1. Go to: https://console.cloud.google.com/monitoring/uptime
2. Should see: "Vault Health Check" (passing) ✅

### Test 6: Check Logs

1. Go to: https://console.cloud.google.com/logs
2. Query: `resource.type="gce_instance" log_id("vault_audit")`
3. Should see: Vault audit logs ✅

### Test 7: Create a Secret

```bash
# SSH back into VM
gcloud compute ssh vault-poc-instance --zone=us-central1-a

export VAULT_ADDR="http://127.0.0.1:8200"
vault login  # Use your root token

# Enable KV engine
vault secrets enable -version=2 kv

# Create secret
vault kv put kv/demo username="admin" password="secret123"

# Read it back
vault kv get kv/demo

exit
```

### Test 8: Verify Metrics Updated

After creating the secret:
1. Go back to Metrics Explorer
2. Search: `vault_core_handle_request_sum`
3. Should see: Request count increased ✅

### Test 9: Trigger an Alert (Optional)

```bash
# SSH to VM
gcloud compute ssh vault-poc-instance --zone=us-central1-a

# Seal Vault (will trigger alert)
export VAULT_ADDR="http://127.0.0.1:8200"
vault login  # Use root token
vault operator seal

# Wait 2-3 minutes
# You should receive email alert: "Vault - Instance is Sealed" 📧

# Unseal it
vault operator unseal  # Use unseal key

exit
```

### Test 10: End-to-End Test

```bash
# From your local machine
gcloud compute ssh vault-poc-instance --zone=us-central1-a --command="vault status"

# Should show Vault status without errors ✅
```

---

## 🐛 Troubleshooting

### Issue: Terraform Authentication Errors

**Error:** "Could not load plugin"

**Solution:**
```bash
gcloud auth application-default login
terraform init
```

### Issue: Vault Not Starting

**Check logs:**
```bash
gcloud compute ssh vault-poc-instance
sudo journalctl -u vault -n 100
sudo systemctl status vault
```

**Common causes:**
- Configuration error → Check `/etc/vault.d/vault.hcl`
- Port conflict → Check `ss -tlnp | grep 8200`
- Permissions → Check `/opt/vault/data` ownership

### Issue: No Metrics Appearing

**Check Ops Agent:**
```bash
gcloud compute ssh vault-poc-instance
sudo systemctl status google-cloud-ops-agent
sudo journalctl -u google-cloud-ops-agent-opentelemetry-collector -n 50
```

**Verify Prometheus endpoint:**
```bash
curl -H "X-Vault-Token: YOUR_TOKEN" http://localhost:8200/v1/sys/metrics?format=prometheus
```

**Common causes:**
- Token expired → Create new token with `configure-monitoring.sh`
- Agent not running → `sudo systemctl restart google-cloud-ops-agent`
- Wrong permissions → Check service account IAM roles

### Issue: Alert Policies Failed to Create

**Error:** "Cannot find metric(s)"

**Cause:** Metrics don't exist yet

**Solution:**
```bash
# Wait 10-15 minutes for metrics to appear
# Check Metrics Explorer first
# Then retry Phase 3
cd 2-monitoring
terraform apply
```

### Issue: Can't Access Vault UI

**Check firewall:**
```bash
gcloud compute firewall-rules describe vault-poc-allow-ui
```

**Check your IP:**
- Visit: https://whatismyipaddress.com/
- Update `allowed_cidrs` in `1-infrastructure/terraform.tfvars`
- Re-apply: `cd 1-infrastructure && terraform apply`

### Issue: Vault Sealed After Reboot

**Expected behavior:** Vault always starts sealed for security

**Solution:**
```bash
gcloud compute ssh vault-poc-instance
export VAULT_ADDR="http://127.0.0.1:8200"
vault operator unseal  # Use your unseal key
```

---

## 🗑️ Cleanup

### Option 1: Stop Instance (Save Costs, Keep Data)

```bash
gcloud compute instances stop vault-poc-instance --zone=us-central1-a
```

**Monthly cost while stopped:** ~$5 (disk storage only)

**To restart:**
```bash
gcloud compute instances start vault-poc-instance --zone=us-central1-a
# Remember to unseal Vault after restart
```

### Option 2: Destroy Everything

```bash
# Destroy monitoring first
cd 2-monitoring
terraform destroy
# Type: yes

# Destroy infrastructure
cd ../1-infrastructure
terraform destroy
# Type: yes
```

**This removes:**
- ✅ VM instance
- ✅ Service account
- ✅ Firewall rules
- ✅ Dashboards
- ✅ Alert policies
- ✅ Uptime checks

**This keeps:**
- ℹ️ Enabled APIs
- ℹ️ Historical metrics (subject to retention policy)
- ℹ️ Metric descriptors

---

## 📊 What You've Deployed

| Component | Quantity | Purpose |
|-----------|----------|---------|
| **VM Instance** | 1 | Runs Vault server |
| **Service Account** | 1 | IAM for metrics/logs |
| **Firewall Rule** | 1 | Allow port 8200 |
| **IAM Bindings** | 2 | Monitoring & Logging permissions |
| **Dashboard** | 1 | Vault metrics visualization |
| **Alert Policies** | 5 | Automated monitoring |
| **Uptime Check** | 1 | Health endpoint monitoring |
| **Notification Channel** | 1 | Email alerts |

---

## 🎯 Next Steps

**You now have a fully functional Vault + GCP Monitoring setup!**

### Production Hardening:
1. Enable TLS/HTTPS
2. Use GCS storage backend
3. Implement auto-unseal (Cloud KMS)
4. Deploy HA cluster (3-5 nodes)
5. Restrict firewall to specific IPs
6. Implement backup strategy
7. Use multiple unseal keys
8. Enable MFA for authentication

### Experiment:
- Enable different secrets engines
- Create policies and roles
- Test dynamic secrets (databases)
- Integrate with applications
- Generate load and watch metrics

---

## 💡 Key Takeaways

✅ **Two-Phase Deployment Works** - Infrastructure first, then monitoring  
✅ **No Conditional Variables** - Clean separation, no `create_alert_policies` toggle  
✅ **Metrics Need Time** - Always wait 5-10 minutes for metrics to appear  
✅ **Separate Concerns** - Infrastructure and monitoring are independent  
✅ **Reusable Modules** - Each folder can be used independently  

---

**🎉 Congratulations!** You've successfully deployed a production-grade Vault PoC with comprehensive monitoring!

For questions or issues, see the [Troubleshooting](#troubleshooting) section or file an issue.

---

**Happy Vaulting!** 🔐
