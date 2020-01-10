#lang parendown racket/base

; punctaffy/hypersnippet/dim
;
; Interfaces to represent numbers that represent the dimensionality of
; hypersnippets.

;   Copyright 2019 The Lathe Authors
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
  -> ->i </c =/c and/c any/c contract? contract-name contract-out
  listof or/c rename-contract)
(require #/only-in racket/contract/combinator
  blame-add-context coerce-contract contract-first-order-passes?
  make-contract)
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
(require #/only-in lathe-morphisms/in-fp/mediary/set
  make-atomic-set-element-sys-impl-from-contract ok/c
  prop:atomic-set-element-sys)

; TODO: Document all of these exports.
(provide #/contract-out
  
  [dim-sys? (-> any/c boolean?)]
  [dim-sys-impl? (-> any/c boolean?)]
  [dim-sys-dim/c (-> dim-sys? contract?)]
  [dim-sys-dim-max
    (->i ([ds dim-sys?])
      #:rest [args (ds) (listof #/dim-sys-dim/c ds)]
      [_ (ds) (dim-sys-dim/c ds)])]
  [dim-sys-dim-zero (->i ([ds dim-sys?]) [_ (ds) (dim-sys-dim/c ds)])]
  [dim-sys-dim=?
    (->i
      (
        [ds dim-sys?]
        [a (ds) (dim-sys-dim/c ds)]
        [b (ds) (dim-sys-dim/c ds)])
      [_ boolean?])]
  [dim-sys-dim<=?
    (->i
      (
        [ds dim-sys?]
        [a (ds) (dim-sys-dim/c ds)]
        [b (ds) (dim-sys-dim/c ds)])
      [_ boolean?])]
  [dim-sys-dim<?
    (->i
      (
        [ds dim-sys?]
        [a (ds) (dim-sys-dim/c ds)]
        [b (ds) (dim-sys-dim/c ds)])
      [_ boolean?])]
  [dim-sys-dim</c
    (->i ([ds dim-sys?] [bound (ds) (dim-sys-dim/c ds)])
      [_ contract?])]
  [dim-sys-dim=/c
    (->i ([ds dim-sys?] [bound (ds) (dim-sys-dim/c ds)])
      [_ contract?])]
  [dim-sys-dim=0?
    (->i ([ds dim-sys?] [d (ds) (dim-sys-dim/c ds)]) [_ boolean?])]
  [dim-sys-0<dim/c (-> dim-sys? contract?)]
  [prop:dim-sys (struct-type-property/c dim-sys-impl?)]
  [make-dim-sys-impl-from-max
    (->
      (-> dim-sys? contract?)
      (->i
        (
          [ds dim-sys?]
          [a (ds) (dim-sys-dim/c ds)]
          [b (ds) (dim-sys-dim/c ds)])
        [_ boolean?])
      (->i ([ds dim-sys?] [lsts (ds) (listof #/dim-sys-dim/c ds)])
        [_ (ds) (dim-sys-dim/c ds)])
      dim-sys-impl?)]
  
  [dim-sys-morphism-sys? (-> any/c boolean?)]
  [dim-sys-morphism-sys-impl? (-> any/c boolean?)]
  [dim-sys-morphism-sys-accepts/c
    (-> dim-sys-morphism-sys? contract?)]
  [dim-sys-morphism-sys-source (-> dim-sys-morphism-sys? dim-sys?)]
  [dim-sys-morphism-sys-put-source
    (-> dim-sys-morphism-sys? dim-sys? dim-sys-morphism-sys?)]
  [dim-sys-morphism-sys-target (-> dim-sys-morphism-sys? dim-sys?)]
  [dim-sys-morphism-sys-put-target
    (-> dim-sys-morphism-sys? dim-sys? dim-sys-morphism-sys?)]
  [dim-sys-morphism-sys-morph-dim
    (->i
      (
        [ms dim-sys-morphism-sys?]
        [d (ms) (dim-sys-dim/c #/dim-sys-morphism-sys-source ms)])
      [_ (ms) (dim-sys-dim/c #/dim-sys-morphism-sys-target ms)])]
  [dim-sys-morphism-sys/c (-> contract? contract? contract?)]
  [prop:dim-sys-morphism-sys
    (struct-type-property/c dim-sys-morphism-sys-impl?)]
  [make-dim-sys-morphism-sys-impl-from-morph
    (->
      (-> dim-sys-morphism-sys? contract?)
      (-> dim-sys-morphism-sys? dim-sys?)
      (-> dim-sys-morphism-sys? dim-sys? dim-sys-morphism-sys?)
      (-> dim-sys-morphism-sys? dim-sys?)
      (-> dim-sys-morphism-sys? dim-sys? dim-sys-morphism-sys?)
      (->i
        (
          [ms dim-sys-morphism-sys?]
          [d (ms) (dim-sys-dim/c #/dim-sys-morphism-sys-source ms)])
        [_ (ms) (dim-sys-dim/c #/dim-sys-morphism-sys-target ms)])
      dim-sys-morphism-sys-impl?)]
  [dim-sys-morphism-sys-identity (-> dim-sys? dim-sys-morphism-sys?)]
  [dim-sys-morphism-sys-chain-two
    (->i
      (
        [a dim-sys-morphism-sys?]
        [b (a)
          (dim-sys-morphism-sys/c
            (ok/c #/dim-sys-morphism-sys-target a)
            any/c)])
      [_ (a b)
        (dim-sys-morphism-sys/c
          (ok/c #/dim-sys-morphism-sys-source a)
          (ok/c #/dim-sys-morphism-sys-target b))])]
  
  [dim-sys-endofunctor-sys? (-> any/c boolean?)]
  [dim-sys-endofunctor-sys-impl? (-> any/c boolean?)]
  [dim-sys-endofunctor-sys-accepts/c
    (-> dim-sys-endofunctor-sys? contract?)]
  [dim-sys-endofunctor-sys-morph-dim-sys
    (-> dim-sys-endofunctor-sys? dim-sys? dim-sys?)]
  [dim-sys-endofunctor-sys-morph-dim-sys-morphism-sys
    (->i
      (
        [es dim-sys-endofunctor-sys?]
        [ms dim-sys-morphism-sys?])
      [_ (ms)
        (dim-sys-morphism-sys/c
          (ok/c
            (dim-sys-endofunctor-sys-morph-dim-sys
              (dim-sys-morphism-sys-source ms)))
          (ok/c
            (dim-sys-endofunctor-sys-morph-dim-sys
              (dim-sys-morphism-sys-target ms))))])]
  [prop:dim-sys-endofunctor-sys
    (struct-type-property/c dim-sys-endofunctor-sys-impl?)]
  [make-dim-sys-endofunctor-sys-impl-from-morph
    (->
      (-> dim-sys-endofunctor-sys? contract?)
      (-> dim-sys-endofunctor-sys? dim-sys? dim-sys?)
      (->i
        (
          [es dim-sys-endofunctor-sys?]
          [ms dim-sys-morphism-sys?])
        [_ (ms)
          (dim-sys-morphism-sys/c
            (ok/c
              (dim-sys-endofunctor-sys-morph-dim-sys
                (dim-sys-morphism-sys-source ms)))
            (ok/c
              (dim-sys-endofunctor-sys-morph-dim-sys
                (dim-sys-morphism-sys-target ms))))])
      dim-sys-endofunctor-sys-impl?)]
  
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

; TODO: Document and uncomment the `successorless-...` exports if we
; ever need them.
;(provide successorless-dim-successors-sys)
;(provide #/contract-out
;  [successorless-dim-successors-sys? (-> any/c boolean?)])
(provide
  nat-dim-sys)
(provide #/contract-out
  [nat-dim-sys? (-> any/c boolean?)])
(provide
  nat-dim-successors-sys)
(provide #/contract-out
  [nat-dim-successors-sys? (-> any/c boolean?)])
(provide
  extended-with-top-dim-finite)
(provide #/contract-out
  [extended-with-top-dim-finite? (-> any/c boolean?)]
  [extended-with-top-dim-finite-original
    (-> extended-with-top-dim-finite? any/c)])
(provide
  extended-with-top-dim-infinite)
(provide #/contract-out
  [extended-with-top-dim-infinite? (-> any/c boolean?)])
(provide #/contract-out
  [extended-with-top-dim? (-> any/c boolean?)]
  [extended-with-top-dim/c (-> contract? contract?)]
  [extended-with-top-dim=?
    (-> (-> any/c any/c boolean?) any/c any/c boolean?)])
(provide
  extended-with-top-dim-sys)
(provide #/contract-out
  [extended-with-top-dim-sys? (-> any/c boolean?)]
  [extended-with-top-dim-sys-original
    (-> extended-with-top-dim-sys? dim-sys?)])
(provide
  extended-with-top-dim-sys-morphism-sys)
(provide #/contract-out
  [extended-with-top-dim-sys-morphism-sys? (-> any/c boolean?)]
  [extended-with-top-dim-sys-morphism-sys-original
    (-> extended-with-top-dim-sys-morphism-sys?
      dim-sys-morphism-sys?)])
(provide
  extended-with-top-dim-sys-endofunctor-sys)
(provide #/contract-out
  [extended-with-top-dim-sys-endofunctor-sys? (-> any/c boolean?)])
(provide
  extend-with-top-dim-sys-morphism-sys)
(provide #/contract-out
  [extend-with-top-dim-sys-morphism-sys? (-> any/c boolean?)]
  [extend-with-top-dim-sys-morphism-sys-source
    (-> extend-with-top-dim-sys-morphism-sys? dim-sys?)])
(provide
  extended-with-top-finite-dim-sys)
(provide #/contract-out
  [extended-with-top-finite-dim-sys? (-> any/c boolean?)]
  [extended-with-top-finite-dim-sys-original
    (-> extended-with-top-finite-dim-sys? dim-sys?)])
(provide
  unextend-with-top-dim-sys-morphism-sys)
(provide #/contract-out
  [unextend-with-top-dim-sys-morphism-sys? (-> any/c boolean?)]
  [unextend-with-top-dim-sys-morphism-sys-target
    (-> unextend-with-top-dim-sys-morphism-sys? dim-sys?)])
(provide
  extended-with-top-dim-successors-sys)
(provide #/contract-out
  [extended-with-top-dim-successors-sys? (-> any/c boolean?)]
  [extended-with-top-dim-successors-sys-original
    (-> extended-with-top-dim-successors-sys? dim-successors-sys?)])
(provide
  fin-multiplied-dim)
(provide #/contract-out
  [fin-multiplied-dim? (-> any/c boolean?)]
  [fin-multiplied-dim-index (-> fin-multiplied-dim? natural?)]
  [fin-multiplied-dim-original (-> fin-multiplied-dim? any/c)]
  [fin-multiplied-dim/c
    (-> exact-positive-integer? contract? contract?)]
  [fin-multiplied-dim=?
    (-> (-> any/c any/c boolean?) any/c any/c boolean?)])
(provide
  fin-multiplied-dim-sys)
(provide #/contract-out
  [fin-multiplied-dim-sys? (-> any/c boolean?)]
  [fin-multiplied-dim-sys-bound
    (-> fin-multiplied-dim-sys? exact-positive-integer?)]
  [fin-multiplied-dim-sys-original
    (-> fin-multiplied-dim-sys? dim-sys?)])
(provide
  fin-multiplied-dim-sys-morphism-sys)
(provide #/contract-out
  [fin-multiplied-dim-sys-morphism-sys? (-> any/c boolean?)]
  [fin-multiplied-dim-sys-morphism-sys-bound
    (-> fin-multiplied-dim-sys-morphism-sys? exact-positive-integer?)]
  [fin-multiplied-dim-sys-morphism-sys-original
    (-> fin-multiplied-dim-sys-morphism-sys?
      dim-sys-morphism-sys?)])
(provide
  fin-multiplied-dim-sys-endofunctor-sys)
(provide #/contract-out
  [fin-multiplied-dim-sys-endofunctor-sys? (-> any/c boolean?)]
  [fin-multiplied-dim-sys-endofunctor-sys-bound
    (-> fin-multiplied-dim-sys-endofunctor-sys?
      exact-positive-integer?)])
(provide
  fin-times-dim-sys-morphism-sys)
(provide #/contract-out
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
  fin-multiplied-dim-successors-sys)
(provide #/contract-out
  [fin-multiplied-dim-successors-sys? (-> any/c boolean?)]
  [fin-multiplied-dim-successors-sys-bound
    (-> fin-multiplied-dim-successors-sys? exact-positive-integer?)]
  [fin-multiplied-dim-successors-sys-original
    (-> fin-multiplied-dim-successors-sys? dim-successors-sys?)])


(define-imitation-simple-generics dim-sys? dim-sys-impl?
  (#:method dim-sys-dim/c (#:this))
  (#:method dim-sys-dim=? (#:this) () ())
  (#:method dim-sys-dim-max-of-list (#:this) ())
  prop:dim-sys make-dim-sys-impl-from-max
  'dim-sys 'dim-sys-impl (list))

(define (dim-sys-dim-max ds . args)
  (dim-sys-dim-max-of-list ds args))

(define (dim-sys-dim-zero ds)
  (dim-sys-dim-max ds))

(define (dim-sys-dim<=? ds a b)
  (dim-sys-dim=? ds b #/dim-sys-dim-max ds a b))

(define (dim-sys-dim<? ds a b)
  (and (not #/dim-sys-dim=? ds a b) (dim-sys-dim<=? ds a b)))

(define (dim-sys-dim</c ds bound)
  (rename-contract (fn v #/dim-sys-dim<? ds v bound)
    `(dim-sys-dim</c ,ds ,bound)))

(define (dim-sys-dim=/c ds bound)
  (rename-contract (fn v #/dim-sys-dim=? ds v bound)
    `(dim-sys-dim=/c ,ds ,bound)))

(define (dim-sys-dim=0? ds d)
  (dim-sys-dim=? ds (dim-sys-dim-zero ds) d))

(define (dim-sys-0<dim/c ds)
  (rename-contract
    (and/c (dim-sys-dim/c ds) (fn v #/not #/dim-sys-dim=0? ds v))
    `(dim-sys-0<dim/c ,ds)))


(define-imitation-simple-generics
  dim-sys-morphism-sys? dim-sys-morphism-sys-impl?
  (#:method dim-sys-morphism-sys-accepts/c (#:this))
  (#:method dim-sys-morphism-sys-source (#:this))
  (#:method dim-sys-morphism-sys-put-source (#:this) ())
  (#:method dim-sys-morphism-sys-target (#:this))
  (#:method dim-sys-morphism-sys-put-target (#:this) ())
  (#:method dim-sys-morphism-sys-morph-dim (#:this) ())
  prop:dim-sys-morphism-sys make-dim-sys-morphism-sys-impl-from-morph
  'dim-sys-morphism-sys 'dim-sys-morphism-sys-impl (list))

(define (dim-sys-morphism-sys/c source/c target/c)
  (w- source/c (coerce-contract 'dim-sys-morphism-sys/c source/c)
  #/w- target/c (coerce-contract 'dim-sys-morphism-sys/c target/c)
  #/w- name
    `(dim-sys-morphism-sys/c
       ,(contract-name source/c)
       ,(contract-name target/c))
  #/w- first-order
    (fn v
      (and
        (dim-sys-morphism-sys? v)
        (contract-first-order-passes? source/c
          (dim-sys-morphism-sys-source v))
        (contract-first-order-passes? target/c
          (dim-sys-morphism-sys-target v))))
  #/make-contract #:name name #:first-order first-order
    
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
        (w- v
          (dim-sys-morphism-sys-put-source v
            (source/c-projection (dim-sys-morphism-sys-source v)
              missing-party))
        #/w- v
          (dim-sys-morphism-sys-put-target v
            (target/c-projection (dim-sys-morphism-sys-target v)
              missing-party))
          v)))))

(define-imitation-simple-struct
  (identity-dim-sys-morphism-sys?
    identity-dim-sys-morphism-sys-endpoint)
  identity-dim-sys-morphism-sys
  'identity-dim-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-accepts/c
      (dissectfn (identity-dim-sys-morphism-sys e)
        (match/c identity-dim-sys-morphism-sys #/ok/c e))
      ; dim-sys-morphism-sys-source
      (dissectfn (identity-dim-sys-morphism-sys e) e)
      ; dim-sys-morphism-sys-put-source
      (fn ms new-s #/identity-dim-sys-morphism-sys new-s)
      ; dim-sys-morphism-sys-target
      (dissectfn (identity-dim-sys-morphism-sys e) e)
      ; dim-sys-morphism-sys-put-target
      (fn ms new-t #/identity-dim-sys-morphism-sys new-t)
      ; dim-sys-morphism-sys-morph-dim
      (fn ms d d))))

(define (dim-sys-morphism-sys-identity endpoint)
  (identity-dim-sys-morphism-sys endpoint))

(define-imitation-simple-struct
  (chain-two-dim-sys-morphism-sys?
    chain-two-dim-sys-morphism-sys-first
    chain-two-dim-sys-morphism-sys-second)
  chain-two-dim-sys-morphism-sys
  'chain-two-dim-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-accepts/c
      (dissectfn (chain-two-dim-sys-morphism-sys a b)
        (match/c chain-two-dim-sys-morphism-sys
          (dim-sys-morphism-sys-accepts/c a)
          (dim-sys-morphism-sys-accepts/c b)))
      ; dim-sys-morphism-sys-source
      (dissectfn (chain-two-dim-sys-morphism-sys a b)
        (dim-sys-morphism-sys-source a))
      ; dim-sys-morphism-sys-put-source
      (fn ms new-s
        (dissect ms (chain-two-dim-sys-morphism-sys a b)
        #/chain-two-dim-sys-morphism-sys
          (dim-sys-morphism-sys-put-source a new-s)
          b))
      ; dim-sys-morphism-sys-target
      (dissectfn (chain-two-dim-sys-morphism-sys a b)
        (dim-sys-morphism-sys-target b))
      ; dim-sys-morphism-sys-put-target
      (fn ms new-t
        (dissect ms (chain-two-dim-sys-morphism-sys a b)
        #/chain-two-dim-sys-morphism-sys
          a
          (dim-sys-morphism-sys-put-target b new-t)))
      ; dim-sys-morphism-sys-morph-dim
      (fn ms d
        (dissect ms (chain-two-dim-sys-morphism-sys a b)
        #/dim-sys-morphism-sys-morph-dim b
          (dim-sys-morphism-sys-morph-dim a d))))))

(define (dim-sys-morphism-sys-chain-two a b)
  (chain-two-dim-sys-morphism-sys a b))


(define-imitation-simple-generics
  dim-sys-endofunctor-sys? dim-sys-endofunctor-sys-impl?
  (#:method dim-sys-endofunctor-sys-accepts/c (#:this))
  (#:method dim-sys-endofunctor-sys-morph-dim-sys (#:this) ())
  (#:method dim-sys-endofunctor-sys-morph-dim-sys-morphism-sys
    (#:this)
    ())
  prop:dim-sys-endofunctor-sys
  make-dim-sys-endofunctor-sys-impl-from-morph
  'dim-sys-endofunctor-sys 'dim-sys-endofunctor-sys-impl (list))


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
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max
    ; dim-sys-dim/c
    (fn ds natural?)
    ; dim-sys-dim=?
    (fn ds a b #/equal? a b)
    ; dim-sys-dim-max-of-list
    (fn ds lst
      (w-loop next state 0 rest lst
        (expect rest (cons first rest) state
        #/next (max state first) rest)))))
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
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max
    ; dim-sys-dim/c
    (dissectfn (extended-with-top-dim-sys orig-ds)
      (extended-with-top-dim/c #/dim-sys-dim/c orig-ds))
    ; dim-sys-dim=?
    (fn ds a b
      (dissect ds (extended-with-top-dim-sys orig-ds)
      #/w- orig-dim=? (fn a b #/dim-sys-dim=? orig-ds a b)
      #/extended-with-top-dim=? orig-dim=? a b))
    ; dim-sys-dim-max-of-list
    (fn ds lst
      (dissect ds (extended-with-top-dim-sys orig-ds)
      #/w-loop next state (dim-sys-dim-zero orig-ds) rest lst
        (expect rest (cons first rest)
          (extended-with-top-dim-finite state)
        #/mat first (extended-with-top-dim-infinite)
          (extended-with-top-dim-infinite)
        #/dissect first (extended-with-top-dim-finite orig-first)
        #/next (dim-sys-dim-max state orig-first) rest)))))
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
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-accepts/c
      (dissectfn (extended-with-top-dim-sys-morphism-sys orig)
        (match/c extended-with-top-dim-sys-morphism-sys
          (dim-sys-morphism-sys-accepts/c orig)))
      ; dim-sys-morphism-sys-source
      (dissectfn (extended-with-top-dim-sys-morphism-sys orig)
        (extended-with-top-dim-sys
          (dim-sys-morphism-sys-source orig)))
      ; dim-sys-morphism-sys-put-source
      (fn ms new-s
        (dissect ms (extended-with-top-dim-sys-morphism-sys orig)
        #/expect new-s (extended-with-top-dim-sys new-s)
          (w- s
            (extended-with-top-dim-sys
              (dim-sys-morphism-sys-source orig))
          #/raise-arguments-error 'dim-sys-morphism-sys-put-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/extended-with-top-dim-sys-morphism-sys
          (dim-sys-morphism-sys-put-source orig new-s)))
      ; dim-sys-morphism-sys-target
      (dissectfn (extended-with-top-dim-sys-morphism-sys orig)
        (extended-with-top-dim-sys
          (dim-sys-morphism-sys-target orig)))
      ; dim-sys-morphism-sys-put-target
      (fn ms new-t
        (dissect ms (extended-with-top-dim-sys-morphism-sys orig)
        #/expect new-t (extended-with-top-dim-sys new-t)
          (w- t
            (extended-with-top-dim-sys
              (dim-sys-morphism-sys-target orig))
          #/raise-arguments-error 'dim-sys-morphism-sys-put-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/extended-with-top-dim-sys-morphism-sys
          (dim-sys-morphism-sys-put-target orig new-t)))
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
  (#:prop prop:dim-sys-endofunctor-sys
    (make-dim-sys-endofunctor-sys-impl-from-morph
      ; dim-sys-endofunctor-sys-accepts/c
      (fn es extended-with-top-dim-sys-endofunctor-sys?)
      ; dim-sys-endofunctor-sys-morph-dim-sys
      (fn es ds #/extended-with-top-dim-sys ds)
      ; dim-sys-endofunctor-sys-morph-dim-sys-morphism-sys
      (fn es ms #/extended-with-top-dim-sys-morphism-sys ms))))
(define-imitation-simple-struct
  (extend-with-top-dim-sys-morphism-sys?
    extend-with-top-dim-sys-morphism-sys-source)
  unguarded-extend-with-top-dim-sys-morphism-sys
  'extend-with-top-dim-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-accepts/c
      (dissectfn (extend-with-top-dim-sys-morphism-sys source)
        (match/c extend-with-top-dim-sys-morphism-sys #/ok/c source))
      ; dim-sys-morphism-sys-source
      (dissectfn (extend-with-top-dim-sys-morphism-sys source)
        source)
      ; dim-sys-morphism-sys-put-source
      (fn ms new-s
        (dissect ms (extend-with-top-dim-sys-morphism-sys source)
        #/extend-with-top-dim-sys-morphism-sys new-s))
      ; dim-sys-morphism-sys-target
      (dissectfn (extend-with-top-dim-sys-morphism-sys source)
        (extended-with-top-dim-sys source))
      ; dim-sys-morphism-sys-put-target
      (fn ms new-t
        (dissect ms (extend-with-top-dim-sys-morphism-sys source)
        #/expect new-t (extended-with-top-dim-sys new-s)
          (w- t (extended-with-top-dim-sys source)
          #/raise-arguments-error 'dim-sys-morphism-sys-put-target
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
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max
    ; dim-sys-dim/c
    (dissectfn (extended-with-top-finite-dim-sys orig-ds)
      (match/c extended-with-top-dim-finite #/dim-sys-dim/c orig-ds))
    ; dim-sys-dim=?
    (fn ds a b
      (dissect ds (extended-with-top-finite-dim-sys orig-ds)
      #/dissect a (extended-with-top-dim-finite a)
      #/dissect b (extended-with-top-dim-finite b)
      #/dim-sys-dim=? orig-ds a b))
    ; dim-sys-dim-max-of-list
    (fn ds lst
      (dissect ds (extended-with-top-finite-dim-sys orig-ds)
      #/dim-sys-dim-max-of-list orig-ds #/list-map lst
        (dissectfn (extended-with-top-dim-finite d) d)))))
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
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-accepts/c
      (dissectfn (unextend-with-top-dim-sys-morphism-sys target)
        (match/c unextend-with-top-dim-sys-morphism-sys
          (ok/c target)))
      ; dim-sys-morphism-sys-source
      (dissectfn (extend-with-top-dim-sys-morphism-sys target)
        (extended-with-top-finite-dim-sys target))
      ; dim-sys-morphism-sys-put-source
      (fn ms new-s
        (dissect ms (extend-with-top-dim-sys-morphism-sys target)
        #/expect new-s (extended-with-top-finite-dim-sys new-t)
          (w- s (extended-with-top-finite-dim-sys target)
          #/raise-arguments-error 'dim-sys-morphism-sys-put-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/extend-with-top-dim-sys-morphism-sys new-t))
      ; dim-sys-morphism-sys-target
      (dissectfn (extend-with-top-dim-sys-morphism-sys target)
        target)
      ; dim-sys-morphism-sys-put-target
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
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max
    ; dim-sys-dim/c
    (dissectfn (fin-multiplied-dim-sys bound orig-ds)
      (fin-multiplied-dim/c bound #/dim-sys-dim/c orig-ds))
    ; dim-sys-dim=?
    (fn ds a b
      (dissect ds (fin-multiplied-dim-sys bound orig-ds)
      #/w- orig-dim=? (fn a b #/dim-sys-dim=? orig-ds a b)
      #/fin-multiplied-dim=? orig-dim=? a b))
    ; dim-sys-dim-max-of-list
    (fn ds lst
      (dissect ds (fin-multiplied-dim-sys bound orig-ds)
      #/w-loop next
        state (fin-multiplied-dim 0 (dim-sys-dim-zero orig-ds))
        rest lst
        
        (expect rest (cons first rest) state
        #/dissect state (fin-multiplied-dim state-i state-orig)
        #/dissect first (fin-multiplied-dim first-i first-orig)
        #/w- max-orig (dim-sys-dim-max state-orig first-orig)
        #/w- state
          (expect (dim-sys-dim=? max-orig state-orig) #t first
          #/expect (dim-sys-dim=? max-orig first-orig) #t state
          #/fin-multiplied-dim (max state-i first-i) max-orig)
        #/next state rest)))))
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
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-accepts/c
      (dissectfn (fin-multiplied-dim-sys-morphism-sys bound orig)
        (match/c fin-multiplied-dim-sys-morphism-sys
          (=/c bound)
          (dim-sys-morphism-sys-accepts/c orig)))
      ; dim-sys-morphism-sys-source
      (dissectfn (fin-multiplied-dim-sys-morphism-sys bound orig)
        (fin-multiplied-dim-sys bound
          (dim-sys-morphism-sys-source orig)))
      ; dim-sys-morphism-sys-put-source
      (fn ms new-s
        (dissect ms (fin-multiplied-dim-sys-morphism-sys bound orig)
        #/expect new-s (fin-multiplied-dim-sys new-bound new-s-orig)
          (w- s
            (fin-multiplied-dim-sys bound
              (dim-sys-morphism-sys-source orig))
          #/raise-arguments-error 'dim-sys-morphism-sys-put-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/expect (= bound new-bound) #t
          (w- s
            (fin-multiplied-dim-sys bound
              (dim-sys-morphism-sys-source orig))
          #/raise-arguments-error 'dim-sys-morphism-sys-put-source
            "tried to replace the source with a source that had a different bound"
            "ms" ms
            "s" s
            "new-s" new-s
            "bound" bound
            "new-bound" new-bound)
        #/fin-multiplied-dim-sys-morphism-sys bound
          (dim-sys-morphism-sys-put-source orig new-s-orig)))
      ; dim-sys-morphism-sys-target
      (dissectfn (fin-multiplied-dim-sys-morphism-sys bound orig)
        (fin-multiplied-dim-sys bound
          (dim-sys-morphism-sys-target orig)))
      ; dim-sys-morphism-sys-put-target
      (fn ms new-t
        (dissect ms (fin-multiplied-dim-sys-morphism-sys bound orig)
        #/expect new-t (fin-multiplied-dim-sys new-bound new-t-orig)
          (w- t
            (fin-multiplied-dim-sys bound
              (dim-sys-morphism-sys-target orig))
          #/raise-arguments-error 'dim-sys-morphism-sys-put-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/expect (= bound new-bound) #t
          (w- t
            (fin-multiplied-dim-sys bound
              (dim-sys-morphism-sys-target orig))
          #/raise-arguments-error 'dim-sys-morphism-sys-put-target
            "tried to replace the target with a target that had a different bound"
            "ms" ms
            "t" t
            "new-t" new-t
            "bound" bound
            "new-bound" new-bound)
        #/fin-multiplied-dim-sys-morphism-sys bound
          (dim-sys-morphism-sys-put-target orig new-t-orig)))
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
  (#:prop prop:dim-sys-endofunctor-sys
    (make-dim-sys-endofunctor-sys-impl-from-morph
      ; dim-sys-endofunctor-sys-accepts/c
      (dissectfn (fin-multiplied-dim-sys-endofunctor-sys bound)
        (match/c fin-multiplied-dim-sys-endofunctor-sys #/=/c bound))
      ; dim-sys-endofunctor-sys-morph-dim-sys
      (fn es ds
        (dissect es (fin-multiplied-dim-sys-endofunctor-sys bound)
        #/fin-multiplied-dim-sys bound ds))
      ; dim-sys-endofunctor-sys-morph-dim-sys-morphism-sys
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
  (#:prop prop:dim-sys-morphism-sys
    (make-dim-sys-morphism-sys-impl-from-morph
      ; dim-sys-morphism-sys-accepts/c
      (dissectfn (fin-times-dim-sys-morphism-sys bound source d->i)
        (match/c fin-times-dim-sys-morphism-sys
          (=/c bound)
          (ok/c source)
          any/c))
      ; dim-sys-morphism-sys-source
      (dissectfn (fin-times-dim-sys-morphism-sys bound source d->i)
        source)
      ; dim-sys-morphism-sys-put-source
      (fn ms new-s
        (dissect ms (fin-times-dim-sys-morphism-sys bound source d->i)
        #/fin-times-dim-sys-morphism-sys bound new-s d->i))
      ; dim-sys-morphism-sys-target
      (dissectfn (fin-times-dim-sys-morphism-sys bound source d->i)
        (fin-multiplied-dim-sys bound source))
      ; dim-sys-morphism-sys-put-target
      (fn ms new-t
        (dissect ms (fin-times-dim-sys-morphism-sys bound source d->i)
        #/expect new-t (fin-multiplied-dim-sys new-bound new-s)
          (w- t (fin-multiplied-dim-sys bound source)
          #/raise-arguments-error 'dim-sys-morphism-sys-put-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/expect (= bound new-bound) #t
          (w- t (fin-multiplied-dim-sys bound source)
          #/raise-arguments-error 'dim-sys-morphism-sys-put-target
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
