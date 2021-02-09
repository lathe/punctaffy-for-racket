#lang parendown racket/base

; punctaffy/scribblings/private/shim
;
; Import lists, debugging constants, and other utilities that are
; useful primarily for this codebase.

;   Copyright 2021 The Lathe Authors
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


(provide shim-require-various-for-label)


(define-syntax-rule (shim-require-various-for-label)
  (begin
    
    (require #/for-label racket/base)
    (require #/for-label #/only-in racket/contract
      struct-type-property/c)
    (require #/for-label #/only-in racket/contract/base
      -> </c and/c any/c contract? flat-contract? ->i list/c listof
      or/c)
    (require #/for-label #/only-in racket/extflonum extflonum?)
    (require #/for-label #/only-in racket/flonum flvector?)
    (require #/for-label #/only-in racket/fixnum fxvector?)
    (require #/for-label #/only-in racket/list append-map)
    (require #/for-label #/only-in racket/math natural?)
    
    (require #/for-label #/only-in lathe-comforts fn)
    (require #/for-label #/only-in lathe-comforts/contract
      flat-obstinacy obstinacy? obstinacy-contract/c)
    (require #/for-label #/only-in lathe-comforts/list list-bind)
    (require #/for-label #/only-in lathe-comforts/maybe
      just? maybe? maybe/c nothing)
    (require #/for-label #/only-in lathe-comforts/trivial trivial?)
    (require #/for-label #/only-in lathe-morphisms/in-fp/category
      category-sys? category-sys-morphism/c functor-sys?
      functor-sys-apply-to-morphism functor-sys-apply-to-object
      functor-sys/c functor-sys-impl? functor-sys-target
      make-functor-sys-impl-from-apply
      make-natural-transformation-sys-impl-from-apply
      natural-transformation-sys-apply-to-morphism
      natural-transformation-sys/c
      natural-transformation-sys-endpoint-target
      natural-transformation-sys-replace-source
      natural-transformation-sys-replace-target
      natural-transformation-sys-source
      natural-transformation-sys-target prop:functor-sys)
    (require #/for-label #/only-in lathe-morphisms/in-fp/mediary/set
      ok/c)
    (require #/for-label #/only-in parendown pd)
    
    (require #/for-label punctaffy)
    (require #/for-label punctaffy/hypersnippet/dim)
    (require #/for-label punctaffy/hypersnippet/hyperstack)
    (require #/for-label punctaffy/hypersnippet/hypernest)
    (require #/for-label punctaffy/hypersnippet/hypertee)
    (require #/for-label punctaffy/hypersnippet/snippet)
    (require #/for-label punctaffy/hyperbracket)
    (require #/for-label punctaffy/quote)
    (require #/for-label punctaffy/let)
    
    ))
