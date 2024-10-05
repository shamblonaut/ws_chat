defmodule Hub.Router do
  use Plug.Router
  require EEx

  plug(:match)
  plug(:dispatch)

  EEx.function_from_file(:defp, :chat_html, "priv/static/chat.html.eex", [])

  get "/" do
    send_resp(conn, 200, "Welcome to the hub!")
  end

  get "/chat" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, chat_html())
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
