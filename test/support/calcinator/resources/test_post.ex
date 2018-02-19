defmodule Calcinator.Resources.TestPost do
  @moduledoc """
  A schema used in examples in `Calcinator.Resources`
  """

  use Ecto.Schema

  import Ecto.Changeset, only: [validate_required: 2]

  alias Calcinator.Resources.{TestAuthor, TestComment, TestTag}

  schema "posts" do
    field(:body, :string)

    timestamps()

    belongs_to(:author, TestAuthor)
    has_many(:comments, TestComment, foreign_key: :post_id)

    many_to_many(
      :tags,
      TestTag,
      join_keys: [
        post_id: :id,
        tag_id: :id
      ],
      join_through: "posts_tags",
      on_replace: :delete
    )
  end

  # Functions

  def changeset(changeset) do
    changeset
    |> validate_required(required_fields())
  end

  def optional_fields, do: []

  def required_fields, do: ~w(author_id body)a
end
