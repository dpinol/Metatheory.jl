# EGraphs and Equality Saturation

An *EGraph* is an efficient data structure for representing congruence relations.
EGraphs are data structures originating from theorem provers. Several projects
have very recently repurposed EGraphs to implement state-of-the-art,
rewrite-driven compiler optimizations and program synthesizers using a technique
known as equality saturation. Metatheory.jl provides a general purpose,
customizable implementation of EGraphs and equality saturation, inspired from
the [egg](https://egraphs-good.github.io/) library for Rust. You can read more
about the design of the EGraph data structure and equality saturation algorithm
in the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304).

See [Alessandro Cheli](https://0x0f0f0f.github.io/) and [Philip Zucker](https://www.philipzucker.com/)'s 
[talk at JuliaCon 2021](https://www.youtube.com/watch?v=tdXfsTliRJk) for an overview of the concepts introduced in this chapter of the manual (**NOTE**: Syntax in the talk slideshow is out of date).

## What can I do with EGraphs in Metatheory.jl?

In classical term rewriting, rewrites are typically destructive and forget the
matched left-hand side. Therefore, rules are applied in an arbitrary or
controlled order - this often results in local minima and looping. For decades,
programmers and scientists using term rewriting systems have spent their time
trying to find confluent and terminating systems of rules. This requires a lot
of effort and time. When studying any computational, mathematical or scientific
system governed by equational rules, about non obviously oriented equations, such as `(a + b) + c = a + (b + c
)`?

E-Graphs come to our help. 
EGraphs are bipartite graphs of [ENode](@ref)s and [EClass](@ref)es:
a data structure for efficiently represent and rewrite on many equivalent expressions at the same time. A sort of fast data structure for sets of trees. Subtrees and parents are shared if possible. This makes EGraphs similar to DAGs.
Most importantly, with EGraph rewriting you can use **bidirectional rewrite rules**, such as **equalities** without worrying about
the ordering and confluence of your rewrite system!
Therefore, rule application in EGraphs is non-destructive - everything is
copied! This allows users to run non-deterministic rewrite systems. Many rules
can match at the same time and the previous state of expressions will not be
lost.

The EGraph backend for Metatheory.jl allows you to create an
EGraph from a starting expression, to add more expressions to the EGraph with
`addexpr!`, and then to effectively fill the EGraph with all possible equivalent
expressions resulting from applying rewrite rules from a [theory](../rewrite#Theories), by using the
`saturate!` function. You can then easily extract expressions from an e-graph by calling `extract!` with a cost
function.

A killer feature of [egg](https://egraphs-good.github.io/) and Metatheory.jl
are **EGraph Analyses**. They allow you to annotate expressions and equivalence classes in an EGraph with values from a semilattice domain, and then to:
* Automatically extract optimal expressions from an EGraph deciding from analysis data.
* Have conditional rules that are executed if some criteria is met on analysis data
* Have dynamic rules that compute the right hand side based on analysis data.

## Library

The `Metatheory.Library` module contains utility functions and macros for creating
rules and theories from commonly used algebraic structures and
properties, to be used with the e-graph backend.
```julia
using Metatheory.Library

comm_monoid = @commutative_monoid (*) 1
```


#### Theories and Algebraic Structures

**The e-graphs backend can directly handle associativity, equalities
commutativity and distributivity**, rules that are
otherwise known of causing loops and require extensive user reasoning 
in classical rewriting.

```julia
t = @theory a b c begin
    a * b == b * a
    a * 1 == a
    a * (b * c) == (a * b) * c
end
```


## Equality Saturation

We can programmatically build and saturate an EGraph.
The function `saturate!` takes an `EGraph` and a theory, and executes
equality saturation. Returns a report
of the equality saturation process.
`saturate!` is configurable, customizable parameters include
a `timeout` on the number of iterations, a `eclasslimit` on the number of e-classes in the EGraph, a `stopwhen` functions that stops saturation when it evaluates to true.
```julia
g = EGraph(:((a * b) * (1 * (b + c))));
report = saturate!(G, t);
# access the saturated EGraph
report.egraph

# show some fancy stats
report
```

```
Equality Saturation Report
=================
        Stop Reason: saturated
        Iterations: 1
        EGraph Size: 9 eclasses, 51 nodes
 ───────────────────────────────────────────────────────────────────────────────────────
                                                Time                   Allocations      
                                        ──────────────────────   ───────────────────────
            Tot / % measured:                1.18s / 0.45%            955KiB / 68.1%    

 Section                        ncalls     time   %tot     avg     alloc   %tot      avg
 ───────────────────────────────────────────────────────────────────────────────────────
 Apply                               1   4.63ms  87.5%  4.63ms    512KiB  78.7%   512KiB
 Search                              1    656μs  12.4%   656μs    139KiB  21.3%   139KiB
   a * (b * c) == (a * b) * c        1    242μs  4.58%   242μs   79.2KiB  12.2%  79.2KiB
   a * b == b * a                    1    153μs  2.89%   153μs   34.2KiB  5.26%  34.2KiB
   a * 1 == a                        1    115μs  2.17%   115μs   14.4KiB  2.21%  14.4KiB
   appending matches                 3   4.06μs  0.08%  1.35μs      544B  0.08%     181B
 Rebuild                             1   3.75μs  0.07%  3.75μs     0.00B  0.00%    0.00B
 ───────────────────────────────────────────────────────────────────────────────────────
```

With the EGraph equality saturation backend, Metatheory.jl can prove **simple**
equalities very efficiently. The `@areequal` macro takes a theory and some
expressions and returns true iff the expressions are equal according to the
theory. The following example may return true with an appropriate example theory. 

```julia 
julia> @areequal some_theory (x+y)*(a+b) ((a*(x+y))+b*(x+y)) ((x*(a+b))+y*(a+b)) 
```


## Configurable Parameters

[`EGraphs.saturate!`](@ref) can accept an additional parameter of type
[`EGraphs.SaturationParams`](@ref) to configure the equality saturation algorithm.
Extensive documentation for the configurable parameters is available in the [`EGraphs.SaturationParams`](@ref) API docstring.

```julia
# create the saturation params
params = SaturationParams(timeout=10, eclasslimit=4000)
saturate!(egraph, theory, params)
```


```@meta
CurrentModule = Base
```

## Outline of the Equality Saturation Algorithm

The `saturate!` function behaves as following.
Given a starting e-graph `g`, a set of rewrite rules `t` and some parameters `p` (including an iteration limit `n`):
* For each rule in `t`, search through the e-graph for l.h.s.
* For each match produced, apply the rewrite
* Do a bottom-up traversal of the e-graph to rebuild the congruence closure
* If the e-graph hasn’t changed from last iteration, it has saturated. If so, halt saturation.
* Loop at most n times.

Note that knowing if an expression with a set of rules saturates an e-graph or never terminates
is still an open research problem



## Extracting from an EGraph

Since e-graphs non-deterministically represent many equivalent symbolic terms,
extracting an expression from an EGraph is the process of selecting and
extracting a single symbolic expression from the set of all the possible
expressions contained in the EGraph. Extraction is done through the `extract!`
function, and the theoretical background behind this procedure is an [EGraph
Analysis](https://dl.acm.org/doi/pdf/10.1145/3434304); A cost function is
provided as a parameter to the `extract!` function. This cost function will
examine mostly every e-node in the e-graph and will determine which e-nodes will
be chosen from each e-class through an automated, recursive algorithm.

Metatheory.jl already provides some simple cost functions, such as `astsize`,
which expresses preference for the smallest expressions contained in equivalence
classes.

Here's an example
Given the theory:

```@example extraction
using Metatheory
using Metatheory.Library

comm_monoid = @commutative_monoid (*) 1;
t = @theory a b c begin
    a + 0 --> a
    a + b --> b + a
    a + inv(a) --> 0 # inverse
    a + (b + c) --> (a + b) + c
	a * (b + c) --> (a * b) + (a * c)
	(a * b) + (a * c) --> a * (b + c)
	a * a --> a^2
	a --> a^1
	a^b * a^c --> a^(b+c)
	log(a^b) --> b * log(a)
	log(a * b) --> log(a) + log(b)
	log(1) --> 0
	log(:e) --> 1
	:e^(log(a)) --> a
	a::Number + b::Number => a + b
	a::Number * b::Number => a * b
end
t = comm_monoid ∪ t ;
nothing # hide
```

We can extract an expression by using

```@example extraction

expr = :((log(e) * log(e)) * (log(a^3 * a^2)))
g = EGraph(expr)
saturate!(g, t)
ex = extract!(g, astsize)
```

The second argument to `extract!` is a **cost function**. [astsize](@ref) is 
a cost function provided by default, which computes the size of expressions.


## Defining custom cost functions for extraction.

A *cost function* for *EGraph extraction* is a function used to determine
which *e-node* will be extracted from an *e-class*. 

It must return a positive, non-complex number value and, must accept 3 arguments.
1) The current [ENode](@ref) `n` that is being inspected. 
2) The current [EGraph](@ref) `g`.
3) The current analysis type `an`.

From those 3 parameters, one can access all the data needed to compute
the cost of an e-node recursively.

* One can use [TermInterface.jl](https://github.com/JuliaSymbolics/TermInterface.jl) methods to access the operation and child arguments of an e-node: `operation(n)`, `arity(n)` and `arguments(n)`
* Since e-node children always point to e-classes in the same e-graph, one can retrieve the [EClass](@ref) object for each child of the currently visited enode with `g[id] for id in arguments(n)`
* One can inspect the analysis data for a given eclass and a given analysis type `an`, by using [hasdata](@ref) and [getdata](@ref).
* Extraction analyses always associate a tuple of 2 values to a single e-class: which e-node is the one that minimizes the cost
and its cost. More details can be found in the [egg paper](https://dl.acm.org/doi/pdf/10.1145/3434304) in the *Analyses* section. 

Here's an example:

```julia
# This is a cost function that behaves like `astsize` but increments the cost 
# of nodes containing the `^` operation. This results in a tendency to avoid 
# extraction of expressions containing '^'.
function cost_function(n::ENodeTerm, g::EGraph, an::Type{<:AbstractAnalysis})
    cost = 1 + arity(n)

    operation(n) == :^ && (cost += 2)

    for id in arguments(n)
        eclass = g[id]
        # if the child e-class has not yet been analyzed, return +Inf
        !hasdata(eclass, an) && (cost += Inf; break)
        cost += last(getdata(eclass, an))
    end
    return cost
end

# All literal expressions (e.g `a`, 123, 0.42, "hello") have cost 1
cost_function(n::ENodeLiteral, g::EGraph, an::Type{<:AbstractAnalysis}) = 1
```

## EGraph Analyses

An *EGraph Analysis* is an efficient and automated way of analyzing all the possible
terms contained in an e-graph. Metatheory.jl provides a toolkit to ease and 
automate the process of EGraph Analysis. An *EGraph Analysis* defines a domain
of values and associates a value from the domain to each [EClass](@ref) in the graph.
Theoretically, the domain should form a [join semilattice](https://en.wikipedia.org/wiki/Semilattice).
Rewrites can cooperate with e-class analyses by depending on analysis facts and adding
equivalences that in turn establish additional facts. 

In Metatheory.jl, EGraph Analyses are identified by a *type* that is subtype of `AbstractAnalysis`.
An [`EGraph`](@ref) can only contain one analysis per type.
The following functions define an interface for analyses based on multiple dispatch 
on `AbstractAnalysis` types: 
* [islazy](@ref) should return true if the analysis should NOT be computed on-the-fly during egraphs operation, only when required.  
* [make](@ref) should take an ENode and return a value from the analysis domain.
* [join](@ref) should return the semilattice join of two values in the analysis domain (e.g. *given two analyses value from ENodes in the same EClass, which one should I choose?*)
* [modify!](@ref) Can be optionally implemented. Can be used modify an EClass on-the-fly given its analysis value.

### Defining a custom analysis

In this example, we will provide a custom analysis that tags each EClass in an EGraph
with `:even` if it contains an even number or with `:odd` if it represents an odd number,
or `nothing` if it does not contain a number at all. Let's suppose that the language of the symbolic expressions
that we are considering will contain *only integer numbers, variable symbols and the `*` and `+` operations.*

Since we are in a symbolic computation context, we are not interested in the
the actual numeric result of the expressions in the EGraph, but we only care to analyze and identify
the symbolic expressions that will result in an even or an odd number.

Defining an EGraph Analysis is similar to the process [Mathematical Induction](https://en.wikipedia.org/wiki/Mathematical_induction).
To define a custom EGraph Analysis, one should start by defining a type that 
subtypes `AbstractAnalysis` that will be used to identify this specific analysis and 
to dispatch against the required methods.

```julia
using Metatheory
using Metatheory.EGraphs
abstract type OddEvenAnalysis <: AbstractAnalysis end
```

The next step, the base case of induction, is to define a method for
[make](@ref) dispatching against our `OddEvenAnalysis`. First, we want to
associate an analysis value only to the *literals* contained in the EGraph. To do this we
take advantage of multiple dispatch against `ENodeLiteral`.

```julia
function EGraphs.make(an::Type{OddEvenAnalysis}, g::EGraph, n::ENodeLiteral)
    if n.value isa Integer
        return iseven(n.value) ? :even : :odd
    else 
        return nothing
    end
end
```

Now we have to consider the *induction step*. 
Knowing that our language contains only `*` and `+` operations, and knowing that:
* odd * odd = odd
* odd * even = even
* even * even = even

And we know that 
* odd + odd = even 
* odd + even = odd 
* even + even = even

We can now define a method for `make` dispatching against 
`OddEvenAnalysis` and `ENodeTerm`s to compute the analysis value for *nested* symbolic terms. 
We take advantage of the methods in [TermInterface](https://github.com/JuliaSymbolics/TermInterface.jl) 
to inspect the content of an `ENodeTerm`.
From the definition of an [ENode](@ref), we know that children of ENodes are always IDs pointing
to EClasses in the EGraph.

```julia
function EGraphs.make(an::Type{OddEvenAnalysis}, g::EGraph, n::ENodeTerm)
    # Let's consider only binary function call terms.
    if exprhead(n) == :call && arity(n) == 2
        op = operation(n)
        # Get the left and right child eclasses
        child_eclasses = arguments(n)
        l = g[child_eclasses[1]]
        r = g[child_eclasses[2]]

        # Get the corresponding OddEvenAnalysis value of the children
        # defaulting to nothing 
        ldata = getdata(l, an, nothing)
        rdata = getdata(r, an, nothing)

        if ldata isa Symbol && rdata isa Symbol
            if op == :*
                return (ldata == :even || rdata == :even) ? :even : :odd
            elseif op == :+
                return (ldata == rdata) ? :even : :odd
            end
        elseif isnothing(ldata) && rdata isa Symbol && op == :*
            return rdata
        elseif ldata isa Symbol && isnothing(rdata) && op == :*
            return ldata
        end
    end

    return nothing
end
```

We have now defined a way of tagging each ENode in the EGraph with `:odd` or `:even`, reasoning 
inductively on the analyses values. The [analyze!](@ref) function will do the dirty job of doing 
a recursive walk over the EGraph. The missing piece, is now telling Metatheory.jl how to merge together
analysis values. Since EClasses represent many equal ENodes, we have to inform the automated analysis
how to extract a single value out of the many analyses values contained in an EGraph.
We do this by defining a method for [join](@ref).

```julia
function EGraphs.join(an::Type{OddEvenAnalysis}, a, b)
    if a == b 
        return a 
    else
        # an expression cannot be odd and even at the same time!
        # this is contradictory, so we ignore the analysis value
        return nothing 
    end
end
```

We do not care to modify the content of EClasses in consequence of our analysis.
Therefore, we can skip the definition of [modify!](@ref).
We are now ready to test our analysis.

```julia
t = @theory a b c begin 
    a * (b * c) == (a * b) * c
    a + (b + c) == (a + b) + c
    a * b == b * a
    a + b == b + a
    a * (b + c) == (a * b) + (a * c)
end

function custom_analysis(expr)
    g = EGraph(expr)
    saturate!(g, t)
    analyze!(g, OddEvenAnalysis)
    return getdata(g[g.root], OddEvenAnalysis)
end

custom_analysis(:(3*a)) # :odd
custom_analysis(:(3*(2+a)*2)) # :even
custom_analysis(:(3y * (2x*y))) # :even
```
