defmodule Calcinator.Resources.TestComment do
  @moduledoc """
  A schema used in examples in `Calcinator.Resources`
  """

  use Ecto.Schema

  schema "comments" do
    field(:text, :string)

    timestamps()

    belongs_to(:post, Calcinator.Resources.TestPost)
  end
end
