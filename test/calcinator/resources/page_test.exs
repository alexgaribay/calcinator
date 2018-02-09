defmodule Calcinator.Resources.PageTest do
  @moduledoc """
  Tests `Calcinator.Resources.Page`
  """

  alias Calcinator.Resources.Page

  # must be synchronous because of the use Application.(get|put)_env in setup and doctests
  use ExUnit.Case, async: false

  # needed to wrap doctests too as there's doctests using Application.put_env
  setup :env_transaction

  doctest Page

  # Functions

  ## Private Functions

  defp env_transaction(_) do
    before = Application.get_env(:calcinator, Calcinator.Resources.Page)

    on_exit(fn ->
      case before do
        nil -> Application.delete_env(:calcinator, Calcinator.Resources.Page)
        _ -> Application.put_env(:calcinator, Calcinator.Resources.Page, before)
      end
    end)

    :ok
  end
end
