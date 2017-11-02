#lang parendown racket/base

; trees2.rkt
;
; Data structures for encoding the kind of higher-order structure that
; occurs in higher quasiquotation.

(require #/only-in racket/list make-list)

(require #/only-in lathe dissect dissectfn expect expectfn mat w-)

(require "../../private/util.rkt")

(provide #/all-defined-out)


#|

Here's an example of a degree-4 hypersnippet along with variations where its high-degree holes are removed so that it's easier to see its matching structure at a glance:

  ;
  (                                       )
^2(                      ,( )             )
^3(         ~2( ,(       ,( )     ) )     )
^4( ~3( ~2( ~2( ,( ,( ,( ,( ) ) ) ) ) ) ) )

And here's an example of running an algorithm from left to right across the sequence of brackets to verify that it's properly balanced:

   | 4
       | 3 (4, 4, 4)
           | 4 (3 (4, 4, *), 3 (4, 4, 4))
               | 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))
                  | 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))
                     | 3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))))
                        | 4 (3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))))
                           | 1 (4 (3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))))))
                             | 4 (3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))))
                               | 3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))))
                                 | 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))
                                   | 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))
                                     | 4 (3 (4, 4, *), 3 (4, 4, 4))
                                       | 3 (4, 4, 4)
                                         | 4
                                           | 0

In that example, the notation "|" represents the cursor as it runs through the brackets shown above. The notation "*" represents parts of the state that are unnecessary to keep track of. The notation "4" by itself is shorthand for "4 ()", which shows a 0-element list as shorthand for the lowest-degree parts of a full 4-element list "4 (3 (*, *, *), 2 (*, *), 1 (*, *), 0 ())". Once fully expanded, the numbers are superfluous; they just represent the length of the list that follows, which corresponds with the degree of the current region in the syntax.

The algorithm proceeds by consuming a bracket, restoring the corresponding element of the history (counting from the right to the left in this example), and finally replacing each element of the looked-up state with the previous state if it's a slot of lower degree than the bracket is. (That's why so many parts of the history are "*"; if they're ever used, those parts will necessarily be overwritten anyway.)

If we introduce a shorthand ">" that means "this element is a duplicate of the element to the right," we can represent things more economically:

   | 4
       | 3 (>, >, 4)
           | 4 (>, 3 (>, >, 4))
               | 2 (>, 4 (>, 3 (>, >, 4)))
                  | 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))
                     | 3 (>, 4, 4 (3 (4, 4, *), 2 (>, 4 (>, 3 (>, >, 4)))))
                        | 4 (3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))))
                           | 1 (4 (3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4)))))))
                             | 4 (3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))))
                               | 3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4)))))
                                 | 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))
                                   | 2 (>, 4 (>, 3 (>, >, 4)))
                                     | 4 (>, 3 (>, >, 4))
                                       | 3 (>, >, 4)
                                         | 4
                                           | 0

|#


; TODO: See if we'll use these "striped list" utilities. We introduced
; them here in case we needed to change the layout of "data" pieces in
; the `hypersnippet` struct, but this was probably not the right
; direction.
;
; We likely want to represent data just the way we're doing, by
; associating segments of data content with their preceding closing
; bracket, since associating it with its succeeding closing brackets
; would make it ambiguous where to put it.
;
; That said, we must be aware of some complexity beyond just "carry
; data on the bracket":
;
;   - Data of different conceptual degrees will have different
;     intuitive "preceding closing brackets," so in the `hypersnippet`
;     struct, a single closing bracket entry of degree N may have N
;     separate kinds of data following it.
;
;   - We may want some complexity to track parts of the data that are
;     meant to be associated with each other as part of striped
;     explosions.
;
; Every hypersnippet shape of degree 1 or greater has a "striped
; explosion," made up of shapes of degree 1 less, and here are some
; examples:
;
;
;   ^2( ,( ) )
;   explodes into an island, a lake, and an island:
;     (  )
;        ( )
;          ( )
;
;   ^3( ~2(  ,( ,( ) ) ) )
;   explodes into an island, a lake, and an island:
;   ^2(  ,(            ) )
;       ^2(  ,(      ) )
;           ^2( ,( ) )
;
;   ^3( ~2( ) )
;   explodes into an island and a lake:
;   ^2(  ,( ) )
;       ^2( )
;
;   ( )
;   explodes into an island and a lake:
;   ;
;     ;
;
; Notice that the first example's third "( )" is of degree 1, and it
; corresponds to the complete region of syntax where the "preceding
; closing bracket" is the first ")". If we represent information
; related to this degree-1 region, we'll be associating it with that
; degree-0 closing bracket, which means now our brackets of degree N
; are associated with degree-N+1-or-less information, not just
; degreee-N-or-less information.
;
; For a complete and very concrete example, if we want to represent
; the interpolated string "foo${...}bar" as a hypersnippet of
; structure "^2( ,( ) )", we'll want to associate the degree-1-shaped
; data "foo" and "bar" with the "^2(" bracket and the first ")"
; bracket respectively, and we'll want to manipulate these pieces of
; data together (e.g. omitting both when we're only processing the
; hole in between).

(define (striped-list? x)
  (or (striped-nil? x) (striped-cons? x)))

(struct-easy "a striped-nil" (striped-nil isle) #:equal)
(struct-easy "a striped-cons" (striped-cons isle lake rest) #:equal
  (#:guard-easy
    (unless (striped-list? rest)
      (error "Expected rest to be a striped list"))))

(define (striped-list-foldl state lst combine-cons combine-nil)
  (mat lst (striped-cons isle lake rest)
    (striped-list-foldl (combine-cons state isle lake) rest
      combine-cons combine-nil)
  #/mat lst (striped-nil isle)
    (combine-nil state isle)
  #/error "Expected lst to be a striped list"))

(define (striped-list-isles lst)
  (reverse #/striped-list-foldl (list) lst
    (lambda (state isle lake) #/cons isle state)
    (lambda (state isle) #/cons isle state)))

(define (striped-list-lakes lst)
  (reverse #/striped-list-foldl (list) lst
    (lambda (state isle lake) #/cons lake state)
    (lambda (state isle) state)))


(define (list-overwrite-first-n n val lst)
  (list-kv-map lst #/lambda (i elem)
    (if (< i n) val elem)))

(define (assert-valid-hsnip-brackets opening-degree closing-degrees)
  (unless (exact-nonnegative-integer? opening-degree)
    (error "Expected opening-degree to be an exact nonnegative integer"))
  (unless (list? closing-degrees)
    (error "Expected closing-degrees to be a list"))
  (expect
    (list-foldl
      (build-list opening-degree #/lambda (i)
        ; Whatever sub-histories we put here don't actually matter
        ; because they'll be overwritten whenever this history is
        ; used, so we just make them empty lists.
        (make-list i #/list))
      closing-degrees
    #/lambda (histories closing-degree)
      (expect (exact-nonnegative-integer? closing-degree) #t
        (error "Expected the degree of a closing bracket to be an exact nonnegative integer")
      #/expect (< closing-degree #/length histories) #t
        (error "Encountered a closing bracket of degree higher than the current region's degree")
      #/list-overwrite-first-n closing-degree histories
      #/list-ref histories closing-degree))
    (list)
    (error "Expected more closing brackets")))


(struct-easy "a hypersnippet"
  (hypersnippet degree initial-data closing-brackets)
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    ; NOTE: We don't validate `initial-data`.
    (unless (list? closing-brackets)
      (error "Expected closing-brackets to be a list"))
    (assert-valid-hsnip-brackets degree #/list-fmap closing-brackets
    #/expectfn (list bracket-degree data)
      (error "Expected each element of closing-brackets to be a two-element list")
      ; NOTE: We don't validate `data`.
      bracket-degree)))

; TODO: Put these tests in the punctaffy-test package instead of here.
(assert-valid-hsnip-brackets 0 #/list)
(assert-valid-hsnip-brackets 1 #/list 0)
(assert-valid-hsnip-brackets 2 #/list 1 0 0)
(assert-valid-hsnip-brackets 3 #/list 2 1 1 0 0 0 0)
(assert-valid-hsnip-brackets 4 #/list 3 2 2 1 1 1 1 0 0 0 0 0 0 0 0)
(assert-valid-hsnip-brackets 5
  (list
    4 3 3 2 2 2 2 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0))

; Takes a hypersnippet of any degree N and upgrades it to any degree
; N or greater, while leaving its holes the way they are.
(define (hypersnippet-promote hsnip new-degree)
  (unless (exact-nonnegative-integer? new-degree)
    (error "Expected new-degree to be an exact nonnegative integer"))
  (expect hsnip (hypersnippet d data closing-brackets)
    (error "Expected hsnip to be a hypersnippet")
  #/expect (<= d new-degree) #t
    (error "Expected hsnip to be a hypersnippet of degree no greater than new-degree")
  #/hypersnippet new-degree 'TODO
  #/list-fmap closing-brackets #/dissectfn (list d data)
    (list d 'TODO)))

; Takes a hypersnippet of any degree N and returns a hypersnippet of
; degree N+1 with all the same degree-less-than-N holes as well as a
; single N-degree hole in the shape of the hypersnippet. This should
; be useful as something like a monadic return.
(define (hypersnippet-contour hsnip)
  (expect hsnip (hypersnippet d data closing-brackets)
    (error "Expected hsnip to be a hypersnippet")
  #/hypersnippet (add1 d) 'TODO
  #/cons (list d 'TODO)
  #/list-bind closing-brackets #/dissectfn (list d data)
    (list (list d 'TODO) (list d 'TODO))))

; Takes a hypersnippet of any degree N and returns a hypersnippet of
; degree N+1 where each hole has been replaced with a
; one-degree-greater hole.
(define (hypersnippet-tunnel hsnip)
  (expect hsnip (hypersnippet d data closing-brackets)
    (error "Expected hsnip to be a hypersnippet")
  #/hypersnippet (add1 d) 'TODO
  #/append
    (list-fmap closing-brackets #/dissectfn (list d data)
      (list (add1 d) 'TODO))
    (list-fmap (reverse closing-brackets) #/dissectfn (list d data)
      (list 0 'TODO))
    (list #/list 0 'TODO)))

(struct-easy "a hypersnippet-join-interpolation"
  (hypersnippet-join-interpolation hsnip)
  (#:guard-easy
    (unless (hypersnippet? hsnip)
      (error "Expected hsnip to be a hypersnippet"))))
(struct-easy "a hypersnippet-join-hole" (hypersnippet-join-hole data))

(define (hypersnippet-join hsnip data-to-fill-or-hole)
  (struct-easy "a history-info"
    (history-info maybe-interpolation-i histories))
  (expect hsnip (hypersnippet overall-degree data closing-brackets)
    (error "Expected hsnip to be a hypersnippet")
  #/w-
    rev-result (list)
    brackets closing-brackets
    interpolations (make-hasheq)
    hist
      (history-info (list) #/build-list overall-degree #/lambda (i)
        (history-info (list) #/make-list i
        #/history-info (list) #/list))
    i 0
    (define (pop-bracket!)
      (expect brackets (cons bracket rest)
        (list)
      #/begin
        (set! brackets rest)
        (list bracket)))
    (define (pop-interpolation-bracket! i)
      (expect (hash-ref interpolations i) (cons bracket rest)
        (list)
      #/begin
        (hash-set! interpolations i rest)
        (list bracket)))
    (define (verify-bracket-degree d bracket)
      (dissect bracket (list #/list actual-d data)
      #/unless (= d actual-d)
        (error "Expected each interpolation of a hypersnippet-join to be the right shape for its interpolation context")))
    (while
      (dissect hist (history-info maybe-interpolation-i histories)
      #/mat maybe-interpolation-i (list interpolation-i)
        
        ; We read from the interpolation's closing bracket stream.
        (expect (pop-interpolation-bracket! interpolation-i)
          (list #/list d data)
          (error "Internal error: A hypersnippet-join interpolation ran out of brackets")
        #/expect (< d #/length histories) #t
          (error "Internal error: A hypersnippet-join interpolation had a closing bracket of degree not less than the current region's degree")
        #/dissect (list-ref histories d)
          (history-info maybe-interpolation-i histories)
        #/begin
          (mat maybe-interpolation-i (list)
            (verify-bracket-degree d #/pop-bracket!)
            (set! rev-result (cons (list d 'TODO) rev-result)))
          (set! hist
            (history-info maybe-interpolation-i
            #/list-overwrite-first-n d hist histories))
          #t)
      
      ; We read from the root's closing bracket stream.
      #/expect (pop-bracket!) (list #/list d data)
        (expect histories (list)
          (error "Internal error: A hypersnippet-join root ran out of brackets before reaching a region of degree 0")
          ; The root has no more closing brackets, and we're in a
          ; region of degree 0, so we end the loop.
          #f)
      #/expect (< d #/length histories) #t
        (error "Internal error: A hypersnippet-join root had a closing bracket of degree not less than the current region's degree")
      #/dissect (list-ref histories d)
        (history-info maybe-interpolation-i histories)
      #/w- fill-or-hole
        (if (= d #/sub1 overall-degree)
          (data-to-fill-or-hole data)
          (hypersnippet-join-hole data))
      #/begin
        (mat fill-or-hole
          (hypersnippet-join-interpolation #/hypersnippet
            data-d data-opening-data data-closing-brackets)
          
          ; We begin an interpolation.
          (expect (= data-d overall-degree) #t
            (error "Expected interpolations from data-to-fill-or-hole to be of the same degree as hsnip")
          #/begin
            (hash-set! interpolations i data-closing-brackets)
            (set! hist
              (history-info (list i)
              #/list-overwrite-first-n d hist
              #/append histories #/list #/history-info (list i)
              #/list-overwrite-first-n d hist histories)))
        
        #/mat fill-or-hole (hypersnippet-join-hole data)
          
          ; We begin a hole in the root, which will either pass
          ; through to a hole in the result or return us to an
          ; interpolation already in progress.
          (begin
            (mat maybe-interpolation-i (list i)
              (verify-bracket-degree d #/pop-interpolation-bracket! i)
              (set! rev-result (cons (list d 'TODO) rev-result)))
            (set! hist
              (history-info maybe-interpolation-i
              #/list-overwrite-first-n d hist histories)))
        
        #/error "Expected the result of data-to-fill-or-hole to be a hypersnippet-join-interpolation or a hypersnippet-join-hole")
        (set! i (add1 i))
        #t)
      
      ; This while loop's body is intentionally left blank. Everything
      ; was done in the condition.
      (void))
    (hash-kv-each interpolations #/lambda (i brackets)
      (expect brackets (list)
        (error "Internal error: Encountered the end of a hypersnippet-join root before getting to the end of its interpolations.")))
    (hypersnippet overall-degree 'TODO #/reverse rev-result)))


; TODO: Put these tests in the punctaffy-test package instead of here.

(hypersnippet-join
  (hypersnippet 2 'a #/list
    (list 1
      (hypersnippet-join-interpolation #/hypersnippet 2 'a #/list
        (list 0 'a)))
    (list 0 'a)
    (list 1
      (hypersnippet-join-interpolation #/hypersnippet 2 'a #/list
        (list 0 'a)))
    (list 0 'a)
    (list 0 'a))
  (lambda (fill-or-hole) fill-or-hole))

(hypersnippet-join
  (hypersnippet 2 'a #/list
    (list 1
      (hypersnippet-join-interpolation #/hypersnippet 2 'a #/list
        (list 1 'a)
        (list 0 'a)
        (list 1 'a)
        (list 0 'a)
        (list 0 'a)))
    (list 0 'a)
    (list 1
      (hypersnippet-join-interpolation #/hypersnippet 2 'a #/list
        (list 1 'a)
        (list 0 'a)
        (list 1 'a)
        (list 0 'a)
        (list 0 'a)))
    (list 0 'a)
    (list 0 'a))
  (lambda (fill-or-hole) fill-or-hole))

(hypersnippet-join
  (hypersnippet 2 'a #/list
    (list 1 #/hypersnippet-join-hole 'a)
    (list 0 'a)
    (list 1
      (hypersnippet-join-interpolation #/hypersnippet 2 'a #/list
        (list 1 'a)
        (list 0 'a)
        (list 0 'a)))
    (list 0 'a)
    (list 1
      (hypersnippet-join-interpolation #/hypersnippet 2 'a #/list
        (list 1 'a)
        (list 0 'a)
        (list 0 'a)))
    (list 0 'a)
    (list 0 'a))
  (lambda (fill-or-hole) fill-or-hole))

(hypersnippet-join
  (hypersnippet 3 'a #/list
    
    ; This is propagated to the result.
    (list 1 'a)
    (list 0 'a)
    
    
    (list 2
      (hypersnippet-join-interpolation #/hypersnippet 3 'a #/list
        
        ; This is propagated to the result.
        (list 2 'a)
        (list 0 'a)
        
        ; This is matched up with one of the root's degree-1 sections
        ; and cancelled out.
        (list 1 'a)
        (list 0 'a)
        
        ; This is propagated to the result.
        (list 2 'a)
        (list 0 'a)
        
        (list 0 'a)))
    
    ; This is matched up with the interpolation's corresponding
    ; degree-1 section and cancelled out.
    (list 1 'a)
    (list 0 'a)
    
    (list 0 'a)
    
    
    ; This is propagated to the result.
    (list 1 'a)
    (list 0 'a)
    
    (list 0 'a))
  (lambda (fill-or-hole) fill-or-hole))


(define (hypersnippet-map-all-degrees hsnip func)
  ; TODO: Implement this.
  'TODO)

(define (hypersnippet-map-one-degree hsnip degree func)
  (hypersnippet-map-all-degrees hsnip #/lambda (hole)
    (if (= degree #/hypersnippet-degree hole)
      (func hole)
      hole)))

(define (hypersnippet-map-pred-degree hsnip degree func)
  (expect (nat-pred-maybe degree) (list pred-degree) hsnip
  #/hypersnippet-map-one-degree hsnip pred-degree func))

(define (hypersnippet-map-highest-degree hsnip func)
  (hypersnippet-map-pred-degree
    hsnip (hypersnippet-degree hsnip) func))

; TODO: Implement `hypersnippet-join-all-degrees` by making the
; current implementation of `hypersnippet-join` operate on
; lower-degree holes as well as the highest-degree holes. Lower-degree
; holes would still carry hypersnippets of the same degree as the
; result, but they would have fewer degrees of holes to match up to,
; so some additional high degrees of holes in those holes' values
; would pass through to the result.
(define (hypersnippet-join-all-degrees hsnip)
  'TODO)

(define (hypersnippet-bind-all-degrees hsnip hole-to-hsnip)
  (hypersnippet-join-all-degrees
  #/hypersnippet-map-all-degrees hsnip hole-to-hsnip))

(define (hypersnippet-bind-one-degree hsnip degree func)
  (hypersnippet-bind-all-degrees hsnip #/lambda (hole)
    (if (= degree #/hypersnippet-degree hole)
      (func hole)
      (hypersnippet-promote (hypersnippet-contour hole)
      #/hypersnippet-degree hsnip))))

(define (hypersnippet-bind-pred-degree hsnip degree func)
  (expect (nat-pred-maybe degree) (list pred-degree) hsnip
  #/hypersnippet-bind-one-degree hsnip pred-degree func))

(define (hypersnippet-bind-highest-degree hsnip func)
  (hypersnippet-bind-pred-degree
    hsnip (hypersnippet-degree hsnip) func))

; This takes a nested structure of same-degree island and lake
; stripes, and it returns a single hypersnippet of one higher degree.
(define (hypersnippet-destripe stripes)
  (hypersnippet-bind-highest-degree stripes #/lambda (rest)
  #/w- d (hypersnippet-degree rest)
  #/hypersnippet-bind-pred-degree
    (hypersnippet-contour rest)
    (hypersnippet-degree rest)
    hypersnippet-destripe))

; TODO: Implement this. It should implement the inverse of
; `hypersnippet-destripe`, taking a hypersnippet and returning a
; nested structure of one-lower-degree island and lake stripes.
(define (hypersnippet-stripe hsnip)
  'TODO)
