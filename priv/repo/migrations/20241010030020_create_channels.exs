defmodule WsChat.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    create table(:channel) do
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:channel, [:name])

    create table(:message) do
      add :content, :string, size: 5000, null: false
      add :author, :string, null: false
      add :channel_id, references(:channel, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:message, [:channel_id])
  end
end
