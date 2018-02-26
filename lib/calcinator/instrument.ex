# Based on https://raw.githubusercontent.com/phoenixframework/phoenix/d6106c692311a2dfbba95243af144481124aad46/lib/
#   phoenix/endpoint/instrument.ex
# Switch to the generic Application Performance Monitor library once Chris McCord releases it.
defmodule Calcinator.Instrument do
  @moduledoc """
  Similar to Phoenix, Calcinator supports instrumenters that can receive events from `Calcinator`.

  The `instrument/3` macro is responsible for measuring the time it takes for the event to be processed and for
  notifying a list of interested instrumenter modules of this measurement.

  You can configure this list of instrumenter modules in the compile-time
  configuration for Calcinator.

      config :calcinator,
             instrumenters: [MyApp.Instrumenter]

  The way these modules express their interest in events is by exporting public functions where the name of each
  function is the name of an event.  The list of defined events is in "Events" section below.

  ### Callbacks cycle

  The event callback sequence is:

    1. The event callback is called *before* the event happens with the atom `:start` as the first argument; see the
       "`:start` clause" section below.
    2. The event occurs
    3. The same event callback is called again, this time with the atom `:stop` as the first argument; see the
       "`:stop` clause" section below.

  The second and third argument that each event callback takes depends on the value of the first argument, `:start` or
  `:stop`. For this reason, most of the time you will want to define (at least) two separate clauses for each event
  callback, one for the `:start` and one for the `:stop` callbacks.

  All event callbacks are run in the same process that calls the `instrument/3` macro; hence, instrumenters should be
  careful to avoid performing blocking actions. If an event callback fails in any way (exits, throws, or raises), it
  won't affect anything as the error is caught, but the failure will be logged. Note that `:stop` callbacks are not
  guaranteed to be called as, for example, a link may break before they've been called.

  #### `:start` clause

  When the first argument to an event callback is `:start`, the signature of that callback is:

      event_callback(:start,
                     compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                     runtime_metadata :: map) :: any

  where:

    * `compile_metadata` is a map of compile-time metadata about the environment
      where `instrument/3` has been called.
      * `:function` - "\#{name}/\#{arity}" of function where `instrument/3` has been called.
    * `runtime_metadata` is a map of runtime data that the instrumentation passes to the callbacks. It varies per call.
      See "Events" below for a list of defined events.

  #### `:stop` clause

  When the first argument to an event callback is `:stop`, the signature of that callback is:

      event_callback(:stop, time_diff :: non_neg_integer, result_of_start_callback :: any)

  where:

    * `time_diff` is an integer representing the time it took to execute the instrumented function **in native units**.
    * `result_of_start_callback` is the return value of the `:start` clause of the same `event_callback`. This is a
       means of passing data from the `:start` clause to the `:stop` clause when instrumenting.

  The return value of each `:start` event callback will be stored and passed to the corresponding `:stop` callback.

  ### Events

  #### `:alembic`

  When `Calcinator` calls `Alembic.Document.from_json/2`

      alembic(:start
              compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
              runtime_metdata :: %{action: :create | :update, params: params})

  #### `:calcinator_authorization`

  `:calcinator_authorization` occurs around calls to the `authorization_module.can?/3` in `Calcinator.can?/3` to measure how long
  it takes to authorize actions on the primary target.

  ##### `:create`

  There are two calls to authorize `:create`.

  The first call will use the `ecto_schema_module` as the `target` to check if `ecto_schema_module` structs can be
  created in general by the `subject`.

      calcinator_authorization(:start,
                               compile_metadata ::
                                 %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                               runtime_metdata :: %{action: :create
                                                    calcinator: %Calcinator{
                                                      authorizaton_module: module
                                                      ecto_schema_module: ecto_schema_module
                                                    },
                                                    target: ecto_schema_module})

  Before

      authorization_module.can?(subject, :create, ecto_schema_module)

  If the `subject` can create `ecto_schema_module` structs in general, then a second call will check if the specific
  `Ecto.Changeset.t` can be created.

      calcinator_authorization(:start,
                               compile_metadata ::
                                 %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                               runtime_metadata :: %{action: :create,
                                                     calcinator: %Calcinator{
                                                       authorizaton_module: module
                                                       ecto_schema_module: ecto_schema_module
                                                     },
                                                     target: %Ecto.Changeset{data: %ecto_schema_module{}}})

  Before

      authorization_module.can?(subject, :create, %Ecto.Changeset{data: %ecto_schema_module{}})

  ##### `:delete`

  There is only one call to authorize `:delete`.

      calcinator_authorization(:start,
                               compile_metadata ::
                                 %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                               runtime_metdata :: %{action: :delete
                                                  calcinator: %Calcinator{
                                                    authorizaton_module: module
                                                    ecto_schema_module: ecto_schema_module
                                                  },
                                                  target: %ecto_schema_module{}})

      authorization_module.can?(subject, :delete, %ecto_schema_module{})

  ##### `:index`

  There is one call to authorize `:index`.

      calcinator_authorization(:start,
                               compile_metadata ::
                                 %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                               runtime_metdata :: %{action: :index
                                                    calcinator: %Calcinator{
                                                      authorizaton_module: module
                                                      ecto_schema_module: ecto_schema_module
                                                    },
                                                    target: ecto_schema_module})

  Before

      authorization_module.can?(subject, :index, ecto_schema_module)

  ##### `:show`

  ###### `Calcinator.get_related_resource/3`

  There is not a special `action` for authorizing `Calcinator.get_related_resource/3`, instead the `source` is authorized
  for `:show`.

  *NOTE: This is the same pattern as for `Calcinator.show/2`, `Calcinator.show_relationship/3`, and
  `Calcinator.update/2`.*

      calcinator_authorization(:start,
                               compile_metadata ::
                                 %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                               runtime_metdata :: %{action: :show
                                                    calcinator: %Calcinator{
                                                      authorizaton_module: module
                                                      ecto_schema_module: ecto_schema_module
                                                    },
                                                    target: %ecto_schema_module{}})

  Before

      authorization_module.can?(subject, :show, %ecto_schema_module{})

  If the `source` can be shown, then its checked if the `related` can be show in an association ascent under `source`.

  *NOTE: This is the same pattern as for `Calcinator.show_relationship/3`.*

      calcinator_authorization(:start,
                               compile_metadata ::
                                 %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                               runtime_metdata :: %{action: :show
                                                    calcinator: %Calcinator{
                                                      authorizaton_module: module
                                                      ecto_schema_module: ecto_schema_module
                                                    },
                                                    target: [%related_ecto_schema_module{}, %ecto_schema_module{}])

  Before

      authorization_module.can?(subject, :show, [%related_ecto_schema_module{}, %ecto_schema_module{}])

  ###### `Calcinator.show/2`

  The primary data is authorized for `:show`.

  *NOTE: This is the same pattern as the authorization to `:show` the `source` for `Calcinator.get_related_resource/3`,
  `Calcinator.show_relationship/3`, and `Calcinator.update/2`.*

      calcinator_authorization(:start,
                               compile_metadata ::
                                 %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                               runtime_metdata :: %{action: :show
                                                    calcinator: %Calcinator{
                                                      authorizaton_module: module
                                                      ecto_schema_module: ecto_schema_module
                                                    },
                                                    target: %ecto_schema_module{}})

  Before

      authorization_module.can?(subject, :show, %ecto_schema_module{})

  ###### `Calcinator.show_relationship/3`

  There is not a special `action` for authorizing `Calcinator.show_relationship/3`, instead the `source` is authorized
  for `:show`.

  *NOTE: This is the same pattern as for `Calcinator.show/2`, `Calcinator.get_related_resource/3`, and
  `Calcinator.update/2`.*

      calcinator_authorization(:start,
                               compile_metadata ::
                                 %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                               runtime_metdata :: %{action: :show
                                                    calcinator: %Calcinator{
                                                      authorizaton_module: module
                                                      ecto_schema_module: ecto_schema_module
                                                    },
                                                    target: %ecto_schema_module{}})

  Before

      authorization_module.can?(subject, :show, %ecto_schema_module{})

  If the `source` can be shown, then its checked if the `related` can be show in an association ascent under `source`.

  *NOTE: This is the same pattern as for `Calcinator.get_related_resource/3`.*

      calcinator_authorization(:start,
                               compile_metadata ::
                                 %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                               runtime_metdata :: %{action: :show
                                                    calcinator: %Calcinator{
                                                      authorizaton_module: module
                                                      ecto_schema_module: ecto_schema_module
                                                    },
                                                    target: [%related_ecto_schema_module{}, %ecto_schema_module{}])

  Before

      authorization_module.can?(subject, :show, [%related_ecto_schema_module{}, %ecto_schema_module{}])

  ###### `Calcinator.update/3`

  Before a `target` can be updated, it is checked that `subject` can `:show` the target. **NOTE: This is the same
  pattern as for `Calcinator.show/2`, `Calcinator.get_related_resource/3`, and `Calcinator.show_relatonship/3`.**

      calcinator_authorization(:start,
                               compile_metadata ::
                                 %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                               runtime_metdata :: %{action: :show
                                                    calcinator: %Calcinator{
                                                      authorizaton_module: module
                                                      ecto_schema_module: ecto_schema_module
                                                    },
                                                    target: %ecto_schema_module{}})

  Before

      authorization_module.can?(subject, :show, %ecto_schema_module{})

  ##### `:update`

  ###### `Calcinator.update/3`

  If a `target` is authorized for `:show`, it is checked if the `subject` can update the `Ecto.Changeset.t`.

      calcinator_authorization(:start,
                               compile_metadata ::
                                 %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                               runtime_metdata :: %{action: :update
                                                    calcinator: %Calcinator{
                                                      authorizaton_module: module
                                                      ecto_schema_module: ecto_schema_module
                                                    },
                                                    target: %Ecto.Changeset{data: %ecto_schema_module{}}})

  Before

      authorization_module.can?(subject, :update, %Ecto.Changeset{data: %ecto_schema_module{}})

  #### `:calcinator_resources`

  The `:calcinator_resources` event is fired around any `resources_module` call by `Calcinator`.

  The general format has the `args` passed to the `Calcinator.Resources.t` `callback`

      calcinator_view(:start,
                      compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                      runtime_metadata :: %{args: args,
                                            calcinator: %Calcinator{resources_module: Calcinator.Resources.t},
                                            callback: atom})

  ##### `Calcinator.Resources.allow_sandbox_access/1`

      calcinator_view(:start,
                      compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                      runtime_metadata :: %{args: [beam],
                                            calcinator: %Calcinator{resources_module: Calcinator.Resources.t},
                                            callback: :allow_sandbox_access})

  The only argument is the opaque `beam` data structure that is used to allow sandbox access.

  ##### `Calcinator.Resources.delete/2`, `Calcinator.Resources.insert/2`, and `Calcinator.Resources.update/2`

      calcinator_resources(:start,
                           compile_metadata ::
                             %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                           runtime_metadata :: %{args: [changeset, query_options],
                                                 calcinator: %Calcinator{resources_module: Calcinator.Resources.t},
                                                 callback: :delete | :insert | :update})

  `Calcinator.Resources.delete/2`, `Calcinator.Resources.insert/2`, and `Calcinator.Resources.update/2` all take 2
  arguments:

  1. `changeset` - `Ecto.Changeset.t`
  2. `query_options` - `Calcinator.Resoures.query_options`

  ##### `Calcinator.Resources.get/2`

      calcinator_view(:start,
                      compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                      runtime_metadata :: %{args: [id, query_options],
                                            calcinator: %Calcinator{resources_module: Calcinator.Resources.t},
                                            callback: :get})

  Arguments

  1. `id` - ID of resource to lookup (`String.t` or `non_neg_integer`)
  2. `query_options` - `Calcinator.Resoures.query_options`

  ##### `Calcinator.Resources.list/1`

      calcinator_view(:start,
                      compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                      runtime_metadata :: %{args: [query_options],
                                            calcinator: %Calcinator{resources_module: Calcinator.Resources.t},
                                            callback: :list})

  Arguments

  1. `query_options` - `Calcinator.Resoures.query_options`

  ##### `Calcinator.Resources.sandboxed?/0`

      calcinator_view(:start,
                      compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                      runtime_metadata :: %{args: [],
                                            calcinator: %Calcinator{resources_module: Calcinator.Resources.t},
                                            callback: :sandboxed?})

  #### `:calcinator_view`

  `calcinator` splits rendering into calling the `view_module` and then encoding to the underlying transport.  Only
  calling `view_module` happens during the `:calcinator_view` event.

  The general format has the `args` passed to the `Calcinator.View.t` `callback`

      calcinator_view(:start,
                      compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                      runtime_metadata ::
                        %{args: args, calcinator: %Calcinator{view_module: Calcinator.View.t}, callback: atom})

  ##### `:get_related_resources` or `:show_relationship`

  For the `Calcinator.View.get_related_resources/2` and `Calcinator.View.show_relations/2` callback, the `args` are the
  same because `show_relationship` uses the same `source` and `related`, but only shows the Resource Identifier
  (`id` and `type`) instead of the full Resource (`id`, `type`, `attributes`, and `relationships`).

      calcinator_view(:start,
                      compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                      runtime_metadata ::
                        %{args: [related_resources :: nil | struct | [struct],
                                 %{related: %{resource: related_resource},
                                   source: %{association: source_association, resource: source_resource},
                                   subject: subject}],
                          calcinator: %Calcinator{view_module: Calcinator.View.t},
                          callback: :index})

   The `args` have 2 elements.

  1. `related_resource` - The related resource(s) whose `id` (or ids) would be used for `show_relationship`.
     Can be one of three formats
     * `nil` - `belongs_to` or `has_one` `source_association` that has no entry
     * `struct` - `belongs_to` or `has_one` `source_association` that has an entry
     * `[struct]` - `has_many` `source_association`
  2. `options`
     * `:related`
       * `:resource` - `related_resources`.  Matches the first argument.
     * `:source`
       * `association` - the name of the associaton on `source_resource` that contained `related_resources`
       * `resource` - `struct` of the starting primary data.
     * `:subject` - the subject that is authorized to see source and related resources

  ##### `:index`

  For the `Calcinator.View.index/2` callback.

      calcinator_view(:start,
                      compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                      runtime_metadata ::
                        %{args: [resources, %{subject: subject}],
                          calcinator: %Calcinator{view_module: Calcinator.View.t},
                          callback: :index})

  The `args` have 2 elements.

  1. `resources` - The index resources
  2. `options`
     * `:subject` - the subject that is authorized to see `resources`

  ##### `:show`

  For the `Calcinator.View.show/2` callback.

      calcinator_view(:start,
                      compile_metadata :: %{module: module, function: String.t, file: String.t, line: non_neg_integer},
                      runtime_metadata ::
                        %{args: [resource, %{subject: subject}],
                          calcinator: %Calcinator{view_module: Calcinator.View.t},
                          callback: :show})

  The `args` have 2 elements.

  1. `resource` - The resource to be shown
  2. `options`
     * `:subject` - the subject that is authorized to see `resource`

  """

  require Logger

  import Calcinator.Instrumenters

  # Macros

  @doc """
  Instruments the given function.

  `event` is the event identifier (usually an atom) that specifies which
  instrumenting function to call in the instrumenter modules. `runtime` is
  metadata to be associated with the event at runtime (e.g., the query being
  issued if the event to instrument is a DB query).

  ## Predefined Events

  ### Examples

      instrument :calcinator_authorization, %{action: action, calcinator: calcinator, target: target}, fn ->
        ...
      end

  """
  defmacro instrument(event, runtime \\ Macro.escape(%{}), fun) do
    compile =
      __CALLER__
      |> strip_caller()
      |> Macro.escape()

    quote do
      import Calcinator.Instrument, only: [instrument: 4]

      instrument(
        unquote(event),
        unquote(compile),
        unquote(runtime),
        unquote(fun)
      )
    end
  end

  # Functions

  # For each event in any of the instrumenters, we must generate a
  # clause of the `instrument/4` function. It'll look like this:
  #
  #   def instrument(:my_event, compile, runtime, fun) do
  #     res0 = Inst0.my_event(:start, compile, runtime)
  #     ...
  #
  #     start = :erlang.monotonic_time
  #     try do
  #       fun.()
  #     after
  #       diff = ...
  #       Inst0.my_event(:stop, diff, res0)
  #       ...
  #     end
  #   end
  #
  @doc false
  def instrument(event, compile, runtime, fun)

  for {event, instrumenters} <- app_instrumenters() do
    def instrument(unquote(event), var!(compile), var!(runtime), fun)
        when is_map(var!(compile)) and is_map(var!(runtime)) and is_function(fun, 0) do
      unquote(compile_start_callbacks(instrumenters, event))
      start = :erlang.monotonic_time()

      try do
        fun.()
      after
        var!(diff) = :erlang.monotonic_time() - start
        unquote(compile_stop_callbacks(instrumenters, event))
      end
    end
  end

  # Catch-all clause
  def instrument(event, compile, runtime, fun)
      when is_atom(event) and is_map(compile) and is_map(runtime) and is_function(fun, 0) do
    fun.()
  end

  ## Private Functions

  defp form_fa({name, arity}), do: Atom.to_string(name) <> "/" <> Integer.to_string(arity)
  defp form_fa(nil), do: nil

  # Strips a `Macro.Env` struct, leaving only interesting compile-time metadata.
  @doc false
  @spec strip_caller(Macro.Env.t()) :: %{
          optional(:application) => atom,
          required(:file) => String.t(),
          required(:line) => non_neg_integer,
          required(:function) => String.t() | nil,
          required(:module) => module
        }
  def strip_caller(%Macro.Env{module: mod, function: fun, file: file, line: line}) do
    caller = %{module: mod, function: form_fa(fun), file: file, line: line}

    if app = Application.get_env(:logger, :compile_time_application) do
      Map.put(caller, :application, app)
    else
      caller
    end
  end
end
