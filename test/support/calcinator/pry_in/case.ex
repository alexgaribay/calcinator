# Based on https://github.com/pryin-io/pryin/blob/9fec04d61a7b8d4ff337653294f13c4e345c7029/test/support/pryin_case.ex
defmodule Calcinator.PryIn.Case do
  @moduledoc """
  Starts `Calcinator.PryIn.Api.Test` and subscribes to it.
  """

  use ExUnit.CaseTemplate

  alias Calcinator.PryIn.Api.Test
  alias PryIn.InteractionStore

  setup do
    ensure_test_api_stopped()
    InteractionStore.reset_state()
    {:ok, _} = Test.start_link()
    Test.subscribe()

    :ok
  end

  defp ensure_test_api_stopped do
    case Process.whereis(Test) do
      nil ->
        :ok

      pid ->
        api_ref = Process.monitor(pid)
        Process.exit(pid, :kill)

        receive do
          {:DOWN, ^api_ref, _, _, _} -> :ok
        after
          1_000 -> raise "did not receive #{inspect(Test)} down message after 1s"
        end
    end
  end
end
