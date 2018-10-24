#lang parendown racket/base

; punctaffy/hypersnippet/hypertee
;
; A data structure for encoding the kind of higher-order structure
; that occurs in higher quasiquotation.

;   Copyright 2017-2018 The Lathe Authors
;
;   Licensed under the Apache License, Version 2.0 (the "License");
;   you may not use this file except in compliance with the License.
;   You may obtain a copy of the License at
;
;       http://www.apache.org/licenses/LICENSE-2.0
;
;   Unless required by applicable law or agreed to in writing,
;   software distributed under the License is distributed on an
;   "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
;   either express or implied. See the License for the specific
;   language governing permissions and limitations under the License.


(require #/only-in racket/contract/base
  -> any any/c list/c listof or/c)
(require #/only-in racket/contract/region define/contract)
(require #/only-in racket/list make-list)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/hash hash-kv-each)
(require #/only-in lathe-comforts/list
  list-all list-any list-bind list-each list-foldl list-kv-map
  list-map)
(require #/only-in lathe-comforts/maybe
  just maybe? maybe/c maybe-map nothing)
(require #/only-in lathe-comforts/struct struct-easy)
(require #/only-in lathe-comforts/trivial trivial)
(require #/only-in lathe-ordinals
  onum<=? onum<? onum-max onum<=omega? onum<omega? onum-plus
  onum-plus1 onum-pred-maybe)
(require #/only-in lathe-ordinals/olist olist-build)

(require #/only-in punctaffy/hypersnippet/hyperstack
  make-poppable-hyperstack make-poppable-hyperstack-n
  make-pushable-hyperstack poppable-hyperstack-dimension
  poppable-hyperstack-pop poppable-hyperstack-pop-n
  poppable-hyperstack-pop-n-with-barrier pushable-hyperstack-dimension
  pushable-hyperstack-pop pushable-hyperstack-push)

(provide
  hypertee-closing-bracket-degree
  (rename-out
    [-hypertee? hypertee?]
    [-hypertee-degree hypertee-degree])
  degree-and-closing-brackets->hypertee
  hypertee->degree-and-closing-brackets
  hypertee-promote
  hypertee-set-degree-maybe
  hypertee-set-degree
  hypertee<omega?
  hypertee-contour
  hypertee-drop1
  hypertee-dv-map-all-degrees
  hypertee-v-map-one-degree
  hypertee-v-map-highest-degree
  hypertee-fold
  (struct-out hypertee-join-selective-interpolation)
  (struct-out hypertee-join-selective-non-interpolation)
  hypertee-join-all-degrees-selective
  hypertee-map-all-degrees
  hypertee-map-one-degree
  hypertee-map-highest-degree
  hypertee-pure
  hypertee-get-hole-zero
  hypertee-plus1
  hypertee-join-all-degrees
  hypertee-bind-all-degrees
  hypertee-bind-one-degree
  hypertee-bind-pred-degree
  hypertee-join-one-degree
  hypertee-dv-any-all-degrees
  hypertee-dv-all-all-degrees
  hypertee-dv-each-all-degrees
  hypertee-v-each-one-degree
  hypertee-each-all-degrees
  hypertee-uncontour
  hypertee-filter
  hypertee-truncate
  hypertee-dv-fold-map-any-all-degrees
  hypertee-zip-selective
  hypertee-zip-low-degrees)


; ===== Hypertees ====================================================

; Intuitively, what we want to represent are higher-order snippets of
; data. A degree-1 snippet is everything after one point in the data,
; except for everything after another point. A degree-2 snippet is
; everything inside one degree-1 snippet, except for everything inside
; some other degree-1 snippets inside it, and so on. Extrapolating
; backwards, a degree-0 snippet is "everything after one point."
; Collectively, we'll call these hypersnippets.
;
; Here's an example of a degree-4 hypersnippet shape -- just the
; shape, omitting whatever data is contained inside:
;
;    ^4( ~3( ~2( ~2( ,( ,( ,( ,( ) ) ) ) ) ) ) )
;
; This has one degree-3 hole, one degree-2 hole, one degree-1 hole,
; and one degree-0 hole. If we remove the solitary degree-3 hole, we
; end up with a degree-4 hypersnippet that simply has no degree-3
; holes, but that kind of hypersnippet *could* be demoted to degree 3:
;
;    ^3(         ~2( ,(       ,( )     ) )     )
;
; And so on, we can eliminate high-degree holes and demote until we
; have to stop at a degree-0 snippet:
;
;    ^2(                      ,( )             )
;      (                                       )
;      ;
;
; Most discussions of "expressions with holes" refer to degree-1
; holes for our purposes, because standard lambda calculus notation
; represents an expression using data that fits snugly in a degree-1
; hypersnippet of text.
;
; To represent hypersnippet-shaped data, we'll use a simpler building
; block we call a "hypertee." A hypertee has the shape of a
; hypersnippet, but it contains precisely one first-class value per
; hole. So if a hypertee had the shape "^2( ,( ) )" it would have two
; values, one for the ",( )" hole and another for the ")" hole at the
; end. And if a hypertee is degree 1, then it's always of the shape
; "( )", so it always has a single value corresponding to the ")".
;
; The name "hypertee" refers to the way it's like a T-shaped coupling.
; It's not exactly a symmetrical branch like the nodes of an everyday
; tree, because some of the holes shoot off in a different dimension
; from all the others.
;
; The values of a hypertee's holes represent information about what's
; on the other side of that hole, rather than telling us something
; about the *inside* of the hypersnippet region of that shape. If we
; want to represent simple data inside that shape, we can simply pair
; the hypertee with a second value representing that data.
;
; Sometimes, the data of a hypersnippet isn't so simple that it can
; be represented using a single first-class value. For instance,
; consider the data in an interpolated string:
;
;     "Hello, ${name}! It's ${weather} today."
;
; The string content of this interpolated string is a degree-1
; hypersnippet with two degree-1 holes (and a degree-0 hole). Here's
; that hypersnippet's shape:
;
;   ^2(       ,(    )       ,(       )       )
;
; On the other side of the degree-1 holes are the expressions `name`
; and `weather`. We can use a hypertee to carry those two expressions
; in a way that keeps track of which hole they each belong to, but
; that doesn't help us carry the strings "Hello, " and "! It's " and
; " today.". We can carry those by moving to a more sophisticated
; representation built out of hypertees.
;
; Above, we were taking a hypersnippet shape, removing its high-degree
; holes, and demoting it to successively lower degrees to visualize
; its structure better. We'll use another way we can demote a
; hypersnippet shape to lower-degree shapes, and this one doesn't lose
; any information.
;
; We'll divide it into stripes, where every other stripe (a "lake")
; represents a hole in the original, and the others ("islands")
; represent pieces of the hypersnippet in between those holes:
;
;   ^2(       ,(    )       ,(       )       )
;
;     (        )
;              (    )
;                   (        )
;                            (       )
;                                    (       )
;
; This can be extrapolated to other degrees. Here's a degree-3
; hypersnippet shape divided into degree-2 stripes:
;
;   ^3( ,( ) ~2(  ,( ,( ) )     ,( ,( ) ) ) )
;
;   ^2( ,( )  ,(                          ) )
;            ^2(  ,(      )     ,(      ) )
;                ^2( ,( ) )    ^2( ,( ) )
;
; Note that in an island, some of the highest-degree holes are
; standing in for holes of the next degree, so they contain lakes,
; but others just represent holes of their own degree. Lower-degree
; holes always represent themselves, never lakes. These rules
; characterize the structure of our stripe-divided data.
;
; Once we divide a hypersnippet shape up this way, we can represent
; each island as a pair of a data value and the hypertee of lakes and
; non-lake hole contents beyond, while we represent each lake as a
; pair of its hole contents and the hypertee of islands beyond.
;
; So in particular, for our interpolated string example, we represent
; the data like this, placing each string segment in a different
; island's data:
;
;  An island representing "Hello, ${name}! It's ${weather} today."
;   |
;   |-- First part: The string "Hello, "
;   |
;   `-- Rest: Hypertee of shape "( )"
;        |
;        `-- Hole of shape ")": A lake representing "${name}! It's ${weather} today."
;             |
;             |-- Hole content: The expression `name`
;             |
;             `-- Rest: Hypertee of shape "( )"
;                  |
;                  `-- Hole of shape ")": An island representing "! It's ${weather} today."
;                       |
;                       |-- First part: The string "! It's "
;                       |
;                       `-- Rest: Hypertee of shape "( )"
;                            |
;                            `-- Hole of shape ")": A lake representing "${weather} today."
;                                 |
;                                 |-- Hole content: The expression `weather`
;                                 |
;                                 `-- Rest: Hypertee of shape "( )"
;                                      |
;                                      `-- Hole of shape ")": Interpolated string expression " today."
;                                           |
;                                           |-- First part: The string " today."
;                                           |
;                                           `-- Rest: Hypertee of shape "( )"
;                                                |
;                                                `-- Hole of shape ")": A non-lake
;                                                     |
;                                                     `-- An ignored trivial value
;
; We call this representation a "hyprid" ("hyper" + "hybrid") since it
; stores both hypersnippet information and the hypertee information
; beyond the holes. Actually, hyprids generalize this striping a bit
; further by allowing the stripes to be striped, and so on. Each
; iteration of the striping works the same way, but the concept of
; "hypertee of shape S" is replaced with "stripes that collapse to a
; hypertee of shape S."
;
; (TODO: This documentation is a bit old now. We still implement
; hyprids in `punctaffy/private/experimental/hyprid`, but we're taking
; a different approach now, "hypernests" (implemented in
; `punctaffy/hyprsnippet/hypernest`), where string pieces like these
; can be represented as degree-1 nested hypernests. Whereas a hypertee
; is a series of labeled closing brackets of various degrees, a
; hypernest is a series of labeled closing brackets and labeled
; opening brackets of various degrees. Once we update this
; documentation, we should probably move this example into
; `punctaffy/private/experimental/hyprid` rather than just tossing it
; out.)
;
; A hyprid can have a number of striping iterations strictly less than
; the degree it has when collapsed to a hypertee. For instance, adding
; even one degree of striping to a degree-1 hyprid doesn't work, since
; an island stripe of degree 0 would have no holes to carry a lake
; stripe in at all.
;
; For circumstances where we're willing to discard the string
; information of our interpolated string, we can use the operation
; `hyprid-destripe-once` to get back a simpler hypertee:
;
;   Hypertee of shape "^2( ,( ) ,( ) )"
;    |
;    |-- First hole of shape ",( )": The expression `name`
;    |
;    |-- Second hole of shape ",( )": The expression `weather`
;    |
;    `-- Hole of shape ")": An ignored trivial value
;
; Technically, `hyprid-destripe-once` returns a hyprid of one less
; stripe iteration. We also offer an operation that collapses all
; degrees of stripes at once, `hyprid-fully-destripe`, which always
; results in a hypertee value.
;
; Note that it would not be so easy to represent hypersnippet data
; without building it out of hypertees. If we have hypertees, we can
; do something like a "flatmap" operation where we process the holes
; to generate more hypertees and then join them all together into one
; combined hypertee. If we were to write an operation like that for
; interpolated strings, we would have to pass in (or assume) a string
; concatenation operation so that "foo${"bar"}baz" could properly
; turn into "foobarbaz". Higher degrees of hypersnippets will likely
; need to use higher-degree notions of concatenation in order to be
; flatmapped, and we haven't explored these yet (TODO).
;
;
; == Verifying hypersnippet shapes ==
;
; So now that we know how to represent hypersnippet-shaped information
; using hypertees, the trickiest part of the implementation of
; hypertees is how to represent the shape itself.
;
; As above, here's an example of a degree-4 hypersnippet shape along
; with variations where its high-degree holes are removed so that it's
; easier to see its matching structure at a glance:
;
;     ;
;     (                                       )
;   ^2(                      ,( )             )
;   ^3(         ~2( ,(       ,( )     ) )     )
;   ^4( ~3( ~2( ~2( ,( ,( ,( ,( ) ) ) ) ) ) ) )
;
; And here's an example of running an algorithm from left to right across the sequence of brackets to verify that it's properly balanced:
;
;      | 4
;          | 3 (4, 4, 4)
;              | 4 (3 (4, 4, *), 3 (4, 4, 4))
;                  | 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))
;                     | 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))
;                        | 3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))))
;                           | 4 (3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))))
;                              | 1 (4 (3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))))))
;                                | 4 (3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))))
;                                  | 3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))))
;                                    | 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))
;                                      | 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))
;                                        | 4 (3 (4, 4, *), 3 (4, 4, 4))
;                                          | 3 (4, 4, 4)
;                                            | 4
;                                              | 0
;
; We needed a bunch of specialized notation just for this
; demonstration. The notation "|" represents the cursor as it runs
; through the brackets shown above. The notation "*" represents parts
; of the state that are unnecessary to keep track of. The notation "4"
; by itself is shorthand for "4 ()". A notation like "4 ()" which has
; a shorter list than the number declared is also shorthand; its list
; represents only the lowest-degree parts of a full 4-element list,
; which could be written as
; "4 (3 (*, *, *), 2 (*, *), 1 (*, *), 0 ())". The implicit
; higher-degree slots are filled in with lists of the same length as
; their degree. Once fully expanded, the numbers are superfluous; they
; just represent the length of the list that follows, which
; corresponds with the degree of the current region in the syntax.
;
; In general, these lists in the history represent what history states
; will be "restored" (perhaps for the first time) when a closing
; bracket of that degree is encountered.
;
; The algorithm proceeds by consuming a bracket, restoring the
; corresponding element of the history (counting from the right to the
; left in this example), and finally replacing each element of the
; looked-up state with the previous state if it's a slot of lower
; degree than the bracket is. (That's why so many parts of the history
; are "*"; if they're ever used, those parts will necessarily be
; overwritten anyway.)
;
; If we introduce a shorthand ">" that means "this element is a
; duplicate of the element to the right," we can display that example
; more economically:
;
;   ^4( ~3( ~2( ~2( ,( ,( ,( ,( ) ) ) ) ) ) ) )
;
;      | 4
;          | 3 (>, >, 4)
;              | 4 (>, 3 (>, >, 4))
;                  | 2 (>, 4 (>, 3 (>, >, 4)))
;                     | 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))
;                        | 3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4)))))
;                           | 4 (3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))))
;                              | 1 (4 (3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4)))))))
;                                | 4 (3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))))
;                                  | 3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4)))))
;                                    | 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))
;                                      | 2 (>, 4 (>, 3 (>, >, 4)))
;                                        | 4 (>, 3 (>, >, 4))
;                                          | 3 (>, >, 4)
;                                            | 4
;                                              | 0
;
; In fact, the actual implementation in
; `assert-valid-hypertee-brackets` represents the history lists in
; reverse order. Here, the slots are displayed from highest to lowest
; degree so that history tends to be appended to and removed from the
; left side (where the cursor is).
;
; If we tried to enforce all of the bracket-balancing in a more
; incremental, structured way, it would be rather difficult. Here's a
; sketch of what the hypertee type itself would look like if we were
; to define it as a correct-by-construction algebraic data type:
;
;   data Hypertee :
;     (n : Nat) ->
;     ( (i : Fin n) ->
;       Hypertee (finToNat i) (\i iEdge -> ()) ->
;       Type) ->
;     Type
;   where
;     HyperteeZ : Hypertee 0 finAbsurd
;     HyperteeS :
;       {n : Nat} ->
;       {m : Fin n} ->
;       {v :
;         (i : Fin n) ->
;         Hypertee (finToNat i) (\i iEdge -> ()) ->
;         Type} ->
;       (edge :
;         Hypertee finToNat m \i iEdge ->
;           (fill : Hypertee n \j jEdge ->
;             if finToNat j < finToNat i
;               then ()
;               else v j) *
;           (hyperteeTruncate (finToNat i) fill = iEdge)) ->
;       v m (hyperteeMapAllDegrees edge \i iEdge val -> ()) ->
;       Hypertee v
;
; This type must be defined as part of an induction-recursion with the
; functions `hyperteeTruncate` (which would remove the highest-degree
; holes from a hypertee and lower its degree, as we provide here under
; the name `hypertee-truncate`) and `hyperteeMapAllDegrees`, which
; seem to end up depending on quite a lot of other constructions.



(define/contract (hypertee-closing-bracket-degree closing-bracket)
  (-> (or/c onum<omega? #/list/c onum<omega? any/c) onum<omega?)
  (mat closing-bracket (list d data)
    d
    closing-bracket))

(define/contract
  (assert-valid-hypertee-brackets opening-degree closing-brackets)
  (-> onum<=omega? list? void?)
;  (void)#;
  (w- final-region-degree
    (poppable-hyperstack-dimension #/list-foldl
      (make-poppable-hyperstack-n opening-degree)
      closing-brackets
    #/fn histories closing-bracket
      (w- closing-degree
        (hypertee-closing-bracket-degree closing-bracket)
      #/expect
        (onum<? closing-degree
        #/poppable-hyperstack-dimension histories)
        #t
        (error "Encountered a closing bracket of degree higher than the current region's degree")
      #/w- restored-history
        (poppable-hyperstack-pop-n histories closing-degree)
      #/begin
        (if
          (equal? closing-degree
          #/poppable-hyperstack-dimension restored-history)
          ; NOTE: We don't validate `hole-value`.
          (expect closing-bracket (list closing-degree hole-value)
            (raise-arguments-error 'degree-and-closing-brackets->hypertee
              "expected a closing bracket that began a hole to be annotated with a data value"
              "opening-degree" opening-degree
              "closing-brackets" closing-brackets
              "closing-bracket" closing-bracket)
          #/void)
          (mat closing-bracket (list closing-degree hole-value)
            (raise-arguments-error 'degree-and-closing-brackets->hypertee
              "expected a closing bracket that did not begin a hole to have no data value annotation"
              "opening-degree" opening-degree
              "closing-brackets" closing-brackets
              "closing-bracket" closing-bracket)
          #/void))
        restored-history))
  #/expect final-region-degree 0
    (raise-arguments-error 'degree-and-closing-brackets->hypertee
      "expected more closing brackets"
      "opening-degree" opening-degree
      "closing-brackets" closing-brackets
      "final-region-degree" final-region-degree)
  #/void))


(struct-easy (hypertee degree closing-brackets)
  #:equal
  (#:guard-easy
    (assert-valid-hypertee-brackets degree closing-brackets)))

; A version of `hypertee?` that does not satisfy
; `struct-predicate-procedure?`.
(define/contract (-hypertee? v)
  (-> any/c boolean?)
  (hypertee? v))

; A version of the `hypertee` constructor that does not satisfy
; `struct-constructor-procedure?`.
(define/contract
  (degree-and-closing-brackets->hypertee degree closing-brackets)
  (->
    onum<=omega?
    (listof #/or/c onum<omega? #/list/c onum<omega? any/c)
    hypertee?)
  ; TODO: See if we can improve the error messages so that they're
  ; like part of the contract of this procedure instead of being
  ; thrown from inside the `hypertee` constructor.
  (hypertee degree closing-brackets))

; A version of `hypertee-degree` that does not satisfy
; `struct-accessor-procedure?`.
(define/contract (-hypertee-degree ht)
  (-> hypertee? onum<=omega?)
  (dissect ht (hypertee d closing-brackets)
    d))

(define/contract (hypertee->degree-and-closing-brackets ht)
  (-> hypertee?
    (list/c onum<=omega?
    #/listof #/or/c onum<omega? #/list/c onum<omega? any/c))
  (dissect ht (hypertee d closing-brackets)
  #/list d closing-brackets))

; Takes a hypertee of any nonzero degree N and upgrades it to any
; degree N or greater, while leaving its holes the way they are.
(define/contract (hypertee-promote new-degree ht)
  (-> onum<=omega? hypertee? hypertee?)
  (dissect ht (hypertee d closing-brackets)
  #/mat d 0
    (raise-arguments-error 'hypertee-promote
      "expected ht to be a hypertee of nonzero degree"
      "ht" ht)
  #/expect (onum<=? d new-degree) #t
    (raise-arguments-error 'hypertee-promote
      "expected ht to be a hypertee of degree no greater than new-degree"
      "new-degree" new-degree
      "ht" ht)
  #/hypertee new-degree closing-brackets))

; Takes a nonzero-degree hypertee and returns a `just` of a degree-N
; hypertee with the same holes if possible. If this isn't possible
; (because some holes in the original are of degree N or greater),
; this returns `(nothing)`.
(define/contract (hypertee-set-degree-maybe new-degree ht)
  (-> onum<=omega? hypertee? #/maybe/c hypertee?)
  (dissect ht (hypertee d closing-brackets)
  #/mat d 0
    (raise-arguments-error 'hypertee-set-degree-maybe
      "expected ht to be a hypertee of nonzero degree"
      "ht" ht)
  #/if
    (or (onum<=? d new-degree)
    #/list-all closing-brackets #/fn closing-bracket
      (expect closing-bracket (list d data) #t
      #/onum<? d new-degree))
    (just #/hypertee new-degree closing-brackets)
    (nothing)))

; Takes a nonzero-degree hypertee with no holes of degree N or greater
; and returns a degree-N hypertee with the same holes.
(define/contract (hypertee-set-degree new-degree ht)
  (-> onum<=omega? hypertee? hypertee?)
  (expect (hypertee-set-degree-maybe new-degree ht) (just result)
    (error "Expected ht to have no holes of degree new-degree or greater")
    result))

(define/contract (hypertee<omega? v)
  (-> any/c boolean?)
  (and (hypertee? v) (onum<omega? #/hypertee-degree v)))

; Takes a hypertee of any degree N and returns a hypertee of degree
; N+1 with all the same degree-less-than-N holes as well as a single
; degree-N hole in the shape of the original hypertee. This should
; be useful as something like a monadic return.
(define/contract (hypertee-contour hole-value ht)
  (-> any/c hypertee<omega? hypertee?)
  (dissect ht (hypertee d closing-brackets)
  #/hypertee (onum-plus d 1)
  #/cons (list d hole-value)
  #/list-bind closing-brackets #/fn closing-bracket
    (list (hypertee-closing-bracket-degree closing-bracket)
      closing-bracket)))

; Takes a hypertee of any degree N and returns a hypertee of degree
; 1+N where each hole has been replaced with a one-degree-greater
; hole. This creates one new hole of degree 0.
(define/contract (hypertee-tunnel hole-value ht)
  (-> any/c hypertee? hypertee?)
  (dissect ht (hypertee d closing-brackets)
  #/hypertee (onum-plus1 d)
  #/append
    (list-map closing-brackets #/fn closing-bracket
      (mat closing-bracket (list d data)
        (list (onum-plus1 d) data)
        (onum-plus1 closing-bracket)))
    (make-list (length closing-brackets) 0)
    (list #/list 0 hole-value)))

(define/contract (hypertee-drop1 ht)
  (-> hypertee? #/maybe/c #/list/c any/c hypertee?)
  
  (struct-easy (loc-outside))
  (struct-easy (loc-dropped))
  (struct-easy (loc-interpolation-uninitialized))
  (struct-easy (loc-interpolation i d))
  
  (struct-easy
    (interpolation-state-in-progress
      rev-brackets interpolation-hyperstack))
  (struct-easy (interpolation-state-finished result))
  
  (dissect ht (hypertee d-root closing-brackets)
  #/expect closing-brackets (cons first rest) (nothing)
  #/dissect first (list d-dropped data-dropped)
  #/just #/list data-dropped
  ; NOTE: This special case is necessary. Most of the code below goes
  ; smoothly for a `d-dropped` equal to `0`, but the fold ends with a
  ; location of `(loc-dropped)` instead of `(loc-outside)`.
  #/mat d-dropped 0 (hypertee 0 #/list)
  #/w- stack
    (make-poppable-hyperstack #/olist-build d-root #/dissectfn _
      (loc-outside))
  #/dissect
    (poppable-hyperstack-pop stack
    #/olist-build d-dropped #/dissectfn _
      (loc-interpolation-uninitialized))
    (list popped-barrier (loc-outside) stack)
  #/w-loop next
    root-brackets (list-kv-map rest #/fn k v #/list k v)
    interpolations (make-immutable-hasheq)
    hist (list (loc-dropped) stack)
    rev-result (list)
    
    (define (push-interpolation-bracket interpolations i bracket)
      (w- d (hypertee-closing-bracket-degree bracket)
      #/dissect (hash-ref interpolations i)
        (interpolation-state-in-progress
          rev-brackets interpolation-hyperstack)
      #/dissect
        (poppable-hyperstack-pop-n-with-barrier
          interpolation-hyperstack d)
        (list popped-barrier interpolation-hyperstack)
      #/hash-set interpolations i
        (interpolation-state-in-progress
          (cons (mat popped-barrier 'root bracket d) rev-brackets)
          interpolation-hyperstack)))
    
    (define
      (push-interpolation-bracket-and-possibly-finish
        interpolations i bracket)
      (w- interpolations
        (push-interpolation-bracket interpolations i bracket)
      #/dissect (hash-ref interpolations i)
        (interpolation-state-in-progress
          rev-brackets interpolation-hyperstack)
      #/hash-set interpolations i
        (mat (poppable-hyperstack-dimension interpolation-hyperstack)
          0
          (interpolation-state-finished
          #/hypertee d-root #/reverse rev-brackets)
          (interpolation-state-in-progress
            rev-brackets interpolation-hyperstack))))
    
    (expect root-brackets (cons root-bracket root-brackets)
      (dissect hist (list (loc-outside) stack)
      #/dissect (poppable-hyperstack-dimension stack) 0
      ; We look up all the indexes stored in `rev-result` and make a
      ; hypertee out of it.
      #/hypertee d-dropped #/reverse
      #/list-map rev-result #/fn bracket
        (expect bracket (list d i) bracket
        #/dissect (hash-ref interpolations i)
          (interpolation-state-finished tail)
        #/list d tail))
    #/dissect root-bracket (list new-i closing-bracket)
    #/dissect hist (list loc stack)
    #/w- d-bracket (hypertee-closing-bracket-degree closing-bracket)
    #/dissect
      (poppable-hyperstack-pop stack
      #/olist-build d-bracket #/dissectfn _ loc)
      (list popped-barrier tentative-new-loc tentative-new-stack)
    #/mat loc (loc-outside)
      (dissect tentative-new-loc (loc-interpolation i d)
      #/next root-brackets
        (push-interpolation-bracket interpolations i closing-bracket)
        (list tentative-new-loc tentative-new-stack)
        rev-result)
    #/mat loc (loc-dropped)
      (mat tentative-new-loc (loc-interpolation-uninitialized)
        (next root-brackets
          (hash-set interpolations new-i
            (interpolation-state-in-progress (list)
              (make-poppable-hyperstack-n d-root)))
          (list
            (loc-interpolation new-i closing-bracket)
            tentative-new-stack)
          (cons (list closing-bracket new-i) rev-result))
      #/dissect tentative-new-loc (loc-interpolation i d)
        (next root-brackets
          (push-interpolation-bracket interpolations i
            closing-bracket)
          (list tentative-new-loc tentative-new-stack)
          (cons closing-bracket rev-result)))
    #/mat loc (loc-interpolation i d)
      (mat tentative-new-loc (loc-outside)
        (next root-brackets
          (push-interpolation-bracket-and-possibly-finish
            interpolations i closing-bracket)
          (list tentative-new-loc tentative-new-stack)
          rev-result)
      #/dissect tentative-new-loc (loc-dropped)
        (next root-brackets
          (push-interpolation-bracket-and-possibly-finish
            interpolations i
            (list closing-bracket #/trivial))
          (list tentative-new-loc tentative-new-stack)
          (cons closing-bracket rev-result)))
    #/error "Internal error: Entered an unexpected kind of region in hypertee-drop1")))

(define/contract (hypertee-dv-map-all-degrees ht func)
  (-> hypertee? (-> onum<omega? any/c any/c) hypertee?)
  (dissect ht (hypertee degree closing-brackets)
  #/hypertee degree #/list-map closing-brackets #/fn bracket
    (expect bracket (list d data) bracket
    #/list d #/func d data)))

(define/contract (hypertee-v-map-one-degree degree ht func)
  (-> onum<omega? hypertee? (-> any/c any/c) hypertee?)
  (hypertee-dv-map-all-degrees ht #/fn hole-degree data
    (if (equal? degree hole-degree)
      (func data)
      data)))

(define/contract (hypertee-v-map-pred-degree degree ht func)
  (-> onum<=omega? hypertee? (-> any/c any/c) hypertee?)
  
  ; If the degree is 0 or a limit ordinal, we have nothing to do. No
  ; hole's degree has the given degree as its successor, so there are
  ; no holes to process.
  (expect (onum-pred-maybe degree) (just pred-degree) ht
  
  #/hypertee-v-map-one-degree pred-degree ht func))

(define/contract (hypertee-v-map-highest-degree ht func)
  (-> hypertee? (-> any/c any/c) hypertee?)
  (hypertee-v-map-pred-degree (hypertee-degree ht) ht func))

(define/contract (hypertee-fold first-nontrivial-d ht func)
  (->
    onum<=omega?
    hypertee?
    (-> onum<=omega? any/c hypertee<omega? any/c)
    any/c)
  (mat (hypertee-degree ht) 0
    ; TODO: Make this part of the contract instead.
    (error "Expected ht to be a hypertee of degree greater than 0")
  #/dissect (hypertee-drop1 ht) (just #/list data tails)
  #/func first-nontrivial-d data
  #/hypertee-dv-map-all-degrees tails #/fn hole-degree tail
    (hypertee-fold (onum-max first-nontrivial-d hole-degree) tail
      func)))

; TODO: See if we can simplify the implementation of
; `hypertee-join-all-degrees` to something like this now that we have
; `hypertee-fold`. There are a few potential circular dependecy
; problems: The implementations of `hypertee-plus1`,
; `hypertee-map-all-degrees`, `hypertee-truncate`, and
; `hypertee-zip-low-degrees` depend on `hypertee-join-all-degrees`.
;
#;
(define/contract (hypertee-join-all-degrees ht)
  (-> hypertee? hypertee?)
  (mat (hypertee-degree ht) 0 ht
  #/hypertee-fold 0 ht #/fn first-nontrivial-d suffix tails
    (w- d (hypertee-degree tails)
    #/if (onum<? d first-nontrivial-d)
      (dissect suffix (trivial)
      ; TODO: See if this is correct.
      #/hypertee-plus1 (hypertee-degree ht)
      #/just #/list (trivial) tails)
    #/expect
      (and
        (hypertee? suffix)
        (onum<? (hypertee-degree tails) (hypertee-degree suffix)))
      #t
      (error "Expected each interpolation of a hypertee join to be a hypertee of the right shape for its interpolation context")
    #/expect
      (hypertee-zip-low-degrees tails suffix #/fn hole tail suffix
        (dissect suffix (trivial)
          tail))
      (just zipped)
      (error "Expected each interpolation of a hypertee join to be a hypertee of the right shape for its interpolation context")
    #/hypertee-join-all-degrees zipped)))

; TODO: See if we should switch to this implementation for
; `hypertee-map-all-degrees`.
;
#;
(define/contract (hypertee-map-all-degrees ht func)
  (-> hypertee? (-> hypertee<omega? any/c any/c) hypertee?)
  (mat (hypertee-degree ht) 0 ht
  #/hypertee-fold 0 ht #/fn first-nontrivial-d data tails
    (w- d (hypertee-degree tails)
    #/if (onum<? d first-nontrivial-d)
      (dissect data (trivial)
      #/hypertee-plus1 (hypertee-degree ht)
      #/just #/list (trivial) tails)
    #/w- hole
      (hypertee-dv-map-all-degrees tails #/fn d data #/trivial)
    #/hypertee-plus1 (hypertee-degree ht)
    #/just #/list (func hole data) tails)))

(struct-easy (hypertee-join-selective-interpolation val) #:equal)
(struct-easy (hypertee-join-selective-non-interpolation val) #:equal)

; This takes a hypertee of degree N where each hole value of each
; degree M is either a `hypertee-join-selective-interpolation`
; containing another degree-N hypertee to be interpolated or a
; `hypertee-join-selective-non-interpolation`. In those interpolated
; hypertees, each value of a hole of degree L is either a
; `hypertee-join-selective-non-interpolation` or, if L is less than M,
; possibly a `hypertee-join-selective-interpolation` of a `trivial`
; value. This returns a single degree-N hypertee which has holes for
; all the non-interpolations of the interpolations and the
; non-interpolations of the root.
;
(define/contract (hypertee-join-all-degrees-selective ht)
  (-> hypertee? hypertee?)
  
  (struct-easy (state-in-root))
  (struct-easy (state-in-interpolation i))
  
  (dissect ht (hypertee overall-degree closing-brackets)
  #/w-loop next
    root-brackets (list-kv-map closing-brackets #/fn k v #/list k v)
    interpolations (make-immutable-hasheq)
    hist
      (list (state-in-root)
      #/make-pushable-hyperstack
      #/olist-build overall-degree #/dissectfn _ #/state-in-root)
    rev-result (list)
    
    (define (finish root-brackets interpolations rev-result)
      (expect root-brackets (list)
        (error "Internal error: Encountered the end of a hypertee join interpolation in a region of degree 0 before getting to the end of the root")
      #/void)
      (hash-kv-each interpolations #/fn i interpolation-brackets
        (expect interpolation-brackets (list)
          (error "Internal error: Encountered the end of a hypertee join root before getting to the end of its interpolations")
        #/void))
      
      ; NOTE: It's possible for this to throw errors, particularly if
      ; some of the things we've joined together include annotated
      ; holes in places where holes of that degree shouldn't be
      ; annotated (because they're closing another hole). Despite the
      ; fact that the errors this raises aren't associated with
      ; `hypertee-join-all-degrees-selective` or caught earlier during
      ; this process, I've found them to be surprisingly helpful since
      ; it's easy to modify this code to log the fully constructed
      ; list of brackets.
      ;
      (hypertee overall-degree #/reverse rev-result))
    
    (define (pop-interpolation-bracket interpolations i)
      (expect (hash-ref interpolations i) (cons bracket rest)
        (list interpolations #/nothing)
        (list (hash-set interpolations i rest) #/just bracket)))
    
    (define (verify-bracket-degree d closing-bracket)
      (unless
        (equal? d #/hypertee-closing-bracket-degree closing-bracket)
        (raise-arguments-error 'hypertee-join-all-degrees-selective
          "expected each interpolation of a hypertee join to be the right shape for its interpolation context"
          "expected-closing-bracket-degree" d
          "actual-closing-bracket" closing-bracket
          "ht" ht)))
    
    (dissect hist (list state histories)
    #/mat state (state-in-interpolation interpolation-i)
      
      ; We read from the interpolation's closing bracket stream.
      (dissect
        (pop-interpolation-bracket interpolations interpolation-i)
        (list interpolations maybe-bracket)
      #/expect maybe-bracket (just closing-bracket)
        (expect (pushable-hyperstack-dimension histories) 0
          (error "Internal error: A hypertee join interpolation ran out of brackets before reaching a region of degree 0")
        ; The interpolation has no more closing brackets, and we're in
        ; a region of degree 0, so we end the loop.
        #/finish root-brackets interpolations rev-result)
      #/mat closing-bracket
        (list d #/hypertee-join-selective-non-interpolation data)
        ; We begin a non-interpolation in an interpolation.
        (w- histories
          (pushable-hyperstack-push histories
          #/olist-build d #/dissectfn _ state)
        #/w- hist (list state histories)
        #/next root-brackets interpolations hist
          (cons (list d data) rev-result))
      #/w- closing-bracket
        (expect closing-bracket (list d data) closing-bracket
        #/expect data (hypertee-join-selective-interpolation data)
          (error "Expected each hole of a hypertee join interpolation to contain a hypertee-join-selective-interpolation or a hypertee-join-selective-non-interpolation")
        #/list d data)
      #/w- d (hypertee-closing-bracket-degree closing-bracket)
      #/expect (onum<? d #/pushable-hyperstack-dimension histories) #t
        (error "Expected each high-degree hole of a hypertee join interpolation to be a hypertee-join-selective-non-interpolation")
      #/dissect
        (pushable-hyperstack-pop histories
        #/olist-build d #/dissectfn _ state)
        (list popped-barrier state histories)
      #/w- hist (list state histories)
      #/mat state (state-in-root)
        
        ; We've moved out of the interpolation through a low-degree
        ; hole and arrived at the root. Now we proceed by processing
        ; the root's brackets instead of the interpolation's brackets.
        ;
        (dissect root-brackets
          (cons (list root-bracket-i root-bracket) root-brackets)
        #/begin
          (verify-bracket-degree d root-bracket)
          (mat closing-bracket (list d data)
            (expect data (trivial)
              ; TODO: Make more of the errors like this one.
              (raise-arguments-error
                'hypertee-join-all-degrees-selective
                "a hypertee join interpolation had an interpolation of low degree where the value wasn't a trivial value"
                "ht" ht
                "closing-bracket" closing-bracket
                "data" data)
            #/void)
          #/void)
        #/next root-brackets interpolations hist rev-result)
      #/dissect state (state-in-interpolation i)
        
        ; We just moved out of a non-interpolation of the
        ; interpolation, so we're still in the interpolation, and we
        ; continue to proceed by processing the interpolation's
        ; brackets.
        ;
        (next root-brackets interpolations hist
          (cons closing-bracket rev-result)))
    
    ; We read from the root's closing bracket stream.
    #/expect root-brackets (cons root-bracket root-brackets)
      (expect (pushable-hyperstack-dimension histories) 0
        (error "Internal error: A hypertee join root ran out of brackets before reaching a region of degree 0")
      ; The root has no more closing brackets, and we're in a region
      ; of degree 0, so we end the loop.
      #/finish root-brackets interpolations rev-result)
    #/dissect root-bracket (list root-bracket-i closing-bracket)
    #/mat closing-bracket
      (list d #/hypertee-join-selective-non-interpolation data)
      ; We begin a non-interpolation in the root.
      (w- histories
        (pushable-hyperstack-push histories
        #/olist-build d #/dissectfn _ state)
      #/w- hist (list state histories)
      #/next root-brackets interpolations hist
        (cons (list d data) rev-result))
    #/w- closing-bracket
      (expect closing-bracket (list d data) closing-bracket
      #/expect data (hypertee-join-selective-interpolation data)
        (error "Expected each hole of a hypertee join root to contain a hypertee-join-selective-interpolation or a hypertee-join-selective-non-interpolation")
      #/list d data)
    #/w- d (hypertee-closing-bracket-degree closing-bracket)
    #/expect (onum<? d #/pushable-hyperstack-dimension histories) #t
      (error "Internal error: Expected the next closing bracket of a hypertee join root to be of a degree less than the current region's degree")
    #/dissect
      (pushable-hyperstack-pop histories
      #/olist-build d #/dissectfn _ state)
      (list popped-barrier state histories)
    #/expect closing-bracket (list d data)
      (w- hist (list state histories)
      #/mat state (state-in-root)
        ; We just moved out of a non-interpolation of the root, so
        ; we're still in the root.
        (next root-brackets interpolations hist
          (cons closing-bracket rev-result))
      #/dissect state (state-in-interpolation i)
        ; We resume an interpolation in the root.
        (dissect (pop-interpolation-bracket interpolations i)
          (list interpolations #/just interpolation-bracket)
        #/begin (verify-bracket-degree d interpolation-bracket)
        #/next root-brackets interpolations hist rev-result))
    ; We begin an interpolation in the root.
    #/expect data (hypertee data-d data-closing-brackets)
      (raise-arguments-error 'hypertee-join-all-degrees-selective
        "expected each hypertee join interpolation to be a hypertee"
        "ht" ht
        "closing-bracket" closing-bracket
        "data" data)
    #/expect (equal? data-d overall-degree) #t
      (raise-arguments-error 'hypertee-join-all-degrees-selective
        "expected each hypertee join interpolation to have the same degree as the root"
        "ht" ht
        "closing-bracket" closing-bracket
        "data" data)
    #/next root-brackets
      (hash-set interpolations root-bracket-i data-closing-brackets)
      (list (state-in-interpolation root-bracket-i) histories)
      rev-result)))

(define/contract (hypertee-map-all-degrees ht func)
  (-> hypertee? (-> hypertee<omega? any/c any/c) hypertee?)
  (dissect ht (hypertee overall-degree closing-brackets)
  ; NOTE: This special case is necessary. Most of the code below goes
  ; smoothly for an `overall-degree` equal to `0`, but the loop ends
  ; with a `maybe-current-hole` of `(nothing)`.
  #/mat overall-degree 0 (hypertee 0 #/list)
  #/w- result
    (list-kv-map closing-brackets #/fn i closing-bracket
      (expect closing-bracket (list d data) closing-bracket
      #/list d #/list data i))
  #/dissect
    (list-foldl
      (list
        (list-foldl (make-immutable-hasheq) result
        #/fn hole-states closing-bracket
          (expect closing-bracket (list d data) hole-states
          #/dissect data (list data i)
          #/hash-set hole-states i
            (list (list) (make-poppable-hyperstack-n d))))
        (list (nothing)
          (make-poppable-hyperstack
          #/olist-build overall-degree #/dissectfn _ #/nothing)))
      result
    #/fn state closing-bracket
      (dissect state
        (list hole-states #/list maybe-current-hole histories)
      #/w- d (hypertee-closing-bracket-degree closing-bracket)
      #/expect (onum<? d #/poppable-hyperstack-dimension histories) #t
        (error "Internal error: Encountered a closing bracket of degree higher than the root's current region")
      #/dissect
        (poppable-hyperstack-pop histories
        #/olist-build d #/dissectfn _ maybe-current-hole)
        (list popped-barrier maybe-restored-hole histories)
      #/w- update-hole-state
        (fn hole-states i
          (dissect (hash-ref hole-states i) (list rev-brackets hist)
          #/expect (onum<? d #/poppable-hyperstack-dimension hist) #t
            (error "Internal error: Encountered a closing bracket of degree higher than the hole's current region")
          #/w- hist (poppable-hyperstack-pop-n hist d)
          #/hash-set hole-states i
            (list
              (cons
                (if (equal? d #/poppable-hyperstack-dimension hist)
                  (list d #/trivial)
                  d)
                rev-brackets)
              hist)))
      #/mat maybe-current-hole (just i)
        (mat maybe-restored-hole (just i)
          (error "Internal error: Went directly from one hole to another in progress")
        #/mat closing-bracket (list d #/list data i)
          (error "Internal error: Went directly from one hole to another's beginning")
        #/list (update-hole-state hole-states i)
          (list (nothing) histories))
      #/mat maybe-restored-hole (just i)
        (mat closing-bracket (list d #/list data i)
          (error "Internal error: Went into two holes at once")
        #/list (update-hole-state hole-states i)
          (list (just i) histories))
      #/mat closing-bracket (list d #/list data state)
        ; NOTE: We don't need to `update-hole-state` here because as
        ; far as this hole's state is concerned, this bracket is the
        ; opening bracket of the hole, not a closing bracket.
        (list hole-states #/list (just state) histories)
      #/error "Internal error: Went directly from the root to the root without passing through a hole"))
    (list hole-states #/list maybe-current-hole histories)
  #/expect (poppable-hyperstack-dimension histories) 0
    (error "Internal error: Ended hypertee-map-all-degrees without being in a zero-degree region")
  #/expect maybe-current-hole (just i)
    (error "Internal error: Ended hypertee-map-all-degrees without being in a hole")
  #/expect (hash-ref hole-states i) (list (list) state-hist)
    (error "Internal error: Ended hypertee-map-all-degrees without being in the zero-degree hole")
  #/expect (poppable-hyperstack-dimension state-hist) 0
    (error "Internal error: Ended hypertee-map-all-degrees without being in the zero-degree hole")
  #/hypertee overall-degree #/list-map result #/fn closing-bracket
    (expect closing-bracket (list d #/list data i) closing-bracket
    #/dissect (hash-ref hole-states i) (list rev-brackets hist)
    #/expect (poppable-hyperstack-dimension hist) 0
      (error "Internal error: Failed to exhaust the history of a hole while doing hypertee-map-all-degrees")
    #/list d (func (hypertee d #/reverse rev-brackets) data))))

(define/contract (hypertee-map-one-degree degree ht func)
  (-> onum<omega? hypertee? (-> hypertee? any/c any/c) hypertee?)
  (hypertee-map-all-degrees ht #/fn hole data
    (if (equal? degree #/hypertee-degree hole)
      (func hole data)
      data)))

(define/contract (hypertee-map-pred-degree degree ht func)
  (-> onum<=omega? hypertee? (-> hypertee? any/c any/c) hypertee?)
  
  ; If the degree is 0 or a limit ordinal, we have nothing to do. No
  ; hole's degree has the given degree as its successor, so there are
  ; no holes to process.
  (expect (onum-pred-maybe degree) (just pred-degree) ht
  
  #/hypertee-map-one-degree pred-degree ht func))

(define/contract (hypertee-map-highest-degree ht func)
  (-> hypertee? (-> hypertee? any/c any/c) hypertee?)
  (hypertee-map-pred-degree (hypertee-degree ht) ht func))

(define/contract (hypertee-pure degree data hole)
  (-> onum<=omega? any/c hypertee<omega? hypertee?)
  (hypertee-promote degree #/hypertee-contour data hole))

(define/contract (hypertee-get-hole-zero ht)
  (-> hypertee? maybe?)
  (dissect ht (hypertee degree closing-brackets)
  #/mat degree 0 (nothing)
  #/dissect (reverse closing-brackets) (cons (list 0 data) _)
  #/just data))

; This takes a hypertee of degree N where each hole value of each
; degree M is another degree-N hypertee to be interpolated. In those
; interpolated hypertees, the values of holes of degree less than M
; must be `trivial` values. This returns a single degree-N hypertee
; which has holes for all the degree-M-or-greater holes of the
; interpolations of each degree M.
;
(define/contract (hypertee-join-all-degrees ht)
  (-> hypertee? hypertee?)
  (hypertee-join-all-degrees-selective
  #/hypertee-dv-map-all-degrees ht #/fn root-hole-degree data
    (expect (hypertee? data) #t
      (error "Expected each interpolation of a hypertee join to be a hypertee")
    #/hypertee-join-selective-interpolation
    #/hypertee-dv-map-all-degrees data
    #/fn interpolation-hole-degree data
      (expect (onum<? interpolation-hole-degree root-hole-degree) #t
        (hypertee-join-selective-non-interpolation data)
      #/hypertee-join-selective-interpolation data))))

(define/contract (hypertee-bind-all-degrees ht hole-to-ht)
  (-> hypertee? (-> hypertee<omega? any/c hypertee?) hypertee?)
  (hypertee-join-all-degrees
  #/hypertee-map-all-degrees ht hole-to-ht))

(define/contract (hypertee-bind-one-degree degree ht func)
  (-> onum<omega? hypertee? (-> hypertee<omega? any/c hypertee?)
    hypertee?)
  (hypertee-bind-all-degrees ht #/fn hole data
    (if (equal? degree #/hypertee-degree hole)
      (func hole data)
      (hypertee-pure (hypertee-degree ht) data hole))))

(define/contract (hypertee-bind-pred-degree degree ht func)
  (-> onum<=omega? hypertee? (-> hypertee? any/c hypertee?) hypertee?)
  
  ; If the degree is 0 or a limit ordinal, we have nothing to do,
  ; because no hole's degree has the given degree as its successor, so
  ; there are no holes to process.
  (expect (onum-pred-maybe degree) (just pred-degree) ht
  
  #/hypertee-bind-one-degree pred-degree ht func))

(define/contract (hypertee-bind-highest-degree ht func)
  (-> hypertee? (-> hypertee? any/c hypertee?) hypertee?)
  (hypertee-bind-pred-degree (hypertee-degree ht) ht func))

(define/contract (hypertee-join-one-degree degree ht)
  (-> onum<omega? hypertee? hypertee?)
  (hypertee-bind-one-degree degree ht #/fn hole data
    data))

(define/contract (hypertee-dv-any-all-degrees ht func)
  (-> hypertee? (-> onum<omega? any/c any/c) any/c)
  (dissect ht (hypertee degree closing-brackets)
  #/list-any closing-brackets #/fn bracket
    (expect bracket (list d data) #f
    #/func d data)))

; TODO: See if we'll use this.
(define/contract (hypertee-v-any-one-degree degree ht func)
  (-> onum<omega? hypertee? (-> any/c any/c) any/c)
  (hypertee-dv-any-all-degrees ht #/fn d data
    (and (equal? degree d)
    #/func data)))

(define/contract (hypertee-any-all-degrees ht func)
  (-> hypertee? (-> hypertee? any/c any/c) any/c)
  (hypertee-dv-any-all-degrees
    (hypertee-map-all-degrees ht #/fn hole data
      (list hole data))
  #/fn d hole-and-data
    (dissect hole-and-data (list hole data)
    #/func hole data)))

(define/contract (hypertee-dv-all-all-degrees ht func)
  (-> hypertee? (-> onum<omega? any/c any/c) any/c)
  (dissect ht (hypertee degree closing-brackets)
  #/list-all closing-brackets #/fn bracket
    (expect bracket (list d data) #t
    #/func d data)))

(define/contract (hypertee-all-all-degrees ht func)
  (-> hypertee? (-> hypertee? any/c any/c) any/c)
  (hypertee-dv-all-all-degrees
    (hypertee-map-all-degrees ht #/fn hole data
      (list hole data))
  #/fn d hole-and-data
    (dissect hole-and-data (list hole data)
    #/func hole data)))

(define/contract (hypertee-dv-each-all-degrees ht body)
  (-> hypertee? (-> onum<omega? any/c any) void?)
  (hypertee-dv-any-all-degrees ht #/fn d data #/begin
    (body d data)
    #f)
  (void))

(define/contract (hypertee-v-each-one-degree degree ht body)
  (-> onum<omega? hypertee? (-> any/c any) void?)
  (hypertee-dv-each-all-degrees ht #/fn d data
    (when (equal? degree d)
      (body data))))

(define/contract (hypertee-each-all-degrees ht body)
  (-> hypertee? (-> hypertee? any/c any) void?)
  (hypertee-any-all-degrees ht #/fn hole data #/begin
    (body hole data)
    #f)
  (void))

(define/contract (hypertee-plus1 degree coil)
  (-> onum<=omega? (maybe/c #/list/c any/c hypertee?) hypertee?)
  (expect coil (just coil)
    (expect degree 0
      (error "Expected the degree to be zero since the coil was nothing")
    #/hypertee 0 #/list)
  #/mat degree 0
    (error "Expected the degree to be nonzero since the coil wasn't nothing")
  #/dissect coil (list data tails)
  #/expect (onum<? (hypertee-degree tails) degree) #t
    (error "Expected tails to be a hypertee with degree less than the given degree")
  #/begin
    (hypertee-dv-each-all-degrees tails #/fn d tail
      (unless
        (and (hypertee? tail) (equal? degree #/hypertee-degree tail))
        (error "Expected tails to be a hypertee with hypertees of the given degree in its holes")))
  #/begin
    (hypertee-dv-each-all-degrees tails #/fn d tail
      (hypertee-dv-each-all-degrees tail #/fn d2 data
        (when (onum<? d2 d)
        #/expect data (trivial)
          (error "Expected tails to be a hypertee containing hypertees such that a hypertee in a hole of degree N contained only trivial values at degrees less than N")
        #/void)))
  #/hypertee-join-all-degrees #/hypertee-pure degree
    (hypertee-pure degree data
    #/hypertee-dv-map-all-degrees tails #/fn d tail
      (trivial))
    tails))

(define/contract (hypertee-contour? v)
  (-> any/c boolean?)
  (and (hypertee? v)
  #/expect (onum-pred-maybe #/hypertee-degree v)
    (just expected-hole-degree)
    #f
  #/w-loop next expected-hole-degree expected-hole-degree v v
    (dissect (hypertee-drop1 v) (just #/list data tails)
    #/and (equal? expected-hole-degree #/hypertee-degree tails)
    #/hypertee-dv-all-all-degrees tails #/fn d tail
      (next d tail))))

(define/contract (hypertee-uncontour ht)
  (-> hypertee? #/maybe/c #/list/c any/c hypertee<omega?)
  (expect (hypertee-contour? ht) #t (nothing)
  #/dissect (hypertee-drop1 ht) (just #/list data tails)
  #/just #/list data #/hypertee-dv-map-all-degrees tails #/fn d data
    (dissect
      (hypertee-uncontour #/hypertee-set-degree (onum-plus d 1) data)
      (just #/list hole-value ht)
      hole-value)))

; TODO:
;
; See if we should define a higher-dimensional "reverse" operation. A
; hypertee reversal could swap any hole with, as long as the hole was
; otherwise of the same shape as the outside. More generally, we would
; have to designate a hole H1, and in each of H1's holes H2, designate
; another hole H3 of the same shape as H2. This could go recursively
; (needing to designate holes H5, H7, etc.), except that H2 already
; has a particular set of holes in spite of whatever we designate.
;
; Given a designation of those things, we could look at the bracket
; sequence and notice that we've split it up into bracket sequences
; that can be reversed individually.
;
; Is there any point to this operation? It's probably related to
; adjoint functors, right? The original motivation for this was to
; simplify our algorithms so they wouldn't have to use hyperstacks,
; but it's not clear that would happen.

; This takes a hypertee and removes all holes which don't satisfy the
; given predicate.
(define/contract (hypertee-filter ht should-keep?)
  (-> hypertee? (-> hypertee? any/c boolean?) hypertee?)
  (dissect ht (hypertee d closing-brackets)
  #/hypertee-bind-all-degrees ht #/fn hole data
    (if (should-keep? hole data)
      (hypertee-pure d data hole)
    #/mat (hypertee-degree hole) 0
      (error "Expected should-keep? to accept the degree-zero hole")
      (hypertee-promote d hole))))

; This takes a hypertee, removes all holes of degree equal to or
; greater than a given degree, and demotes the hypertee to that
; degree. The given degree must not be greater than the hypertee's
; existing degree.
(define/contract (hypertee-truncate new-degree ht)
  (-> onum<=omega? hypertee? hypertee?)
  (dissect ht (hypertee d closing-brackets)
  #/expect (onum<=? new-degree d) #t
    (error "Expected ht to be a hypertee of degree no less than new-degree")
  #/mat new-degree 0
    ; NOTE: Since `hypertee-filter` can't filter out the degree-zero
    ; hole, we treat truncation to degree zero as a special case.
    (hypertee 0 #/list)
  #/dissect
    (hypertee-filter ht #/fn hole data
      (onum<? (hypertee-degree hole) new-degree))
    (hypertee d closing-brackets)
  #/hypertee new-degree closing-brackets))

(define/contract (hypertee-zip a b func)
  (-> hypertee? hypertee? (-> hypertee? any/c any/c any/c)
    (maybe/c hypertee?))
  (dissect a (hypertee d-a closing-brackets-a)
  #/dissect b (hypertee d-b closing-brackets-b)
  #/expect (equal? d-a d-b) #t
    (error "Expected hypertees a and b to have the same degree")
  #/expect (= (length closing-brackets-a) (length closing-brackets-b))
    #t
    (nothing)
  #/maybe-map
    (w-loop next
      
      closing-brackets
      (map list closing-brackets-a closing-brackets-b)
      
      rev-zipped (list)
      
      (expect closing-brackets (cons entry closing-brackets)
        (just #/reverse rev-zipped)
      #/dissect entry (list a b)
      #/mat a (list d-a data-a)
        (mat b (list d-b data-b)
          (expect (equal? d-a d-b) #t (nothing)
          #/next closing-brackets
            (cons (list d-a #/list data-a data-b) rev-zipped))
          (nothing))
        (mat b (list d-b data-b)
          (nothing)
          (expect (equal? a b) #t (nothing)
          #/next closing-brackets (cons a rev-zipped)))))
  #/fn zipped-closing-brackets
  #/hypertee-map-all-degrees (hypertee d-a zipped-closing-brackets)
  #/fn hole data
    (dissect data (list a b)
    #/func hole a b)))

; TODO: See if we should add this to Lathe Comforts.
(define/contract (list-fold-map-any state lst on-elem)
  (-> any/c list? (-> any/c any/c #/list/c any/c #/maybe/c any/c)
    (list/c any/c #/maybe/c list?))
  (w-loop next state state lst lst rev-result (list)
    (expect lst (cons elem lst)
      (list state #/just #/reverse rev-result)
    #/dissect (on-elem state elem) (list state maybe-elem)
    #/expect maybe-elem (just elem) (list state #/nothing)
    #/next state lst (cons elem rev-result))))

(define/contract
  (hypertee-dv-fold-map-any-all-degrees state ht on-hole)
  (->
    any/c
    hypertee?
    (-> any/c onum<omega? any/c #/list/c any/c #/maybe/c any/c)
    (list/c any/c #/maybe/c hypertee?))
  (dissect ht (hypertee d closing-brackets)
  #/dissect
    (list-fold-map-any state closing-brackets #/fn state bracket
      (expect bracket (list d data) (list state #/just bracket)
      #/dissect (on-hole state d data) (list state maybe-data)
      #/expect maybe-data (just data) (list state #/nothing)
      #/list state #/just #/list d data))
    (list state #/just closing-brackets)
  #/list state #/just #/hypertee d closing-brackets))

; This zips a degree-N hypertee with a same-degree-or-higher hypertee
; if the hypertees have the same shape when certain holes of the
; higher-degree hypertee are removed -- namely, the holes of degree N
; or greater and the holes that don't match the given predicate.
(define/contract
  (hypertee-zip-selective smaller bigger should-zip? func)
  (->
    hypertee?
    hypertee?
    (-> hypertee? any/c boolean?)
    (-> hypertee? any/c any/c any/c)
    (maybe/c hypertee?))
  (dissect smaller (hypertee d-smaller closing-brackets-smaller)
  #/dissect bigger (hypertee d-bigger closing-brackets-bigger)
  #/expect (onum<=? d-smaller d-bigger) #t
    (error "Expected smaller to be a hypertee of degree no greater than bigger's degree")
  #/w- prepared-bigger
    (hypertee d-bigger
    #/list-kv-map closing-brackets-bigger #/fn i bracket
      (expect bracket (list d data) bracket
      #/list d #/list data i))
  #/w- prepared-bigger
    (hypertee-map-all-degrees prepared-bigger #/fn hole data
      (dissect data (list data i)
      #/list data i
        (and
          (onum<? (hypertee-degree hole) d-smaller)
          (should-zip? hole data))))
  #/w- filtered-bigger
    (hypertee-filter (hypertee-truncate d-smaller prepared-bigger)
    #/fn hole data
      (dissect data (list data i should-zip)
        should-zip))
  #/maybe-map
    (hypertee-zip smaller filtered-bigger #/fn hole smaller bigger
      (dissect bigger (list data i #t)
        (list (func hole smaller data) i)))
  #/dissectfn (hypertee zipped-filtered-d zipped-filtered-brackets)
  #/w- env
    (list-foldl (make-immutable-hasheq) zipped-filtered-brackets
    #/fn env bracket
      (expect bracket (list d data) env
      #/dissect data (list data i)
      #/hash-set env i data))
  #/hypertee-dv-map-all-degrees prepared-bigger #/fn d data
    (dissect data (list data i should-zip)
    #/if should-zip
      (hash-ref env i)
      data)))

; This zips a degree-N hypertee with a same-degree-or-higher hypertee
; if the hypertees have the same shape when truncated to degree N.
(define/contract (hypertee-zip-low-degrees smaller bigger func)
  (-> hypertee? hypertee? (-> hypertee? any/c any/c any/c)
    (maybe/c hypertee?))
  (hypertee-zip-selective smaller bigger (fn hole data #t) func))
