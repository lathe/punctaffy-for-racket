#lang parendown racket/base

; monad.rkt
;
; A dictionary-passing implementation of the monoid type class for
; Racket, using Racket's generic methods so that it's more
; straightforward to define dictiaonries that are comparable by
; `equal?`.

;   Copyright 2017-2019 The Lathe Authors
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


(require #/only-in racket/contract/base -> any any/c cons/c)
(require #/only-in racket/contract/region define/contract)
(require #/only-in racket/generic define-generics)

(require #/only-in lathe-comforts dissect expect)
(require #/only-in lathe-comforts/struct struct-easy)

(require #/only-in "monoid.rkt" monoid-empty monoid-append)

(provide gen:monad monad? monad/c
  monad-done monad-bind monad-map monad-join)

(provide #/rename-out [make-monad-identity monad-identity])
(provide #/rename-out [make-monad-from-monoid monad-from-monoid])


(define-generics monad
  (monad-done monad leaf)
  (monad-bind monad prefix leaf-to-suffix)
  (monad-map monad tree leaf-to-leaf)
  (monad-join monad tree-of-trees))


; This monad does nothing. All map and bind operations just process
; the value itself.
(struct-easy (monad-identity)
  #:equal
  #:other
  
  #:constructor-name make-monad-identity
  
  #:methods gen:monad
  [
    
    (define (monad-done this leaf)
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
(struct-easy (monad-from-monoid monoid)
  #:equal
  #:other
  
  #:constructor-name make-monad-from-monoid
  
  #:methods gen:monad
  [
    
    (define (monad-done this leaf)
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
