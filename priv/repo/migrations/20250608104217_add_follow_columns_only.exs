defmodule Socialite.Repo.Migrations.AddFollowColumnsOnly do
  use Ecto.Migration

  def change do
    # Create follows table for user following functionality
    create table(:follows) do
      add :follower_id, references(:users, on_delete: :delete_all), null: false
      add :followed_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:follows, [:follower_id])
    create index(:follows, [:followed_id])
    # Users can only follow another user once
    create unique_index(:follows, [:follower_id, :followed_id])

    # Add followers_count and following_count to users for efficiency
    alter table(:users) do
      add :followers_count, :integer, default: 0
      add :following_count, :integer, default: 0
    end

    # Remove the unique constraint from kudos table to allow multiple kudos transactions
    drop_if_exists unique_index(:kudos, [:giver_id, :receiver_id])
  end
end
