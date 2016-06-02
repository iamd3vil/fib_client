defmodule FibClient.Receiver do
  @moduledoc """
  Receiver GenServer which sends message and sends the reply from
  the server to the appropriate client
  """
  use GenServer
  require Logger

  def start_link([connection]) do
    GenServer.start_link(__MODULE__, connection, [])
  end

  def init(connection) do
    {:ok, channel} = AMQP.Channel.open(connection)

    {:ok, %{queue: queue_name}} = AMQP.Queue.declare(channel, "", exclusive: true)
    AMQP.Basic.consume(channel, queue_name, nil, no_ack: true)
    {:ok, {channel, queue_name, %{}}}
  end

  def handle_call({:fib, number}, from, {channel, queue_name, clients}) do
    correlation_id = :crypto.rand_bytes(16) |> Base.encode64()
    new_state = clients
                |> Map.put(correlation_id, from)
    AMQP.Basic.publish(channel, "", "rpc_queue", to_string(number), reply_to: queue_name, correlation_id: correlation_id)
    {:noreply, {channel, queue_name, new_state}}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
    Logger.debug "[*] BASIC CONSUME OK"
    {:noreply, state}
  end

  @doc """
  Receives the message from rabbtimq and sends the reply to the appropriate client.
  It finds the appropriate client by the correlation_id and uses `GenServer.reply/2`
  to send the message to the client.
  """
  def handle_info({:basic_deliver, payload, %{correlation_id: correlation_id}}, {channel, queue_name, clients}) do
    Logger.debug "Getting message: #{payload} on #{inspect self}"
    # :timer.sleep(2000)
    client = Map.get(clients, correlation_id)
    GenServer.reply(client, payload)
    new_clients = Map.delete(clients, correlation_id)
    {:noreply, {channel, queue_name, new_clients}}
  end
end
