defmodule Orcsocket do
    require Logger
    alias Phoenix.Channels.GenSocketClient
    @behaviour GenSocketClient

    def start_link(servernode) do
        GenSocketClient.start_link(__MODULE__,Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,"ws://"<>servernode<>":4000/socket/websocket")
    end
  
    def init(url) do
      {:connect, url, [], %{first_join: true, ping_ref: 1}}
    end
  
    def handle_connected(transport, state) do
            GenSocketClient.join(transport, "room:sim")
        {:ok, state}
    end
  
    def handle_disconnected(reason, state) do
        #Logger.error("disconnected: #{inspect reason}")
        #Process.send_after(self(), :connect, :timer.seconds(1))
        {:ok, state}
    end
  
    def handle_joined(topic, _payload, _transport, state) do
        Logger.info("simulator joined the topic #{topic}")
        if state.first_join do
            GenServer.cast(:orc,{:registered})
            #timer.send_interval(:timer.seconds(10), self(), :ping_server)
            {:ok, %{state | first_join: false}}
        else
            {:ok, state}
        end
    end
  
    def handle_join_error(topic, payload, _transport, state) do
        Logger.warn("join error on the topic #{topic}: #{inspect payload}")
        {:ok, state}
    end
  
    def handle_channel_closed(topic, payload, _transport, state) do
        Logger.warn("disconnected from the topic #{topic}: #{inspect payload}")
        #Process.send_after(self(), {:join, topic}, :timer.seconds(1))
        {:ok, state}
    end
  
    def handle_message(topic, event, payload, _transport, state) do
        Logger.warn("message on topic #{topic}: #{event} #{inspect payload} by client number #{state.num}")
        {:ok, state}
    end
  
    def handle_reply(topic, _ref, payload, _transport, state) do
        Logger.warn("reply on topic #{topic}: #{inspect payload} by client number #{state.num}")
        {:ok, state}
    end

    def handle_info(:terminate,transport,state) do
        GenSocketClient.push(transport, "room:sim", "simulator:end", %{paylod: "stop_all"})   
    end
    
    def handle_info(message, _transport, state) do
        Logger.warn("Unhandled message #{inspect message}")
        {:ok, state}
    end

  end
  