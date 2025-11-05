#!/bin/bash
# Vault Installation and Setup Script
# This script runs automatically when the GCP VM starts for the first time

set -e

echo "Starting Vault installation script..."

# Variables (passed from Terraform)
VAULT_VERSION="${vault_version}"
VAULT_USER="vault"
VAULT_DIR="/opt/vault"
VAULT_CONFIG_DIR="/etc/vault.d"
VAULT_DATA_DIR="/opt/vault/data"

# Update system packages
echo "Updating system packages..."
apt-get update
apt-get install -y wget unzip curl jq

# Install Google Cloud Ops Agent
echo "Installing Google Cloud Ops Agent..."
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install
rm add-google-cloud-ops-agent-repo.sh

# Verify Ops Agent installation
systemctl status google-cloud-ops-agent || true

# Create vault user
echo "Creating vault user..."
useradd --system --home $VAULT_DIR --shell /bin/false $VAULT_USER || true

# Create necessary directories
echo "Creating directories..."
mkdir -p $VAULT_DIR
mkdir -p $VAULT_CONFIG_DIR
mkdir -p $VAULT_DATA_DIR
mkdir -p /var/log/vault

# Download and install Vault
echo "Downloading Vault $VAULT_VERSION..."
cd /tmp
wget https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_amd64.zip
unzip vault_$${VAULT_VERSION}_linux_amd64.zip
mv vault /usr/local/bin/
chmod +x /usr/local/bin/vault
rm vault_$${VAULT_VERSION}_linux_amd64.zip

# Verify installation
vault version

# Set ownership
chown -R $VAULT_USER:$VAULT_USER $VAULT_DIR
chown -R $VAULT_USER:$VAULT_USER $VAULT_CONFIG_DIR
chown -R $VAULT_USER:$VAULT_USER /var/log/vault

# Create Vault configuration file
echo "Creating Vault configuration..."
cat > $VAULT_CONFIG_DIR/vault.hcl <<EOF
# Vault Configuration File
# Location: /etc/vault.d/vault.hcl

# Storage backend - using file storage for PoC
storage "file" {
  path = "$VAULT_DATA_DIR"
}

# Listener configuration
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

# API address
api_addr = "http://0.0.0.0:8200"

# UI enabled
ui = true

# Telemetry for Prometheus metrics
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}

# Log level
log_level = "info"
EOF

chown $VAULT_USER:$VAULT_USER $VAULT_CONFIG_DIR/vault.hcl

# Create systemd service file
echo "Creating systemd service..."
cat > /etc/systemd/system/vault.service <<EOF
[Unit]
Description=HashiCorp Vault - A tool for managing secrets
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl

[Service]
User=$VAULT_USER
Group=$VAULT_USER
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

# Create initialization script
echo "Creating initialization script..."
cat > /root/initialize-vault.sh <<'INITEOF'
#!/bin/bash
# Vault Initialization Script
# Run this script ONCE after Vault is running to initialize it

set -e

export VAULT_ADDR="http://127.0.0.1:8200"

echo "=========================================="
echo "Initializing Vault..."
echo "=========================================="

# Check if Vault is already initialized
if vault status 2>&1 | grep -q "Vault is already initialized"; then
    echo "ERROR: Vault is already initialized!"
    echo "If you need to re-initialize, you must delete the data directory and restart Vault."
    exit 1
fi

# Initialize Vault with 1 key share and 1 key threshold (PoC only!)
INIT_OUTPUT=$(vault operator init -key-shares=1 -key-threshold=1 -format=json)

# Extract keys
UNSEAL_KEY=$(echo $INIT_OUTPUT | jq -r '.unseal_keys_b64[0]')
ROOT_TOKEN=$(echo $INIT_OUTPUT | jq -r '.root_token')

# Save to file
cat > /root/vault-keys.txt <<EOF
========================================
VAULT INITIALIZATION KEYS
========================================
SAVE THESE KEYS SECURELY!

Unseal Key: $UNSEAL_KEY
Root Token: $ROOT_TOKEN

========================================
IMPORTANT NOTES:
========================================
1. The Unseal Key is required to unseal Vault after any restart
2. The Root Token provides full administrative access
3. In production, use multiple key shares and store them separately
4. Store these keys in a secure password manager
5. Delete this file after storing the keys securely

To unseal Vault:
  export VAULT_ADDR="http://127.0.0.1:8200"
  vault operator unseal $UNSEAL_KEY

To login:
  vault login $ROOT_TOKEN
========================================
EOF

chmod 600 /root/vault-keys.txt

echo ""
echo "=========================================="
echo "Vault Initialized Successfully!"
echo "=========================================="
echo ""
echo "Unseal Key: $UNSEAL_KEY"
echo "Root Token: $ROOT_TOKEN"
echo ""
echo "These keys have been saved to: /root/vault-keys.txt"
echo ""
echo "Next steps:"
echo "1. Run: vault operator unseal $UNSEAL_KEY"
echo "2. Run: vault login $ROOT_TOKEN"
echo "3. Run: sudo bash /root/configure-monitoring.sh"
echo ""
echo "=========================================="
INITEOF

chmod +x /root/initialize-vault.sh

# Create demo use cases script
echo "Creating demo use cases script..."
cat > /root/demo-use-cases.sh <<'DEMOEOF'
#!/bin/bash
# Vault Production Use Cases Demo
# This script demonstrates realistic Vault usage patterns and generates metrics

set -e

export VAULT_ADDR="http://127.0.0.1:8200"

echo "=========================================="
echo "Vault Production Use Cases Demo"
echo "=========================================="
echo ""

# Check if Vault is unsealed
if ! vault status &> /dev/null; then
    echo "ERROR: Vault is sealed or not accessible"
    echo "Please unseal Vault first: vault operator unseal"
    exit 1
fi

# Check if authenticated
if ! vault token lookup &> /dev/null; then
    echo "ERROR: Not authenticated to Vault"
    echo "Please login: vault login <TOKEN>"
    exit 1
fi

echo "✓ Vault is accessible and unsealed"
echo ""

# Enable engines and create demo data (abbreviated version)
vault secrets enable -path=database -version=2 kv 2>/dev/null || true
vault kv put database/postgres/prod username="prod_user" password="SecurePass123" host="postgres.internal"

vault secrets enable -path=api-keys -version=2 kv 2>/dev/null || true
vault kv put api-keys/stripe public_key="pk_live_..." secret_key="sk_live_..."

vault secrets enable -path=app-config -version=2 kv 2>/dev/null || true
vault kv put app-config/web-app/production debug_mode="false" log_level="error"

# Generate load
echo "📊 Generating load (50 operations)..."
for i in {1..50}; do
    vault kv get database/postgres/prod > /dev/null 2>&1 || true
    vault kv get api-keys/stripe > /dev/null 2>&1 || true
    [ $((i % 10)) -eq 0 ] && echo "  Progress: $i/50"
done

echo "✓ Demo completed! Check GCP Monitoring for metrics."
DEMOEOF

chmod +x /root/demo-use-cases.sh

# Create monitoring configuration script
echo "Creating monitoring configuration script..."
cat > /root/configure-monitoring.sh <<'MONEOF'
#!/bin/bash
# Configure Vault Monitoring with GCP Cloud Monitoring
# Run this script AFTER initializing and unsealing Vault

set -e

export VAULT_ADDR="http://127.0.0.1:8200"

echo "=========================================="
echo "Configuring Vault Monitoring"
echo "=========================================="

# Check if Vault is sealed
if vault status 2>&1 | grep -q "Sealed.*true"; then
    echo "ERROR: Vault is sealed. Please unseal it first."
    echo "Run: vault operator unseal <UNSEAL_KEY>"
    exit 1
fi

# Check if we're authenticated
if ! vault token lookup &> /dev/null; then
    echo "ERROR: Not authenticated to Vault."
    echo "Please login first: vault login <ROOT_TOKEN>"
    exit 1
fi

echo ""
echo "Step 1: Enabling audit logging..."
vault audit enable file file_path=/var/log/vault/audit.log || echo "Audit already enabled"

echo ""
echo "Step 2: Creating policy for Prometheus metrics..."
vault policy write prometheus-metrics - <<EOF
# Allow reading metrics endpoint
path "sys/metrics" {
  capabilities = ["read"]
}
EOF

echo ""
echo "Step 3: Generating token for metrics collection..."
PROMETHEUS_TOKEN=$(vault token create \
  -policy=prometheus-metrics \
  -period=768h \
  -orphan \
  -display-name="prometheus-metrics-token" \
  -format=json | jq -r '.auth.client_token')

echo ""
echo "Step 4: Configuring Ops Agent..."
cat > /etc/google-cloud-ops-agent/config.yaml <<OPSEOF
metrics:
  receivers:
    prometheus:
      type: prometheus
      config:
        scrape_configs:
          - job_name: 'vault'
            scrape_interval: 60s
            metrics_path: '/v1/sys/metrics'
            params:
              format: ['prometheus']
            bearer_token: '$PROMETHEUS_TOKEN'
            static_configs:
              - targets: ['localhost:8200']
  service:
    pipelines:
      prometheus:
        receivers:
          - prometheus

logging:
  receivers:
    vault_audit:
      type: files
      include_paths:
        - /var/log/vault/audit.log
  processors:
    vault_audit_json:
      type: parse_json
      field: message
  service:
    pipelines:
      vault_audit:
        receivers:
          - vault_audit
        processors:
          - vault_audit_json
OPSEOF

# Set proper permissions on audit log
chown vault:vault /var/log/vault/audit.log 2>/dev/null || touch /var/log/vault/audit.log && chown vault:vault /var/log/vault/audit.log

echo ""
echo "Step 5: Restarting Ops Agent..."
systemctl restart google-cloud-ops-agent

echo ""
echo "=========================================="
echo "Monitoring Configuration Complete!"
echo "=========================================="
echo ""
echo "Prometheus Token: $PROMETHEUS_TOKEN"
echo ""
echo "This token has been saved to: /root/prometheus-token.txt"
echo ""
echo "$PROMETHEUS_TOKEN" > /root/prometheus-token.txt
chmod 600 /root/prometheus-token.txt
echo ""
echo "Next steps:"
echo "1. Wait 1-2 minutes for metrics to start flowing"
echo "2. Go to GCP Console > Monitoring > Metrics Explorer"
echo "3. Search for 'vault' metrics"
echo "4. Go to GCP Console > Logging > Logs Explorer"
echo "5. Search for 'vault_audit' logs"
echo ""
echo "=========================================="
MONEOF

chmod +x /root/configure-monitoring.sh

# Enable and start Vault service
echo "Enabling and starting Vault service..."
systemctl daemon-reload
systemctl enable vault
systemctl start vault

# Wait for Vault to start
echo "Waiting for Vault to start..."
sleep 10

# Check Vault status
echo "Checking Vault status..."
vault status || true

echo ""
echo "=========================================="
echo "Vault Installation Complete!"
echo "=========================================="
echo ""
echo "Vault is running but needs to be initialized."
echo ""
echo "Next steps:"
echo "1. SSH into this instance"
echo "2. Run: sudo /root/initialize-vault.sh"
echo "3. Save the unseal key and root token"
echo "4. Unseal Vault with the key"
echo "5. Login with the root token"
echo "6. Run: sudo bash /root/configure-monitoring.sh"
echo ""
echo "=========================================="

