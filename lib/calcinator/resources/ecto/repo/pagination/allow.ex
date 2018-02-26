defmodule Calcinator.Resources.Ecto.Repo.Pagination.Allow do
  @moduledoc """
  All resources with `nil` pagination is returned when `query_options[:page]` is `nil`.  A page of resources with the
  pagination information is returned when `query_options[:page]` is not `nil`.  **This is the default paginator.**
  """

  import Ecto.Query
  import Ecto.Queryable, only: [to_query: 1]

  alias Alembic.Pagination

  @behaviour Calcinator.Resources.Ecto.Repo.Pagination

  # Functions

  @impl Calcinator.Resources.Ecto.Repo.Pagination
  def paginate(repo, query, query_options) do
    # there is no default order in Postgres, so enforce if there is no caller supplied order_by
    ordered_query = put_new_order_by(query)
    resources = resources(repo, ordered_query, query_options)
    pagination = pagination(repo, ordered_query, query_options)

    {:ok, resources, pagination}
  end

  ## Private Functions

  defp alembic_pagination(%{
         page: %Calcinator.Resources.Page{number: number, size: size},
         total_size: total_size
       }) do
    last_page_number = last_page_number(total_size, size)

    %Pagination{
      first: %Pagination.Page{number: 1, size: size},
      last: %Pagination.Page{number: last_page_number, size: size},
      total_size: total_size
    }
    |> put_next_page(number)
    |> put_previous_page(number)
  end

  defp last_page_number(0, _), do: 1

  defp last_page_number(total_size, size) do
    total_size
    |> Kernel./(size)
    |> Float.ceil()
    |> round()
  end

  defp put_new_order_by(query = %Ecto.Query{order_bys: order_bys}) do
    case order_bys do
      [] -> order_by(query, :id)
      [_ | _] -> query
    end
  end

  defp put_new_order_by(queryable) do
    queryable
    |> to_query()
    |> put_new_order_by()
  end

  defp pagination(repo, query, query_options) do
    case Map.get(query_options, :page) do
      nil ->
        nil

      page = %Calcinator.Resources.Page{} ->
        total_size = total_size(repo, query)
        alembic_pagination(%{page: page, total_size: total_size})
    end
  end

  defp put_next_page(
         alembic_pagination = %Pagination{
           last: %Pagination.Page{number: total_pages, size: size}
         },
         number
       ) do
    if number < total_pages do
      %Pagination{alembic_pagination | next: %Pagination.Page{number: number + 1, size: size}}
    else
      alembic_pagination
    end
  end

  defp put_previous_page(
         alembic_pagination = %Pagination{first: %Pagination.Page{size: size}},
         number
       ) do
    if number > 1 do
      %Pagination{
        alembic_pagination
        | previous: %Pagination.Page{number: number - 1, size: size}
      }
    else
      alembic_pagination
    end
  end

  defp resources(repo, query, query_options) do
    case Map.get(query_options, :page) do
      nil ->
        repo.all(query)

      %Calcinator.Resources.Page{number: number, size: size} ->
        offset = size * (number - 1)

        query
        |> limit(^size)
        |> offset(^offset)
        |> repo.all()
    end
  end

  defp total_size(repo, query) do
    query
    |> exclude(:group_by)
    |> exclude(:order_by)
    |> repo.aggregate(:count, :id)
  end
end
