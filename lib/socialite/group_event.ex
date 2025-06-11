defmodule Socialite.GroupEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "group_events" do
    field :title, :string
    field :description, :string
    field :lat, :float
    field :lng, :float
    field :address, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :max_attendees, :integer
    field :attendees_count, :integer, default: 0
    field :is_online, :boolean, default: false
    field :meeting_url, :string

    belongs_to :user, Socialite.User
    belongs_to :group, Socialite.Group
    has_many :event_attendees, Socialite.EventAttendee, foreign_key: :event_id

    timestamps(type: :naive_datetime)
  end

  @doc false
  def changeset(group_event, attrs) do
    group_event
    |> cast(attrs, [:title, :description, :address, :start_time, :end_time, :max_attendees,
                    :is_online, :meeting_url, :user_id, :group_id, :lat, :lng])
    |> validate_required([:title, :start_time, :user_id, :group_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:description, max: 1000)
    |> validate_number(:max_attendees, greater_than: 0)
    |> validate_number(:lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:lng, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_start_before_end()
  end

  defp validate_start_before_end(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && DateTime.compare(start_time, end_time) != :lt do
      add_error(changeset, :end_time, "must be after start time")
    else
      changeset
    end
  end


end
