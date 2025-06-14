defmodule Socialite.Tags do
  @moduledoc """
  The Tags context.
  """

  import Ecto.Query, warn: false
  alias Socialite.Repo
  alias Socialite.{Tag, TagCategory, UserTag, User}

  ## Tag Categories

  @doc """
  Returns the list of tag categories ordered by order_index.
  """
  def list_tag_categories do
    TagCategory
    |> order_by([tc], tc.order_index)
    |> preload(:tags)
    |> Repo.all()
  end

  @doc """
  Gets a single tag category.
  """
  def get_tag_category!(id), do: Repo.get!(TagCategory, id)

  @doc """
  Creates a tag category.
  """
  def create_tag_category(attrs \\ %{}) do
    %TagCategory{}
    |> TagCategory.changeset(attrs)
    |> Repo.insert()
  end

  ## Tags

  @doc """
  Returns the list of tags for a specific category.
  """
  def list_tags_by_category(category_id) do
    Tag
    |> where([t], t.category_id == ^category_id and t.is_active == true)
    |> order_by([t], [desc: t.usage_count, asc: t.name])
    |> Repo.all()
  end

  @doc """
  Returns all active tags with their categories.
  """
  def list_all_tags do
    Tag
    |> where([t], t.is_active == true)
    |> preload(:category)
    |> order_by([t], [asc: t.name])
    |> Repo.all()
  end

  @doc """
  Gets a single tag.
  """
  def get_tag!(id), do: Repo.get!(Tag, id)

  @doc """
  Creates a tag.
  """
  def create_tag(attrs \\ %{}) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, tag} ->
        # Increment usage count
        increment_tag_usage(tag.id)
        {:ok, tag}
      error -> error
    end
  end

  @doc """
  Searches for tags by name.
  """
  def search_tags(query) when is_binary(query) and query != "" do
    search_term = "%#{String.downcase(query)}%"

    Tag
    |> where([t], t.is_active == true)
    |> where([t], fragment("LOWER(?)", t.name) |> like(^search_term))
    |> preload(:category)
    |> order_by([t], [desc: t.usage_count, asc: t.name])
    |> limit(20)
    |> Repo.all()
  end

  def search_tags(_), do: []

  ## User Tags

  @doc """
  Gets all tags for a user, grouped by category.
  """
  def get_user_tags_by_category(user_id) do
    query = from ut in UserTag,
      join: t in Tag, on: ut.tag_id == t.id,
      join: tc in TagCategory, on: t.category_id == tc.id,
      where: ut.user_id == ^user_id and ut.is_public == true,
      order_by: [tc.order_index, t.name],
      preload: [tag: :category]

    user_tags = Repo.all(query)

    # Group by category
    user_tags
    |> Enum.group_by(fn ut -> ut.tag.category end)
    |> Enum.sort_by(fn {category, _} -> category.order_index end)
  end

  @doc """
  Gets all public tags for a user.
  """
  def get_user_tags(user_id) do
    UserTag
    |> where([ut], ut.user_id == ^user_id and ut.is_public == true)
    |> preload([ut], tag: :category)
    |> Repo.all()
  end

  @doc """
  Adds a tag to a user.
  """
  def add_user_tag(user_id, tag_id, proficiency_level \\ 1) do
    attrs = %{
      user_id: user_id,
      tag_id: tag_id,
      proficiency_level: proficiency_level,
      is_public: true
    }

    %UserTag{}
    |> UserTag.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user_tag} ->
        # Increment tag usage count
        increment_tag_usage(tag_id)
        {:ok, user_tag}
      error -> error
    end
  end

  @doc """
  Removes a tag from a user.
  """
  def remove_user_tag(user_id, tag_id) do
    UserTag
    |> where([ut], ut.user_id == ^user_id and ut.tag_id == ^tag_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      user_tag ->
        result = Repo.delete(user_tag)
        # Decrement tag usage count
        decrement_tag_usage(tag_id)
        result
    end
  end

  @doc """
  Updates a user tag's proficiency level.
  """
  def update_user_tag_proficiency(user_id, tag_id, proficiency_level) do
    UserTag
    |> where([ut], ut.user_id == ^user_id and ut.tag_id == ^tag_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      user_tag ->
        user_tag
        |> UserTag.changeset(%{proficiency_level: proficiency_level})
        |> Repo.update()
    end
  end

  ## Compatibility

  @doc """
  Calculates compatibility percentage between two users based on their tags.
  Returns a float between 0.0 and 100.0.
  """
  def calculate_compatibility(user1_id, user2_id) do
    user1_tags = get_user_tag_ids(user1_id)
    user2_tags = get_user_tag_ids(user2_id)

    if Enum.empty?(user1_tags) or Enum.empty?(user2_tags) do
      0.0
    else
      common_tags = MapSet.intersection(MapSet.new(user1_tags), MapSet.new(user2_tags))
      total_unique_tags = MapSet.union(MapSet.new(user1_tags), MapSet.new(user2_tags))

      # Jaccard similarity coefficient
      compatibility = MapSet.size(common_tags) / MapSet.size(total_unique_tags) * 100
      Float.round(compatibility, 1)
    end
  end

  @doc """
  Gets compatibility breakdown by category between two users.
  """
  def get_compatibility_breakdown(user1_id, user2_id) do
    user1_tags_by_category = get_user_tags_by_category_map(user1_id)
    user2_tags_by_category = get_user_tags_by_category_map(user2_id)

    all_categories = MapSet.union(
      MapSet.new(Map.keys(user1_tags_by_category)),
      MapSet.new(Map.keys(user2_tags_by_category))
    )

    Enum.map(all_categories, fn category ->
      user1_category_tags = Map.get(user1_tags_by_category, category, [])
      user2_category_tags = Map.get(user2_tags_by_category, category, [])

      if Enum.empty?(user1_category_tags) or Enum.empty?(user2_category_tags) do
        %{category: category, compatibility: 0.0, common_tags: []}
      else
        common_tags = MapSet.intersection(
          MapSet.new(user1_category_tags),
          MapSet.new(user2_category_tags)
        )
        total_unique_tags = MapSet.union(
          MapSet.new(user1_category_tags),
          MapSet.new(user2_category_tags)
        )

        compatibility = MapSet.size(common_tags) / MapSet.size(total_unique_tags) * 100

        %{
          category: category,
          compatibility: Float.round(compatibility, 1),
          common_tags: MapSet.to_list(common_tags)
        }
      end
    end)
    |> Enum.sort_by(& &1.compatibility, :desc)
  end

  ## Private functions

  defp get_user_tag_ids(user_id) do
    UserTag
    |> where([ut], ut.user_id == ^user_id and ut.is_public == true)
    |> select([ut], ut.tag_id)
    |> Repo.all()
  end

  defp get_user_tags_by_category_map(user_id) do
    query = from ut in UserTag,
      join: t in Tag, on: ut.tag_id == t.id,
      join: tc in TagCategory, on: t.category_id == tc.id,
      where: ut.user_id == ^user_id and ut.is_public == true,
      select: {tc.name, t.id}

    Repo.all(query)
    |> Enum.group_by(fn {category, _tag_id} -> category end, fn {_category, tag_id} -> tag_id end)
  end

  defp increment_tag_usage(tag_id) do
    Tag
    |> where([t], t.id == ^tag_id)
    |> Repo.update_all(inc: [usage_count: 1])
  end

  defp decrement_tag_usage(tag_id) do
    Tag
    |> where([t], t.id == ^tag_id and t.usage_count > 0)
    |> Repo.update_all(inc: [usage_count: -1])
  end
end
