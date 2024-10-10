defmodule WsChat.Database.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  schema "channel" do
    field(:name, :string)

    has_many(:messages, WsChat.Database.Message)

    timestamps()
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
