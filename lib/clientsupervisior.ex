defmodule ClientSupervisor do
    use Supervisor
    def start_link([clients,acts,subPercent,servernode]) do
        return = {:ok,sup} = Supervisor.start_link(__MODULE__,{clients,acts,servernode},[])
        list = Supervisor.which_children(sup)
        IO.puts "In supervisor"
        IO.inspect list
        start_workers(sup,clients,acts,subPercent,servernode)
        GenServer.cast(:orc,{:spawn_completed,list})        
        return
    end
    def init({clients,acts,servernode}) do
        n_list = Enum.to_list 1..clients
        children = Enum.map(n_list, fn(x)->worker(Client, [x,clients,servernode,acts], [id: "client#{x}"]) end)
        supervise children, strategy: :one_for_one
    end
    def start_workers(sup,numClients,acts,subPercent,servernode) do
        {:ok, orcid} = Supervisor.start_child(sup, worker(Orc, [numClients,acts,subPercent,servernode]))                      
    end

end