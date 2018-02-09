defmodule Calcinator.Resources.Page do
  @moduledoc """
  Page in `Calcinator.Resources.query_options`
  """

  alias Alembic.{Document, Error, FromJson, Source}

  # Constants
  @error_template %Alembic.Error{
    source: %Alembic.Source{
      pointer: "/page"
    }
  }

  @number_options %{
    field: :number,
    member: %{
      from_json: &__MODULE__.positive_integer_from_json/2,
      name: "number",
      required: true
    }
  }

  @size_options %{
    field: :size,
    member: %{
      from_json: &__MODULE__.positive_integer_from_json/2,
      name: "size",
      required: true
    }
  }

  @page_child_options_list [
    @number_options,
    @size_options
  ]

  # Struct

  defstruct ~w(number size)a

  # Types

  @typedoc """
    * `number` - the page number.  1-based.
    * `size` - the size of each page.
  """
  @type t :: %__MODULE__{
          number: pos_integer,
          size: pos_integer
        }

  # Functions

  @doc """
  Parses `t` out of `params`

  ## Errors

  A page number can't be given as the `"page"` parameter alone because no default page size is assumed.

      iex> Calcinator.Resources.Page.from_params(%{"page" => 1})
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/page` type is not object",
              meta: %{
                "type" => "object"
              },
              source: %Alembic.Source{
                pointer: "/page"
              },
              status: "422",
              title: "Type is wrong"
            }
          ]
        }
      }

  ### Number format

  `"page"` `"number"` must be a positive integer.  It is 1-based.  The first page is `"1"`

      iex> Calcinator.Resources.Page.from_params(
      ...>   %{
      ...>     "page" => %{
      ...>       "number" => 0,
      ...>       "size" => 10
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/page/number` type is not positive integer",
              meta: %{
                "type" => "positive integer"
              },
              source: %Alembic.Source{
                pointer: "/page/number"
              },
              status: "422",
              title: "Type is wrong"
            }
          ]
        }
      }

  ### Size format

  `"page"` `"size"` must be a positive integer.

      iex> Calcinator.Resources.Page.from_params(
      ...>   %{
      ...>     "page" => %{
      ...>       "number" => 1,
      ...>       "size" => 0
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/page/size` type is not positive integer",
              meta: %{
                "type" => "positive integer"
              },
              source: %Alembic.Source{
                pointer: "/page/size"
              },
              status: "422",
              title: "Type is wrong"
            }
          ]
        }
      }

  ### Maximum size

  The maximum size can be configured

      config :calcinator, Calcinator.Resources.Page, size: [maximum: 20]

  or at runtimew using `Application.put_env/3`

      Application.put_env(:calcinator, Calcinator.Resources.Page, size: [maximum: 20]

  If size exceeds the maximum size, an error will be returned.

      iex> Application.put_env(:calcinator, Calcinator.Resources.Page, size: [maximum: 20])
      iex> Calcinator.Resources.Page.from_params(%{"page" => %{"number" => 1, "size" => 25}})
      {:error,
       %Alembic.Document{
         errors: [
           %Alembic.Error{
             detail: "Page size (25) is greater than the maximum (20).",
             meta: %{"maximum" => 20},
             source: %Alembic.Source{parameter: nil, pointer: "/page/size"},
             status: "422",
             title: "Exceeds Maximum"
           }
         ]
       }}

  The default size is also checked against the maximum size.

      iex> Application.put_env(:calcinator, Calcinator.Resources.Page, size: [default: 25, maximum: 20])
      iex> Calcinator.Resources.Page.from_params(%{})
      {:error,
       %Alembic.Document{
         errors: [
           %Alembic.Error{
             detail: "Page size (25) is greater than the maximum (20).",
             meta: %{"maximum" => 20},
             source: %Alembic.Source{parameter: nil, pointer: "/page/size"},
             status: "422",
             title: "Exceeds Maximum"
           }
         ]
       }}

  ## With default page size

  A default page size can be configured.

      config :calcinator, Calcinator.Resources.Page, size: [default: 5]

  or at runtime using `Application.put_env/3`

      Application.put_env(:calcinator, Calcinator.Resources.Page, size: [default: 10])

  If there is no `"page"` key, then there is pagination using the default page size and the default number, 1.

      iex> Application.put_env(:calcinator, Calcinator.Resources.Page, size: [default: 15])
      iex> Calcinator.Resources.Page.from_params(%{})
      {:ok, %Calcinator.Resources.Page{number: 1, size: 15}}

  If there is a `"page"` key with a `"size"` child, but not a `"number" child, then the first page is assumed

      iex> Application.put_env(:calcinator, Calcinator.Resources.Page, size: [default: 20])
      iex> Calcinator.Resources.Page.from_params(%{"page" => %{"size" => 10}})
      {:ok, %Calcinator.Resources.Page{number: 1, size: 10}}

  If there is a `"page"` key with a `"number"` child, but not a `"size" child, then the number page is used with the
  default page size

      iex> Application.put_env(:calcinator, Calcinator.Resources.Page, size: [default: 25])
      iex> Calcinator.Resources.Page.from_params(%{"page" => %{"number" => 2}})
      {:ok, %Calcinator.Resources.Page{number: 2, size: 25}}

  If there is a `"page"` key with both a `"number"` and `"size"` children, then the defaults are ignored and the number
  and size are used

      iex> Application.put_env(:calcinator, Calcinator.Resources.Page, size: [default: 30])
      iex> Calcinator.Resources.Page.from_params(%{"page" => %{"number" => 2, "size" => 10}})
      {:ok, %Calcinator.Resources.Page{number: 2, size: 10}}

  ## Without default page size

  If there is no `"page"` key, then there is no pagination.

      iex> Calcinator.Resources.Page.from_params(%{})
      {:ok, nil}

  ### Pagination

  If there is a "page" key with `"number"` and `"size"` children, then there is pagination.

      iex> Calcinator.Resources.Page.from_params(
      ...>   %{
      ...>     "page" => %{
      ...>       "number" => 1,
      ...>       "size" => 2
      ...>     }
      ...>   }
      ...> )
      {:ok, %Calcinator.Resources.Page{number: 1, size: 2}}

  In addition to be decoded JSON, the params can also be the raw `%{String.t => String.t}` and the quoted integers will
  be decoded.

      iex> Calcinator.Resources.Page.from_params(
      ...>   %{
      ...>     "page" => %{
      ...>       "number" => "1",
      ...>       "size" => "2"
      ...>     }
      ...>   }
      ...> )
      {:ok, %Calcinator.Resources.Page{number: 1, size: 2}}

  ### Required parameters

  Likewise, the `"page"` map can't have only a `"number"` parameter because no default page size is assumed.

      iex> Calcinator.Resources.Page.from_params(
      ...>   %{
      ...>     "page" => %{
      ...>       "number" => 1
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/page/size` is missing",
              meta: %{
                "child" => "size"
              },
              source: %Alembic.Source{
                pointer: "/page"
              },
              status: "422",
              title: "Child missing"
            }
          ]
        }
      }

  The page number is not assumed to be 1 when not given.

      iex> Calcinator.Resources.Page.from_params(
      ...>   %{
      ...>     "page" => %{
      ...>       "size" => 10
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/page/number` is missing",
              meta: %{
                "child" => "number"
              },
              source: %Alembic.Source{
                pointer: "/page"
              },
              status: "422",
              title: "Child missing"
            }
          ]
        }
      }

  """

  def from_params(%{"page" => page}) when is_map(page) do
    env = env()
    from_parent_json(%{error_template: @error_template, json: put_defaults(page, env)}, env)
  end

  def from_params(%{"page" => page}) when not is_map(page) do
    {:error, %Document{errors: [Error.type(@error_template, "object")]}}
  end

  def from_params(params) when is_map(params) do
    env = env()

    %{}
    |> put_defaults(env)
    |> case do
      empty when map_size(empty) == 0 -> {:ok, nil}
      page_params -> from_parent_json(%{error_template: @error_template, json: page_params}, env)
    end
  end

  def to_params(nil), do: %{}

  def to_params(%__MODULE__{number: number, size: size})
      when is_integer(number) and number > 0 and is_integer(size) and size > 0 do
    %{
      "page" => %{
        "number" => number,
        "size" => size
      }
    }
  end

  def positive_integer_from_json(child, error_template) do
    with {:ok, integer} <- integer_from_json(child, error_template) do
      integer_to_positive_integer(integer, error_template)
    end
  end

  ## Private Functions

  defp env do
    Application.get_env(:calcinator, __MODULE__) || []
  end

  defp from_parent_json(parent, env) do
    @page_child_options_list
    |> Stream.map(&Map.put(&1, :parent, parent))
    |> Stream.map(&put_maximum(&1, env))
    |> Stream.map(&FromJson.from_parent_json_to_field_result/1)
    |> FromJson.reduce({:ok, %__MODULE__{}})
  end

  defp integer_from_json(
         quoted_integer,
         error_template = %Error{
           source:
             source = %Source{
               pointer: pointer
             }
         }
       )
       when is_binary(quoted_integer) do
    case Integer.parse(quoted_integer) do
      :error ->
        {
          :error,
          %Document{
            errors: [
              Error.type(error_template, "quoted integer")
            ]
          }
        }

      {integer, ""} ->
        {:ok, integer}

      {integer, remainder_of_binary} ->
        {
          :error,
          %Document{
            errors: [
              %Error{
                detail:
                  "`#{pointer}` contains quoted integer (`#{integer}`), " <>
                    "but also excess text (`#{inspect(remainder_of_binary)}`)",
                meta: %{
                  excess: remainder_of_binary,
                  integer: integer,
                  type: "quoted integer"
                },
                source: source,
                status: "422",
                title: "Excess text in quoted integer"
              }
            ]
          }
        }
    end
  end

  defp integer_from_json(integer, _) when is_integer(integer), do: {:ok, integer}

  defp integer_from_json(_, error_template) do
    {
      :error,
      %Document{
        errors: [
          Error.type(error_template, "integer")
        ]
      }
    }
  end

  defp integer_to_positive_integer(integer, _) when is_integer(integer) and integer > 0 do
    {:ok, integer}
  end

  defp integer_to_positive_integer(integer, error_template) when is_integer(integer) do
    {:error, %Document{errors: [Error.type(error_template, "positive integer")]}}
  end

  defp put_maximum(child_options = %{field: field}, env) do
    case field do
      :number ->
        child_options

      :size ->
        with {:ok, size_env} <- Keyword.fetch(env, :size),
             {:ok, maximum} <- Keyword.fetch(size_env, :maximum) do
          update_in(child_options.member.from_json, fn from_json ->
            fn json, error_template ->
              with {:ok, size} when size > maximum <- from_json.(json, error_template) do
                {:error,
                 %Document{
                   errors: [
                     %Error{
                       error_template
                       | detail: "Page size (#{size}) is greater than the maximum (#{maximum}).",
                         meta: %{"maximum" => maximum},
                         status: "422",
                         title: "Exceeds Maximum"
                     }
                   ]
                 }}
              end
            end
          end)
        else
          _ -> child_options
        end
    end
  end

  defp put_defaults(page, env) do
    with {:ok, size_env} <- Keyword.fetch(env, :size),
         {:ok, default} <- Keyword.fetch(size_env, :default) do
      page
      |> Map.put_new("number", 1)
      |> Map.put_new("size", default)
    else
      :error -> page
    end
  end
end
