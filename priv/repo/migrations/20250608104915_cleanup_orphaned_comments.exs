defmodule Socialite.Repo.Migrations.CleanupOrphanedComments do
  use Ecto.Migration

  def change do
    # Delete comments that don't have a corresponding post
    execute "DELETE FROM comments WHERE post_id NOT IN (SELECT id FROM posts)"
  end
end
