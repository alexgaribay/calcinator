defmodule Calcinator.TestPostController do
  @moduledoc """
  Test controller for `Calcinator.PryIn.InstrumenterTest`
  """

  alias Calcinator.Controller

  use Phoenix.Controller

  use Controller,
    actions: ~w(create delete get_related_resource index show show_relationship update)a,
    configuration: %Calcinator{
      associations_by_include: %{
        "author" => :author,
        "tags" => :tags
      },
      ecto_schema_module: Calcinator.Resources.TestPost,
      resources_module: Calcinator.Resources.Ecto.Repo.TestPosts,
      view_module: Calcinator.TestPostView
    }
end
