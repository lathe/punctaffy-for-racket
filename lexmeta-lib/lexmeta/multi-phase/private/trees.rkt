#lang parendown racket/base

; trees.rkt
;
; Data structures for encoding the kind of higher-order structure that
; occurs in higher quasiquotation.

(require #/only-in racket/generic define-generics)

(require #/only-in lathe expect mat w-)

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
; provided to the validator must be of that diminished degree and must
; use that edge medium, or the validation request is not valid.
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

(struct-easy "a medium-unpacked-zero"
  (medium-unpacked-zero verify-readable))
(struct-easy "a medium-unpacked-succ"
  (medium-unpacked-succ degree edge-island-medium verify-content))

(define-generics medium
  (medium-unpack medium))

(define (medium-degree medium)
  (w- unpacked (medium-unpack medium)
  #/mat unpacked (medium-unpacked-zero verify-readable) 0
  #/mat unpacked
    (medium-unpacked-succ degree edge-island-medium verify-content)
    degree
  #/error "Expected the result of medium-unpack to be a medium-unpacked-zero or a medium-unpacked-succ"))



; This is a medium where the degree N is `degree`. The edge is another
; `null-medium` of degree N-1. The readable values and content values
; are empty lists.
(struct-easy "a null-medium" (null-medium degree) #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer")))
  #:other
  
  #:methods gen:medium
  [#/define (medium-unpack this)
    (expect this (null-medium degree)
      (error "Expected this to be a null-medium")
    #/expect (nat-pred-maybe degree) (list lower-degree)
      (medium-unpacked-zero #/lambda (readable)
        (expect readable (list)
          (error "Expected readable to be an empty list")))
      (medium-unpacked-succ degree (null-medium lower-degree)
      #/lambda (content-edge content)
        (expect content (list)
          (error "Expected content to be an empty list"))))]
)

; The degree N is the natural number `degree`.
;
; The edge is a `cons-medium` of the edges of the components.
;
; A readable value is a cons cell consisting of the readable values of
; the components, and likewise for content values.
;
(struct-easy "a cons-medium" (cons-medium degree a b) #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    (unless (medium? a)
      (error "Expected a to be a medium"))
    (unless (medium? b)
      (error "Expected b to be a medium"))
    (unless (eq? degree #/medium-degree a)
      (error "Expected degree and the degree of a to match"))
    (unless (eq? degree #/medium-degree b)
      (error "Expected degree and the degree of b to match")))
  #:other
  
  #:methods gen:medium
  [#/define (medium-unpack this)
    (expect this (cons-medium degree a b)
      (error "Expected this to be a cons-medium")
    #/expect (nat-pred-maybe degree) (list lower-degree)
      (expect (medium-unpack a)
        (medium-unpacked-zero verify-readable-a)
        (error "Expected the unpacked a to be a medium-unpacked-zero")
      #/expect (medium-unpack b)
        (medium-unpacked-zero verify-readable-b)
        (error "Expected the unpacked b to be a medium-unpacked-zero")
      #/medium-unpacked-zero #/lambda (readable)
        (expect readable (cons readable-a readable-b)
          (error "Expected readable to be a cons cell")
          (verify-readable-a readable-a)
          (verify-readable-b readable-b)))
      (expect (medium-unpack a)
        (medium-unpacked-succ degree-a medium-edge-a verify-content-a)
        (error "Expected the unpacked a to be a medium-unpacked-succ")
      #/expect (medium-unpack b)
        (medium-unpacked-succ degree-b medium-edge-b verify-content-b)
        (error "Expected the unpacked b to be a medium-unpacked-succ")
      #/expect (= degree degree-a) #t
        (error "Expected degree to match the degree of a")
      #/expect (= degree degree-b) #t
        (error "Expected degree to match the degree of b")
      #/medium-unpacked-succ degree
        (cons-medium lower-degree medium-edge-a medium-edge-b)
      #/lambda (content-edge content)
        (expect content (cons content-a content-b)
          (error "Expected content to be a cons cell")
          (verify-content-a content-edge content-a)
          (verify-content-b content-edge content-b))))]
)

; This is a medium that acts just like the medium `main-medium` in
; most cases, while allowing certain highest-degree content values
; to contain towers whose mediums are of degree one higher than this
; medium. The point of this step upward in degree is to help with
; representing a tower: We can represent it with a lower-degree tower
; containing all the low-degree lakes and the "near" low-degree side
; of every highest-degree lake, where in each of those truncated lakes
; we have another tower of what's beyond it. The tower beyond is equal
; in degree to the one we're modeling, so we can model it the same way
; recursively, ending up with a representation comprised only of
; lower-degree towers.
;
; The degree N is the natural number `degree`.
;
; The edge is the edge of `main-medium`.
;
; A readable value is just like a `main-medium` readable value.
;
; A content value for some degree-N-1 content edge is expected to be
; a sum type of either (`subtower-medium-continue`) a `main-medium`
; content value or (`subtower-medium-subtower`) a tower of degree N+1
; where the degree-N-2-or-less free variables match the given ones.
; The `island-medium` and `lake-medium` of the tower must be the given
; `subtower-island-medium` and `subtower-lake-medium`.
;
(struct-easy "a subtower-medium-continue"
  (subtower-medium-continue content))
(struct-easy "a subtower-medium-subtower"
  (subtower-medium-subtower tower))
(struct-easy "a subtower-medium"
  (subtower-medium
    degree main-medium subtower-island-medium subtower-lake-medium)
  #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    (unless (medium? main-medium)
      (error "Expected main-medium to be a medium"))
    (unless (medium? subtower-island-medium)
      (error "Expected subtower-island-medium to be a medium"))
    (unless (medium? subtower-lake-medium)
      (error "Expected subtower-lake-medium to be a medium"))
    (unless (= degree #/medium-degree main-medium)
      (error "Expected degree and the degree of main-medium to match"))
    (unless (= (+ 1 degree) #/medium-degree subtower-island-medium)
      (error "Expected degree to be 1 less than the degree of subtower-island-medium"))
    (unless (= (+ 1 degree) #/medium-degree subtower-lake-medium)
      (error "Expected degree to be 1 less than the degree of subtower-lake-medium")))
  #:other
  
  #:methods gen:medium
  [#/define (medium-unpack this)
    (expect this
      (subtower-medium
        degree main-medium subtower-island-medium
        subtower-lake-medium)
      (error "Expected this to be a subtower-medium")
    #/expect (nat-pred-maybe degree) (list lower-degree)
      (expect (medium-unpack main-medium)
        (medium-unpacked-zero verify-readable-main)
        (error "Expected the result of unpacking main-medium to be a medium-unpacked-zero")
      #/medium-unpacked-zero #/lambda (readable)
        (verify-readable-main readable))
      (expect (medium-unpack main-medium)
        (medium-unpacked-succ
          degree-main medium-edge-main verify-content-main)
        (error "Expected the result of unpacking main-medium to be a medium-unpacked-zero")
      #/expect (= degree degree-main) #t
        (error "Expected degree to match the degree of main-medium")
      #/medium-unpacked-succ degree medium-edge-main
      #/lambda (content-edge content)
        (mat content (subtower-medium-continue content)
          (verify-content-main content-edge content)
        #/mat content (subtower-medium-subtower tower)
          ; TODO: Where N is `degree`, verify that `tower` is a tower
          ; of degree N+1 where the degree-N-2-or-less free variables
          ; match the given `content-edge`. The `island-medium` and
          ; `lake-medium` of the tower must be the given
          ; `subtower-island-medium` and `subtower-lake-medium`.
          (void)
        #/error "Expected content to be a subtower-medium-continue or a subtower-medium-subtower")))]
)

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



; To represent a bunch of matched brackets with a degree-N-tower
; flattened shape, we use a degree-N tower where the island medium is
; the syntax that appears between the brackets and the lake medium is
; a medium built out of `cons-medium`, `const-medium`, and
; `fill-medium` which bundles bracket information together with
; another bunch of matched brackets with a degree-N-tower flattened
; shape, with its lakes of degree N-2 and less matching up and its
; lakes of degree N-1 shining through.
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
; To represent a bunch of matched brackets with a degree-N-tower
; flattened shape alongside a bunch of unmatched closing brackets
; closing off degree-N-tower-shaped content in some of the degree-N-1
; holes, we use a degree-N tower where the lake medium is built out of
; `cons-medium`, `const-medium`, and `tail-medium` where the main
; tower is the matched brackets and all the tails are the unmatched
; closing brackets.
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
; most cases, while allowing certain highest-degree content values
; to contain towers of the same medium as this one. The point of
; keeping it at the same degree is to represent one tower meshing up
; with another layer of towers without any holes in between. The point
; of reusing this medium for the fills is so that the fills can have
; their own fills, and so on. The combined shape of the tower and all
; the nested towers within it is the same degree as the original.
;
; The degree N is the natural number `degree`.
;
; The edge is the edge of `main-medium`.
;
; A readable value is just like a `main-medium` readable value.
;
; A content value of degree N-1 for some free variables is expected to
; be a sum type of either (`fill-medium-continue`) a `main-medium`
; content value or (`fill-medium-fill`) a tower of degree N where the
; degree-N-2-or-less free variables match the given content edge. The
; `island-medium` and `lake-medium` of the tower must be the overall
; `fill-medium` and the given `fill-lake-medium`.
;
(struct-easy "a fill-medium-continue" (fill-medium-continue content))
(struct-easy "a fill-medium-fill" (fill-medium-fill tower))
(struct-easy "a fill-medium"
  (fill-medium degree main-medium fill-lake-medium)
  #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    (unless (medium? main-medium)
      (error "Expected main-medium to be a medium"))
    (unless (medium? fill-lake-medium)
      (error "Expected fill-lake-medium to be a medium"))
    (unless (= degree #/medium-degree main-medium)
      (error "Expected degree and the degree of main-medium to match"))
    (unless (= degree #/medium-degree fill-lake-medium)
      (error "Expected degree and the degree of fill-lake-medium to match")))
  #:other
  
  #:methods gen:medium
  [#/define (medium-unpack this)
    (expect this (fill-medium degree main-medium fill-lake-medium)
      (error "Expected this to be a fill-medium")
    #/expect (nat-pred-maybe degree) (list lower-degree)
      (expect (medium-unpack main-medium)
        (medium-unpacked-zero verify-readable-main)
        (error "Expected the result of unpacking main-medium to be a medium-unpacked-zero")
      #/medium-unpacked-zero #/lambda (readable)
        (verify-readable-main readable))
      (expect (medium-unpack main-medium)
        (medium-unpacked-succ
          degree-main medium-edge-main verify-content-main)
        (error "Expected the result of unpacking main-medium to be a medium-unpacked-zero")
      #/expect (= degree degree-main) #t
        (error "Expected degree to match the degree of main-medium")
      #/medium-unpacked-succ degree medium-edge-main
      #/lambda (content-edge content)
        (mat content (fill-medium-continue content)
          (verify-content-main content-edge content)
        #/mat content (fill-medium-fill tower)
          ; TODO: Where N is `degree`, verify that `tower` is a tower
          ; of degree N where the degree-N-2-or-less free variables
          ; match the given `content-edge`. The `island-medium` and
          ; `lake-medium` of the tower must be the overall
          ; `fill-medium` and the given `fill-lake-medium`.
          (void)
        #/error "Expected content to be a fill-medium-continue or a fill-medium-fill")))]
)

; This is a medium that acts just like the medium `main-medium` in
; most cases, while allowing certain highest-degree content values
; to contain towers of the same degree as this medium. The point of
; keeping the degree the same is to represent a stretch of content
; starting on the other side of a tower's highest-degree holes and
; continuing all the way from there to its own holes. The combined
; shape of the tower and the area beyond is of the same degree as the
; tower itself.
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
(struct-easy "a tail-medium-continue" (tail-medium-continue content))
(struct-easy "a tail-medium-tail" (tail-medium-tail tower))
(struct-easy "a tail-medium"
  (tail-medium degree main-medium tail-island-medium tail-lake-medium)
  #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    (unless (medium? main-medium)
      (error "Expected main-medium to be a medium"))
    (unless (medium? tail-island-medium)
      (error "Expected tail-island-medium to be a medium"))
    (unless (medium? tail-lake-medium)
      (error "Expected tail-lake-medium to be a medium"))
    (unless (= degree #/medium-degree main-medium)
      (error "Expected degree and the degree of main-medium to match"))
    (unless (= degree #/medium-degree tail-island-medium)
      (error "Expected degree and the degree of tail-island-medium to match"))
    (unless (= degree #/medium-degree tail-lake-medium)
      (error "Expected degree and the degree of tail-lake-medium to match")))
  #:other
  
  #:methods gen:medium
  [#/define (medium-unpack this)
    (expect this
      (tail-medium
        degree main-medium tail-island-medium tail-lake-medium)
      (error "Expected this to be a tail-medium")
    #/expect (nat-pred-maybe degree) (list lower-degree)
      (expect (medium-unpack main-medium)
        (medium-unpacked-zero verify-readable-main)
        (error "Expected the result of unpacking main-medium to be a medium-unpacked-zero")
      #/medium-unpacked-zero #/lambda (readable)
        (verify-readable-main readable))
      (expect (medium-unpack main-medium)
        (medium-unpacked-succ
          degree-main medium-edge-main verify-content-main)
        (error "Expected the result of unpacking main-medium to be a medium-unpacked-zero")
      #/expect (= degree degree-main) #t
        (error "Expected degree to match the degree of main-medium")
      #/medium-unpacked-succ degree medium-edge-main
      #/lambda (content-edge content)
        (mat content (tail-medium-continue content)
          (verify-content-main content-edge content)
        #/mat content (tail-medium-tail tower)
          ; TODO: Where N is `degree`, verify that `tower` is a tower
          ; of degree N where the degree-N-2-or-less free variables
          ; match the given `content-edge`. The `island-medium` and
          ; `lake-medium` of the tower must be the given
          ; `tail-island-medium` and `tail-lake-medium`.
          (void)
        #/error "Expected content to be a tail-medium-continue or a tail-medium-tail")))]
)

; TODO: See if we can represent something like `tail-medium` as a
; combination of `fill-medium` with some kind of fixed point. The
; challenge here is that if we make a lazy medium which is equal to
; another lazy medium if their thunks return equal values, the thunks
; may nevertheless have different side effects. Is there an idiomatic
; way we can prohibit or discourage side effects in Racket?

; The value of `readable-medium` must be a medium of degree 0.
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
  #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    (unless (medium? readable-medium)
      (error "Expected readable-medium to be a medium"))
    (unless (= 0 #/medium-degree readable-medium)
      (error "Expected readable-medium to have a degree of 0")))
  #:other
  
  #:methods gen:medium
  [#/define (medium-unpack this)
    (expect this (const-medium degree readable-medium)
      (error "Expected this to be a const-medium")
    #/expect (medium-unpack readable-medium)
      (medium-unpacked-zero verify-readable)
      (error "Expected the result of unpacking readable-medium to be a medium-unpacked-zero")
    #/expect (nat-pred-maybe degree) (list lower-degree)
      (medium-unpacked-zero #/lambda (readable)
        (verify-readable readable))
      (medium-unpacked-succ degree
        (const-medium lower-degree readable-medium)
      #/lambda (content-edge content)
        (verify-readable content)))]
)
