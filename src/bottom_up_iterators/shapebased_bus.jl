@programiterator SizeBasedBottomUpIterator(
    bank=MeasureHashedBank{Int}()
) <: BottomUpIterator

@doc """
     SizeBasedBottomUpIterator

A bottom-up iterator with a bank indexed by the size of a program.
""" SizeBasedBottomUpIterator


"""
    $(TYPEDEF)

Sets the maximum value of a measure for program enumeration.
For example, if the limit is 5 (using depth as the measure), all programs up to depth 5 are included.
"""
function get_measure_limit(iter::SizeBasedBottomUpIterator)
    return get_max_size(iter)
end 

function calc_measure(iter::SizeBasedBottomUpIterator, program::AbstractRuleNode)
    return length(program)
end

_calc_measure(::SizeBasedBottomUpIterator, children_costs::Tuple{Vararg{Int}}) = sum(children_costs)

calc_measure(::SizeBasedBottomUpIterator, combination::Tuple{Vararg{AccessAddress}}) = sum(get_measure.(combination))


@programiterator DepthBasedBottomUpIterator(
    bank=MeasureHashedBank{Int}()
) <: BottomUpIterator

@doc """
     DepthBasedBottomUpIterator

A bottom-up iterator with a bank indexed by the size of a program.
""" DepthBasedBottomUpIterator


"""
    $(TYPEDEF)

Sets the maximum value of a measure for program enumeration.
For example, if the limit is 5 (using depth as the measure), all programs up to depth 5 are included.
"""
function get_measure_limit(iter::DepthBasedBottomUpIterator)
    return get_max_depth(iter)
end 

function calc_measure(iter::DepthBasedBottomUpIterator, program::AbstractRuleNode)
    return depth(program)
end

calc_measure(::DepthBasedBottomUpIterator, combination::Tuple{Vararg{AccessAddress}}) = maximum(get_measure.(combination))

