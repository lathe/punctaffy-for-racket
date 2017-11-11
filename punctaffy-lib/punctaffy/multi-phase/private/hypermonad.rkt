#lang parendown racket/base

; hypermonad.rkt
;
; Generic interfaces for "hypermonad" and "hyperzip" type class
; dictionaries, which are mutually recursive. They both manipulate
; hypersnippet-shaped data. Hypermonads manipulate hypersnippets as
; trees composed end to end, while hyperzips detect whether
; hypersnippets have the same shape and if so, pair up the data from
; their holes.

(require #/only-in racket/generic define-generics)

(require #/only-in lathe expect mat)

(require "../../private/util.rkt")

(provide gen:hypermonad hypermonad? hypermonad/c
  
  hypermonad-hypersnippet/c
  
  hypermonad-degree
  
  hypermonad-hole-hypermonad-for-degree
  hypermonad-hole-hyperzip-for-degree
  
  hypermonad-pure
  hypermonad-bind-with-degree-and-shape
  hypermonad-map-with-degree-and-shape
  hypermonad-join
  
  hypermonad-bind-with-degree
  hypermonad-map-with-degree
)

(provide gen:hyperzip hyperzip? hyperzip/c
  
  hyperzip-first
  hyperzip-second
  hyperzip-combination
  
  hyperzip-zip-maybe
  
  hyperzip-get-first
  hyperzip-get-second
  
  hyperzip-flip
  
  hyperzip-to-flip
)

(provide #/rename-out [make-hypermonad-zero hypermonad-zero])

(provide #/rename-out
  [make-simplified-hyperzip-backwards hyperzip-backwards]
  [make-hyperzip-zero hyperzip-zero])


(define-generics hypermonad
  
  ; This is a contract that classifies whether a value is an
  ; appropriate hypersnippet for this hypermonad.
  (hypermonad-hypersnippet/c hypermonad)
  
  ; This is the degree of the hypermonad, i.e. how many degrees of
  ; holes may be encountered in a value.
  (hypermonad-degree hypermonad)
  
  ; This returns a hypermonad where high-degree holes are prohibited.
  ; The valid hypersnippets may be disjoint from this hypermonad's
  ; valid hypersnippets as well.
  (hypermonad-hole-hypermonad-for-degree hypermonad degree)
  
  ; This returns a hyperzip instance where `first` is a
  ; `hypermonad-ignoring-highest` of this hypermonad and `second` is
  ; the corresponding `hole-hypermonad-for-degree`.
  (hypermonad-hole-hyperzip-for-degree hypermonad degree)
  
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

(define-generics hyperzip
  
  ; These are hypermonad instances, and they must all have the same
  ; degree.
  (hyperzip-first hyperzip)
  (hyperzip-second hyperzip)
  (hyperzip-combination hyperzip)
  
  ; This takes a hypersnippet from the `first` hypermonad instance and
  ; a hypersnippet from the `second` hypermonad instance and returns a
  ; maybe which contains a hypersnippet from the `combination`
  ; hypermonad instance with with the same holes as both, if they have
  ; the same holes. The values of the holes are cons cells containing
  ; the original values.
  (hyperzip-zip-maybe
    hyperzip first-hypersnippet second-hypersnippet)
  
  ; Given a `combination` hypersnippet value, these return a `first`
  ; or a `second` hypersnippet with the same holes, containing the
  ; same values in those holes.
  (hyperzip-get-first hyperzip combination-hypersnippet)
  (hyperzip-get-second hyperzip combination-hypersnippet)
  
  ; This is a hyperzip where `first` and `second` are swapped and
  ; where `flip` is this hyperzip.
  (hyperzip-flip hyperzip)
  
  ; This converts a hypersnippet from `combination` into the
  ; `combination` of `flip`.
  (hyperzip-to-flip hyperzip combination-hypersnippet)
)


; This is a degree-0 hypermonad.
(struct-easy "a hypermonad-zero" (hypermonad-zero)
  #:equal
  #:other
  
  #:constructor-name make-hypermonad-zero
  
  #:methods gen:hypermonad
  [
    
    (define (hypermonad-hypersnippet/c this)
      (expect this (hypermonad-zero)
        (error "Expected this to be a hypermonad-zero")
        null?))
    
    (define (hypermonad-degree this)
      (expect this (hypermonad-zero)
        (error "Expected this to be a hypermonad-zero")
        0))
    
    (define (hypermonad-hole-hypermonad-for-degree this degree)
      (expect this (hypermonad-zero)
        (error "Expected this to be a hypermonad-zero")
      #/expect (exact-nonnegative-integer? degree) #t
        (error "Expected degree to be an exact nonnegative integer")
        (error "Called hypermonad-hole-hypermonad-for-degree on a hypermonad-zero")))
    
    (define (hypermonad-hole-hyperzip-for-degree this degree)
      (expect this (hypermonad-zero)
        (error "Expected this to be a hypermonad-zero")
      #/expect (exact-nonnegative-integer? degree) #t
        (error "Expected degree to be an exact nonnegative integer")
        (error "Called hypermonad-hole-hyperzip-for-degree on a hypermonad-zero")))
    
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


; Given a hyperzip, this returns a hyperzip where `first` and `second`
; have traded places, but `combination` remains the same.
(struct-easy "a hyperzip-backwards" (hyperzip-backwards hz)
  #:equal
  (#:guard-easy
    (unless (hyperzip? hz)
      (error "Expected hz to be a hypermonad")))
  
  #:other
  
  #:constructor-name make-hyperzip-backwards
  
  #:methods gen:hyperzip
  [
    
    (define (hyperzip-first this)
      (expect this (hyperzip-backwards hz)
        (error "Expected this to be a hyperzip-backwards")
      #/hyperzip-second hz))
    (define (hyperzip-second this)
      (expect this (hyperzip-backwards hz)
        (error "Expected this to be a hyperzip-backwards")
      #/hyperzip-first hz))
    (define (hyperzip-combination this)
      (expect this (hyperzip-backwards hz)
        (error "Expected this to be a hyperzip-backwards")
      #/hyperzip-combination hz))
    
    (define
      (hyperzip-zip-maybe this first-hypersnippet second-hypersnippet)
      (expect this (hyperzip-backwards hz)
        (error "Expected this to be a hyperzip-backwards")
      #/hyperzip-zip-maybe hz first-hypersnippet second-hypersnippet))
    
    (define (hyperzip-get-first this combination-hypersnippet)
      (expect this (hyperzip-backwards hz)
        (error "Expected this to be a hyperzip-backwards")
      #/hyperzip-get-second hz combination-hypersnippet))
    (define (hyperzip-get-second this combination-hypersnippet)
      (expect this (hyperzip-backwards hz)
        (error "Expected this to be a hyperzip-backwards")
      #/hyperzip-get-first hz combination-hypersnippet))
    
    (define (hyperzip-flip this)
      (expect this (hyperzip-backwards hz)
        (error "Expected this to be a hyperzip-backwards")
        hz))
    
    (define (hyperzip-to-flip this combination-hypersnippet)
      (expect this (hyperzip-backwards hz)
        (error "Expected this to be a hyperzip-backwards")
        combination-hypersnippet))
  ])

(define (make-simplified-hyperzip-backwards hyperzip)
  (mat hyperzip (hyperzip-backwards hz) hz
  #/make-hyperzip-backwards hyperzip))


; Given a degree-0 hypermonad, this retrns a hyperzip where `first`
; and `combination` are that hypermonad, and `second` is
; `hypermonad-zero`.
(struct-easy "a hyperzip-zero" (hyperzip-zero hypermonad)
  #:equal
  (#:guard-easy
    (unless (hypermonad? hypermonad)
      (error "Expected hypermonad to be a hypermonad"))
    (unless (= 0 #/hypermonad-degree hypermonad)
      (error "Expected hypermonad to be a degree-zero hypermonad")))
  
  #:other
  
  #:constructor-name make-hyperzip-zero
  
  #:methods gen:hyperzip
  [
    
    (define (hyperzip-first this)
      (expect this (hyperzip-zero hypermonad)
        (error "Expected this to be a hyperzip-zero")
        hypermonad))
    (define (hyperzip-second this)
      (expect this (hyperzip-zero hypermonad)
        (error "Expected this to be a hyperzip-zero")
      #/make-hypermonad-zero))
    (define (hyperzip-combination this)
      (expect this (hyperzip-zero hypermonad)
        (error "Expected this to be a hyperzip-zero")
        hypermonad))
    
    (define
      (hyperzip-zip-maybe this first-hypersnippet second-hypersnippet)
      (expect this (hyperzip-zero hypermonad)
        (error "Expected this to be a hyperzip-zero")
      #/expect second-hypersnippet (list)
        (error "Expected second-hypersnippet to be an empty list")
      #/list first-hypersnippet))
    
    (define (hyperzip-get-first this combination-hypersnippet)
      (expect this (hyperzip-zero hypermonad)
        (error "Expected this to be a hyperzip-zero")
        combination-hypersnippet))
    (define (hyperzip-get-second this combination-hypersnippet)
      (expect this (hyperzip-zero hypermonad)
        (error "Expected this to be a hyperzip-zero")
        null))
    
    (define (hyperzip-flip this)
      (expect this (hyperzip-zero hypermonad)
        (error "Expected this to be a hyperzip-zero")
      #/make-hyperzip-backwards this))
    
    (define (hyperzip-to-flip this combination-hypersnippet)
      (expect this (hyperzip-zero hypermonad)
        (error "Expected this to be a hyperzip-zero")
        combination-hypersnippet))
  ])
