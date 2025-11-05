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

# ============================================
# Use Case 1: Database Credentials Management
# ============================================
echo "📦 Use Case 1: Database Credentials Management"
echo "-------------------------------------------"
echo "Scenario: Applications need PostgreSQL credentials"
echo ""

# Enable KV v2 for application secrets
vault secrets enable -path=database -version=2 kv 2>/dev/null || echo "  • Database secrets engine already enabled"

# Store database credentials
echo "  • Storing PostgreSQL production credentials..."
vault kv put database/postgres/prod \
    username="prod_db_user" \
    password="SecureP@ssw0rd123!" \
    host="postgres-prod.internal.example.com" \
    port="5432" \
    database="production_db" \
    max_connections="20"

echo "  • Storing PostgreSQL staging credentials..."
vault kv put database/postgres/staging \
    username="staging_db_user" \
    password="StagingP@ss456!" \
    host="postgres-staging.internal.example.com" \
    port="5432" \
    database="staging_db"

# Simulate application reading credentials
echo "  • Simulating application credential retrieval..."
for i in {1..5}; do
    vault kv get -format=json database/postgres/prod > /dev/null
    sleep 0.2
done

echo "✓ Database credentials configured"
echo ""

# ============================================
# Use Case 2: API Keys Management
# ============================================
echo "🔑 Use Case 2: API Keys Management"
echo "-------------------------------------------"
echo "Scenario: Microservices need external API keys"
echo ""

vault secrets enable -path=api-keys -version=2 kv 2>/dev/null || echo "  • API keys engine already enabled"

# Store various API keys
echo "  • Storing Stripe API keys..."
vault kv put api-keys/stripe \
    public_key="pk_live_51GqIC8KxJrL..." \
    secret_key="sk_live_51GqIC8KxJrL..." \
    webhook_secret="whsec_..." \
    environment="production"

echo "  • Storing AWS credentials for S3..."
vault kv put api-keys/aws/s3 \
    access_key_id="AKIAIOSFODNN7EXAMPLE" \
    secret_access_key="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" \
    region="us-east-1" \
    bucket="company-documents"

echo "  • Storing SendGrid API key..."
vault kv put api-keys/sendgrid \
    api_key="SG.1234567890abcdef..." \
    from_email="noreply@company.com" \
    environment="production"

echo "✓ API keys stored securely"
echo ""

# ============================================
# Use Case 3: TLS Certificates Management
# ============================================
echo "🔐 Use Case 3: TLS Certificates Management"
echo "-------------------------------------------"
echo "Scenario: Managing SSL/TLS certificates"
echo ""

vault secrets enable -path=certificates -version=2 kv 2>/dev/null || echo "  • Certificates engine already enabled"

echo "  • Storing wildcard certificate..."
vault kv put certificates/wildcard/production \
    common_name="*.company.com" \
    certificate="-----BEGIN CERTIFICATE-----\nMIIDXTCCAkWgAwIBAgIJ..." \
    private_key="-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhki..." \
    ca_chain="-----BEGIN CERTIFICATE-----\nMIIEkjCCA3qgAwIBAgIQ..." \
    expiry_date="2025-12-31" \
    issuer="Let's Encrypt"

echo "  • Storing API gateway certificate..."
vault kv put certificates/api-gateway \
    common_name="api.company.com" \
    certificate="-----BEGIN CERTIFICATE-----\nMIIDXTCCAkWgAwIBAgIK..." \
    private_key="-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkj..." \
    expiry_date="2025-06-30"

echo "✓ Certificates stored"
echo ""

# ============================================
# Use Case 4: Application Configuration
# ============================================
echo "⚙️  Use Case 4: Application Configuration"
echo "-------------------------------------------"
echo "Scenario: Environment-specific app configs"
echo ""

vault secrets enable -path=app-config -version=2 kv 2>/dev/null || echo "  • App config engine already enabled"

echo "  • Storing production app configuration..."
vault kv put app-config/web-app/production \
    debug_mode="false" \
    log_level="error" \
    session_timeout="3600" \
    max_upload_size="10485760" \
    redis_url="redis://redis-prod:6379" \
    cache_ttl="300" \
    feature_flags='{"new_ui":true,"beta_features":false}' \
    sentry_dsn="https://abc123@sentry.io/123456"

echo "  • Storing staging app configuration..."
vault kv put app-config/web-app/staging \
    debug_mode="true" \
    log_level="debug" \
    session_timeout="7200" \
    max_upload_size="52428800" \
    redis_url="redis://redis-staging:6379" \
    cache_ttl="60" \
    feature_flags='{"new_ui":true,"beta_features":true}' \
    sentry_dsn="https://xyz789@sentry.io/789012"

echo "✓ Application configs stored"
echo ""

# ============================================
# Use Case 5: Service-to-Service Authentication
# ============================================
echo "🤝 Use Case 5: Service-to-Service Auth Tokens"
echo "-------------------------------------------"
echo "Scenario: Microservices authentication"
echo ""

vault secrets enable -path=service-tokens -version=2 kv 2>/dev/null || echo "  • Service tokens engine already enabled"

echo "  • Creating auth tokens for microservices..."
vault kv put service-tokens/payment-service \
    service_name="payment-service" \
    jwt_secret="a1b2c3d4e5f6g7h8i9j0" \
    api_key="ps_live_abc123xyz789" \
    timeout="300" \
    allowed_origins='["https://app.company.com","https://api.company.com"]'

vault kv put service-tokens/user-service \
    service_name="user-service" \
    jwt_secret="z9y8x7w6v5u4t3s2r1q0" \
    api_key="us_live_xyz789abc123" \
    timeout="600"

vault kv put service-tokens/notification-service \
    service_name="notification-service" \
    jwt_secret="q1w2e3r4t5y6u7i8o9p0" \
    api_key="ns_live_def456ghi789"

echo "✓ Service tokens configured"
echo ""

# ============================================
# Use Case 6: Simulate Production Load
# ============================================
echo "📊 Use Case 6: Simulating Production Load"
echo "-------------------------------------------"
echo "Generating realistic traffic for monitoring..."
echo ""

# Create some policies
echo "  • Creating access policies..."
vault policy write app-read - <<EOF
path "database/data/postgres/prod" {
  capabilities = ["read"]
}
path "api-keys/data/aws/s3" {
  capabilities = ["read"]
}
path "app-config/data/web-app/production" {
  capabilities = ["read"]
}
EOF

vault policy write app-write - <<EOF
path "database/data/postgres/*" {
  capabilities = ["create", "update", "read"]
}
path "api-keys/data/*" {
  capabilities = ["create", "update", "read"]
}
EOF

# Create some tokens with different policies
echo "  • Creating application tokens..."
APP_TOKEN_1=$(vault token create -policy=app-read -ttl=24h -format=json | jq -r '.auth.client_token')
APP_TOKEN_2=$(vault token create -policy=app-write -ttl=12h -format=json | jq -r '.auth.client_token')
APP_TOKEN_3=$(vault token create -policy=app-read -ttl=6h -format=json | jq -r '.auth.client_token')

echo "  • Created 3 application tokens with different policies"
echo ""

# Simulate read traffic
echo "  • Simulating 50 read operations..."
for i in {1..50}; do
    vault kv get -format=json database/postgres/prod > /dev/null 2>&1 || true
    vault kv get -format=json api-keys/stripe > /dev/null 2>&1 || true
    vault kv get -format=json app-config/web-app/production > /dev/null 2>&1 || true
    
    if [ $((i % 10)) -eq 0 ]; then
        echo "    Progress: $i/50"
    fi
done

echo "✓ Load test completed"
echo ""

# ============================================
# Summary & Metrics
# ============================================
echo "=========================================="
echo "Demo Completed Successfully! 🎉"
echo "=========================================="
echo ""
echo "📊 Secrets Created:"
vault kv list database/ 2>/dev/null | grep -v "Keys" | wc -l | xargs echo "  • Database credentials:"
vault kv list api-keys/ 2>/dev/null | grep -v "Keys" | wc -l | xargs echo "  • API keys:"
vault kv list certificates/ 2>/dev/null | grep -v "Keys" | wc -l | xargs echo "  • Certificates:"
vault kv list app-config/ 2>/dev/null | grep -v "Keys" | wc -l | xargs echo "  • App configurations:"
vault kv list service-tokens/ 2>/dev/null | grep -v "Keys" | wc -l | xargs echo "  • Service tokens:"
echo ""

echo "🔑 Active Tokens:"
vault token lookup -format=json | jq -r '.data.num_uses' | xargs echo "  • Current token uses:"
echo ""

echo "📈 Monitoring Metrics Available:"
echo "  • Request counts (handle_request)"
echo "  • Storage operations (barrier.put, barrier.get)"
echo "  • Token operations (token.count)"
echo "  • Memory usage (runtime.alloc_bytes)"
echo "  • Goroutines (runtime.num_goroutines)"
echo ""

echo "🎯 Next Steps:"
echo "  1. View metrics in GCP Console:"
echo "     https://console.cloud.google.com/monitoring"
echo ""
echo "  2. View the monitoring dashboard:"
echo "     Search for 'Vault Production Monitoring'"
echo ""
echo "  3. Check audit logs in Cloud Logging:"
echo "     Filter: resource.type=\"gce_instance\" log_id(\"vault_audit\")"
echo ""
echo "  4. Run this script again to generate more traffic:"
echo "     sudo bash /root/demo-use-cases.sh"
echo ""
echo "=========================================="

