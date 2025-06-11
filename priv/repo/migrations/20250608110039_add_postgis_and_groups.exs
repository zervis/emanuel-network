defmodule Socialite.Repo.Migrations.AddPostgisAndGroups do
  use Ecto.Migration

  def up do
    # Create groups table
    create table(:groups) do
      add :name, :string, null: false
      add :description, :text
      add :lat, :float
      add :lng, :float
      add :address, :string
      add :creator_id, references(:users, on_delete: :delete_all), null: false
      add :members_count, :integer, default: 0
      add :is_public, :boolean, default: true
      add :avatar, :string
      add :banner, :string

      timestamps()
    end

    create index(:groups, [:creator_id])
    create index(:groups, [:lat, :lng])

    # Create group_members table
    create table(:group_members) do
      add :role, :string, default: "member"
      add :joined_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :group_id, references(:groups, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:group_members, [:user_id])
    create index(:group_members, [:group_id])
    create unique_index(:group_members, [:user_id, :group_id])

    # Create group_posts table
    create table(:group_posts) do
      add :content, :text, null: false
      add :image_url, :string
      add :likes_count, :integer, default: 0
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :group_id, references(:groups, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:group_posts, [:user_id])
    create index(:group_posts, [:group_id])
    create index(:group_posts, [:inserted_at])

    # Create group_events table
    create table(:group_events) do
      add :title, :string, null: false
      add :description, :text
      add :lat, :float
      add :lng, :float
      add :address, :string
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime
      add :max_attendees, :integer
      add :attendees_count, :integer, default: 0
      add :is_online, :boolean, default: false
      add :meeting_url, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :group_id, references(:groups, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:group_events, [:user_id])
    create index(:group_events, [:group_id])
    create index(:group_events, [:start_time])
    create index(:group_events, [:lat, :lng])

    # Create event_attendees table
    create table(:event_attendees) do
      add :status, :string, default: "attending"
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :event_id, references(:group_events, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:event_attendees, [:user_id])
    create index(:event_attendees, [:event_id])
    create unique_index(:event_attendees, [:user_id, :event_id])

    # Create group_post_comments table
    create table(:group_post_comments) do
      add :content, :text, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :group_post_id, references(:group_posts, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:group_post_comments, [:user_id])
    create index(:group_post_comments, [:group_post_id])
  end

  def down do
    drop table(:group_post_comments)
    drop table(:event_attendees)
    drop table(:group_events)
    drop table(:group_posts)
    drop table(:group_members)
    drop table(:groups)
  end
end
