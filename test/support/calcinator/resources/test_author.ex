defmodule Calcinator.Resources.TestAuthor do
  @moduledoc """
  A schema used in examples in `Calcinator.Resources`
  """

  use Ecto.Schema

  import Ecto.Changeset, only: [cast: 3, no_assoc_constraint: 2, validate_required: 2]

  schema "authors" do
    field(:name, :string)
    field(:password, :string, virtual: true)
    field(:password_confirmation, :string, virtual: true)

    has_many(:posts, Calcinator.Resources.TestPost, foreign_key: :author_id)
  end

  # Functions

  def changeset(changeset) do
    changeset
    |> no_assoc_constraint(:posts)
    |> validate_required(required_fields())
  end

  def changeset(model, params) do
    model
    |> cast(params, optional_fields() ++ required_fields())
    |> changeset()
  end

  def optional_fields, do: ~w(password password_confirmation)a

  def required_fields, do: ~w(name)a
end
