using Random

"""
    abstract type StochasticSearchStrategy

An abstract strategy for the algorithms Metropolis Hastings, Very Large Scale Neighbourhood and Simulated Annealing.
Each strategy implements `neighbourhood` `propose` `accept` and `temperature` functions. Below the signiture of all this function is shown

## Signatures
---
Returns a node location from the program that is the neighbourhood. It can also return other information using  `dict`

    neighbourhood(program::RuleNode, grammar::Grammar) -> (loc::NodeLocation, dict::Dict)
---
Proposes a list of programs using the location provided by `neighbourhood` and the `dict`.
    
    propose(current_program, loc::NodeLocation, grammar::Grammar, max_depth::Int64, dict::Dict) -> Iter[RuleNode]
----

Based on the current program and possible cost and temperature it accepts the program or not. Usually we would always want to accept
better programs but we might get stuck if we do so. That is why some implementations of the `accept` function accept with a probability 
costs that are worse. 
`cost` means how different are the outcomes of the program compared to the correct outcomes.
The lower the `cost` the better the program performs on the examples. The `cost` is provided by the `cost_function`

    accept(current_cost::Real, possible_cost::Real, temperature::Real) -> Bool
----
Returns the new temperature based on the previous temperature. Higher the `temperature` means that the algorithm will explore more.
    
    temperature(previous_temperature::Real) -> Real 
---
Returns the cost of the current program. It receives a list of tuples `(expected, found)` and gives back a cost.
    
    cost_function(outcomes::Tuple{<:Number,<:Number}[]) -> Real
"""

abstract type StochasticSearchStrategy <: AbstractSearchStrategy end

#todo: refactor to the new strategy structure:

#abstract type ConcreteStrategy1 <: StochasticSearchStrategy end
#abstract type ConcreteStrategy2 <: StochasticSearchStrategy end
#abstract type ConcreteStrategy3 <: StochasticSearchStrategy end
#abstract type ConcreteStrategy4 <: StochasticSearchStrategy end

#implement different algorithms, dispatched on concrete strategies:

#function propose(::ConcreteStrategy1, ...params) end
#function propose(::ConcreteStrategy2, ...params) end
#function propose(::ConcreteStrategy3, ...params) end
#function propose(::ConcreteStrategy4, ...params) end

#function neighbourhood(::ConcreteStrategy1, ...params) end
#function neighbourhood(::ConcreteStrategy2, ...params) end
#function neighbourhood(::ConcreteStrategy3, ...params) end
#function neighbourhood(::ConcreteStrategy4, ...params) end

#function accept(::ConcreteStrategy1, ...params) end
#function accept(::ConcreteStrategy2, ...params) end
#function accept(::ConcreteStrategy3, ...params) end
#function accept(::ConcreteStrategy4, ...params) end

#function temperature(::ConcreteStrategy1, ...params) end
#function temperature(::ConcreteStrategy2, ...params) end
#function temperature(::ConcreteStrategy3, ...params) end
#function temperature(::ConcreteStrategy4, ...params) end