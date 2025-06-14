defmodule SocialiteWeb.EventLive do
  use SocialiteWeb, :live_view
  alias Socialite.{Groups, Repo}
  import Ecto.Query

  @impl true
  def mount(%{"id" => id}, session, socket) do
    current_user = get_current_user(session)

    if current_user do
      event = Groups.get_group_event!(id)

      # Check if user is attending
      is_attending = Repo.exists?(
        from ea in Socialite.EventAttendee,
        where: ea.user_id == ^current_user.id and ea.event_id == ^event.id
      )

      {:ok,
       socket
       |> assign(:current_user, current_user)
       |> assign(:event, event)
       |> assign(:is_attending, is_attending)
       |> assign(:comment_changeset, Groups.change_event_comment(%Socialite.EventComment{}, %{"user_id" => current_user.id, "event_id" => event.id}))}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to view events")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("attend_event", _params, socket) do
    case Groups.join_event(socket.assigns.current_user.id, socket.assigns.event.id) do
      {:ok, _attendee} ->
        # Refresh event data
        event = Groups.get_group_event!(socket.assigns.event.id)

        {:noreply,
         socket
         |> assign(:event, event)
         |> assign(:is_attending, true)
         |> put_flash(:info, "Successfully joined the event!")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to join event")}
    end
  end

  @impl true
  def handle_event("leave_event", _params, socket) do
    case Groups.leave_event(socket.assigns.current_user.id, socket.assigns.event.id) do
      {:ok, _} ->
        # Refresh event data
        event = Groups.get_group_event!(socket.assigns.event.id)

        {:noreply,
         socket
         |> assign(:event, event)
         |> assign(:is_attending, false)
         |> put_flash(:info, "Successfully left the event!")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to leave event")}
    end
  end

  @impl true
  def handle_event("validate_comment", %{"event_comment" => comment_params}, socket) do
    changeset =
      %Socialite.EventComment{}
      |> Groups.change_event_comment(Map.merge(comment_params, %{
        "user_id" => socket.assigns.current_user.id,
        "event_id" => socket.assigns.event.id
      }))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :comment_changeset, changeset)}
  end

  @impl true
  def handle_event("create_comment", %{"event_comment" => comment_params}, socket) do
    comment_params = Map.merge(comment_params, %{
      "user_id" => socket.assigns.current_user.id,
      "event_id" => socket.assigns.event.id
    })

    case Groups.create_event_comment(comment_params) do
      {:ok, _comment} ->
        # Refresh event data to include new comment
        event = Groups.get_group_event!(socket.assigns.event.id)

        {:noreply,
         socket
         |> assign(:event, event)
         |> assign(:comment_changeset, Groups.change_event_comment(%Socialite.EventComment{}, %{"user_id" => socket.assigns.current_user.id, "event_id" => socket.assigns.event.id}))
         |> put_flash(:info, "Comment added successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :comment_changeset, changeset)}
    end
  end

  defp get_current_user(session) do
    case session["current_user_id"] do
      nil -> nil
      user_id -> Socialite.Repo.get!(Socialite.User, user_id)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <div class="max-w-4xl mx-auto py-8 px-4 sm:px-6 lg:px-8">
        <div class="bg-white shadow rounded-lg overflow-hidden">
          <!-- Event Header -->
          <div class="bg-gradient-to-r from-blue-600 to-indigo-600 px-6 py-8 text-white">
            <div class="flex items-center justify-between">
              <div class="flex-1">
                <h1 class="text-3xl font-bold mb-2"><%= @event.title %></h1>
                <p class="text-blue-100 mb-4">
                  Hosted by <strong><%= Socialite.User.full_name(@event.user) %></strong> in <strong><%= @event.group.name %></strong>
                </p>
                <div class="flex items-center gap-6 text-sm">
                  <div class="flex items-center gap-2">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                    </svg>
                    <span><%= Calendar.strftime(@event.start_time, "%B %d, %Y at %I:%M %p") %></span>
                  </div>
                  <div class="flex items-center gap-2">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                    </svg>
                    <span><%= @event.attendees_count %> attending</span>
                  </div>
                </div>
              </div>
              <div class="flex flex-col gap-3">
                <%= if @is_attending do %>
                  <button
                    phx-click="leave_event"
                    class="bg-red-500 text-white px-6 py-3 rounded-lg hover:bg-red-600 transition-colors font-medium flex items-center gap-2"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                    </svg>
                    Leave Event
                  </button>
                <% else %>
                  <button
                    phx-click="attend_event"
                    class="bg-green-500 text-white px-6 py-3 rounded-lg hover:bg-green-600 transition-colors font-medium flex items-center gap-2"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
                    </svg>
                    Attend Event
                  </button>
                <% end %>
                <.link
                  navigate={~p"/groups/#{@event.group.id}"}
                  class="bg-white/20 text-white px-6 py-2 rounded-lg hover:bg-white/30 transition-colors font-medium text-center"
                >
                  View Group
                </.link>
              </div>
            </div>
          </div>

          <!-- Event Details -->
          <div class="px-6 py-8">
            <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
              <!-- Main Content -->
              <div class="lg:col-span-2">
                <div class="space-y-6">
                  <!-- Description -->
                  <%= if @event.description do %>
                    <div>
                      <h2 class="text-xl font-semibold text-gray-900 mb-3">About this event</h2>
                      <p class="text-gray-700 leading-relaxed"><%= @event.description %></p>
                    </div>
                  <% end %>

                  <!-- Location -->
                  <%= if @event.address || @event.is_online do %>
                    <div>
                      <h2 class="text-xl font-semibold text-gray-900 mb-3">Location</h2>
                      <%= if @event.is_online do %>
                        <div class="flex items-center gap-3 p-4 bg-blue-50 rounded-lg">
                          <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
                          </svg>
                          <div>
                            <p class="font-medium text-blue-900">Online Event</p>
                            <%= if @event.meeting_url do %>
                              <a href={@event.meeting_url} target="_blank" class="text-blue-600 hover:text-blue-700 text-sm">
                                Join Meeting →
                              </a>
                            <% end %>
                          </div>
                        </div>
                      <% end %>
                      <%= if @event.address do %>
                        <div class="flex items-center gap-3 p-4 bg-gray-50 rounded-lg">
                          <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                          </svg>
                          <div>
                            <p class="font-medium text-gray-900">In-Person Event</p>
                            <p class="text-gray-600"><%= @event.address %></p>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Sidebar -->
              <div class="space-y-6">
                <!-- Event Info -->
                <div class="bg-gray-50 rounded-lg p-6">
                  <h3 class="font-semibold text-gray-900 mb-4">Event Details</h3>
                  <div class="space-y-4 text-sm">
                    <div class="flex items-center gap-3">
                      <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                      </svg>
                      <div>
                        <p class="font-medium text-gray-900">Start Time</p>
                        <p class="text-gray-600"><%= Calendar.strftime(@event.start_time, "%B %d, %Y at %I:%M %p") %></p>
                      </div>
                    </div>
                    <%= if @event.end_time do %>
                      <div class="flex items-center gap-3">
                        <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                        </svg>
                        <div>
                          <p class="font-medium text-gray-900">End Time</p>
                          <p class="text-gray-600"><%= Calendar.strftime(@event.end_time, "%B %d, %Y at %I:%M %p") %></p>
                        </div>
                      </div>
                    <% end %>
                    <%= if @event.max_attendees do %>
                      <div class="flex items-center gap-3">
                        <svg class="w-5 h-5 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                        </svg>
                        <div>
                          <p class="font-medium text-gray-900">Capacity</p>
                          <p class="text-gray-600"><%= @event.attendees_count %>/<%= @event.max_attendees %> attending</p>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>

                <!-- Group Info -->
                <div class="bg-gray-50 rounded-lg p-6">
                  <h3 class="font-semibold text-gray-900 mb-4">Hosted by</h3>
                  <div class="flex items-center gap-3">
                    <img src={@event.group.avatar || ~p"/images/avatars/avatar-7.jpg"} alt="" class="w-12 h-12 rounded-full">
                    <div>
                      <p class="font-medium text-gray-900"><%= @event.group.name %></p>
                      <p class="text-sm text-gray-600"><%= @event.group.members_count %> members</p>
                    </div>
                  </div>
                  <.link
                    navigate={~p"/groups/#{@event.group.id}"}
                    class="block mt-4 text-center bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium"
                  >
                    View Group
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Comments Section -->
        <div class="mt-8 bg-white shadow rounded-lg overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-xl font-semibold text-gray-900">Discussion</h2>
          </div>

          <!-- Add Comment Form -->
          <div class="px-6 py-4 border-b border-gray-200">
            <.form :let={f} for={@comment_changeset} phx-change="validate_comment" phx-submit="create_comment" class="space-y-4">
              <div class="flex items-start gap-4">
                <div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white font-medium flex-shrink-0">
                  <%= String.first(@current_user.first_name) %><%= String.first(@current_user.last_name) %>
                </div>
                <div class="flex-1">
                  <.input
                    field={f[:content]}
                    type="textarea"
                    placeholder="Share your thoughts about this event..."
                    rows="3"
                    class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                  />
                  <div class="mt-3 flex justify-end">
                    <button
                      type="submit"
                      disabled={!@comment_changeset.valid?}
                      class="bg-blue-500 text-white px-6 py-2 rounded-lg hover:bg-blue-600 transition-colors font-medium text-sm disabled:bg-gray-300 disabled:cursor-not-allowed"
                    >
                      Post Comment
                    </button>
                  </div>
                </div>
              </div>
            </.form>
          </div>

          <!-- Comments List -->
          <div class="px-6 py-4">
            <%= if @event.event_comments != [] do %>
              <div class="space-y-6">
                <%= for comment <- @event.event_comments do %>
                  <div class="flex items-start gap-4">
                    <div class="w-10 h-10 bg-gray-300 rounded-full flex items-center justify-center text-gray-600 font-medium flex-shrink-0">
                      <%= String.first(comment.user.first_name) %><%= String.first(comment.user.last_name) %>
                    </div>
                    <div class="flex-1">
                      <div class="bg-gray-50 rounded-lg p-4">
                        <div class="flex items-center gap-2 mb-2">
                          <span class="font-medium text-gray-900">
                            <%= comment.user.first_name %> <%= comment.user.last_name %>
                          </span>
                          <span class="text-sm text-gray-500">
                            <%= Calendar.strftime(comment.inserted_at, "%B %d at %I:%M %p") %>
                          </span>
                        </div>
                        <p class="text-gray-700 whitespace-pre-wrap"><%= comment.content %></p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div class="text-center py-8">
                <div class="text-gray-500 mb-4">
                  <svg class="w-12 h-12 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                  </svg>
                </div>
                <h3 class="text-lg font-medium text-gray-900 mb-2">No comments yet</h3>
                <p class="text-gray-600">Be the first to share your thoughts about this event!</p>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Back to Feed -->
        <div class="mt-6 text-center">
          <.link navigate={~p"/feed"} class="text-blue-600 hover:text-blue-700 font-medium">
            ← Back to Feed
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
