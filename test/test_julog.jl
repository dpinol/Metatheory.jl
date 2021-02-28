using MatchCore
using Julog
#
# # example assuming * operation is always binary

struct JulogAnalysis <: AbstractAnalysis
    egraph::EGraph
    facts::Vector{Clause}
    data::Dict{Int64, Vector{Clause}}
end

# Mandatory for AbstractAnalysis
JulogAnalysis(g::EGraph, facts::Vector{Clause}) =
    JulogAnalysis(g, facts, Dict{Int64, Vector{Clause}}())

# This should be auto-generated by a macro
function EGraphs.make(an::JulogAnalysis, n)
    !(n isa Expr) && return []

    m = @matcher begin
        l * r |> begin
            get(an, l, [])
        end

        _ => nothing
    end

    return m(n)
end

EGraphs.join(analysis::NumberFold, from, to) = from ∪ to

function EGraphs.modify!(an::NumberFold, id::Int64)
    g = an.egraph
    # !haskey(an, id) && return nothing
    if an[id] isa Number
        newclass = EGraphs.add!(g, an[id])
        merge!(g, newclass.id, id)
    end
end

Base.setindex!(an::JulogAnalysis, value, id::Int64) = setindex!(an.data, value, id)
Base.getindex(an::JulogAnalysis, id::Int64) = an.data[id]
Base.haskey(an::JulogAnalysis, id::Int64) = haskey(an.data, id)
Base.delete!(an::JulogAnalysis, id::Int64) = delete!(an.data, id)

g = EGraph(:(x * (cos(z)/cos(z))))
facts = @julog [
    iszero(z) <<= true,
    iszero(X) <<= fail
]
extractor = addanalysis!(g, ExtractionAnalysis, astsize)
# ja = addanalysis!(g, JulogAnalysis, facts)

macro res(goals, facts)
    quote first(resolve(@julog($goals), $facts)) end
end

example = @theory begin
    x/x |> (@res(not(iszero(x)), facts) ? :($x) : :($x/$x))
end

display(g.M); println()
saturate!(g, example; mod=@__MODULE__)
println(extract!(g, extractor))
