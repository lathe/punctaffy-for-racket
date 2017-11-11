#lang parendown racket/base

; monoid.rkt
;
; A dictionary-passing implementation of the monoid typeclass for
; Racket, using Racket's generic methods so that it's more
; straightforward to define dictiaonries that are comparable by
; `equal?`.

(require #/only-in racket/contract/base -> any any/c)
(require #/only-in racket/contract/region define/contract)
(require #/only-in racket/generic define-generics)

(require #/only-in lathe expect)

(require "../../private/util.rkt")

(provide gen:monoid monoid? monoid/c
  monoid-segment/c monoid-empty monoid-append)

(provide #/rename-out [make-monoid-trivial monoid-trivial])


(define-generics monoid
  (monoid-segment/c monoid)
  (monoid-empty monoid)
  (monoid-append monoid prefix suffix))


; This monoid has only one segment, namely the empty list.
(struct-easy "a monoid-trivial" (monoid-trivial)
  #:equal
  #:other
  
  #:constructor-name make-monoid-trivial
  
  #:methods gen:monoid
  [
    (define (monoid-segment/c this)
      (expect this (monoid-trivial)
        (error "Expected this to be a monoid-trivial")
        null?))
    
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


; TODO: See if we'll ever use these. At least they demonstrate monoids
; better.
#;(begin

(require #/only-in racket/contract/base flat-rec-contract struct/c)
(require #/only-in lathe mat next nextlet)


(struct-easy "a striped-nil" (striped-nil island) #:equal)
(struct-easy "a striped-cons" (striped-cons island lake rest)
  #:equal
  (#:guard-easy
    (unless (striped-list? rest)
      (error "Expected rest to be a striped list"))))

(define (striped-list? x)
  (or (striped-nil? x) (striped-cons? x)))

(define (striped-list/c island/c lake/c)
  (flat-rec-contract result
    (struct/c striped-nil island/c)
    (struct/c striped-cons island/c lake/c result)))

(struct-easy "a monoid-striped" (monoid-striped island lake)
  #:equal
  (#:guard-easy
    (unless (monoid? island)
      (error "Expected island to be a monoid"))
    (unless (monoid? lake)
      (error "Expected lake to be a monoid")))
  #:other
  
  #:constructor-name make-monoid-striped
  
  #:methods gen:monoid
  [
    (define (monoid-segment/c this)
      (expect this (monoid-striped island lake)
        (error "Expected this to be a monoid-striped")
      #/striped-list/c island lake))
    
    (define (monoid-empty this)
      (expect this (monoid-striped island lake)
        (error "Expected this to be a monoid-striped")
      #/striped-nil #/monoid-empty island))
    
    (define (monoid-append this prefix suffix)
      (expect this (monoid-striped island lake)
        (error "Expected this to be a monoid-striped")
      #/nextlet a prefix b suffix
        (mat a (striped-cons a-island a-lake a)
          (striped-cons a-island a-lake #/next a b)
        #/expect a (striped-nil a-island)
          (error "Expected a to be a striped list")
        #/mat b (striped-nil b-island)
          (striped-nil #/monoid-append island a-island b-island)
        #/expect b (striped-cons b-island b-lake b)
          (error "Expected b to be a striped list")
        #/striped-cons (monoid-append island a-island b-island)
          b-lake b)))
  ])

)
