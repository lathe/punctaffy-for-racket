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
(require #/only-in racket/math natural?)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/hash hash-kv-each)
(require #/only-in lathe-comforts/list
  list-bind list-each list-foldl list-map)
(require #/only-in lathe-comforts/maybe
  just maybe/c maybe-map nothing)
(require #/only-in lathe-comforts/struct struct-easy)
(require #/only-in lathe-comforts/trivial trivial)
(require #/only-in lathe-ordinals
  onum<=? onum<? onum-max onum<=omega? onum<omega? onum-plus
  onum-plus1 onum-pred-maybe)
(require #/only-in lathe-ordinals/olist olist-build)

(require #/only-in punctaffy/hypersnippet/hyperstack
  make-poppable-hyperstack make-poppable-hyperstack-n
  poppable-hyperstack-dimension poppable-hyperstack-pop
  poppable-hyperstack-pop-n poppable-hyperstack-promote)

(provide
  (rename-out
    [-hypertee? hypertee?]
    [-hypertee-degree hypertee-degree])
  degree-and-closing-brackets->hypertee
  hypertee-promote
  hypertee-contour
  hypertee-drop1
  hypertee-fold
  hypertee-join-all-degrees
  hypertee-map-all-degrees
  hypertee-map-one-degree
  hypertee-map-highest-degree
  hypertee-pure
  hypertee-bind-all-degrees
  hypertee-bind-one-degree
  hypertee-bind-pred-degree
  hypertee-join-one-degree
  hypertee-each-all-degrees
  hypertee-truncate
  hypertee-zip-selective)

(module+ private/unsafe #/provide
  hypertee
  hypertee-closing-bracket-degree)


; ===== Helpers for this module ======================================

(define-syntax-rule (while condition body ...)
  (w-loop next #/when condition #/#/begin0 next
    body ...))


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
; hyprids in `punctaffy/private/experimental/hyprid`, but we're going
; to take a different approach soon, "hypernests," where string pieces
; like these can be represented as degree-1 nested hypernests. Whereas
; a hypertee is a series of labeled closing brackets of various
; degrees, a hypernest will be a series of labeled closing brackets
; and labeled opening brackets of various degrees. Once we update this
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
  (-> (or/c natural? #/list/c natural? any/c) natural?)
  (mat closing-bracket (list d data)
    d
    closing-bracket))

(define/contract
  (assert-valid-hypertee-brackets opening-degree closing-brackets)
  (-> onum<=omega? list? void?)
  (expect
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
        (when
          (equal? closing-degree
          #/poppable-hyperstack-dimension restored-history)
          ; NOTE: We don't validate `hole-value`.
          (expect closing-bracket (list closing-degree hole-value)
            (error "Expected a closing bracket that began a hole to be annotated with a data value")
          #/void))
        restored-history))
    0
    (error "Expected more closing brackets")
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
  (-> onum<=omega? (listof #/or/c natural? #/list/c natural? any/c)
    hypertee?)
  ; TODO: See if we can improve the error messages so that they're
  ; like part of the contract of this procedure instead of being
  ; thrown from inside the `hypertee` constructor.
  (hypertee degree closing-brackets))

; A version of `hypertee-degree` that does not satisfy
; `struct-accessor-procedure?`.
(define/contract (-hypertee-degree ht)
  (-> hypertee? onum<=omega?)
  (hypertee-degree ht))

(define/contract (hypertee->degree-and-closing-brackets ht)
  (-> hypertee?
    (list/c onum<=omega?
    #/listof #/or/c natural? #/list/c natural? any/c))
  (dissect ht (hypertee d closing-brackets)
  #/list d closing-brackets))

; Takes a hypertee of any degree N and upgrades it to any degree N or
; greater, while leaving its holes the way they are.
(define/contract (hypertee-promote new-degree ht)
  (-> onum<=omega? hypertee? hypertee?)
  (dissect ht (hypertee d closing-brackets)
  #/expect (onum<=? d new-degree) #t
    (error "Expected ht to be a hypertee of degree no greater than new-degree")
  #/hypertee new-degree closing-brackets))

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

; TODO MUTABLE: Stop using `set-box!` here. The boxes we use it on are
; the `result-box` and `rev-brackets-box` we set up each time we make
; a `loc-interpolation`.
;
(define/contract (hypertee-drop1 ht)
  (-> hypertee? #/maybe/c #/list/c any/c hypertee?)
  
  (define (push-box! bx elem)
    (set-box! bx (cons elem #/unbox bx)))
  
  (struct-easy (loc-outside))
  (struct-easy (loc-dropped))
  (struct-easy (loc-interpolation-uninitialized))
  (struct-easy (loc-interpolation result-box d rev-brackets-box))
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
    (list (loc-outside) stack)
  #/dissect
    (list-foldl (list (list) (list (loc-dropped) stack)) rest
    #/fn state closing-bracket
      (dissect state (list dropped-rev-brackets hist)
      #/dissect hist (list loc stack)
      #/w- d-bracket (hypertee-closing-bracket-degree closing-bracket)
      #/w- pop
        (fn loc
          (poppable-hyperstack-pop stack
          #/olist-build d-bracket #/dissectfn _ loc))
      #/dissect (pop loc) (list tentative-new-loc tentative-new-stack)
      #/mat loc (loc-outside)
        (dissect tentative-new-loc
          (loc-interpolation result-box d rev-brackets-box)
        #/begin (push-box! rev-brackets-box closing-bracket)
        #/list dropped-rev-brackets
          (list tentative-new-loc tentative-new-stack))
      #/mat loc (loc-dropped)
        (mat tentative-new-loc (loc-interpolation-uninitialized)
          (w- result-box (box #/nothing)
          #/w- rev-brackets-box (box #/list)
          #/list
            (cons (list closing-bracket result-box)
              dropped-rev-brackets)
            (list
              (loc-interpolation
                result-box closing-bracket rev-brackets-box)
              tentative-new-stack))
        #/dissect tentative-new-loc
          (loc-interpolation result-box d rev-brackets-box)
          (begin (push-box! rev-brackets-box closing-bracket)
          #/list (cons closing-bracket dropped-rev-brackets)
            (list tentative-new-loc tentative-new-stack)))
      #/mat loc (loc-interpolation result-box d rev-brackets-box)
        (mat tentative-new-loc (loc-outside)
          (begin
            (push-box! rev-brackets-box closing-bracket)
            (mat (poppable-hyperstack-dimension tentative-new-stack) 0
              (set-box! result-box
                (just
                #/hypertee d-root #/reverse #/unbox rev-brackets-box))
            #/void)
            (list dropped-rev-brackets
              (list tentative-new-loc tentative-new-stack)))
        #/dissect tentative-new-loc (loc-dropped)
          (w- dropped-rev-brackets
            (cons closing-bracket dropped-rev-brackets)
          #/begin
            (push-box! rev-brackets-box
              (list closing-bracket #/trivial))
            (mat d-bracket 0
              (set-box! result-box
                (just
                #/hypertee d-root #/reverse #/unbox rev-brackets-box))
            #/void)
            (list dropped-rev-brackets
              (list tentative-new-loc tentative-new-stack))))
      #/error "Internal error: Entered an unexpected kind of region in hypertee-drop1"))
    (list dropped-rev-brackets hist)
  #/dissect hist (list (loc-outside) stack)
  #/dissect (poppable-hyperstack-dimension stack) 0
  ; We remove all the mutable boxes from `dropped-rev-brackets` and
  ; make a hypertee out of it.
  #/hypertee d-dropped #/reverse
  #/list-map dropped-rev-brackets #/fn bracket
    (expect bracket (list d data) bracket
    #/dissect (unbox data) (just tail)
    #/list d tail)))

(define/contract (hypertee-fold first-nontrivial-d ht func)
  (-> onum<=omega? hypertee? (-> onum<=omega? any/c hypertee? any/c)
    any/c)
  (mat (hypertee-degree ht) 0
    ; TODO: Make this part of the contract instead.
    (error "Expected ht to be a hypertee of degree greater than 0")
  #/dissect (hypertee-drop1 ht) (just #/list data tails)
  #/func first-nontrivial-d data
  #/hypertee-map-all-degrees tails #/fn hole tail
    (hypertee-fold
      (onum-max first-nontrivial-d #/hypertee-degree hole)
      tail
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
      #/hypertee-plus1 (trivial) tails)
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
  (-> hypertee? hypertee?)
  (mat (hypertee-degree ht) 0 ht
  #/hypertee-fold 0 ht #/fn first-nontrivial-d data tails
    (w- d (hypertee-degree tails)
    #/if (onum<? d first-nontrivial-d)
      (dissect data (trivial)
      #/hypertee-plus1 (trivial) tails)
    #/w- hole
      (hypertee-map-all-degrees tails #/fn hole data #/trivial)
    #/hypertee-plus1 (func hole data) tails)))

; This takes a hypertee of degree N where each hole value of each
; degree M is another degree-N hypertee to be interpolated. In those
; interpolated hypertees, the values of holes of degree less than M
; must be `trivial` values. This returns a single degree-N hypertee
; which has holes for all the degree-M-or-greater holes of the
; interpolations of each degree M.
;
(define/contract (hypertee-join-all-degrees ht)
  (-> hypertee? hypertee?)
  (dissect ht (hypertee overall-degree closing-brackets)
  #/w-loop next
    rev-result (list)
    brackets closing-brackets
    interpolations (make-immutable-hasheq)
    hist
      (list (nothing)
      #/make-poppable-hyperstack
      #/olist-build overall-degree #/dissectfn _ #/nothing)
    root-bracket-i 0
    
    (define (finish brackets interpolations rev-result)
      (expect brackets (list)
        (error "Internal error: Encountered the end of a hypertee join interpolation in a region of degree 0 before getting to the end of the root")
      #/void)
      (hash-kv-each interpolations #/fn i brackets
        (expect brackets (list)
          (error "Internal error: Encountered the end of a hypertee join root before getting to the end of its interpolations")
        #/void))
      (hypertee overall-degree #/reverse rev-result))
    
    (define (pop-root-bracket brackets root-bracket-i)
      (expect brackets (cons bracket brackets)
        (list brackets root-bracket-i #/nothing)
        (list brackets (add1 root-bracket-i) #/just bracket)))
    
    (define (pop-interpolation-bracket interpolations i)
      (expect (hash-ref interpolations i) (cons bracket rest)
        (list interpolations #/nothing)
        (list (hash-set interpolations i rest) #/just bracket)))
    
    (define (verify-bracket-degree d maybe-closing-bracket)
      (dissect maybe-closing-bracket (just closing-bracket)
      #/unless
        (equal? d #/hypertee-closing-bracket-degree closing-bracket)
        (error "Expected each interpolation of a hypertee join to be the right shape for its interpolation context")))
    
    (dissect hist (list maybe-interpolation-i histories)
    #/mat maybe-interpolation-i (just interpolation-i)
      
      ; We read from the interpolation's closing bracket stream.
      (dissect
        (pop-interpolation-bracket interpolations interpolation-i)
        (list interpolations maybe-bracket)
      #/expect maybe-bracket (just closing-bracket)
        (expect (poppable-hyperstack-dimension histories) 0
          (error "Internal error: A hypertee join interpolation ran out of brackets before reaching a region of degree 0")
        ; The interpolation has no more closing brackets, and we're in
        ; a region of degree 0, so we end the loop.
        #/finish brackets interpolations rev-result)
      #/w- d (hypertee-closing-bracket-degree closing-bracket)
      #/expect (onum<? d #/poppable-hyperstack-dimension histories) #t
        (error "Internal error: A hypertee join interpolation had a closing bracket of degree not less than the current region's degree")
      #/dissect
        (poppable-hyperstack-pop histories
        #/olist-build d #/dissectfn _ maybe-interpolation-i)
        (list maybe-interpolation-i histories)
      #/w- hist (list maybe-interpolation-i histories)
      #/mat maybe-interpolation-i (nothing)
        (dissect (pop-root-bracket brackets root-bracket-i)
          (list brackets root-bracket-i maybe-bracket)
        #/begin
          (verify-bracket-degree d maybe-bracket)
          (mat closing-bracket (list d data)
            (expect data (trivial)
              (error "A hypertee join interpolation had a hole of low degree where the value wasn't a trivial value")
            #/void)
          #/void)
        #/next rev-result brackets interpolations hist root-bracket-i)
        (next (cons closing-bracket rev-result) brackets
          interpolations hist root-bracket-i))
    
    ; We read from the root's closing bracket stream.
    #/w- this-root-bracket-i root-bracket-i
    #/dissect (pop-root-bracket brackets root-bracket-i)
      (list brackets root-bracket-i maybe-bracket)
    #/expect maybe-bracket (just closing-bracket)
      (expect (poppable-hyperstack-dimension histories) 0
        (error "Internal error: A hypertee join root ran out of brackets before reaching a region of degree 0")
      ; The root has no more closing brackets, and we're in a region
      ; of degree 0, so we end the loop.
      #/finish brackets interpolations rev-result)
    #/w- d (hypertee-closing-bracket-degree closing-bracket)
    #/expect (onum<? d #/poppable-hyperstack-dimension histories) #t
      (error "Internal error: A hypertee join root had a closing bracket of degree not less than the current region's degree")
    #/dissect
      (poppable-hyperstack-pop histories
      #/olist-build d #/dissectfn _ maybe-interpolation-i)
      (list maybe-interpolation-i histories)
    #/expect closing-bracket (list d data)
      ; We resume an interpolation.
      (expect maybe-interpolation-i (just i)
        (error "Internal error: A hypertee join root had a closing bracket that did not begin a hole but did not resume an interpolation either")
      #/dissect (pop-interpolation-bracket interpolations i)
        (list interpolations maybe-bracket)
      #/begin (verify-bracket-degree d maybe-bracket)
      #/next rev-result brackets interpolations
        (list maybe-interpolation-i histories)
        root-bracket-i)
    ; We begin an interpolation.
    #/expect data (hypertee data-d data-closing-brackets)
      (error "Expected each hypertee join interpolation to be a hypertee")
    #/expect (equal? data-d overall-degree) #t
      (error "Expected each hypertee join interpolation to have the same degree as the root")
    #/next rev-result brackets
      (hash-set interpolations this-root-bracket-i
        data-closing-brackets)
      (list (just this-root-bracket-i)
      
      ; We build a list of histories of length `overall-degree`, since
      ; the hypertee we're interpolating into the root must be of that
      ; degree.
      ;
      ; The lowest-degree holes correspond to the structure of the
      ; hole this interpolation is being spliced into, so they return
      ; us to the root's histories.
      ;
      ; The highest-degree holes are propagated through to the result.
      ; They don't cause us to return to the root.
      ;
      #/poppable-hyperstack-promote histories overall-degree
        (just this-root-bracket-i))
      root-bracket-i)))


; TODO MUTABLE: Stop using `set!` and `set-box!` here. The variable we
; `set!` is `hist`, and the boxes we use `set-box!` on are the `state`
; boxes we set up during the `list-map` at the beginning.
;
(define/contract (hypertee-map-all-degrees ht func)
  (-> hypertee? (-> hypertee? any/c any/c) hypertee?)
  (dissect ht (hypertee overall-degree closing-brackets)
  ; NOTE: This special case is necessary. Most of the code below goes
  ; smoothly for an `overall-degree` equal to `0`, but the loop ends
  ; with a `maybe-current-hole` of `(nothing)`.
  #/mat overall-degree 0 (hypertee 0 #/list)
  #/w- result
    (list-map closing-brackets #/fn closing-bracket
      (mat closing-bracket (list d data)
        (w- rev-brackets (list)
        #/w- hist (make-poppable-hyperstack-n d)
        #/list d #/list data #/box #/list rev-brackets hist)
        closing-bracket))
  #/w- hist
    (list (nothing)
    #/make-poppable-hyperstack
    #/olist-build overall-degree #/dissectfn _ #/nothing)
  #/begin
    (list-each result #/fn closing-bracket
      (dissect hist (list maybe-current-hole histories)
      #/w- d (hypertee-closing-bracket-degree closing-bracket)
      #/expect (onum<? d #/poppable-hyperstack-dimension histories) #t
        (error "Internal error: Encountered a closing bracket of degree higher than the root's current region")
      #/dissect
        (poppable-hyperstack-pop histories
        #/olist-build d #/dissectfn _ maybe-current-hole)
        (list maybe-restored-hole histories)
      #/w- update-hole-state!
        (fn state
          (dissect (unbox state) (list rev-brackets hist)
          #/expect (onum<? d #/poppable-hyperstack-dimension hist) #t
            (error "Internal error: Encountered a closing bracket of degree higher than the hole's current region")
          #/w- hist (poppable-hyperstack-pop-n hist d)
          #/set-box! state
            (list
              (cons
                (if (equal? d #/poppable-hyperstack-dimension hist)
                  (list d #/trivial)
                  d)
                rev-brackets)
              hist)))
      #/mat maybe-current-hole (just state)
        (mat maybe-restored-hole (just state)
          (error "Internal error: Went directly from one hole to another in progress")
        #/mat closing-bracket (list d #/list data state)
          (error "Internal error: Went directly from one hole to another's beginning")
        #/begin
          (set! hist (list (nothing) histories))
          (update-hole-state! state))
      #/mat maybe-restored-hole (just state)
        (mat closing-bracket (list d #/list data state)
          (error "Internal error: Went into two holes at once")
        #/begin
          (set! hist (list (just state) histories))
          (update-hole-state! state))
      #/mat closing-bracket (list d #/list data state)
        ; NOTE: We don't need to `update-hole-state!` here because as
        ; far as this hole's state is concerned, this bracket is the
        ; opening bracket of the hole, not a closing bracket.
        (set! hist (list (just state) histories))
      #/error "Internal error: Went directly from the root to the root without passing through a hole"))
  #/dissect hist (list maybe-current-hole histories)
  #/expect (poppable-hyperstack-dimension histories) 0
    (error "Internal error: Ended hypertee-map-all-degrees without being in a zero-degree region")
  #/expect maybe-current-hole (just state)
    (error "Internal error: Ended hypertee-map-all-degrees without being in a hole")
  #/expect (unbox state) (list (list) state-hist)
    (error "Internal error: Ended hypertee-map-all-degrees without being in the zero-degree hole")
  #/expect (poppable-hyperstack-dimension state-hist) 0
    (error "Internal error: Ended hypertee-map-all-degrees without being in the zero-degree hole")
  #/hypertee overall-degree #/list-map result #/fn closing-bracket
    (expect closing-bracket (list d #/list data state) closing-bracket
    #/dissect (unbox state) (list rev-brackets hist)
    #/expect (poppable-hyperstack-dimension hist) 0
      (error "Internal error: Failed to exhaust the history of a hole while doing hypertee-map-all-degrees")
    #/list d (func (hypertee d #/reverse rev-brackets) data))))

(define/contract (hypertee-map-one-degree ht degree func)
  (-> hypertee? natural? (-> hypertee? any/c any/c) hypertee?)
  (hypertee-map-all-degrees ht #/fn hole data
    (if (equal? degree #/hypertee-degree hole)
      (func hole data)
      data)))

(define/contract (hypertee-map-pred-degree ht degree func)
  (-> hypertee? onum<=omega? (-> hypertee? any/c any/c) hypertee?)
  
  ; If the degree is 0 or a limit ordinal, we have nothing to do,
  ; because no hole's degree has the given degree as its successor, so
  ; there are no holes to process.
  (expect (onum-pred-maybe degree) (just pred-degree) ht
  
  #/hypertee-map-one-degree ht pred-degree func))

(define/contract (hypertee-map-highest-degree ht func)
  (-> hypertee? (-> hypertee? any/c any/c) hypertee?)
  (hypertee-map-pred-degree ht (hypertee-degree ht) func))

(define/contract (hypertee-pure degree data hole)
  (-> onum<=omega? any/c hypertee? hypertee?)
  (hypertee-promote degree #/hypertee-contour data hole))

(define/contract (hypertee-plus1 data tails)
  (-> any/c hypertee? hypertee?)
  (hypertee-join-all-degrees #/hypertee-contour data tails))

(define/contract (hypertee-bind-all-degrees ht hole-to-ht)
  (-> hypertee? (-> hypertee? any/c hypertee?) hypertee?)
  (hypertee-join-all-degrees
  #/hypertee-map-all-degrees ht hole-to-ht))

(define/contract (hypertee-bind-one-degree ht degree func)
  (-> hypertee? natural? (-> hypertee? any/c hypertee?) hypertee?)
  (hypertee-bind-all-degrees ht #/fn hole data
    (if (equal? degree #/hypertee-degree hole)
      (func hole data)
      (hypertee-pure (hypertee-degree ht) data hole))))

(define/contract (hypertee-bind-pred-degree ht degree func)
  (-> hypertee? onum<=omega? (-> hypertee? any/c hypertee?) hypertee?)
  
  ; If the degree is 0 or a limit ordinal, we have nothing to do,
  ; because no hole's degree has the given degree as its successor, so
  ; there are no holes to process.
  (expect (onum-pred-maybe degree) (just pred-degree) ht
  
  #/hypertee-bind-one-degree ht pred-degree func))

(define/contract (hypertee-bind-highest-degree ht func)
  (-> hypertee? (-> hypertee? any/c hypertee?) hypertee?)
  (hypertee-bind-pred-degree ht (hypertee-degree ht) func))

(define/contract (hypertee-join-one-degree ht degree)
  (-> hypertee? natural? hypertee?)
  (hypertee-bind-one-degree ht degree #/fn hole data
    data))

(define/contract (hypertee-each-all-degrees ht body)
  (-> hypertee? (-> hypertee? any/c any) void?)
  ; TODO: See if this can be more efficient.
  (hypertee-map-all-degrees ht #/fn hole data #/begin
    (body hole data)
    (void))
  (void))

; TODO: Judging by the mutable state used in our hypertee algorithms,
; if we ever want to use purer implementations, or even to generalize
; the data to start with trees as the underlying syntax rather than
; lists, we'll want to be able to accumulate information in reverse.
; In fact, it seems like there may be an interesting higher-order
; notion of "reverse" where the shape
;
;   A ~2( B ,( C D ) E ,( F G ) H ) I
;
; degree-0-reverses to
;
;   I ~2( H ,( G F ) E ,( D C ) B ) A
;
; and degree-1-reverses to the client's choice of:
;
;   C ~2( B ,( A I ) H ,( G F ) E ) D
;   D ~2( E ,( F G ) H ,( I A ) B ) C
;   F ~2( E ,( D C ) B ,( A I ) H ) G
;   G ~2( H ,( I A ) B ,( C D ) E ) F
;
; A possible structure-respecting implementation strategy is splitting
; into degree-N stripes, choosing a lake, optionally
; degree-N-minus-1-reversing the parts before and after that lake
; (through some hole of the lake), and degree-N-minus-1-concatenating
; them (using a degree-N-minus-1-reverse-onto operation).
;
; But... sometimes the lake has more than one island beyond it:
;
;   A ~3( ~2( ,( B C ) ,( D E ) ) ) F
;
; When we reverse that, should we get three roots back? Or are only
; lakes that have one neighboring island (i.e. no islands beyond)
; valid targets? Or should we instead target an arbitrary place in an
; *island*, punching a hole so we can treat that hole as the root?
; Perhaps there isn't a really elegant higher-degree reversal
; operation after all.
;
; Besides, even if we accumulated data on one path through a tree,
; we'd have to go back down partway to accumulate more data on another
; branch. At that point, what our traversal accumulates looks just
; like a sequence of brackets anyway. Or we could branch our
; accumulation into multiple deteriministically concurrent uses of
; monotonic states, but then the code will resemble the mutable boxes
; we're using in these algorithms as it is. Maybe it doesn't get a
; whole lot more elegant than what we're doing now.
;
; Wait... Degree-2-reversing into a degree-2 target should be
; well-defined if we also pick one degree-1 sub-target beyond each of
; its holes. That way, the shape of the target corresponds with the
; low-degree shape of the result. Then degree-2-reversing consists
; only of striping, removing the lake we're targeting, destriping each
; part we just disconnected, degree-1-reversing each of them, striping
; them again, and reconnecting them using the same lake shape in the
; middle. (TODO: Rewrite this comment to incorporate this insight
; earlier, and reconsider the implications on our algorithms.)

; This takes a hypertee and removes all holes which don't satisfy the
; given predicate.
(define/contract (hypertee-filter ht should-keep?)
  (-> hypertee? (-> hypertee? any/c boolean?) hypertee?)
  (dissect ht (hypertee d closing-brackets)
  #/hypertee-bind-all-degrees ht #/fn hole data
    (if (should-keep? hole data)
      (hypertee-pure d data hole)
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

; This zips a degree-N hypertee with a same-degree-or-higher hypertee
; if the hypertees have the same shape when certain holes of the
; higher-degree hypertee are removed -- namely, the holes of degree N
; or greater and the holes that don't match the given predicate.
;
; TODO MUTABLE: Stop using `set-box!` here. The boxes we use it on are
; the `boxed-data` boxes we set up during the
; `hypertee-map-all-degrees` at the beginning.
;
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
    (hypertee-map-all-degrees bigger #/fn hole data
      (if
        (and
          (onum<? (hypertee-degree hole) d-smaller)
          (should-zip? hole data))
        (list #t (box data))
        (list #f (box data))))
  #/w- filtered-bigger
    (hypertee-filter (hypertee-truncate d-smaller prepared-bigger)
    #/fn hole data
      (dissect data (list should-zip boxed-data)
        should-zip))
  #/maybe-map
    (hypertee-zip smaller filtered-bigger #/fn hole smaller bigger
      (dissect bigger (list should-zip boxed-data)
        (set-box! boxed-data (func hole smaller #/unbox boxed-data))))
  #/dissectfn _
  #/hypertee-map-all-degrees prepared-bigger #/fn hole data
    (dissect data (list should-zip boxed-data)
      (unbox boxed-data))))

; This zips a degree-N hypertee with a same-degree-or-higher hypertee
; if the hypertees have the same shape when truncated to degree N.
(define/contract (hypertee-zip-low-degrees smaller bigger func)
  (-> hypertee? hypertee? (-> hypertee? any/c any/c any/c)
    (maybe/c hypertee?))
  (hypertee-zip-selective smaller bigger (fn hole data #t) func))
