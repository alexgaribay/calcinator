defmodule Calcinator.Resources.Ecto.Repo.Pagination do
  @moduledoc """
  Modules implementing this behaviour can paginate a `query` against a `repo` using `:page` in `query_options`.
  """

  alias Calcinator.Resources

  @doc """
  Paginates a `query` against a `repo` using `:page` in `query_options`.

  ## Returns

  The returns are the same as those supported by `c:Calcinator.Resources.list/1`.

  * `{:ok, [resource], nil}` - all resources matching query
  * `{:ok, [resource], pagination}` - page of resources matching query
  * `{:error, :ownership}` - connection to backing store was not owned by the calling process
  * `{:error, :timeout}` - timeout occured while getting resources from backing store.
  * `{:error, reason}` - an error occurred with the backing store for `reason` that is backing store specific.

  """
  @callback paginate(repo :: Ecto.Repo.t(), query :: Ecto.Query.t(), Resources.query_options()) ::
              {:ok, [Ecto.Schema.t()], Alembic.Pagination.t() | nil}
              | {:error, :ownership}
              | {:error, Alembic.Document.t()}
end
