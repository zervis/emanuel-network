defmodule Socialite.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :content, :string
    field :read_at, :naive_datetime
    field :message_type, :string, default: "text"

    belongs_to :sender, Socialite.Accounts.User, foreign_key: :sender_id
    belongs_to :recipient, Socialite.Accounts.User, foreign_key: :recipient_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :message_type, :sender_id, :recipient_id])
    |> validate_required([:content, :sender_id, :recipient_id])
    |> validate_length(:content, min: 1, max: 1000)
    |> validate_inclusion(:message_type, ["text", "image", "file"])
    |> foreign_key_constraint(:sender_id)
    |> foreign_key_constraint(:recipient_id)
  end

  def mark_as_read(message) do
    message
    |> change(read_at: NaiveDateTime.utc_now())
  end
end
