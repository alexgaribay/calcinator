defmodule Calcinator.Resources.Ecto.Repo.Repo.Migrations.AddPosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add(:author_id, references(:authors), null: false)
      add(:body, :string, null: false)

      timestamps()
    end
  end
end
