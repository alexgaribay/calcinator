defmodule Calcinator.TestAuthorView do
  @moduledoc """
  View for `Calcinator.TestAuthor`
  """

  alias Calcinator.{RelatedView, RelationshipView}

  use JaSerializer.PhoenixView
  use Calcinator.JaSerializer.PhoenixView, phoenix_view_module: __MODULE__

  location("/api/v1/test-authors/:id")

  # Attributes

  attributes(~w(name)a)

  # Relationships

  has_many(:posts, serializers: Calcinator.TestPostView)

  # Functions

  def render("get_related_resource.json-api", options) do
    RelatedView.render("get_related_resource.json-api", Map.put(options, :view, __MODULE__))
  end

  def render("show_relationship.json-api", options) do
    RelationshipView.render("show_relationship.json-api", Map.put(options, :view, __MODULE__))
  end

  ## JaSerializer.PhoenixView callbacks

  def type, do: "test-authors"
end
