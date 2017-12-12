defmodule Client do
    require Logger
    alias Phoenix.Channels.GenSocketClient
    @behaviour GenSocketClient

    def start_link(x,clients,servernode,acts) do
        GenSocketClient.start_link(__MODULE__,Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,{x,clients,acts,"ws://"<>servernode<>":4000/socket/websocket"})
    end
  
    def init({x,clients,acts,url}) do
        {:noconnect, url, [], %{total: clients, activity: acts, num: x, tweet_cnt: 0, tweets_pool: [], first_join: true}}
    end
  
    def handle_connected(transport, state) do
        GenSocketClient.join(transport, "room:user"<>Integer.to_string(state.num))
        
        dummy_pool = ["160 characters from user #{state.num}.","COP5615 is a good course.","#{state.num} This is a sample tweet.","Random tweet from user.","One more random tweet.", "And one more."]
        
        #ZIPF: Randomly start tweeting/retweeting/subscribe/querying activities acc to zipf rank
        zipfcount = cond do
             state.num <= (state.total*0.01) ->
                 state.activity * 20
                 
             state.num <= (state.total*0.1) ->
                state.activity * 10
             
             state.num <= (state.total*0.6) ->
                state.activity * 2
 
             true ->
                state.activity
         end
        {:ok, %{state | tweets_pool: dummy_pool, activity: zipfcount}}
    end
  
    def handle_disconnected(reason, state) do
      Logger.warn("disconnected: #{inspect reason}")
      #Process.send_after(self(), :connect, :timer.seconds(5))
      {:ok, state}
    end
  
    def handle_joined(topic, _payload, _transport, state) do
        #Logger.info("joined the topic #{topic}")        
        if state.first_join do
            GenServer.cast(:orc,{:registered})
            #timer.send_interval(:timer.seconds(10), self(), :ping_server)
            {:ok, %{state | first_join: false}}
        else
            {:ok, state}
        end
    end

    def handle_join_error(topic, :already_joined, _transport, state) do
        Logger.warn("IGNORE")
        {:ok, state}
    end
  
    def handle_join_error(topic, payload, _transport, state) do
        IO.inspect(payload)
        if (payload == ":already_joined") do
        #nothing 
        else
            Logger.warn("join error on the stopic #{topic}: #{inspect payload}")            
        end
        {:ok, state}
    end
  
    def handle_channel_closed(topic, payload, _transport, state) do
      Logger.warn("disconnected from the topic #{topic}: #{inspect payload}")
      #Process.send_after(self(), {:join, topic}, :timer.seconds(1))
      {:ok, state}
    end
  
    def handle_message(topic, event, payload, transport, state) do
        msg = payload["tweet"]
        src = payload["source"]
        if (:rand.uniform(999) == 99) do
            rt_msg = if (Regex.match?(~r/^RT, Source:/ , msg)) do
                msg
            else
                "RT, Source: user#{src} Tweet: " <>msg
            end
            #IO.puts "Retweeting: "<>rt_msg
            #GenServer.cast({:server,servernode},{:tweet,x,rt_msg})
            GenSocketClient.push(transport, "room:user"<>Integer.to_string(state.num), "tweet:new", %{num: x, tweet: rt_msg, tweetcount: state.tweet_cnt})
        end 
      #Logger.warn("message on topic #{topic}: #{event} #{inspect payload} by client number #{state.num}")
      {:ok, %{state | tweet_cnt: state.tweet_cnt + 1}} 
    end

    # FOR EXTERNAL REPLIES< DO SEPCIFIC THINGS

    # # def handle_reply("ping", _ref, %{"status" => "ok"} = payload, _transport, state) do
    # #   Logger.info("server pong ##{payload}")
    # #   {:ok, state}
    # end

    def handle_reply(topic, _ref, payload, _transport, state) do
      #Logger.warn("reply on topic #{topic}: #{inspect payload} by client number #{state.num}")
      {:ok, state}
    end
  
    def handle_info(:connect, _transport, state) do
      #Logger.info("Now trying to connecting")
      {:connect, state}
    end

    #For EXTERNAL SUBSCRIBE

    # def handle_info({:join, topic}, transport, state) do
    #   Logger.info("joining the topic #{topic}")
    #   case GenSocketClient.join(transport, topic) do
    #     {:error, reason} ->
    #       Logger.error("error joining the topic #{topic}: #{inspect reason}")
    #       Process.send_after(self(), {:join, topic}, :timer.seconds(1))
    #     {:ok, _ref} -> :ok
    #   end
    #   {:ok, state}
    # end
    
    def handle_info({:activate, subscribe_to}, transport, state) do
        Enum.map(subscribe_to,fn(x) -> GenSocketClient.join(transport, "room:user"<>Integer.to_string(x)) end )
        send self(), :pick_random
        {:ok, state}
    end

    def handle_info(:pick_random, transport, state) do
        if(state.tweet_cnt < state.activity) do
            choice = rem(:rand.uniform(999999),14)
            case choice do
                1 ->
                    tweet_hash(state.num,state.tweets_pool,state.total,transport,state.tweet_cnt)

                2 ->
                    tweet_mention(state.num,state.tweets_pool,state.total,transport,state.tweet_cnt)

                3 ->
                    queryhashtags(state.num,transport)

                4 ->
                    query_self_mentions(state.num,transport)

                # 5 ->
                #     discon(state.num,state.tweets_pool,state.total,transport,state.tweet_cnt)
                6 ->
                    rand_subscribe(state.num,state.total,transport)

                _ ->
                    tweet(state.num,state.tweets_pool,transport,state.tweet_cnt)
            end
            
            #Process.sleep (:rand.uniform(200))
            #IO.puts "citsliein #{state.num} act #{state.tweet_cnt}"
            send self(), :pick_random
        else
            IO.puts "User #{state.num} has finised generating at least #{state.activity} activities (Tweets/Queries)."
            GenServer.cast(:orc, {:acts_completed})
        end
        {:ok, %{state | tweet_cnt: state.tweet_cnt + 1}}  
    end

    def handle_info({:time_to_stop, osocketpid}, transport, state) do
        #IO.puts "RECIEVED TERMINATE"

        #send osocketpid, :terminate
        #:init.stop
        {:ok, state} 
    end

    def handle_info(message, _transport, state) do
        Logger.warn("Unhandled message: #{inspect message}")
        {:ok, state}
    end

    def tweet(x,tweets_pool,transport,count) do
        #Generate a message
        msg = Enum.random(tweets_pool)
        #GenServer.cast({:server,servernode},{:tweet,x,msg})
        GenSocketClient.push(transport, "room:user"<>Integer.to_string(x), "tweet:new", %{num: x, tweet: msg, tweetcount: count})
    end

    def tweet_hash(x,tweets_pool,_,transport,count) do
        #Generate a message
        msg = Enum.random(tweets_pool) <> " #hashtag" <>Integer.to_string(:rand.uniform(999))
        #GenServer.cast({:server,servernode},{:tweet,x,msg})
        GenSocketClient.push(transport, "room:user"<>Integer.to_string(x), "tweet:new", %{num: x, tweet: msg, tweetcount: count})
    end

    def tweet_mention(x,tweets_pool,clients,transport,count) do
        msg = Enum.random(tweets_pool) <> " @user"<>Integer.to_string(:rand.uniform(clients))
        #GenServer.cast({:server,servernode},{:tweet,x,msg})
        GenSocketClient.push(transport, "room:user"<>Integer.to_string(x), "tweet:new", %{num: x, tweet: msg, tweetcount: count})
    end

    def rand_subscribe(x,clients,transport) do
        #Pick random user
        follow = :rand.uniform(clients)
        if follow != x do
            case GenSocketClient.join(transport, "room:user"<>Integer.to_string(follow)) do
                {:error, reason} ->
                    Logger.error("Can't follow user room:user"<>Integer.to_string(follow)<> ": #{inspect reason}")
                {:ok, _ref} -> :ok
            end
        end
    end
    
    def queryhashtags(x,transport) do
        #Pick a random hashtag
        hashtag = "#hashtag" <>Integer.to_string(:rand.uniform(999))
        GenSocketClient.push(transport, "room:user"<>Integer.to_string(x), "query:hashtag", %{num: x, hashtag: hashtag})
        #GenServer.cast({:server,servernode},{:hashtags,x,hashtag})
    end
    
    def query_self_mentions(x,transport) do
        mention = "@user"<>Integer.to_string(x)
        GenSocketClient.push(transport, "room:user"<>Integer.to_string(x), "query:mentions", %{num: x, mention: mention})        
        #GenServer.cast({:server,servernode},{:mentions,x,mention})
    end

    # def discon(x,servernode)do
    #     #stop all activities, play dead
    #     #inform server
    #     time = :rand.uniform(5)*10
    #     GenServer.cast({:server,servernode},{:disconnection,x})
    #     Process.sleep(time)
    #     GenServer.cast({:server,servernode},{:reconnection,x})
    # end

end
  