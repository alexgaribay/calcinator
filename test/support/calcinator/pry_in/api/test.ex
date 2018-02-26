# Based on https://github.com/pryin-io/pryin/blob/9fec04d61a7b8d4ff337653294f13c4e345c7029/test/support/test_api.ex
defmodule Calcinator.PryIn.Api.Test do
  @moduledoc """
  Test `PryIn.Api` that sends data sent by `send_data/1` and `send_system_metrics/1` back to listeners instead of of
  `pryin.io`.
  """

  @behaviour PryIn.Api

  use GenServer

  # Functions

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def subscribe do
    GenServer.call(__MODULE__, {:subscribe, self()})
  end

  ## PryIn.Api callbacks

  @impl PryIn.Api
  def send_data(interactions) do
    GenServer.call(__MODULE__, {:send_data, interactions})
  end

  @impl PryIn.Api
  def send_system_metrics(data) do
    GenServer.call(__MODULE__, {:send_system_metrics, data})
  end

  ## GenServer callbacks

  @impl GenServer
  def handle_call({:subscribe, pid}, _from, listeners) do
    {:reply, :ok, [pid | listeners]}
  end

  @impl GenServer
  def handle_call({:send_data, data}, _from, listeners) do
    send_to_listeners(listeners, {:data_sent, data})
    {:reply, :ok, listeners}
  end

  @impl GenServer
  def handle_call({:send_system_metrics, data}, _from, listeners) do
    send_to_listeners(listeners, {:system_metrics_sent, data})
    {:reply, :ok, listeners}
  end

  @impl GenServer
  def init([]) do
    {:ok, []}
  end

  ## Private Functons

  defp send_to_listeners(listeners, message) do
    for listener <- listeners do
      send(listener, message)
    end
  end
end
