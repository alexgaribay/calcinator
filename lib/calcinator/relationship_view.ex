defmodule Calcinator.RelationshipView do
  @moduledoc """
  Defines `"show_relationhip.json-api"` `render/2` clauses that defer to `render_relationship/2` and
  `render_relationship_links/1` callbacks.
  """

  alias Alembic.ResourceIdentifier

  import Calcinator.RelatedView, only: [base_url: 1, relationship: 1]

  # Functions

  def render("show_relationship.json-api", options) do
    %Alembic.Document{
      jsonapi: %{
        version: "1.0"
      },
      data: data(options),
      links: links(options)
    }
  end

  ## Private Functions

  defp data(%{
         related: %{
           resource: nil
         }
       }) do
    nil
  end

  defp data(%{
         conn: conn,
         related: %{
           resource: related_resources,
           view_module: view_module
         }
       })
       when is_list(related_resources) do
    Enum.map(related_resources, &resource_identifier(&1, %{conn: conn, view_module: view_module}))
  end

  defp data(%{
         conn: conn,
         related: %{
           resource: related,
           view_module: view_module
         }
       }) do
    resource_identifier(related, %{conn: conn, view_module: view_module})
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
      related: "#{base_url}/#{relationship}",
      self: "#{base_url}/relationships/#{relationship}"
    }
  end

  defp resource_identifier(resource, %{conn: conn, view_module: view_module}) do
    id =
      resource
      |> view_module.id(conn)
      |> to_string()

    %ResourceIdentifier{
      type: view_module.type(),
      id: id
    }
  end
end
