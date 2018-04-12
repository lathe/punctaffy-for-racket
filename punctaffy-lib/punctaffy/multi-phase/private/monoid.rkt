#lang parendown racket/base

; monoid.rkt
;
; A dictionary-passing implementation of the monoid type class for
; Racket, using Racket's generic methods so that it's more
; straightforward to define dictiaonries that are comparable by
; `equal?`.

(require #/only-in racket/contract/base -> any any/c)
(require #/only-in racket/contract/region define/contract)
(require #/only-in racket/generic define-generics)

(require #/only-in lathe-comforts expect)

(require "../../private/util.rkt")

(provide gen:monoid monoid? monoid/c monoid-empty monoid-append)

(provide #/rename-out [make-monoid-trivial monoid-trivial])


(define-generics monoid
  (monoid-empty monoid)
  (monoid-append monoid prefix suffix))


; This monoid has only one segment, namely the empty list.
(struct-easy "a monoid-trivial" (monoid-trivial)
  #:equal
  #:other
  
  #:constructor-name make-monoid-trivial
  
  #:methods gen:monoid
  [
    
    (define (monoid-empty this)
      (expect this (monoid-trivial)
        (error "Expected this to be a monoid-trivial")
        null))
    
    (define/contract (monoid-append this prefix suffix)
      (-> any/c null? null? any)
      (expect this (monoid-trivial)
        (error "Expected this to be a monoid-trivial")
        null))
  ])
