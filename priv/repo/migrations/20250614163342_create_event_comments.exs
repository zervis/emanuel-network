defmodule Socialite.Repo.Migrations.CreateEventComments do
  use Ecto.Migration

  def change do
    create table(:event_comments) do
      add :content, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :event_id, references(:group_events, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:event_comments, [:user_id])
    create index(:event_comments, [:event_id])
    create index(:event_comments, [:inserted_at])
  end
end
