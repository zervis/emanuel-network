# Tigiris Deployment Guide

This guide covers deploying the Socialite application with **Tigris** object storage from tigrisdata.com. Tigris is an S3-compatible storage service that's easier to set up than AWS S3.

## 📋 Prerequisites

- AWS Account with S3 access
- Domain name (tigiris.com)
- SSL certificate
- PostgreSQL database
- SMTP credentials for email

## 🚀 Quick Setup

### 1. Local Development Setup

```bash
# Clone and setup
git clone <repository>
cd socialite

# Install dependencies
mix deps.get
npm install --prefix assets

# Setup database
mix ecto.setup

# Configure for local development (uses local file storage)
# No additional setup needed - uploads go to priv/static/uploads/

# Start development server
mix phx.server
```

### 2. Tigris Setup

#### 1. Create Tigris Account

1. Go to [tigrisdata.com](https://www.tigrisdata.com/)
2. Sign up for a free account
3. Create a new project
4. Generate API credentials in your dashboard

#### 2. Environment Variables

##### Development (.env or shell)
```bash
# Tigris credentials
export TIGRIS_ACCESS_KEY_ID="your_tigris_access_key"
export TIGRIS_SECRET_ACCESS_KEY="your_tigris_secret_key"
export TIGRIS_BUCKET_NAME="socialite-dev-uploads"

# Email configuration
export SMTP_USERNAME="your_email@gmail.com"
export SMTP_PASSWORD="your_app_password"
```

##### Production
```bash
# Database
export DATABASE_URL="postgresql://user:pass@host:port/database"

# Application
export SECRET_KEY_BASE="your_secret_key_base_64_chars_long"
export PHX_HOST="your-domain.com"

# Tigris Storage
export TIGRIS_ACCESS_KEY_ID="your_tigris_access_key"
export TIGRIS_SECRET_ACCESS_KEY="your_tigris_secret_key"
export TIGRIS_BUCKET_NAME="socialite-production"

# Email
export SMTP_USERNAME="your_email@gmail.com"
export SMTP_PASSWORD="your_app_password"
```

#### 3. Create Buckets

In your Tigris dashboard, create buckets:
- `socialite-dev-uploads` (for development)
- `socialite-production` (for production)

### 3. Environment Variables

#### Development (.env or shell)
```bash
# Optional for development (uses local storage by default)
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="eu-north-1"
export AWS_S3_BUCKET="tigiris-uploads"
```

#### Production (Required)
```bash
# Database
export DATABASE_URL="postgresql://user:pass@host:port/database"
export POOL_SIZE="10"

# Phoenix
export SECRET_KEY_BASE="your-secret-key-base"
export PHX_HOST="tigiris.com"
export PORT="4000"
export PHX_SERVER="true"

# AWS S3
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="eu-north-1"
export AWS_S3_BUCKET="tigiris-uploads"

# Email
export SMTP_USERNAME="your-email@gmail.com"
export SMTP_PASSWORD="your-app-password"
```

## 🔧 Configuration Files

### Development Configuration
- **File**: `config/dev.exs`
- **Storage**: Local (`priv/static/uploads/`)
- **S3**: Disabled by default (can be enabled with credentials)

### Production Configuration
- **File**: `config/prod_tigiris.exs`
- **Storage**: S3 (`tigiris-uploads` bucket)
- **S3**: Required

## 📦 Deployment Options

### Option 1: Using Production Config
```bash
# Build release with Tigiris config
MIX_ENV=prod mix release --config=config/prod_tigiris.exs

# Run with environment variables
_build/prod/rel/socialite/bin/socialite start
```

### Option 2: Docker Deployment
```dockerfile
# Dockerfile example
FROM elixir:1.15-alpine

# Install dependencies
RUN apk add --no-cache build-base npm git python3

# Set working directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy assets and compile
COPY assets assets
RUN npm install --prefix assets
RUN npm run build --prefix assets

# Copy source and compile
COPY . .
RUN MIX_ENV=prod mix compile
RUN MIX_ENV=prod mix assets.deploy
RUN MIX_ENV=prod mix release

# Runtime
EXPOSE 4000
CMD ["_build/prod/rel/socialite/bin/socialite", "start"]
```

### Option 3: Heroku Deployment
```bash
# Add buildpacks
heroku buildpacks:add hashnuke/elixir
heroku buildpacks:add https://github.com/gjaldon/heroku-buildpack-phoenix-static.git

# Set config vars
heroku config:set SECRET_KEY_BASE="your-secret-key-base"
heroku config:set DATABASE_URL="your-database-url"
heroku config:set AWS_ACCESS_KEY_ID="your-access-key"
heroku config:set AWS_SECRET_ACCESS_KEY="your-secret-key"
heroku config:set AWS_REGION="eu-north-1"
heroku config:set AWS_S3_BUCKET="tigiris-uploads"

# Deploy
git push heroku main
```

## 🧪 Testing Upload Configuration

### Test Tigris Connection
```bash
# Test current configuration
mix test_tigris

# Test with specific credentials
TIGRIS_ACCESS_KEY_ID=your_key TIGRIS_SECRET_ACCESS_KEY=your_secret mix test_tigris
```

### Test File Uploads
1. Start the application
2. Go to Settings page
3. Try uploading a profile picture
4. Check if file appears in:
   - **Local**: `priv/static/uploads/`
   - **S3**: `https://tigiris-uploads.s3.eu-north-1.amazonaws.com/`

## 🔒 Security Considerations

### S3 Bucket Security
- ✅ Public read access for uploaded files
- ✅ Private write access (authenticated only)
- ✅ CORS configured for web uploads
- ✅ Bucket in EU region (GDPR compliance)

### Application Security
- ✅ File type validation
- ✅ File size limits
- ✅ Secure file naming
- ✅ SSL/TLS encryption

## 📁 File Upload Features

### Supported File Types
- Images: JPG, PNG, GIF, WebP
- Documents: PDF (if enabled)
- Size limit: 10MB per file

### Upload Locations
- **Profile pictures**: `uploads/avatars/`
- **Post images**: `uploads/posts/`
- **Group banners**: `uploads/groups/`
- **Event images**: `uploads/events/`

## 🚨 Troubleshooting

### Common Issues

#### 1. S3 Connection Failed
```bash
# Check credentials
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY

# Test with AWS CLI
aws s3 ls s3://tigiris-uploads
```

#### 2. Region Mismatch
- Ensure bucket region matches config: `eu-north-1`
- Check AWS console for actual bucket region

#### 3. Permission Denied
- Verify IAM user has S3 permissions
- Check bucket policy allows public read

#### 4. CORS Errors
- Verify CORS configuration in S3 console
- Check browser developer tools for CORS errors

### Switching Between Local and S3

#### Enable S3 in Development
```elixir
# In config/dev.exs, change:
adapter: :local  # to
adapter: :s3
```

#### Fallback to Local in Production
```elixir
# In config/prod_tigiris.exs, change:
adapter: :s3  # to
adapter: :local
```

## 📞 Support

For deployment issues:
1. Check logs: `mix phx.server` or application logs
2. Test S3: `mix test_s3`
3. Verify environment variables
4. Check AWS console for bucket status

## 🎯 Production Checklist

- [ ] S3 bucket created (`tigiris-uploads`)
- [ ] Bucket policy configured
- [ ] CORS policy configured
- [ ] AWS credentials set
- [ ] Database configured
- [ ] SSL certificate installed
- [ ] Domain DNS configured
- [ ] SMTP credentials set
- [ ] Environment variables set
- [ ] Application deployed
- [ ] Upload functionality tested

---

**Ready to deploy Tigiris! 🚀** 