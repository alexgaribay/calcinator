defmodule Calcinator.TestPostView do
  @moduledoc """
  View for `Calcinator.TestPost`
  """

  alias Calcinator.{RelatedView, RelationshipView, TestAuthorView, TestTagView}
  alias Calcinator.Resources.TestPost

  use JaSerializer.PhoenixView
  use Calcinator.JaSerializer.PhoenixView, phoenix_view_module: __MODULE__

  location("/api/v1/test-posts/:id")

  # Attributes

  attributes(~w(body)a)

  # Relationships

  has_one(:author, serializer: TestAuthorView)
  has_many(:tags, serializer: TestTagView)

  # Functions

  def render("get_related_resource.json-api", options) do
    RelatedView.render("get_related_resource.json-api", Map.put(options, :view, __MODULE__))
  end

  def render("show_relationship.json-api", options) do
    RelationshipView.render("show_relationship.json-api", Map.put(options, :view, __MODULE__))
  end

  ## JaSerializer.Serializer callbacks

  @impl JaSerializer.Serializer
  def relationships(test_post, conn) do
    test_post
    |> super(conn)
    |> Enum.filter(relationships_filter(test_post))
    |> Enum.into(%{})
  end

  def type, do: "test-posts"

  ## Private Functions

  defp relationships_filter(test_post = %TestPost{}) do
    not_loaded_names =
      Enum.reduce([author: :author], [], fn {field, relationship}, acc ->
        case Map.get(test_post, field) do
          %Ecto.Association.NotLoaded{} ->
            [relationship | acc]

          _ ->
            acc
        end
      end)

    fn {name, _relationship} ->
      name not in not_loaded_names
    end
  end
end
