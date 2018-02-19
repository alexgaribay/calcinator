defmodule Calcinator.Resources.Ecto.Repo.Repo.Case do
  @moduledoc """
  Helpers for accessing `Calcinator.Resources.Ecto.Repo.Repo`.
  """

  alias Calcinator.Meta.Beam
  alias Calcinator.Resources.Ecto.Repo.Repo

  @doc """
  Checks out connection to `Calcinator.Resources.Ecto.Repo.Repo` from `Ecto.Adapters.SQL.Sandbox` and return the
  `"meta"` to pass in params to reconnect to that connection from the controller.
  """
  def checkout_meta do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    %{}
    |> Beam.put(Repo)
    |> Enum.into(%{}, fn {key, value} ->
      {to_string(key), value}
    end)
  end
end
