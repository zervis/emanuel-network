#!/bin/bash

# Tigris Storage Setup Script for Socialite
# This script helps you configure Tigris object storage

set -e

echo "🐅 Tigris Storage Setup for Socialite"
echo "======================================"
echo ""

# Check if running in development
if [ "$MIX_ENV" = "prod" ]; then
    echo "⚠️  Running in production mode. Make sure you have all credentials set!"
else
    echo "📝 Setting up for development environment"
fi

echo ""
echo "📚 Setup Instructions:"
echo "1. Sign up at https://www.tigrisdata.com/"
echo "2. Create a new project"
echo "3. Generate API credentials"
echo "4. Create buckets for your environments"
echo ""

# Check if credentials are already set
if [ -n "$TIGRIS_ACCESS_KEY_ID" ] && [ -n "$TIGRIS_SECRET_ACCESS_KEY" ]; then
    echo "✅ Tigris credentials are already set!"
    echo "   Access Key: ${TIGRIS_ACCESS_KEY_ID:0:8}..."
    echo "   Bucket: ${TIGRIS_BUCKET_NAME:-socialite-dev-uploads}"
else
    echo "❌ Tigris credentials not found"
    echo ""
    echo "🔧 To set up Tigris credentials:"
    echo ""
    echo "For development (add to your shell profile):"
    echo "export TIGRIS_ACCESS_KEY_ID=\"your_access_key_here\""
    echo "export TIGRIS_SECRET_ACCESS_KEY=\"your_secret_key_here\""
    echo "export TIGRIS_BUCKET_NAME=\"socialite-dev-uploads\""
    echo ""
    echo "For production:"
    echo "export TIGRIS_ACCESS_KEY_ID=\"your_access_key_here\""
    echo "export TIGRIS_SECRET_ACCESS_KEY=\"your_secret_key_here\""
    echo "export TIGRIS_BUCKET_NAME=\"socialite-production\""
    echo ""
fi

# Test current configuration
echo "🧪 Testing current configuration..."
echo ""

if command -v mix >/dev/null 2>&1; then
    mix test_tigris
else
    echo "❌ Mix not found. Make sure Elixir is installed."
    exit 1
fi

echo ""
echo "📖 Next Steps:"
echo "1. If using local storage: You're all set for development!"
echo "2. If setting up Tigris:"
echo "   - Set the environment variables above"
echo "   - Create buckets in your Tigris dashboard"
echo "   - Run 'mix test_tigris' again to verify"
echo "3. For production deployment, see TIGIRIS_DEPLOYMENT.md"
echo ""
echo "🚀 Ready to start developing!"
echo "   Run: mix phx.server" 