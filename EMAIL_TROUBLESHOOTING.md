# Email Troubleshooting Guide

## Current Status

I've temporarily switched your email configuration to use the **Local adapter** instead of SMTP. This means:

✅ **Emails will be captured locally instead of sent via SMTP**
✅ **You can view all emails at: http://localhost:4000/dev/mailbox**
✅ **This helps us test if the email generation is working**

## Step 1: Test Email Generation

1. **Go to your app**: http://localhost:4000
2. **Register a new user account** or **try to resend confirmation email**
3. **Check the local mailbox**: http://localhost:4000/dev/mailbox
4. **You should see the confirmation email there**

If you see emails in the local mailbox, the email generation is working correctly, and the issue is with SMTP configuration.

## Step 2: Fix SMTP Configuration (Gmail)

The issue with Gmail is that you need an **App Password**, not your regular password.

### Gmail App Password Setup:

1. **Enable 2-Factor Authentication** on your Gmail account:
   - Go to https://myaccount.google.com/security
   - Turn on 2-Step Verification

2. **Generate App Password**:
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" as the app
   - Copy the generated 16-character password

3. **Update the configuration**:
   Edit `config/dev.exs` and uncomment the SMTP section:

```elixir
# Configure mailer for development - using Local adapter for testing
# This will store emails locally so you can see them at http://localhost:4000/dev/mailbox
# config :socialite, Socialite.Mailer,
#   adapter: Swoosh.Adapters.Local

# Uncomment below for SMTP (requires proper Gmail App Password)
config :socialite, Socialite.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  port: 587,
  username: "emanuel.network.email@gmail.com",
  password: "your-16-character-app-password-here",  # Replace with actual app password
  tls: :if_available,
  allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
  ssl: false,
  retries: 1,
  no_mx_lookups: false,
  auth: :always
```

## Step 3: Alternative Email Services

If Gmail continues to have issues, here are better alternatives:

### Option A: Mailtrap (Recommended for Development)

Mailtrap is perfect for development - it captures emails without sending them:

1. Sign up at https://mailtrap.io (free tier available)
2. Get your SMTP credentials
3. Update `config/dev.exs`:

```elixir
config :socialite, Socialite.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.mailtrap.io",
  port: 587,
  username: "your-mailtrap-username",
  password: "your-mailtrap-password",
  tls: :if_available,
  ssl: false,
  auth: :always
```

### Option B: SendGrid (Production Ready)

1. Sign up at https://sendgrid.com (free tier: 100 emails/day)
2. Create an API key
3. Update `config/dev.exs`:

```elixir
config :socialite, Socialite.Mailer,
  adapter: Swoosh.Adapters.Sendgrid,
  api_key: "your-sendgrid-api-key"
```

### Option C: Mailgun

1. Sign up at https://mailgun.com
2. Get your API key and domain
3. Update `config/dev.exs`:

```elixir
config :socialite, Socialite.Mailer,
  adapter: Swoosh.Adapters.Mailgun,
  api_key: "your-mailgun-api-key",
  domain: "your-mailgun-domain"
```

## Step 4: Testing Process

1. **Test with Local adapter first** (current setup)
2. **Verify emails appear at http://localhost:4000/dev/mailbox**
3. **Switch to SMTP when ready**
4. **Restart server after config changes**: `mix phx.server`
5. **Check server logs for SMTP errors**

## Step 5: Debug SMTP Issues

If SMTP still doesn't work, add this to see detailed logs:

```elixir
# Add to config/dev.exs
config :logger, level: :debug

# Add to lib/socialite/accounts.ex in the send_confirmation_email function
require Logger
Logger.debug("Attempting to send email to: #{user.email}")
Logger.debug("SMTP Config: #{inspect(Application.get_env(:socialite, Socialite.Mailer))}")
```

## Current Recommendation

**For now, use the Local adapter** (current setup) to verify your email system works:

1. ✅ Go to http://localhost:4000/dev/mailbox
2. ✅ Register a new user
3. ✅ Check if confirmation email appears in mailbox
4. ✅ Click the confirmation link to test the full flow

Once you confirm the email system works locally, then we can fix the SMTP configuration for actual email sending.

## Quick Test Commands

```bash
# Restart server after config changes
mix phx.server

# Test email endpoint
curl http://localhost:4000/dev/mailbox

# Check if server is running
curl -I http://localhost:4000/
```

Let me know what you see in the local mailbox at http://localhost:4000/dev/mailbox after trying to register or resend confirmation emails! 