defmodule SocialiteWeb.Router do
  use SocialiteWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SocialiteWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug SocialiteWeb.Plugs.AssignCurrentUser
  end

  pipeline :require_email_confirmation do
    plug SocialiteWeb.Plugs.RequireEmailConfirmation
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SocialiteWeb do
    pipe_through :browser

    # Public routes (no authentication required)
    get "/", PageController, :home
    get "/terms", PageController, :terms
    get "/teaching", PageController, :teaching
    post "/login", PageController, :login
    post "/register", PageController, :register
    get "/logout", PageController, :logout
    get "/confirm-email/:user_id/:token", PageController, :confirm_email

    # Routes that require login but not email confirmation
    get "/email-confirmation", PageController, :email_confirmation
    post "/resend-confirmation", PageController, :resend_confirmation
    get "/clear-session", PageController, :clear_session
  end

  scope "/", SocialiteWeb do
    pipe_through [:browser, :require_email_confirmation]

    # Protected routes that require email confirmation
    live "/feed", FeedLive
    get "/profile", PageController, :profile
    get "/search", PageController, :search
    live "/tags", TagsLive, :index
    live "/users/:user_id", ProfileLive, :show
    live "/profile/:user_id", ProfileLive, :show
    live "/kudos/:user_id", KudosLive, :show
    live "/messages", MessagesLive, :index
    live "/messages/:user_id", MessagesLive, :conversation
    live "/friends", FriendsLive, :index
    live "/leaderboard", LeaderboardLive, :index
    live "/groups", GroupsLive, :index
    live "/groups/new", CreateGroupLive, :new
    live "/groups/:group_id", GroupLive, :show
    live "/groups/:group_id/events/new", CreateEventLive, :new
    live "/events", EventsLive, :index
    live "/events/:id", EventLive, :show
    live "/events/new", CreateEventLive, :new
    live "/settings", SettingsLive, :index
    live "/notifications", NotificationsLive, :index
    post "/posts", PageController, :create_post
    post "/posts/:post_id/comments", PageController, :create_comment
  end

  # Other scopes may use custom stacks.
  # scope "/api", SocialiteWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:socialite, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SocialiteWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
