defmodule Socialite.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :type, :string  # "follow", "post_like", "post_comment", etc.
    field :message, :string
    field :read_at, :utc_datetime
    field :data, :map  # Additional data like post_id, etc.

    belongs_to :user, Socialite.User  # The user receiving the notification
    belongs_to :actor, Socialite.User  # The user who triggered the notification

    timestamps()
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :message, :read_at, :data, :user_id, :actor_id])
    |> validate_required([:type, :message, :user_id, :actor_id])
    |> validate_inclusion(:type, ["follow", "post_like", "post_comment", "kudos_received"])
  end

  def mark_as_read(notification) do
    changeset(notification, %{read_at: DateTime.utc_now()})
  end
end
