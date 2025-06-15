defmodule SocialiteWeb.Plugs.RequireEmailConfirmation do
  import Plug.Conn
  import Phoenix.Controller
  alias Socialite.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = conn.assigns[:current_user]

    case current_user do
      nil ->
        # No user logged in, let it pass (other plugs will handle authentication)
        conn

      user ->
        if Accounts.email_confirmed?(user) do
          # Email is confirmed, proceed
          conn
        else
          # Email not confirmed, redirect to confirmation page
          conn
          |> put_flash(:error, "Please confirm your email address to access this feature.")
          |> redirect(to: "/email-confirmation")
          |> halt()
        end
    end
  end
end
