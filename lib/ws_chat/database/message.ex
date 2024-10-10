defmodule WsChat.Database.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "message" do
    field(:content, :string)
    field(:author, :string)

    belongs_to(:channel, WsChat.Database.Channel)

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :author, :channel_id])
    |> validate_required([:content, :author, :channel_id])
  end
end
