defmodule Calcinator.Instrumenters do
  @moduledoc false

  # Constants

  # This is the arity that event callbacks in the instrumenter modules must
  # have.
  @event_callback_arity 3

  # Functions

  # Reads a list of the instrumenters from the config of `:calcinator` and finds all events in those instrumenters. The
  # return value is a list of `{event, instrumenters}` tuples, one for each event defined by any instrumenters (with no
  # duplicated events); `instrumenters` is the list of instrumenters interested in `event`.
  @doc false
  def app_instrumenters do
    instrumenters = Application.get_env(:calcinator, :instrumenters, [])

    unless is_list(instrumenters) and Enum.all?(instrumenters, &is_atom/1) do
      raise ":instrumenters must be a list of instrumenter modules"
    end

    events_to_instrumenters(instrumenters)
  end

  # Returns the AST for all the calls to the "start event" callbacks in the given
  # list of `instrumenters`.
  # Each function call looks like this:
  #
  #     res0 = Instr0.my_event(:start, compile, runtime)
  #
  @doc false
  @spec compile_start_callbacks([module], term) :: Macro.t()
  def compile_start_callbacks(instrumenters, event) do
    instrumenters
    |> Enum.with_index()
    |> Enum.map(fn {inst, index} ->
      error_prefix = "Instrumenter #{inspect(inst)}.#{event}/3 failed.\n"

      quote do
        unquote(build_result_variable(index)) =
          try do
            unquote(inst).unquote(event)(:start, var!(compile), var!(runtime))
          catch
            kind, error ->
              Logger.error(unquote(error_prefix) <> Exception.format(kind, error))
          end
      end
    end)
  end

  # Returns the AST for all the calls to the "stop event" callbacks in the given
  # list of `instrumenters`.
  # Each function call looks like this:
  #
  #     Instr0.my_event(:stop, diff, res0)
  #
  @doc false
  @spec compile_stop_callbacks([module], term) :: Macro.t()
  def compile_stop_callbacks(instrumenters, event) do
    instrumenters
    |> Enum.with_index()
    |> Enum.map(fn {inst, index} ->
      error_prefix = "Instrumenter #{inspect(inst)}.#{event}/3 failed.\n"

      quote do
        try do
          unquote(inst).unquote(event)(:stop, var!(diff), unquote(build_result_variable(index)))
        catch
          kind, error ->
            Logger.error(unquote(error_prefix) <> Exception.format(kind, error))
        end
      end
    end)
  end

  ## Private Functions

  defp build_result_variable(index) when is_integer(index) do
    "res#{index}" |> String.to_atom() |> Macro.var(nil)
  end

  # Takes a list of instrumenter modules and returns a list of `{event,
  # instrumenters}` tuples where each tuple represents an event and all the
  # modules interested in that event.
  defp events_to_instrumenters(instrumenters) do
    # [Ins1, Ins2, ...]
    # [{Ins1, e1}, {Ins2, e1}, ...]
    # %{e1 => [{Ins1, e1}, ...], ...}
    # [{e1, [Ins1, Ins2]}, ...]
    instrumenters
    |> instrumenters_and_events()
    |> Enum.group_by(fn {_inst, e} -> e end)
    |> Enum.map(fn {e, insts} -> {e, strip_events(insts)} end)
  end

  defp instrumenters_and_events(instrumenters) do
    # We're only interested in functions (events) with the given arity.
    for inst <- instrumenters,
        {event, @event_callback_arity} <- inst.__info__(:functions),
        do: {inst, event}
  end

  defp strip_events(instrumenters) do
    for {inst, _evt} <- instrumenters, do: inst
  end
end
