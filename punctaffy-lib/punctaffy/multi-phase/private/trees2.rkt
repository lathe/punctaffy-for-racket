#lang parendown racket/base

; trees2.rkt
;
; Data structures for encoding the kind of higher-order structure that
; occurs in higher quasiquotation.

(require #/only-in racket/list make-list)

(require #/only-in lathe dissect expect mat w-)

(require "../../private/util.rkt")

(provide #/all-defined-out)


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
; Once divide a hypersnippet shape up this way, we can represent each
; island as a pair of a data value and the hypertee of lakes and
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
; beyond the holes. Hyprids allow this striping to be iterated to any
; number of degrees up to the degree of the hypersnippet shape. Each
; iteration works the same way, but the concept of "hypertee of
; shape S" is replaced with "stripes that collapse to a hypertee of
; shape S."
;
; For circumstances where we're willing to discard the string
; information of our interpolated string, we can use the operation
; `hyprid-destripe-maybe` to get back a simpler hypertee:
;
;   Hypertee of shape "^2( ,( ) ,( ) )"
;    |
;    |-- First hole of shape ",( )": The expression `name`
;    |
;    |-- Second hole of shape ",( )": The expression `weather`
;    |
;    `-- Hole of shape ")": An ignored trivial value
;
; Technically, `hyprid-destripe-maybe` returns a hyprid of one less
; stripe iteration (or will even return nothing if the original hyprid
; had zero stripe iterations). While this collapses one level of
; stripes, the operation `hyprid-fully-destripe` repeatedly collapses
; stripes and always results in a hypertee value.
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
;                                             | 0
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
; functions `hyperteeTruncate` (which should remove the highest-degree
; holes from a hypertee and lower its degree) and
; `hyperteeMapAllDegrees`, which seem to end up depending on quite a
; lot of other constructions.



(define (list-overwrite-first-n n val lst)
  (list-kv-map lst #/lambda (i elem)
    (if (< i n) val elem)))

(define (hypertee-closing-bracket-degree closing-bracket)
  (w- d
    (mat closing-bracket (list d data)
      d
      closing-bracket)
  #/expect (exact-nonnegative-integer? d) #t
    (error "Expected the degree of a hypertee closing bracket to be an exact nonnegative integer")
    d))

(define
  (assert-valid-hypertee-brackets opening-degree closing-brackets)
  (unless (exact-nonnegative-integer? opening-degree)
    (error "Expected opening-degree to be an exact nonnegative integer"))
  (unless (list? closing-brackets)
    (error "Expected closing-brackets to be a list"))
  (expect
    (list-foldl
      (build-list opening-degree #/lambda (i)
        ; Whatever sub-histories we put here don't actually matter
        ; because they'll be overwritten whenever this history is
        ; used, so we just make them empty lists.
        (make-list i #/list))
      closing-brackets
    #/lambda (histories closing-bracket)
      (w- closing-degree
        (hypertee-closing-bracket-degree closing-bracket)
      #/expect (< closing-degree #/length histories) #t
        (error "Encountered a closing bracket of degree higher than the current region's degree")
      #/w- restored-history (list-ref histories closing-degree)
      #/begin
        (when (= closing-degree #/length restored-history)
          ; NOTE: We don't validate `hole-value`.
          (expect closing-bracket (list closing-degree hole-value)
            (error "Expected a closing bracket that began a hole to be annotated with a data value")))
      #/list-overwrite-first-n
        closing-degree histories restored-history))
    (list)
    (error "Expected more closing brackets")))


(struct-easy "a hypertee" (hypertee degree closing-brackets)
  #:equal
  (#:guard-easy
    (assert-valid-hypertee-brackets degree closing-brackets)))

; Takes a hypertee of any degree N and upgrades it to any degree N or
; greater, while leaving its holes the way they are.
(define (hypertee-promote new-degree ht)
  (unless (exact-nonnegative-integer? new-degree)
    (error "Expected new-degree to be an exact nonnegative integer"))
  (expect ht (hypertee d closing-brackets)
    (error "Expected ht to be a hypertee")
  #/expect (<= d new-degree) #t
    (error "Expected ht to be a hypertee of degree no greater than new-degree")
  #/hypertee new-degree closing-brackets))

; Takes a hypertee of any degree N and returns a hypertee of degree
; N+1 with all the same degree-less-than-N holes as well as a single
; degree-N hole in the shape of the original hypertee. This should
; be useful as something like a monadic return.
(define (hypertee-contour hole-value ht)
  (expect ht (hypertee d closing-brackets)
    (error "Expected ht to be a hypertee")
  #/hypertee (add1 d)
  #/cons (list d hole-value)
  #/list-bind closing-brackets #/lambda (closing-bracket)
    (list (hypertee-closing-bracket-degree closing-bracket)
      closing-bracket)))

; Takes a hypertee of any degree N and returns a hypertee of degree
; N+1 where each hole has been replaced with a one-degree-greater
; hole. This creates one new hole of degree 0.
(define (hypertee-tunnel hole-value ht)
  (expect ht (hypertee d closing-brackets)
    (error "Expected ht to be a hypertee")
  #/hypertee (add1 d)
  #/append
    (list-fmap closing-brackets #/lambda (closing-bracket)
      (mat closing-bracket (list d data)
        (list (add1 d) data)
        (add1 closing-bracket)))
    (make-list (length closing-brackets) 0)
    (list #/list 0 hole-value)))

; This takes a hypertee of degree N where each hole value of each
; degree M is another degree-N hypertee to be interpolated. In those
; interpolated hypertees, the values of holes of degree less than M
; must be empty lists. This returns a single degree-N hypertee
; which has holes for all the degree-M-or-greater holes of the
; interpolations of each degree M.
(define (hypertee-join-all-degrees ht)
  (struct-easy "a history-info"
    (history-info maybe-interpolation-i histories))
  (expect ht (hypertee overall-degree closing-brackets)
    (error "Expected ht to be a hypertee")
  #/w-
    rev-result (list)
    brackets closing-brackets
    interpolations (make-hasheq)
    hist
      (history-info (list) #/build-list overall-degree #/lambda (i)
        (history-info (list) #/make-list i
        ; These `history-info` values with empty lists are just dummy
        ; values, since they'll be replaced whenever this part of the
        ; history is used.
        #/history-info (list) #/list))
    root-bracket-i 0
    (define (pop-root-bracket!)
      (expect brackets (cons bracket rest)
        (list)
      #/begin
        (set! brackets rest)
        (set! root-bracket-i (add1 root-bracket-i))
        (list bracket)))
    (define (pop-interpolation-bracket! i)
      (expect (hash-ref interpolations i) (cons bracket rest)
        (list)
      #/begin
        (hash-set! interpolations i rest)
        (list bracket)))
    (define (verify-bracket-degree d maybe-closing-bracket)
      (dissect maybe-closing-bracket (list closing-bracket)
      #/unless (= d #/hypertee-closing-bracket-degree closing-bracket)
        (error "Expected each interpolation of a hypertee join to be the right shape for its interpolation context")))
    (while
      (dissect hist (history-info maybe-interpolation-i histories)
      #/mat maybe-interpolation-i (list interpolation-i)
        
        ; We read from the interpolation's closing bracket stream.
        (expect (pop-interpolation-bracket! interpolation-i)
          (list closing-bracket)
          (expect histories (list)
            (error "Internal error: A hypertee join interpolation ran out of brackets before reaching a region of degree 0")
            ; The interpolation has no more closing brackets, and
            ; we're in a region of degree 0, so we end the loop.
            #f)
        #/w- d (hypertee-closing-bracket-degree closing-bracket)
        #/expect (< d #/length histories) #t
          (error "Internal error: A hypertee join interpolation had a closing bracket of degree not less than the current region's degree")
        #/dissect (list-ref histories d)
          (history-info maybe-interpolation-i histories)
        #/begin0 #t
          (mat maybe-interpolation-i (list)
            (begin
              (verify-bracket-degree d #/pop-root-bracket!)
              (mat closing-bracket (list d data)
                (expect data (list)
                  (error "A hypertee join interpolation had a hole of low degree where the value wasn't an empty list"))))
            (set! rev-result (cons closing-bracket rev-result)))
          (set! hist
            (history-info maybe-interpolation-i
            #/list-overwrite-first-n d hist histories)))
      
      ; We read from the root's closing bracket stream.
      #/w- this-root-bracket-i root-bracket-i
      #/expect (pop-root-bracket!) (list closing-bracket)
        (expect histories (list)
          (error "Internal error: A hypertee join root ran out of brackets before reaching a region of degree 0")
          ; The root has no more closing brackets, and we're in a
          ; region of degree 0, so we end the loop.
          #f)
      #/w- d (hypertee-closing-bracket-degree closing-bracket)
      #/expect (< d #/length histories) #t
        (error "Internal error: A hypertee join root had a closing bracket of degree not less than the current region's degree")
      #/dissect (list-ref histories d)
        (history-info maybe-interpolation-i histories)
      #/begin0 #t
      #/expect closing-bracket (list d data)
        ; We resume an interpolation.
        (expect maybe-interpolation-i (list i)
          (error "Internal error: A hypertee join root had a closing bracket that did not begin a hole but did not resume an interpolation either")
        #/begin
          (verify-bracket-degree d (pop-interpolation-bracket! i))
          (set! hist
            (history-info maybe-interpolation-i
            #/list-overwrite-first-n d hist histories)))
      ; We begin an interpolation.
      #/expect data (hypertee data-d data-closing-brackets)
        (error "Expected each hypertee join interpolation to be a hypertee")
      #/expect (= data-d overall-degree) #t
        (error "Expected each hypertee join interpolation to have the same degree as the root")
      #/w- overwritten-histories
        (list-overwrite-first-n d hist histories)
      #/w- histories-len (length overwritten-histories)
      #/begin
        (hash-set! interpolations this-root-bracket-i
          data-closing-brackets)
        (set! hist
          (history-info (list this-root-bracket-i)
          
          ; We build a list of histories of length `overall-degree`,
          ; since the hypertee we're interpolating into the root must
          ; be of that degree.
          
          ; The lowest-degree holes correspond to the structure of the
          ; hole this interpolation is being spliced into, so they
          ; return us to the root's histories.
          #/append overwritten-histories
          
          ; The highest-degree holes are propagated through to the
          ; result. They don't cause us to return to the root.
          #/build-list (- overall-degree histories-len)
          #/lambda (j)
            (history-info (list this-root-bracket-i)
            #/make-list (+ histories-len j)
            
            ; The values we use here don't matter since they'll be
            ; overwritten whenever this part of the history is
            ; restored.
            #/history-info (list this-root-bracket-i) #/list))))
      
      ; This while loop's body is intentionally left blank. Everything
      ; was done in the condition.
      (void))
    (expect brackets (list)
      (error "Internal error: Encountered the end of a hypertee join interpolation in a region of degree 0 before getting to the end of the root"))
    (hash-kv-each interpolations #/lambda (i brackets)
      (expect brackets (list)
        (error "Internal error: Encountered the end of a hypertee join root before getting to the end of its interpolations")))
    (hypertee overall-degree #/reverse rev-result)))


(define (hypertee-map-all-degrees ht func)
  (struct-easy "a history-info"
    (history-info maybe-current-hole histories))
  (expect ht (hypertee overall-degree closing-brackets)
    (error "Expected ht to be a hypertee")
  #/w- result
    (list-fmap closing-brackets #/lambda (closing-bracket)
      (mat closing-bracket (list d data)
        (w- rev-brackets (list)
        #/w- hist
          (build-list d #/lambda (i)
            (make-list i
            ; These empty lists are just dummy values, since they'll
            ; be replaced whenever this part of the history is used.
            #/list))
        #/list d #/list data #/box #/list rev-brackets hist)
        closing-bracket))
  #/w- hist
    (history-info (list) #/build-list overall-degree #/lambda (i)
      (history-info (list) #/make-list i
      ; These `history-info` values with empty lists are just dummy
      ; values, since they'll be replaced whenever this part of the
      ; history is used.
      #/history-info (list) #/list))
  #/begin
    (list-each result #/lambda (closing-bracket)
      (dissect hist (history-info maybe-current-hole histories)
      #/w- d (hypertee-closing-bracket-degree closing-bracket)
      #/expect (< d #/length histories) #t
        (error "Internal error: Encountered a closing bracket of degree higher than the root's current region")
      #/dissect (list-ref histories d)
        (history-info maybe-restored-hole histories)
      #/w- histories (list-overwrite-first-n d hist histories)
      #/w- update-hole-state!
        (lambda (state)
          (dissect (unbox state) (list rev-brackets hist)
          #/expect (< d #/length hist) #t
            (error "Internal error: Encountered a closing bracket of degree higher than the hole's current region")
          #/w- hist (list-overwrite-first-n d hist #/list-ref hist d)
          #/set-box! state
            (list
              (cons
                (if (= d #/length hist)
                  (list d #/list)
                  d)
                rev-brackets)
              hist)))
      #/mat maybe-current-hole (list state)
        (mat maybe-restored-hole (list state)
          (error "Internal error: Went directly from one hole to another in progress")
        #/mat closing-bracket (list d #/list data state)
          (error "Internal error: Went directly from one hole to another's beginning")
        #/begin
          (set! hist (history-info (list) histories))
          (update-hole-state! state))
      #/mat maybe-restored-hole (list state)
        (mat closing-bracket (list d #/list data state)
          (error "Internal error: Went into two holes at once")
        #/begin
          (set! hist (history-info (list state) histories))
          (update-hole-state! state))
      #/mat closing-bracket (list d #/list data state)
        ; NOTE: We don't need to `update-hole-state!` here because as
        ; far as this hole's state is concerned, this bracket is the
        ; opening bracket of the hole, not a closing bracket.
        (set! hist (history-info (list state) histories))
      #/error "Internal error: Went directly from the root to the root without passing through a hole"))
  #/dissect hist (history-info maybe-current-hole histories)
  #/expect histories (list)
    (error "Internal error: Ended hypertee-map-all-degrees without being in a zero-degree region")
  #/expect maybe-current-hole (list state)
    (error "Internal error: Ended hypertee-map-all-degrees without being in a hole")
  #/expect (unbox state) (list (list) (list))
    (error "Internal error: Ended hypertee-map-all-degrees without being in the zero-degree hole")
  #/hypertee overall-degree
  #/list-fmap result #/lambda (closing-bracket)
    (expect closing-bracket (list d #/list data state) closing-bracket
    #/dissect (unbox state) (list rev-brackets hist)
    #/expect hist (list)
      (error "Internal error: Failed to exhaust the history of a hole while doing hypertee-map-all-degrees")
    #/list d (func (hypertee d #/reverse rev-brackets) data))))

(define (hypertee-map-one-degree ht degree func)
  (hypertee-map-all-degrees ht #/lambda (hole data)
    (if (= degree #/hypertee-degree hole)
      (func hole)
      hole)))

(define (hypertee-map-pred-degree ht degree func)
  (expect (nat-pred-maybe degree) (list pred-degree) ht
  #/hypertee-map-one-degree ht pred-degree func))

(define (hypertee-map-highest-degree ht func)
  (hypertee-map-pred-degree ht (hypertee-degree ht) func))

(define (hypertee-pure degree data hole)
  (hypertee-promote degree #/hypertee-contour data hole))

(define (hypertee-bind-all-degrees ht hole-to-ht)
  (hypertee-join-all-degrees
  #/hypertee-map-all-degrees ht hole-to-ht))

(define (hypertee-bind-one-degree ht degree func)
  (hypertee-bind-all-degrees ht #/lambda (hole data)
    (if (= degree #/hypertee-degree hole)
      (func hole data)
      (hypertee-pure (hypertee-degree ht) data hole))))

(define (hypertee-bind-pred-degree ht degree func)
  (expect (nat-pred-maybe degree) (list pred-degree) ht
  #/hypertee-bind-one-degree ht pred-degree func))

(define (hypertee-bind-highest-degree ht func)
  (hypertee-bind-pred-degree ht (hypertee-degree ht) func))

(define (hypertee-each-all-degrees ht body)
  ; TODO: See if this can be more efficient.
  (hypertee-map-all-degrees ht body)
  (void))

; A hyprid is a hypertee that *also* contains hypersnippet data.
;
; TODO: Come up with a better name than "hyprid."
;
(struct-easy "a hyprid"
  (hyprid striped-degrees unstriped-degrees striped-hypertee)
  #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? striped-degrees)
      (error "Expected striped-degrees to be an exact nonnegative integer"))
    (unless (exact-nonnegative-integer? unstriped-degrees)
      (error "Expected unstriped-degrees to be an exact nonnegative integer"))
    (expect (nat-pred-maybe striped-degrees)
      (list pred-striped-degrees)
      (expect striped-hypertee (hypertee degree closing-brackets)
        (error "Expected striped-hypertee to be a hypertee since striped-degrees was zero")
      #/unless (= unstriped-degrees degree)
        (error "Expected striped-hypertee to be a hypertee of degree unstriped-degrees"))
      (expect striped-hypertee
        (island-cane data
        #/hyprid striped-degrees-2 unstriped-degrees-2 striped-hypertee-2)
        (error "Expected striped-hypertee to be an island-cane since striped-degrees was nonzero")
      #/expect (= pred-striped-degrees striped-degrees-2) #t
        (error "Expected striped-hypertee to be an island-cane of striped-degrees one less")
      #/unless (= unstriped-degrees unstriped-degrees-2)
        (error "Expected striped-hypertee to be an island-cane of the same unstriped-degrees")))))

(define (hyprid-degree h)
  (expect h
    (hyprid striped-degrees unstriped-degrees striped-hypertee)
    (error "Expected h to be a hyprid")
  #/+ striped-degrees unstriped-degrees))

(struct-easy "an island-cane" (island-cane data rest)
  #:equal
  (#:guard-easy
    (unless (hyprid? rest)
      (error "Expected rest to be a hyprid"))
    (w- d (hyprid-degree rest)
    #/hyprid-each-lake-all-degrees rest #/lambda (hole-hypertee data)
      (when (= d #/add1 #/hypertee-degree hole-hypertee)
        (mat data (lake-cane data rest)
          (unless (= d #/hypertee-degree rest)
            (error "Expected data to be of the same degree as the island-cane if it was a lake-cane"))
        #/mat data (non-lake-cane data)
          (void)
        #/error "Expected data to be a lake-cane or a non-lake-cane")))))

(struct-easy "a lake-cane" (lake-cane data rest)
  #:equal
  (#:guard-easy
    (unless (hypertee? rest)
      (error "Expected rest to be a hypertee"))
    (w- d (hypertee-degree rest)
    #/hypertee-each-all-degrees rest #/lambda (hole data)
      (if (= d #/add1 #/hypertee-degree hole)
        ; TODO: In this case, also verify that the island's
        ; non-highest-degree holes contain empty lists. The *root*
        ; island of a hyprid can contain data in its low-degree holes,
        ; but the other islands' low-degree holes just represent
        ; passing the baton back to the previous lake. (Note that any
        ; island can have a nontrivial `non-lake-cane` in a highest
        ; degree hole. It's only the degrees below that that should be
        ; restricted.)
        (expect data (island-cane data rest)
          (error "Expected data to be an island-cane")
        #/unless (= d #/hyprid-degree rest)
          (error "Expected data to be an island-cane of the same degree"))
        (expect data (list)
          (error "Expected data to be an empty list"))))))

(struct-easy "a non-lake-cane" (non-lake-cane data) #:equal)

(define (hyprid-map-lakes-highest-degree h func)
  (expect h
    (hyprid striped-degrees unstriped-degrees striped-hypertee)
    (error "Expected h to be a hyprid")
  #/hyprid striped-degrees unstriped-degrees
  #/expect (nat-pred-maybe striped-degrees)
    (list pred-striped-degrees)
    (hypertee-map-highest-degree striped-hypertee func)
  #/dissect striped-hypertee (island-cane data rest)
  #/island-cane data
  #/hyprid-map-lakes-highest-degree rest #/lambda (hole-hypertee rest)
    (mat rest (lake-cane data rest)
      (lake-cane
        (func
          (hypertee-map-highest-degree rest #/lambda (hole rest)
            (list))
          data)
      #/hypertee-map-highest-degree rest #/lambda (hole rest)
        (dissect
          (hyprid-map-lakes-highest-degree
          #/hyprid striped-degrees unstriped-degrees rest)
          (hyprid striped-degrees-2 unstriped-degrees-2 rest)
          rest))
    #/mat rest (non-lake-cane data) (non-lake-cane data)
    #/error "Internal error")))

(define (hyprid-destripe-maybe h)
  (expect h
    (hyprid striped-degrees unstriped-degrees striped-hypertee)
    (error "Expected h to be a hyprid")
  #/expect (nat-pred-maybe striped-degrees)
    (list pred-striped-degrees)
    (list)
  #/w- succ-unstriped-degrees (add1 unstriped-degrees)
  #/list #/hyprid pred-striped-degrees succ-unstriped-degrees
  #/dissect striped-hypertee
    (island-cane data
    #/hyprid pred-striped-degrees-2 unstriped-degrees-2 rest)
  #/expect (nat-pred-maybe pred-striped-degrees)
    (list pred-pred-striped-degrees)
    (hypertee-bind-pred-degree
      (hypertee-promote succ-unstriped-degrees rest)
      unstriped-degrees
    #/lambda (hole rest)
      (mat rest (lake-cane data rest)
        (hypertee-bind-pred-degree (hypertee-contour data rest)
          unstriped-degrees
        #/lambda (hole rest)
          (dissect
            (hyprid-destripe-maybe
            #/hyprid striped-degrees unstriped-degrees rest)
            (list
            #/hyprid pred-striped-degrees succ-unstriped-degrees
              destriped-rest)
            destriped-rest))
      #/mat rest (non-lake-cane data)
        (hypertee-pure succ-unstriped-degrees data hole)
      #/error "Internal error"))
  #/island-cane data
  #/dissect (hyprid-destripe-maybe rest) (list destriped-rest)
  #/hyprid-map-lakes-highest-degree destriped-rest
  #/lambda (hole-hypertee rest)
    (mat rest (lake-cane data rest)
      (lake-cane data
      #/hypertee-map-highest-degree rest #/lambda (hole rest)
        (dissect
          (hyprid-destripe-maybe
          #/hyprid striped-degrees unstriped-degrees rest)
          (list
          #/hyprid pred-striped-degrees succ-unstriped-degrees
            destriped-rest)
          destriped-rest))
    #/mat rest (non-lake-cane data) (non-lake-cane data)
    #/error "Internal error")))

(define (hyprid-fully-destripe h)
  (expect h
    (hyprid striped-degrees unstriped-degrees striped-hypertee)
    (error "Expected h to be a hyprid")
  #/mat (hyprid-destripe-maybe h) (list destriped-once)
    (hyprid-fully-destripe destriped-once)
    striped-hypertee))

(define (hyprid-each-lake-all-degrees h body)
  (hypertee-each-all-degrees (hyprid-fully-destripe h) body))

; This is the inverse of `hyprid-destripe-maybe`, taking a hyprid and
; returning a hyprid with one more striped degree and one fewer
; unstriped degree. The new stripe's data values are empty lists, as
; implemented at the comment labeled "EMPTY LIST NOTE".
;
; TODO: Test this.
;
(define (hyprid-stripe-maybe h)
  (define (location-needs-state? location)
    (not #/memq location #/list 'non-lake 'lake))
  (define (location-is-island? location)
    (not #/not #/memq location #/list 'root-island 'inner-island))
  (struct-easy "a history-info"
    (history-info location maybe-state histories)
    (#:guard-easy
      (unless
        (memq location
        #/list 'root-island 'non-lake 'lake 'inner-island 'hole)
        (error "Internal error"))
      (if (location-needs-state? location)
        (expect maybe-state (list state)
          (error "Internal error"))
        (expect maybe-state (list)
          (error "Internal error")))))
  (struct-easy "an unfinished-lake-cane"
    (unfinished-lake-cane data rest-state))
  (struct-easy "a stripe-state" (stripe-state rev-brackets hist))
  (define (update-simple-history closing-degree hist)
    (expect (< closing-degree #/length hist) #t
      (error "Internal error")
    #/list-overwrite-first-n closing-degree hist
    #/list-ref hist closing-degree))
  
  (expect h
    (hyprid striped-degrees unstriped-degrees striped-hypertee)
    (error "Expected h to be a hyprid")
  #/expect (nat-pred-maybe unstriped-degrees)
    (list pred-unstriped-degrees)
    (list)
  #/w- succ-striped-degrees (add1 striped-degrees)
  #/list #/hyprid succ-striped-degrees pred-unstriped-degrees
  #/expect striped-degrees 0
    (dissect (hyprid-stripe-maybe striped-hypertee)
      (list striped-striped-hypertee)
    #/hyprid-map-lakes-highest-degree striped-striped-hypertee
    #/lambda (hole-hypertee rest)
      (mat rest (lake-cane data rest)
        (lake-cane data
        #/hypertee-map-highest-degree rest #/lambda (hole rest)
          (dissect
            (hyprid-stripe-maybe
            #/hyprid striped-degrees unstriped-degrees rest)
            (list
            #/hyprid succ-striped-degrees pred-unstriped-degrees
              striped-rest)
            striped-rest))
      #/mat rest (non-lake-cane data) (non-lake-cane data)
      #/error "Internal error"))
  #/dissect striped-hypertee (hypertee d closing-brackets)
  #/expect (= d unstriped-degrees) #t
    (error "Internal error")
  ; We begin a mutable state to place the root island's brackets in
  ; and a mutable state for the overall history.
  #/w- stripe-starting-state
    (w- rev-brackets (list)
    #/stripe-state rev-brackets
    #/build-list pred-unstriped-degrees #/lambda (i)
      ; These empty lists are just dummy values, since they'll be
      ; replaced whenever this part of the history is used.
      (make-list i #/list))
  #/w- root-island-state (box stripe-starting-state)
  #/w- hist
    (history-info 'root-island (list root-island-state)
    #/build-list d #/lambda (i)
      (history-info 'hole (list) #/make-list i
      ; These `history-info` values with empty lists are just dummy
      ; values, since they'll be replaced whenever this part of the
      ; history is used.
      #/history-info 'hole (list) #/list))
  #/begin
    (list-each closing-brackets #/lambda (closing-bracket)
      
      ; As we encounter lakes, we build mutable states to keep their
      ; histories in, and so on for every island and lake at every
      ; depth.
      
      (dissect hist
        (history-info
          location-before maybe-state-before histories-before)
      #/w- d (hypertee-closing-bracket-degree closing-bracket)
      #/expect (< d #/length histories-before) #t
        (error "Internal error")
      #/dissect (list-ref histories-before d)
        (history-info
          location-after maybe-state-after histories-after)
      #/w- histories-after
        (list-overwrite-first-n d hist histories-after)
      #/if (= pred-unstriped-degrees d)
        
        ; If we've encountered a closing bracket of the highest degree
        ; the original hypertee can support, we're definitely starting
        ; a lake.
        (expect (location-is-island? location-before) #t
          (error "Internal error")
        #/expect (eq? 'hole location-after) #t
          (error "Internal error")
        #/expect closing-bracket (list d data)
          (error "Internal error")
        #/w- rest-state (box stripe-starting-state)
        #/begin
          (set! hist
            (history-info 'lake (list rest-state) histories-after))
        #/dissect maybe-state-before (list state)
        #/dissect (unbox state) (stripe-state rev-brackets hist)
        #/set-box! state
          (stripe-state
            (cons (list d #/unfinished-lake-cane data rest-state)
              rev-brackets)
            (update-simple-history d hist)))
      
      #/if (= pred-unstriped-degrees #/add1 d)
        
        ; If we've encountered a closing bracket of the highest degree
        ; that a stripe in the result can support, we may be starting
        ; an island or a non-lake.
        (mat closing-bracket (list d data)
          
          ; This bracket is closing the original hypertee, so it must
          ; be closing an island, so we're starting a non-lake.
          (expect (location-is-island? location-before) #t
            (error "Internal error")
          #/expect (eq? 'hole location-before) #t
            (error "Internal error")
          #/begin
            (set! hist
              (history-info 'non-lake (list) histories-after))
          #/dissect maybe-state-before (list state)
          #/dissect (unbox state) (stripe-state rev-brackets hist)
          #/set-box! state
            (stripe-state
              (cons (list d #/non-lake-cane data) rev-brackets)
              (update-simple-history d hist)))
          
          ; This bracket is closing an even higher-degree bracket,
          ; which must have started a lake, so we're starting an
          ; island.
          (expect (eq? 'lake location-before) #t
            (error "Internal error")
          #/expect (eq? 'root-island location-after) #t
            (error "Internal error")
          #/w- new-state (box stripe-starting-state)
          #/begin
            (set! hist
              (history-info
                'inner-island (list new-state) histories-after))
          #/dissect maybe-state-after (list state)
          #/dissect (unbox state) (stripe-state rev-brackets hist)
          #/set-box! state
            (stripe-state
              (cons closing-bracket rev-brackets)
              (update-simple-history d hist))))
      
      ; If we've encountered a closing bracket of low degree, we pass
      ; it through to whatever island or lake we're departing from
      ; (including any associated data in the bracket) and whatever
      ; island or lake we're arriving at (excluding the data, since
      ; this bracket must be closing some hole which was started there
      ; earlier). In some circumstances, we need to associate an empty
      ; list with the bracket we record to the departure island or
      ; lake, even if this bracket is not a hole-opener as far as the
      ; original hypertee is concerned.
      #/begin
        (set! hist
          (history-info
            location-after maybe-state-after histories-after))
        (expect maybe-state-before (list state) (void)
        #/dissect (unbox state) (stripe-state rev-brackets hist)
        #/w- hist (update-simple-history d hist)
        #/set-box! state
          (stripe-state
            (cons
              (mat closing-bracket (list d data) closing-bracket
              #/if (= d #/length hist)
                (list d #/list)
                d)
              rev-brackets)
            hist))
        (expect maybe-state-after (list state) (void)
        #/dissect (unbox state) (stripe-state rev-brackets hist)
        #/set-box! state
          (stripe-state
            (cons d rev-brackets)
            (update-simple-history d hist)))))
  ; In the end, we build the root island by accessing its state to get
  ; the brackets, arranging the brackets in the correct order, and
  ; recursively assembling lakes and islands using their states the
  ; same way.
  #/let assemble-island-from-state ([state root-island-state])
    (dissect (unbox state) (stripe-state rev-brackets #/list)
    
    ; EMPTY LIST NOTE: This is where we put an empty list into the new
    ; layer of stripe data.
    #/island-cane (list)
    
    #/hypertee pred-unstriped-degrees
    #/list-fmap (reverse rev-brackets) #/lambda (closing-bracket)
      (expect closing-bracket (list d data) closing-bracket
      #/expect (= d pred-unstriped-degrees) #t closing-bracket
      #/mat data (non-lake-cane data) closing-bracket
      #/mat data (unfinished-lake-cane data rest-state)
        (dissect (unbox rest-state)
          (stripe-state rev-brackets #/list)
        #/list d #/lake-cane data #/hypertee pred-unstriped-degrees
        #/list-fmap rev-brackets #/lambda (closing-bracket)
          (expect closing-bracket (list d data) closing-bracket
          #/expect (= d pred-unstriped-degrees) #t closing-bracket
          #/list d #/assemble-island-from-state data))
      #/error "Internal error"))))

; TODO: Judging by the mutable state used in the above algorithms, if
; we ever want to use purer implementations, or even to generalize the
; data to start with trees as the underlying syntax rather than lists,
; we'll want to be able to accumulate information in reverse. In fact,
; it seems like there may be an interesting higher-order notion of
; "reverse" where the shape
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
; When we reverse that, should we get three roots back?  Or are only
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

; TODO: Implement the ability to zip a degree-N hypertee with a
; higher-degree hypertee if the hypertees have the same shape when
; truncated to degree N.

; TODO: Implement a truncation operation, which takes a hypertee and
; removes all holes of degree equal to or greater than a given degree
; and demotes the hypertee to that degree.
