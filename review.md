  2. [P2] Non-integer membership makes set equality asymmetric.
     Only integer membership is specialized. Other values use Base’s generic iterable comparison:

     s = USet{UInt8}([0])
     t = Set([-0.0])
     s == t          # false
     t == s          # true
     isequal(t, s)   # true, despite different hashes
     missing in s    # missing

     This violates equality and hashing expectations when these sets are compared or used as keys. Julia’s BitSet shares this inherited behavior, but USet can
     avoid it by supplying a general membership fallback using isequal, while retaining the integer fast path. See membership implementation (src/uset.jl:157).

  3. [P2] Mixed-type set operations disagree with membership and equality.
     1.0 in USet{UInt8}([1]) is true, and that set equals Set([1.0]), yet both intersect(s, [1.0]) and setdiff(s, [1.0]) throw MethodError. Even unrelated non-
     integer values cannot simply be ignored.

     Error behavior also depends on iteration order: setdiff(s, [1, "a"]) succeeds, while setdiff(s, ["a", 1]) throws. The integer-only restriction is deliberate
     in comments and tests, but absent from the public documentation. Prefer consistent membership-based semantics for intersection and difference; otherwise
     explicitly document the restriction and early termination. See intersect (src/uset.jl:267) and setdiff (src/uset.jl:298).

  4. [P2, API design] pop(s, member) behaves like delete, unlike the other pop methods.
     pop(s) returns (newset, removed), whereas pop(s, member) returns only a set and silently ignores absent members. This differs from both the package’s other
     removal methods and Base’s pop!.

     Worse, using the familiar destructuring pattern can silently succeed incorrectly:

     remaining, removed = pop(USet{UInt8}([1, 2, 3]), 1)
     # remaining == UInt32(2), removed == UInt32(3)

     I recommend naming the current operation delete(s, member) and making targeted pop return a tuple with a clearly defined missing-member policy. See targeted
     pop (src/uset.jl:230).

  6. [P2] Julia compatibility permits versions where the package cannot load.
     julia = "1" includes Julia 1.0. I verified that loading the source on Julia 1.0.5 fails with UndefVarError: isdisjoint not defined. Raise the compatibility
     floor to the oldest supported and tested version, or guard newer Base extensions. See Project.toml:13 and isdisjoint extension (src/uset.jl:375).

  7. [API/documentation] Result-type and allocation behavior needs an explicit contract.
     Equivalent selections return different collection types:

     v[1:2]       # UVec
     v[[1, 2]]    # Vector{Bool}
     filter(identity, v) # Vector{Bool}
     similar(v)         # BitVector
     similar(v, Bool)   # Vector{Bool}

     This matters particularly for a package advertised as immutable and non-allocating. Document which operations preserve UVec and which produce ordinary
     mutable arrays. The one-argument similar also copies the existing values, making its behavior unnecessarily different from the other forms. See similar
     (src/uvec.jl:110) and indexing (src/uvec.jl:122).


  Several behavioral documentation fixes would also be valuable:

  - setindex masks: document that replacement count equals the number of true mask entries, not mask length; document repeated indices as “last assignment wins.”
    Its current prose also mistakenly says the destination index comes from items. Docstring (src/uvec.jl:440).

  - spliceinto: the insertion span uses length(v) where it should use length(e). Range replacement may shift the suffix downwards, despite saying upwards.
    Specify nonempty deletion bounds separately from empty insertion ranges, and add an actual range-replacement example. Insertion docs (src/uvec.jl:630),
    replacement docs (src/uvec.jl:685).

  - Constructors and set operations: document UVec’s iterable construction and strict Bool conversion, narrowing-conversion rules, first-operand backing-type
    preservation, and the different treatment of unrepresentable members in union versus intersection. push(::USet, ...) also needs its own documentation; the
    existing push docstring describes only boolean-vector behavior. UVec constructor (src/uvec.jl:29), USet push (src/uset.jl:168).
