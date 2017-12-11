defmodule Client do
    require Logger
    alias Phoenix.Channels.GenSocketClient
    @behaviour GenSocketClient
  
    def start_link(x) do
        GenSocketClient.start_link(__MODULE__,Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,{x,"ws://192.168.0.5:4000/socket/websocket"})
    end
  
    def init({x,url}) do
      {:connect, url, [], %{first_join: true, ping_ref: 1, num: x}}
    end
  
    def handle_connected(transport, state) do
        Logger.info("connected")
        if (rem(state.num,2) == 1) do
            GenSocketClient.join(transport, "room:trio")
        else
            GenSocketClient.join(transport, "room:couple")
        end
        {:ok, state}
    end
  
    def handle_disconnected(reason, state) do
      Logger.error("disconnected: #{inspect reason}")
      Process.send_after(self(), :connect, :timer.seconds(1))
      {:ok, state}
    end
  
    def handle_joined(topic, _payload, _transport, state) do
      Logger.info("joined the topic #{topic}")
  
      if state.first_join do
        :timer.send_interval(:timer.seconds(10), self(), :ping_server)
        {:ok, %{state | first_join: false, ping_ref: 1}}
      else
        {:ok, %{state | ping_ref: 1}}
      end
    end
  
    def handle_join_error(topic, payload, _transport, state) do
      Logger.error("join error on the topic #{topic}: #{inspect payload}")
      {:ok, state}
    end
  
    def handle_channel_closed(topic, payload, _transport, state) do
      Logger.error("disconnected from the topic #{topic}: #{inspect payload}")
      Process.send_after(self(), {:join, topic}, :timer.seconds(1))
      {:ok, state}
    end
  
    def handle_message(topic, event, payload, _transport, state) do
      Logger.warn("message on topic #{topic}: #{event} #{inspect payload} by client number #{state.num}")
      {:ok, state}
    end
  
    def handle_reply("ping", _ref, %{"status" => "ok"} = payload, _transport, state) do
      Logger.info("server pong ##{payload}")
      {:ok, state}
    end
    def handle_reply(topic, _ref, payload, _transport, state) do
      Logger.warn("reply on topic #{topic}: #{inspect payload} by client number #{state.num}")
      {:ok, state}
    end
  
    def handle_info(:connect, _transport, state) do
      Logger.info("connecting")
      {:connect, state}
    end
    def handle_info({:join, topic}, transport, state) do
      Logger.info("joining the topic #{topic}")
      case GenSocketClient.join(transport, topic) do
        {:error, reason} ->
          Logger.error("error joining the topic #{topic}: #{inspect reason}")
          Process.send_after(self(), {:join, topic}, :timer.seconds(1))
        {:ok, _ref} -> :ok
      end
  
      {:ok, state}
    end
    def handle_info(:ping_server, transport, state) do
        if (state.num == 1) do
            #GenSocketClient.join(transport, "room:trio")
            GenSocketClient.push(transport, "room:trio", "message:new", %{ping_ref: 333})
        end
        if(state.num == 2) do
            #GenSocketClient.join(transport, "room:couple")
            GenSocketClient.push(transport, "room:couple", "message:new", %{ping_ref: 222})
        end
      Logger.info("sending ping ##{state.ping_ref}")
      GenSocketClient.push(transport, "room:*", "message:new", %{ping_ref: state.ping_ref})
      {:ok, %{state | ping_ref: state.ping_ref + 1}}
    end
    def handle_info(message, _transport, state) do
      Logger.warn("Unhandled message #{inspect message}")
      {:ok, state}
    end
  end
  