defmodule SpringBoard.ApiAuth do
  @behaviour Plug
  @moduledoc """
  Plug for authenticating Api requests.
  """
  @realm "Secret"
  alias Plug.Conn
  alias SpringBoard.{Repo, UserSerializer, AppSerializer}
  alias SpringBoard.Web.Context
  alias SpringBoard.Web.ApiKey

  @freepass_credentials {"sk_test_dAr7QeOyb4KaDXA33wyL5pYo", ""}

  def init(opts), do: opts

  def call(conn, opts) do
    if opts[:allow] && free_pass?(conn, opts[:allow]) do
      maybe_authenticate(conn, @freepass_credentials)
    else
      maybe_authenticate(conn, conn.assigns[:credentials])
    end
  end

  def free_pass?(conn, allowed_paths) do
    conn_method = String.downcase(conn.method)|> String.to_atom
    request_path =
      (if String.ends_with?(conn.request_path, "/") do
         conn.request_path
       else
         conn.request_path <> "/"
       end)
    freepassers =
      (Enum.filter(allowed_paths, fn {method, path, callback} ->
          path = if(String.ends_with?(path, "/"), do: path, else: path <> "/")
          (method == conn_method) &&
          (request_path == path) &&
          callback.(conn.params) end))

    not(Enum.empty?(freepassers))
  end

  defp maybe_authenticate(conn, {nil, _}) do
      Blaguth.halt_with_login(conn, @realm)
  end

  defp maybe_authenticate(conn, {req_secret_key, _}) do
    if api_key = ApiKey.valid_secret_key?(req_secret_key) do
      context = conn |> build_context(api_key, req_secret_key)

      Conn.assign(conn, :req_context, context)
    else
      Blaguth.halt_with_login(conn, @realm)
    end
  end

  defp build_context(conn, api_key, req_secret_key) do
    env = String.to_atom(api_key.env)
    user = UserSerializer.to_map(Repo.preload(api_key.app, :user).user)
    # match the request api key and also the ApiKey model's env field
    livemode? = Regex.match?(~r/^sk_live/, req_secret_key) && env == :live
    request_id = :proplists.get_value("x-request-id", conn.resp_headers)
    idempotency_key =
      case :proplists.get_value("idempotency-key", conn.req_headers) do
        :undefined -> nil
        val -> val
      end

    %Context{
      api_key: req_secret_key,
      env: env,
      app: AppSerializer.to_map(api_key.app),
      user: user,
      request_id: request_id,
      url: conn.request_path,
      livemode?: livemode?,
      idempotency_key: idempotency_key
     }
  end
end
