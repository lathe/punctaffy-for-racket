#lang parendown racket/base

; hypermonad.rkt
;
; A generic interface for "hypermonad" type class dictionaries, which
; manipulate hypersnippet-shaped data.

(require #/only-in racket/generic define-generics)

(require #/only-in lathe expect mat next nextlet w-)

(require "../../private/util.rkt")

(provide gen:hypermonad hypermonad? hypermonad/c
  
  hypermonad-hole-hypermonad-for-degree
  
  hypermonad-pure
  hypermonad-bind-with-degree-and-shape
  hypermonad-map-with-degree-and-shape
  hypermonad-join
  
  hypermonad-bind-with-degree
  hypermonad-map-with-degree
)

(provide #/rename-out [make-hypermonad-zero hypermonad-zero])


(define-generics hypermonad
  
  ; This returns a hypermonad where high-degree holes are prohibited.
  ; The valid hypersnippets may be disjoint from this hypermonad's
  ; valid hypersnippets as well.
  (hypermonad-hole-hypermonad-for-degree hypermonad degree)
  
  ; We redundantly cover several monad operations so that they can be
  ; implemented efficiently.
  (hypermonad-pure hypermonad hole-degree hole-shape leaf)
  (hypermonad-bind-with-degree-and-shape
    hypermonad prefix degree-shape-and-leaf-to-suffix)
  (hypermonad-map-with-degree-and-shape
    hypermonad hypersnippet degree-shape-and-leaf-to-leaf)
  (hypermonad-join hypermonad hypersnippets)
  
  ; We provide separate operations for potentially more efficient
  ; variations.
  (hypermonad-bind-with-degree
    hypermonad prefix degree-and-leaf-to-suffix)
  (hypermonad-map-with-degree
    hypermonad hypersnippet degree-and-leaf-to-leaf)
)


; This is a degree-0 hypermonad.
(struct-easy "a hypermonad-zero" (hypermonad-zero)
  #:equal
  #:other
  
  #:constructor-name make-hypermonad-zero
  
  #:methods gen:hypermonad
  [
    
    (define (hypermonad-hole-hypermonad-for-degree this degree)
      (expect this (hypermonad-zero)
        (error "Expected this to be a hypermonad-zero")
      #/expect (exact-nonnegative-integer? degree) #t
        (error "Expected degree to be an exact nonnegative integer")
        (error "Called hypermonad-hole-hypermonad-for-degree on a hypermonad-zero")))
    
    (define (hypermonad-pure this hole-degree hole-shape leaf)
      (expect this (hypermonad-zero)
        (error "Expected this to be a hypermonad-zero")
      #/expect (exact-nonnegative-integer? hole-degree) #t
        (error "Expected hole-degree to be an exact nonnegative integer")
        (error "Called hypermonad-pure on a hypermonad-zero")))
    (define
      (hypermonad-bind-with-degree-and-shape
        this prefix degree-shape-and-leaf-to-suffix)
      (expect this (hypermonad-zero)
        (error "Expected this to be a hypermonad-zero")
      #/expect prefix (list)
        (error "Expected prefix to be an empty list")
      #/list))
    (define
      (hypermonad-map-with-degree-and-shape
        this hypersnippet degree-shape-and-leaf-to-leaf)
      (expect this (hypermonad-zero)
        (error "Expected this to be a hypermonad-zero")
      #/expect hypersnippet (list)
        (error "Expected hypersnippet to be an empty list")
      #/list))
    (define (hypermonad-join this hypersnippets)
      (expect this (hypermonad-zero)
        (error "Expected this to be a hypermonad-zero")
      #/expect hypersnippets (list)
        (error "Expected hypersnippets to be an empty list")
      #/list))
    
    (define
      (hypermonad-bind-with-degree
        this prefix degree-and-leaf-to-suffix)
      (hypermonad-bind-with-degree-and-shape this prefix
      #/lambda (hole-degree hole-shape leaf)
        (degree-and-leaf-to-suffix hole-degree leaf)))
    (define
      (hypermonad-map-with-degree
        this hypersnippet degree-and-leaf-to-leaf)
      (hypermonad-map-with-degree-and-shape this hypersnippet
      #/lambda (hole-degree hole-shape leaf)
        (degree-and-leaf-to-leaf hole-degree leaf)))
  ])


(struct-easy "a striped-hypersnippet"
  (striped-hypersnippet island-and-lakes-and-rest)
  #:equal)
(struct-easy "a striped-hypersnippet-lake"
  (striped-hypersnippet-lake leaf lake-and-rest)
  #:equal)
(struct-easy "a striped-hypersnippet-non-lake"
  (striped-hypersnippet-non-lake rest)
  #:equal)

; This is a striped hypermonad alternating between two striped
; hypermonads.
#|
double-stripe-snippet ii il li ll =
  stripe-snippet
    (stripe-snippet (snippet-of ii) (snippet-of il))
    (stripe-snippet (snippet-of li) (snippet-of ll))

hll-to-hil :: forall holeVals.
  (snippet-of ll) holeVals ->
  (snippet-of il) holeVals
hl-to-hil :: forall holeVals.
  (snippet-of (ignore-highest l)) holeVals ->
  (snippet-of il) holeVals
hil-to-hiil :: forall holeVals.
  (snippet-of (ignore-highest il)) holeVals ->
  (snippet-of (hole-hypermonad-for-pred-degree ii)) holeVals
to-hll :: forall holeVals.
  (double-stripe-snippet ii il li ll) holeVals ->
  (snippet-of ll) holeVals
fill-pred-hole :: forall holeVals.
  (double-stripe-snippet ii il li ll) (trivial-hole-vals) ->
  ; TODO: See how we should document this type. It should probably be
  ; `(stripe-snippet (snippet-of li) (snippet-of-ll)) holeVals`, but
  ; with values of type (double-stripe-snippet ii il li ll) in the
  ; highest-degree holes. Where do those values go in the result?
  (stripe-snippet (snippet-of li) (double-stripe-snippet ii il li ll)
    ) holeVals ->
  Maybe ((double-stripe-snippet ii il li ll) holeVals)
fill-pred-pred-hole :: forall holeVals.
  (double-stripe-snippet ii il li ll) (trivial-hole-vals) ->
  (snippet-of il) holeVals ->
  Maybe ((double-stripe-snippet ii il li ll) holeVals)
|#
(struct-easy "a hypermonad-striped-striped"
  (hypermonad-striped-striped
    overall-degree hii hil hli hll hl
    hll-to-hil hl-to-hil hil-to-hiil to-hll
    fill-pred-hole fill-pred-pred-hole)
  #:equal
  (#:guard-easy
    (unless (exact-nonnegative-integer? overall-degree)
      (error "Expected overall-degree to be an exact nonnegative integer"))
    (unless (<= 3 overall-degree)
      (error "Expected overall-degree to be 3 or greater")))
  #:other
  
  #:constructor-name make-hypermonad-striped-striped
  
  #:methods gen:hypermonad
  [
    
    (define (hypermonad-hole-hypermonad-for-degree this degree)
      (expect this
        (hypermonad-striped-striped
          overall-degree hii hil hli hll hl
          hll-to-hil hl-to-hil hil-to-hiil to-hll
          fill-pred-hole fill-pred-pred-hole)
        (error "Expected this to be a hypermonad-striped-striped")
      #/expect (exact-nonnegative-integer? degree) #t
        (error "Expected degree to be an exact nonnegative integer")
      #/expect (< degree overall-degree) #t
        (error "Expected degree to be an exact nonnegative integer less than overall-degree")
      #/if (= overall-degree #/add1 degree)
        hl
      #/if (= overall-degree #/add1 #/add1 degree)
        hil
      #/hypermonad-hole-hypermonad-for-degree hii degree))
    
    (define (hypermonad-pure this hole-degree hole-shape leaf)
      (expect this
        (hypermonad-striped-striped
          overall-degree hii hil hli hll hl
          hll-to-hil hl-to-hil hil-to-hiil to-hll
          fill-pred-hole fill-pred-pred-hole)
        (error "Expected this to be a hypermonad-striped-striped")
      #/expect (exact-nonnegative-integer? hole-degree) #t
        (error "Expected hole-degree to be an exact nonnegative integer")
      #/expect (< hole-degree overall-degree) #t
        (error "Expected hole-degree to be an exact nonnegative integer less than overall-degree")
      
      #/if (= overall-degree #/add1 hole-degree)
        
        ; We transform something of the form:
        ;
        ;         ^N+1(  ~N(  )  )
        ;              li   ll li
        ;   Striped:  [          ]
        ;
        ; into something of the form:
        ;
        ;         ^N+2(  ~N+1(  ~N(  ~N(  )  )   )    )
        ;              ii     li   ii   il ii  li   ii
        ;   Striped:              [  --il--  ]
        ;   Striped:         [    -----ll-----   ]
        ;   Striped:  [      ----------il---------    ]
        ;   (Those 3 layers of striping are striped.)
        ;
        (striped-hypersnippet
        #/striped-hypersnippet
        #/hypermonad-pure hii (sub1 #/sub1 hole-degree)
          (hil-to-hiil #/hl-to-hil hole-shape)
        #/striped-hypersnippet-lake
          (striped-hypersnippet-lake leaf
          #/hypermonad-map-with-degree-and-shape hl hole-shape
          #/lambda (hole-hole-degree hole-hole-shape hole-leaf)
            (expect (< hole-hole-degree hole-degree) #t
              (error "Expected hole-shape to be a valid hypersnippet for a particular hypermonad")
            #/expect hole-leaf (list)
              (error "Expected each leaf of hole-shape to be an empty list")
            #/expect (= hole-hole-degree #/sub1 hole-degree) #t
              null
            ; TODO: Provide `hll-to-hil`.
            #/w- islandlake (hll-to-hil hole-hole-shape)
            #/hypermonad-pure hii (sub1 #/sub1 hole-degree)
              (hil-to-hiil islandlake)
            #/striped-hypersnippet-lake
              (striped-hypersnippet-non-lake null)
            #/hypermonad-map-with-degree-and-shape hil islandlake
            #/lambda
              (
                islandlake-hole-degree islandlake-hole-shape
                islandlake-leaf)
              (w- islandlake-degree hole-hole-degree
              #/expect (< islandlake-hole-degree islandlake-degree) #t
                (error "Expected hole-shape and the results of hl-to-hil, hil-to-hiil, and hll-to-hil to be valid hypersnippets for particular hypermonads")
              #/expect islandlake-leaf (list)
                (error "Expected each leaf of each of hole-shape's highest-degree holes and each leaf of each result of hll-to-hil to be an empty list")
              #/expect
                (= islandlake-hole-degree #/sub1 islandlake-degree)
                #t
                null
              #/hypermonad-pure hii (sub1 #/sub1 hole-degree)
                ; NOTE: This assumes `hil and `hii` have the same hole
                ; shape at the highest degree.
                islandlake-hole-shape
              #/striped-hypersnippet-non-lake null)))
        #/hypermonad-map-with-degree-and-shape hil
          (hl-to-hil hole-shape)
        #/lambda
          (
            islandlake-hole-degree islandlake-hole-shape
            islandlake-leaf)
          (w- islandlake-degree (sub1 hole-degree)
          #/expect (< islandlake-hole-degree islandlake-degree) #t
            (error "Expected hole-shape and the result of hl-to-hil to be valid hypersnippets for particular hypermonads")
          #/expect (= islandlake-hole-degree #/sub1 islandlake-degree)
            #t
            (expect islandlake-leaf (list)
              (error "Expected each leaf of hole-shape to be an empty list")
              null)
          ; NOTE: This assumes `hil` and `hii` have the same hole
          ; shape at the highest degree.
          #/hypermonad-pure hii (sub1 #/sub1 hole-degree)
            islandlake-hole-shape
          #/striped-hypersnippet-non-lake leaf))
      
      #/if (= overall-degree #/add1 #/add1 hole-degree)
        
        ; We transform something of the form:
        ;
        ;   ^N(  )
        ;      il
        ;
        ; into something of the form:
        ;
        ;        ^N+1(  ~N(  )  )
        ;             ii   il ii
        ;  Striped:  [  --il--  ]
        ;  (That 1 layer of striping is striped.)
        ;
        (striped-hypersnippet
        #/striped-hypersnippet
        #/hypermonad-pure hii (sub1 hole-degree)
          (hil-to-hiil hole-shape)
        #/striped-hypersnippet-lake
          (striped-hypersnippet-non-lake leaf)
        #/hypermonad-map-with-degree-and-shape hil hole-shape
        #/lambda (hole-hole-degree hole-hole-shape hole-leaf)
          (expect (< hole-hole-degree hole-degree) #t
            (error "Expected hole-shape to be a valid hypersnippet for a particular hypermonad")
          #/expect hole-leaf (list)
            (error "Expected each leaf of hole-shape to be an empty list")
          #/expect (= hole-hole-degree #/sub1 hole-degree) #t
            null
          ; NOTE: This assumes `hil` and `hii` have the same hole
          ; shape at the highest degree.
          #/hypermonad-pure hii (sub1 hole-degree) hole-hole-shape
          #/striped-hypersnippet-non-lake null))
      
      #/hypermonad-pure hii hole-degree hole-shape leaf))
    (define
      (hypermonad-bind-with-degree-and-shape
        this prefix degree-shape-and-leaf-to-suffix)
      (expect this
        (hypermonad-striped-striped
          overall-degree hii hil hli hll hl
          hll-to-hil hl-to-hil hil-to-hiil to-hll
          fill-pred-hole fill-pred-pred-hole)
        (error "Expected this to be a hypermonad-striped-striped")
      
      ; TODO: At some point during this process, we might transform
      ; something of the form:
      ;
      ;             ^N+2(  ~N+1(  ~N(  ~N(  )    )   )    ~N(  )  )
      ;                  ii     li   ii   il   ii  li   ii   il ii
      ;   Striped:                  [  --il--    ]
      ;   Striped:             [    ------ll------   ]
      ;   Striped:      [      -----------il----------    --il--  ]
      ;   (Those 3 layers of striping are striped.)
      ;
      ; into something roughly of the form (TODO: Stop being so sloppy
      ; in the following diagrams.):
      ;
      ;             ^N+2(              ~N(  )             ~N(  )  )
      ;                  ii     li   ii   il   ii  li  ii    il ii
      ;   Striped:      [              ]      [          ]     [  ]
      ;   Striped:      [                                         ]
      ;
      ;
      ; so that we can zip it with something of the form:
      ;
      ;             ^N+2(              ~N(  )             ~N(  )  )
      ;                         hi        hl       hi        hl hi
      ;   Striped:      [                                         ]
      ;
      ; by zipping things of the form:
      ;
      ;               ^N(              )
      ;   Ignored:  ^N+1(    ~N(  )    )
      ;                  ii     li   ii
      ;   Striped:      [              ]
      ;
      ; with things of the form:
      ;
      ;                      ^N(  )
      ;                         hi
      
      #/expect prefix (striped-hypersnippet prefix)
        (error "Expected prefix to be a valid double-striped hypersnippet")
      #/striped-hypersnippet
      #/let next-island
        ([island-and-lakes-and-rest prefix] [is-first-island #t])
      #/expect island-and-lakes-and-rest
        (striped-hypersnippet island-and-lakes-and-rest)
        (error "Expected prefix to be a valid double-striped hypersnippet")
      #/striped-hypersnippet
      #/let next-islandisland
        (
          [islandisland-etc island-and-lakes-and-rest]
          [is-first-islandisland #t])
      #/hypermonad-bind-with-degree-and-shape hii islandisland-etc
      #/lambda (islandisland-hole-degree islandisland-hole-shape leaf)
        (w- islandisland-degree (sub1 #/sub1 overall-degree)
        #/expect (< islandisland-hole-degree islandisland-degree) #t
          (error "Expected prefix to be a valid double-striped hypersnippet for a particular hypermonad")
        #/expect
          (= islandisland-hole-degree #/sub1 islandisland-degree)
          #t
          (if (and is-first-island is-first-islandisland)
            (expect
              (degree-shape-and-leaf-to-suffix
                islandisland-hole-degree islandisland-hole-shape leaf)
              (striped-hypersnippet #/striped-hypersnippet suffix)
              (error "Expected the result of degree-shape-and-leaf-to-suffix to be a valid double-striped hypersnippet")
              suffix)
            (expect leaf (list)
              (error "Expected prefix to be a valid double-striped hypersnippet")
              null))
        #/mat leaf (striped-hypersnippet-lake leaf islandlake-etc)
          (w- islandlake-degree (sub1 #/sub1 overall-degree)
          #/expect
            (fill-pred-pred-hole
              (degree-shape-and-leaf-to-suffix islandlake-degree
                (hypermonad-map-with-degree hil islandlake-etc
                #/lambda (islandlake-hole-degree leaf)
                  null)
                leaf)
              (hypermonad-map-with-degree hil islandlake-etc
              #/lambda (islandlake-hole-degree leaf)
                (expect (< islandlake-hole-degree islandlake-degree)
                  #t
                  (error "Expected prefix to be a valid double-striped hypersnippet for a particular hypermonad")
                #/expect
                  (= islandlake-hole-degree #/sub1 islandlake-degree)
                  #t
                  (expect leaf (list)
                    (error "Expected prefix to be a valid double-striped hypersnippet")
                    null)
                #/next-islandisland leaf #f)))
            (striped-hypersnippet #/striped-hypersnippet suffix)
            (error "Expected the results of degree-shape-and-leaf-to-suffix and fill-pred-pred-hole to be valid double-striped hypersnippets for a particular hypermonad")
            suffix)
        #/mat leaf
          (striped-hypersnippet-non-lake possible-lake-and-rest)
          (mat possible-lake-and-rest
            (striped-hypersnippet-non-lake leaf)
            (if is-first-island
              (expect
                (degree-shape-and-leaf-to-suffix
                  (sub1 #/sub1 #/sub1 overall-degree)
                  islandisland-hole-shape
                  leaf)
                (striped-hypersnippet #/striped-hypersnippet suffix)
                (error "Expected the result of degree-shape-and-leaf-to-suffix to be a valid double-striped hypersnippet")
                suffix)
              (expect leaf (list)
                (error "Expected prefix to be a valid double-edged hypersnippet")
                null))
          #/mat possible-lake-and-rest
            (striped-hypersnippet-lake leaf lake-and-rest)
            ; TODO: Once we implement this, make sure it uses
            ; `next-island`.
            'TODO
          #/error "Expected prefix to be a valid double-striped hypersnippet")
        #/error "Expected prefix to be a valid double-striped hypersnippet")))
    (define
      (hypermonad-map-with-degree-and-shape
        this hypersnippet degree-shape-and-leaf-to-leaf)
      (hypermonad-bind-with-degree-and-shape this hypersnippet
      #/lambda (hole-degree hole-shape leaf)
      #/hypermonad-pure this hole-degree hole-shape leaf))
    (define (hypermonad-join this hypersnippets)
      (hypermonad-bind-with-degree-and-shape this hypersnippets
      #/lambda (hole-degree hole-shape hypersnippet)
        hypersnippet))
    
    (define
      (hypermonad-bind-with-degree
        this prefix degree-and-leaf-to-suffix)
      (hypermonad-bind-with-degree-and-shape this prefix
      #/lambda (hole-degree hole-shape leaf)
        (degree-and-leaf-to-suffix hole-degree leaf)))
    (define
      (hypermonad-map-with-degree
        this hypersnippet degree-and-leaf-to-leaf)
      (hypermonad-map-with-degree-and-shape this hypersnippet
      #/lambda (hole-degree hole-shape leaf)
        (degree-and-leaf-to-leaf hole-degree leaf)))
  ])
