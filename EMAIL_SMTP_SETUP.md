# Email SMTP Configuration Guide

This guide will help you configure SMTP email sending for the Socialite application.

## Current Configuration

The application is configured to use SMTP for sending emails in development. The configuration is in `config/dev.exs`.

## Setting Up Email Credentials

### Option 1: Environment Variables (Recommended)

Set the following environment variables in your terminal:

```bash
export SMTP_USERNAME="your-email@gmail.com"
export SMTP_PASSWORD="your-app-password"
```

### Option 2: Direct Configuration

Edit `config/dev.exs` and replace the placeholder values:

```elixir
config :socialite, Socialite.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.gmail.com",
  port: 587,
  username: "your-actual-email@gmail.com",
  password: "your-actual-app-password",
  # ... rest of config
```

## Email Provider Settings

### Gmail Setup

1. **Enable 2-Factor Authentication** on your Gmail account
2. **Generate an App Password**:
   - Go to Google Account settings
   - Security → 2-Step Verification → App passwords
   - Generate a new app password for "Mail"
3. **Use these settings**:
   - SMTP Server: `smtp.gmail.com`
   - Port: `587`
   - Username: Your Gmail address
   - Password: The generated app password (not your regular password)

### Outlook/Hotmail Setup

Update `config/dev.exs`:

```elixir
config :socialite, Socialite.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp-mail.outlook.com",
  port: 587,
  username: "your-email@outlook.com",
  password: "your-password",
  tls: :if_available,
  ssl: false,
  auth: :always
```

### Yahoo Mail Setup

Update `config/dev.exs`:

```elixir
config :socialite, Socialite.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp.mail.yahoo.com",
  port: 587,
  username: "your-email@yahoo.com",
  password: "your-app-password",  # Generate app password in Yahoo settings
  tls: :if_available,
  ssl: false,
  auth: :always
```

### Custom SMTP Server

```elixir
config :socialite, Socialite.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "mail.yourdomain.com",
  port: 587,  # or 25, 465, 2525 depending on your server
  username: "your-email@yourdomain.com",
  password: "your-password",
  tls: :if_available,
  ssl: false,  # set to true if using port 465
  auth: :always
```

## Testing Email Configuration

1. **Start the Phoenix server**:
   ```bash
   mix phx.server
   ```

2. **Test email confirmation**:
   - Register a new user account
   - Check if the confirmation email is sent
   - Check server logs for any SMTP errors

3. **Check logs for errors**:
   - Look for SMTP connection errors
   - Verify authentication is successful
   - Check if emails are being queued and sent

## Common Issues and Solutions

### Authentication Failed
- **Gmail**: Make sure you're using an App Password, not your regular password
- **Outlook**: Ensure 2FA is enabled and you're using the correct credentials
- **Yahoo**: Generate and use an App Password

### Connection Timeout
- Check if your firewall/network allows SMTP connections
- Try different ports (587, 465, 25)
- Some networks block SMTP ports

### TLS/SSL Issues
- Try setting `tls: :always` or `tls: :never`
- For port 465, set `ssl: true`
- For port 587, set `ssl: false` and `tls: :if_available`

### Rate Limiting
- Gmail: 500 emails per day for free accounts
- Outlook: 300 emails per day for free accounts
- Consider using a dedicated email service for production

## Production Configuration

For production, update `config/runtime.exs` or use environment variables:

```elixir
config :socialite, Socialite.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: System.get_env("SMTP_RELAY") || "smtp.gmail.com",
  port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
  username: System.get_env("SMTP_USERNAME"),
  password: System.get_env("SMTP_PASSWORD"),
  tls: :if_available,
  ssl: false,
  auth: :always
```

## Alternative Email Services

For production applications, consider using dedicated email services:

- **SendGrid**: Reliable with good deliverability
- **Mailgun**: Developer-friendly with good APIs
- **Amazon SES**: Cost-effective for high volume
- **Postmark**: Excellent for transactional emails

These services provide better deliverability, analytics, and handling of bounces/complaints.

## Verification

After configuration, you should see successful email sending in the logs:

```
[info] Email sent successfully to user@example.com
```

If you see errors, check the specific error message and refer to the troubleshooting section above. 