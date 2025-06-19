function levenshtein!(
    source::AbstractString,
    target::AbstractString,
    deletion_cost::R = 1,
    insertion_cost::S = Inf,
    substitution_cost::T = Inf,
    case_cost::U = 1,
    costs::Matrix=Array{promote_type(R, S, T, U)}(undef, 2, length(target) + 1)
) where {R <: Real, S <: Real, T <: Real, U <: Real}
    if length(source) < length(target)
        # Space complexity of function = O(length(target))
        return levenshtein!(target, source, insertion_cost, deletion_cost, substitution_cost, case_cost, costs)
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