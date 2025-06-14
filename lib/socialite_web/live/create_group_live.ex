defmodule SocialiteWeb.CreateGroupLive do
  use SocialiteWeb, :live_view

  alias Socialite.Groups
  alias Socialite.Group

    def mount(_params, session, socket) do
    current_user_id = session["current_user_id"]

    if current_user_id do
      current_user = Socialite.Accounts.get_user!(current_user_id)

      # Pre-populate group with user's location data
      initial_params = %{
        "creator_id" => current_user.id
      }

      # Add location data if user has it
      initial_params = if current_user.latitude != nil and current_user.longitude != nil do
        location_data = %{
          "lat" => current_user.latitude,
          "lng" => current_user.longitude
        }

        # Add address if available
        location_data = if current_user.address && String.trim(current_user.address) != "" do
          Map.put(location_data, "address", current_user.address)
        else
          location_data
        end

        Map.merge(initial_params, location_data)
      else
        initial_params
      end

      changeset = Groups.change_group(%Group{}, initial_params)

      socket =
        socket
        |> assign(:current_user, current_user)
        |> assign(:group_changeset, changeset)
        |> assign(:form, to_form(changeset))

      {:ok, socket}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

    def handle_event("validate_group", %{"group" => group_params}, socket) do
    # Add the creator_id to the params during validation
    group_params_with_creator = Map.put(group_params, "creator_id", socket.assigns.current_user.id)

    changeset =
      %Group{}
      |> Groups.change_group(group_params_with_creator)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:group_changeset, changeset)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("create_group", %{"group" => group_params}, socket) do
    current_user = socket.assigns.current_user

    # Add creator_id to the group params
    group_attrs = Map.put(group_params, "creator_id", current_user.id)

    case Groups.create_group(group_attrs) do
      {:ok, group} ->
        {:noreply,
         socket
         |> put_flash(:info, "Group created successfully!")
         |> redirect(to: ~p"/groups/#{group.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:group_changeset, changeset)
         |> assign(:form, to_form(changeset))}
    end
  end

  def handle_event("set_location", %{"latitude" => lat, "longitude" => lng}, socket) do
    # Update the form with current location
    current_params = socket.assigns.group_changeset.params || %{}
    updated_params = Map.merge(current_params, %{
      "lat" => String.to_float(lat),
      "lng" => String.to_float(lng)
    })

    changeset =
      %Group{}
      |> Groups.change_group(updated_params)

    {:noreply,
     socket
     |> assign(:group_changeset, changeset)
     |> assign(:form, to_form(changeset))
     |> put_flash(:info, "Location updated with current coordinates!")}
  end
end
