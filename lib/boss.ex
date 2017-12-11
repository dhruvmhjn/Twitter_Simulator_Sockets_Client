defmodule Boss do
    def main(args) do 
        parse_args(args)
    end
    defp parse_args(args) do
        cmdarg = OptionParser.parse(args)

        {[],argstr,[]} = cmdarg
        sregex = ~r/^server/

        if Regex.match?(sregex,Enum.at(argstr,0)) do
            #Server Twitter Engine
        else
            #Client Simulators
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
            end
        end
        boss_receiver()
    end         
    def boss_receiver() do
        receive do
            {:all_requests_served_s} ->
                IO.puts "All requests served, engine terminating. Check simulator console for summary stats."
                :init.stop
            {:all_requests_served_c,time_taken,clients,acts,subPercent} ->
                time_taken = time_taken/1000
                IO.puts "All requests served, simulation terminating."
                IO.puts "Summary Statics"
                IO.puts "Total time (Seconds): #{time_taken}"
                IO.puts "Number of requests generated and served."
                IO.puts "   Minimum activities : #{acts}"
                IO.puts "   Top 1% of the clients do at least 20 times the minumum activities."
                IO.puts "   Next 9% of the clients do at least 10 times the minumum activities."
                IO.puts "   Next 50% of the clients do at least 2 times the minumum activities."
                IO.puts "   Rest 40% of the clients do at least the minumum activities."
                IO.puts "Total activities, approx = #{acts*20} * #{clients*0.01} + #{acts*10} * #{clients*0.09} + #{acts*2} * #{clients*0.5} + #{acts} * #{clients*0.4}"
                tot = (acts*20 * clients*0.01) + (acts* 10 * clients*0.09) + (acts*2 * clients*0.5) + (acts * clients*0.4)
                IO.puts "Approx total: #{round(tot)}"
                #time_taken = time_taken/1000
                IO.puts "Approx. activities per second: #{tot/time_taken}"
                :init.stop                 
         end
        boss_receiver()
       
    end
end