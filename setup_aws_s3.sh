#!/bin/bash

# AWS S3 Setup Script for Socialite Development
# This script helps you configure AWS S3 for your development environment

set -e

echo "🚀 AWS S3 Setup for Socialite Development"
echo "=========================================="
echo ""

# Check if running in development
if [ "$MIX_ENV" = "prod" ]; then
    echo "⚠️  Running in production mode. Make sure you have all credentials set!"
else
    echo "📝 Setting up for development environment"
fi

echo ""
echo "📚 Setup Instructions:"
echo "1. Create an AWS account at https://aws.amazon.com/"
echo "2. Create an IAM user with S3 permissions"
echo "3. Create an S3 bucket in your preferred region"
echo "4. Set the environment variables below"
echo ""

# Check if credentials are already set
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "✅ AWS credentials are already set!"
    echo "   Access Key ID: ${AWS_ACCESS_KEY_ID:0:8}..."
    echo "   Region: ${AWS_REGION:-eu-north-1}"
    echo "   Bucket: ${AWS_S3_BUCKET:-socialite-dev-uploads}"
else
    echo "❌ AWS credentials not found in environment variables"
    echo ""
    echo "🔧 To set up AWS S3, add these environment variables:"
    echo ""
    echo "export AWS_ACCESS_KEY_ID=\"your_access_key_here\""
    echo "export AWS_SECRET_ACCESS_KEY=\"your_secret_key_here\""
    echo "export AWS_REGION=\"eu-north-1\"  # or your preferred region"
    echo "export AWS_S3_BUCKET=\"your-bucket-name\""
    echo ""
    echo "💡 You can add these to your ~/.bashrc, ~/.zshrc, or create a .env file"
fi

echo ""
echo "🔒 Required IAM Permissions for your AWS user:"
echo "{"
echo "  \"Version\": \"2012-10-17\","
echo "  \"Statement\": ["
echo "    {"
echo "      \"Effect\": \"Allow\","
echo "      \"Action\": ["
echo "        \"s3:GetObject\","
echo "        \"s3:PutObject\","
echo "        \"s3:DeleteObject\","
echo "        \"s3:ListBucket\""
echo "      ],"
echo "      \"Resource\": ["
echo "        \"arn:aws:s3:::your-bucket-name\","
echo "        \"arn:aws:s3:::your-bucket-name/*\""
echo "      ]"
echo "    }"
echo "  ]"
echo "}"

echo ""
echo "🧪 Testing Configuration..."

# Test the configuration
if command -v mix >/dev/null 2>&1; then
    echo "Running mix test_s3..."
    mix test_s3 || echo "⚠️  Test failed - check your configuration"
else
    echo "Mix not found - make sure you're in the project directory"
fi

echo ""
echo "📖 For more information, see:"
echo "   - AWS S3 Documentation: https://docs.aws.amazon.com/s3/"
echo "   - ExAws Documentation: https://hexdocs.pm/ex_aws_s3/"
echo ""
echo "✨ Setup complete! Your application will use local storage until AWS credentials are provided." 