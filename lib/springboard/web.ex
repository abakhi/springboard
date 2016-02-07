defmodule SpringBoard.Web do
  defmodule Context do
    @moduledoc """
    Request context that is available on the HTTP request connection.
    """
    defstruct [
      :api_key,
      :env,
      :app,
      :user,
      :livemode,
      :request_id,
      :object,
      :url,
      :idempotency_key,
    ]
  end

  @doc """
  Returns the object/resource being accessed by the request
  """
  @spec resource(Plug.Conn.t) :: String.t
  def resource(conn) do
    ctrl =
       conn
       |> Phoenix.Controller.controller_module
       |> Module.split
       |> Enum.at(1)

    # "Controller" is of length 10
    String.slice(ctrl, 0, String.length(ctrl)-10)
  end
end
