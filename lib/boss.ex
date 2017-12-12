defmodule Boss do
    def main(args) do 
        parse_args(args)
    end
    defp parse_args(args) do
        cmdarg = OptionParser.parse(args)

        {[],argstr,[]} = cmdarg
        [numClients,minActs,serverip]=argstr
        numClientsInt = String.to_integer(numClients)
        minActsInt = String.to_integer(minActs)
        subPercentInt= cond do
            numClientsInt >= 10000 ->
                100
            numClientsInt >= 100 ->
                10
            true ->
                1
        end
        #IO.puts subPercentInt
        :global.register_name(:client_boss, self())
        ClientSupervisor.start_link([numClientsInt,minActsInt,subPercentInt,serverip]) 
        boss_receiver()
    end

    def boss_receiver() do
        receive do
            {:all_requests_served_s} ->
                {:ok}              
         end
        boss_receiver()  
    end
end