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


(require #/only-in racket/contract struct-type-property/c)
(require #/only-in racket/contract/base
  -> ->i </c and/c any/c contract? contract-name contract-out listof
  or/c rename-contract)
(require #/only-in racket/contract/combinator coerce-contract)
(require #/only-in racket/math natural?)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/match
  define-match-expander-attenuated
  define-match-expander-from-match-and-make match/c)
(require #/only-in lathe-comforts/maybe
  just maybe/c maybe-map nothing)
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

(define (dim-sys-accepts? ds other)
  (equal? ds other))

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
        (mat n 0 (just d)
        #/nothing)))))

(define-imitation-simple-struct (nat-dim-sys?) nat-dim-sys
  'nat-dim-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max
    (fn ds natural?)
    (fn ds a b #/equal? a b)
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


; TODO HYPERNEST-2-FROM-BRACKETS: Use
;
;   (extended-with-top-dim-successors-sys
;     (fin-multiplied-dim-successors-sys 2 orig-dss))
;
; to implement hypernests in `punctaffy/hypernest/snippet`. The
; `fin-multiplied` part ensures bumps can be represented by holes of
; slightly higher degree, and the `extended-with-top` part ensures
; bumps of arbitrarily large size can exist as unselected holes of a
; selective snippet.
;
; Oh yeah, in order for that to work, we'll also need selective
; snippets to use `(extended-with-top-dim-successors-sys orig-dss)`
; themselves so they can contain (arbitrarily large) unselected holes
; of degree larger than their own degree.


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
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max
    (dissectfn (extended-with-top-dim-sys orig-ds)
      (extended-with-top-dim/c #/dim-sys-dim/c orig-ds))
    (fn ds a b
      (dissect ds (extended-with-top-dim-sys orig-ds)
      #/w- orig-dim=? (fn a b #/dim-sys-dim=? orig-ds a b)
      #/extended-with-top-dim=? orig-dim=? a b))
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
  (extended-with-top-dim-successors-sys?
    extended-with-top-dim-successors-sys-original)
  unguarded-extended-with-top-dim-successors-sys
  'extended-with-top-dim-successors-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:dim-successors-sys
    (make-dim-successors-sys-impl-from-dim-plus-int
      (dissectfn (extended-with-top-dim-successors-sys orig-dss)
        (extended-with-top-dim-sys
          (dim-successors-sys-dim-sys orig-dss)))
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
  (#:prop prop:dim-sys #/make-dim-sys-impl-from-max
    (dissectfn (fin-multiplied-dim-sys bound orig-ds)
      (fin-multiplied-dim/c bound #/dim-sys-dim/c orig-ds))
    (fn ds a b
      (dissect ds (fin-multiplied-dim-sys bound orig-ds)
      #/w- orig-dim=? (fn a b #/dim-sys-dim=? orig-ds a b)
      #/fin-multiplied-dim=? orig-dim=? a b))
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
  (fin-multiplied-dim-successors-sys?
    fin-multiplied-dim-successors-sys-bound
    fin-multiplied-dim-successors-sys-original)
  unguarded-fin-multiplied-dim-successors-sys
  'fin-multiplied-dim-successors-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:dim-successors-sys
    (make-dim-successors-sys-impl-from-dim-plus-int
      (dissectfn (fin-multiplied-dim-successors-sys bound orig-dss)
        (fin-multiplied-dim-sys bound
          (dim-successors-sys-dim-sys orig-dss)))
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
