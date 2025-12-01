

"""
check_observational_equivalence(iter, program, outputs) -> Bool
If OE pruning is enabled on `iter`, check whether the vector of `outputs` (one per
example) has already been observed. If yes, *add a Forbidden constraint* for `program`
(to the grammar) and return `false`. Otherwise, record the signature and return `true`.


Usage pattern (user‑driven):
```julia
for (prog, ...) in iter
    outs = evaluate_on_examples(prog, examples)
    keep = check_observational_equivalence(iter, prog, outs)
    keep || continue
    # score, etc.
end
```
"""
function is_observational_equivalent end

struct OutputSig
    data::Vector{UInt64}
end

Base.:(==)(a::OutputSig, b::OutputSig) = a.data == b.data
Base.hash(a::OutputSig, h::UInt) = hash(a.data, h)

"""
    $(TYPEDSIGNATURES)

Hashes a vector of outputs. Hashes to UInt64 by default.
"""
function _hash_outputs_to_u64vec(outs_any::Vector{<:Any})
    sig = Vector{UInt64}(undef, length(outs_any))
    @inbounds for i in eachindex(outs_any)
        sig[i] = hash(outs_any[i], 0x9d1c43f52d7a01ff)
    end
    return sig
end