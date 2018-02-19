defmodule Calcinator.Authorization.SubjectLess do
  @moduledoc """
  Allows all actions to all targets, but only if there is no `subject`.  Only use if your system wants no authorization
  at all.
  """

  @behaviour Calcinator.Authorization

  @doc """
  Allows all actions to all targets, as long as no subject is tracked

      iex> Calcinator.Authorization.SubjectLess.can?(nil, :show, Calcinator.Resources.TestAuthor)
      true

  Raises an `ArgumentError` if a `subject` is given, to prevent improper use.

      iex> try do
      ...>   Calcinator.Authorization.SubjectLess.can?(
      ...>     %Calcinator.Resources.TestAuthor{id: 1},
      ...>     :show,
      ...>     %Calcinator.Resources.TestAuthor{id: 2}
      ...>   )
      ...> rescue
      ...>   error in ArgumentError ->
      ...>     error
      ...> end
      %ArgumentError{
        message: "Calcinator.Authorization.SubjectLess.can?/3 should only be called with a `nil` subject, " <>
                 "but was called with " <>
                 "`%Calcinator.Resources.TestAuthor{__meta__: #Ecto.Schema.Metadata<:built, \\"authors\\">, id: 1, " <>
                 "name: nil, password: nil, password_confirmation: nil, " <>
                 "posts: #Ecto.Association.NotLoaded<association :posts is not loaded>}`"
      }

  """
  @impl Calcinator.Authorization
  def can?(nil, _, _), do: true

  def can?(subject, _, _) do
    raise ArgumentError,
          "#{inspect(__MODULE__)}.can?/3 should only be called with a `nil` subject, " <>
            "but was called with `#{inspect(subject)}`"
  end

  @doc """
  Allows all associations on target, as long as no subject is tracked

      iex> Calcinator.Authorization.SubjectLess.filter_associations_can(
      ...>   %Calcinator.Resources.TestAuthor{
      ...>     id: 1,
      ...>     posts: [
      ...>       %Calcinator.Resources.TestPost{
      ...>         id: 2
      ...>       }
      ...>     ]
      ...>   },
      ...>   nil,
      ...>   :show
      ...> )
      %Calcinator.Resources.TestAuthor{
        id: 1,
        posts: [
          %Calcinator.Resources.TestPost{
            id: 2
          }
        ]
      }

  Raises an `ArgumentError` if a `subject` is given, to prevent improper use.

      iex> try do
      ...>   Calcinator.Authorization.SubjectLess.filter_associations_can(
      ...>     %Calcinator.Resources.TestAuthor{
      ...>       id: 1,
      ...>       posts: [
      ...>         %Calcinator.Resources.TestPost{
      ...>           id: 2
      ...>         }
      ...>       ]
      ...>     },
      ...>     %Calcinator.Resources.TestAuthor{id: 1},
      ...>     :show
      ...>   )
      ...> rescue
      ...>   error in ArgumentError ->
      ...>     error
      ...> end
      %ArgumentError{
        message: "Calcinator.Authorization.SubjectLess.filter_associations_can/3 should only be called with a `nil` " <>
                 "subject, but was called with " <>
                 "`%Calcinator.Resources.TestAuthor{__meta__: #Ecto.Schema.Metadata<:built, \\"authors\\">, id: 1, " <>
                 "name: nil, password: nil, password_confirmation: nil, " <>
                 "posts: #Ecto.Association.NotLoaded<association :posts is not loaded>}`"
      }

  """
  @impl Calcinator.Authorization
  def filter_associations_can(target, nil, _), do: target

  def filter_associations_can(_, subject, _) do
    raise ArgumentError,
          "#{inspect(__MODULE__)}.filter_associations_can/3 should only be called with a `nil` subject, " <>
            "but was called with `#{inspect(subject)}`"
  end

  @doc """
  Allows all targets, as long as no subject is tracked

      iex> Calcinator.Authorization.SubjectLess.filter_can(
      ...>   [
      ...>     %Calcinator.Resources.TestPost{id: 2},
      ...>     %Calcinator.Resources.TestAuthor{id: 1}
      ...>   ],
      ...>   nil,
      ...>   :show
      ...> )
      [
        %Calcinator.Resources.TestPost{id: 2},
        %Calcinator.Resources.TestAuthor{id: 1}
      ]

  Raises an `ArgumentError` if a `subject` is given, to prevent improper use.

      iex> try do
      ...>   Calcinator.Authorization.SubjectLess.filter_can(
      ...>     [
      ...>       %Calcinator.Resources.TestPost{id: 2},
      ...>       %Calcinator.Resources.TestAuthor{id: 1}
      ...>     ],
      ...>     %Calcinator.Resources.TestAuthor{id: 2},
      ...>     :show
      ...>   )
      ...> rescue
      ...>   error in ArgumentError ->
      ...>     error
      ...> end
      %ArgumentError{
        message: "Calcinator.Authorization.SubjectLess.filter_can/3 should only be called with a `nil` subject, but " <>
                 "was called with " <>
                 "`%Calcinator.Resources.TestAuthor{__meta__: #Ecto.Schema.Metadata<:built, \\"authors\\">, id: 2, " <>
                 "name: nil, password: nil, password_confirmation: nil, " <>
                 "posts: #Ecto.Association.NotLoaded<association :posts is not loaded>}`"
      }

  """
  @impl Calcinator.Authorization
  def filter_can(targets, nil, _), do: targets

  def filter_can(_, subject, _) do
    raise ArgumentError,
          "#{inspect(__MODULE__)}.filter_can/3 should only be called with a `nil` subject, " <>
            "but was called with `#{inspect(subject)}`"
  end
end
