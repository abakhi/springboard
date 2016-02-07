defmodule SpringBoard.Idempotency do
  @moduledoc """
  Plug for enforcing idempotency.

  Uses a Redis SET for saving and checking idempotent requests.

  ### Options

  - bucket: The redis bucket name

  ## Usage
  Use `plug SpringBoard.Idempotency` somewhere in your router pipeline, endpoint or
  the controller.

  # in your onctroller
  def render_with_idempotency(conn, data) do
    if conn.private[:save_idempotency] do
      key = conn.private[:idempotency_key]
      MyApp.Idempotency.save_idempotency(key, data)
    else
      json(conn, data)
    end
  end
  """
  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn, only: [put_resp_header: 3, put_private: 3, halt: 1]
  require Logger

  @bucket Application.get_env(:springboard, :idempotency_bucket) || "idempotency_bkt"
  @redis  SpringBoard.Redis

  def init(opts) do
    [bucket: opts[:bucket] || @bucket]
  end

  def call(conn, opts) do
    if conn.method == "POST", do: maybe_idempotempt(conn, opts), else: conn
  end

  defp maybe_idempotempt(conn, opts) do
    bucket = opts[:bucket]
    key = get_idempotency_key(conn)
    cond do
      key && key_exists?(key, bucket) ->
        return_idempotency(conn, key)
      key ->
        add_to_bucket(key, bucket)
        # turn on flag to save response body
        conn
        |> put_private(:save_idempotency, true)
        |> put_private(:idempotency_key, key)
      true ->
        conn
    end
  end

  @doc """
  Returns the `idempotency-key` header value if found. Otherwise, return nil.
  """
  @spec get_idempotency_key(Plug.Conn.t) :: nil | String.t
  defp get_idempotency_key(conn) do
    ctx = conn.assigns.req_context
    if ctx.idempotency_key, do: "#{ctx.api_key}:#{ctx.idempotency_key}"
  end

  @doc "Check if the key is in the Idempotency Redis bucket"
  @spec key_exists?(String.t, String.t) :: boolean
  def key_exists?(key, bucket) do
    case @redis.command(["SISMEMBER", "#{bucket}", "#{key}"]) do
      {:ok, 0} -> false
      {:ok, 1} -> true
    end
  end

  @spec add_to_bucket(String.t, String.t) :: Redix.Protocol.redis_value
  defp add_to_bucket(key, bucket) do
    @redis.command(["SADD", "#{bucket}", "#{key}"])
  end

  @spec save_idempotency(String.t, any) :: Redix.Protocol.redis_value
  def save_idempotency(key, data) do
    value = Poison.encode!(data)
    @redis.command(["SET", "#{key}", "#{value}"])
  end

  @spec return_idempotency(Plug.Conn.t, String.t) :: Plug.Conn.t
  defp return_idempotency(conn, key) do
    {:ok, value} = @redis.command(["GET", "#{key}"])
    resp_body = Poison.decode!(value)
    Logger.debug("Idempotent Request: #{key} \n: #{inspect resp_body}")

    conn
    |> put_resp_header("idempotency-key", key)
    |> json(resp_body)
    |> halt
  end
end
