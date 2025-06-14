defmodule Socialite.EventComment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "event_comments" do
    field :content, :string

    belongs_to :user, Socialite.User
    belongs_to :event, Socialite.GroupEvent

    timestamps()
  end

  @doc false
  def changeset(event_comment, attrs) do
    event_comment
    |> cast(attrs, [:content, :user_id, :event_id])
    |> validate_required([:content, :user_id, :event_id])
    |> validate_length(:content, min: 1, max: 1000)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:event_id)
  end
end
