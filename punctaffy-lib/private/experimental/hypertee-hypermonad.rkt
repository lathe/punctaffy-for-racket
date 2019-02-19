#lang parendown racket/base

; hypertee-hypermonad.rkt
;
; A hypermonad instance for hypertees.

;   Copyright 2018-2019 The Lathe Authors
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


(require #/only-in racket/math natural?)

(require #/only-in lathe-comforts expect fn)
(require #/only-in lathe-comforts/struct struct-easy)

(require #/only-in punctaffy/hypersnippet/hypertee
  hypertee-bind-all-degrees hypertee-degree hypertee-done
  hypertee-join-all-degrees hypertee-map-all-degrees)

(require #/only-in punctaffy/private/experimental/hypermonad
  gen:hypermonad)


; ===== The hypermonad instance for hypertees ========================

; Several of the hypertee operations we've defined obey the hypermonad
; interface. In fact, this may be the only nontrivial hypermonad
; instance we've implemented right now. (TODO: Revise this comment
; when we have other instances. We should see if hyprids (in
; hyprid.rkt) form an instance.)
(struct-easy (hypermonad-hypertee degree)
  #:equal
  (#:guard-easy
    (unless (natural? degree)
      (error "Expected degree to be a natural number")))
  #:other
  
  #:constructor-name make-hypermonad-hypertee
  
  #:methods gen:hypermonad
  [
    
    (define (hypermonad-hole-hypermonad-for-degree this degree)
      (expect this (hypermonad-hypertee overall-degree)
        (error "Expected this to be a hypermonad-hypertee")
      #/expect (natural? degree) #t
        (error "Expected degree to be a natural number")
      #/expect (< degree overall-degree) #t
        (error "Expected the hole degree to be less than the degree of the hypermonad-hypertee")
      #/make-hypermonad-hypertee degree))
    
    (define (hypermonad-done this hole-degree hole-shape leaf)
      (expect this (hypermonad-hypertee degree)
        (error "Expected this to be a hypermonad-hypertee")
      #/expect (natural? hole-degree) #t
        (error "Expected hole-degree to be a natural number")
      #/hypertee-done degree leaf hole-shape))
    (define
      (hypermonad-bind-with-degree-and-shape
        this prefix degree-shape-and-leaf-to-suffix)
      (expect this (hypermonad-hypertee degree)
        (error "Expected this to be a hypermonad-hypertee")
      #/hypertee-bind-all-degrees prefix #/fn hole data
        (degree-shape-and-leaf-to-suffix (hypertee-degree hole) hole
          data)))
    (define
      (hypermonad-map-with-degree-and-shape
        this hypersnippet degree-shape-and-leaf-to-leaf)
      (expect this (hypermonad-hypertee degree)
        (error "Expected this to be a hypermonad-hypertee")
      #/hypertee-map-all-degrees hypersnippet #/fn hole data
        (degree-shape-and-leaf-to-leaf (hypertee-degree hole) hole
          data)))
    (define (hypermonad-join this hypersnippets)
      (expect this (hypermonad-hypertee degree)
        (error "Expected this to be a hypermonad-hypertee")
      #/hypertee-join-all-degrees hypersnippets))
    
    (define
      (hypermonad-bind-with-degree
        this prefix degree-and-leaf-to-suffix)
      (hypermonad-bind-with-degree-and-shape this prefix
      #/fn hole-degree hole-shape leaf
        (degree-and-leaf-to-suffix hole-degree leaf)))
    (define
      (hypermonad-map-with-degree
        this hypersnippet degree-and-leaf-to-leaf)
      (hypermonad-map-with-degree-and-shape this hypersnippet
      #/fn hole-degree hole-shape leaf
        (degree-and-leaf-to-leaf hole-degree leaf)))
  ])
