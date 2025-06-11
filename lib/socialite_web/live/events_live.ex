defmodule SocialiteWeb.EventsLive do
  use SocialiteWeb, :live_view

  import Ecto.Query, warn: false
  alias Socialite.{Groups, Accounts}

  @impl true
  def mount(_params, session, socket) do
    current_user_id = session["current_user_id"]

    # Safely get user from database
    case Socialite.Repo.get(Socialite.User, current_user_id) do
      %Socialite.User{} = current_user ->
        # Get user's joined groups
        user_groups = Groups.get_user_groups(current_user_id)

        # Get all upcoming events from joined groups
        upcoming_events = Groups.get_upcoming_group_events(current_user_id)

        # Get all events (including past) from joined groups for complete view
        all_events = get_all_user_group_events(current_user_id)

        {:ok,
         socket
         |> assign(:current_user, current_user)
         |> assign(:user_groups, user_groups)
         |> assign(:upcoming_events, upcoming_events)
         |> assign(:all_events, all_events)
         |> assign(:selected_group, nil)
         |> assign(:show_create_group_modal, false)
         |> assign(:show_create_event_modal, false)
         |> assign(:group_changeset, Groups.change_group(%Socialite.Group{}, %{"creator_id" => current_user.id}))
         |> assign(:event_changeset, Groups.change_group_event(%Socialite.GroupEvent{}, %{"user_id" => current_user.id}))}

      nil ->
        {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_event("show_create_group_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_group_modal, true)}
  end

  @impl true
  def handle_event("hide_create_group_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_group_modal, false)}
  end

    @impl true
  def handle_event("show_create_event_modal", %{"group-select" => group_id}, socket) when group_id != "" do
    selected_group = Enum.find(socket.assigns.user_groups, &(&1.id == String.to_integer(group_id)))

    event_changeset = Groups.change_group_event(
      %Socialite.GroupEvent{},
      %{"user_id" => socket.assigns.current_user.id, "group_id" => group_id}
    )

    {:noreply,
     socket
     |> assign(:show_create_event_modal, true)
     |> assign(:selected_group, selected_group)
     |> assign(:event_changeset, event_changeset)}
  end

  @impl true
  def handle_event("show_create_event_modal", %{"group-select" => ""}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_create_event_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_event_modal, false)
     |> assign(:selected_group, nil)}
  end

  @impl true
  def handle_event("validate_group", %{"group" => group_params}, socket) do
    changeset =
      %Socialite.Group{}
      |> Groups.change_group(Map.put(group_params, "creator_id", socket.assigns.current_user.id))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :group_changeset, changeset)}
  end

  @impl true
  def handle_event("validate_event", %{"group_event" => event_params}, socket) do
    changeset =
      %Socialite.GroupEvent{}
      |> Groups.change_group_event(Map.merge(event_params, %{
        "user_id" => socket.assigns.current_user.id,
        "group_id" => socket.assigns.selected_group.id
      }))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :event_changeset, changeset)}
  end

  @impl true
  def handle_event("create_group", %{"group" => group_params}, socket) do
    # Set as private group and add creator_id
    group_params = Map.merge(group_params, %{
      "creator_id" => socket.assigns.current_user.id,
      "is_public" => false  # Make it private
    })

    case Groups.create_group(group_params) do
      {:ok, group} ->
        # Refresh user groups
        user_groups = Groups.get_user_groups(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:user_groups, user_groups)
         |> assign(:show_create_group_modal, false)
         |> assign(:group_changeset, Groups.change_group(%Socialite.Group{}, %{"creator_id" => socket.assigns.current_user.id}))
         |> put_flash(:info, "Private group created successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :group_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("create_event", %{"group_event" => event_params}, socket) do
    event_params = Map.merge(event_params, %{
      "user_id" => socket.assigns.current_user.id,
      "group_id" => socket.assigns.selected_group.id
    })

    case Groups.create_group_event(event_params) do
      {:ok, _event} ->
        # Refresh events
        upcoming_events = Groups.get_upcoming_group_events(socket.assigns.current_user.id)
        all_events = get_all_user_group_events(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:upcoming_events, upcoming_events)
         |> assign(:all_events, all_events)
         |> assign(:show_create_event_modal, false)
         |> assign(:selected_group, nil)
         |> assign(:event_changeset, Groups.change_group_event(%Socialite.GroupEvent{}, %{"user_id" => socket.assigns.current_user.id}))
         |> put_flash(:info, "Event created successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :event_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("join_event", %{"event_id" => event_id}, socket) do
    case Groups.join_event(socket.assigns.current_user.id, String.to_integer(event_id)) do
      {:ok, _attendee} ->
        # Refresh events to update attendee counts
        upcoming_events = Groups.get_upcoming_group_events(socket.assigns.current_user.id)
        all_events = get_all_user_group_events(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:upcoming_events, upcoming_events)
         |> assign(:all_events, all_events)
         |> put_flash(:info, "Successfully joined the event!")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to join event")}
    end
  end

  @impl true
  def handle_event("leave_event", %{"event_id" => event_id}, socket) do
    case Groups.leave_event(socket.assigns.current_user.id, String.to_integer(event_id)) do
      {:ok, _} ->
        # Refresh events to update attendee counts
        upcoming_events = Groups.get_upcoming_group_events(socket.assigns.current_user.id)
        all_events = get_all_user_group_events(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:upcoming_events, upcoming_events)
         |> assign(:all_events, all_events)
         |> put_flash(:info, "Successfully left the event!")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to leave event")}
    end
  end

  # Helper function to get all events from user's groups (including past events)
  defp get_all_user_group_events(user_id) do
    Socialite.Repo.all(
      from ge in Socialite.GroupEvent,
        join: gm in Socialite.GroupMember, on: gm.group_id == ge.group_id,
        where: gm.user_id == ^user_id,
        order_by: [desc: ge.start_time],
        preload: [:user, :group]
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen bg-gray-50 overflow-hidden">
      <!-- Flash Messages -->
      <.flash_group flash={@flash} class="fixed top-20 right-2 z-[1000] space-y-2" />

      <!-- Header -->
      <header class="bg-white border-b border-gray-200 px-4 py-3 fixed top-0 left-0 right-0 z-[100]">
        <div class="flex items-center justify-between max-w-6xl mx-auto">
          <div class="flex items-center space-x-4">
            <a href="/feed" class="text-2xl font-bold text-blue-600">Socialite</a>
            <div class="hidden md:flex items-center bg-gray-100 rounded-full px-4 py-2">
              <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
              <input type="text" placeholder="Search..." class="bg-transparent ml-2 focus:outline-none text-gray-700" />
            </div>
          </div>
          <div class="flex items-center space-x-4">
            <a href="/feed" class="p-2 rounded-full hover:bg-gray-100">
              <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
              </svg>
            </a>
            <a href="/messages" class="p-2 rounded-full hover:bg-gray-100">
              <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-3.582 8-8 8a9.863 9.863 0 01-4.255-.949L5 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 3.582-8 8-8s8 3.582 8 8z" />
              </svg>
            </a>
            <a href="/profile" class="p-2 rounded-full hover:bg-gray-100">
              <img src={@current_user.avatar || "/images/default-avatar.png"} alt="Profile" class="w-8 h-8 rounded-full" />
            </a>
          </div>
        </div>
      </header>

      <!-- Main Content with Sidebar -->
      <main class="pt-16 flex">
        <!-- Sidebar -->
        <div class="w-64 bg-white h-screen overflow-y-auto border-r border-gray-200 fixed left-0 top-16">
          <nav class="p-4 space-y-2">
            <a href="/feed" class="flex items-center space-x-3 text-gray-700 p-3 rounded-lg hover:bg-gray-100">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
              </svg>
              <span>Home</span>
            </a>
            <a href="/groups" class="flex items-center space-x-3 text-gray-700 p-3 rounded-lg hover:bg-gray-100">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
              <span>Groups</span>
            </a>
            <a href="/events" class="flex items-center space-x-3 text-white bg-blue-600 p-3 rounded-lg">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <span>Events</span>
            </a>
            <a href="/messages" class="flex items-center space-x-3 text-gray-700 p-3 rounded-lg hover:bg-gray-100">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-3.582 8-8 8a9.863 9.863 0 01-4.255-.949L5 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 3.582-8 8-8s8 3.582 8 8z" />
              </svg>
              <span>Messages</span>
            </a>
          </nav>
        </div>

        <!-- Center Content -->
        <div class="flex-1 ml-64 mr-8">
          <!-- Page Header -->
          <div class="mb-8 pt-6">
            <div class="flex justify-between items-center">
              <div>
                <h1 class="text-3xl font-bold text-gray-900 mb-2">Events</h1>
                <p class="text-gray-600">Discover and manage events from your groups</p>
              </div>
              <div class="flex space-x-3">
                <button
                  phx-click="show_create_group_modal"
                  class="bg-gray-500 text-white px-6 py-2 rounded-lg hover:bg-gray-600 transition-colors font-medium"
                >
                  Create Private Group
                </button>
                <%= if @user_groups != [] do %>
                  <div class="relative inline-block text-left">
                    <select
                      id="group-select"
                      class="bg-blue-500 text-white px-6 py-2 rounded-lg hover:bg-blue-600 transition-colors font-medium border-none focus:outline-none appearance-none cursor-pointer"
                      phx-change="show_create_event_modal"
                    >
                      <option value="">Create Event</option>
                      <%= for group <- @user_groups do %>
                        <option value={group.id}><%= group.name %></option>
                      <% end %>
                    </select>
                    <div class="absolute inset-y-0 right-0 flex items-center pr-2 pointer-events-none">
                      <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                      </svg>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Events Content -->
          <div class="xl:space-y-6 space-y-3">

            <!-- Upcoming Events -->
            <%= if @upcoming_events != [] do %>
              <div class="bg-white rounded-xl shadow-sm border p-6">
                <h2 class="text-lg font-semibold text-gray-900 mb-4">Upcoming Events</h2>
                <div class="space-y-4">
                  <%= for event <- @upcoming_events do %>
                    <div class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow">
                      <div class="flex justify-between items-start">
                        <div class="flex-1">
                          <h3 class="font-semibold text-gray-900"><%= event.title %></h3>
                          <p class="text-sm text-blue-600 mb-2">
                            <%= event.group.name %>
                          </p>
                          <p class="text-gray-600 text-sm mb-2"><%= event.description %></p>
                          <div class="flex items-center space-x-4 text-sm text-gray-500">
                            <span class="flex items-center">
                              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                              </svg>
                              <%= Calendar.strftime(event.start_time, "%B %d, %Y at %I:%M %p") %>
                            </span>
                            <span class="flex items-center">
                              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                              </svg>
                              <%= event.attendees_count %> attending
                            </span>
                            <%= if event.address do %>
                              <span class="flex items-center">
                                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                                </svg>
                                <%= event.address %>
                              </span>
                            <% end %>
                          </div>
                        </div>
                        <div class="flex flex-col space-y-2">
                          <button
                            phx-click="join_event"
                            phx-value-event_id={event.id}
                            class="bg-green-500 text-white px-4 py-2 rounded hover:bg-green-600 transition-colors text-sm"
                          >
                            RSVP
                          </button>
                          <button
                            phx-click="leave_event"
                            phx-value-event_id={event.id}
                            class="bg-red-500 text-white px-4 py-2 rounded hover:bg-red-600 transition-colors text-sm"
                          >
                            Leave
                          </button>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- All Events -->
            <%= if @all_events != [] do %>
              <div class="bg-white rounded-xl shadow-sm border p-6">
                <h2 class="text-lg font-semibold text-gray-900 mb-4">All Events</h2>
                <div class="space-y-4">
                  <%= for event <- @all_events do %>
                    <div class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow">
                      <div class="flex justify-between items-start">
                        <div class="flex-1">
                          <h3 class="font-semibold text-gray-900"><%= event.title %></h3>
                          <p class="text-sm text-blue-600 mb-2">
                            <%= event.group.name %>
                          </p>
                          <p class="text-gray-600 text-sm mb-2"><%= event.description %></p>
                          <div class="flex items-center space-x-4 text-sm text-gray-500">
                            <span class="flex items-center">
                              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                              </svg>
                              <%= Calendar.strftime(event.start_time, "%B %d, %Y at %I:%M %p") %>
                            </span>
                            <span class="flex items-center">
                              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                              </svg>
                              <%= event.attendees_count %> attending
                            </span>
                            <%= if event.address do %>
                              <span class="flex items-center">
                                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                                </svg>
                                <%= event.address %>
                              </span>
                            <% end %>
                          </div>
                          <%= if DateTime.compare(event.start_time, DateTime.utc_now()) == :lt do %>
                            <span class="inline-block mt-2 px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded">Past Event</span>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <div class="bg-white rounded-xl shadow-sm border p-8 text-center">
                <svg class="w-16 h-16 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <h3 class="text-lg font-medium text-gray-900 mb-2">No Events Found</h3>
                <p class="text-gray-600 mb-4">Join some groups to see events!</p>
                <a href="/groups" class="bg-blue-500 text-white px-6 py-2 rounded-lg hover:bg-blue-600 transition-colors font-medium inline-block">
                  Browse Groups
                </a>
              </div>
            <% end %>

          </div>
        </div>
      </main>

      <!-- Create Group Modal -->
      <%= if @show_create_group_modal do %>
        <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" phx-click="hide_create_group_modal">
          <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white" phx-click-away="hide_create_group_modal">
            <div class="mt-3">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Create Private Group</h3>
              <.form for={@group_changeset} phx-change="validate_group" phx-submit="create_group">
                <div class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Group Name</label>
                    <.input
                      field={@group_changeset[:name]}
                      type="text"
                      placeholder="Enter group name"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
                    <.input
                      field={@group_changeset[:description]}
                      type="textarea"
                      placeholder="Describe your group"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div class="flex justify-end space-x-3 pt-4">
                    <button type="button" phx-click="hide_create_group_modal" class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400">
                      Cancel
                    </button>
                    <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700" disabled={!@group_changeset.valid?}>
                      Create Group
                    </button>
                  </div>
                </div>
              </.form>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Create Event Modal -->
      <%= if @show_create_event_modal and @selected_group do %>
        <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" phx-click="hide_create_event_modal">
          <div class="relative top-10 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white max-h-screen overflow-y-auto" phx-click-away="hide_create_event_modal">
            <div class="mt-3">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Create Event for <%= @selected_group.name %></h3>
              <.form for={@event_changeset} phx-change="validate_event" phx-submit="create_event">
                <div class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Event Title</label>
                    <.input
                      field={@event_changeset[:title]}
                      type="text"
                      placeholder="Enter event title"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
                    <.input
                      field={@event_changeset[:description]}
                      type="textarea"
                      placeholder="Describe your event"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Start Time</label>
                    <.input
                      field={@event_changeset[:start_time]}
                      type="datetime-local"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">End Time (Optional)</label>
                    <.input
                      field={@event_changeset[:end_time]}
                      type="datetime-local"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Address (Optional)</label>
                    <.input
                      field={@event_changeset[:address]}
                      type="text"
                      placeholder="Event location"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Max Attendees (Optional)</label>
                    <.input
                      field={@event_changeset[:max_attendees]}
                      type="number"
                      placeholder="Maximum number of attendees"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  <div class="flex items-center">
                    <.input
                      field={@event_changeset[:is_online]}
                      type="checkbox"
                      class="mr-2"
                    />
                    <label class="text-sm font-medium text-gray-700">Online Event</label>
                  </div>
                  <div class="flex justify-end space-x-3 pt-4">
                    <button type="button" phx-click="hide_create_event_modal" class="px-4 py-2 bg-gray-300 text-gray-700 rounded-md hover:bg-gray-400">
                      Cancel
                    </button>
                    <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700" disabled={!@event_changeset.valid?}>
                      Create Event
                    </button>
                  </div>
                </div>
              </.form>
            </div>
          </div>
        </div>
      <% end %>


    </div>
    """
  end
end
