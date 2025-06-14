defmodule SocialiteWeb.FriendsLive do
  use SocialiteWeb, :live_view
  import Ecto.Query
  alias Socialite.{Repo, User, FollowContext, Tags}

  @genders ["Male", "Female", "Other"]
  @relationship_statuses ["Single", "In a relationship", "Married", "Divorced", "Widowed", "Other"]
  @personality_types ["INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"]

  def mount(_params, session, socket) do
    current_user_id = Map.get(session, "current_user_id")

    if current_user_id do
      # Get the current user struct from the database
      current_user = Repo.get!(User, current_user_id)

      # Initialize search filters
      search_filters = %{
        distance: 25,
        gender: "",
        relationship_status: "",
        personality_type: "",
        min_age: 18,
        max_age: 65
      }

      friends = get_friends_by_filters(current_user, search_filters)

      {:ok, assign(socket,
        current_user: current_user,
        friends: friends,
        search_filters: search_filters,
        genders: @genders,
        relationship_statuses: @relationship_statuses,
        personality_types: @personality_types,
        page_title: "Friends"
      )}
    else
      {:ok, redirect(socket, to: "/login")}
    end
  end

  def handle_event("update_filters", %{"search" => search_params}, socket) do
    search_filters = %{
      distance: String.to_integer(search_params["distance"] || "25"),
      gender: search_params["gender"] || "",
      relationship_status: search_params["relationship_status"] || "",
      personality_type: search_params["personality_type"] || "",
      min_age: String.to_integer(search_params["min_age"] || "18"),
      max_age: String.to_integer(search_params["max_age"] || "65")
    }

    friends = get_friends_by_filters(socket.assigns.current_user, search_filters)

    {:noreply, assign(socket, friends: friends, search_filters: search_filters)}
  end

  def handle_event("follow_user", %{"user_id" => user_id}, socket) do
    follower_id = socket.assigns.current_user.id
    followed_id = String.to_integer(user_id)

    case FollowContext.follow_user(follower_id, followed_id) do
      {:ok, _follow} ->
        # Refresh friends list to update follow status
        friends = get_friends_by_filters(socket.assigns.current_user, socket.assigns.search_filters)

        {:noreply,
         socket
         |> assign(friends: friends)
         |> put_flash(:info, "Successfully followed user!")}

      {:error, error} ->
        error_message = if is_binary(error), do: error, else: "Unable to follow user"
        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  def handle_event("unfollow_user", %{"user_id" => user_id}, socket) do
    follower_id = socket.assigns.current_user.id
    followed_id = String.to_integer(user_id)

    case FollowContext.unfollow_user(follower_id, followed_id) do
      {:ok, :unfollowed} ->
        # Refresh friends list to update follow status
        friends = get_friends_by_filters(socket.assigns.current_user, socket.assigns.search_filters)

        {:noreply,
         socket
         |> assign(friends: friends)
         |> put_flash(:info, "Successfully unfollowed user!")}

      {:error, error} ->
        error_message = if is_binary(error), do: error, else: "Unable to unfollow user"
        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  def handle_event("message_user", %{"user_id" => user_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/messages/#{user_id}")}
  end

  def render(assigns) do
    ~H"""
    <!-- main contents -->
      <div class="p-2.5 pt-4">
        <!-- timeline -->
        <div class="lg:flex lg:items-start 2xl:gap-8 gap-6 ml-16" id="js-oversized">

          <!-- Center Content -->
          <div class="flex-1">
            <!-- Page Header -->
            <div class="bg-white rounded-lg shadow-sm border p-6 mb-6">
              <h1 class="text-3xl font-bold text-gray-900 mb-2">Find Friends Nearby</h1>
              <p class="text-gray-600">
                Discover people within your chosen distance and connect with them. Use the filters below to refine your search.
              </p>
              <%= if @current_user.latitude && @current_user.longitude do %>
                <p class="text-sm text-green-600 mt-2">
                  📍 Your location: <%= full_address(@current_user) %>
                </p>
              <% else %>
                <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mt-4">
                  <p class="text-yellow-800">
                    <strong>📍 Location not set:</strong>
                    <.link navigate="/settings" class="text-yellow-900 underline hover:text-yellow-700">
                      Update your location in settings
                    </.link>
                    to see friends sorted by distance.
                  </p>
                </div>
              <% end %>
            </div>

            <!-- Search Filters -->
            <div class="bg-white rounded-lg shadow-sm border p-6 mb-6">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">Search Filters</h2>
              <form phx-change="update_filters" class="space-y-4">
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
                  <!-- Distance Filter -->
                  <div>
                    <label for="distance" class="block text-sm font-medium text-gray-700 mb-2">
                      Distance Radius
                    </label>
                    <select name="search[distance]" id="distance" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
                      <option value="5" selected={@search_filters.distance == 5}>Within 5km</option>
                      <option value="15" selected={@search_filters.distance == 15}>Within 15km</option>
                      <option value="25" selected={@search_filters.distance == 25}>Within 25km</option>
                    </select>
                  </div>

                  <!-- Gender Filter -->
                  <div>
                    <label for="gender" class="block text-sm font-medium text-gray-700 mb-2">
                      Gender
                    </label>
                    <select name="search[gender]" id="gender" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
                      <option value="" selected={@search_filters.gender == ""}>All Genders</option>
                      <%= for gender <- @genders do %>
                        <option value={gender} selected={@search_filters.gender == gender}>
                          <%= gender %>
                        </option>
                      <% end %>
                    </select>
                  </div>

                  <!-- Min Age Filter -->
                  <div>
                    <label for="min_age" class="block text-sm font-medium text-gray-700 mb-2">
                      Min Age
                    </label>
                    <select name="search[min_age]" id="min_age" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
                      <%= for age <- 18..65 do %>
                        <option value={age} selected={@search_filters.min_age == age}>
                          <%= age %>
                        </option>
                      <% end %>
                    </select>
                  </div>

                  <!-- Max Age Filter -->
                  <div>
                    <label for="max_age" class="block text-sm font-medium text-gray-700 mb-2">
                      Max Age
                    </label>
                    <select name="search[max_age]" id="max_age" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
                      <%= for age <- 18..65 do %>
                        <option value={age} selected={@search_filters.max_age == age}>
                          <%= age %>
                        </option>
                      <% end %>
                    </select>
                  </div>

                  <!-- Relationship Status Filter -->
                  <div>
                    <label for="relationship_status" class="block text-sm font-medium text-gray-700 mb-2">
                      Relationship Status
                    </label>
                    <select name="search[relationship_status]" id="relationship_status" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
                      <option value="" selected={@search_filters.relationship_status == ""}>All Statuses</option>
                      <%= for status <- @relationship_statuses do %>
                        <option value={status} selected={@search_filters.relationship_status == status}>
                          <%= status %>
                        </option>
                      <% end %>
                    </select>
                  </div>

                  <!-- Personality Type Filter -->
                  <div>
                    <label for="personality_type" class="block text-sm font-medium text-gray-700 mb-2">
                      Personality Type
                    </label>
                    <select name="search[personality_type]" id="personality_type" class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
                      <option value="" selected={@search_filters.personality_type == ""}>All Types</option>
                      <%= for type <- @personality_types do %>
                        <option value={type} selected={@search_filters.personality_type == type}>
                          <%= type %>
                        </option>
                      <% end %>
                    </select>
                  </div>
                </div>

                <!-- Results Summary -->
                <div class="pt-4 border-t border-gray-200">
                  <p class="text-sm text-gray-600">
                    Showing <strong><%= length(@friends) %></strong> users
                    within <strong><%= @search_filters.distance %>km</strong>
                    • Ages <strong><%= @search_filters.min_age %>-<%= @search_filters.max_age %></strong>
                    <%= if @search_filters.gender != "" do %>
                      • Gender: <strong><%= @search_filters.gender %></strong>
                    <% end %>
                    <%= if @search_filters.relationship_status != "" do %>
                      • Relationship: <strong><%= @search_filters.relationship_status %></strong>
                    <% end %>
                    <%= if @search_filters.personality_type != "" do %>
                      • Personality: <strong><%= @search_filters.personality_type %></strong>
                    <% end %>
                  </p>
                </div>
              </form>
            </div>

            <!-- Friends List -->
            <div class="xl:space-y-6 space-y-3">
              <%= if Enum.empty?(@friends) do %>
                <div class="bg-white rounded-lg shadow-sm border p-8 text-center">
                  <div class="text-gray-400 text-6xl mb-4">👥</div>
                  <%= if @current_user.latitude && @current_user.longitude do %>
                    <h3 class="text-xl font-semibold text-gray-900 mb-2">No users found</h3>
                    <p class="text-gray-600">
                      No users match your current search criteria within <%= @search_filters.distance %>km.
                      Try adjusting your filters or expanding your search radius.
                    </p>
                  <% else %>
                    <h3 class="text-xl font-semibold text-gray-900 mb-2">Location required</h3>
                    <p class="text-gray-600">
                      <.link navigate="/settings" class="text-indigo-600 underline hover:text-indigo-700">
                        Set your location in settings
                      </.link>
                      to find friends near you.
                    </p>
                  <% end %>
                </div>
              <% else %>
                <%= for friend <- @friends do %>
                  <div class="bg-white rounded-lg shadow-sm border p-6 hover:shadow-md transition-shadow">
                    <div class="flex items-start space-x-4">
                      <!-- Avatar -->
                      <div class="flex-shrink-0">
                        <%= if friend.avatar && friend.avatar != "" do %>
                          <img src={friend.avatar} alt={friend.full_name} class="w-16 h-16 rounded-full object-cover">
                        <% else %>
                          <div class="w-16 h-16 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center">
                            <span class="text-white font-semibold text-xl">
                              <%= String.first(friend.first_name) <> String.first(friend.last_name) %>
                            </span>
                          </div>
                        <% end %>
                      </div>

                      <!-- User Info -->
                      <div class="flex-1 min-w-0">
                        <div class="flex items-start justify-between">
                          <div>
                            <h3 class="text-lg font-semibold text-gray-900 truncate">
                              <%= friend.full_name %>
                            </h3>

                            <%= if friend.bio && friend.bio != "" do %>
                              <p class="text-gray-600 mt-1 line-clamp-2">
                                <%= friend.bio %>
                              </p>
                            <% end %>

                            <!-- User Details -->
                            <div class="flex flex-wrap gap-2 mt-2">
                              <%= if friend.age do %>
                                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                                  🎂 <%= friend.age %> years old
                                </span>
                              <% end %>
                              <%= if friend.height do %>
                                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-orange-100 text-orange-800">
                                  📏 <%= friend.height %> cm
                                </span>
                              <% end %>
                              <%= if friend.weight do %>
                                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                                  ⚖️ <%= friend.weight %> kg
                                </span>
                              <% end %>
                              <%= if friend.bmi do %>
                                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-teal-100 text-teal-800">
                                  📊 BMI <%= friend.bmi %>
                                </span>
                              <% end %>
                              <%= if friend.gender do %>
                                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                  <%= case friend.gender do %>
                                    <% "Male" -> %>👨 Male
                                    <% "Female" -> %>👩 Female
                                    <% "Other" -> %>🧑 Other
                                    <% _ -> %>🧑 <%= friend.gender %>
                                  <% end %>
                                </span>
                              <% end %>
                              <%= if friend.relationship_status do %>
                                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-pink-100 text-pink-800">
                                  💕 <%= friend.relationship_status %>
                                </span>
                              <% end %>
                              <%= if friend.personality_type do %>
                                <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                                  🧠 <%= friend.personality_type %>
                                </span>
                              <% end %>
                            </div>

                            <!-- Location Info -->
                            <%= if friend.city || friend.state do %>
                              <div class="flex items-center text-sm text-gray-500 mt-2">
                                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                                </svg>
                                <%= [friend.city, friend.state] |> Enum.filter(&(&1 && &1 != "")) |> Enum.join(", ") %>
                              </div>
                            <% end %>

                            <!-- Distance -->
                            <%= if Map.has_key?(friend, :distance) && friend.distance && friend.distance != 999999 do %>
                              <div class="flex items-center text-sm font-medium text-indigo-600 mt-1 bg-indigo-50 px-2 py-1 rounded-md inline-flex">
                                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                                </svg>
                                <%= format_distance(friend.distance) %> away
                              </div>
                            <% else %>
                              <div class="flex items-center text-sm text-gray-400 mt-1">
                                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728L5.636 5.636m12.728 12.728L18 18M5.636 5.636L6 6"/>
                                </svg>
                                Location not available
                              </div>
                            <% end %>

                            <!-- Compatibility Bar -->
                            <%= if friend.compatibility && friend.compatibility > 0 do %>
                              <div class="flex items-center space-x-2 mt-2">
                                <span class="text-xs text-gray-500">Compatibility:</span>
                                <div class="w-20 h-2 bg-gray-200 rounded-full overflow-hidden">
                                  <div
                                    class={[
                                      "h-full rounded-full transition-all duration-300",
                                      if(friend.compatibility >= 70, do: "bg-green-500", else: if(friend.compatibility >= 40, do: "bg-yellow-500", else: "bg-red-500"))
                                    ]}
                                    style={"width: #{friend.compatibility}%"}
                                  ></div>
                                </div>
                                <span class={[
                                  "text-xs font-medium",
                                  if(friend.compatibility >= 70, do: "text-green-600", else: if(friend.compatibility >= 40, do: "text-yellow-600", else: "text-red-600"))
                                ]}>
                                  <%= friend.compatibility %>%
                                </span>
                              </div>
                            <% end %>

                            <!-- Stats -->
                            <div class="flex items-center space-x-4 mt-3 text-sm text-gray-500">
                              <span>
                                <strong class="text-gray-900"><%= friend.followers_count || 0 %></strong> followers
                              </span>
                              <span>
                                <strong class="text-gray-900"><%= friend.following_count || 0 %></strong> following
                              </span>
                              <span>
                                <strong class="text-gray-900"><%= friend.kudos_count || 0 %></strong> kudos
                              </span>
                            </div>
                          </div>

                          <!-- Actions -->
                          <div class="flex flex-col space-y-2 ml-4">
                            <%= if friend.is_following do %>
                              <button
                                phx-click="unfollow_user"
                                phx-value-user_id={friend.id}
                                class="bg-gray-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-gray-700 transition-colors">
                                Following
                              </button>
                            <% else %>
                              <button
                                phx-click="follow_user"
                                phx-value-user_id={friend.id}
                                class="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors">
                                Follow
                              </button>
                            <% end %>
                            <button
                              phx-click="message_user"
                              phx-value-user_id={friend.id}
                              class="bg-gray-100 text-gray-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-gray-200 transition-colors">
                              Message
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    """
  end

  # Get users based on search filters
  defp get_friends_by_filters(current_user, filters) do
    today = Date.utc_today()

    # Calculate birthdate range for age filtering
    max_birthdate = Date.add(today, -filters.min_age * 365)
    min_birthdate = Date.add(today, -filters.max_age * 365)

    base_query = from(u in User,
      where: u.id != ^current_user.id,
      select: %{
        id: u.id,
        first_name: u.first_name,
        last_name: u.last_name,
        email: u.email,
        avatar: u.avatar,
        bio: u.bio,
        city: u.city,
        state: u.state,
        country: u.country,
        latitude: u.latitude,
        longitude: u.longitude,
        followers_count: u.followers_count,
        following_count: u.following_count,
        kudos_count: u.kudos_count,
        gender: u.gender,
        relationship_status: u.relationship_status,
        personality_type: u.personality_type,
        birthdate: u.birthdate,
        height: u.height,
        weight: u.weight
      },
      order_by: [desc: u.inserted_at]
    )

    # Apply age filter (using birthdate range)
    query = from(u in base_query,
      where: not is_nil(u.birthdate) and u.birthdate <= ^max_birthdate and u.birthdate >= ^min_birthdate
    )

    # Apply gender filter
    query = if filters.gender != "" do
      from(u in query, where: u.gender == ^filters.gender)
    else
      query
    end

    # Apply relationship status filter
    query = if filters.relationship_status != "" do
      from(u in query, where: u.relationship_status == ^filters.relationship_status)
    else
      query
    end

    # Apply personality type filter
    query = if filters.personality_type != "" do
      from(u in query, where: u.personality_type == ^filters.personality_type)
    else
      query
    end

    query
    |> Repo.all()
    |> Enum.map(fn user ->
      # Calculate age and add to user map
      age = if user.birthdate do
        trunc(Date.diff(today, user.birthdate) / 365.25)
      else
        nil
      end

      # Calculate BMI if height and weight are available
      bmi = if user.height && user.weight do
        height_m = user.height / 100.0
        Float.round(user.weight / (height_m * height_m), 1)
      else
        nil
      end

      # Check if current user is following this user
      is_following = FollowContext.following?(current_user.id, user.id)

      # Calculate compatibility based on tags
      compatibility = Tags.calculate_compatibility(current_user.id, user.id)

      user
      |> Map.put(:full_name, "#{user.first_name} #{user.last_name}")
      |> Map.put(:age, age)
      |> Map.put(:bmi, bmi)
      |> Map.put(:is_following, is_following)
      |> Map.put(:compatibility, compatibility)
    end)
    |> add_distance_calculation(current_user)
    |> filter_by_distance(filters.distance)
  end

  # Calculate distance using Haversine formula and filter by distance
  defp add_distance_calculation(users, current_user) do
    if current_user.latitude && current_user.longitude do
      users
      |> Enum.map(fn user ->
        if user.latitude && user.longitude do
          distance = haversine_distance(
            current_user.latitude, current_user.longitude,
            user.latitude, user.longitude
          )
          Map.put(user, :distance, distance)
        else
          # For users without location, set a very high distance so they appear last
          Map.put(user, :distance, 999999)
        end
      end)
      |> Enum.sort_by(&Map.get(&1, :distance, 999999))
    else
      # If current user has no location, just return users without distance calculation
      users
      |> Enum.map(&Map.put(&1, :distance, nil))
    end
  end

  # Filter users by maximum distance in kilometers
  defp filter_by_distance(users, max_distance_km) do
    users
    |> Enum.filter(fn user ->
      case Map.get(user, :distance) do
        nil -> false # Exclude users without location data
        distance when is_number(distance) -> distance <= max_distance_km
        _ -> false
      end
    end)
  end

  # Haversine formula for calculating distance between two points
  defp haversine_distance(lat1, lon1, lat2, lon2) do
    rad_per_deg = :math.pi() / 180
    rlat1 = lat1 * rad_per_deg
    rlat2 = lat2 * rad_per_deg
    delta_lat = (lat2 - lat1) * rad_per_deg
    delta_lon = (lon2 - lon1) * rad_per_deg

    a = :math.sin(delta_lat / 2) * :math.sin(delta_lat / 2) +
        :math.cos(rlat1) * :math.cos(rlat2) *
        :math.sin(delta_lon / 2) * :math.sin(delta_lon / 2)
    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    # Earth's radius in kilometers
    6371 * c
  end

  # Format distance in a human-readable way
  defp format_distance(distance_km) when is_number(distance_km) and distance_km != 999999 do
    cond do
      distance_km < 0.1 ->
        "< 100m"
      distance_km < 1 ->
        "#{round(distance_km * 1000)}m"
      distance_km < 10 ->
        "#{Float.round(distance_km, 1)}km"
      true ->
        "#{round(distance_km)}km"
    end
  end

  defp format_distance(_), do: "unknown"

  # Helper function to create full address from user data
  defp full_address(user) do
    [user.address, user.city, user.state, user.postal_code, user.country]
    |> Enum.filter(&(&1 && String.trim(&1) != ""))
    |> Enum.join(", ")
  end
end
