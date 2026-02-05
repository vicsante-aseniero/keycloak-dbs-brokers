#!/bin/bash
# generate-certs.sh
# Generate self-signed SSL certificates for PostgreSQL
# Usage: ./generate-certs.sh

set -e

CERT_DIR="./certs"
DAYS_VALID=365
CN="postgres-dev"

echo "🔐 Generating SSL certificates for PostgreSQL..."

# Create certs directory if not exists
mkdir -p "$CERT_DIR"

# Check if certificates already exist
if [ -f "$CERT_DIR/server.crt" ] && [ -f "$CERT_DIR/server.key" ]; then
    echo "⚠️  Certificates already exist!"
    read -p "Do you want to regenerate? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing certificates."
        exit 0
    fi
    echo "Regenerating certificates..."
fi

# Generate self-signed certificate
openssl req -new -x509 -days $DAYS_VALID -nodes -text \
    -out "$CERT_DIR/server.crt" \
    -keyout "$CERT_DIR/server.key" \
    -subj "/CN=$CN"

# Set proper permissions
chmod 644 "$CERT_DIR/server.crt"
chmod 600 "$CERT_DIR/server.key"

echo ""
echo "✅ Certificates generated successfully!"
echo ""
echo "📁 Files created:"
echo "   - $CERT_DIR/server.crt (public certificate)"
echo "   - $CERT_DIR/server.key (private key, mode 600)"
echo ""
echo "📅 Valid for: $DAYS_VALID days"
echo ""
echo "💡 Next step: Run 'docker compose up -d' to start services."
