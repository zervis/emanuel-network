#!/bin/bash

echo "🚀 Deploying Socialite to Fly.io..."

# Create volume if it doesn't exist
echo "📦 Creating uploads volume..."
fly volumes create uploads_data --region waw --size 1 || echo "Volume already exists or creation failed"

# Deploy the application
echo "🔄 Deploying application..."
fly deploy

echo "✅ Deployment complete!"
echo "🌐 Your app is available at: https://emanuel-network.fly.dev" 