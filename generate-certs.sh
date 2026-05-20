#!/bin/bash
# generate-certs.sh
# Generate self-signed SSL certificates for PostgreSQL
# Usage: ./generate-certs.sh [--days N] [--cn COMMON_NAME]

set -euo pipefail  # 1. Stricter error handling

CERT_DIR="./certs"
DAYS_VALID=825      # 2. Max days browsers trust (was 365)
CN="postgres-dev"

# 3. Parse optional CLI arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --days) DAYS_VALID="$2"; shift 2 ;;
    --cn)   CN="$2";         shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🔐 Generating SSL certificates for PostgreSQL..."
echo "   CN=${CN}, valid for ${DAYS_VALID} days"

mkdir -p "$CERT_DIR"

if [ -f "$CERT_DIR/server.crt" ] && [ -f "$CERT_DIR/server.key" ]; then
    echo "⚠️  Certificates already exist!"
    read -p "Do you want to regenerate? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing certificates."
        exit 0
    fi
fi

# 4. Add a Subject Alternative Name (SAN) — required by modern clients
openssl req -new -x509 \
    -days "$DAYS_VALID" \
    -nodes \
    -out  "$CERT_DIR/server.crt" \
    -keyout "$CERT_DIR/server.key" \
    -subj "/CN=${CN}" \
    -addext "subjectAltName=DNS:${CN},DNS:localhost,IP:127.0.0.1"

# 5. Set permissions
chmod 644 "$CERT_DIR/server.crt"
chmod 600 "$CERT_DIR/server.key"

# 6. Show cert summary so you can verify what was created
echo ""
echo "✅ Certificates generated successfully!"
echo ""
openssl x509 -in "$CERT_DIR/server.crt" -noout -text \
  | grep -E "(Subject:|Not Before|Not After|Subject Alternative)"
echo ""
echo "📁 $CERT_DIR/server.crt  (644 — public)"
echo "📁 $CERT_DIR/server.key  (600 — private)"
echo ""
echo "💡 Next: Run 'docker compose up -d'"