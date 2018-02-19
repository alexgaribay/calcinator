defmodule Calcinator.Resources.Sort do
  @moduledoc """
  Sort in `Calcinator.Resources.query_options`
  """

  alias Alembic.{Document, Error, Fetch.Includes, Source}
  alias Calcinator.Resources

  import Resources, only: [attribute_to_field: 2]

  # Struct

  defstruct field: nil,
            direction: :ascending,
            association: nil

  # Types

  @typedoc """
  Keyword list of association path used to Ecto preloading
  """
  @type association :: Keyword.t()

  @typedoc """
  The direction to sort.  Default to `:ascending` per the JSONAPI spec.  Can be `:descending` when the dot-separated
  attribute path is prefixed with `-`.
  """
  @type direction :: :ascending | :descending

  @typedoc """
  Name of a field in an `Ecto.Schema.t`
  """
  @type field_name :: atom

  @typedoc """
  * `:assocation` - Keyword list of nested associations.  `nil` when the `:field` is direction on the primary data.
  * `:direction` - the direction to sort `:field`
  * `:field` - name of the field to sort
  """
  @type t :: %__MODULE__{
          association: nil | association,
          direction: direction,
          field: field_name
        }

  @typedoc """
  Used to convert includes used by JSONAPI to the corresponding association in Ecto.

  This map does not need to be a simple conversion of the nested map of strings `Alembic.Fetch.Includes.t` to
  the `Keyword.t` of `associations`, but can include completely different names or associations that the JSONAPI doesn't
  even expose, so that deprecated relationships can be mapped to newer associations.
  """
  @type associations_by_include :: %{Alembic.Fetch.Includes.t() => association}

  @typedoc """
  * `:associations_by_include` - maps the `Alembic.Fetch.Includes.t` to Keyword.t of associations.
  * `:ecto_schema_module` - primary Ecto.Schema module for checking if attribute is an existent field after applying
    associations.
  """
  @type from_alembic_fetch_sort_options :: %{
          required(:associations_by_include) => associations_by_include,
          required(:ecto_schema_module) => module
        }

  @typedoc """
  Used to convert associations used in Ecto to JSONAPI includes.

  This map need not be the inverse of `associations_by_include` if the JSONAPI incoming relationships are no the same
  as the outgoing relationships.
  """
  @type include_by_associations :: %{association => Alembic.Fetch.Includes.t()}

  # Functions

  @doc """
  Maps `Alembic.Fetch.Sort.t` `attribute` to `t` `field` and `Alembic.Fetch.Sort.t` `relationships` to
  `t` `associations`.

  When there are no `relationships`, there are no assocations

      iex> Calcinator.Resources.Sort.from_alembic_fetch_sort(
      ...>   %Alembic.Fetch.Sort{
      ...>     attribute: "inserted-at"
      ...>   },
      ...>   %{
      ...>     associations_by_include: %{},
      ...>     ecto_schema_module: Calcinator.Resources.TestPost
      ...>   }
      ...> )
      {
        :ok,
        %Calcinator.Resources.Sort{field: :inserted_at}
      }

  When there is `relationship` it is converted to association using `:associations_by_include`

      iex> Calcinator.Resources.Sort.from_alembic_fetch_sort(
      ...>   %Alembic.Fetch.Sort{
      ...>     attribute: "inserted-at",
      ...>     relationship: "posts"
      ...>   },
      ...>   %{
      ...>     associations_by_include: %{"posts" => :posts},
      ...>     ecto_schema_module: Calcinator.Resources.TestAuthor
      ...>   }
      ...> )
      {
        :ok,
        %Calcinator.Resources.Sort{
          association: :posts,
          direction: :ascending,
          field: :inserted_at
        }
      }

  The relationship can also be nested and it will be converted using `:associations_by_include` too

      iex> Calcinator.Resources.Sort.from_alembic_fetch_sort(
      ...>   %Alembic.Fetch.Sort{
      ...>     attribute: "inserted-at",
      ...>     relationship: %{
      ...>       "posts" => "comments"
      ...>     }
      ...>   },
      ...>   %{
      ...>     associations_by_include: %{
      ...>       %{
      ...>         "posts" => "comments"
      ...>       } => [posts: :comments]
      ...>     },
      ...>     ecto_schema_module: Calcinator.Resources.TestAuthor
      ...>   }
      ...> )
      {
        :ok,
        %Calcinator.Resources.Sort{
          association: [posts: :comments],
          direction: :ascending,
          field: :inserted_at
        }
      }

  ## Errors

  If the `Alembic.Fetch.Sort.t` `relationship` is not in `:associations_by_include`, then an error is returned

      iex> Calcinator.Resources.Sort.from_alembic_fetch_sort(
      ...>   %Alembic.Fetch.Sort{
      ...>     attribute: "inserted-at",
      ...>     relationship: "author"
      ...>   },
      ...>   %{
      ...>     associations_by_include: %{},
      ...>     ecto_schema_module: Calcinator.Resources.TestPost
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`author` is an unknown relationship path",
              meta: %{
                "relationship_path" => "author"
              },
              source: %Alembic.Source{
                parameter: "include"
              },
              title: "Unknown relationship path"
            }
          ]
        }
      }

  If the `Alembic.Fetch.Sort.t` `attribute` is not on `:ecto_schema_module` when there is no `relationship`, then an
  error is returned with only the `attribute` in it

      iex> Calcinator.Resources.Sort.from_alembic_fetch_sort(
      ...>   %Alembic.Fetch.Sort{
      ...>     attribute: "likes",
      ...>     relationship: nil
      ...>   },
      ...>   %{
      ...>     associations_by_include: %{},
      ...>     ecto_schema_module: Calcinator.Resources.TestPost
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "Does not have `likes` attribute",
              meta: %{
                "attribute" => "likes"
              },
              source: %Alembic.Source{
                parameter: "sort"
              },
              title: "Unknown attribute"
            }
          ]
        }
      }

  If the `Alembic.Fetch.Sort.t` `attribute` is not on the associated `Ecto.Schema` module, than an error is returned
  with both the `relationship` and `attribute` in it.

      iex> Calcinator.Resources.Sort.from_alembic_fetch_sort(
      ...>   %Alembic.Fetch.Sort{
      ...>     attribute: "title",
      ...>     relationship: "author"
      ...>   },
      ...>   %{
      ...>     associations_by_include: %{
      ...>       "author" => :author
      ...>     },
      ...>     ecto_schema_module: Calcinator.Resources.TestPost
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`author` does not have a `title` attribute",
              meta: %{
                "attribute" => "title",
                "relationship_path" => "author"
              },
              source: %Alembic.Source{
                parameter: "sort"
              },
              title: "Unknown attribute"
            }
          ]
        }
      }

  If the relationship is far, then the whole relationship is shown in the error

      iex> Calcinator.Resources.Sort.from_alembic_fetch_sort(
      ...>   %Alembic.Fetch.Sort{
      ...>     attribute: "likes",
      ...>     relationship: %{
      ...>       "posts" => "comments"
      ...>     }
      ...>   },
      ...>   %{
      ...>     associations_by_include: %{
      ...>       %{
      ...>         "posts" => "comments"
      ...>       } => [posts: :comments]
      ...>     },
      ...>     ecto_schema_module: Calcinator.Resources.TestAuthor
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`posts.comments` does not have a `likes` attribute",
              meta: %{
                "attribute" => "likes",
                "relationship_path" => "posts.comments"
              },
              source: %Alembic.Source{
                parameter: "sort"
              },
              title: "Unknown attribute"
            }
          ]
        }
      }

  """
  @spec from_alembic_fetch_sort(Alembic.Fetch.Sort.t(), from_alembic_fetch_sort_options) ::
          {:ok, t} | {:error, Document.t()}
  def from_alembic_fetch_sort(sort = %Alembic.Fetch.Sort{direction: direction, relationship: relationship}, %{
        associations_by_include: associations_by_include,
        ecto_schema_module: ecto_schema_module
      }) do
    with {:ok, association} <- association(relationship, associations_by_include),
         {:ok, field} <- field(%{association: association, ecto_schema_module: ecto_schema_module, sort: sort}) do
      {:ok, %__MODULE__{association: association, direction: direction, field: field}}
    end
  end

  @doc """
  Maps `t` `field` to `Alembic.Fetch.Sort.t` `attribute` and `t` `associations` to `Alembic.Fetch.Sort.t`
  `relationships`.
  """
  @spec to_alembic_fetch_sort(t, Resources.t()) :: {:ok, Alembic.Fetch.Sort.t()} | {:error, Document.t()}
  def to_alembic_fetch_sort(%__MODULE__{association: association, direction: direction, field: field}, module) do
    {
      :ok,
      %Alembic.Fetch.Sort{
        attribute: attribute(field),
        direction: direction,
        relationship: relationship(module, association)
      }
    }
  end

  ## Private Functions

  defp association(nil, _), do: {:ok, nil}

  defp association(relationship, associations_by_include) when is_binary(relationship) or is_map(relationship) do
    with {:ok, [association]} <- Includes.to_preloads([relationship], associations_by_include) do
      {:ok, association}
    end
  end

  defp attribute(field) do
    field
    |> to_string()
    |> String.replace("_", "-")
  end

  defp attribute_error(%Error{detail: detail, meta: meta}) do
    %Error{
      detail: detail,
      meta: meta,
      source: %Source{
        parameter: "sort"
      },
      title: "Unknown attribute"
    }
  end

  defp attribute_error(%Alembic.Fetch.Sort{attribute: attribute, relationship: nil}) do
    attribute_error(%Error{
      detail: "Does not have `#{attribute}` attribute",
      meta: %{
        "attribute" => attribute
      }
    })
  end

  defp attribute_error(%Alembic.Fetch.Sort{attribute: attribute, relationship: relationship}) do
    relationship_path = Includes.to_string([relationship])

    attribute_error(%Error{
      detail: "`#{relationship_path}` does not have a `#{attribute}` attribute",
      meta: %{
        "attribute" => attribute,
        "relationship_path" => relationship_path
      }
    })
  end

  defp attribute_error_document(sort), do: %Document{errors: [attribute_error(sort)]}

  defp attribute_error_result(sort), do: {:error, attribute_error_document(sort)}

  defp field(%{
         association: nil,
         ecto_schema_module: ecto_schema_module,
         sort:
           sort = %Alembic.Fetch.Sort{
             attribute: attribute
           }
       }) do
    attribute
    |> attribute_to_field(ecto_schema_module)
    |> case do
      {:ok, field} ->
        {:ok, field}

      {:error, ^attribute} ->
        attribute_error_result(sort)
    end
  end

  defp field(%{
         association: association,
         ecto_schema_module: ecto_schema_module,
         sort: sort
       })
       when is_atom(association) do
    # Does not produce a JSON error because association being wrong is a programmer error that associatons_by_include
    # has a bad associciations
    %{related: related_ecto_schema_module} = ecto_schema_module.__schema__(:association, association)
    field(%{association: nil, ecto_schema_module: related_ecto_schema_module, sort: sort})
  end

  defp field(%{
         association: [{current_association, child_association}],
         ecto_schema_module: ecto_schema_module,
         sort: sort
       }) do
    # Does not produce a JSON error because association being wrong is a programmer error that associatons_by_include
    # has a bad associciations
    %{related: related_ecto_schema_module} = ecto_schema_module.__schema__(:association, current_association)
    field(%{association: child_association, ecto_schema_module: related_ecto_schema_module, sort: sort})
  end

  defp relationship(_, nil), do: nil
  defp relationship(module, association), do: module.association_to_include(association)
end
