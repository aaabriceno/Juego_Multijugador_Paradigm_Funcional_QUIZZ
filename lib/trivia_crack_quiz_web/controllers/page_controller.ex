defmodule TriviaCrackQuizWeb.PageController do
  use TriviaCrackQuizWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
