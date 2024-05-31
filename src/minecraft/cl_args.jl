using ArgParse

function parse_commandline()
    settings = ArgParseSettings()
    @add_arg_table! settings begin
        "--experiment", "-e"
            help = "experiment number"
            arg_type = Int
            required = true
        "--seed", "-s"
            help = "world seed"
            arg_type = Int
            required = true
        "--tries", "-t"
            help = "number of tries"
            arg_type = Int
            default = 1
        "--max-time"
            help = "max. time per try"
            arg_type = Int
            default = 600
        "--env"
            help = "environment name"
            arg_type = String
            default = "MineRLNavigateDenseProgSynth-v0"
        "--render", "-r"
            help = "render the environment"
            action = :store_true
    end

    return parse_args(settings)
end
