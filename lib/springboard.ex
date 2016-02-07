defmodule SpringBoard do
  @type key    ::  atom

  @doc """
  Generates an MD5 hash
  """
  @spec md5(String.t, boolean) :: String.t
  def md5(data, ch_case \\ :lower) do
    Base.encode16(:erlang.md5(data), case: ch_case)
  end

  @doc """
  Generates HMAC hash using sha256. The default key used is a random Mac address.
  """
  @spec hmac(String.t, String.t) :: String.t
  def hmac(data, key \\ nil) do
    key = key || Enum.random(macaddrs)
    :crypto.hmac(:sha256, key, data) |> Base.encode16
  end
  @doc """
  Returns the computer's MAC address
  """
  @spec macaddr :: String.t
  def macaddr, do: :macaddr.address |> to_string

  @doc """
  Returns a list of MAC addresses on this computer
  """
  @spec macaddrs :: [String.t]
  def macaddrs, do: :macaddr.address_list |> Enum.map(&to_string/1)

  @doc """
  Returns the value of the key in config
  """
  @spec app_env(key(), key()) :: any
  def app_env(env_name, default \\ nil) do
    :application.get_application
    |> Application.get_env(env_name, default)
  end

  def app_env_in(env_name, env_child, default \\ nil) do
    :application.get_application
    |> Application.get_env(env_name) |> Keyword.get(env_child, default)
  end

  @spec lower_case?(String.t) :: boolean
  def lower_case?(x) do
    a_to_z = ?a..?z |> Enum.to_list |> String.Chars.to_string
    String.contains?(a_to_z, x)
  end

  @spec upper_case?(String.t) :: boolean
  def upper_case?(x) do
    a_to_z = ?A..?Z |> Enum.to_list |> String.Chars.to_string
    String.contains?(a_to_z, x)
  end

  @spec is_character?(String.t) :: boolean
  def is_character?(ch) do
    upper_case?(ch) || lower_case?(ch)
  end

  @spec get_local_ip :: String.t
  def get_local_ip do
    {:ok, [{ip, _, _}|_]} = :inet.getif
    Tuple.to_list(ip) |> Enum.join(".")
  end

  @spec priv_dir :: String.t
  def priv_dir do
    case :code.priv_dir(__MODULE__) do
      {:error, _bad_name} ->
        ebin = Path.dirname(:code.which(__MODULE__))
        Path.join(Path.dirname(ebin), "priv")
      dir ->
        dir
    end
  end
end


# TODO: idempotency, basic auth, iex helpers, model.ex, serializer.ex etc
