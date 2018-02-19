defmodule Calcinator.Resources.Ecto.Repo.TestAuthors do
  @moduledoc """
  `Calcinator.Resources.Ecto.Repo.TestAuthor` resources
  """

  use Calcinator.Resources.Ecto.Repo

  alias Calcinator.Resources.{Ecto.Repo.Repo, TestAuthor}

  import Calcinator.Resources, only: [split_filter_value: 1, unknown_filter: 1]
  import Ecto.Query, only: [from: 2, where: 3]

  # Functions

  ## Calcinator.Resources.Ecto.Repo callbacks

  def delete(data, query_options) do
    case override(:delete) do
      nil ->
        super(data, query_options)

      override ->
        override
    end
  end

  def ecto_schema_module, do: TestAuthor

  def filter(query, "id", comma_separated_ids) do
    {:ok, where(query, [i], i.id in ^split_filter_value(comma_separated_ids))}
  end

  def filter(query, "posts.body", body_substring) do
    filter_query =
      from(
        i in query,
        join: p in assoc(i, :posts),
        where: ilike(p.body, ^"%#{body_substring}%")
      )

    {:ok, filter_query}
  end

  def filter(_, name, _), do: {:error, unknown_filter(name)}

  def get(id, query_options) do
    case override(:get) do
      nil ->
        super(id, query_options)

      override ->
        override
    end
  end

  def insert(changeset, query_options) do
    case override(:insert) do
      nil ->
        super(changeset, query_options)

      override ->
        override
    end
  end

  def list(query_options) do
    case override(:list) do
      nil ->
        super(query_options)

      override ->
        override
    end
  end

  def repo, do: Repo

  def update(changeset, query_options) do
    case override(:update) do
      nil ->
        super(changeset, query_options)

      override ->
        override
    end
  end

  ## Private Functions

  defp override(action) do
    :calcinator
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(action)
  end
end
