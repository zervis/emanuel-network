defmodule Socialite.Groups do
  @moduledoc """
  The Groups context for managing groups, group membership, posts, and events.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.{Group, GroupMember, GroupPost, GroupEvent, EventAttendee, GroupPostComment}

  ## Groups

  @doc """
  Returns the list of groups.
  """
  def list_groups do
    Repo.all(
      from g in Group,
        preload: [:creator, :group_members]
    )
  end

  @doc """
  Finds groups near a given location using Haversine formula.
  Radius is in meters.
  """
  def find_nearby_groups(lat, lng, radius_meters \\ 10_000) do
    # Convert radius from meters to degrees (approximate)
    radius_degrees = radius_meters / 111_320.0

    query = from g in Group,
      where: not is_nil(g.lat) and not is_nil(g.lng),
      where: g.lat >= ^(lat - radius_degrees) and g.lat <= ^(lat + radius_degrees),
      where: g.lng >= ^(lng - radius_degrees) and g.lng <= ^(lng + radius_degrees),
      preload: [:creator, :group_members]

    groups = Repo.all(query)

    # Filter by actual distance using Haversine formula
    Enum.filter(groups, fn group ->
      distance = haversine_distance(lat, lng, group.lat, group.lng)
      distance <= radius_meters
    end)
    |> Enum.sort_by(fn group ->
      haversine_distance(lat, lng, group.lat, group.lng)
    end)
  end

  # Haversine formula to calculate distance between two points
  defp haversine_distance(lat1, lng1, lat2, lng2) do
    r = 6_371_000  # Earth's radius in meters

    dlat = :math.pi() * (lat2 - lat1) / 180
    dlng = :math.pi() * (lng2 - lng1) / 180

    a = :math.sin(dlat / 2) * :math.sin(dlat / 2) +
        :math.cos(:math.pi() * lat1 / 180) * :math.cos(:math.pi() * lat2 / 180) *
        :math.sin(dlng / 2) * :math.sin(dlng / 2)

    c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))

    r * c
  end

  @doc """
  Gets a single group.
  """
  def get_group!(id) do
    Repo.get!(Group, id)
    |> Repo.preload([:creator, :group_members, :group_posts, :group_events])
  end

  @doc """
  Creates a group.
  """
  def create_group(attrs \\ %{}) do
    %Group{}
    |> Group.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, group} ->
        # Automatically make creator an admin member
        {:ok, _membership} = create_group_membership(group.creator_id, group.id, "admin")
        update_group_member_count(group.id)
        {:ok, Repo.preload(group, [:creator, :group_members])}
      error ->
        error
    end
  end

  @doc """
  Updates a group.
  """
  def update_group(%Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a group.
  """
  def delete_group(%Group{} = group) do
    Repo.delete(group)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.
  """
  def change_group(%Group{} = group, attrs \\ %{}) do
    Group.changeset(group, attrs)
  end

  ## Group Membership

  @doc """
  Joins a user to a group.
  """
  def join_group(user_id, group_id) do
    case create_group_membership(user_id, group_id, "member") do
      {:ok, membership} ->
        update_group_member_count(group_id)
        {:ok, membership}
      error ->
        error
    end
  end

  @doc """
  Leaves a group.
  """
  def leave_group(user_id, group_id) do
    membership = Repo.get_by(GroupMember, user_id: user_id, group_id: group_id)

    case membership do
      nil -> {:error, :not_member}
      member ->
        result = Repo.delete(member)
        update_group_member_count(group_id)
        result
    end
  end

  @doc """
  Checks if a user is a member of a group.
  """
  def member?(user_id, group_id) do
    Repo.exists?(from gm in GroupMember, where: gm.user_id == ^user_id and gm.group_id == ^group_id)
  end

  @doc """
  Gets user's role in a group.
  """
  def get_user_role(user_id, group_id) do
    case Repo.get_by(GroupMember, user_id: user_id, group_id: group_id) do
      nil -> nil
      %GroupMember{role: role} -> role
    end
  end

  @doc """
  Gets groups that a user is a member of.
  """
  def get_user_groups(user_id) do
    Repo.all(
      from g in Group,
        join: gm in GroupMember, on: gm.group_id == g.id,
        where: gm.user_id == ^user_id,
        preload: [:creator]
    )
  end

  defp create_group_membership(user_id, group_id, role) do
    %GroupMember{}
    |> GroupMember.changeset(%{user_id: user_id, group_id: group_id, role: role})
    |> Repo.insert()
  end

  defp update_group_member_count(group_id) do
    count = Repo.aggregate(
      from(gm in GroupMember, where: gm.group_id == ^group_id),
      :count
    )

    Repo.update_all(
      from(g in Group, where: g.id == ^group_id),
      set: [members_count: count]
    )
  end

  ## Group Posts

  @doc """
  Gets posts for a group.
  """
  def list_group_posts(group_id) do
    Repo.all(
      from gp in GroupPost,
        where: gp.group_id == ^group_id,
        order_by: [desc: gp.inserted_at],
        preload: [:user, :group, group_post_comments: [:user]]
    )
  end

  @doc """
  Creates a group post.
  """
  def create_group_post(attrs \\ %{}) do
    %GroupPost{}
    |> GroupPost.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets posts from all groups that a user is a member of.
  """
  def get_feed_group_posts(user_id) do
    Repo.all(
      from gp in GroupPost,
        join: gm in GroupMember, on: gm.group_id == gp.group_id,
        where: gm.user_id == ^user_id,
        order_by: [desc: gp.inserted_at],
        preload: [:user, :group, group_post_comments: [:user]]
    )
  end

  ## Group Events

  @doc """
  Gets events for a group.
  """
  def list_group_events(group_id) do
    Repo.all(
      from ge in GroupEvent,
        where: ge.group_id == ^group_id,
        order_by: [asc: ge.start_time],
        preload: [:user, :group, :event_attendees]
    )
  end

  @doc """
  Gets upcoming events from all groups that a user is a member of.
  """
  def get_upcoming_group_events(user_id) do
    now = DateTime.utc_now()

    Repo.all(
      from ge in GroupEvent,
        join: gm in GroupMember, on: gm.group_id == ge.group_id,
        where: gm.user_id == ^user_id and ge.start_time > ^now,
        order_by: [asc: ge.start_time],
        preload: [:user, :group]
    )
  end

  @doc """
  Creates a group event.
  """
  def create_group_event(attrs \\ %{}) do
    %GroupEvent{}
    |> GroupEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a single group event.
  """
  def get_group_event!(id) do
    Repo.get!(GroupEvent, id)
    |> Repo.preload([:user, :group, :event_attendees])
  end

  @doc """
  Joins an event (RSVP).
  """
  def join_event(user_id, event_id, status \\ "attending") do
    result = %EventAttendee{}
    |> EventAttendee.changeset(%{user_id: user_id, event_id: event_id, status: status})
    |> Repo.insert(
      on_conflict: {:replace, [:status, :updated_at]},
      conflict_target: [:user_id, :event_id]
    )

    case result do
      {:ok, attendee} ->
        update_event_attendee_count(event_id)
        {:ok, attendee}
      error ->
        error
    end
  end

  @doc """
  Leaves an event.
  """
  def leave_event(user_id, event_id) do
    attendee = Repo.get_by(EventAttendee, user_id: user_id, event_id: event_id)

    case attendee do
      nil -> {:error, :not_attending}
      attendee ->
        result = Repo.delete(attendee)
        update_event_attendee_count(event_id)
        result
    end
  end

  defp update_event_attendee_count(event_id) do
    count = Repo.aggregate(
      from(ea in EventAttendee, where: ea.event_id == ^event_id and ea.status == "attending"),
      :count
    )

    Repo.update_all(
      from(ge in GroupEvent, where: ge.id == ^event_id),
      set: [attendees_count: count]
    )
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group event changes.
  """
  def change_group_event(%GroupEvent{} = group_event, attrs \\ %{}) do
    GroupEvent.changeset(group_event, attrs)
  end

  ## Group Post Comments

  @doc """
  Creates a comment on a group post.
  """
  def create_group_post_comment(attrs \\ %{}) do
    %GroupPostComment{}
    |> GroupPostComment.changeset(attrs)
    |> Repo.insert()
  end
end
