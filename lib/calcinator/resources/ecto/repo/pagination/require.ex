defmodule Calcinator.Resources.Ecto.Repo.Pagination.Require do
  alias Alembic.{Document, Error, Source}
  alias Calcinator.Resources.Ecto.Repo.Pagination.Allow

  @behaviour Calcinator.Resources.Ecto.Repo.Pagination

  # Functions

  @impl Calcinator.Resources.Ecto.Repo.Pagination
  def paginate(repo, query, query_options) do
    case Map.get(query_options, :page) do
      nil ->
        {:error,
         %Document{
           errors: [
             %Error{
               detail: "Pagination parameters were not passed, but they are required",
               source: %Source{pointer: "/"},
               status: "422",
               title: "Pagination required"
             }
           ]
         }}

      _ ->
        Allow.paginate(repo, query, query_options)
    end
  end
end
