defmodule Socialite.EventAttendee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "event_attendees" do
    field :status, :string, default: "attending"

    belongs_to :user, Socialite.User
    belongs_to :event, Socialite.GroupEvent, foreign_key: :event_id

    timestamps()
  end

  @doc false
  def changeset(event_attendee, attrs) do
    event_attendee
    |> cast(attrs, [:status, :user_id, :event_id])
    |> validate_required([:user_id, :event_id])
    |> validate_inclusion(:status, ["attending", "maybe", "not_attending"])
    |> unique_constraint([:user_id, :event_id])
  end
end
