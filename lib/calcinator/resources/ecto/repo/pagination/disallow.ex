defmodule Calcinator.Resources.Ecto.Repo.Pagination.Disallow do
  alias Alembic.{Document, Error, Source}
  alias Calcinator.Resources.Ecto.Repo.Pagination.Ignore

  @behaviour Calcinator.Resources.Ecto.Repo.Pagination

  @impl Calcinator.Resources.Ecto.Repo.Pagination
  def paginate(repo, query, query_options) do
    case Map.get(query_options, :page) do
      nil ->
        Ignore.paginate(repo, query, query_options)

      _ ->
        {:error,
         %Document{
           errors: [
             %Error{
               detail: "Pagination parameters were passed, but they are not allowed",
               source: %Source{pointer: "/page"},
               status: "422",
               title: "Pagination disallowed"
             }
           ]
         }}
    end
  end
end
