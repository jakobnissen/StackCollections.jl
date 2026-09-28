using Test
using BitIntegers: UInt256, UInt512
using StackCollections: StackCollections,
    USet,
    UVec,
    pop,
    push,
    popfirst,
    pushfirst,
    append,
    deleteat,
    insert,
    capacity,
    maximum_member,
    can_contain,
    to_bits,
    from_bits,
    setindex,
    spliceinto
using Aqua: Aqua

@testset "Aqua" begin
    Aqua.test_all(
        StackCollections
        # ambiguities = false,
        # unbound_args = false,
        # undefined_exports = false,
        # project_extras = false,
        # stale_deps = false,
        # deps_compat = false,
        # piracies = false,
        # persistent_tasks = false,
        # undocumented_names = true,
    )
end

# Bit patterns of length `len` to test against. Every pattern is covered for
# short lengths; longer lengths use patterns that expose both ends, the high
# bit, alternation and uniform payloads.
function bit_patterns(len::Integer)
    return if len <= 3
        [[isodd(bits >> i) for i in 0:(len - 1)] for bits in 0:((1 << len) - 1)]
    else
        [
            falses(len), trues(len), isodd.(1:len), iseven.(1:len),
            [i == 1 for i in 1:len], [i == len for i in 1:len],
        ]
    end
end

# A single top-level testset, so that failures in one testset do not prevent
# the others from running.
@testset "StackCollections" begin
    @testset "USet" begin
        include("uset.jl")
    end

    @testset "UVec" begin
        include("uvec.jl")
        include("editing.jl")
    end
end
