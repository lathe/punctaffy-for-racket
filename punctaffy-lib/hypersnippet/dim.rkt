#lang parendown racket/base

; punctaffy/hypersnippet/dim
;
; Interfaces to represent numbers that represent the dimensionality of
; hypersnippets.

;   Copyright 2019, 2020, 2022 The Lathe Authors
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


; NOTE: The Racket documentation says `get/build-late-neg-projection`
; is in `racket/contract/combinator`, but it isn't. It's in
; `racket/contract/base`. Since it's also in `racket/contract` and the
; documentation correctly says it is, we require it from there.
(require #/only-in racket/contract
  get/build-late-neg-projection struct-type-property/c)
(require #/only-in racket/contract/base
  -> ->i </c =/c and/c any/c contract? contract-name flat-contract?
  flat-contract-predicate listof or/c rename-contract)
(require #/only-in racket/contract/combinator
  blame-add-context coerce-contract contract-first-order-passes?
  make-contract make-flat-contract)
(require #/only-in racket/contract/region define/contract)
(require #/only-in racket/math natural?)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/list list-map)
(require #/only-in lathe-comforts/match
  define-match-expander-attenuated
  define-match-expander-from-match-and-make match/c)
(require #/only-in lathe-comforts/maybe
  just maybe/c maybe-map nothing)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct)
(require #/only-in lathe-morphisms/in-fp/set
  makeshift-set-sys-from-contract)
(require #/only-in lathe-morphisms/in-fp/category
  category-sys-morphism/c functor-sys-apply-to-morphism
  functor-sys-apply-to-object functor-sys/c functor-sys-impl?
  functor-sys-target make-category-sys-impl-from-chain-two
  make-functor-sys-impl-from-apply
  natural-transformation-sys-apply-to-morphism
  natural-transformation-sys/c
  natural-transformation-sys-endpoint-target
  natural-transformation-sys-source natural-transformation-sys-target
  prop:category-sys prop:functor-sys)
(require #/only-in lathe-morphisms/in-fp/mediary/set
  make-atomic-set-element-sys-impl-from-contract ok/c
  prop:atomic-set-element-sys)

; TODO NOW: Remove uses of `lathe-morphisms/private/shim`,
; particularly including `shim-contract-out` and
; `shim-recontract-out`.
(require lathe-morphisms/private/shim)
(require punctaffy/private/shim)
(init-shim)


(provide #/own-contract-out
  
  dim-sys?
  dim-sys-impl?
  dim-sys-dim/c
  dim-sys-dim-max
  dim-sys-dim-zero
  dim-sys-dim-max-of-two
  dim-sys-dim=?
  dim-sys-dim<=?
  dim-sys-dim<?
  dim-sys-dim</c
  dim-sys-dim=/c
  dim-sys-dim=0?
  dim-sys-0<dim/c
  prop:dim-sys
  make-dim-sys-impl-from-max-of-two
  
  dim-sys-morphism-sys?
  dim-sys-morphism-sys-impl?
  dim-sys-morphism-sys-source
  dim-sys-morphism-sys-replace-source
  dim-sys-morphism-sys-target
  dim-sys-morphism-sys-replace-target
  dim-sys-morphism-sys-morph-dim
  dim-sys-morphism-sys/c
  prop:dim-sys-morphism-sys
  make-dim-sys-morphism-sys-impl-from-morph
  dim-sys-morphism-sys-identity
  dim-sys-morphism-sys-chain-two)

(provide
  dim-sys-category-sys)
(provide #/shim-contract-out
  [dim-sys-category-sys? (-> any/c boolean?)]
  [functor-from-dim-sys-sys-apply-to-morphism
    (->i
      (
        [fs (functor-sys/c dim-sys-category-sys? any/c)]
        [dsms dim-sys-morphism-sys?])
      [_ (fs dsms)
        (category-sys-morphism/c (functor-sys-target fs)
          (functor-sys-apply-to-object fs
            (dim-sys-morphism-sys-source dsms))
          (functor-sys-apply-to-object fs
            (dim-sys-morphism-sys-target dsms)))])]
  [natural-transformation-from-from-dim-sys-sys-apply-to-morphism
    (->i
      (
        [nts
          (natural-transformation-sys/c
            dim-sys-category-sys? any/c any/c any/c)]
        [dsms dim-sys-morphism-sys?])
      [_ (nts dsms)
        (category-sys-morphism/c
          (natural-transformation-sys-endpoint-target nts)
          (functor-sys-apply-to-object
            (natural-transformation-sys-source nts)
            (dim-sys-morphism-sys-source dsms))
          (functor-sys-apply-to-object
            (natural-transformation-sys-target nts)
            (dim-sys-morphism-sys-target dsms)))])]
  [dim-sys-endofunctor-sys? (-> any/c boolean?)]
  [make-dim-sys-endofunctor-sys-impl-from-apply
    (->
      (-> dim-sys-endofunctor-sys? dim-sys? dim-sys?)
      (->i
        (
          [es dim-sys-endofunctor-sys?]
          [ms dim-sys-morphism-sys?])
        [_ (es ms)
          (dim-sys-morphism-sys/c
            (ok/c
              (functor-sys-apply-to-object es
                (dim-sys-morphism-sys-source ms)))
            (ok/c
              (functor-sys-apply-to-object es
                (dim-sys-morphism-sys-target ms))))])
      functor-sys-impl?)])

; TODO: Document these exports if we ever need them. We would comment
; them out, but they're currently in use by some internal experiments.
;#;
(provide #/shim-contract-out
  [dim-successors-sys? (-> any/c boolean?)]
  [dim-successors-sys-impl? (-> any/c boolean?)]
  [dim-successors-sys-dim-sys (-> dim-successors-sys? dim-sys?)]
  [dim-successors-sys-dim-plus-int
    (->i
      (
        [dss dim-successors-sys?]
        [d (dss) (dim-sys-dim/c #/dim-successors-sys-dim-sys dss)]
        [n exact-integer?])
      [_ (dss)
        (maybe/c #/dim-sys-dim/c #/dim-successors-sys-dim-sys dss)])]
  [dim-successors-sys-dim-from-int
    (->i ([dss dim-successors-sys?] [n exact-integer?])
      [_ (dss)
        (maybe/c #/dim-sys-dim/c #/dim-successors-sys-dim-sys dss)])]
  [dim-successors-sys-dim=plus-int?
    (->i
      (
        [dss dim-successors-sys?]
        [candidate (dss)
          (dim-sys-dim/c #/dim-successors-sys-dim-sys dss)]
        [d (dss) (dim-sys-dim/c #/dim-successors-sys-dim-sys dss)]
        [n exact-integer?])
      [_ boolean?])]
  [prop:dim-successors-sys
    (struct-type-property/c dim-successors-sys-impl?)]
  [make-dim-successors-sys-impl-from-dim-plus-int
    (->
      (-> dim-successors-sys? dim-sys?)
      (->i
        (
          [dss dim-successors-sys?]
          [d (dss)
            (dim-sys-dim/c #/dim-successors-sys-dim-sys dss)]
          [n exact-integer?])
        [_ (dss n)
          (maybe/c
          #/dim-sys-dim/c #/dim-successors-sys-dim-sys dss)])
      dim-successors-sys-impl?)]
  
  )

; TODO: Uncomment these exports if we ever need them.
;(provide successorless-dim-successors-sys)
;(provide #/shim-contract-out
;  [successorless-dim-successors-sys? (-> any/c boolean?)])
(provide
  nat-dim-sys)
(provide #/shim-contract-out
  [nat-dim-sys? (-> any/c boolean?)])
; TODO: Document this export if we ever need it. We would comment it
; out, but it's currently in use by some internal experiments.
;#;
(provide
  nat-dim-successors-sys)
; TODO: Uncomment this export if we ever need it.
;(provide #/shim-contract-out
;  [nat-dim-successors-sys? (-> any/c boolean?)])
(provide
  extended-with-top-dim-finite)
(provide #/shim-contract-out
  [extended-with-top-dim-finite? (-> any/c boolean?)]
  [extended-with-top-dim-finite-original
    (-> extended-with-top-dim-finite? any/c)])
(provide
  extended-with-top-dim-infinite)
(provide #/shim-contract-out
  [extended-with-top-dim-infinite? (-> any/c boolean?)])
(provide #/shim-contract-out
  [extended-with-top-dim? (-> any/c boolean?)]
  [extended-with-top-dim/c (-> contract? contract?)]
  [extended-with-top-dim=?
    (->
      (-> any/c any/c boolean?)
      extended-with-top-dim?
      extended-with-top-dim?
      boolean?)])
(provide
  extended-with-top-dim-sys)
(provide #/shim-contract-out
  [extended-with-top-dim-sys? (-> any/c boolean?)]
  [extended-with-top-dim-sys-original
    (-> extended-with-top-dim-sys? dim-sys?)])
(provide
  extended-with-top-dim-sys-morphism-sys)
(provide #/shim-contract-out
  [extended-with-top-dim-sys-morphism-sys? (-> any/c boolean?)]
  [extended-with-top-dim-sys-morphism-sys-original
    (-> extended-with-top-dim-sys-morphism-sys?
      dim-sys-morphism-sys?)])
(provide
  extended-with-top-dim-sys-endofunctor-sys)
(provide #/shim-contract-out
  [extended-with-top-dim-sys-endofunctor-sys? (-> any/c boolean?)])
(provide
  extend-with-top-dim-sys-morphism-sys)
(provide #/shim-contract-out
  [extend-with-top-dim-sys-morphism-sys? (-> any/c boolean?)]
  [extend-with-top-dim-sys-morphism-sys-source
    (-> extend-with-top-dim-sys-morphism-sys? dim-sys?)])
(provide
  extended-with-top-finite-dim-sys)
(provide #/shim-contract-out
  [extended-with-top-finite-dim-sys? (-> any/c boolean?)]
  [extended-with-top-finite-dim-sys-original
    (-> extended-with-top-finite-dim-sys? dim-sys?)])
(provide
  unextend-with-top-dim-sys-morphism-sys)
(provide #/shim-contract-out
  [unextend-with-top-dim-sys-morphism-sys? (-> any/c boolean?)]
  [unextend-with-top-dim-sys-morphism-sys-target
    (-> unextend-with-top-dim-sys-morphism-sys? dim-sys?)])
(provide
  extended-with-top-dim-successors-sys)
(provide #/shim-contract-out
  [extended-with-top-dim-successors-sys? (-> any/c boolean?)]
  [extended-with-top-dim-successors-sys-original
    (-> extended-with-top-dim-successors-sys? dim-successors-sys?)])
; TODO: Uncomment these exports if we ever need them.
#|
(provide
  fin-multiplied-dim)
(provide #/shim-contract-out
  [fin-multiplied-dim? (-> any/c boolean?)]
  [fin-multiplied-dim-index (-> fin-multiplied-dim? natural?)]
  [fin-multiplied-dim-original (-> fin-multiplied-dim? any/c)]
  [fin-multiplied-dim/c
    (-> exact-positive-integer? contract? contract?)]
  [fin-multiplied-dim=?
    (-> (-> any/c any/c boolean?) any/c any/c boolean?)])
(provide
  fin-multiplied-dim-sys)
(provide #/shim-contract-out
  [fin-multiplied-dim-sys? (-> any/c boolean?)]
  [fin-multiplied-dim-sys-bound
    (-> fin-multiplied-dim-sys? exact-positive-integer?)]
  [fin-multiplied-dim-sys-original
    (-> fin-multiplied-dim-sys? dim-sys?)])
(provide
  fin-multiplied-dim-sys-morphism-sys)
(provide #/shim-contract-out
  [fin-multiplied-dim-sys-morphism-sys? (-> any/c boolean?)]
  [fin-multiplied-dim-sys-morphism-sys-bound
    (-> fin-multiplied-dim-sys-morphism-sys? exact-positive-integer?)]
  [fin-multiplied-dim-sys-morphism-sys-original
    (-> fin-multiplied-dim-sys-morphism-sys?
      dim-sys-morphism-sys?)])
(provide
  fin-multiplied-dim-sys-endofunctor-sys)
(provide #/shim-contract-out
  [fin-multiplied-dim-sys-endofunctor-sys? (-> any/c boolean?)]
  [fin-multiplied-dim-sys-endofunctor-sys-bound
    (-> fin-multiplied-dim-sys-endofunctor-sys?
      exact-positive-integer?)])
(provide
  fin-times-dim-sys-morphism-sys)
(provide #/shim-contract-out
  [fin-times-dim-sys-morphism-sys? (-> any/c boolean?)]
  [fin-times-dim-sys-morphism-sys-bound
    (-> fin-times-dim-sys-morphism-sys? exact-positive-integer?)]
  [fin-times-dim-sys-morphism-sys-source
    (-> fin-times-dim-sys-morphism-sys? dim-sys?)]
  [fin-times-dim-sys-morphism-sys-dim-to-index
    (->i ([ms fin-times-dim-sys-morphism-sys?])
      [_ (ms)
        (-> (dim-sys-dim/c #/fin-times-dim-sys-morphism-sys-source ms)
          (and/c natural?
            (</c #/fin-times-dim-sys-morphism-sys-bound ms)))])])
(provide
  fin-untimes-dim-sys-morphism-sys)
(provide #/shim-contract-out
  [fin-untimes-dim-sys-morphism-sys? (-> any/c boolean?)]
  [fin-untimes-dim-sys-morphism-sys-bound
    (-> fin-untimes-dim-sys-morphism-sys? exact-positive-integer?)]
  [fin-untimes-dim-sys-morphism-sys-target
    (-> fin-untimes-dim-sys-morphism-sys? dim-sys?)])
(provide
  fin-multiplied-dim-successors-sys)
(provide #/shim-contract-out
  [fin-multiplied-dim-successors-sys? (-> any/c boolean?)]
  [fin-multiplied-dim-successors-sys-bound
    (-> fin-multiplied-dim-successors-sys? exact-positive-integer?)]
  [fin-multiplied-dim-successors-sys-original
    (-> fin-multiplied-dim-successors-sys? dim-successors-sys?)])
|#


(define-imitation-simple-generics dim-sys? dim-sys-impl?
  (#:method dim-sys-dim/c (#:this))
  (#:method dim-sys-dim=? (#:this) () ())
  (#:method dim-sys-dim-zero (#:this))
  (#:method dim-sys-dim-max-of-two (#:this) () ())
  prop:dim-sys make-dim-sys-impl-from-max-of-two
  'dim-sys 'dim-sys-impl (list))
(ascribe-own-contract dim-sys? (-> any/c boolean?))
(ascribe-own-contract dim-sys-impl? (-> any/c boolean?))
(ascribe-own-contract dim-sys-dim/c (-> dim-sys? flat-contract?))
(ascribe-own-contract dim-sys-dim=?
  (->i
    (
      [ds dim-sys?]
      [a (ds) (dim-sys-dim/c ds)]
      [b (ds) (dim-sys-dim/c ds)])
    [_ boolean?]))
(ascribe-own-contract dim-sys-dim-zero
  (->i ([ds dim-sys?]) [_ (ds) (dim-sys-dim/c ds)]))
(ascribe-own-contract dim-sys-dim-max-of-two
  (->i
    (
      [ds dim-sys?]
      [a (ds) (dim-sys-dim/c ds)]
      [b (ds) (dim-sys-dim/c ds)])
    [_ (ds) (dim-sys-dim/c ds)]))
(ascribe-own-contract prop:dim-sys
  (struct-type-property/c dim-sys-impl?))
(ascribe-own-contract make-dim-sys-impl-from-max-of-two
  (->
    (-> dim-sys? flat-contract?)
    (->i
      (
        [ds dim-sys?]
        [a (ds) (dim-sys-dim/c ds)]
        [b (ds) (dim-sys-dim/c ds)])
      [_ boolean?])
    (->i ([ds dim-sys?]) [_ (ds) (dim-sys-dim/c ds)])
    (->i
      (
        [ds dim-sys?]
        [a (ds) (dim-sys-dim/c ds)]
        [b (ds) (dim-sys-dim/c ds)])
      [_ (ds) (dim-sys-dim/c ds)])
    dim-sys-impl?))

(define (dim-sys-dim-max-of-dim-and-list ds d lst)
  (expect lst (cons first rest)
    d
  #/dim-sys-dim-max-of-dim-and-list
    ds (dim-sys-dim-max-of-two ds d first) rest))

; TODO: See if we'll use this.
(define (dim-sys-dim-max-of-list ds lst)
  (dim-sys-dim-max-of-dim-and-list ds (dim-sys-dim-zero ds) lst))

; NOTE OPTIMIZATION: The use of `case-lambda` gives this a substantial
; boost.
(define/own-contract dim-sys-dim-max
  (->i ([ds dim-sys?]) #:rest [args (ds) (listof #/dim-sys-dim/c ds)]
    [_ (ds) (dim-sys-dim/c ds)])
  (case-lambda
    [(ds a b) (dim-sys-dim-max-of-two ds a b)]
    [(ds) (dim-sys-dim-zero ds)]
    [(ds d . args) (dim-sys-dim-max-of-dim-and-list ds d args)]))

(define/own-contract (dim-sys-dim<=? ds a b)
  (->i
    (
      [ds dim-sys?]
      [a (ds) (dim-sys-dim/c ds)]
      [b (ds) (dim-sys-dim/c ds)])
    [_ boolean?])
  (dim-sys-dim=? ds b #/dim-sys-dim-max ds a b))

(define/own-contract (dim-sys-dim<? ds a b)
  (->i
    (
      [ds dim-sys?]
      [a (ds) (dim-sys-dim/c ds)]
      [b (ds) (dim-sys-dim/c ds)])
    [_ boolean?])
  (and (not #/dim-sys-dim=? ds a b) (dim-sys-dim<=? ds a b)))

(define/own-contract (dim-sys-dim</c ds bound)
  (->i ([ds dim-sys?] [bound (ds) (dim-sys-dim/c ds)])
    [_ flat-contract?])
  (rename-contract
    (and/c (dim-sys-dim/c ds) (fn v #/dim-sys-dim<? ds v bound))
    `(dim-sys-dim</c ,ds ,bound)))

(define/own-contract (dim-sys-dim=/c ds bound)
  (->i ([ds dim-sys?] [bound (ds) (dim-sys-dim/c ds)])
    [_ flat-contract?])
  (rename-contract
    (and/c (dim-sys-dim/c ds) (fn v #/dim-sys-dim=? ds v bound))
    `(dim-sys-dim=/c ,ds ,bound)))

(define/own-contract (dim-sys-dim=0? ds d)
  (->i ([ds dim-sys?] [d (ds) (dim-sys-dim/c ds)]) [_ boolean?])
  (dim-sys-dim=? ds (dim-sys-dim-zero ds) d))

(define/own-contract (dim-sys-0<dim/c ds)
  (-> dim-sys? flat-contract?)
  (rename-contract
    (and/c (dim-sys-dim/c ds) (fn v #/not #/dim-sys-dim=0? ds v))
    `(dim-sys-0<dim/c ,ds)))


(define-imitation-simple-generics
  dim-sys-morphism-sys? dim-sys-morphism-sys-impl?
  (#:method dim-sys-morphism-sys-source (#:this))
  (#:method dim-sys-morphism-sys-replace-source (#:this) ())
  (#:method dim-sys-morphism-sys-target (#:this))
  (#:method dim-sys-morphism-sys-replace-target (#:this) ())
  (#:method dim-sys-morphism-sys-morph-dim (#:this) ())
  prop:dim-sys-morphism-sys make-dim-sys-morphism-sys-impl-from-morph
  'dim-sys-morphism-sys 'dim-sys-morphism-sys-impl (list))
(ascribe-own-contract dim-sys-morphism-sys? (-> any/c boolean?))
(ascribe-own-contract dim-sys-morphism-sys-impl? (-> any/c boolean?))
(ascribe-own-contract dim-sys-morphism-sys-source
  (-> dim-sys-morphism-sys? dim-sys?))
(ascribe-own-contract dim-sys-morphism-sys-replace-source
  (-> dim-sys-morphism-sys? dim-sys? dim-sys-morphism-sys?))
(ascribe-own-contract dim-sys-morphism-sys-target
  (-> dim-sys-morphism-sys? dim-sys?))
(ascribe-own-contract dim-sys-morphism-sys-replace-target
  (-> dim-sys-morphism-sys? dim-sys? dim-sys-morphism-sys?))
(ascribe-own-contract dim-sys-morphism-sys-morph-dim
  (->i
    (
      [ms dim-sys-morphism-sys?]
      [d (ms) (dim-sys-dim/c #/dim-sys-morphism-sys-source ms)])
    [_ (ms) (dim-sys-dim/c #/dim-sys-morphism-sys-target ms)]))
(ascribe-own-contract prop:dim-sys-morphism-sys
  (struct-type-property/c dim-sys-morphism-sys-impl?))
(ascribe-own-contract make-dim-sys-morphism-sys-impl-from-morph
  (->
    (-> dim-sys-morphism-sys? dim-sys?)
    (-> dim-sys-morphism-sys? dim-sys? dim-sys-morphism-sys?)
    (-> dim-sys-morphism-sys? dim-sys?)
    (-> dim-sys-morphism-sys? dim-sys? dim-sys-morphism-sys?)
    (->i
      (
        [ms dim-sys-morphism-sys?]
        [d (ms) (dim-sys-dim/c #/dim-sys-morphism-sys-source ms)])
      [_ (ms) (dim-sys-dim/c #/dim-sys-morphism-sys-target ms)])
    dim-sys-morphism-sys-impl?))

(define/own-contract (dim-sys-morphism-sys/c source/c target/c)
  (-> contract? contract? contract?)
  (w- source/c (coerce-contract 'dim-sys-morphism-sys/c source/c)
  #/w- target/c (coerce-contract 'dim-sys-morphism-sys/c target/c)
  #/w- name
    `(dim-sys-morphism-sys/c
       ,(contract-name source/c)
       ,(contract-name target/c))
  #/
    (if (and (flat-contract? source/c) (flat-contract? target/c))
      make-flat-contract
      make-contract)
    
    #:name name
    
    #:first-order
    (fn v
      (and
        (dim-sys-morphism-sys? v)
        (contract-first-order-passes? source/c
          (dim-sys-morphism-sys-source v))
        (contract-first-order-passes? target/c
          (dim-sys-morphism-sys-target v))))
    
    #:late-neg-projection
    (fn blame
      (w- source/c-projection
        (
          (get/build-late-neg-projection source/c)
          (blame-add-context blame "source of"))
      #/w- target/c-projection
        (
          (get/build-late-neg-projection target/c)
          (blame-add-context blame "target of"))
      #/fn v missing-party
        (w- replace-if-not-flat
          (fn c c-projection replace get v
            (w- c-projection (c-projection (get v) missing-party)
            #/if (flat-contract? c)
              v
              (replace v c-projection)))
        #/w- v
          (replace-if-not-flat
            source/c
            source/c-projection
            dim-sys-morphism-sys-replace-source
            dim-sys-morphism-sys-source
            v)
        #/w- v
          (replace-if-not-flat
            target/c
            target/c-projection
            dim-sys-morphism-sys-replace-target
            dim-sys-morphism-sys-target
            v)
          v)))))

(define-imitation-simple-struct
  (identity-dim-sys-morphism-sys?
    identity-dim-sys-morphism-sys-endpoint)
  identity-dim-sys-morphism-sys
  'identity-dim-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (identity-dim-sys-morphism-sys e)
        (match/c identity-dim-sys-morphism-sys #/ok/c e))))
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-source
      (dissectfn (identity-dim-sys-morphism-sys e) e)
      ; dim-sys-morphism-sys-replace-source
      (fn ms new-s #/identity-dim-sys-morphism-sys new-s)
      ; dim-sys-morphism-sys-target
      (dissectfn (identity-dim-sys-morphism-sys e) e)
      ; dim-sys-morphism-sys-replace-target
      (fn ms new-t #/identity-dim-sys-morphism-sys new-t)
      ; dim-sys-morphism-sys-morph-dim
      (fn ms d d))))

(define/own-contract (dim-sys-morphism-sys-identity endpoint)
  (-> dim-sys? dim-sys-morphism-sys?)
  (identity-dim-sys-morphism-sys endpoint))

(define-imitation-simple-struct
  (chain-two-dim-sys-morphism-sys?
    chain-two-dim-sys-morphism-sys-first
    chain-two-dim-sys-morphism-sys-second)
  chain-two-dim-sys-morphism-sys
  'chain-two-dim-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (chain-two-dim-sys-morphism-sys ab bc)
        (match/c chain-two-dim-sys-morphism-sys
          (ok/c ab)
          (ok/c bc)))))
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-source
      (dissectfn (chain-two-dim-sys-morphism-sys ab bc)
        (dim-sys-morphism-sys-source ab))
      ; dim-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms (chain-two-dim-sys-morphism-sys ab bc)
        #/chain-two-dim-sys-morphism-sys
          (dim-sys-morphism-sys-replace-source ab new-s)
          bc))
      ; dim-sys-morphism-sys-target
      (dissectfn (chain-two-dim-sys-morphism-sys ab bc)
        (dim-sys-morphism-sys-target bc))
      ; dim-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms (chain-two-dim-sys-morphism-sys ab bc)
        #/chain-two-dim-sys-morphism-sys
          ab
          (dim-sys-morphism-sys-replace-target bc new-t)))
      ; dim-sys-morphism-sys-morph-dim
      (fn ms d
        (dissect ms (chain-two-dim-sys-morphism-sys ab bc)
        #/dim-sys-morphism-sys-morph-dim bc
          (dim-sys-morphism-sys-morph-dim ab d))))))

(define/own-contract (dim-sys-morphism-sys-chain-two ab bc)
  (->i
    (
      [ab dim-sys-morphism-sys?]
      [bc (ab)
        (dim-sys-morphism-sys/c
          (ok/c #/dim-sys-morphism-sys-target ab)
          any/c)])
    [_ (ab bc)
      (dim-sys-morphism-sys/c
        (ok/c #/dim-sys-morphism-sys-source ab)
        (ok/c #/dim-sys-morphism-sys-target bc))])
  (chain-two-dim-sys-morphism-sys ab bc))


(define-imitation-simple-struct
  (dim-sys-category-sys?)
  dim-sys-category-sys
  'dim-sys-category-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn _ dim-sys-category-sys?)))
  (#:prop prop:category-sys
    (make-category-sys-impl-from-chain-two
      ; category-sys-object-set-sys
      (fn cs
        (makeshift-set-sys-from-contract
          ; makeshift-set-sys-element/c
          (fn dim-sys?)
          ; makeshift-set-sys-element-accepts/c
          (fn element #/ok/c element)))
      ; category-sys-morphism-set-sys
      (fn cs s t
        (makeshift-set-sys-from-contract
          ; makeshift-set-sys-element/c
          (fn #/dim-sys-morphism-sys/c (ok/c s) (ok/c t))
          ; makeshift-set-sys-element-accepts/c
          (fn element #/ok/c element)))
      ; category-sys-object-identity-morphism
      (fn cs endpoint
        (dim-sys-morphism-sys-identity endpoint))
      ; category-sys-morphism-chain-two
      (fn cs a b c ab bc
        (dim-sys-morphism-sys-chain-two ab bc)))))

(define (functor-from-dim-sys-sys-apply-to-morphism fs dsms)
  (functor-sys-apply-to-morphism fs
    (dim-sys-morphism-sys-source dsms)
    (dim-sys-morphism-sys-target dsms)
    dsms))

(define
  (natural-transformation-from-from-dim-sys-sys-apply-to-morphism
    nts dsms)
  (natural-transformation-sys-apply-to-morphism nts
    (dim-sys-morphism-sys-source dsms)
    (dim-sys-morphism-sys-target dsms)
    dsms))

(define (dim-sys-endofunctor-sys? v)
  (
    (flat-contract-predicate
      (functor-sys/c dim-sys-category-sys? dim-sys-category-sys?))
    v))

(define
  (make-dim-sys-endofunctor-sys-impl-from-apply
    apply-to-dim-sys
    apply-to-dim-sys-morphism-sys)
  (make-functor-sys-impl-from-apply
    ; functor-sys-source
    (fn fs #/dim-sys-category-sys)
    ; functor-sys-replace-source
    (fn fs new-s
      (expect (dim-sys-category-sys? new-s) #t
        (raise-arguments-error 'functor-sys-replace-source
          "tried to replace the source with a source that was rather different"
          "fs" fs
          "s" (dim-sys-category-sys)
          "new-s" new-s)
        fs))
    ; functor-sys-target
    (fn fs #/dim-sys-category-sys)
    ; functor-sys-replace-target
    (fn fs new-t
      (expect (dim-sys-category-sys? new-t) #t
        (raise-arguments-error 'functor-sys-replace-target
          "tried to replace the target with a target that was rather different"
          "fs" fs
          "t" (dim-sys-category-sys)
          "new-t" new-t)
        fs))
    ; functor-sys-apply-to-object
    (fn fs ds #/apply-to-dim-sys fs ds)
    ; functor-sys-apply-to-morphism
    (fn fs a b ms #/apply-to-dim-sys-morphism-sys fs ms)))


(define-imitation-simple-generics
  dim-successors-sys? dim-successors-sys-impl?
  (#:method dim-successors-sys-dim-sys (#:this))
  (#:method dim-successors-sys-dim-plus-int (#:this) () ())
  prop:dim-successors-sys
  make-dim-successors-sys-impl-from-dim-plus-int
  'dim-successors-sys 'dim-successors-sys-impl (list))

(define (dim-successors-sys-dim-from-int dss n)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/dim-successors-sys-dim-plus-int dss (dim-sys-dim-zero ds) n))

(define (dim-successors-sys-dim=plus-int? dss candidate d n)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/expect (dim-successors-sys-dim-plus-int dss d n) (just result) #f
  #/dim-sys-dim=? ds candidate result))


(define-imitation-simple-struct
  (successorless-dim-successors-sys?
    successorless-dim-successors-sys-dim-sys)
  successorless-dim-successors-sys
  'successorless-dim-successors-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (successorless-dim-successors-sys ds)
        (match/c successorless-dim-successors-sys #/ok/c ds))))
  (#:prop prop:dim-successors-sys
    (make-dim-successors-sys-impl-from-dim-plus-int
      ; dim-successors-sys-dim-sys
      (dissectfn (successorless-dim-successors-sys ds) ds)
      ; dim-successors-sys-dim-plus-int
      (fn dss d n
        (mat n 0 (just d)
        #/nothing)))))

(define-imitation-simple-struct (nat-dim-sys?) nat-dim-sys
  'nat-dim-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (fn es nat-dim-sys?)))
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max-of-two
    ; dim-sys-dim/c
    (fn ds natural?)
    ; dim-sys-dim=?
    (fn ds a b #/equal? a b)
    ; dim-sys-dim-zero
    (fn ds 0)
    ; dim-sys-dim-max-of-two
    (fn ds a b #/max a b)))
(define-imitation-simple-struct (nat-dim-successors-sys?)
  nat-dim-successors-sys 'nat-dim-successors-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (fn es nat-dim-successors-sys?)))
  (#:prop prop:dim-successors-sys
    (make-dim-successors-sys-impl-from-dim-plus-int
      ; dim-successors-sys-dim-sys
      (fn dss #/nat-dim-sys)
      ; dim-successors-sys-dim-plus-int
      (fn dss d n
        (w- result (+ d n)
        #/if (< result 0) (nothing)
        #/just result)))))


(define-imitation-simple-struct
  (extended-with-top-dim-finite?
    extended-with-top-dim-finite-original)
  extended-with-top-dim-finite
  'extended-with-top-dim-finite (current-inspector)
  (auto-write)
  (auto-equal))
(define-imitation-simple-struct (extended-with-top-dim-infinite?)
  extended-with-top-dim-infinite
  'extended-with-top-dim-infinite (current-inspector)
  (auto-write)
  (auto-equal))
(define (extended-with-top-dim? v)
  (or
    (extended-with-top-dim-finite? v)
    (extended-with-top-dim-infinite? v)))
(define (extended-with-top-dim/c original-dim/c)
  (w- original-dim/c
    (coerce-contract 'extended-with-top-dim/c original-dim/c)
  #/rename-contract
    (or/c
      (match/c extended-with-top-dim-finite original-dim/c)
      extended-with-top-dim-infinite?)
    `(extended-with-top-dim/c ,(contract-name original-dim/c))))
(define (extended-with-top-dim=? original-dim=? a b)
  (mat a (extended-with-top-dim-finite orig-a)
    (expect b (extended-with-top-dim-finite orig-b) #f
    #/original-dim=? orig-a orig-b)
  #/dissect a (extended-with-top-dim-infinite)
    (expect b (extended-with-top-dim-infinite) #f
      #t)))
(define-imitation-simple-struct
  (extended-with-top-dim-sys? extended-with-top-dim-sys-original)
  unguarded-extended-with-top-dim-sys
  'extended-with-top-dim-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (extended-with-top-dim-sys orig-ds)
        (match/c extended-with-top-dim-sys #/ok/c orig-ds))))
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max-of-two
    ; dim-sys-dim/c
    (dissectfn (extended-with-top-dim-sys orig-ds)
      (extended-with-top-dim/c #/dim-sys-dim/c orig-ds))
    ; dim-sys-dim=?
    (fn ds a b
      (dissect ds (extended-with-top-dim-sys orig-ds)
      #/w- orig-dim=? (fn a b #/dim-sys-dim=? orig-ds a b)
      #/extended-with-top-dim=? orig-dim=? a b))
    ; dim-sys-dim-zero
    (fn ds
      (dissect ds (extended-with-top-dim-sys orig-ds)
      #/extended-with-top-dim-finite #/dim-sys-dim-zero orig-ds))
    ; dim-sys-dim-max-of-two
    (fn ds a b
      (dissect ds (extended-with-top-dim-sys orig-ds)
      #/expect a (extended-with-top-dim-finite orig-a) a
      #/expect b (extended-with-top-dim-finite orig-b) b
      #/extended-with-top-dim-finite
        (dim-sys-dim-max-of-two orig-ds orig-a orig-b)))))
(define-match-expander-attenuated
  attenuated-extended-with-top-dim-sys
  unguarded-extended-with-top-dim-sys
  [original dim-sys?]
  #t)
(define-match-expander-from-match-and-make
  extended-with-top-dim-sys
  unguarded-extended-with-top-dim-sys
  attenuated-extended-with-top-dim-sys
  attenuated-extended-with-top-dim-sys)
(define-imitation-simple-struct
  (extended-with-top-dim-sys-morphism-sys?
    extended-with-top-dim-sys-morphism-sys-original)
  unguarded-extended-with-top-dim-sys-morphism-sys
  'extended-with-top-dim-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (extended-with-top-dim-sys-morphism-sys orig)
        (match/c extended-with-top-dim-sys-morphism-sys
          (ok/c orig)))))
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-source
      (dissectfn (extended-with-top-dim-sys-morphism-sys orig)
        (extended-with-top-dim-sys
          (dim-sys-morphism-sys-source orig)))
      ; dim-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms (extended-with-top-dim-sys-morphism-sys orig)
        #/expect new-s (extended-with-top-dim-sys new-s)
          (w- s
            (extended-with-top-dim-sys
              (dim-sys-morphism-sys-source orig))
          #/raise-arguments-error 'dim-sys-morphism-sys-replace-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/extended-with-top-dim-sys-morphism-sys
          (dim-sys-morphism-sys-replace-source orig new-s)))
      ; dim-sys-morphism-sys-target
      (dissectfn (extended-with-top-dim-sys-morphism-sys orig)
        (extended-with-top-dim-sys
          (dim-sys-morphism-sys-target orig)))
      ; dim-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms (extended-with-top-dim-sys-morphism-sys orig)
        #/expect new-t (extended-with-top-dim-sys new-t)
          (w- t
            (extended-with-top-dim-sys
              (dim-sys-morphism-sys-target orig))
          #/raise-arguments-error 'dim-sys-morphism-sys-replace-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/extended-with-top-dim-sys-morphism-sys
          (dim-sys-morphism-sys-replace-target orig new-t)))
      ; dim-sys-morphism-sys-morph-dim
      (fn ms d
        (dissect ms (extended-with-top-dim-sys-morphism-sys orig)
        #/expect d (extended-with-top-dim-finite d)
          (extended-with-top-dim-infinite)
        #/extended-with-top-dim-finite
          (dim-sys-morphism-sys-morph-dim orig d))))))
(define-match-expander-attenuated
  attenuated-extended-with-top-dim-sys-morphism-sys
  unguarded-extended-with-top-dim-sys-morphism-sys
  [original dim-sys-morphism-sys?]
  #t)
(define-match-expander-from-match-and-make
  extended-with-top-dim-sys-morphism-sys
  unguarded-extended-with-top-dim-sys-morphism-sys
  attenuated-extended-with-top-dim-sys-morphism-sys
  attenuated-extended-with-top-dim-sys-morphism-sys)
(define-imitation-simple-struct
  (extended-with-top-dim-sys-endofunctor-sys?)
  extended-with-top-dim-sys-endofunctor-sys
  'extended-with-top-dim-sys-endofunctor-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (fn es extended-with-top-dim-sys-endofunctor-sys?)))
  (#:prop prop:functor-sys
    (make-dim-sys-endofunctor-sys-impl-from-apply
      (fn es ds #/extended-with-top-dim-sys ds)
      (fn es ms #/extended-with-top-dim-sys-morphism-sys ms))))
(define-imitation-simple-struct
  (extend-with-top-dim-sys-morphism-sys?
    extend-with-top-dim-sys-morphism-sys-source)
  unguarded-extend-with-top-dim-sys-morphism-sys
  'extend-with-top-dim-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (extend-with-top-dim-sys-morphism-sys source)
        (match/c extend-with-top-dim-sys-morphism-sys
          (ok/c source)))))
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-source
      (dissectfn (extend-with-top-dim-sys-morphism-sys source)
        source)
      ; dim-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms (extend-with-top-dim-sys-morphism-sys source)
        #/extend-with-top-dim-sys-morphism-sys new-s))
      ; dim-sys-morphism-sys-target
      (dissectfn (extend-with-top-dim-sys-morphism-sys source)
        (extended-with-top-dim-sys source))
      ; dim-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms (extend-with-top-dim-sys-morphism-sys source)
        #/expect new-t (extended-with-top-dim-sys new-s)
          (w- t (extended-with-top-dim-sys source)
          #/raise-arguments-error 'dim-sys-morphism-sys-replace-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/extend-with-top-dim-sys-morphism-sys new-s))
      ; dim-sys-morphism-sys-morph-dim
      (fn ms d #/extended-with-top-dim-finite d))))
(define-match-expander-attenuated
  attenuated-extend-with-top-dim-sys-morphism-sys
  unguarded-extend-with-top-dim-sys-morphism-sys
  [source dim-sys?]
  #t)
(define-match-expander-from-match-and-make
  extend-with-top-dim-sys-morphism-sys
  unguarded-extend-with-top-dim-sys-morphism-sys
  attenuated-extend-with-top-dim-sys-morphism-sys
  attenuated-extend-with-top-dim-sys-morphism-sys)
(define-imitation-simple-struct
  (extended-with-top-finite-dim-sys?
    extended-with-top-finite-dim-sys-original)
  unguarded-extended-with-top-finite-dim-sys
  'extended-with-top-finite-dim-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (extended-with-top-finite-dim-sys orig-ds)
        (match/c extended-with-top-finite-dim-sys #/ok/c orig-ds))))
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max-of-two
    ; dim-sys-dim/c
    (dissectfn (extended-with-top-finite-dim-sys orig-ds)
      (match/c extended-with-top-dim-finite #/dim-sys-dim/c orig-ds))
    ; dim-sys-dim=?
    (fn ds a b
      (dissect ds (extended-with-top-finite-dim-sys orig-ds)
      #/dissect a (extended-with-top-dim-finite a)
      #/dissect b (extended-with-top-dim-finite b)
      #/dim-sys-dim=? orig-ds a b))
    ; dim-sys-dim-zero
    (fn ds
      (dissect ds (extended-with-top-finite-dim-sys orig-ds)
      #/extended-with-top-dim-finite #/dim-sys-dim-zero orig-ds))
    ; dim-sys-dim-max-of-two
    (fn ds a b
      (dissect ds (extended-with-top-finite-dim-sys orig-ds)
      #/dissect a (extended-with-top-dim-finite orig-a)
      #/dissect b (extended-with-top-dim-finite orig-b)
      #/extended-with-top-dim-finite
        (dim-sys-dim-max-of-two orig-ds orig-a orig-b)))))
(define-match-expander-attenuated
  attenuated-extended-with-top-finite-dim-sys
  unguarded-extended-with-top-finite-dim-sys
  [original dim-sys?]
  #t)
(define-match-expander-from-match-and-make
  extended-with-top-finite-dim-sys
  unguarded-extended-with-top-finite-dim-sys
  attenuated-extended-with-top-finite-dim-sys
  attenuated-extended-with-top-finite-dim-sys)
(define-imitation-simple-struct
  (unextend-with-top-dim-sys-morphism-sys?
    unextend-with-top-dim-sys-morphism-sys-target)
  unguarded-unextend-with-top-dim-sys-morphism-sys
  'unextend-with-top-dim-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (unextend-with-top-dim-sys-morphism-sys target)
        (match/c unextend-with-top-dim-sys-morphism-sys
          (ok/c target)))))
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-source
      (dissectfn (unextend-with-top-dim-sys-morphism-sys target)
        (extended-with-top-finite-dim-sys target))
      ; dim-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms (unextend-with-top-dim-sys-morphism-sys target)
        #/expect new-s (extended-with-top-finite-dim-sys new-t)
          (w- s (extended-with-top-finite-dim-sys target)
          #/raise-arguments-error 'dim-sys-morphism-sys-replace-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/unextend-with-top-dim-sys-morphism-sys new-t))
      ; dim-sys-morphism-sys-target
      (dissectfn (unextend-with-top-dim-sys-morphism-sys target)
        target)
      ; dim-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms (unextend-with-top-dim-sys-morphism-sys target)
        #/unextend-with-top-dim-sys-morphism-sys new-t))
      ; dim-sys-morphism-sys-morph-dim
      (fn ms d
        (dissect d (extended-with-top-dim-finite d)
          d)))))
(define-match-expander-attenuated
  attenuated-unextend-with-top-dim-sys-morphism-sys
  unguarded-unextend-with-top-dim-sys-morphism-sys
  [source dim-sys?]
  #t)
(define-match-expander-from-match-and-make
  unextend-with-top-dim-sys-morphism-sys
  unguarded-unextend-with-top-dim-sys-morphism-sys
  attenuated-unextend-with-top-dim-sys-morphism-sys
  attenuated-unextend-with-top-dim-sys-morphism-sys)
(define-imitation-simple-struct
  (extended-with-top-dim-successors-sys?
    extended-with-top-dim-successors-sys-original)
  unguarded-extended-with-top-dim-successors-sys
  'extended-with-top-dim-successors-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (extended-with-top-dim-successors-sys orig-dss)
        (match/c extended-with-top-dim-successors-sys
          (ok/c orig-dss)))))
  (#:prop prop:dim-successors-sys
    (make-dim-successors-sys-impl-from-dim-plus-int
      ; dim-successors-sys-dim-sys
      (dissectfn (extended-with-top-dim-successors-sys orig-dss)
        (extended-with-top-dim-sys
          (dim-successors-sys-dim-sys orig-dss)))
      ; dim-successors-sys-dim-plus-int
      (fn dss d n
        (dissect dss (extended-with-top-dim-successors-sys orig-dss)
        
        ; If the integer to add is zero, we return the dimension value
        ; unchanged.
        #/mat n 0 (just d)
        
        ; If the given dimension is the new top, it's not related to
        ; any of the others by successor or predecessor relationships.
        #/mat d (extended-with-top-dim-infinite) (nothing)
        
        ; If the given dimension is one of the original ones, we add
        ; the integer in the original way.
        #/dissect d (extended-with-top-dim-finite orig-d)
        #/maybe-map
          (dim-successors-sys-dim-plus-int orig-dss orig-d n)
        #/fn result
          (extended-with-top-dim-finite result))))))
(define-match-expander-attenuated
  attenuated-extended-with-top-dim-successors-sys
  unguarded-extended-with-top-dim-successors-sys
  [original dim-successors-sys?]
  #t)
(define-match-expander-from-match-and-make
  extended-with-top-dim-successors-sys
  unguarded-extended-with-top-dim-successors-sys
  attenuated-extended-with-top-dim-successors-sys
  attenuated-extended-with-top-dim-successors-sys)


; The `fin-multiplied-dim-successors-sys` systems represent a
; dimension number system which imitates an existing one but treats
; each of its dimension numbers as a sequence of `bound` consecutive
; dimension numbers instead. Where there was a successor/predecessor
; relationship in the original number system, the updated number
; system treats the last element of the predecessor's sequence as the
; predecessor of the first element of the successor's sequence. A
; `bound` of zero is not allowed.
;
; If the ordering of the original dimension number system is a
; well-ordering (an ordinal), the ordering of the result
; corresponds to the ordinal obtained by multiplying that one by the
; natural number `bound` *on the left*. (For limit ordinals, this ends
; up being the same ordinal.) That's why we're calling it
; "fin-multiplied" rather than "multiplied-by-fin," and that's why
; we're putting the index on the left in the representation.
;
; Note that the way lexicographic ordering works for that kind of
; ordinal notation is little-endian; the first component only needs to
; be compared if the second component is equal.
;
; NOTE: "Fin" here is short for "finite" and means the type of all
; natural numbers strictly less than some statically known natural
; number. (Strictly speaking, it's an indexed type, and the static
; bound is the index to that type.) "Fin" is a common name for this in
; dependently typed languages like Agda.

(define-imitation-simple-struct
  (fin-multiplied-dim?
    fin-multiplied-dim-index
    fin-multiplied-dim-original)
  unguarded-fin-multiplied-dim 'fin-multiplied-dim (current-inspector)
  (auto-write)
  (auto-equal))
(define-match-expander-attenuated
  attenuated-fin-multiplied-dim
  unguarded-fin-multiplied-dim
  [index natural?]
  [original any/c]
  #t)
(define-match-expander-from-match-and-make
  fin-multiplied-dim
  unguarded-fin-multiplied-dim
  attenuated-fin-multiplied-dim
  attenuated-fin-multiplied-dim)
(define (fin-multiplied-dim/c bound original-dim/c)
  (w- original-dim/c
    (coerce-contract 'fin-multiplied-dim/c original-dim/c)
  #/rename-contract
    (match/c fin-multiplied-dim
      (and/c natural? #/</c bound)
      original-dim/c)
    `(fin-multiplied-dim/c ,bound ,(contract-name original-dim/c))))
(define (fin-multiplied-dim=? original-dim=? a b)
  (dissect a (fin-multiplied-dim a-i a-orig)
  #/dissect b (fin-multiplied-dim b-i b-orig)
  
  ; NOTE: We compare the original dimensions first, not because we
  ; have to right here but because it's consistent with other
  ; lexicographic comparisons we do with this type.
  #/and (original-dim=? a-orig b-orig) (equal? a-i b-i)))
(define-imitation-simple-struct
  (fin-multiplied-dim-sys?
    fin-multiplied-dim-sys-bound
    fin-multiplied-dim-sys-original)
  unguarded-fin-multiplied-dim-sys
  'fin-multiplied-dim-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (fin-multiplied-dim-sys bound orig-ds)
        (match/c fin-multiplied-dim-sys (=/c bound) (ok/c orig-ds)))))
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max-of-two
    ; dim-sys-dim/c
    (dissectfn (fin-multiplied-dim-sys bound orig-ds)
      (fin-multiplied-dim/c bound #/dim-sys-dim/c orig-ds))
    ; dim-sys-dim=?
    (fn ds a b
      (dissect ds (fin-multiplied-dim-sys bound orig-ds)
      #/w- orig-dim=? (fn a b #/dim-sys-dim=? orig-ds a b)
      #/fin-multiplied-dim=? orig-dim=? a b))
    ; dim-sys-dim-zero
    (fn ds
      (dissect ds (fin-multiplied-dim-sys bound orig-ds)
      #/fin-multiplied-dim 0 #/dim-sys-dim-zero orig-ds))
    ; dim-sys-dim-max-of-two
    (fn ds a b
      (dissect ds (fin-multiplied-dim-sys bound orig-ds)
      #/dissect a (fin-multiplied-dim a-i a-orig)
      #/dissect b (fin-multiplied-dim b-i b-orig)
      #/w- max-orig (dim-sys-dim-max-of-two orig-ds a-orig b-orig)
      #/expect (dim-sys-dim=? orig-ds max-orig a-orig) #t
        b
      #/expect (dim-sys-dim=? orig-ds max-orig b-orig) #t
        a
      #/fin-multiplied-dim (max a-i b-i) max-orig))))
(define-match-expander-attenuated
  attenuated-fin-multiplied-dim-sys
  unguarded-fin-multiplied-dim-sys
  [bound exact-positive-integer?]
  [original dim-sys?]
  #t)
(define-match-expander-from-match-and-make
  fin-multiplied-dim-sys
  unguarded-fin-multiplied-dim-sys
  attenuated-fin-multiplied-dim-sys
  attenuated-fin-multiplied-dim-sys)
(define-imitation-simple-struct
  (fin-multiplied-dim-sys-morphism-sys?
    fin-multiplied-dim-sys-morphism-sys-bound
    fin-multiplied-dim-sys-morphism-sys-original)
  unguarded-fin-multiplied-dim-sys-morphism-sys
  'fin-multiplied-dim-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (fin-multiplied-dim-sys-morphism-sys bound orig)
        (match/c fin-multiplied-dim-sys-morphism-sys
          (=/c bound)
          (ok/c orig)))))
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-source
      (dissectfn (fin-multiplied-dim-sys-morphism-sys bound orig)
        (fin-multiplied-dim-sys bound
          (dim-sys-morphism-sys-source orig)))
      ; dim-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms (fin-multiplied-dim-sys-morphism-sys bound orig)
        #/expect new-s (fin-multiplied-dim-sys new-bound new-s-orig)
          (w- s
            (fin-multiplied-dim-sys bound
              (dim-sys-morphism-sys-source orig))
          #/raise-arguments-error 'dim-sys-morphism-sys-replace-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/expect (= bound new-bound) #t
          (w- s
            (fin-multiplied-dim-sys bound
              (dim-sys-morphism-sys-source orig))
          #/raise-arguments-error 'dim-sys-morphism-sys-replace-source
            "tried to replace the source with a source that had a different bound"
            "ms" ms
            "s" s
            "new-s" new-s
            "bound" bound
            "new-bound" new-bound)
        #/fin-multiplied-dim-sys-morphism-sys bound
          (dim-sys-morphism-sys-replace-source orig new-s-orig)))
      ; dim-sys-morphism-sys-target
      (dissectfn (fin-multiplied-dim-sys-morphism-sys bound orig)
        (fin-multiplied-dim-sys bound
          (dim-sys-morphism-sys-target orig)))
      ; dim-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms (fin-multiplied-dim-sys-morphism-sys bound orig)
        #/expect new-t (fin-multiplied-dim-sys new-bound new-t-orig)
          (w- t
            (fin-multiplied-dim-sys bound
              (dim-sys-morphism-sys-target orig))
          #/raise-arguments-error 'dim-sys-morphism-sys-replace-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/expect (= bound new-bound) #t
          (w- t
            (fin-multiplied-dim-sys bound
              (dim-sys-morphism-sys-target orig))
          #/raise-arguments-error 'dim-sys-morphism-sys-replace-target
            "tried to replace the target with a target that had a different bound"
            "ms" ms
            "t" t
            "new-t" new-t
            "bound" bound
            "new-bound" new-bound)
        #/fin-multiplied-dim-sys-morphism-sys bound
          (dim-sys-morphism-sys-replace-target orig new-t-orig)))
      ; dim-sys-morphism-sys-morph-dim
      (fn ms d
        (dissect ms (fin-multiplied-dim-sys-morphism-sys bound orig)
        #/dissect d (fin-multiplied-dim i d)
        #/fin-multiplied-dim i
          (dim-sys-morphism-sys-morph-dim orig d))))))
(define-match-expander-attenuated
  attenuated-fin-multiplied-dim-sys-morphism-sys
  unguarded-fin-multiplied-dim-sys-morphism-sys
  [bound exact-positive-integer?]
  [original dim-sys-morphism-sys?]
  #t)
(define-match-expander-from-match-and-make
  fin-multiplied-dim-sys-morphism-sys
  unguarded-fin-multiplied-dim-sys-morphism-sys
  attenuated-fin-multiplied-dim-sys-morphism-sys
  attenuated-fin-multiplied-dim-sys-morphism-sys)
(define-imitation-simple-struct
  (fin-multiplied-dim-sys-endofunctor-sys?
    fin-multiplied-dim-sys-endofunctor-sys-bound)
  unguarded-fin-multiplied-dim-sys-endofunctor-sys
  'fin-multiplied-dim-sys-endofunctor-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (fin-multiplied-dim-sys-endofunctor-sys bound)
        (match/c fin-multiplied-dim-sys-endofunctor-sys
          (=/c bound)))))
  (#:prop prop:functor-sys
    (make-dim-sys-endofunctor-sys-impl-from-apply
      (fn es ds
        (dissect es (fin-multiplied-dim-sys-endofunctor-sys bound)
        #/fin-multiplied-dim-sys bound ds))
      (fn es ms
        (dissect es (fin-multiplied-dim-sys-endofunctor-sys bound)
        #/fin-multiplied-dim-sys bound ms)))))
(define-match-expander-attenuated
  attenuated-fin-multiplied-dim-sys-endofunctor-sys
  unguarded-fin-multiplied-dim-sys-endofunctor-sys
  [bound exact-positive-integer?]
  #t)
(define-match-expander-from-match-and-make
  fin-multiplied-dim-sys-endofunctor-sys
  unguarded-fin-multiplied-dim-sys-endofunctor-sys
  attenuated-fin-multiplied-dim-sys-endofunctor-sys
  attenuated-fin-multiplied-dim-sys-endofunctor-sys)
(define-imitation-simple-struct
  (fin-times-dim-sys-morphism-sys?
    fin-times-dim-sys-morphism-sys-bound
    fin-times-dim-sys-morphism-sys-source
    fin-times-dim-sys-morphism-sys-dim-to-index)
  unguarded-fin-times-dim-sys-morphism-sys
  'fin-times-dim-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (fin-times-dim-sys-morphism-sys bound source d->i)
        (match/c fin-times-dim-sys-morphism-sys
          (=/c bound)
          (ok/c source)
          any/c))))
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-source
      (dissectfn (fin-times-dim-sys-morphism-sys bound source d->i)
        source)
      ; dim-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms (fin-times-dim-sys-morphism-sys bound source d->i)
        #/fin-times-dim-sys-morphism-sys bound new-s d->i))
      ; dim-sys-morphism-sys-target
      (dissectfn (fin-times-dim-sys-morphism-sys bound source d->i)
        (fin-multiplied-dim-sys bound source))
      ; dim-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms (fin-times-dim-sys-morphism-sys bound source d->i)
        #/expect new-t (fin-multiplied-dim-sys new-bound new-s)
          (w- t (fin-multiplied-dim-sys bound source)
          #/raise-arguments-error 'dim-sys-morphism-sys-replace-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/expect (= bound new-bound) #t
          (w- t (fin-multiplied-dim-sys bound source)
          #/raise-arguments-error 'dim-sys-morphism-sys-replace-target
            "tried to replace the target with a target that had a different bound"
            "ms" ms
            "t" t
            "new-t" new-t
            "bound" bound
            "new-bound" new-bound)
        #/fin-times-dim-sys-morphism-sys bound new-s d->i))
      ; dim-sys-morphism-sys-morph-dim
      (fn ms d
        (dissect ms (fin-times-dim-sys-morphism-sys bound source d->i)
        #/fin-multiplied-dim (d->i d) d)))))
; TODO: We have a dilemma. The `define/contract` version of
; `attenuated-fin-times-dim-sys-morphism-sys` will give less precise
; source location information in its errors, and it won't catch
; applications with incorrect arity. On the other hand, the
; `define-match-expander-attenuated` version can't express a fully
; precise contract for `dim-to-index`, namely
; `(-> (dim-sys-dim/c source) (and/c natural? #/</c bound))`.
; Dependent contracts would be difficult to make matchers for, but
; perhaps we could implement an alternative to
; `define-match-expander-attenuated` that just defined the
; function-like side and not actually the match expander.
(define attenuated-fin-times-dim-sys-morphism-sys
  (let ()
    (define/contract
      (fin-times-dim-sys-morphism-sys bound source dim-to-index)
      (->i
        (
          [bound exact-positive-integer?]
          [source dim-sys?]
          [dim-to-index (bound source)
            (-> (dim-sys-dim/c source) (and/c natural? #/</c bound))])
        [_ fin-times-dim-sys-morphism-sys?])
      (unguarded-fin-times-dim-sys-morphism-sys
        bound source dim-to-index))
    fin-times-dim-sys-morphism-sys))
#;
(define-match-expander-attenuated
  attenuated-fin-times-dim-sys-morphism-sys
  unguarded-fin-times-dim-sys-morphism-sys
  [bound exact-positive-integer?]
  [source dim-sys?]
  [dim-to-index (-> any/c natural?)]
  #t)
(define-match-expander-from-match-and-make
  fin-times-dim-sys-morphism-sys
  unguarded-fin-times-dim-sys-morphism-sys
  attenuated-fin-times-dim-sys-morphism-sys
  attenuated-fin-times-dim-sys-morphism-sys)
(define-imitation-simple-struct
  (fin-untimes-dim-sys-morphism-sys?
    fin-untimes-dim-sys-morphism-sys-bound
    fin-untimes-dim-sys-morphism-sys-target)
  unguarded-fin-untimes-dim-sys-morphism-sys
  'fin-untimes-dim-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (fin-untimes-dim-sys-morphism-sys bound target)
        (match/c fin-untimes-dim-sys-morphism-sys
          (=/c bound)
          (ok/c target)))))
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-source
      (dissectfn (fin-untimes-dim-sys-morphism-sys bound target)
        (fin-multiplied-dim-sys bound target))
      ; dim-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms (fin-untimes-dim-sys-morphism-sys bound target)
        #/expect new-s (fin-multiplied-dim-sys new-bound new-t)
          (w- s (fin-multiplied-dim-sys bound target)
          #/raise-arguments-error 'dim-sys-morphism-sys-replace-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/expect (= bound new-bound) #t
          (w- s (fin-multiplied-dim-sys bound target)
          #/raise-arguments-error 'dim-sys-morphism-sys-replace-source
            "tried to replace the source with a source that had a different bound"
            "ms" ms
            "s" s
            "new-s" new-s
            "bound" bound
            "new-bound" new-bound)
        #/fin-untimes-dim-sys-morphism-sys bound new-t))
      ; dim-sys-morphism-sys-target
      (dissectfn (fin-untimes-dim-sys-morphism-sys bound target)
        target)
      ; dim-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms (fin-untimes-dim-sys-morphism-sys bound target)
        #/fin-untimes-dim-sys-morphism-sys bound new-t))
      ; dim-sys-morphism-sys-morph-dim
      (fn ms d
        (dissect d (fin-multiplied-dim i d)
          d)))))
(define-match-expander-attenuated
  attenuated-fin-untimes-dim-sys-morphism-sys
  unguarded-fin-untimes-dim-sys-morphism-sys
  [bound exact-positive-integer?]
  [target dim-sys?]
  #t)
(define-match-expander-from-match-and-make
  fin-untimes-dim-sys-morphism-sys
  unguarded-fin-untimes-dim-sys-morphism-sys
  attenuated-fin-untimes-dim-sys-morphism-sys
  attenuated-fin-untimes-dim-sys-morphism-sys)
(define-imitation-simple-struct
  (fin-multiplied-dim-successors-sys?
    fin-multiplied-dim-successors-sys-bound
    fin-multiplied-dim-successors-sys-original)
  unguarded-fin-multiplied-dim-successors-sys
  'fin-multiplied-dim-successors-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (fin-multiplied-dim-successors-sys bound orig-dss)
        (match/c fin-multiplied-dim-successors-sys
          (=/c bound)
          (ok/c orig-dss)))))
  (#:prop prop:dim-successors-sys
    (make-dim-successors-sys-impl-from-dim-plus-int
      ; dim-successors-sys-dim-sys
      (dissectfn (fin-multiplied-dim-successors-sys bound orig-dss)
        (fin-multiplied-dim-sys bound
          (dim-successors-sys-dim-sys orig-dss)))
      ; dim-successors-sys-dim-plus-int
      (fn dss d n
        (dissect dss
          (fin-multiplied-dim-successors-sys bound orig-dss)
        
        ; If the integer to add is zero, we return the dimension value
        ; unchanged.
        #/mat n 0 (just d)
        
        ; Otherwise, first we combine the integer to add with the
        ; integer index of this dimension number. Then we divide that
        ; number by the `bound` to figure out what integer to add
        ; according to the original dimension successors system.
        #/dissect d (fin-multiplied-dim i orig-d)
        #/let-values
          ([(n-to-add-to-orig i) (quotient/remainder (+ i n) bound)])
        #/maybe-map
          (dim-successors-sys-dim-plus-int
            orig-dss orig-d n-to-add-to-orig)
        #/fn orig-result
          (fin-multiplied-dim i orig-result))))))
(define-match-expander-attenuated
  attenuated-fin-multiplied-dim-successors-sys
  unguarded-fin-multiplied-dim-successors-sys
  [bound exact-positive-integer?]
  [original dim-successors-sys?]
  #t)
(define-match-expander-from-match-and-make
  fin-multiplied-dim-successors-sys
  unguarded-fin-multiplied-dim-successors-sys
  attenuated-fin-multiplied-dim-successors-sys
  attenuated-fin-multiplied-dim-successors-sys)
