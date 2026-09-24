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


Several behavioral documentation fixes would also be valuable:
    Specify nonempty deletion bounds separately from empty insertion ranges, and add an actual range-replacement example. Insertion docs (src/uvec.jl:630),
    replacement docs (src/uvec.jl:685).

  - Constructors and set operations: document UVec’s iterable construction and strict Bool conversion, narrowing-conversion rules, first-operand backing-type
    preservation, and the different treatment of unrepresentable members in union versus intersection. push(::USet, ...) also needs its own documentation; the
    existing push docstring describes only boolean-vector behavior. UVec constructor (src/uvec.jl:29), USet push (src/uset.jl:168).
