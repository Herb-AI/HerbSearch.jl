using JSON

data = JSON.parsefile("src/iterators/meta_search/output_delftblue/output_data.json")
alg_solved = []
for alg_data in data 
    for (alg_name, problems) in alg_data 
        prob_data = Dict()
        for prob in problems 
            for (prob_name, problem_data) in prob
                prob_data[prob_name] = problem_data["solve_count"]
            end 
        end 
        push!(alg_solved, (alg_name,prob_data))
    end 
end

for (alg_name, prob_data) in alg_solved
    println("$alg_name: ")
    for (prob,val) in prob_data
        println("$prob => $val")
    end
end