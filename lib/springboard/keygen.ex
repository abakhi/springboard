defmodule SpringBoard.KeyGen do
  @moduledoc """
  Generates secret and public API keys for the given environment

  ### Examples

       iex> {sk, pk} = SpringBoard.KeyGen.new_keys("test")
  """
  import SpringBoard, only: [app_env: 1]

  @salt    app_env(:keygen_salt) || "coYid8oi"
  @coder   Hashids.new([salt: @salt, min_len: 24])
  @env     :test
  @envs    [:live, :test]
  @scopes  [:public, :secret]

  @type secret_key :: String.t
  @type public_key :: String.t

  @spec new_keys(atom) :: {secret_key, public_key}
  def new_keys(env \\ @env) when env in @envs do
    {new_key(env, :secret), new_key(env, :public)}
  end

  @doc """
  Generates a key for the given environment.

  ### Accepted environments
  - :test
  - :live
  """
  @spec new_key(atom, String.t) :: String.t
  def new_key(env \\ @env, scope) when scope in @scopes and env in @envs do
    case scope do
      :public -> "pk_#{env}_#{key}"
      :secret -> "sk_#{env}_#{key}"
    end
  end

  defp key, do: get_time |> encode

  defp get_time do
    :erlang.system_time
  end

  def encode(data) do
    Hashids.encode(@coder, data)
  end

  def decode(data) do
    Hashids.decode(@coder,data)
  end
end
