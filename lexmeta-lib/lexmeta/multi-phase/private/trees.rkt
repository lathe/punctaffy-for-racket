#lang parendown racket/base

; trees.rkt
;
; Data structures for encoding the kind of higher-order structure that
; occurs in higher quasiquotation.

(require "../../private/util.rkt")

(provide #/all-defined-out)




; ===== Higher quasiquotation data ===================================

; Our definition of higher-quasiquotation-shaped data is corecursive
; with our definition of the kinds of syntax they're built out of,
; "mediums."
;
; A medium represents something that has a certain innate degree to
; it; a certain kind of "readable" value it can validate if it's
; degree 0; a certain kind of "content" value it can validate for a
; given tower of degree N (the content's edge) if it's of degree N+1;
; and finally a certain "edge" medium it has, of degree 1 less. When
; validating a content value with a medium, the content edge tower
; provided to the validator must use that edge medium, or the
; validation request is not valid.
;
; A tower actually uses two mediums: An "island" medium and a "lake"
; medium, both of the same degree as the tower itself. The lake medium
; describes the syntax of all the highest-degree holes in the tower.
; There are also lower-degree holes, but the next-lower ones are
; described by the island's edge medium, and the ones a degree below
; that are described by the edge of that edge, and so ono.
;
; It turns out we only need to model two constructors for towers:
; `hoqq-tower-readable` for the degree-0 case, and
; `hoqq-tower-content` for everything else. These make use of
; `null-medium` and `subtower-medium`. (In fact, the trivial
; `null-medium` is rather pervasive because the lake medium of
; every edge tower used for validating mediums' content values must be
; a `null-medium`.)
;
; We keep track of the arrangement of islands and lakes in a tower by
; use of "free variables" that name them. "Free variable" makes a
; little more sense as terminology if you consider that the free
; variables of a tower are a combination of the free variables of its
; subtowers. (TODO: It doesn't make that much sense. See if we can
; find new terminology.) Something exotic about these free variables
; is that they can have free variables of their own, representing the
; islands on the far side of a lake or the lakes on the far side of an
; island. They basically capture all the structure of a tower except
; for the syntactic content it contains and the spatial juxtaposition
; of that content along various degrees of nested syntax, which is
; what we use the rest of the tower data to represent.



; This is a medium where the degree N is `degree`. The edge is another
; `null-medium` of degree N-1. The readable values and content values
; are empty lists.
(struct-easy "a null-medium" (null-medium degree) #:equal)

; The degree N is the natural number `degree`.
;
; The edge is a `cons-medium` of the edges of the components.
;
; A readable value is a cons cell consisting of the readable values of
; the components, and likewise for content values.
;
(struct-easy "a cons-medium" (cons-medium degree a b) #:equal)

; This is a medium that acts just like the medium `main-medium` in
; most cases, while allowing certain highest-degree content values
; to contain towers of degree 2 higher. The point of this jump by two
; degrees is to help with representing a tower, by letting a
; highest-degree lake in the tower (of degree one less than the tower)
; be represented by a simpler lake of degree one less than that
; (representing the lake's root edge). Hence we're jumping from a lake
; that represents the edge of a lake, up two degrees to a tower that
; represents everything past the opposite edges of the lake.
;
; The degree N is the natural number `degree`.
;
; The edge is the edge of `main-medium`.
;
; A readable value is just like a `main-medium` readable value.
;
; A content value of degree N-1 for some free variables is expected to
; be a sum type of either an `island-medium` content value or a tower
; of degree N+1 where the degree-N-2-or-less free variables match the
; given ones. The `island-medium` and `lake-medium` of the tower must
; be the given `subtower-island-medium` and `subtower-lake-medium`.
;
(struct-easy "a subtower-medium"
  (subtower-medium
    degree main-medium subtower-island-medium subtower-lake-medium)
  #:equal)

; This has degree 0 and no island free variables or lake free
; variables. The `readable` must be a valid readable value for
; `island-medium`.
(struct-easy "a hoqq-tower-readable"
  (hoqq-tower-readable island-medium lake-medium island-readable)
  #:equal)

; Let N be the degree of the tower `tower-of-subtowers`.
;
; The degree of this tower is N+1.
;
; The tower `tower-of-subtowers` must have an island medium that's the
; edge of this `island-medium`, and it must have a lake medium that's
; a `subtower-medium` with a `degree` of N, a `main-medium` matching
; the edge of this `lake-medium`, a `subtower-island-medium` matching
; this `lake-medium`, and a `subtower-lake-medium` matching this
; `island-medium`. Yes, we switch the lakes and the islands for the
; subtowers.
;
; The `root-content` must be a valid `island-medium` content value for
; the redaction of `tower-of-subtowers` after all the degree-N lakes
; are replaced with a `null-medium` of degree N.
;
; Because of the fact that the lakes are `subtower-medium` trees, some
; of the degree-N-1 lakes are towers of degree N+1. We'll call those
; the subtowers, and we'll call the rest of `tower-of-subtowers` the
; root tower.
;
; This tower has lake free variables from multiple sources:
;
;   - This has every lake free variable from the root tower. The ones
;     that correspond to subtowers are degree N instead of N-1 in this
;     tower, and they now have degree-N-1 free variables matching the
;     degree-N-1 lake free variables of their subtowers.
;
;   - This has a degree-N lake free variable corresponding to every
;     island free variable of the subtowers.
;
; These must be mutually exclusive.
;
; These lake free variables are summarized in `lake-sig`, which must
; be a sig. A sig is a list from degrees to tables from variables to
; sigs, representing the fact that these free variables have free
; variables of their own, of various degrees. A variable occurring in
; a valid sig will never have free variables of degree equal to or
; greater than its own degree.
;
; This has island free variables corresponding to the degree-N lake
; free variables of the subtowers. This is computed each time, not
; summarized anywhere.
;
(struct-easy "a hoqq-tower-content"
  (hoqq-tower-content
    island-medium lake-medium lake-sig root-content
    tower-of-subtowers)
  #:equal)



; To represent a bunch of matched brackets with a degree-N external
; shape, we use a degree-N+1 tower where the island medium is the
; syntax that appears between the brackets and the lake medium is a
; medium built out of `cons-medium`, `const-medium`, and `fill-medium`
; which bundles bracket information together with another bunch of
; matched brackets with a degree-N external shape, with its lakes of
; degree N and less matching up.
;
;   (TODO: Bracket information we need to track for that: Arbitrary
;   data, the perimiter of expressions to construct the raw bracket
;   syntax, the expressions to construct the raw content syntax, and
;   the expanded content. Figure out how we'll represent perimiters.
;   It might be as simple as pairing a prefix with a tower where the
;   holes are perimiters, but this will probably require at least a
;   new medium struct to express the recursion.)
;
;
; To represent a bunch of matched brackets with a degree-N external
; shape alongside a bunch of degree-N-external-shaped unmatched
; closing brackets in some of the degree-N holes, we use a tower where
; the lake medium is built out of `cons-medium`, `const-medium`, and
; `tail-medium` where the main tower is the matched brackets and all
; the tails are the unmatched closing brackets.
;
;   (TODO: Bracket information we need to track for that: Arbitrary
;   data and the perimiter of expressions to construct the raw closing
;   bracket syntax.)
;
;
; (TODO: See how we'll represent a bunch of matched brackets that have
; been simplified to remove syntactic residue, so that they're clean
; enough to pass through a macroexpander like s-expressions again.)



; This is a medium that acts just like the medium `main-medium` in
; most cases, while requiring the highest-degree content values to
; contain towers of the same degree. The point of keeping it at the
; same degree is to represent one tower meshing up within another
; without any internal holes. The combined shape of the tower and the
; other towers within it is one less than the degree of the original
; tower.
;
; The degree N is the natural number `degree`.
;
; The edge is the edge of `main-medium`.
;
; A readable value is just like a `main-medium` readable value.
;
; A content value of degree N-1 for some free variables is expected to
; be a sum type of either an `island-medium` content value or a tower
; of degree N where the degree-N-2-or-less free variables match the
; given ones. The `island-medium` and `lake-medium` of the tower must
; be the given `fill-island-medium` and `fill-lake-medium`.
;
(struct-easy "a fill-medium"
  (fill-medium degree main-medium fill-island-medium fill-lake-medium)
  #:equal)

; This is a medium that acts just like the medium `main-medium` in
; most cases, while allowing certain highest-degree content values
; to contain towers of degree 1 higher. The point of this jump by one
; degree is to represent a stretch of content starting on the other
; side of a tower's highest-degree holes and continuing all the way
; from there to its own holes. In this case, the combined shape of the
; tower and the area beyond is still of the same degree as the tower
; itself, so this can be part of a toolkit of degree-preserving
; operations.
;
; The degree N is the natural number `degree`.
;
; The edge is the edge of `main-medium`.
;
; A readable value is just like a `main-medium` readable value.
;
; A content value of degree N-1 for some free variables is expected to
; be a sum type of either an `island-medium` content value or a tower
; of degree N where the degree-N-2-or-less free variables match the
; given ones. The `island-medium` and `lake-medium` of the tower must
; be the given `tail-island-medium` and `tail-lake-medium`.
;
(struct-easy "a tail-medium"
  (tail-medium degree main-medium tail-island-medium tail-lake-medium)
  #:equal)


; The value of `readable-medium` should be a medium of degree 0.
;
; The degree N is the natural number `degree`.
;
; The edge is another `const-medium` with degree N-1 but the same
; `readable-medium`.
;
; A readable value is just like a `readable-medium` readable value.
;
; A content value is also like a `readable-medium` readable value (not
; a content value), ignoring the tower edge altogether.
;
(struct-easy "a const-medium" (const-medium degree readable-medium)
  #:equal)
