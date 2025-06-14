defmodule SocialiteWeb.GroupLive do
  use SocialiteWeb, :live_view

  alias Socialite.Groups

  @impl true
  def mount(%{"group_id" => group_id}, session, socket) do
    current_user_id = session["current_user_id"]

    # Safely get user and group from database
    with %Socialite.User{} = current_user <- Socialite.Repo.get(Socialite.User, current_user_id),
         %Socialite.Group{} = group <- Groups.get_group!(group_id) do

      # Get group posts, events, and members
      group_posts = Groups.list_group_posts(group.id)
      group_events = Groups.list_group_events(group.id)
      group_members = Groups.list_group_members(group.id)
      is_member = Groups.member?(current_user_id, group.id)
      user_role = Groups.get_user_role(current_user_id, group.id)

      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:group, group)
       |> assign(:group_posts, group_posts)
       |> assign(:group_events, group_events)
       |> assign(:group_members, group_members)
       |> assign(:is_member, is_member)
       |> assign(:user_role, user_role)
       |> assign(:show_create_post_modal, false)
       |> assign(:post_changeset, Groups.change_group_post(%Socialite.GroupPost{}, %{"user_id" => current_user_id, "group_id" => group.id}))
       |> assign(:quick_post_content, "")
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
  def handle_event("show_create_post_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_post_modal, true)}
  end

  @impl true
  def handle_event("hide_create_post_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_post_modal, false)}
  end



  @impl true
  def handle_event("validate_post", %{"group_post" => post_params}, socket) do
    changeset =
      %Socialite.GroupPost{}
      |> Groups.change_group_post(Map.merge(post_params, %{
        "user_id" => socket.assigns.current_user.id,
        "group_id" => socket.assigns.group.id
      }))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :post_changeset, changeset)}
  end



  @impl true
  def handle_event("create_post", %{"group_post" => post_params}, socket) do
    post_params = Map.merge(post_params, %{
      "user_id" => socket.assigns.current_user.id,
      "group_id" => socket.assigns.group.id
    })

    case Groups.create_group_post(post_params) do
      {:ok, _post} ->
        # Refresh posts
        group_posts = Groups.list_group_posts(socket.assigns.group.id)

        {:noreply,
         socket
         |> assign(:group_posts, group_posts)
         |> assign(:show_create_post_modal, false)
         |> assign(:post_changeset, Groups.change_group_post(%Socialite.GroupPost{}, %{"user_id" => socket.assigns.current_user.id, "group_id" => socket.assigns.group.id}))
         |> put_flash(:info, "Post created successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :post_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("update_quick_post", %{"content" => content}, socket) do
    {:noreply, assign(socket, :quick_post_content, content)}
  end

  @impl true
  def handle_event("submit_quick_post", %{"content" => content}, socket) do
    content = String.trim(content)

    if content != "" do
      post_params = %{
        "content" => content,
        "user_id" => socket.assigns.current_user.id,
        "group_id" => socket.assigns.group.id
      }

      case Groups.create_group_post(post_params) do
        {:ok, _post} ->
          # Refresh posts
          group_posts = Groups.list_group_posts(socket.assigns.group.id)

          {:noreply,
           socket
           |> assign(:group_posts, group_posts)
           |> assign(:quick_post_content, "")
           |> put_flash(:info, "Post shared successfully!")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to create post")}
      end
    else
      {:noreply, put_flash(socket, :error, "Post content cannot be empty")}
    end
  end



  @impl true
  def render(assigns) do
    ~H"""
    <!-- Main layout container -->
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <header class="bg-white border-b border-gray-200 px-4 py-3 flex items-center justify-between relative z-[100]">
        <!-- Left side -->
        <div class="flex items-center space-x-4">
          <!-- Mobile menu button -->
          <button
            id="root-sidebar-toggle"
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

      <main class="flex">
        <!-- Sidebar -->
        <aside
          id="root-site__sidebar"
          class="w-64 bg-white border-r border-gray-200 transition-transform duration-300 ease-in-out max-xl:-translate-x-full fixed xl:relative h-screen xl:h-auto z-50"
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
          id="root-site__sidebar__overlay"
          class="fixed inset-0 bg-black bg-opacity-50 z-40 hidden xl:hidden"
        ></div>

        <!-- Content Area -->
        <div class="flex-1 flex">
          <!-- Center Content -->
          <div class="flex-1 xl:mr-80 mr-8 p-6 pb-8">
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

            <!-- Quick Post and Actions (only for members) -->
            <%= if @is_member do %>
              <div class="bg-white rounded-xl shadow-sm border p-6 mb-6">
                <!-- Quick Post Input -->
                <div class="flex items-start gap-4 mb-4">
                  <div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white font-medium flex-shrink-0">
                    <%= String.first(@current_user.first_name) %><%= String.first(@current_user.last_name) %>
                  </div>
                  <div class="flex-1">
                    <form phx-submit="submit_quick_post" phx-change="update_quick_post" class="space-y-3">
                      <textarea
                        name="content"
                        placeholder="Say something to the group..."
                        rows="3"
                        class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                      ><%= @quick_post_content %></textarea>
                      <div class="flex justify-between items-center">
                        <.link
                          navigate={~p"/groups/#{@group.id}/events/new"}
                          class="bg-green-500 text-white px-4 py-2 rounded-lg hover:bg-green-600 transition-colors font-medium text-sm flex items-center gap-2"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                          Create Event
                        </.link>
                        <div class="flex gap-2">
                          <button
                            phx-click="show_create_post_modal"
                            type="button"
                            class="text-gray-600 hover:text-gray-800 px-3 py-2 rounded-lg hover:bg-gray-100 transition-colors text-sm"
                          >
                            Add Photo
                          </button>
                          <button
                            type="submit"
                            disabled={@quick_post_content == ""}
                            class="bg-blue-500 text-white px-6 py-2 rounded-lg hover:bg-blue-600 transition-colors font-medium text-sm disabled:bg-gray-300 disabled:cursor-not-allowed"
                          >
                            Post
                          </button>
                        </div>
                      </div>
                    </form>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- Group Content -->
            <div class="xl:space-y-6 space-y-3">

              <!-- Upcoming Events -->
              <%= if @group_events != [] do %>
                <div class="bg-white rounded-xl shadow-sm border p-6">
                  <h2 class="text-lg font-semibold text-gray-900 mb-4">Upcoming Events</h2>
                  <div class="space-y-4">
                    <%= for event <- Enum.take(@group_events, 3) do %>
                      <div class="border border-gray-200 rounded-lg p-4 hover:border-blue-300 transition-colors">
                        <div class="flex justify-between items-start">
                          <div class="flex-1">
                            <.link navigate={~p"/events/#{event.id}"} class="font-semibold text-gray-900 hover:text-blue-600 transition-colors">
                              <%= event.title %>
                            </.link>
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

          <!-- Right Sidebar - Members -->
          <div class="hidden xl:block w-72 fixed right-0 top-16 h-[calc(100vh-64px)] bg-white border-l border-gray-200 overflow-y-auto">
            <div class="p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">
                Members (<%= @group.members_count %>)
              </h3>

              <div class="space-y-3">
                <%= for member <- @group_members do %>
                  <div class="flex items-center gap-3 p-2 rounded-lg hover:bg-gray-50">
                    <div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white font-medium">
                      <%= String.first(member.user.first_name) %><%= String.first(member.user.last_name) %>
                    </div>
                    <div class="flex-1">
                      <p class="font-medium text-gray-900 text-sm">
                        <%= member.user.first_name %> <%= member.user.last_name %>
                        <%= if member.role == "admin" do %>
                          <span class="text-xs bg-blue-100 text-blue-600 px-2 py-0.5 rounded-full ml-1">Admin</span>
                        <% end %>
                        <%= if member.role == "moderator" do %>
                          <span class="text-xs bg-green-100 text-green-600 px-2 py-0.5 rounded-full ml-1">Mod</span>
                        <% end %>
                      </p>
                      <p class="text-xs text-gray-500">
                        Joined <%= Calendar.strftime(member.inserted_at, "%B %Y") %>
                      </p>
                    </div>
                  </div>
                <% end %>
              </div>

              <%= if @group.members_count > length(@group_members) do %>
                <div class="mt-4 text-center">
                  <button class="text-blue-600 hover:text-blue-700 text-sm font-medium">
                    View all members →
                  </button>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </main>
    </div>

    <!-- Create Post Modal -->
    <%= if @show_create_post_modal do %>
      <div id={"create_post_modal_#{@group.id}"} class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" phx-click="hide_create_post_modal">
        <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white" phx-click-away="hide_create_post_modal">
          <div class="mt-3">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Create Post</h3>
            <.form for={@post_changeset} phx-change="validate_post" phx-submit="create_post">
              <div class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Post Content</label>
                  <.input
                    field={@post_changeset[:content]}
                    type="textarea"
                    placeholder="What's on your mind?"
                    rows="4"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Image URL (Optional)</label>
                  <.input
                    field={@post_changeset[:image_url]}
                    type="text"
                    placeholder="https://example.com/image.jpg"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
                <div class="flex justify-end space-x-3 pt-4">
                  <button type="button" phx-click="hide_create_post_modal" class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400">
                    Cancel
                  </button>
                  <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700" disabled={!@post_changeset.valid?}>
                    Create Post
                  </button>
                </div>
              </div>
            </.form>
          </div>
        </div>
      </div>
    <% end %>



    <script>
      // Simple sidebar toggle for mobile
      document.getElementById('root-sidebar-toggle')?.addEventListener('click', function() {
        const sidebar = document.getElementById('root-site__sidebar');
        const overlay = document.getElementById('root-site__sidebar__overlay');
        sidebar.classList.toggle('-translate-x-full');
        overlay.classList.toggle('hidden');
      });

      document.getElementById('root-site__sidebar__overlay')?.addEventListener('click', function() {
        const sidebar = document.getElementById('root-site__sidebar');
        const overlay = document.getElementById('root-site__sidebar__overlay');
        sidebar.classList.add('-translate-x-full');
        overlay.classList.add('hidden');
      });
    </script>
    """
  end
end
