defmodule Calcinator.Resources.Ecto.Repo.Repo.Migrations.AddAuthors do
  use Ecto.Migration

  def change do
    create table(:authors) do
      add(:name, :string, null: false)
    end
  end
end
