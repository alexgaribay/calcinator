defmodule Calcinator.Resources.Ecto.Repo.Repo.Migrations.AddTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add(:name, :string, null: false)
    end
  end
end
