if Code.ensure_loaded?(Phoenix.Controller) do
  defmodule Calcinator.Controller do
    @moduledoc """
    Controller that replicates [`JSONAPI::ActsAsResourceController`](http://www.rubydoc.info/gems/jsonapi-resources/
    JSONAPI/ActsAsResourceController).

    ## Actions

    The available actions:
      * `create`
      * `delete`
      * `get_related_resource`
      * `index`
      * `show`
      * `show_relationship`
      * `update`

    Chosen actions are specified to the `use Calcinator.Controller` call as a list of atoms:

        use Calcinator.Controller,
            actions: ~w(create delete get_related_resource index show show_relationship update)a,
            ...

    ## Authorization

    ### Authenticated/Authorized Read/Write

    If you authenticate users, you need to tell `Calcinator.Controller` they are your `subject` for the
    `authorization_module`

        alias Calcinator.Controller

        use Controller,
            actions: ~w(create delete get_related_resource index show show_relationship update)a,
            configuration: %Controller{
              authorization_module: MyApp.Authorization,
              ...
            }

        # Plugs

        plug :put_subject

        # Functions

        def put_subject(conn = %Conn{assigns: %{user: user}}, _), do: Controller.put_subject(conn, user)

    ### Public Read-Only

    If the controller exposes a read-only resource that you're comfortable being publicly-readable, you can skip
    authorization: it will default to `Calcinator.Authorization.Subjectless`.  `Calcinator.Authorization.Subjectless`
    will error out if you starts to have a non-`nil` `subject`, so it will catch if you're mixing authenticated and
    unauthenticated pipelines accidentally.

        alias Calcinator.Controller

        use Controller,
            actions: ~w(get_related_resource index show show_relationship)a,
            configuration: %Controller{
              ...
            }

    ## Routing

    ### CRUD

    If you only the standard CRUD actions

        use Calcinator.Controller,
            actions: ~w(create delete index show update)a,
            ...

    then the normal Phoenix `resources` macro will work

       resources "/posts", PostController

    ### `get_related_resource/3` and `show_relationship/3`

    If you use the `get_related_resource/3` or `show_relationship/3` actions

        use Calcinator.Controller,
            actions: ~w(get_related_resource index show show_relationship),
            ...

    You'll need custom routes

        resources "/posts", PostController do
           get "/author",
               PostController,
               :get_related_resource,
               as: :author,
               assigns: %{
                 related: %{
                   view_module: AuthorView
                 },
                 source: %{
                   association: :credential_source,
                   id_key: "credential_id"
                 }
               }
           get "/relationships/author"",
              PostController,
              :show_relationship,
              as: :relationships_author,
              assigns: %{
                association: :author,
                source: %{
                  id_key: "author_id"
                }
              }
        end

    """

    alias Plug.Conn

    import Calcinator.{Authorization, Controller.Error}
    import Conn

    # Macros

    defmacro __using__(opts) do
      {names, _} =
        opts
        |> Keyword.fetch!(:actions)
        |> Code.eval_quoted([], __CALLER__)

      quoted_configuration = Keyword.fetch!(opts, :configuration)

      for name <- names do
        name_quoted_action = quoted_action(name, quoted_configuration)
        Module.eval_quoted(__CALLER__.module, name_quoted_action, [], __CALLER__)
      end
    end

    # Functions

    @doc """
    Gets the subject used for the `%Calcinator{}` passed to action functions.

        iex> %Plug.Conn{} |>
        iex> Calcinator.Controller.put_subject(:admin) |>
        iex> Calcinator.Controller.get_subject()
        :admin

    It can be `nil` if `put_subject/2` was not called or called `put_subject(conn, nil)`.

        iex> Calcinator.Controller.get_subject(%Plug.Conn{})
        nil
        iex> %Plug.Conn{} |>
        iex> Calcinator.Controller.put_subject(nil) |>
        iex> Calcinator.Controller.get_subject()
        nil

    """
    @spec get_subject(Conn.t()) :: Authorization.subject()
    def get_subject(conn), do: conn.private[:calcinator_subject]

    @doc """
    Puts the subject used for the `%Calciantor{}` pass to action functions.

    If you use subject-based authorization, where you don't use `Calcinator.Authorization.Subjectless` (the default) for
    the `:authorization` module, then you will need to set the subject.

    Here, the subject is set from the `user` assign set by some authorization plug (not shown)

        defmodule MyAppWeb.PostController do
          alias Calcinator.Controller

          use Controller,
              actions: ~w(create destroy index show update)a,
              configuration: %Calcinator{
                authorization_module: MyAppWeb.Authorization,
                ecto_schema_module: MyApp.Post,
                resources_module: MyApp.Posts,
                view_module: MyAppWeb.PostView
              }

          # Plugs

          plug :put_subject

          # Functions

          def put_subject(conn = %Conn{assigns: %{user: user}}, _), do: Controller.put_subject(conn, user)
        end

    """
    @spec put_subject(Conn.t(), Authorization.subject()) :: Conn.t()
    def put_subject(conn, subject), do: put_private(conn, :calcinator_subject, subject)

    ## Action Functions

    @spec create(Conn.t(), Calcinator.params(), Calcinator.t()) :: Conn.t()
    def create(conn = %Conn{}, params, calcinator = %Calcinator{}) do
      put_rendered_or_error(
        conn,
        Calcinator.create(%Calcinator{calcinator | subject: get_subject(conn)}, params),
        :created
      )
    end

    @spec delete(Conn.t(), Calcinator.params(), Calcinator.t()) :: Conn.t()
    def delete(conn, params = %{"id" => _}, calcinator = %Calcinator{}) do
      case Calcinator.delete(%Calcinator{calcinator | subject: get_subject(conn)}, params) do
        :ok ->
          deleted(conn)

        error ->
          put_calcinator_error(conn, error)
      end
    end

    @doc """
    Unlike `show`, which can infer its information from the default routing information provided by Phoenix's
    `resources` routing macro, `get_related_resource/3` requires manual routing to setup the `related` and `source`
    assigns.

        resources "/posts", PostController do
           # Route will be `/posts/:author_id/author`
           get "/author",
               PostController,
               :get_related_resource,
               as: :author,
               assigns: %{
                 related: %{
                   view_module: AuthorView
                 },
                 source: %{
                   association: :author,
                   id_key: "post_id"
                 }
               }
        end

    """
    @spec get_related_resource(Conn.t(), Calcinator.params(), Calcinator.t()) :: Conn.t()
    def get_related_resource(
          conn = %Conn{
            assigns: %{
              related: related,
              source: source
            }
          },
          params,
          calcinator = %Calcinator{}
        ) do
      put_rendered_or_error(
        conn,
        Calcinator.get_related_resource(%Calcinator{calcinator | subject: get_subject(conn)}, params, %{
          related: related,
          source: source
        })
      )
    end

    @spec index(Conn.t(), Calcinator.params(), Calcinator.t()) :: Conn.t()
    def index(conn, params, calcinator = %Calcinator{}) do
      put_rendered_or_error(
        conn,
        Calcinator.index(%Calcinator{calcinator | subject: get_subject(conn)}, params, %{base_uri: base_uri(conn)})
      )
    end

    @spec show(Conn.t(), Calcinator.params(), Calcinator.t()) :: Conn.t()
    def show(conn, params = %{"id" => _}, calcinator = %Calcinator{}) do
      put_rendered_or_error(
        conn,
        Calcinator.show(%Calcinator{calcinator | subject: get_subject(conn)}, params)
      )
    end

    @doc """
    Unlike `show`, which can infer its information from the default routing information provided by Phoenix's
    `resources` routing macro, `show_relationship/3` requires manual routing to setup the `association` and `source`
    assigns.

        resources "/posts", PostController do
          # Route will be `/posts/:post_id/relationships/author`
          get "/relationships/author"",
              PostController,
              :show_relationship,
              as: :relationships_author,
              assigns: %{
                related: %{
                  view_module: AuthorView
                }
                source: %{
                  association: :author,
                  id_key: "post_id"
                }
              }
        end

    For relationships, the related resource is not rendered through it's view, but the `related[:view_module]` is still
    needed in the `assigns` for the `view_module.type()` of the associated resource since relatinships are composed of
    the `"type"` and `"id"` of the related resource(s).
    """
    @spec show_relationship(Conn.t(), Calcinator.params(), Calcinator.t()) :: Conn.t()
    def show_relationship(
          conn = %Conn{
            assigns: %{
              related: related,
              source: source
            }
          },
          params,
          calcinator = %Calcinator{}
        ) do
      put_rendered_or_error(
        conn,
        Calcinator.show_relationship(%Calcinator{calcinator | subject: get_subject(conn)}, params, %{
          related: related,
          source: source
        })
      )
    end

    @spec update(Conn.t(), Calcinator.params(), Calcinator.t()) :: Conn.t()
    def update(conn, params, calcinator = %Calcinator{}) do
      put_rendered_or_error(
        conn,
        Calcinator.update(%Calcinator{calcinator | subject: get_subject(conn)}, params)
      )
    end

    ## Private Functions

    defp base_uri(%Conn{request_path: path}), do: %URI{path: path}

    defp put_rendered_or_error(conn, rendered_or_error, status \\ :ok)
    defp put_rendered_or_error(conn, {:ok, rendered}, status), do: render_json(conn, rendered, status)
    defp put_rendered_or_error(conn, error, _), do: put_calcinator_error(conn, error)

    defp quoted_action(quoted_name, quoted_configuration) do
      quote do
        def unquote(quoted_name)(conn, params) do
          Calcinator.Controller.unquote(quoted_name)(conn, params, unquote(quoted_configuration))
        end
      end
    end
  end
end
