#lang parendown racket/base

; punctaffy/hyperbracket
;
; Interfaces to represent hyperbracket notation keywords, behaviorless
; macros which can cooperate with Racket macros that are aware of
; Punctaffy's representation of hypersnippet-shaped lexical structure.

;   Copyright 2021, 2022 The Lathe Authors
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


(require #/only-in racket/contract struct-type-property/c)
(require #/only-in racket/contract/base -> and/c any/c none/c)

(require #/only-in lathe-comforts dissect fn)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct)

(require punctaffy/private/shim)
(init-shim)


(provide #/own-contract-out
  
  hyperbracket-notation?
  hyperbracket-notation-impl?
  prop:hyperbracket-notation
  make-hyperbracket-notation-impl
  
  hyperbracket-notation-prefix-expander?
  hyperbracket-notation-prefix-expander-impl?
  hyperbracket-notation-prefix-expander-expand
  prop:hyperbracket-notation-prefix-expander
  make-hyperbracket-notation-prefix-expander-impl
  makeshift-hyperbracket-notation-prefix-expander
  
  )
(provide
  hyperbracket-open-with-degree)
(provide #/own-contract-out
  hyperbracket-open-with-degree?)
(provide
  hyperbracket-close-with-degree)
(provide #/own-contract-out
  hyperbracket-close-with-degree?)


(define-imitation-simple-generics
  hyperbracket-notation?
  hyperbracket-notation-impl?
  prop:hyperbracket-notation make-hyperbracket-notation-impl
  'hyperbracket-notation 'hyperbracket-notation-impl (list))
(ascribe-own-contract hyperbracket-notation? (-> any/c boolean?))
(ascribe-own-contract hyperbracket-notation-impl? (-> any/c boolean?))
(ascribe-own-contract prop:hyperbracket-notation
  (struct-type-property/c hyperbracket-notation-impl?))
(ascribe-own-contract make-hyperbracket-notation-impl
  (-> hyperbracket-notation-impl?))

(define (raise-hyperbracket-notation-as-expression-error stx)
  (raise-syntax-error #f "hyperbracket notation keyword not allowed as an expression"
    stx))

(define-imitation-simple-generics
  hyperbracket-notation-prefix-expander?
  hyperbracket-notation-prefix-expander-impl?
  (#:method hyperbracket-notation-prefix-expander-expand (#:this) ())
  prop:hyperbracket-notation-prefix-expander
  make-hyperbracket-notation-prefix-expander-impl
  'hyperbracket-notation-prefix-expander
  'hyperbracket-notation-prefix-expander-impl
  (list))
(ascribe-own-contract hyperbracket-notation-prefix-expander?
  (-> any/c boolean?))
(ascribe-own-contract hyperbracket-notation-prefix-expander-impl?
  (-> any/c boolean?))
(ascribe-own-contract hyperbracket-notation-prefix-expander-expand
  (-> hyperbracket-notation-prefix-expander? syntax? syntax?))
(ascribe-own-contract prop:hyperbracket-notation-prefix-expander
  (struct-type-property/c
    hyperbracket-notation-prefix-expander-impl?))
(ascribe-own-contract make-hyperbracket-notation-prefix-expander-impl
  (-> (-> hyperbracket-notation-prefix-expander? syntax? syntax?)
    hyperbracket-notation-prefix-expander-impl?))

(define-imitation-simple-struct
  (makeshift-hyperbracket-notation-prefix-expander?
    makeshift-hyperbracket-notation-prefix-expander-impl)
  unguarded-makeshift-hyperbracket-notation-prefix-expander
  'makeshift-hyperbracket-notation-prefix-expander (current-inspector)
  (auto-write)
  (#:prop prop:procedure #/fn op stx
    (raise-hyperbracket-notation-as-expression-error stx))
  (#:prop prop:hyperbracket-notation
    (make-hyperbracket-notation-impl))
  (#:prop prop:hyperbracket-notation-prefix-expander
    (make-hyperbracket-notation-prefix-expander-impl #/fn op stx
      (dissect op
        (unguarded-makeshift-hyperbracket-notation-prefix-expander
          impl)
      #/impl stx))))

(define/own-contract
  (makeshift-hyperbracket-notation-prefix-expander impl)
  (-> (-> syntax? syntax?)
    (and/c
      procedure?
      hyperbracket-notation?
      hyperbracket-notation-prefix-expander?))
  (unguarded-makeshift-hyperbracket-notation-prefix-expander impl))


(define-imitation-simple-struct
  (hyperbracket-open-with-degree?)
  hyperbracket-open-with-degree
  'hyperbracket-open-with-degree (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:procedure #/fn op stx
    (raise-hyperbracket-notation-as-expression-error stx))
  (#:prop prop:hyperbracket-notation
    (make-hyperbracket-notation-impl)))
(ascribe-own-contract hyperbracket-open-with-degree?
  (-> any/c boolean?))

(define-imitation-simple-struct
  (hyperbracket-close-with-degree?)
  hyperbracket-close-with-degree
  'hyperbracket-close-with-degree (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:procedure #/fn op stx
    (raise-hyperbracket-notation-as-expression-error stx))
  (#:prop prop:hyperbracket-notation
    (make-hyperbracket-notation-impl)))
(ascribe-own-contract hyperbracket-close-with-degree?
  (-> any/c boolean?))
