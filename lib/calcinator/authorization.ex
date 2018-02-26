defmodule Calcinator.Authorization do
  @moduledoc """
  Behaviour for `Calcinator.Resources.t` `authorization_module`
  """

  # Types

  @typedoc """
  The actions that must be handled by `can?/3`, `filter_associations_can/3`, and `filter_can/3`.
  """
  @type action :: :create | :delete | :index | :update | :show

  @typedoc """
  A list of `Ecto.Schema.t` with the head being the near association and each successive element being the next
  `Ecto.Schema.t` following the associations back to the root `Ecto.Schema.t` for the action.

  Ascents are used, so that associations don't have to preload their parent to do `can?` checks.
  """
  @type association_ascent :: [struct, ...]

  @typedoc """
  The subject that is trying to do the action and needs to be authorized by `authorization_module`
  """
  @type subject :: term

  @typedoc """
  The target of the `subject`'s action
  """
  @type target :: term

  # Callbacks

  @doc """
  Checks whether `subject` (from `Calcinator.Resources.t` `subject`) can perform `action` on `target`.

  ## :create

    * `can?(subject, :create, ecto_schema_module) :: boolean` - called by `Calcinator.create/2` to check if `subject`
       can create `ecto_schema_module` structs in general.
    * `can?(subjecct, :create, Ecto.Changeset.t) :: boolean` - called by `Calcinator.create/2` to check if `subject`
       can create a specific changeset.

  ## :delete

    * `can?(subject, :delete, struct) :: boolean` - called by `Calcinator.delete/2` to check if `subject` can delete a
       specific `struct`.

  ## :index

    * `can?(subject, :index, ecto_schema_module) :: boolean` - called by `Calcinator.index/3` to check if `subject` can
       index `ecto_schema_module` structs in general.

  ## :show

    * `can?(subject, :show, struct) :: boolean` - called by `Calcinator.show/2` and `Calcinator.show_relationship/3` to
      check if `subject` can show a specific struct.
    * `can?(subject, :show, association_ascent) :: boolean` - called by `Calcinator.create/2`,
      `Calcinator.get_related_resource/3`, `Calcinator.index/3`, `Calcinator.show/2`, `Calcinator.show_relationship/3`,
      `Calcinator.update/2` to check if `subject` can show the head associated struct of the `association_ascent` list.

  ## :update

    * `can?(subject, :update, Ecto.Changeset.t) :: boolean` - called by `Calcinator.update/2` to check if `subject` can
      update a specific changeset.

  """
  @callback can?(subject, :create | :index, module) :: boolean
  @callback can?(subject, :create | :update, Ecto.Changeset.t()) :: boolean
  @callback can?(subject, :delete | :show, struct) :: boolean
  @callback can?(subject, action, target :: struct | association_ascent) :: boolean

  @doc """
  Reduces associations on `target` to only those where `can?(subject, action, associated_ascent)` is `true`.

  ## :show

    * `filter_associations_can(struct, subject, :show) :: struct` - called by `Calcinator.create/2`,
      `Calcinator.show/2`, and `Calcinator.update/2` filter the associations on the allowed target.
    * `filter_associations_can([struct], subject, :show) :: [struct]` - called by `Calciantor.index/2` after
      `filter_can([struct], subject, :show)` to filter the assocations of the allowed targets.
  """
  @callback filter_associations_can(target :: struct | [struct], subject, action) :: target

  @doc """
  Reduces `targets` to only those elements where `can?(subject, action, targets_element)` is `true`.

  ## :show

    * `filter_can([struct], subject, :show) :: [struct]` - called by `Calcinator.index/2` to filter the list of structs
      to only those where `can?(subject, :show, struct)` is `true`.

  """
  @callback filter_can(targets :: [struct], subject, action) :: [target]
end
