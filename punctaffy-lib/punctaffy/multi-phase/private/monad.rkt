#lang parendown racket/base

; monad.rkt
;
; A dictionary-passing implementation of the monoid typeclass for
; Racket, using Racket's generic methods so that it's more
; straightforward to define dictiaonries that are comparable by
; `equal?`.

(require #/only-in racket/contract/base -> any any/c cons/c)
(require #/only-in racket/contract/region define/contract)
(require #/only-in racket/generic define-generics)

(require #/only-in lathe dissect expect)

(require "../../private/util.rkt")

(require #/only-in "monoid.rkt"
  monoid-segment/c monoid-empty monoid-append)

(provide gen:monad monad? monad/c
  monad-tree/c monad-pure monad-bind monad-map monad-join)

(provide #/rename-out [make-monad-identity monad-identity])
(provide #/rename-out [make-monad-from-monoid monad-from-monoid])


(define-generics monad
  (monad-tree/c monad)
  (monad-pure monad leaf)
  (monad-bind monad prefix leaf-to-suffix)
  (monad-map monad tree leaf-to-leaf)
  (monad-join monad tree-of-trees))


; This monad does nothing. All map and bind operations just process
; the value itself.
(struct-easy "a monad-identity" (monad-identity)
  #:equal
  #:other
  
  #:constructor-name make-monad-identity
  
  #:methods gen:monad
  [
    (define (monad-tree/c this)
      (expect this (monad-identity)
        (error "Expected this to be a monad-identity")
        any/c))
    
    (define (monad-pure this leaf)
      (expect this (monad-identity)
        (error "Expected this to be a monad-identity")
        leaf))
    
    (define/contract (monad-bind this prefix leaf-to-suffix)
      (-> any/c any/c (-> any/c any) any)
      (expect this (monad-identity)
        (error "Expected this to be a monad-identity")
      #/leaf-to-suffix prefix))
    
    (define/contract (monad-map this tree leaf-to-leaf)
      (-> any/c any/c (-> any/c any) any)
      (expect this (monad-identity)
        (error "Expected this to be a monad-identity")
      #/leaf-to-leaf tree))
    
    (define (monad-join this tree-of-trees)
      (expect this (monad-identity)
        (error "Expected this to be a monad-identity")
        tree-of-trees))
  ])


; Given a monoid, returns a monad where a valid tree is a cons cell
; whose first element is a valid segment of the monoid.
(struct-easy "a monad-from-monoid" (monad-from-monoid monoid)
  #:equal
  #:other
  
  #:constructor-name make-monad-from-monoid
  
  #:methods gen:monad
  [
    (define (monad-tree/c this)
      (expect this (monad-from-monoid monoid)
        (error "Expected this to be a monad-from-monoid")
      #/cons/c (monoid-segment/c monoid) any/c))
    
    (define (monad-pure this leaf)
      (expect this (monad-from-monoid monoid)
        (error "Expected this to be a monad-from-monoid")
      #/cons (monoid-empty monoid) leaf))
    
    (define/contract (monad-bind this prefix leaf-to-suffix)
      (-> any/c (cons/c any/c any/c) (-> any/c #/cons/c any/c any/c)
        any)
      (expect this (monad-from-monoid monoid)
        (error "Expected this to be a monad-from-monoid")
      #/dissect prefix (cons prefix leaf)
      #/dissect (leaf-to-suffix leaf) (cons suffix leaf)
      #/cons (monoid-append monoid prefix suffix) leaf))
    
    (define/contract (monad-map this tree leaf-to-leaf)
      (-> any/c (cons/c any/c any/c) (-> any/c any/c) any)
      (expect this (monad-from-monoid monoid)
        (error "Expected this to be a monad-from-monoid")
      #/dissect tree (cons segment leaf)
      #/cons segment #/leaf-to-leaf leaf))
    
    (define (monad-join this tree-of-trees)
      (-> any/c (cons/c any/c #/cons/c any/c any/c)
      #/cons/c any/c any/c)
      (expect this (monad-from-monoid monoid)
        (error "Expected this to be a monad-from-monoid")
      #/dissect tree-of-trees (cons prefix #/cons suffix leaf)
      #/cons (monoid-append monoid prefix suffix) leaf))
  ])
