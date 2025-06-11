defmodule SocialiteWeb.FeedLive do
  use SocialiteWeb, :live_view

  alias Socialite.Accounts
  alias Socialite.Posts
  alias Socialite.Kudos

  @impl true
  def mount(_params, _session, socket) do
    # For demo purposes, we'll create a sample user if none exists
    current_user = get_or_create_demo_user()

    # Reset daily kudos if needed
    Accounts.reset_daily_kudos_if_needed()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:users, Accounts.list_users())
      |> assign(:leaderboard, Accounts.get_leaderboard())
      |> assign(:page_title, "Socialite - Social Network")

    {:ok, socket}
  end

  @impl true
  def handle_event("give_kudo", %{"user_id" => user_id, "message" => message}, socket) do
    current_user = socket.assigns.current_user

    case Kudos.can_give_kudo?(current_user.id, user_id) do
      true ->
        case Kudos.create_kudo(%{
          giver_id: current_user.id,
          receiver_id: user_id,
          message: message
        }) do
          {:ok, _kudo} ->
            # Update current user and leaderboard
            updated_user = Accounts.get_user!(current_user.id)
            leaderboard = Accounts.get_leaderboard()

            socket =
              socket
              |> assign(:current_user, updated_user)
              |> assign(:leaderboard, leaderboard)
              |> put_flash(:info, "Kudo sent successfully!")

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to send kudo")}
        end

      false ->
        {:noreply, put_flash(socket, :error, "You cannot give a kudo to this user today")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <header class="bg-white shadow-sm border-b">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center h-16">
            <div class="flex items-center">
              <h1 class="text-2xl font-bold text-blue-600">Socialite</h1>
            </div>

            <div class="flex items-center space-x-4">
              <span class="text-sm text-gray-600">
                Daily Kudos: <span class="font-semibold text-blue-600"><%= @current_user.daily_kudos %></span>
              </span>
              <span class="text-sm text-gray-600">
                Total Kudos: <span class="font-semibold text-green-600"><%= @current_user.kudos_count %></span>
              </span>
              <div class="flex items-center space-x-2">
                <img src={@current_user.avatar_url || "/images/default-avatar.png"}
                     alt="Avatar" class="w-8 h-8 rounded-full">
                <span class="text-sm font-medium"><%= @current_user.first_name %> <%= @current_user.last_name %></span>
              </div>
            </div>
          </div>
        </div>
      </header>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Main Feed -->
          <div class="lg:col-span-2">
            <div class="bg-white rounded-lg shadow p-6 mb-6">
              <h2 class="text-xl font-semibold mb-4">Welcome to Socialite!</h2>
              <p class="text-gray-600 mb-4">
                Connect with people, share your thoughts, and give kudos to spread positivity!
              </p>
              <div class="flex space-x-4">
                <.link navigate="/messages" class="bg-blue-500 text-white px-4 py-2 rounded-lg hover:bg-blue-600">
                  Messages
                </.link>
                <.link navigate="/groups" class="bg-green-500 text-white px-4 py-2 rounded-lg hover:bg-green-600">
                  Groups
                </.link>
                <.link navigate="/leaderboard" class="bg-purple-500 text-white px-4 py-2 rounded-lg hover:bg-purple-600">
                  Leaderboard
                </.link>
              </div>
            </div>

            <!-- Users List -->
            <div class="bg-white rounded-lg shadow p-6">
              <h3 class="text-lg font-semibold mb-4">Community Members</h3>
              <div class="space-y-4">
                <%= for user <- @users do %>
                  <%= if user.id != @current_user.id do %>
                    <div class="flex items-center justify-between p-4 border rounded-lg">
                      <div class="flex items-center space-x-3">
                        <img src={user.avatar_url || "/images/default-avatar.png"}
                             alt="Avatar" class="w-12 h-12 rounded-full">
                        <div>
                          <h4 class="font-medium"><%= user.first_name %> <%= user.last_name %></h4>
                          <p class="text-sm text-gray-600">@<%= user.username %></p>
                          <p class="text-sm text-green-600"><%= user.kudos_count %> kudos</p>
                        </div>
                      </div>

                      <%= if Kudos.can_give_kudo?(@current_user.id, user.id) do %>
                        <form phx-submit="give_kudo" class="flex items-center space-x-2">
                          <input type="hidden" name="user_id" value={user.id}>
                          <input type="text" name="message" placeholder="Say something nice..."
                                 class="px-3 py-1 border rounded text-sm" maxlength="100">
                          <button type="submit"
                                  class="bg-yellow-500 text-white px-3 py-1 rounded text-sm hover:bg-yellow-600">
                            Give Kudo ⭐
                          </button>
                        </form>
                      <% else %>
                        <span class="text-sm text-gray-400">Kudo given today</span>
                      <% end %>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Sidebar -->
          <div class="space-y-6">
            <!-- Leaderboard -->
            <div class="bg-white rounded-lg shadow p-6">
              <h3 class="text-lg font-semibold mb-4">🏆 Kudos Leaderboard</h3>
              <div class="space-y-3">
                <%= for {user, index} <- Enum.with_index(@leaderboard) do %>
                  <div class="flex items-center space-x-3">
                    <span class="text-lg">
                      <%= case index do %>
                        <% 0 -> "🥇" %>
                        <% 1 -> "🥈" %>
                        <% 2 -> "🥉" %>
                        <% _ -> "#{index + 1}." %>
                      <% end %>
                    </span>
                    <img src={user.avatar_url || "/images/default-avatar.png"}
                         alt="Avatar" class="w-8 h-8 rounded-full">
                    <div class="flex-1">
                      <p class="text-sm font-medium"><%= user.first_name %> <%= user.last_name %></p>
                      <p class="text-xs text-green-600"><%= user.kudos_count %> kudos</p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Quick Stats -->
            <div class="bg-white rounded-lg shadow p-6">
              <h3 class="text-lg font-semibold mb-4">📊 Your Stats</h3>
              <div class="space-y-2">
                <div class="flex justify-between">
                  <span class="text-sm text-gray-600">Daily Kudos Left:</span>
                  <span class="text-sm font-semibold text-blue-600"><%= @current_user.daily_kudos %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-sm text-gray-600">Total Kudos:</span>
                  <span class="text-sm font-semibold text-green-600"><%= @current_user.kudos_count %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-sm text-gray-600">Member Since:</span>
                  <span class="text-sm text-gray-600">
                    <%= Calendar.strftime(@current_user.inserted_at, "%b %Y") %>
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_or_create_demo_user do
    case Accounts.get_user_by_email("demo@socialite.com") do
      nil ->
        {:ok, user} = Accounts.create_user(%{
          email: "demo@socialite.com",
          username: "demo_user",
          first_name: "Demo",
          last_name: "User",
          password: "password123",
          password_confirmation: "password123"
        })
        user

      user -> user
    end
  end
end
