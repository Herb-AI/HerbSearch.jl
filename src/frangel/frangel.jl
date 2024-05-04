function frangel(examples::Vector{<:IOExample}, iterator::ProgramIterator, runtime_config::FrAngelConfig)
    #TODO
    return nothing
end

struct FrAngelConfig
    max_time::Int
    random_generation_max_size::Int
    random_generation_use_fragments_chance::Float16
    use_angelic_conditions::Bool
end