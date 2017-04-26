defmodule Calcinator.Resources.Ecto.Repo.TestAuthors do
  use Calcinator.Resources.Ecto.Repo

  import Calcinator.Resources, only: [split_filter_value: 1, unknown_filter: 1]
  import Ecto.Query, only: [where: 3]

  # Functions

  ## Calcinator.Resources.Ecto.Repo callbacks

  def ecto_schema_module(), do: Calcinator.Resources.TestAuthor

  def filter(query, "id", comma_separated_ids) do
    {:ok, where(query, [i], i.id in ^split_filter_value(comma_separated_ids))}
  end
  def filter(_,     name, _), do: {:error, unknown_filter(name)}

  def repo(), do: Calcinator.Resources.Ecto.Repo.Repo
end
