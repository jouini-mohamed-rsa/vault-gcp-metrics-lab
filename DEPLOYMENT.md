# Vault + GCP Monitoring PoC - Deployment

Short guide to deploy Vault on GCP and enable metrics/logs in Cloud Monitoring. This is a PoC, not a production setup.

## Prerequisites

### Required Tools

```bash
# Check if tools are installed
gcloud --version     # Google Cloud SDK
terraform --version  # Terraform >= 1.0
git --version        # Git
```

Install with your preferred method or package manager if any tool is missing.

### GCP Requirements

- Active GCP account
- Project with billing enabled
- Owner or Editor role on project

---

## GCP Authentication Setup

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

## Phase 1: Deploy Infrastructure

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

You should see providers initialize successfully.

### Step 4: Preview Changes

```bash
terraform plan
```

Review the plan and ensure resources look correct (APIs, SA, IAM, firewall, VM).

### Step 5: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. Save the outputs (IP, UI URL, SSH command) for later.

### Step 6: Wait for Vault Installation

The VM startup script installs Vault. Wait 3-5 minutes, then:

```bash
# SSH into the VM
gcloud compute ssh vault-poc-instance --zone=us-central1-a --project=<PROJECT-ID>

# Check Vault installation
vault --version
# Check Vault service
sudo systemctl status vault
# Expect: active (running)

# Exit SSH
exit
```

---

## Phase 2: Configure Vault

This phase initializes Vault, unseals it, and configures monitoring.

### Step 1: SSH to Vault Instance

```bash
gcloud compute ssh vault-poc-instance --zone=us-central1-a
```

### Step 2: Initialize Vault

```bash
sudo /root/initialize-vault.sh
```

Save the unseal key and root token securely.

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

Expect `Sealed: false`.

### Step 4: Login to Vault

```bash
vault login
# Paste your root token when prompted
```

### Step 5: Configure Monitoring

Export your token so `sudo` can use it:

```bash
export VAULT_TOKEN=<YOUR_ROOT_TOKEN>
sudo -E bash /root/configure-monitoring.sh
```

This creates a monitoring token and configures the Ops Agent.

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

Wait 5–10 minutes for metrics to appear in Cloud Monitoring. In Metrics Explorer, search `prometheus.googleapis.com/vault`.

---

## Phase 3: Deploy Monitoring

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

Type `yes` to apply. Note the dashboard URL and alert policy IDs from outputs.

---

## Verification

### Vault UI

```bash
# Get Vault URL from Phase 1 output
# Open in browser: http://YOUR_VM_IP:8200

# Login with root token
# You should see the Vault UI
```

### Metrics in GCP

1. Go to: https://console.cloud.google.com/monitoring/metrics-explorer
2. Search: `prometheus.googleapis.com/vault_core_unsealed`
3. Expect value 1

### Dashboard

1. Go to: https://console.cloud.google.com/monitoring/dashboards
2. Find: "Vault Production Monitoring"
3. Expect live widgets

### Alert Policies

1. Go to: https://console.cloud.google.com/monitoring/alerting/policies
2. Expect the alert policies
   - Vault - High Memory Usage
   - Vault - Instance is Sealed
   - Vault - High Request Rate
   - Vault - Instance Not Responding
   - Vault - Health Check Failed

### Uptime Check

1. Go to: https://console.cloud.google.com/monitoring/uptime
2. Expect "Vault Health Check" passing

### Logs

1. Go to: https://console.cloud.google.com/logs
2. Query: `resource.type="gce_instance" log_id("vault_audit")`
3. Expect Vault audit logs

### Create a Secret

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

### Metrics Updated

After creating the secret:
1. Go back to Metrics Explorer
2. Search: `vault_core_handle_request_sum`
3. Expect request count increased

### Trigger an Alert (Optional)

```bash
# SSH to VM
gcloud compute ssh vault-poc-instance --zone=us-central1-a

# Seal Vault (will trigger alert)
export VAULT_ADDR="http://127.0.0.1:8200"
vault login  # Use root token
vault operator seal

# Wait 2-3 minutes
# You should receive email alert: "Vault - Instance is Sealed"

# Unseal it
vault operator unseal  # Use unseal key

exit
```

### End-to-End Test

```bash
# From your local machine
gcloud compute ssh vault-poc-instance --zone=us-central1-a --command="vault status"

# Expect Vault status without errors
```

---

## Troubleshooting

### Issue: Terraform Authentication Errors

Error: "Could not load plugin"

Solution:
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

Common causes: bad config (`/etc/vault.d/vault.hcl`), port conflict (`ss -tlnp | grep 8200`), data dir permissions.

### Issue: No Metrics Appearing

**Check Ops Agent:**
```bash
gcloud compute ssh vault-poc-instance
sudo systemctl status google-cloud-ops-agent
sudo journalctl -u google-cloud-ops-agent-opentelemetry-collector -n 50
```

Verify Prometheus endpoint:
```bash
curl -H "X-Vault-Token: YOUR_TOKEN" http://localhost:8200/v1/sys/metrics?format=prometheus
```

Common causes: token expired, agent not running, missing IAM roles.

### Issue: Alert Policies Failed to Create

Error: "Cannot find metric(s)"

Cause: Metrics don't exist yet

Solution:
```bash
# Wait 10-15 minutes for metrics to appear
# Check Metrics Explorer first
# Then retry Phase 3
cd 2-monitoring
terraform apply
```

### Issue: Can't Access Vault UI

Check firewall:
```bash
gcloud compute firewall-rules describe vault-poc-allow-ui
```

Check your IP:
- Visit: https://whatismyipaddress.com/
- Update `allowed_cidrs` in `1-infrastructure/terraform.tfvars`
- Re-apply: `cd 1-infrastructure && terraform apply`

### Issue: Vault Sealed After Reboot

Expected: Vault starts sealed

Solution:
```bash
gcloud compute ssh vault-poc-instance
export VAULT_ADDR="http://127.0.0.1:8200"
vault operator unseal  # Use your unseal key
```

---

## Cleanup

### Option 1: Stop Instance (Save Costs, Keep Data)

```bash
gcloud compute instances stop vault-poc-instance --zone=us-central1-a
```

To restart later:
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

This removes the VM, service account, firewall, dashboards, alert policies, and uptime checks. APIs and historical metrics may remain.
---

This is a PoC guide. Adapt as needed for your environment.
