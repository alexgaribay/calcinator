defmodule Calcinator.Authorization.Can do
  @moduledoc """
  `Calcinator.Authorization` where `filter_associations_can/3` and `filter_can/3` are implemented in terms of `can/3`,
  so only `can/3` needs to be implemented.
  """

  alias Calcinator.Authorization

  # Types

  @typedoc """
  A module that implements the `Calcinator.Authorization.can?/3` callback
  """
  @type t :: module

  # Macros

  @doc """
  Uses `Calcinator.Authorization.Can.filter_associations_can/4` for `Calcinator.Authorization.filter_associations_can/3`
  and `Calcinator.Authorization.Can.filter_can/4` for `Calcinator.Authorization.filter_can/3`, so using module only need
  to implement `Calcinator.Authorization.can?/3`.
  """
  defmacro __using__([]) do
    quote do
      alias Calcinator.{Authorization, Authorization.Can}

      @behaviour Authorization

      @impl Authorization
      def filter_associations_can(target, subject, action) do
        Can.filter_associations_can(target, subject, action, __MODULE__)
      end

      @impl Authorization
      def filter_can(target, subject, action) do
        Can.filter_can(target, subject, action, __MODULE__)
      end
    end
  end

  # Functions

  @doc """
  `nil` out all associations where the `subject` can't do `action` on the association's model
  """
  @spec filter_associations_can(struct, Authorization.subject(), Authorization.action(), t) :: struct
  def filter_associations_can(model = %{__struct__: ecto_schema}, subject, action, callback_module) do
    :associations
    |> ecto_schema.__schema__()
    |> Enum.reduce(model, fn association_name, acc ->
      Map.update!(acc, association_name, &filter_association_can(&1, [acc], subject, action, callback_module))
    end)
  end

  @spec filter_associations_can([struct], Authorization.subject(), Authorization.action(), t) :: [struct]
  def filter_associations_can(models, subject, action, callback_module) when is_list(models) do
    models
    |> filter_can(subject, action, callback_module)
    |> Enum.map(&filter_associations_can(&1, subject, action, callback_module))
  end

  @doc """
  Filters `models` to only those where `subject` can do `action` to a specific model in `models`.
  """
  @spec filter_can([struct], Authorization.subject(), Authorization.action(), t) :: [struct]
  def filter_can(models, subject, action, callback_module) when is_list(models) do
    Enum.filter(models, &callback_module.can?(subject, action, &1))
  end

  @doc """
  Filters `association_models` to only those `association_model`s where `subject` can do `action` on the combined
  association path of `[association_model | association_ascent]`.
  """
  @spec filter_can([struct], Authorization.association_ascent(), Authorization.subject(), Authorization.action(), t) ::
          [struct]
  def filter_can(association_models, association_ascent, subject, action, callback_module)
      when is_list(association_models) and is_list(association_ascent) do
    Enum.filter(association_models, &callback_module.can?(subject, action, [&1 | association_ascent]))
  end

  ## Private Functions

  #  `nil` out association if the `subject` can't do `action` on the association's model.  Otherwise, recursively
  #  `filter_associations_can` on the association model's associations.
  @spec filter_association_can(
          nil,
          Authorization.association_ascent(),
          Authorization.subject(),
          Authorization.action(),
          t
        ) :: nil
  @spec filter_association_can(
          struct,
          Authorization.association_ascent(),
          Authorization.subject(),
          Authorization.action(),
          t
        ) :: struct | nil
  @spec filter_association_can(
          [struct],
          Authorization.association_ascent(),
          Authorization.subject(),
          Authorization.action(),
          t
        ) :: [struct]

  defp filter_association_can(nil, _, _, _, _), do: nil
  defp filter_association_can(not_loaded = %Ecto.Association.NotLoaded{}, _, _, _, _), do: not_loaded

  defp filter_association_can(association_models, association_ascent, subject, action, callback_module)
       when is_list(association_models) do
    association_models
    |> filter_can(association_ascent, subject, action, callback_module)
    |> filter_associations_can(association_ascent, subject, action, callback_module)
  end

  defp filter_association_can(association_model, association_ascent, subject, action, callback_module) do
    if callback_module.can?(subject, action, [association_model | association_ascent]) do
      filter_associations_can(association_model, association_ascent, subject, action, callback_module)
    else
      nil
    end
  end

  # `nil` out all associations where the `subject` can't do `action` on the association's model

  @spec filter_associations_can(
          struct,
          Authorization.association_ascent(),
          Authorization.subject(),
          Authorization.action(),
          t
        ) :: struct
  defp filter_associations_can(
         association_model = %ecto_schema_module{},
         association_ascent,
         subject,
         action,
         callback_module
       ) do
    :associations
    |> ecto_schema_module.__schema__()
    |> Enum.reduce(association_model, fn association_name, acc ->
      Map.update!(
        acc,
        association_name,
        &filter_association_can(&1, [acc | association_ascent], subject, action, callback_module)
      )
    end)
  end

  @spec filter_associations_can(
          [struct],
          Authorization.association_ascent(),
          Authorization.subject(),
          Authorization.action(),
          t
        ) :: [struct]
  defp filter_associations_can(association_models, association_ascent, subject, action, callback_module)
       when is_list(association_models) do
    association_models
    |> filter_can(association_ascent, subject, action, callback_module)
    |> Enum.map(&filter_associations_can(&1, association_ascent, subject, action, callback_module))
  end
end
