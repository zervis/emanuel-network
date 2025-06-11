defmodule SocialiteWeb.LeaderboardLive do
  use SocialiteWeb, :live_view

  alias Socialite.Accounts

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:leaderboard, Accounts.get_leaderboard(50))
      |> assign(:page_title, "Kudos Leaderboard")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <header class="bg-white shadow-sm border-b">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center h-16">
            <div class="flex items-center space-x-4">
              <.link navigate="/" class="text-2xl font-bold text-blue-600">Socialite</.link>
              <span class="text-gray-400">|</span>
              <h1 class="text-xl font-semibold">🏆 Kudos Leaderboard</h1>
            </div>

            <.link navigate="/" class="text-blue-600 hover:text-blue-800">
              ← Back to Feed
            </.link>
          </div>
        </div>
      </header>

      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="bg-white rounded-lg shadow">
          <div class="px-6 py-4 border-b">
            <h2 class="text-lg font-semibold">Top Community Members</h2>
            <p class="text-sm text-gray-600">Ranked by total kudos received</p>
          </div>

          <div class="divide-y">
            <%= for {user, index} <- Enum.with_index(@leaderboard) do %>
              <div class="px-6 py-4 flex items-center space-x-4">
                <div class="flex-shrink-0 w-12 text-center">
                  <span class="text-2xl">
                    <%= case index do %>
                      <% 0 -> "🥇" %>
                      <% 1 -> "🥈" %>
                      <% 2 -> "🥉" %>
                      <% _ -> %>
                        <span class="text-lg font-semibold text-gray-600">#<%= index + 1 %></span>
                    <% end %>
                  </span>
                </div>

                <img src={user.avatar_url || "/images/default-avatar.png"}
                     alt="Avatar" class="w-16 h-16 rounded-full">

                <div class="flex-1">
                  <h3 class="text-lg font-medium"><%= user.first_name %> <%= user.last_name %></h3>
                  <p class="text-sm text-gray-600">@<%= user.username %></p>
                  <%= if user.bio do %>
                    <p class="text-sm text-gray-500 mt-1"><%= user.bio %></p>
                  <% end %>
                </div>

                <div class="text-right">
                  <div class="text-2xl font-bold text-green-600"><%= user.kudos_count %></div>
                  <div class="text-sm text-gray-600">kudos</div>
                </div>
              </div>
            <% end %>
          </div>

          <%= if Enum.empty?(@leaderboard) do %>
            <div class="px-6 py-12 text-center">
              <div class="text-gray-400 text-lg">No users found</div>
              <p class="text-gray-500 mt-2">Be the first to give and receive kudos!</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
