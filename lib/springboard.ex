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


defmodule SpringBoard.UUID do
  @moduledoc """
    Helper module for generating unique user ids. The UUID generated here
    differs from Ecto.UUID by removing all the dashes/separators.

    It also supports optional UUID prefixes.

    # Examples:
    iex> UUID.generate("evt_")
    iex> evt_9vbkjhfkfcjddfk87654yu
    """
  import SpringBoard

  def generate_prefix(model) when is_map(model) do
    generate_prefix(model.__struct__)
  end

  def generate_prefix(thing) do
  (thing
   |> do_generate_prefix
   |> String.downcase) <> "_"
  end

  defp do_generate_prefix(word) do
    case String.length(word) do
      wc when wc <= 3 ->
        word
      wc when wc >= 4 ->
        String.slice(word, 0..2)
    end
  end

  def generate(prefix \\ "", allow_caps? \\ false) do
    uuid = :erlang.system_time |> to_string |> md5

    unless allow_caps? do
      prefix <> random_casetoggle(uuid)
    else
      prefix <> uuid
    end
  end

  @doc """
  Randomly upcases a character in a string.

  This is meant to be used in conjunction with ``UUID.geneate``
  """
  def random_casetoggle(word, to_case \\ :lower) do
    if is_list(word) do
      do_random_casetoggle(word, [], to_case)
    else
      String.split(word,"") |> do_random_casetoggle([], to_case)
    end
  end

  defp do_random_casetoggle([], xs, _to_case) do
    xs |> Enum.reverse |> Enum.join("")
  end

  defp do_random_casetoggle([""|rest], xs, to_case) do
    do_random_casetoggle(rest, xs, to_case)
  end

  defp do_random_casetoggle([x|rest], xs, to_case) do
    new_x = toggle_case(to_case, x)
    do_random_casetoggle(rest, [new_x|xs], to_case)
  end

  defp toggle_case(:lower, x) do
    to_lower? = upper_case?(x) && Enum.random([true, false])
    if to_lower? do
      to_string(x) |> String.downcase
    else
      to_string(x)
    end
  end

  defp toggle_case(:upper, x) do
    to_upper? = lower_case?(x) && Enum.random([true, false])
    if to_upper? do
      to_string(x) |> String.upcase
    else
      to_string(x)
    end
  end
end


defmodule SpringBoard.Keygen do
  @moduledoc """
  Generates secret and public API keys for the given environment

  ### Examples

       iex> {sk, pk} = SpringBoard.Keygen.new_keys("test")
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


defmodule SpringBoard.IExHelpers do
  @doc "Recompiles and reloads app"
  def rr(app \\ nil) do
    IEx.Helpers.recompile
    app = app || :application.get_application
    # restart app
    :ok = Application.ensure_started(app)
  end

  @doc "Lookup documentation on Erlang modules etc"
  def hh(thing), do: Erlh.h thing

  if Code.ensure_loaded(Mix) && Mix.env == :dev do
    import Mex
    Mex.set_width 160
  end
end

# TODO: idempotency, basic auth, iex helpers, model.ex, serializer.ex etc
