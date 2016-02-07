defmodule SpringBoard.Web.Request do
  @moduledoc """
  Delivery request object:

   - fields: for partial response. returns only selected object fields
   - metadata: key-value pairs
   - idempotency_key: key to ensure idempotency
   - livemode
   - sort: asc | desc
  """
  defstruct [
    fields: [],
    idempotency_key: nil,
    sort: :asc
  ]
  defmodule Error do
    @moduledoc """
    Object representing a request error

    - type: api_error, invalid_request_error,
    - message: Developer friendly message, usually an interpretation of the code
    - code:
      - incorrect_pin
      - payment_declined
      - processing_error
      - invalid_params
      - service_unavailable
      - request_limit_exceeded
      - not_found: object reference not found
      - request_rate_exceeded: max API reqeust rate
      - unauthorized
      - forbidden
      - server_error
    - more_info:
        - url: URL to see for more information on the error
        - message: A user-friendly message that can be directly shown to the user
        - errors: Key-Value pairs of error, useful for when request for creating
                  new resources that fail due to validation errors

    The error response can also include standarad HTTP error codes
    """
    @derive [Poison.Encoder]
    defstruct [:type, :message, :code, :more_info]

    @unauthorized        "UnAuthorized: either the API keys are missing or invlaid"
    @invalid_params      "Invalid Params: Missing or invalid request parameters"
    @forbidden           "Forbidden: you don't have the permission to acess this resource"
    @not_found           "Not Found: resource not found"
    @processing_errors   "Processing Errors: Parameters were valid but request failed"
    @service_unavailable "Service Unavailable: Something wrong on SpringBoard server"

    @default_info %{"message" => "There was an error processing this request", "errors" => %{}}

    @error_funcs  [
      not_found: {@not_found, 404},
      forbidden: {@forbidden, 403},
      unauthorized: {@unauthorized, 401},
      invalid_params: {@invalid_params, 400},
      processing_errors: {@processing_errors, 402},
      service_unavailable: {@service_unavailable, 500},
    ]

    error_funcs =
      quote bind_quoted: [funcs: @error_funcs], location: :keep do
      Enum.each funcs, fn {k, v} ->
        def unquote(k)(info \\ @default_info) do
          more_info =
          (cond do
             is_binary(info) -> %{"message" => info}
             is_list(info) ->
               Enum.map(info, fn {k, v} -> {to_string(k), v} end) |> Map.new
             is_map(info) -> info
          end)

          opts = %{message: elem(unquote(v), 0),
                   code: elem(unquote(v), 1),
                   more_info: Map.merge(@default_info, more_info)}
          do_error(unquote(k), opts)
        end
      end
    end

    Module.eval_quoted __MODULE__, error_funcs, [], __ENV__

    defp do_error(type, opts \\ %{}) do
      info = opts[:more_info]

      %__MODULE__{
              type:      type,
              code:      opts[:code],
              message:   opts[:message],
              more_info: if(is_list(info), do: Map.new(info), else: info)
          }
    end
  end
end
