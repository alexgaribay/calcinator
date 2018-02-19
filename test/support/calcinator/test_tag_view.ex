defmodule Calcinator.TestTagView do
  @moduledoc """
  View for `Calcinator.TestTag`
  """

  alias Calcinator.TestPostView

  use JaSerializer.PhoenixView
  use Calcinator.JaSerializer.PhoenixView, phoenix_view_module: __MODULE__

  location("/api/v1/test-tags/:id")

  # Attributes

  attributes(~w(name)a)

  # Relationships

  has_many(:posts, serializers: TestPostView)

  ## JaSerializer.PhoenixView callbacks

  def type, do: "test-tags"
end
