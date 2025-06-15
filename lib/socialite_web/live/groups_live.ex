defmodule SocialiteWeb.GroupsLive do
  use SocialiteWeb, :live_view

  alias Socialite.Groups

  @distance_options [
    {5, "5 km"},
    {10, "10 km"},
    {25, "25 km"},
    {50, "50 km"},
    {100, "100 km"}
  ]

  @impl true
  def mount(_params, session, socket) do
    current_user_id = session["current_user_id"]

    # Add safety check for current_user_id
    if current_user_id do
      # Use Repo.get instead of get_user! to avoid exceptions
      case Socialite.Repo.get(Socialite.Accounts.User, current_user_id) do
        %Socialite.Accounts.User{} = current_user ->
          # Get user groups and add distance information
          user_groups = Groups.get_user_groups(current_user_id)
          user_groups_with_distance = Groups.add_distance_to_groups(user_groups, current_user.latitude, current_user.longitude)

          # Automatically load nearby groups if user has location
          {nearby_groups, search_location} = if current_user.latitude && current_user.longitude do
            distance_meters = 10 * 1000  # Default 10km
            nearby = Groups.find_nearby_groups_within_distance(current_user.latitude, current_user.longitude, distance_meters)
            nearby_with_distance = Groups.add_distance_to_groups(nearby, current_user.latitude, current_user.longitude)
            sorted_nearby = Enum.sort_by(nearby_with_distance, fn group -> group.distance_km || 999999 end)
            {sorted_nearby, %{lat: current_user.latitude, lng: current_user.longitude}}
          else
            {[], nil}
          end

          {:ok,
           socket
           |> assign(:current_user, current_user)
           |> assign(:user_groups, user_groups_with_distance)
           |> assign(:nearby_groups, nearby_groups)
           |> assign(:search_location, search_location)
           |> assign(:selected_distance, 10)
           |> assign(:distance_options, @distance_options)
           |> assign(:loading, false)
}

        nil ->
          {:ok, redirect(socket, to: "/")}
      end
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_distance", %{"distance" => distance_str}, socket) do
    distance = String.to_integer(distance_str)

    # Use user's profile location if available
    socket = if socket.assigns.current_user.latitude && socket.assigns.current_user.longitude do
      lat = socket.assigns.current_user.latitude
      lng = socket.assigns.current_user.longitude
      update_nearby_groups(socket, lat, lng, distance)
    else
      assign(socket, :selected_distance, distance)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("join_group", %{"group_id" => group_id}, socket) do
    group_id = String.to_integer(group_id)

    case Groups.join_group(socket.assigns.current_user.id, group_id) do
      {:ok, _membership} ->
        # Refresh user groups with distance calculations
        user_groups = Groups.get_user_groups(socket.assigns.current_user.id)
        user_groups_with_distance = Groups.add_distance_to_groups(user_groups, socket.assigns.current_user.latitude, socket.assigns.current_user.longitude)

        {:noreply,
         socket
         |> put_flash(:info, "Successfully joined the group!")
         |> assign(:user_groups, user_groups_with_distance)}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to join group")}
    end
  end

  @impl true
  def handle_event("leave_group", %{"group_id" => group_id}, socket) do
    group_id = String.to_integer(group_id)

    case Groups.leave_group(socket.assigns.current_user.id, group_id) do
      {:ok, _} ->
        # Refresh user groups with distance calculations
        user_groups = Groups.get_user_groups(socket.assigns.current_user.id)
        user_groups_with_distance = Groups.add_distance_to_groups(user_groups, socket.assigns.current_user.latitude, socket.assigns.current_user.longitude)

        {:noreply,
         socket
         |> put_flash(:info, "Left the group successfully!")
         |> assign(:user_groups, user_groups_with_distance)}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to leave group")}
    end
  end



  defp update_nearby_groups(socket, lat, lng, distance_km) do
    # Convert km to meters for the Groups function
    distance_meters = distance_km * 1000

    nearby_groups = Groups.find_nearby_groups_within_distance(lat, lng, distance_meters)
    nearby_groups_with_distance = Groups.add_distance_to_groups(nearby_groups, lat, lng)

    # Sort by distance (closest first)
    sorted_groups = Enum.sort_by(nearby_groups_with_distance, fn group ->
      group.distance_km || 999999
    end)

    socket
    |> assign(:nearby_groups, sorted_groups)
    |> assign(:search_location, %{lat: lat, lng: lng})
    |> assign(:selected_distance, distance_km)
  end

  defp is_member?(user_groups, group_id) do
    Enum.any?(user_groups, fn g -> g.id == group_id end)
  end
end
