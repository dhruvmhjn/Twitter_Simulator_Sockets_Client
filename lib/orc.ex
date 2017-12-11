defmodule Orc do
    use GenServer
    def start_link(numClients,acts,subPercent,servernode) do
        myname = String.to_atom("orc")
        return = GenServer.start_link(__MODULE__, {numClients,acts,subPercent,servernode}, name: myname )
        return
    end
    def init({numClients,acts,subPercent,servernode}) do
        {:ok,{numClients,acts,subPercent,0,0,servernode,[],""}}
    end
    def handle_cast({:spawn_completed,list},{numClients,acts,subPercent,numRegistered,numCompleted,servernode,_,_}) do
        IO.puts "Registering clients"
        {:ok, osocketpind} = Orcsocket.start_link(servernode)
        #extract pids
        pids = Enum.map(list, fn(x)-> elem(x,1) end)
        #send connect message

        Enum.map(pids, fn(pid)-> send pid, :connect end)
        {:noreply,{numClients,acts,subPercent,numRegistered,numCompleted,servernode,pids,osocketpind}}
    end


    def handle_cast({:registered},{numClients,acts,subPercent,numRegistered,numCompleted,servernode,pids,osocketpind})do
        numRegistered = numRegistered+1
        if numRegistered == numClients+1 do
            IO.puts "Finished registration."
            GenServer.cast(:orc,{:begin_activate})
         end
         {:noreply,{numClients,acts,subPercent,numRegistered,numCompleted,servernode,pids,osocketpind}}
    end

    def handle_cast({:begin_activate},{numClients,acts,subPercent,numRegistered,numCompleted,servernode,pids,osocketpind})do
        #IO.puts "Activating clients, and starting time measurement."
        #rangemax = :math.pow(10,String.length(Integer.to_string(numClients)-2))
        #IO.puts subPercent
        
        n_list = Enum.to_list 1..numClients
        sub_list = Enum.map(1..numClients, fn(_)-> Enum.map(Range.new(1,subPercent), fn(_)-> bais(numClients) end) end)
        Enum.map(n_list, fn(x)-> send Enum.at(pids,x-1), {:activate,Enum.uniq(Enum.at(sub_list,x-1))} end)
        #start_time = System.system_time(:millisecond)
        {:noreply,{numClients,acts,subPercent,numRegistered,numCompleted,servernode,pids,osocketpind}}
    end
    
    def handle_cast({:acts_completed},{numClients,acts,subPercent,numRegistered,numCompleted,servernode,pids,osocketpind}) do
        numCompleted= numCompleted + 1
        if(numCompleted == numClients) do
            #Process.sleep(1000)
            IO.puts ("Request generation completed, messages getting delivered. Pls wait.")
            #GenServer.cast({:server,servernode},{:all_completed})
            send List.last(pids),{:terminate, osocketpind}
            #send osocketpind, :terminate
            #:init.stop
        end
        {:noreply,{numClients,acts,subPercent,numRegistered,numCompleted,servernode,pids,osocketpind}}
    end

    def bais(numClients) do
        case rem(:rand.uniform(99999),7) do
            1 ->
                :rand.uniform(round(Float.ceil(numClients*0.1)))
            2 ->
                :rand.uniform(round(Float.ceil(numClients*0.1)))
            3 ->
                :rand.uniform(round(Float.ceil(numClients*0.6)))
            4 ->
                :rand.uniform(numClients)
            5 ->
                :rand.uniform(numClients)
            _ ->
                :rand.uniform(round(Float.ceil(numClients*0.01)))
        end
    end
end

# def handle_cast({:simulate_disconnection},{numClients,acts,subPercent,numRegistered,numCompleted,servernode,start_time}) do
#     client = :rand.uniform(numClients)
#     time = :rand.uniform(5)*500
#     GenServer.cast(String.to_atom("user"<>Integer.to_string(client)),{:disconnect,time})
#     Process.sleep(3000)
#     GenServer.cast(self(),{:simulate_disconnection})
#     {:noreply,{numClients,acts,subPercent,numRegistered,numCompleted,servernode,start_time}}
# end