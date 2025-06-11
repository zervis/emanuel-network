defmodule SocialiteWeb.GroupLive do
  use SocialiteWeb, :live_view

  alias Socialite.{Groups, Accounts}

  @impl true
  def mount(%{"group_id" => group_id}, session, socket) do
    current_user_id = session["current_user_id"]

    # Safely get user and group from database
    with %Socialite.User{} = current_user <- Socialite.Repo.get(Socialite.User, current_user_id),
         %Socialite.Group{} = group <- Groups.get_group!(group_id) do

      # Get group posts and events
      group_posts = Groups.list_group_posts(group.id)
      group_events = Groups.list_group_events(group.id)
      is_member = Groups.member?(current_user_id, group.id)
      user_role = Groups.get_user_role(current_user_id, group.id)

      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:group, group)
       |> assign(:group_posts, group_posts)
       |> assign(:group_events, group_events)
       |> assign(:is_member, is_member)
       |> assign(:user_role, user_role)
       |> assign(:page_title, "#{group.name} - Groups")}
    else
      nil ->
        {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("join_group", _params, socket) do
    case Groups.join_group(socket.assigns.current_user.id, socket.assigns.group.id) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> assign(:is_member, true)
         |> assign(:user_role, "member")
         |> put_flash(:info, "Successfully joined #{socket.assigns.group.name}!")}
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to join group")}
    end
  end

  @impl true
  def handle_event("leave_group", _params, socket) do
    case Groups.leave_group(socket.assigns.current_user.id, socket.assigns.group.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:is_member, false)
         |> assign(:user_role, nil)
         |> put_flash(:info, "Left #{socket.assigns.group.name}")}
      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to leave group")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Flash messages -->
    <div class="fixed top-20 right-2 z-[1000] space-y-2">
      <.flash_group flash={@flash} />
    </div>

    <!-- Main layout container -->
    <div class="h-screen bg-gray-50 overflow-hidden">
      <!-- Header -->
      <header class="bg-white border-b border-gray-200 px-4 py-3 flex items-center justify-between relative z-[100]">
        <!-- Left side -->
        <div class="flex items-center space-x-4">
          <!-- Mobile menu button -->
          <button
            id="sidebar-toggle"
            class="lg:hidden p-2 rounded-md text-gray-600 hover:text-gray-900 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>

          <!-- Logo -->
          <div class="flex items-center">
            <a href="/" class="text-xl font-bold text-blue-600">Socialite</a>
          </div>
        </div>

        <!-- Center - Search -->
        <div class="hidden md:flex flex-1 max-w-md mx-8">
          <div class="relative w-full">
            <input
              type="text"
              placeholder="Search..."
              class="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
            <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <svg class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>
          </div>
        </div>

        <!-- Right side - Navigation icons -->
        <div class="flex items-center space-x-2">
          <a href="/feed" class="p-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg">
            <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z" />
            </svg>
          </a>
          <a href="/messages" class="p-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg">
            <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
          </a>
          <a href="/profile" class="p-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg">
            <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            </svg>
          </a>
        </div>
      </header>

      <main class="flex h-[calc(100vh-64px)]">
        <!-- Sidebar -->
        <aside
          id="site__sidebar"
          class="w-64 bg-white border-r border-gray-200 transition-transform duration-300 ease-in-out max-xl:-translate-x-full fixed xl:relative h-full z-50"
        >
          <nav class="p-4 space-y-2">
            <a
              href="/feed"
              class="flex items-center space-x-3 px-3 py-2 text-gray-700 rounded-lg hover:bg-gray-100"
            >
              <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z" />
              </svg>
              <span>Feed</span>
            </a>
            <a
              href="/groups"
              class="flex items-center space-x-3 px-3 py-2 text-blue-600 bg-blue-50 rounded-lg"
            >
              <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
              <span>Groups</span>
            </a>
            <a
              href="/messages"
              class="flex items-center space-x-3 px-3 py-2 text-gray-700 rounded-lg hover:bg-gray-100"
            >
              <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
              </svg>
              <span>Messages</span>
            </a>
            <a
              href="/profile"
              class="flex items-center space-x-3 px-3 py-2 text-gray-700 rounded-lg hover:bg-gray-100"
            >
              <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
              <span>Profile</span>
            </a>
          </nav>
        </aside>

        <!-- Sidebar overlay for mobile -->
        <div
          id="site__sidebar__overlay"
          class="fixed inset-0 bg-black bg-opacity-50 z-40 hidden xl:hidden"
        ></div>

        <!-- Content Area -->
        <div class="flex-1 flex">
          <!-- Center Content -->
          <div class="flex-1 mr-8">
            <!-- Group Header -->
            <div class="mb-8">
              <div class="bg-white rounded-xl shadow-sm border p-6">
                <div class="flex justify-between items-start">
                  <div class="flex-1">
                    <div class="flex items-center gap-4 mb-4">
                      <a
                        href="/groups"
                        class="text-blue-600 hover:text-blue-700 flex items-center gap-1"
                      >
                        <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                        </svg>
                        Back to Groups
                      </a>
                    </div>
                    <h1 class="text-3xl font-bold text-gray-900 mb-2"><%= @group.name %></h1>
                    <%= if @group.description do %>
                      <p class="text-gray-600 mb-4"><%= @group.description %></p>
                    <% end %>
                    <div class="flex items-center gap-6 text-sm text-gray-500">
                      <span><%= @group.members_count %> members</span>
                      <%= if @group.address do %>
                        <span>📍 <%= @group.address %></span>
                      <% end %>
                      <span>Created by <%= @group.creator.first_name %> <%= @group.creator.last_name %></span>
                    </div>
                  </div>
                  <div class="flex items-center gap-3">
                    <%= if @is_member do %>
                      <span class="text-green-600 text-sm font-medium">✓ Member</span>
                      <%= if @user_role != "admin" do %>
                        <button
                          phx-click="leave_group"
                          class="bg-red-500 text-white px-4 py-2 rounded-lg hover:bg-red-600 transition-colors text-sm"
                        >
                          Leave Group
                        </button>
                      <% end %>
                    <% else %>
                      <button
                        phx-click="join_group"
                        class="bg-blue-500 text-white px-6 py-2 rounded-lg hover:bg-blue-600 transition-colors font-medium"
                      >
                        Join Group
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>

            <!-- Group Content -->
            <div class="xl:space-y-6 space-y-3">

              <!-- Upcoming Events -->
              <%= if @group_events != [] do %>
                <div class="bg-white rounded-xl shadow-sm border p-6">
                  <h2 class="text-lg font-semibold text-gray-900 mb-4">Upcoming Events</h2>
                  <div class="space-y-4">
                    <%= for event <- Enum.take(@group_events, 3) do %>
                      <div class="border border-gray-200 rounded-lg p-4">
                        <div class="flex justify-between items-start">
                          <div class="flex-1">
                            <h3 class="font-semibold text-gray-900"><%= event.title %></h3>
                            <p class="text-sm text-gray-600 mt-1">
                              📅 <%= Calendar.strftime(event.start_time, "%B %d, %Y at %I:%M %p") %>
                            </p>
                            <%= if event.description do %>
                              <p class="text-sm text-gray-600 mt-2"><%= String.slice(event.description, 0, 100) %></p>
                            <% end %>
                          </div>
                          <div class="text-sm text-gray-500">
                            <%= event.attendees_count %> attending
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                  <%= if length(@group_events) > 3 do %>
                    <div class="mt-4 text-center">
                      <a href="#" class="text-blue-600 hover:text-blue-700 text-sm font-medium">
                        View all events →
                      </a>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <!-- Group Posts -->
              <%= if @group_posts != [] do %>
                <div class="space-y-6">
                  <%= for post <- @group_posts do %>
                    <div class="bg-white rounded-xl shadow-sm border p-6">
                      <!-- Post header -->
                      <div class="flex items-center justify-between mb-4">
                        <div class="flex items-center space-x-3">
                          <div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white font-medium">
                            <%= String.first(post.user.first_name) %><%= String.first(post.user.last_name) %>
                          </div>
                          <div>
                            <p class="font-medium text-gray-900">
                              <%= post.user.first_name %> <%= post.user.last_name %>
                            </p>
                            <p class="text-sm text-gray-500">
                              <%= Calendar.strftime(post.inserted_at, "%B %d, %Y at %I:%M %p") %>
                            </p>
                          </div>
                        </div>
                      </div>

                      <!-- Post content -->
                      <div class="mb-4">
                        <p class="text-gray-900 whitespace-pre-wrap"><%= post.content %></p>
                        <%= if post.image_url do %>
                          <div class="mt-4">
                            <img src={post.image_url} alt="Post image" class="rounded-lg max-w-full h-auto" />
                          </div>
                        <% end %>
                      </div>

                      <!-- Post actions -->
                      <div class="flex items-center justify-between pt-4 border-t border-gray-100">
                        <div class="flex items-center space-x-6">
                          <button class="flex items-center space-x-2 text-gray-500 hover:text-blue-600">
                            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                            </svg>
                            <span><%= post.likes_count %></span>
                          </button>
                          <button class="flex items-center space-x-2 text-gray-500 hover:text-blue-600">
                            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                            </svg>
                            <span><%= length(post.group_post_comments) %></span>
                          </button>
                        </div>
                      </div>

                      <!-- Comments -->
                      <%= if post.group_post_comments != [] do %>
                        <div class="mt-4 pt-4 border-t border-gray-100">
                          <div class="space-y-3">
                            <%= for comment <- Enum.take(post.group_post_comments, 3) do %>
                              <div class="flex space-x-3">
                                <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center text-sm text-gray-600">
                                  <%= String.first(comment.user.first_name) %><%= String.first(comment.user.last_name) %>
                                </div>
                                <div class="flex-1">
                                  <p class="text-sm">
                                    <span class="font-medium text-gray-900">
                                      <%= comment.user.first_name %> <%= comment.user.last_name %>
                                    </span>
                                    <%= comment.content %>
                                  </p>
                                  <p class="text-xs text-gray-500 mt-1">
                                    <%= Calendar.strftime(comment.inserted_at, "%B %d at %I:%M %p") %>
                                  </p>
                                </div>
                              </div>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <div class="bg-white rounded-xl shadow-sm border p-6 text-center">
                  <div class="text-gray-500 mb-4">
                    <svg class="w-12 h-12 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                    </svg>
                  </div>
                  <h3 class="text-lg font-medium text-gray-900 mb-2">No posts yet</h3>
                  <p class="text-gray-600">Be the first to share something with this group!</p>
                </div>
              <% end %>

            </div>
          </div>
        </div>
      </main>
    </div>

    <script>
      // Sidebar toggle functionality
      document.addEventListener('DOMContentLoaded', function() {
        const sidebarToggle = document.getElementById('sidebar-toggle');
        const sidebar = document.getElementById('site__sidebar');
        const overlay = document.getElementById('site__sidebar__overlay');

        if (sidebarToggle && sidebar && overlay) {
          sidebarToggle.addEventListener('click', function() {
            sidebar.classList.toggle('max-xl:-translate-x-full');
            overlay.classList.toggle('hidden');
          });

          overlay.addEventListener('click', function() {
            sidebar.classList.add('max-xl:-translate-x-full');
            overlay.classList.add('hidden');
          });
        }
      });
    </script>
    """
  end
end
