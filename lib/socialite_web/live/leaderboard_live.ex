defmodule SocialiteWeb.LeaderboardLive do
  use SocialiteWeb, :live_view
  import Ecto.Query
  alias Socialite.{Repo, User}

  @impl true
  def mount(_params, session, socket) do
    current_user_id = session["current_user_id"]

    if current_user_id do
      current_user = Repo.get(User, current_user_id)

      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:active_tab, "kudos")
        |> load_leaderboard_data("kudos")

      {:ok, socket}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    socket =
      socket
      |> assign(:active_tab, tab)
      |> load_leaderboard_data(tab)

    {:noreply, socket}
  end

  defp load_leaderboard_data(socket, "kudos") do
    top_users =
      from(u in User,
        where: u.is_active == true,
        order_by: [desc: u.kudos_count, asc: u.inserted_at],
        limit: 50
      )
      |> Repo.all()

    assign(socket, :leaderboard, top_users)
  end

  defp load_leaderboard_data(socket, "followers") do
    top_users =
      from(u in User,
        where: u.is_active == true,
        order_by: [desc: u.followers_count, asc: u.inserted_at],
        limit: 50
      )
      |> Repo.all()

    assign(socket, :leaderboard, top_users)
  end

  defp load_leaderboard_data(socket, "posts") do
    # Get users with their post counts
    top_users =
      from(u in User,
        left_join: p in assoc(u, :posts),
        where: u.is_active == true,
        group_by: u.id,
        select: %{user: u, post_count: count(p.id)},
        order_by: [desc: count(p.id), asc: u.inserted_at],
        limit: 50
      )
      |> Repo.all()

    assign(socket, :leaderboard, top_users)
  end

  defp get_rank(leaderboard, user_id, tab) do
    case tab do
      "posts" ->
        leaderboard
        |> Enum.with_index(1)
        |> Enum.find_index(fn {%{user: user}, _index} -> user.id == user_id end)
        |> case do
          nil -> nil
          index -> index + 1
        end
      _ ->
        leaderboard
        |> Enum.with_index(1)
        |> Enum.find_index(fn {user, _index} -> user.id == user_id end)
        |> case do
          nil -> nil
          index -> index + 1
        end
    end
  end

  defp get_metric_value(entry, tab) do
    case tab do
      "kudos" -> entry.kudos_count
      "followers" -> entry.followers_count
      "posts" -> entry.post_count
    end
  end

  defp get_metric_label(tab) do
    case tab do
      "kudos" -> "Kudos"
      "followers" -> "Followers"
      "posts" -> "Posts"
    end
  end

  defp format_number(num) when num >= 1_000_000 do
    "#{Float.round(num / 1_000_000, 1)}M"
  end

  defp format_number(num) when num >= 1_000 do
    "#{Float.round(num / 1_000, 1)}K"
  end

  defp format_number(num), do: Integer.to_string(num)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-6">
      <div class="text-center mb-8">
        <h1 class="text-4xl font-bold text-gray-900 mb-2">🏆 Leaderboard</h1>
        <p class="text-gray-600">See who's leading the community!</p>
      </div>

      <!-- Tab Navigation -->
      <div class="flex justify-center mb-8">
        <div class="bg-gray-100 rounded-lg p-1">
          <button
            class={"px-4 py-2 rounded-md transition-colors #{if @active_tab == "kudos", do: "bg-white text-blue-600 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            phx-click="switch_tab"
            phx-value-tab="kudos"
          >
            ⭐ Kudos
          </button>
          <button
            class={"px-4 py-2 rounded-md transition-colors #{if @active_tab == "followers", do: "bg-white text-blue-600 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            phx-click="switch_tab"
            phx-value-tab="followers"
          >
            👥 Followers
          </button>
          <button
            class={"px-4 py-2 rounded-md transition-colors #{if @active_tab == "posts", do: "bg-white text-blue-600 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            phx-click="switch_tab"
            phx-value-tab="posts"
          >
            📝 Posts
          </button>
        </div>
      </div>

      <!-- Your Rank -->
      <%= if @current_user do %>
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-3">
              <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                <%= if @current_user.avatar && @current_user.avatar != "" do %>
                  <img src={@current_user.avatar} class="w-10 h-10 rounded-full object-cover" alt="Your avatar">
                <% else %>
                  <span class="text-blue-600 font-semibold">
                    <%= String.first(@current_user.first_name) <> String.first(@current_user.last_name) %>
                  </span>
                <% end %>
              </div>
              <div>
                <p class="font-semibold text-gray-900">Your Position</p>
                <p class="text-sm text-gray-600"><%= User.full_name(@current_user) %></p>
              </div>
            </div>
            <div class="text-right">
              <%= case get_rank(@leaderboard, @current_user.id, @active_tab) do %>
                <% nil -> %>
                  <p class="text-lg font-bold text-gray-500">Not Ranked</p>
                <% rank -> %>
                  <p class="text-lg font-bold text-blue-600">#<%= rank %></p>
              <% end %>
              <p class="text-sm text-gray-600">
                <%= case @active_tab do %>
                  <% "posts" -> %>
                    <%= Enum.find(@leaderboard, fn entry ->
                      case entry do
                        %{user: user} -> user.id == @current_user.id
                        _ -> false
                      end
                    end) |> case do
                      %{post_count: count} -> "#{format_number(count)} posts"
                      _ -> "0 posts"
                    end %>
                  <% "kudos" -> %>
                    <%= format_number(@current_user.kudos_count) %> kudos
                  <% "followers" -> %>
                    <%= format_number(@current_user.followers_count) %> followers
                <% end %>
              </p>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Leaderboard -->
      <div class="bg-white rounded-lg shadow-md overflow-hidden">
        <div class="px-6 py-4 bg-gray-50 border-b">
          <h2 class="text-lg font-semibold text-gray-900">
            Top <%= get_metric_label(@active_tab) %> Leaders
          </h2>
        </div>

        <div class="divide-y divide-gray-200">
          <%= if @active_tab == "posts" do %>
            <%= for {%{user: user, post_count: metric_value}, index} <- Enum.with_index(@leaderboard, 1) do %>
              <div class={"px-6 py-4 flex items-center justify-between hover:bg-gray-50 transition-colors #{if @current_user && user.id == @current_user.id, do: "bg-blue-50"}"}>
                <div class="flex items-center space-x-4">
                  <!-- Rank -->
                  <div class="flex-shrink-0 w-8 text-center">
                    <%= if index <= 3 do %>
                      <span class="text-2xl">
                        <%= case index do %>
                          <% 1 -> %>🥇
                          <% 2 -> %>🥈
                          <% 3 -> %>🥉
                        <% end %>
                      </span>
                    <% else %>
                      <span class="text-lg font-bold text-gray-500">#<%= index %></span>
                    <% end %>
                  </div>

                  <!-- User Info -->
                  <div class="flex items-center space-x-3">
                    <div class="w-12 h-12 bg-gray-200 rounded-full flex items-center justify-center">
                      <%= if user.avatar && user.avatar != "" do %>
                        <img src={user.avatar} class="w-12 h-12 rounded-full object-cover" alt="Avatar">
                      <% else %>
                        <span class="text-gray-600 font-semibold">
                          <%= String.first(user.first_name) <> String.first(user.last_name) %>
                        </span>
                      <% end %>
                    </div>
                    <div>
                      <p class="font-semibold text-gray-900"><%= User.full_name(user) %></p>
                      <%= if user.bio && String.trim(user.bio) != "" do %>
                        <p class="text-sm text-gray-600 truncate max-w-xs"><%= user.bio %></p>
                      <% end %>
                      <%= if User.has_location?(user) do %>
                        <p class="text-xs text-gray-500">📍 <%= user.city %><%= if user.state, do: ", #{user.state}" %></p>
                      <% end %>
                    </div>
                  </div>
                </div>

                <!-- Metric Value -->
                <div class="text-right">
                  <p class="text-lg font-bold text-gray-900">
                    <%= format_number(metric_value) %>
                  </p>
                  <p class="text-sm text-gray-500"><%= get_metric_label(@active_tab) %></p>
                </div>
              </div>
            <% end %>
          <% else %>
            <%= for {user, index} <- Enum.with_index(@leaderboard, 1) do %>
              <% metric_value = get_metric_value(user, @active_tab) %>
              <div class={"px-6 py-4 flex items-center justify-between hover:bg-gray-50 transition-colors #{if @current_user && user.id == @current_user.id, do: "bg-blue-50"}"}>
                <div class="flex items-center space-x-4">
                  <!-- Rank -->
                  <div class="flex-shrink-0 w-8 text-center">
                    <%= if index <= 3 do %>
                      <span class="text-2xl">
                        <%= case index do %>
                          <% 1 -> %>🥇
                          <% 2 -> %>🥈
                          <% 3 -> %>🥉
                        <% end %>
                      </span>
                    <% else %>
                      <span class="text-lg font-bold text-gray-500">#<%= index %></span>
                    <% end %>
                  </div>

                  <!-- User Info -->
                  <div class="flex items-center space-x-3">
                    <div class="w-12 h-12 bg-gray-200 rounded-full flex items-center justify-center">
                      <%= if user.avatar && user.avatar != "" do %>
                        <img src={user.avatar} class="w-12 h-12 rounded-full object-cover" alt="Avatar">
                      <% else %>
                        <span class="text-gray-600 font-semibold">
                          <%= String.first(user.first_name) <> String.first(user.last_name) %>
                        </span>
                      <% end %>
                    </div>
                    <div>
                      <p class="font-semibold text-gray-900"><%= User.full_name(user) %></p>
                      <%= if user.bio && String.trim(user.bio) != "" do %>
                        <p class="text-sm text-gray-600 truncate max-w-xs"><%= user.bio %></p>
                      <% end %>
                      <%= if User.has_location?(user) do %>
                        <p class="text-xs text-gray-500">📍 <%= user.city %><%= if user.state, do: ", #{user.state}" %></p>
                      <% end %>
                    </div>
                  </div>
                </div>

                <!-- Metric Value -->
                <div class="text-right">
                  <p class="text-lg font-bold text-gray-900">
                    <%= format_number(metric_value) %>
                  </p>
                  <p class="text-sm text-gray-500"><%= get_metric_label(@active_tab) %></p>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>

        <%= if Enum.empty?(@leaderboard) do %>
          <div class="px-6 py-12 text-center">
            <p class="text-gray-500">No data available yet. Be the first!</p>
          </div>
        <% end %>
      </div>

      <!-- Stats Summary -->
      <div class="mt-8 grid grid-cols-1 md:grid-cols-3 gap-6">
        <div class="bg-gradient-to-br from-yellow-400 to-yellow-600 rounded-lg p-6 text-white">
          <div class="flex items-center">
            <span class="text-3xl mr-3">⭐</span>
            <div>
              <p class="text-sm opacity-90">Total Kudos</p>
              <p class="text-2xl font-bold">
                <%= @leaderboard
                    |> Enum.map(fn entry ->
                      case entry do
                        %{user: user} -> user.kudos_count || 0
                        user -> user.kudos_count || 0
                      end
                    end)
                    |> Enum.sum()
                    |> format_number() %>
              </p>
            </div>
          </div>
        </div>

        <div class="bg-gradient-to-br from-blue-400 to-blue-600 rounded-lg p-6 text-white">
          <div class="flex items-center">
            <span class="text-3xl mr-3">👥</span>
            <div>
              <p class="text-sm opacity-90">Active Users</p>
              <p class="text-2xl font-bold"><%= length(@leaderboard) %></p>
            </div>
          </div>
        </div>

        <div class="bg-gradient-to-br from-green-400 to-green-600 rounded-lg p-6 text-white">
          <div class="flex items-center">
            <span class="text-3xl mr-3">📝</span>
            <div>
              <p class="text-sm opacity-90">Total Posts</p>
              <p class="text-2xl font-bold">
                <%= if @active_tab == "posts" do %>
                  <%= @leaderboard
                      |> Enum.map(fn %{post_count: count} -> count end)
                      |> Enum.sum()
                      |> format_number() %>
                <% else %>
                  <%= @leaderboard
                      |> Enum.map(fn user ->
                        # Quick estimate - in a real app you'd want to cache this
                        case Repo.aggregate(from(p in Socialite.Post, where: p.user_id == ^user.id), :count, :id) do
                          nil -> 0
                          count -> count
                        end
                      end)
                      |> Enum.sum()
                      |> format_number() %>
                <% end %>
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
