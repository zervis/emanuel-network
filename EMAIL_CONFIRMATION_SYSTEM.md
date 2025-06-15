# Email Confirmation System

This document describes the email confirmation system implemented for the Socialite application.

## Overview

The email confirmation system ensures that users verify their email addresses before accessing the full functionality of the application. This helps maintain data quality and prevents spam accounts.

## Components

### 1. Database Schema
- The `users` table includes a `confirmed_at` field (`:naive_datetime`) that stores when the user confirmed their email
- `confirmed_at` is `nil` for unconfirmed users and contains a timestamp for confirmed users

### 2. Accounts Context (`lib/socialite/accounts.ex`)

#### New Functions Added:
- `register_user/1` - Creates a user and sends confirmation email (replaces direct `create_user/1` in registration)
- `generate_confirmation_token/0` - Generates a secure random token for email confirmation
- `send_confirmation_email/1` - Sends confirmation email with token
- `confirm_user_email/2` - Confirms user email with token validation
- `resend_confirmation_email/1` - Resends confirmation email
- `email_confirmed?/1` - Checks if user's email is confirmed

#### Token Storage:
- Uses `:persistent_term` for token storage (simple in-memory cache)
- Tokens expire after 24 hours
- In production, consider using Redis or a database table for token storage

### 3. Email System (`lib/socialite/emails.ex`)

#### Email Templates:
- **Confirmation Email**: Sent after registration with confirmation link
- **Welcome Email**: Sent after successful email confirmation

#### Features:
- HTML and text versions of all emails
- Professional styling with Emanuel Network branding
- Clear call-to-action buttons
- Helpful instructions and support information

### 4. Authentication Middleware (`lib/socialite_web/plugs/require_email_confirmation.ex`)

#### Functionality:
- Checks if logged-in users have confirmed their email
- Redirects unconfirmed users to `/email-confirmation` page
- Applied to protected routes that require email confirmation

### 5. Routes and Controllers

#### New Routes:
- `GET /email-confirmation` - Shows confirmation status page
- `GET /confirm-email/:user_id/:token` - Processes email confirmation
- `POST /resend-confirmation` - Resends confirmation email

#### Route Organization:
- **Public routes**: No authentication required (home, login, register, etc.)
- **Login-only routes**: Require login but not email confirmation (email-confirmation page, resend)
- **Protected routes**: Require both login and email confirmation (feed, profile, etc.)

### 6. User Interface

#### Email Confirmation Page:
- Clean, professional design
- Shows user's email address
- Instructions for next steps
- Resend confirmation button
- Help and support information

#### Notification Banner:
- Appears on all pages for unconfirmed users
- Shows in the main layout
- Links to email confirmation page
- Clear call-to-action

## User Flow

### Registration Flow:
1. User fills out registration form
2. `register_user/1` creates user account (unconfirmed)
3. Confirmation email is sent automatically
4. User is logged in but redirected to `/email-confirmation`
5. User sees confirmation page with instructions

### Email Confirmation Flow:
1. User receives email with confirmation link
2. User clicks link: `/confirm-email/:user_id/:token`
3. System validates token and expiration
4. If valid: user's `confirmed_at` is set, welcome email sent
5. User is redirected to feed with success message

### Login Flow:
1. User enters credentials
2. If authentication succeeds:
   - If email confirmed: redirect to feed
   - If email not confirmed: redirect to confirmation page

### Access Control:
1. User tries to access protected route
2. `RequireEmailConfirmation` plug checks confirmation status
3. If not confirmed: redirect to confirmation page with error message
4. If confirmed: allow access to requested page

## Configuration

### Email Settings:
- Emails are sent using Swoosh mailer
- From address: "Emanuel Network" <noreply@emanuel.network>
- Development: Emails can be previewed at `/dev/mailbox`

### Token Security:
- Tokens are 32-byte random values, base64-encoded
- 24-hour expiration
- Single-use (deleted after successful confirmation)

## Testing

### Manual Testing:
1. Register a new account
2. Check that confirmation email is sent
3. Verify redirect to confirmation page
4. Test confirmation link
5. Verify access to protected routes after confirmation

### Email Preview:
- In development, visit `/dev/mailbox` to see sent emails
- No actual emails are sent in development mode

## Security Considerations

1. **Token Security**: Tokens are cryptographically secure random values
2. **Expiration**: Tokens expire after 24 hours
3. **Single Use**: Tokens are deleted after successful use
4. **Rate Limiting**: Consider adding rate limiting for resend requests
5. **Email Validation**: Email format is validated during registration

## Future Improvements

1. **Database Storage**: Move token storage from memory to database/Redis
2. **Rate Limiting**: Add rate limiting for confirmation email requests
3. **Email Templates**: Add more sophisticated email templates
4. **Analytics**: Track confirmation rates and user behavior
5. **Customization**: Allow users to change email before confirmation

## Troubleshooting

### Common Issues:
1. **Emails not sending**: Check Swoosh configuration
2. **Tokens not working**: Verify token storage and expiration logic
3. **Redirect loops**: Check route organization and plug order
4. **Layout errors**: Ensure `@current_user` is available in templates

### Debug Commands:
```elixir
# Check if user email is confirmed
Socialite.Accounts.email_confirmed?(user)

# Manually confirm a user (for testing)
user |> Socialite.Accounts.User.confirm_changeset() |> Socialite.Repo.update()

# Check stored tokens (development only)
:persistent_term.get({:email_confirmation, user_id}, nil)
``` 