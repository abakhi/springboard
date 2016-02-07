defmodule SpringBoard.Web.Response do
  @moduledoc """

    A response from the SpringBoard API server.
    Each API requst has an associated requested ID to help in debugging.
    Find the request ID the ```Request-Id``` HTTP response.

    The standard errors are mapped to a subset of HTTP codes

    * 200 - OK                    Everything worked as expected.
    * 201 - Created               Successfull POST call
    * 303 - See Other             Sent by handlers to return results that it considers optional
    * 304 - Not modified          Sent to preserve bandwidth (with conditional GET)
    * 400 - Bad Request           Often missing a required parameter.
    * 401 - Unauthorized          No valid API key provided.
    * 402 - Request Failed        Parameters were valid but request failed.
    * 403 - Forbidden
    * 404 - Not Found             The requested item doesn't exist.
    * 405 -  Method Not Allowed   HTTP method not allowed
    * 406 -  Not Acceptable       Sent when the client tried to request data in
      an unsupported media type   format
    * 500, 502, 503, 504          Server Errors, something wrong on SpringBoard server
  """
  @type t :: %__MODULE__{}

  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn, only: [put_status: 2]
  import SpringBoard.Web, only: [resource: 1]
  alias SpringBoard.Web.Idempotency
  alias SpringBoard.Web.Request.Error

  @derive [Poison.Encoder]
  defstruct [
    object: nil,
    url: nil,
    livemode: false,
    status: :success,
  ]

  @doc """
  Provides shorcut for building error responses, so intead of
  *build_response(conn, data, %{error: error})*, you call *build_error(conn, error)*
  """
  @spec build_error(Plug.Conn.t, Map.t) :: SpringBoard.Web.Response.t
  def build_error(conn, error) do
    build_response(conn, %{}, %{error: error})
  end

  @spec build_response(Plug.Conn.t, Ecto.Model.t, Map.t) :: SpringBoard.Web.Response.t
  def build_response(conn, data, meta \\ %{}) do
    ctx = conn.assigns.req_context
    error = meta[:error]
    status = (if error, do: :error, else: :success)
    resp =
      %__MODULE__{
         url: ctx.url,
         livemode: ctx.livemode,
         status: status,
      }
    conn_rsc = resource(conn)

    output =
       ((if is_list(data) do
           Map.merge(resp, %{object: meta[:resource] || :list})
           |> Map.merge(%{has_more: false})
         else
           object = (meta[:resource] || conn_rsc) |> String.downcase
           Map.merge(resp, %{object: object})
         end) |> Map.delete(:__struct__))

    if error do
      Map.merge(output, %{error: error})
    else
      if is_list(data) do
        Map.merge(output, %{data: data})
      else
        Map.merge(output, data)
      end
    end
  end

  @doc """
  Serializes the model data into JSON for the client. Gueses the serializer name
  from the resources being accessed.
  """
  @spec render_json(Plug.Conn.t, term) :: Plug.Conn.t
  def render_json(conn, data) do
    resp_data =
      Module.concat(Mix.Phoenix.base, "#{resource(conn)}Serializer")
      |> apply(:to_map, [data])

     render_with_idempotency(conn, build_response(conn, resp_data))
  end

  @doc """
  Like `render_json` but without guessing the serializer,
  so just passes it down to `render_ok`
  """
  def render_json!(conn, data) do
    render_ok(conn, data)
  end

  def render_ok(conn, data \\  %{}) do
    render_with_idempotency(conn, build_response(conn, data))
  end

  @doc """
  Error formatter:
  - For returning changeset errors to the clients
  - JSON error outputs for SpringBoard.Web.Request.Error
  - Generic errors
  """
  @spec render_error(Plug.Conn.t, map) :: Plug.Conn.t
  def render_error(conn, changeset = %Ecto.Changeset{}) do
    errors = Enum.map(changeset.errors, fn {field, detail} ->
      {field, render_error_detail(detail)}
    end)
    conn
    |> put_status(:unprocessable_entity)
    |> render_error(Error.invalid_params(errors: kw_to_map(errors)))
  end

  defp kw_to_map(errors) do
    Enum.into(errors, %{},
      fn {k,v} when is_list(v) -> {k, Map.new(v)};
        {k, v} -> {k, v}
      end)
  end

  def render_error(conn, error = %SpringBoard.Web.Request.Error{}) do
    conn = put_status(conn, error.code)
    error = build_error(conn, error)
    render_with_idempotency(conn, error)
  end

  def render_error(conn, error) do
    render_with_idempotency(conn, build_error(conn, error))
  end

  defp render_error_detail({message, values}) do
    Enum.reduce(values, message, fn {k, v}, acc ->
      String.replace(acc, "%{#{k}}", to_string(v))
    end)
  end

  defp render_error_detail(message) when is_binary(message) do
    message
  end

  defp render_error_detail(errors) when is_list(errors) do
    Enum.map(errors, fn {field, detail} ->
      {field, render_error_detail(detail)}
    end)
  end

  def render_with_idempotency(conn, data) do
    if conn.private[:save_idempotency] do
      key = conn.private[:idempotency_key]
      Idempotency.save_idempotency(key, data)
    end
    json(conn, data)
  end
end
