#lang parendown racket/base

; punctaffy/hypersnippet/dim
;
; Data structures to help with traversing a sequence of brackets of
; various degrees to manipulate hypersnippet-shaped data.

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


(require #/only-in racket/contract struct-type-property/c)
(require #/only-in racket/contract/base
  -> ->i and/c any/c contract? contract-out listof or/c
  rename-contract)
(require #/only-in racket/math natural?)

(require #/only-in lathe-comforts expect fn mat w- w-loop)
(require #/only-in lathe-comforts/maybe just maybe/c nothing)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct)

; TODO: Document all of these exports.
(provide #/contract-out
  
  [dim-sys? (-> any/c boolean?)]
  [dim-sys-impl? (-> any/c boolean?)]
  [dim-sys-accepts? (-> dim-sys? dim-sys? boolean?)]
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
  [dim-sys-dim=0?
    (->i ([ds dim-sys?] [d (ds) (dim-sys-dim/c ds)])
      [_ boolean?])]
  [dim-sys-0<dim/c (-> dim-sys? contract?)]
  [prop:dim-sys (struct-type-property/c dim-sys-impl?)]
  [make-dim-sys-impl-from-max
    (->
      (-> dim-sys? contract?)
      (->i ([ds dim-sys?] [lsts (ds) (listof #/dim-sys-dim/c ds)])
        [_ (ds) (dim-sys-dim/c ds)])
      dim-sys-impl?)]
  
  [dim-successors-sys? (-> any/c boolean?)]
  [dim-successors-sys-impl? (-> any/c boolean?)]
  [dim-successors-sys-accepts?
    (-> dim-successors-sys? dim-successors-sys? boolean?)]
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
  omega)
(provide #/contract-out
  [omega? (-> any/c boolean?)])
(provide
  extended-nat-dim-sys)
(provide #/contract-out
  [extended-nat-dim-sys? (-> any/c boolean?)])
(provide
  extended-nat-dim-successors-sys)
(provide #/contract-out
  [extended-nat-dim-successors-sys? (-> any/c boolean?)])


(define-imitation-simple-generics dim-sys? dim-sys-impl?
  (#:method dim-sys-dim/c (#:this))
  (#:method dim-sys-dim-max-of-list (#:this) ())
  prop:dim-sys make-dim-sys-impl-from-max
  'dim-sys 'dim-sys-impl (list))

(define (dim-sys-accepts? ds other)
  (equal? ds other))

(define (dim-sys-dim-max ds . args)
  (dim-sys-dim-max-of-list ds args))

(define (dim-sys-dim-zero ds)
  (dim-sys-dim-max ds))

(define (dim-sys-dim=? ds a b)
  (equal? a b))

(define (dim-sys-dim<=? ds a b)
  (dim-sys-dim=? ds b #/dim-sys-dim-max ds a b))

(define (dim-sys-dim<? ds a b)
  (and (not #/dim-sys-dim=? ds a b) (dim-sys-dim<=? ds a b)))

(define (dim-sys-dim</c ds bound)
  (rename-contract (fn v #/dim-sys-dim<? ds v bound)
    `(dim-sys-dim</c ,ds ,bound)))

(define (dim-sys-dim=0? ds d)
  (dim-sys-dim=? ds (dim-sys-dim-zero ds) d))

(define (dim-sys-0<dim/c ds)
  (rename-contract
    (and/c (dim-sys-dim/c ds) (fn v #/not #/dim-sys-dim=0? ds v))
    `(dim-sys-0<dim/c ,ds)))


(define-imitation-simple-generics
  dim-successors-sys? dim-successors-sys-impl?
  (#:method dim-successors-sys-dim-sys (#:this))
  (#:method dim-successors-sys-dim-plus-int (#:this) () ())
  prop:dim-successors-sys
  make-dim-successors-sys-impl-from-dim-plus-int
  'dim-successors-sys 'dim-successors-sys-impl (list))

(define (dim-successors-sys-accepts? dss other)
  (equal? dss other))

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
  (#:prop prop:dim-successors-sys
    (make-dim-successors-sys-impl-from-dim-plus-int
      (fn dss #/successorless-dim-successors-sys-dim-sys dss)
      (fn dss d n
        (mat n 0 d
        #/nothing)))))

(define-imitation-simple-struct (nat-dim-sys?) nat-dim-sys
  'nat-dim-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max
    (fn ds natural?)
    (fn ds lst
      (w-loop next state 0 rest lst
        (expect rest (cons first rest) state
        #/next (max state first) rest)))))
(define-imitation-simple-struct (nat-dim-successors-sys?)
  nat-dim-successors-sys 'nat-dim-successors-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:dim-successors-sys
    (make-dim-successors-sys-impl-from-dim-plus-int
      (fn dss #/nat-dim-sys)
      (fn dss d n
        (w- result (+ d n)
        #/if (< result 0) (nothing)
        #/just result)))))

; TODO: See if we'll use these.
(define-imitation-simple-struct (omega?) omega
  'omega (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct (extended-nat-dim-sys?)
  extended-nat-dim-sys
  'extended-nat-dim-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max
    (fn ds #/or/c natural? omega?)
    (fn ds lst
      (w-loop next state 0 rest lst
        (expect rest (cons first rest) state
        #/mat first (omega) (omega)
        #/next (max state first) rest)))))
(define-imitation-simple-struct (extended-nat-dim-successors-sys?)
  extended-nat-dim-successors-sys
  'extended-nat-dim-successors-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:dim-successors-sys
    (make-dim-successors-sys-impl-from-dim-plus-int
      (fn dss #/extended-nat-dim-sys)
      (fn dss d n
        (mat n 0 d
        #/mat d (omega) (nothing)
        #/w- result (+ d n)
        #/if (< result 0) (nothing)
        #/just result)))))
