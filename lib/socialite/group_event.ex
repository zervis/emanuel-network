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
    has_many :event_comments, Socialite.EventComment, foreign_key: :event_id

    timestamps(type: :naive_datetime)
  end

  @doc false
  def changeset(group_event, attrs) do
    group_event
    |> cast(attrs, [:title, :description, :address, :start_time, :end_time, :max_attendees,
                    :is_online, :meeting_url, :user_id, :group_id, :lat, :lng])
    |> convert_local_datetime_to_utc(:start_time)
    |> convert_local_datetime_to_utc(:end_time)
    |> validate_required([:title, :start_time, :user_id, :group_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:description, max: 1000)
  end

  defp convert_local_datetime_to_utc(changeset, field) do
    case get_change(changeset, field) do
      %NaiveDateTime{} = naive_dt ->
        # Convert naive datetime to UTC (assuming local timezone)
        utc_dt = DateTime.from_naive!(naive_dt, "Etc/UTC")
        put_change(changeset, field, utc_dt)

      %DateTime{} = dt ->
        # Already a DateTime, just use it as is
        put_change(changeset, field, dt)

      datetime_string when is_binary(datetime_string) and datetime_string != "" ->
        # Handle string input from HTML datetime-local input
        # HTML datetime-local format: "2023-12-25T14:30"
        case NaiveDateTime.from_iso8601(datetime_string <> ":00") do
          {:ok, naive_dt} ->
            utc_dt = DateTime.from_naive!(naive_dt, "Etc/UTC")
            put_change(changeset, field, utc_dt)
          {:error, _} ->
            # Try without adding seconds
            case NaiveDateTime.from_iso8601(datetime_string) do
              {:ok, naive_dt} ->
                utc_dt = DateTime.from_naive!(naive_dt, "Etc/UTC")
                put_change(changeset, field, utc_dt)
              {:error, _} ->
                add_error(changeset, field, "is not a valid datetime")
            end
        end

      nil ->
        changeset

      "" ->
        changeset

      _ ->
        changeset
    end
  rescue
    ArgumentError ->
      add_error(changeset, field, "is not a valid datetime")
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
