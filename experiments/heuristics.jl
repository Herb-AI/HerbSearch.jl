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

function cap_function(n)
    return min(1, n)
end

function levenshtein_blocksqrt!(
    source::AbstractString,
    target::AbstractString,
    deletion_cost::R = 1,
    insertion_cost::S = Inf,
    substitution_cost::T = Inf,
    case_cost::U = 1,
    costs::Matrix = Array{promote_type(R, S, T, U)}(undef, 2, length(target) + 1),
    delete_lens::Matrix{Int} = zeros(Int, 2, length(target) + 1),
    case_lens::Matrix{Int} = zeros(Int, 2, length(target) + 1),
) where {R <: Real, S <: Real, T <: Real, U <: Real}
    if length(source) < length(target)
        return levenshtein_blocksqrt!(
            target, source, insertion_cost, deletion_cost, substitution_cost, case_cost,
            costs, delete_lens, case_lens
        )
    elseif length(target) == 0
        return cap_function(length(source)) * deletion_cost
    else
        old, new = 1, 2

        costs[old, 1] = 0
        delete_lens[old, 1] = 0
        case_lens[old, 1] = 0

        for j in 1:length(target)
            costs[old, j+1] = j * insertion_cost
            delete_lens[old, j+1] = 0
            case_lens[old, j+1] = 0
        end

        for i in 1:length(source)
            r = source[i]

            # Start of new row: delete i chars from source
            delete_lens[new, 1] = delete_lens[old, 1] + 1
            costs[new, 1] = cap_function(delete_lens[new, 1]) * deletion_cost
            case_lens[new, 1] = 0

            for j in 1:length(target)
                c = target[j]

                # Deletion: source[i] deleted
                if delete_lens[old, j+1] > 0
                    del_len = delete_lens[old, j+1] + 1
                    deletion = costs[old, j+1] - cap_function(delete_lens[old, j+1]) * deletion_cost +
                               cap_function(del_len) * deletion_cost
                else
                    del_len = 1
                    deletion = costs[old, j+1] + cap_function(1) * deletion_cost
                end

                # Insertion
                insertion = costs[new, j] + insertion_cost

                # Substitution
                substitution = costs[old, j]
                case_len = 0
                if r != c
                    if uppercase(r) == uppercase(c)
                        if case_lens[old, j] > 0
                            case_len = case_lens[old, j] + 1
                            substitution -= cap_function(case_lens[old, j]) * case_cost
                            substitution += cap_function(case_len) * case_cost
                        else
                            case_len = 1
                            substitution += cap_function(1) * case_cost
                        end
                    else
                        substitution += substitution_cost
                    end
                end

                # Pick minimum
                best = min(deletion, insertion, substitution)
                costs[new, j+1] = best

                # Track block lengths
                delete_lens[new, j+1] = (best == deletion) ? del_len : 0
                case_lens[new, j+1] = (best == substitution && case_len > 0) ? case_len : 0
            end

            old, new = new, old
        end

        return costs[old, length(target)+1]
    end
end



function string_heuristic!(sources, targets, pointers)
    heuristic = 0

    for (s, t, p) in zip(sources, targets, pointers)
        l = levenshtein!(s, t)
        
        if l == Inf
            return Inf
        end
        
        heuristic += l
    end

    if heuristic == 0
        return 0
    end


    return heuristic / length(sources)
end