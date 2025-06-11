defmodule Socialite.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :content, :string
    field :read_at, :utc_datetime

    belongs_to :sender, Socialite.User
    belongs_to :recipient, Socialite.User

    timestamps(type: :naive_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :sender_id, :recipient_id, :read_at])
    |> validate_required([:content, :sender_id, :recipient_id])
    |> validate_length(:content, min: 1, max: 1000)
    |> foreign_key_constraint(:sender_id)
    |> foreign_key_constraint(:recipient_id)
  end

  def mark_as_read(message) do
    message
    |> change(%{read_at: DateTime.utc_now() |> DateTime.truncate(:second)})
  end
end
