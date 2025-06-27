#
# File has to be manually included because HerbBenchmarks is not a dependency of HerbSearch.
# Therefore, this file is not included in HerbSearch.jl
#


# Function added from levenstein library: [https://github.com/rawrgrr/Levenshtein.jl/blob/master/src/Levenshtein.jl]
function levenshtein!(
    source::AbstractString,
    target::AbstractString,
    deletion_cost::R,
    insertion_cost::S,
    substitution_cost::T,
    costs::Matrix=Array{promote_type(R, S, T)}(undef, 2, length(target) + 1)
) where {R<:Real,S<:Real,T<:Real}
    cost_type = promote_type(R, S, T)
    if length(source) < length(target)
        # Space complexity of function = O(length(target))
        return levenshtein!(target, source, insertion_cost, deletion_cost, substitution_cost, costs)
    else
        if length(target) == 0
            return length(source) * deletion_cost
        else
            old_cost_index = 1
            new_cost_index = 2

            costs[old_cost_index, 1] = 0
            for i in 1:length(target)
                costs[old_cost_index, i+1] = i * insertion_cost
            end

            i = 0
            for r in source
                i += 1

                # Delete i characters from source to get empty target
                costs[new_cost_index, 1] = i * deletion_cost

                j = 0
                for c in target
                    j += 1

                    deletion = costs[old_cost_index, j+1] + deletion_cost
                    insertion = costs[new_cost_index, j] + insertion_cost
                    substitution = costs[old_cost_index, j]
                    if r != c
                        substitution += substitution_cost
                    end

                    costs[new_cost_index, j+1] = min(deletion, insertion, substitution)
                end

                old_cost_index, new_cost_index = new_cost_index, old_cost_index
            end

            new_cost_index = old_cost_index
            return costs[new_cost_index, length(target)+1]
        end
    end
end


function levenshtein_with_uppercase!(
    source::AbstractString,
    target::AbstractString,
    deletion_cost::R=1,
    insertion_cost::S=Inf,
    substitution_cost::T=Inf,
    case_cost::U=1,
    costs::Matrix=Array{promote_type(R, S, T, U)}(undef, 2, length(target) + 1)
) where {R<:Real,S<:Real,T<:Real,U<:Real}
    if length(source) < length(target)
        # Space complexity of function = O(length(target))
        return levenshtein_with_uppercase!(target, source, insertion_cost, deletion_cost, substitution_cost, case_cost, costs)
    else
        if length(target) == 0
            return length(source) * deletion_cost
        else
            old_cost_index = 1
            new_cost_index = 2

            costs[old_cost_index, 1] = 0
            for i in 1:length(target)
                costs[old_cost_index, i+1] = i * insertion_cost
            end

            i = 0
            for r in source
                i += 1

                # Delete i characters from source to get empty target
                costs[new_cost_index, 1] = i * deletion_cost

                j = 0
                for c in target
                    j += 1

                    deletion = costs[old_cost_index, j+1] + deletion_cost
                    insertion = costs[new_cost_index, j] + insertion_cost
                    substitution = costs[old_cost_index, j]
                    if r != c
                        if uppercase(r) == uppercase(c)
                            substitution += case_cost
                        else
                            substitution += substitution_cost
                        end
                    end

                    costs[new_cost_index, j+1] = min(deletion, insertion, substitution)
                end

                old_cost_index, new_cost_index = new_cost_index, old_cost_index
            end

            new_cost_index = old_cost_index
            return costs[new_cost_index, length(target)+1]
        end
    end
end


using HerbBenchmarks

function karel_edit_dist(expected::HerbBenchmarks.Karel_2018.KarelState,
    actual::HerbBenchmarks.Karel_2018.KarelState)
    dist = sum(abs.(expected.hero.position .- actual.hero.position))
    dist += min(mod(Int(expected.hero.direction) - Int(actual.hero.direction), 4),
        mod(Int(expected.hero.direction) + Int(actual.hero.direction), 4))

    all_positions = union(keys(expected.markers), keys(actual.markers))
    for pos in all_positions
        count_expected = get(expected.markers, pos, 0)
        count_actual = get(actual.markers, pos, 0)
        dist += abs(count_expected - count_actual)
    end
    return dist
end

function Base.:(==)(a::HerbBenchmarks.Robots_2020.RobotState, b::HerbBenchmarks.Robots_2020.RobotState)
    return a.holds_ball == b.holds_ball &&
           a.robot_x == b.robot_x &&
           a.robot_y == b.robot_y &&
           a.ball_x == b.ball_x &&
           a.ball_y == b.ball_y &&
           a.size == b.size
end

function robot_all_steps_dist(expected::HerbBenchmarks.Robots_2020.RobotState,
    actual::HerbBenchmarks.Robots_2020.RobotState)
    dist = 0

    if actual.ball_x == expected.ball_x && actual.ball_y == expected.ball_y &&
       actual.holds_ball == expected.holds_ball
        # Ball is already in correct place, just compare state
        dist += abs(expected.robot_x - actual.robot_x)
        dist += abs(expected.robot_y - actual.robot_y)
    else
        # 1. Robot goes to current ball position
        dist += abs(actual.robot_x - actual.ball_x)
        dist += abs(actual.robot_y - actual.ball_y)

        dist += abs(actual.holds_ball - 1) # Pick up ball

        # 2. Move ball to expected ball position
        dist += abs(expected.ball_x - actual.ball_x)
        dist += abs(expected.ball_y - actual.ball_y)

        dist += abs(expected.holds_ball - 1) # Drop ball

        # 3. Move robot to final target position
        dist += abs(expected.robot_x - expected.ball_x)
        dist += abs(expected.robot_y - expected.ball_y)
    end

    return dist
end

function robot_simple_dist(expected::HerbBenchmarks.Robots_2020.RobotState,
    actual::HerbBenchmarks.Robots_2020.RobotState)
    dist = 0
    dist += abs(expected.robot_x - actual.robot_x)
    dist += abs(expected.robot_y - actual.robot_y)
    dist += abs(expected.ball_x - actual.ball_x)
    dist += abs(expected.ball_y - actual.ball_y)
    dist += abs(expected.holds_ball - actual.holds_ball)
    return dist
end

function pixel_edit_dist(expected::HerbBenchmarks.Pixels_2020.PixelState,
    actual::HerbBenchmarks.Pixels_2020.PixelState)
    if size(expected.matrix) != size(actual.matrix)
        error("Matrix sizes do not match.")
    end
    return count(expected.matrix .!= actual.matrix)
end


"""
    construct_aux_function(dist_fn::Function, ::Type{OutputType}) where {OutputType}

Constructs an `AuxFunction` object using the provided distance function `dist_fn` 
    and the specified output type `OutputType`. Assumes optimal distance 0.

# Arguments
- `dist_fn::Function`: A function that computes the distance between two outputs.
- `::Type{OutputType}`: The type of the output values to be compared.

# Returns
- `AuxFunction`: An object encapsulating:
    - A function that computes the distance between the expected and actual outputs.
    - A function that computes the total score over all examples in a problem specification.
    - Optimal distance (assumes to be 0).

# Example
"""
function construct_aux_function(
    dist_fn::Function,
    ::Type{OutputType}
) where {OutputType}
    AuxFunction(
        (expected::IOExample{<:Any,<:OutputType}, actual::OutputType) ->
            dist_fn(expected.out, actual),
        problem::Problem -> begin
            score = 0
            for example in problem.spec
                score += dist_fn(example.out, only(values(example.in)))
            end
            return score
        end,
        0
    )
end

const AUX_FUNCTIONS = Dict(
    "strings" => Dict(
        "aulile_edit_distance" => construct_aux_function((a, b) ->
                levenshtein!(a.str, b.str, 1, 1, 1),
            HerbBenchmarks.String_transformations_2020.StringState),
        "aulile_penalize_deleting" => construct_aux_function((a, b) ->
                levenshtein_with_uppercase!(a.str, b.str),
            HerbBenchmarks.String_transformations_2020.StringState),
    ), "robots" => Dict(
        "aulile_all_steps_manhattan" => construct_aux_function(robot_all_steps_dist,
            HerbBenchmarks.Robots_2020.RobotState),
        "aulile_simple_manhattan" => construct_aux_function(robot_simple_dist,
            HerbBenchmarks.Robots_2020.RobotState)
    ), "pixels" => Dict(
        "aulile_edit_distance" => construct_aux_function(pixel_edit_dist,
            HerbBenchmarks.Pixels_2020.PixelState)
    ), "karel" => Dict(
        "aulile_edit_distance" => construct_aux_function(karel_edit_dist,
            HerbBenchmarks.Karel_2018.KarelState)
    ),
)