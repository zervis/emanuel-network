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
    <!-- Flash Messages -->
    <%= if Phoenix.Flash.get(@flash, :info) do %>
      <div class="fixed top-20 right-2 mr-2 w-80 sm:w-96 z-[1000] max-w-md w-full mx-4">
        <div class="bg-emerald-50 text-emerald-800 ring-emerald-500 ring-1 px-6 py-3 rounded-lg shadow-lg">
          <div class="flex items-center justify-between">
            <span class="font-medium"><%= Phoenix.Flash.get(@flash, :info) %></span>
            <button onclick="this.parentElement.parentElement.parentElement.remove()" class="text-emerald-600 hover:text-emerald-400 ml-4">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>
    <% end %>

    <%= if Phoenix.Flash.get(@flash, :error) do %>
      <div class="fixed top-20 right-2 mr-2 w-80 sm:w-96 z-[1000] max-w-md w-full mx-4">
        <div class="bg-red-50 text-red-800 ring-red-500 ring-1 px-6 py-3 rounded-lg shadow-lg">
          <div class="flex items-center justify-between">
            <span class="font-medium"><%= Phoenix.Flash.get(@flash, :error) %></span>
            <button onclick="this.parentElement.parentElement.parentElement.remove()" class="text-red-600 hover:text-red-400 ml-4">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>
    <% end %>

    <!-- Main Content -->
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
                      <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3a2 2 0 012-2h4a2 2 0 012 2v4m-6 4v10m6-10v10m-6-4h6" />
                      </svg>
                      Create Event
                    </.link>
                    <div class="flex gap-2">
                      <button
                        type="submit"
                        class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium text-sm"
                      >
                        Share
                      </button>
                    </div>
                  </div>
                </form>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Group Events -->
        <div class="space-y-6 mb-8">
          <div class="flex items-center justify-between">
            <h2 class="text-xl font-semibold text-gray-900">Upcoming Events</h2>
          </div>

          <!-- Events List -->
          <div class="space-y-4">
            <%= if @group_events != [] do %>
              <div class="space-y-4">
                <%= for event <- @group_events do %>
                  <div class="bg-white rounded-xl shadow-sm border p-6">
                    <!-- Event header -->
                    <div class="flex items-start justify-between mb-4">
                      <div class="flex-1">
                        <h3 class="text-lg font-semibold text-gray-900 mb-2"><%= event.title %></h3>
                        <%= if event.description do %>
                          <p class="text-gray-600 mb-3"><%= event.description %></p>
                        <% end %>
                        <div class="flex flex-wrap items-center gap-4 text-sm text-gray-500">
                          <div class="flex items-center gap-1">
                            <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3a2 2 0 012-2h4a2 2 0 012 2v4m-6 4v10m6-10v10m-6-4h6" />
                            </svg>
                            <span><%= Calendar.strftime(event.start_time, "%B %d, %Y at %I:%M %p") %></span>
                          </div>
                          <%= if event.end_time do %>
                            <span>- <%= Calendar.strftime(event.end_time, "%I:%M %p") %></span>
                          <% end %>
                          <%= if event.address do %>
                            <div class="flex items-center gap-1">
                              <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                              </svg>
                              <span><%= event.address %></span>
                            </div>
                          <% end %>
                          <%= if event.is_online do %>
                            <div class="flex items-center gap-1">
                              <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                              </svg>
                              <span>Online Event</span>
                            </div>
                          <% end %>
                        </div>
                      </div>
                      <div class="flex items-center gap-3 ml-4">
                        <div class="text-right">
                          <p class="text-sm font-medium text-gray-900"><%= event.attendees_count %> attending</p>
                          <%= if event.max_attendees do %>
                            <p class="text-xs text-gray-500">of <%= event.max_attendees %> max</p>
                          <% end %>
                        </div>
                        <%= if @is_member do %>
                          <.link
                            navigate={~p"/groups/#{@group.id}/events/#{event.id}"}
                            class="bg-blue-500 text-white px-4 py-2 rounded-lg hover:bg-blue-600 transition-colors font-medium text-sm"
                          >
                            View Event
                          </.link>
                        <% end %>
                      </div>
                    </div>

                    <!-- Event organizer -->
                    <div class="flex items-center gap-2 text-sm text-gray-500">
                      <span>Organized by</span>
                      <div class="flex items-center gap-2">
                        <div class="w-6 h-6 bg-blue-500 rounded-full flex items-center justify-center text-white text-xs font-medium">
                          <%= String.first(event.user.first_name) %><%= String.first(event.user.last_name) %>
                        </div>
                        <span class="font-medium"><%= event.user.first_name %> <%= event.user.last_name %></span>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="bg-white rounded-xl shadow-sm border p-6 text-center">
                <div class="text-gray-500 mb-4">
                  <svg class="w-12 h-12 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3a2 2 0 012-2h4a2 2 0 012 2v4m-6 4v10m6-10v10m-6-4h6" />
                  </svg>
                </div>
                <h3 class="text-lg font-medium text-gray-900 mb-2">No upcoming events</h3>
                <p class="text-gray-600 mb-4">Be the first to create an event for this group!</p>
                <%= if @is_member do %>
                  <.link
                    navigate={~p"/groups/#{@group.id}/events/new"}
                    class="inline-flex items-center gap-2 bg-green-500 text-white px-4 py-2 rounded-lg hover:bg-green-600 transition-colors font-medium text-sm"
                  >
                    <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                    </svg>
                    Create Event
                  </.link>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Group Posts -->
        <div class="space-y-6">
          <div class="flex items-center justify-between">
            <h2 class="text-xl font-semibold text-gray-900">Recent Posts</h2>
          </div>

          <!-- Posts List -->
          <div class="space-y-6">
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


    """
  end
end
