defmodule Calcinator.Meta.Beam do
  @moduledoc """
  Stores and extracts BEAM metadata from JSONAPI meta.
  """

  # CONSTANTS

  @key "beam"
  @version :v1

  # Types

  @typedoc """
  A list of Ecto.Repo module names OR a single Ecto.Repo module name
  """
  @type repo :: [module, ...] | module

  @opaque version1_token :: %{required(:owner) => pid, required(:repo) => repo}

  @type token :: version1_token

  # Functions

  @doc """
  Decodes the repo and owner process for the connection.
  """
  @spec decode(String.t()) :: map | no_return
  def decode(encoded) do
    # See https://github.com/phoenixframework/phoenix_ecto/blob/90ba79feef55e31573047f789b3561f4ab7f30f6/lib/
    #   phoenix_ecto/sql/sandbox.ex#L73-L79
    encoded
    |> Base.url_decode64!()
    |> :erlang.binary_to_term()
    |> case do
      {@version, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  @doc """
  Encodes and versions the repo and current process, so it can be used for the connection ownership
  """
  @spec encode(repo | token) :: String.t()
  def encode(repo_or_token) do
    repo_or_token
    |> versioned
    |> :erlang.term_to_binary()
    |> Base.url_encode64()
  end

  @spec get(map) :: map
  def get(meta) do
    case Map.fetch(meta, @key) do
      {:ok, beam} -> decode(beam)
      :error -> %{}
    end
  end

  @doc """
  `repo` and owner process in a versioned format
  """
  @spec versioned(version1_token) :: {:v1, version1_token}
  def versioned(version1_token = %{owner: owner, repo: _}) when is_pid(owner), do: {@version, version1_token}

  @spec versioned(repo) :: {atom, token}
  def versioned(repo) do
    repo
    |> version1_token()
    |> versioned()
  end

  @doc """
  Puts BEAM metadata into `meta`
  """
  @spec put(map, repo | token) :: map
  def put(meta, repo_or_token), do: Map.put(meta, @key, encode(repo_or_token))

  @doc """
  Puts BEAM metadata into `meta` if its not already present
  """
  def put_new_lazy(meta, repo_or_token_generator) do
    Map.put_new_lazy(meta, @key, fn ->
      repo_or_token_generator.()
      |> encode()
    end)
  end

  ## Private Functions

  @spec version1_token(repo) :: version1_token
  def version1_token(repo) do
    %{owner: self(), repo: repo}
  end
end
