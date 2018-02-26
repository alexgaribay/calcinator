defmodule Calcinator.Resources.TestTag do
  @moduledoc """
  A schema used in examples in `Calcinator.Resources`
  """

  use Ecto.Schema

  alias Calcinator.Resources.TestPost

  schema "tags" do
    field(:name, :string)

    # Associations

    many_to_many(
      :posts,
      TestPost,
      join_keys: [
        tag_id: :id,
        post_id: :id
      ],
      join_through: "posts_tags",
      on_replace: :delete
    )
  end
end
