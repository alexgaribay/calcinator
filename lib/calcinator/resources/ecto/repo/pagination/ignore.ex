defmodule Calcinator.Resources.Ecto.Repo.Pagination.Ignore do
  import Calcinator.Resources.Ecto.Repo, only: [wrap_ownership_error: 3]

  @behaviour Calcinator.Resources.Ecto.Repo.Pagination

  @impl Calcinator.Resources.Ecto.Repo.Pagination
  def paginate(repo, query, _) do
    case wrap_ownership_error(repo, :all, [query]) do
      {:error, :ownership} ->
        {:error, :ownership}

      all ->
        {:ok, all, nil}
    end
  end
end
