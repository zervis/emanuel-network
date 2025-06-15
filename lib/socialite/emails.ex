defmodule Socialite.Emails do
  import Swoosh.Email
  alias Socialite.Accounts.User

  @doc """
  Sends a confirmation email to a newly registered user.
  """
  def confirmation_email(%User{} = user, token) do
    confirmation_url = "#{SocialiteWeb.Endpoint.url()}/confirm-email/#{user.id}/#{token}"

    new()
    |> to({user.first_name <> " " <> user.last_name, user.email})
    |> from({"Emanuel Network", "noreply@emanuel.network"})
    |> subject("Welcome to Emanuel Network - Please confirm your email")
    |> html_body(confirmation_html_body(user, confirmation_url))
    |> text_body(confirmation_text_body(user, confirmation_url))
  end

  defp confirmation_html_body(%User{} = user, confirmation_url) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Welcome to Emanuel Network</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
            .content { background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }
            .button { display: inline-block; background: #667eea; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold; margin: 20px 0; }
            .button:hover { background: #5a6fd8; }
            .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>Welcome to Emanuel Network!</h1>
            <p>Thank you for joining our community, #{user.first_name}!</p>
        </div>

        <div class="content">
            <h2>Please confirm your email address</h2>
            <p>Hi #{user.first_name},</p>
            <p>Welcome to Emanuel Network! We're excited to have you as part of our community where meaningful connections are made.</p>
            <p>To get started and access all features, please confirm your email address by clicking the button below:</p>

            <div style="text-align: center;">
                <a href="#{confirmation_url}" class="button">Confirm My Email</a>
            </div>

            <p>If the button doesn't work, you can copy and paste this link into your browser:</p>
            <p style="word-break: break-all; background: #e9ecef; padding: 10px; border-radius: 5px;">#{confirmation_url}</p>

            <p><strong>This link will expire in 24 hours.</strong></p>

            <p>If you didn't create an account with Emanuel Network, please ignore this email.</p>

            <p>Best regards,<br>The Emanuel Network Team</p>
        </div>

        <div class="footer">
            <p>Emanuel Network - Connecting meaningful relationships</p>
            <p>If you have any questions, please contact us at support@emanuel.network</p>
        </div>
    </body>
    </html>
    """
  end

  defp confirmation_text_body(%User{} = user, confirmation_url) do
    """
    Welcome to Emanuel Network!

    Hi #{user.first_name},

    Thank you for joining Emanuel Network! We're excited to have you as part of our community where meaningful connections are made.

    To get started and access all features, please confirm your email address by visiting this link:

    #{confirmation_url}

    This link will expire in 24 hours.

    If you didn't create an account with Emanuel Network, please ignore this email.

    Best regards,
    The Emanuel Network Team

    ---
    Emanuel Network - Connecting meaningful relationships
    If you have any questions, please contact us at support@emanuel.network
    """
  end

  @doc """
  Sends a welcome email after email confirmation.
  """
  def welcome_email(%User{} = user) do
    new()
    |> to({user.first_name <> " " <> user.last_name, user.email})
    |> from({"Emanuel Network", "noreply@emanuel.network"})
    |> subject("Welcome to Emanuel Network - Your account is now active!")
    |> html_body(welcome_html_body(user))
    |> text_body(welcome_text_body(user))
  end

  defp welcome_html_body(%User{} = user) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Welcome to Emanuel Network</title>
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
            .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
            .content { background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px; }
            .feature { background: white; padding: 20px; margin: 15px 0; border-radius: 5px; border-left: 4px solid #667eea; }
            .button { display: inline-block; background: #667eea; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold; margin: 20px 0; }
            .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🎉 Your account is now active!</h1>
            <p>Welcome to Emanuel Network, #{user.first_name}!</p>
        </div>

        <div class="content">
            <h2>You're all set to start connecting!</h2>
            <p>Hi #{user.first_name},</p>
            <p>Congratulations! Your email has been confirmed and your Emanuel Network account is now fully active.</p>

            <h3>Here's what you can do now:</h3>

            <div class="feature">
                <h4>🏠 Complete Your Profile</h4>
                <p>Add your bio, location, and interests to help others find and connect with you.</p>
            </div>

            <div class="feature">
                <h4>👥 Find Your Community</h4>
                <p>Discover and join groups that match your interests and location.</p>
            </div>

            <div class="feature">
                <h4>💬 Start Conversations</h4>
                <p>Share posts, comment on others' content, and send direct messages.</p>
            </div>

            <div class="feature">
                <h4>⭐ Give Kudos</h4>
                <p>Show appreciation for community members with our kudos system.</p>
            </div>

                         <div style="text-align: center;">
                 <a href="#{SocialiteWeb.Endpoint.url()}/feed" class="button">Start Exploring</a>
             </div>

            <p>We're here to help you build meaningful connections. If you have any questions, don't hesitate to reach out!</p>

            <p>Best regards,<br>The Emanuel Network Team</p>
        </div>

        <div class="footer">
            <p>Emanuel Network - Connecting meaningful relationships</p>
            <p>Need help? Contact us at support@emanuel.network</p>
        </div>
    </body>
    </html>
    """
  end

  defp welcome_text_body(%User{} = user) do
    """
    🎉 Your account is now active!

    Hi #{user.first_name},

    Congratulations! Your email has been confirmed and your Emanuel Network account is now fully active.

    Here's what you can do now:

    🏠 Complete Your Profile
    Add your bio, location, and interests to help others find and connect with you.

    👥 Find Your Community
    Discover and join groups that match your interests and location.

    💬 Start Conversations
    Share posts, comment on others' content, and send direct messages.

    ⭐ Give Kudos
    Show appreciation for community members with our kudos system.

         Visit Emanuel Network: #{SocialiteWeb.Endpoint.url()}/feed

    We're here to help you build meaningful connections. If you have any questions, don't hesitate to reach out!

    Best regards,
    The Emanuel Network Team

    ---
    Emanuel Network - Connecting meaningful relationships
    Need help? Contact us at support@emanuel.network
    """
  end
end
