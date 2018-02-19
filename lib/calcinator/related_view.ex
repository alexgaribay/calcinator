defmodule Calcinator.RelatedView do
  @moduledoc """
  Defines `"get_related_resource.json-api"` `render/2` clauses that defer to `render_related_resource/2` callbacks.
  """

  alias Alembic.Document

  import JaSerializer.Formatter.Utils, only: [format_key: 1]

  # Functions

  def base_url(
        options = %{
          source: %{
            view_module: view_module
          }
        }
      ) do
    Regex.replace(~r/:\w+/, view_module.__location, &id_key_for_id(&1, options))
  end

  def relationship(association), do: format_key(association)

  # The "show.json-api" for JaSerializer does not handle `nil` for `options[:data]`, but when `nil`, we don't care about
  # the `attributes/2` callback anyway, so render directly using Alembic,
  def render("get_related_resource.json-api", %{data: nil}) do
    %Document{
      data: nil,
      jsonapi: %{
        version: "1.0"
      }
    }
  end

  def render(
        "get_related_resource.json-api",
        options = %{
          related: %{
            view_module: related_view_module
          }
        }
      ) do
    "show.json-api"
    |> related_view_module.render(Map.delete(options, [:related, :source]))
    |> put_links(options)
  end

  ## Private Functions

  defp id_key_for_id(":id", %{
         conn: conn,
         source: %{
           resource: resource,
           view_module: view_module
         }
       }) do
    resource
    |> view_module.id(conn)
    |> to_string()
  end

  defp links(
         options = %{
           source: %{
             association: association
           }
         }
       ) do
    base_url = base_url(options)
    relationship = relationship(association)

    %{
      self: "#{base_url}/#{relationship}"
    }
  end

  defp put_links(rendered, options) do
    case rendered["data"] do
      # has_many relationship has relationship in top-level "links" since it is the link for collection of resources
      # has_one with nil data has no object for data, so "links" must go to top-level
      data when is_list(data) or is_nil(data) ->
        put_in(rendered["links"], links(options))

      # has_one without nil has an object, so "links" can be added
      data when is_map(data) ->
        put_in(rendered["data"]["links"], links(options))
    end
  end
end
