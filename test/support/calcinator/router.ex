defmodule Calcinator.Router do
  @moduledoc """
  Router configuration and mapping file.  Scopes must be "piped" through a pipeline.  Only current pipeline is :api for
  JSON:API only requests and responses
  """

  use Phoenix.Router

  pipeline :api do
    plug(:accepts, ["json-api"])
    plug(JaSerializer.ContentTypeNegotiation)
    plug(JaSerializer.Deserializer)
  end

  scope "/api", Calcinator do
    pipe_through(:api)

    resources("/test-posts", TestPostController)
  end
end
