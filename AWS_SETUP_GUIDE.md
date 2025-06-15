# AWS S3 Setup Guide - Fix "Access Denied" Error

## Problem
You're getting: `Access denied to bucket 'emanuel-network'`

## Solution Steps

### 1. Install AWS CLI ✅ (Already Done)
```bash
brew install awscli
```

### 2. Configure AWS Credentials

#### Option A: Using AWS Configure (Recommended)
```bash
aws configure
```

Enter when prompted:
- **AWS Access Key ID**: `AKIA...` (from AWS Console)
- **AWS Secret Access Key**: `...` (from AWS Console)
- **Default region name**: `eu-north-1`
- **Default output format**: `json`

#### Option B: Using Environment Variables
```bash
export AWS_ACCESS_KEY_ID="your_access_key_here"
export AWS_SECRET_ACCESS_KEY="your_secret_key_here"
export AWS_REGION="eu-north-1"
export AWS_S3_BUCKET="emanuel-network"
```

### 3. Get AWS Credentials

1. Go to [AWS Console](https://console.aws.amazon.com/)
2. Navigate to **IAM** → **Users** → Your user
3. Click **Security credentials** tab
4. Click **Create access key**
5. Choose **Command Line Interface (CLI)**
6. Copy the Access Key ID and Secret Access Key

### 4. Set Up IAM Permissions

#### Option A: Attach Policy to User
1. Go to **IAM** → **Users** → Your user
2. Click **Add permissions** → **Attach policies directly**
3. Create a custom policy with this JSON:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::emanuel-network",
        "arn:aws:s3:::emanuel-network/*"
      ]
    }
  ]
}
```

#### Option B: Update Bucket Policy
1. Go to **S3** → **emanuel-network** bucket
2. Click **Permissions** tab
3. Edit **Bucket policy** and add:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::YOUR-ACCOUNT-ID:user/YOUR-USERNAME"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::emanuel-network",
        "arn:aws:s3:::emanuel-network/*"
      ]
    }
  ]
}
```

### 5. Verify Setup

After configuring credentials, test the connection:

```bash
# Check credentials
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://emanuel-network

# Test from your app
mix test_s3
```

### 6. Troubleshooting

#### If bucket doesn't exist:
```bash
# Create the bucket
aws s3 mb s3://emanuel-network --region eu-north-1
```

#### If region mismatch:
Make sure your bucket is in `eu-north-1` region or update your config to match the bucket's region.

#### If still getting access denied:
1. Check your IAM user has the correct permissions
2. Verify the bucket policy allows your user
3. Make sure you're using the correct bucket name
4. Check if MFA is required for your account

### 7. Alternative: Use Local Storage for Development

If you want to skip AWS setup for now, you can use local storage:

```bash
# Remove AWS credentials to force local storage
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY

# Test - should use local storage
mix test_s3
```

## Quick Fix Commands

```bash
# 1. Configure AWS
aws configure

# 2. Test credentials
aws sts get-caller-identity

# 3. Test S3 access
aws s3 ls s3://emanuel-network

# 4. Test your app
mix test_s3
```

## Environment Variables for Development

Add to your shell profile (`~/.zshrc` or `~/.bash_profile`):

```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_REGION="eu-north-1"
export AWS_S3_BUCKET="emanuel-network"
```

Then reload: `source ~/.zshrc` 