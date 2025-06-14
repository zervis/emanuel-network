defmodule Socialite.Repo.Migrations.CreateTagsSystem do
  use Ecto.Migration

  def change do
    # Create tag categories table
    create table(:tag_categories) do
      add :name, :string, null: false
      add :description, :text
      add :icon, :string
      add :color, :string
      add :order_index, :integer, default: 0

      timestamps()
    end

    create unique_index(:tag_categories, [:name])

    # Create tags table
    create table(:tags) do
      add :name, :string, null: false
      add :description, :text
      add :category_id, references(:tag_categories, on_delete: :delete_all), null: false
      add :usage_count, :integer, default: 0
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:tags, [:name, :category_id])
    create index(:tags, [:category_id])
    create index(:tags, [:usage_count])

    # Create user_tags join table
    create table(:user_tags) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
      add :proficiency_level, :integer, default: 1 # 1-5 scale for how much they like/know this
      add :is_public, :boolean, default: true

      timestamps()
    end

    create unique_index(:user_tags, [:user_id, :tag_id])
    create index(:user_tags, [:user_id])
    create index(:user_tags, [:tag_id])

    # Insert default categories
    execute """
    INSERT INTO tag_categories (name, description, icon, color, order_index, inserted_at, updated_at) VALUES
    ('movies', 'Films, TV shows, and cinema', '🎬', '#e74c3c', 1, NOW(), NOW()),
    ('music', 'Musical genres, artists, and instruments', '🎵', '#9b59b6', 2, NOW(), NOW()),
    ('games', 'Video games, board games, and sports', '🎮', '#3498db', 3, NOW(), NOW()),
    ('books', 'Literature, genres, and authors', '📚', '#27ae60', 4, NOW(), NOW()),
    ('activities', 'Hobbies, sports, and interests', '🏃', '#f39c12', 5, NOW(), NOW()),
    ('food', 'Cuisines, cooking, and dining', '🍕', '#e67e22', 6, NOW(), NOW()),
    ('travel', 'Places, cultures, and adventures', '✈️', '#1abc9c', 7, NOW(), NOW()),
    ('technology', 'Programming, gadgets, and innovation', '💻', '#34495e', 8, NOW(), NOW())
    """, ""

    # Insert some default tags for each category
    execute """
    INSERT INTO tags (name, description, category_id, inserted_at, updated_at) VALUES
    -- Movies
    ('Action', 'Action and adventure films', (SELECT id FROM tag_categories WHERE name = 'movies'), NOW(), NOW()),
    ('Comedy', 'Comedy films and shows', (SELECT id FROM tag_categories WHERE name = 'movies'), NOW(), NOW()),
    ('Drama', 'Dramatic films and series', (SELECT id FROM tag_categories WHERE name = 'movies'), NOW(), NOW()),
    ('Horror', 'Horror and thriller movies', (SELECT id FROM tag_categories WHERE name = 'movies'), NOW(), NOW()),
    ('Sci-Fi', 'Science fiction content', (SELECT id FROM tag_categories WHERE name = 'movies'), NOW(), NOW()),

    -- Music
    ('Rock', 'Rock music and subgenres', (SELECT id FROM tag_categories WHERE name = 'music'), NOW(), NOW()),
    ('Pop', 'Popular music', (SELECT id FROM tag_categories WHERE name = 'music'), NOW(), NOW()),
    ('Hip-Hop', 'Hip-hop and rap music', (SELECT id FROM tag_categories WHERE name = 'music'), NOW(), NOW()),
    ('Classical', 'Classical and orchestral music', (SELECT id FROM tag_categories WHERE name = 'music'), NOW(), NOW()),
    ('Electronic', 'Electronic and dance music', (SELECT id FROM tag_categories WHERE name = 'music'), NOW(), NOW()),

    -- Games
    ('RPG', 'Role-playing games', (SELECT id FROM tag_categories WHERE name = 'games'), NOW(), NOW()),
    ('FPS', 'First-person shooter games', (SELECT id FROM tag_categories WHERE name = 'games'), NOW(), NOW()),
    ('Strategy', 'Strategy and tactical games', (SELECT id FROM tag_categories WHERE name = 'games'), NOW(), NOW()),
    ('Board Games', 'Tabletop and board games', (SELECT id FROM tag_categories WHERE name = 'games'), NOW(), NOW()),
    ('Sports Games', 'Sports and racing games', (SELECT id FROM tag_categories WHERE name = 'games'), NOW(), NOW()),

    -- Books
    ('Fiction', 'Fiction literature', (SELECT id FROM tag_categories WHERE name = 'books'), NOW(), NOW()),
    ('Non-Fiction', 'Non-fiction and educational', (SELECT id FROM tag_categories WHERE name = 'books'), NOW(), NOW()),
    ('Fantasy', 'Fantasy novels and series', (SELECT id FROM tag_categories WHERE name = 'books'), NOW(), NOW()),
    ('Mystery', 'Mystery and detective stories', (SELECT id FROM tag_categories WHERE name = 'books'), NOW(), NOW()),
    ('Biography', 'Biographies and memoirs', (SELECT id FROM tag_categories WHERE name = 'books'), NOW(), NOW()),

    -- Activities
    ('Hiking', 'Hiking and outdoor activities', (SELECT id FROM tag_categories WHERE name = 'activities'), NOW(), NOW()),
    ('Photography', 'Photography and visual arts', (SELECT id FROM tag_categories WHERE name = 'activities'), NOW(), NOW()),
    ('Cooking', 'Cooking and culinary arts', (SELECT id FROM tag_categories WHERE name = 'activities'), NOW(), NOW()),
    ('Fitness', 'Exercise and fitness activities', (SELECT id FROM tag_categories WHERE name = 'activities'), NOW(), NOW()),
    ('Art', 'Visual arts and crafts', (SELECT id FROM tag_categories WHERE name = 'activities'), NOW(), NOW())
    """, ""
  end
end
