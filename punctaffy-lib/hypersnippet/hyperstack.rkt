#lang parendown racket/base

; punctaffy/hypersnippet/hyperstack
;
; Data structures to help with traversing a sequence of brackets of
; various degrees to manipulate hypersnippet-shaped data.

;   Copyright 2018, 2019 The Lathe Authors
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
  -> ->i and/c any/c contract? contract-out list/c listof or/c
  rename-contract)
(require #/only-in racket/math natural?)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/maybe just maybe/c nothing)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct)
(require #/only-in lathe-comforts/trivial trivial)

; TODO: Document all of these exports.
(provide #/contract-out
  
  ; TODO: See if the `dym-sys?` utilities should be provided by
  ; another module.
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
  [dim-sys-dimlist/c (-> dim-sys? contract?)]
  [dim-sys-dimlist-build
    (->i
      (
        [ds dim-sys?]
        [length (ds) (dim-sys-dim/c ds)]
        [func (ds) (-> (dim-sys-dim/c ds) any/c)])
      [_ (ds) (dim-sys-dimlist/c ds)])]
  [dim-sys-dimlist-uniform
    (->i ([ds dim-sys?] [length (ds) (dim-sys-dim/c ds)] [elem any/c])
      [_ (ds) (dim-sys-dimlist/c ds)])]
  [dim-sys-dimlist-length
    (->i ([ds dim-sys?] [lst (ds) (dim-sys-dimlist/c ds)])
      [_ (ds) (dim-sys-dim/c ds)])]
  [dim-sys-dimlist-map
    (->i
      (
        [ds dim-sys?]
        [lst (ds) (dim-sys-dimlist/c ds)]
        [v->v (-> any/c any/c)])
      [_ (ds) (dim-sys-dimlist/c ds)])]
  [dim-sys-dimlist-zip-map
    (->i
      (
        [ds dim-sys?]
        [a (ds) (dim-sys-dimlist/c ds)]
        [b (ds) (dim-sys-dimlist/c ds)]
        [func (-> any/c any/c any/c)])
      
      #:pre (ds a b)
      (dim-sys-dim=? ds
        (dim-sys-dimlist-length ds a)
        (dim-sys-dimlist-length ds b))
      
      [_ (ds) (dim-sys-dimlist/c ds)])]
  [dim-sys-dimlist-zero
    (->i ([ds dim-sys?]) [_ (ds) (dim-sys-dimlist/c ds)])]
  [dim-sys-dimlist-chevrons
    ; TODO: See if we should make this contract more specific. The
    ; result value is a dimension-indexed list of dimension-indexed
    ; lists.
    (->i ([ds dim-sys?] [lst (ds) (dim-sys-dimlist/c ds)])
      [_ (ds) (dim-sys-dimlist/c ds)])]
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
        [_ (dss)
          (maybe/c
          #/dim-sys-dim/c #/dim-successors-sys-dim-sys dss)])
      dim-successors-sys-impl?)]
  
  )

(provide successorless-dim-successors-sys)
(provide #/contract-out
  [successorless-dim-successors-sys? (-> any/c boolean?)])
(provide nat-dim-sys)
(provide #/contract-out
  [nat-dim-sys? (-> any/c boolean?)])
(provide nat-dim-successors-sys)
(provide #/contract-out
  [nat-dim-successors-sys? (-> any/c boolean?)])
(provide omega)
(provide #/contract-out
  [omega? (-> any/c boolean?)])
(provide extended-nat-dim-sys)
(provide #/contract-out
  [extended-nat-dim-sys? (-> any/c boolean?)])
(provide extended-nat-dim-successors-sys)
(provide #/contract-out
  [extended-nat-dim-successors-sys? (-> any/c boolean?)])

(provide #/contract-out
  
  [hyperstack? (-> any/c boolean?)]
  [hyperstack/c (-> dim-sys? contract?)]
  [hyperstack-dim-sys (-> hyperstack? dim-sys?)]
  [make-hyperstack
    (->i ([ds dim-sys?] [elems (ds) (dim-sys-dimlist/c ds)])
      [_ (ds) (hyperstack/c ds)])]
  [hyperstack-dimension
    (->i ([h hyperstack?])
      [_ (h) (dim-sys-dim/c #/hyperstack-dim-sys h)])]
  [hyperstack-peek-elem
    (->i
      (
        [h hyperstack?]
        [i (h)
          (w- ds (hyperstack-dim-sys h)
          #/dim-sys-dim</c ds #/hyperstack-dimension h)])
      [_ any/c])]
  [hyperstack-push
    (->i
      (
        [h hyperstack?]
        [elems-to-push (h)
          (dim-sys-dimlist/c #/hyperstack-dim-sys h)])
      [_ (h) (hyperstack/c #/hyperstack-dim-sys h)])]
  [hyperstack-pop
    (->i
      (
        [h hyperstack?]
        [elems-to-push (h)
          (dim-sys-dimlist/c #/hyperstack-dim-sys h)])
      
      #:pre (h elems-to-push)
      (w- ds (hyperstack-dim-sys h)
      #/dim-sys-dim<? ds
        (dim-sys-dimlist-length ds elems-to-push)
        (hyperstack-dimension h))
      
      [_ (h) (list/c any/c (hyperstack/c #/hyperstack-dim-sys h))])]
  
  [make-hyperstack-uniform
    (->i
      ([ds dim-sys?] [dimension (ds) (dim-sys-dim/c ds)] [elem any/c])
      [_ (ds) (hyperstack/c ds)])]
  [make-hyperstack-n
    (->i ([ds dim-sys?] [dimension (ds) (dim-sys-dim/c ds)])
      [_ (ds) (hyperstack/c ds)])]
  [hyperstack-push-uniform
    (->i
      (
        [h hyperstack?]
        [bump-degree (h) (dim-sys-dim/c #/hyperstack-dim-sys h)]
        [elem any/c])
      [_ (h) (hyperstack/c #/hyperstack-dim-sys h)])]
  [hyperstack-pop-uniform
    (->i
      (
        [h hyperstack?]
        [i (h)
          (w- ds (hyperstack-dim-sys h)
          #/dim-sys-dim</c ds #/hyperstack-dimension h)]
        [elem any/c])
      [_ (h) (list/c any/c (hyperstack/c #/hyperstack-dim-sys h))])]
  [hyperstack-pop-n
    (->i
      (
        [h hyperstack?]
        [i (h)
          (w- ds (hyperstack-dim-sys h)
          #/dim-sys-dim</c ds #/hyperstack-dimension h)])
      [_ (h) (hyperstack/c #/hyperstack-dim-sys h)])]
  
  )


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

(define-imitation-simple-struct
  (dimlist? dimlist-dim-sys dimlist-length dimlist-func)
  dimlist 'dimlist (current-inspector) (auto-write))

(define (dim-sys-dimlist? ds v)
  (and (dimlist? v) (dim-sys-accepts? ds #/dimlist-dim-sys v)))

(define (dim-sys-dimlist/c ds)
  (rename-contract (fn v #/dim-sys-dimlist? ds v)
    `(dim-sys-dimlist/c ,ds)))

(define (dim-sys-dimlist-build ds length func)
  (dimlist ds length func))

(define (dim-sys-dimlist-uniform ds length elem)
  (dim-sys-dimlist-build ds length #/dissectfn _ elem))

(define (dim-sys-dimlist-ref-and-call ds lst i)
  (dissect lst (dimlist ds length func)
  #/func i))

(define (dim-sys-dimlist-length ds lst)
  (dimlist-length lst))

(define (dim-sys-dimlist-map ds lst v->v)
  (dissect lst (dimlist ds length func)
  #/dimlist ds length #/fn i #/v->v #/func i))

(define (dim-sys-dimlist-zip-map ds a b func)
  (dissect a (dimlist _ length a-func)
  #/dissect b (dimlist _ _ b-func)
  #/dimlist ds length #/fn i #/func (a-func i) (b-func i)))

(define (dim-sys-dimlist-shadow ds shadower orig)
  (dissect shadower (dimlist _ shadower-length shadower-func)
  #/dissect orig (dimlist _ orig-length orig-func)
  #/if (dim-sys-dim<=? ds orig-length shadower-length) shadower
  #/dimlist ds (dim-sys-dim-max ds orig-length shadower-length) #/fn i
    (if (dim-sys-dim<? ds i shadower-length)
      (shadower-func i)
      (orig-func i))))

(define (dim-sys-dimlist-zero ds)
  (w- zero (dim-sys-dim-zero ds)
  #/dim-sys-dimlist-build ds zero #/fn value-less-than-zero
    (raise-arguments-error 'dim-sys-dimlist-zero-result
      "a dim-sys implementation allowed for a dimension value which was less strictly less than the \"zero\" obtained as the maximum of an empty set of dimension values"
      "zero" zero
      "value-less-than-zero" value-less-than-zero)))

; Given a dimension system and a dimension-indexed list in that
; system, returns a list of the same length where, at each index `i`,
; the value is the original list but possibly with the thunks at
; indexes less than `i` changed.
;
; This means if a list of length `n` goes in, then what comes out is a
; list of length `n` containing lists of length `n`, but each of those
; inner lists has a progressively thinner stripe of indices where it's
; well-defined. Since the indices aren't necessarily totally ordered,
; but merely form a bounded semilattice, the stripe of values less
; than `n` but not less than than `i` would tend to be drawn with a
; chevron chape (a diamond with a diamond cut out of the bottom tip).
;
; NOTE: The behavior we implement here isn't customizable per
; dimension system yet. It just returns lists that are exactly like
; the input list. Someday, for certain dimension systems, customizing
; this behavior may achieve goals related to performance or
; implementation details. For instance, it may allow the values stored
; in those indexes to be reclaimed by the garbage collector, or it may
; eliminate information that would only be distracting during
; debugging.
;
(define (dim-sys-dimlist-chevrons ds lst)
  (dim-sys-dimlist-uniform ds (dim-sys-dimlist-length ds lst) lst))


(define-imitation-simple-generics
  dim-successors-sys? dim-successors-sys-impl?
  (#:method dim-successors-sys-dim-sys (#:this))
  (#:method dim-successors-sys-dim-plus-int (#:this) () ())
  prop:dim-successors-sys
  make-dim-successors-sys-impl-from-dim-plus-int
  'dim-successors-sys 'dim-successors-sys-impl (list))

(define (dim-successors-sys-accepts? dss other)
  (equal? dss other))

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


(define-imitation-simple-struct
  (hyperstack? hyperstack-dim-sys hyperstack-rep)
  hyperstack 'hyperstack (current-inspector) (auto-write))

(define (hyperstack/c ds)
  (rename-contract
    (fn v
      (and
        (hyperstack? v)
        (dim-sys-accepts? ds #/hyperstack-dim-sys v)))
    `(hyperstack/c ,ds)))

(define (make-hyperstack ds elems)
  (hyperstack ds #/dim-sys-dimlist-map ds elems #/fn elem
    (list elem #/dim-sys-dimlist-zero ds)))

(define (hyperstack-dimension h)
  (dissect h (hyperstack ds rep)
  #/dim-sys-dimlist-length ds rep))

(define (hyperstack-peek-elem h i)
  (dissect h (hyperstack ds rep)
  #/dissect (dim-sys-dimlist-ref-and-call ds rep i)
    (list elem suspended-chevron)
    elem))

(define (hyperstack-push h elems-to-push)
  (dissect h (hyperstack ds rep)
  #/hyperstack ds #/dim-sys-dimlist-shadow ds
    (dim-sys-dimlist-zip-map ds
      elems-to-push
      (dim-sys-dimlist-chevrons ds rep)
      (fn elem rep-chevron
        (list elem rep-chevron)))
    rep))

(define (hyperstack-pop h elems-to-push)
  (dissect h (hyperstack ds rep)
  #/w- i (dim-sys-dimlist-length ds elems-to-push)
  #/dissect (dim-sys-dimlist-ref-and-call ds rep i)
    (list elem suspended-chevron)
  #/list elem
    (hyperstack ds #/dim-sys-dimlist-shadow ds
      (dim-sys-dimlist-zip-map ds
        elems-to-push
        (dim-sys-dimlist-chevrons ds rep)
        (fn elem rep-chevron
          (list elem rep-chevron)))
      suspended-chevron)))

(define (make-hyperstack-uniform ds dimension elem)
  (make-hyperstack ds #/dim-sys-dimlist-uniform ds dimension elem))

(define (make-hyperstack-n ds dimension)
  (make-hyperstack-uniform ds dimension #/trivial))

(define (hyperstack-push-uniform h bump-degree elem)
  (w- ds (hyperstack-dim-sys h)
  #/hyperstack-push h #/dim-sys-dimlist-uniform ds bump-degree elem))

(define (hyperstack-pop-uniform h i elem)
  (w- ds (hyperstack-dim-sys h)
  #/hyperstack-pop h #/dim-sys-dimlist-uniform ds i elem))

(define (hyperstack-pop-n h i)
  (w- ds (hyperstack-dim-sys h)
  #/dissect (hyperstack-pop-uniform h i #/trivial) (list elem rest)
    rest))
