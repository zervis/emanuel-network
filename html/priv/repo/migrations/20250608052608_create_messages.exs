defmodule Socialite.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :read_at, :naive_datetime
      add :message_type, :string, default: "text"
      add :sender_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :recipient_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:sender_id])
    create index(:messages, [:recipient_id])
    create index(:messages, [:inserted_at])
    create index(:messages, [:read_at])
  end
end
