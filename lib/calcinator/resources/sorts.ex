defmodule Calcinator.Resources.Sorts do
  @moduledoc """
  Sorts in `Calcinator.Resources.query_options`
  """

  alias Alembic.FromJson
  alias Calcinator.Resources
  alias Calcinator.Resources.Sort

  # Types

  @type t :: [Sort.t()]

  # Functions

  @doc """
  Maps `Alembic.Fetch.t` `sorts` `attribute` to `t` `Resources.Sort.t` `field` and `Alembic.Fetch.t` `sorts`
  `relationships` to `t` `Resources.Sort.t` `associations`.
  """
  @spec from_alembic_fetch(Alembic.Fetch.t(), Sort.from_alembic_fetch_sort_options()) ::
          {:ok, t | nil} | FromJson.error()
  def from_alembic_fetch(%Alembic.Fetch{sorts: sorts}, options), do: from_alembic_fetch_sorts(sorts, options)

  @doc """
  Maps `Alembic.Fetch.t` `sorts` `attribute` to `t` `Resources.Sort.t` `field` and `Alembic.Fetch.t` `sorts`
  `relationships` to `t` `Resources.Sort.t` `associations`.
  """
  @spec from_alembic_fetch_sorts(Alemic.Fetch.Sorts.t() | nil, Sort.from_alembic_fetch_sort_options()) ::
          {:ok, nil | t} | FromJson.error()
  def from_alembic_fetch_sorts(nil, _), do: {:ok, nil}

  def from_alembic_fetch_sorts(sorts, options) when is_list(sorts) do
    sorts
    |> Stream.map(&Sort.from_alembic_fetch_sort(&1, options))
    |> FromJson.reduce({:ok, []})
  end

  @doc """
  Maps `t` `Resources.Sort.t` `field` to `Alembic.Fetch.t` `sorts` `attribute` and `t` `Resources.Sort.t` `associations`
  to `Alembic.Fetch.t` `sorts` `relationships`.
  """

  @spec to_alembic_fetch_sorts(nil, Resources.t()) :: {:ok, nil}
  def to_alembic_fetch_sorts(nil, _), do: {:ok, nil}

  @spec to_alembic_fetch_sorts(t, Resources.t()) :: {:ok, Alembic.Fetch.Sorts.t()} | FromJson.error()
  def to_alembic_fetch_sorts(sorts, options) when is_list(sorts) do
    sorts
    |> Stream.map(&Sort.to_alembic_fetch_sort(&1, options))
    |> FromJson.reduce({:ok, []})
  end
end
