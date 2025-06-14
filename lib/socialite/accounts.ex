defmodule Socialite.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.Accounts.User

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user by email.
  """
  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    result = %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()

    case result do
      {:ok, user} ->
        # Automatically make new users follow Bogumił Gargula
        official_user = Repo.get_by(User, email: "bogumil@emanuel.network")
        if official_user && user.id != official_user.id do
          case Socialite.FollowContext.follow_user(user.id, official_user.id) do
            {:ok, _follow} ->
              IO.puts("New user #{user.first_name} #{user.last_name} is now following Bogumił Gargula")
            {:error, _} ->
              IO.puts("Failed to auto-follow Bogumił Gargula for #{user.first_name} #{user.last_name}")
          end
        end
        {:ok, user}
      error -> error
    end
  end

  @doc """
  Authenticates a user by email and password.
  """
  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && User.verify_password(user, password) ->
        {:ok, user}

      user ->
        {:error, :invalid_password}

      true ->
        # Perform a dummy check to prevent timing attacks
        Bcrypt.no_user_verify()
        {:error, :not_found}
    end
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a user's location.
  """
  def update_user_location(%User{} = user, attrs) do
    user
    |> User.location_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates a user's profile including location.
  """
  def update_user_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Searches for users by first name, last name, or email, excluding the current user.
  """
  def search_users(query, current_user_id) do
    search_term = "%#{String.downcase(query)}%"

    from(u in User,
      where: u.id != ^current_user_id and
             (fragment("LOWER(?)", u.first_name) |> like(^search_term) or
              fragment("LOWER(?)", u.last_name) |> like(^search_term) or
              fragment("LOWER(?)", u.email) |> like(^search_term)),
      limit: 10,
      select: [:id, :first_name, :last_name, :avatar, :latitude, :longitude]
    )
    |> Repo.all()
  end

  @doc """
  Adds distance information to users based on current user location.
  """
  def add_distance_to_users(users, user_lat, user_lng) when not is_nil(user_lat) and not is_nil(user_lng) do
    Enum.map(users, fn user ->
      distance = calculate_distance(user_lat, user_lng, user.latitude, user.longitude)
      Map.put(user, :distance_km, distance)
    end)
  end

  def add_distance_to_users(users, _, _) do
    # Always add distance_km field, even if nil, to avoid KeyError
    Enum.map(users, fn user ->
      Map.put(user, :distance_km, nil)
    end)
  end

  @doc """
  Finds users within a certain distance (in kilometers) from a given point.
  """
  def find_nearby_users(latitude, longitude, radius_km \\ 50, current_user_id \\ nil) do
    query = from u in User,
      where: not is_nil(u.latitude) and not is_nil(u.longitude),
      where: fragment("ST_DWithin(location_point, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ?)",
        ^longitude, ^latitude, ^(radius_km * 1000)),
      order_by: fragment("ST_Distance(location_point, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography)",
        ^longitude, ^latitude),
      select: [:id, :first_name, :last_name, :email, :avatar, :latitude, :longitude, :city, :state, :country]

    query = if current_user_id do
      where(query, [u], u.id != ^current_user_id)
    else
      query
    end

    Repo.all(query)
  end

  @doc """
  Finds users within a certain distance from the current user.
  """
  def find_nearby_users_for_user(%User{latitude: lat, longitude: lng} = user, radius_km) when not is_nil(lat) and not is_nil(lng) do
    find_nearby_users(lat, lng, radius_km, user.id)
  end

  def find_nearby_users_for_user(_user, _radius_km), do: []

  @doc """
  Gets the distance between two users in kilometers.
  """
  def distance_between_users(%User{latitude: lat1, longitude: lng1}, %User{latitude: lat2, longitude: lng2})
      when not is_nil(lat1) and not is_nil(lng1) and not is_nil(lat2) and not is_nil(lng2) do

    query = from u in User,
      where: u.id == 1,  # Dummy condition since we just need to run the distance calculation
      select: fragment("ST_Distance(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography) / 1000",
        ^lng1, ^lat1, ^lng2, ^lat2)

    case Repo.one(query) do
      nil -> nil
      distance -> Float.round(distance, 2)
    end
  end

  def distance_between_users(_, _), do: nil

  @doc """
  Gets users with location data.
  """
  def list_users_with_location do
    from(u in User,
      where: not is_nil(u.latitude) and not is_nil(u.longitude),
      select: [:id, :first_name, :last_name, :email, :avatar, :latitude, :longitude, :city, :state, :country]
    )
    |> Repo.all()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  def change_user_profile(%User{} = user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

  def calculate_distance(lat1, lon1, lat2, lon2) when not is_nil(lat1) and not is_nil(lon1) and not is_nil(lat2) and not is_nil(lon2) do
    # Haversine formula to calculate distance between two points
    r = 6371 # Earth's radius in kilometers

    lat1_rad = :math.pi * lat1 / 180
    lat2_rad = :math.pi * lat2 / 180
    delta_lat = :math.pi * (lat2 - lat1) / 180
    delta_lon = :math.pi * (lon2 - lon1) / 180

    a = :math.sin(delta_lat / 2) * :math.sin(delta_lat / 2) +
        :math.cos(lat1_rad) * :math.cos(lat2_rad) *
        :math.sin(delta_lon / 2) * :math.sin(delta_lon / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
    Float.round(r * c, 1)
  end

  def calculate_distance(_, _, _, _), do: nil

  def find_users_within_radius(%User{} = user, radius_km) when is_number(radius_km) do
    if user.latitude && user.longitude do
      User
      |> where([u], u.id != ^user.id)
      |> where([u], not is_nil(u.latitude) and not is_nil(u.longitude))
      |> Repo.all()
      |> Enum.filter(fn other_user ->
        distance = calculate_distance(
          user.latitude,
          user.longitude,
          other_user.latitude,
          other_user.longitude
        )
        distance <= radius_km
      end)
    else
      []
    end
  end

  # User Pictures functions

  @doc """
  Creates a user picture.
  """
  def create_user_picture(attrs \\ %{}) do
    %Socialite.UserPicture{}
    |> Socialite.UserPicture.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets all pictures for a user.
  """
  def list_user_pictures(user_id) do
    from(up in Socialite.UserPicture,
      where: up.user_id == ^user_id,
      order_by: [asc: up.order, desc: up.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Sets a picture as the user's avatar.
  """
  def set_avatar_picture(user_id, picture_id) do
    Repo.transaction(fn ->
      # First, unset any existing avatar
      from(up in Socialite.UserPicture,
        where: up.user_id == ^user_id and up.is_avatar == true
      )
      |> Repo.update_all(set: [is_avatar: false])

      # Then set the new avatar
      picture = Repo.get!(Socialite.UserPicture, picture_id)
      if picture.user_id == user_id do
        picture
        |> Socialite.UserPicture.changeset(%{is_avatar: true})
        |> Repo.update!()

        # Update the user's avatar field with the picture URL
        user = Repo.get!(User, user_id)
        user
        |> User.profile_changeset(%{avatar: picture.url})
        |> Repo.update!()
      else
        Repo.rollback("Picture does not belong to user")
      end
    end)
  end

  @doc """
  Deletes a user picture.
  """
  def delete_user_picture(user_id, picture_id) do
    picture = Repo.get!(Socialite.UserPicture, picture_id)
    if picture.user_id == user_id do
      Repo.delete(picture)
    else
      {:error, "Picture does not belong to user"}
    end
  end

  @doc """
  Updates the order of user pictures.
  """
  def update_picture_order(user_id, picture_orders) do
    Repo.transaction(fn ->
      Enum.each(picture_orders, fn {picture_id, order} ->
        picture = Repo.get!(Socialite.UserPicture, picture_id)
        if picture.user_id == user_id do
          picture
          |> Socialite.UserPicture.changeset(%{order: order})
          |> Repo.update!()
        end
      end)
    end)
  end

  @doc """
  Gets the count of pictures for a user.
  """
  def count_user_pictures(user_id) do
    from(up in Socialite.UserPicture,
      where: up.user_id == ^user_id,
      select: count(up.id)
    )
    |> Repo.one()
  end
end
