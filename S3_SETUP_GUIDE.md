# Amazon S3 Setup Guide for Socialite

This guide will help you configure Amazon S3 for file uploads in your Socialite application.

## Prerequisites

1. An AWS account
2. AWS CLI installed (optional but recommended)
3. Basic understanding of AWS IAM

## Step 1: Create an S3 Bucket

1. **Log in to AWS Console**
   - Go to [AWS Console](https://console.aws.amazon.com/)
   - Navigate to S3 service

2. **Create a new bucket**
   - Click "Create bucket"
   - Choose a unique bucket name (e.g., `socialite-uploads-prod`)
   - Select your preferred region
   - **Important**: Uncheck "Block all public access" since we need public read access for images
   - Acknowledge the warning about public access
   - Click "Create bucket"

3. **Configure bucket policy for public read access**
   - Go to your bucket → Permissions → Bucket Policy
   - Add the following policy (replace `YOUR-BUCKET-NAME` with your actual bucket name):

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/uploads/*"
        }
    ]
}
```

## Step 2: Create IAM User for Application Access

1. **Navigate to IAM**
   - Go to IAM service in AWS Console
   - Click "Users" → "Add users"

2. **Create user**
   - User name: `socialite-s3-user`
   - Access type: Select "Programmatic access"
   - Click "Next: Permissions"

3. **Set permissions**
   - Click "Attach existing policies directly"
   - Click "Create policy"
   - Use the JSON editor and paste:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/uploads/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME"
        }
    ]
}
```

   - Name the policy: `SocialiteS3Policy`
   - Create the policy
   - Go back to user creation and attach this policy
   - Complete user creation

4. **Save credentials**
   - **Important**: Save the Access Key ID and Secret Access Key
   - You won't be able to see the secret key again!

## Step 3: Configure Environment Variables

### For Development (.env file or shell)

Create a `.env` file in your project root or set these environment variables:

```bash
# AWS S3 Configuration
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_REGION="us-east-1"  # or your preferred region
export AWS_S3_BUCKET="socialite-dev-uploads"
```

### For Production

Set these environment variables in your production environment:

```bash
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
AWS_REGION=us-east-1
AWS_S3_BUCKET=socialite-uploads-prod
```

## Step 4: Update Configuration

The application is already configured to use S3. You can switch between S3 and local storage by updating `config/dev.exs`:

```elixir
# For S3 storage
config :socialite, :file_storage,
  adapter: :s3,
  bucket: System.get_env("AWS_S3_BUCKET") || "socialite-dev-uploads",
  region: System.get_env("AWS_REGION") || "us-east-1"

# For local storage (fallback)
config :socialite, :file_storage,
  adapter: :local
```

## Step 5: Test the Configuration

1. **Start your application**
   ```bash
   mix phx.server
   ```

2. **Test file upload**
   - Go to Settings page
   - Try uploading a profile picture
   - Check if the file appears in your S3 bucket under the `uploads/` folder

## Troubleshooting

### Common Issues

1. **Access Denied Error**
   - Check your IAM policy
   - Ensure the bucket name matches in the policy
   - Verify your AWS credentials

2. **Bucket Not Found**
   - Verify the bucket name in your environment variables
   - Ensure the bucket exists in the correct region

3. **Images Not Loading**
   - Check the bucket policy for public read access
   - Verify the bucket policy allows access to `uploads/*` path

4. **Upload Fails**
   - Check your AWS credentials
   - Verify the IAM user has the correct permissions
   - Check the application logs for detailed error messages

### Testing S3 Connection

You can test your S3 configuration in the Elixir console:

```elixir
# Start IEx
iex -S mix

# Test S3 connection
ExAws.S3.list_objects("your-bucket-name") |> ExAws.request()

# Test file upload
file_content = "test content"
ExAws.S3.put_object("your-bucket-name", "test/test.txt", file_content) |> ExAws.request()
```

## Security Best Practices

1. **Use IAM roles in production** instead of access keys when possible
2. **Rotate access keys regularly**
3. **Use least privilege principle** - only grant necessary permissions
4. **Enable CloudTrail** to monitor S3 access
5. **Consider using signed URLs** for sensitive content
6. **Enable versioning** on your S3 bucket for backup purposes

## Cost Optimization

1. **Set up lifecycle policies** to automatically delete old files
2. **Use appropriate storage classes** (Standard, IA, Glacier)
3. **Monitor usage** with AWS Cost Explorer
4. **Consider CDN** (CloudFront) for better performance and reduced costs

## Production Considerations

1. **Use separate buckets** for different environments
2. **Set up monitoring** and alerts
3. **Configure CORS** if needed for direct browser uploads
4. **Consider using presigned URLs** for large file uploads
5. **Implement file size limits** and validation
6. **Set up backup and disaster recovery**

## Environment-Specific Bucket Names

- Development: `socialite-dev-uploads`
- Staging: `socialite-staging-uploads`
- Production: `socialite-prod-uploads`

This ensures clear separation between environments and prevents accidental data mixing. 