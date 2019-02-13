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


(require #/only-in racket/contract/base
  -> ->i any/c contract? contract-out list/c rename-contract)
(require #/only-in racket/math natural?)

(require #/only-in lathe-comforts dissect dissectfn expect fn w-)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct)
(require #/only-in lathe-comforts/trivial trivial)

(require #/only-in punctaffy/hypersnippet/dim
  dim-sys? dim-sys-accepts? dim-sys-dim<? dim-sys-dim<=? dim-sys-dim/c
  dim-sys-dim</c dim-sys-dim-max dim-sys-dim-zero)

; TODO: If we ever need these exports, document and uncomment them,
; and move them to the `punctaffy/hypersnippet/dim` module. For now,
; dimension-indexed lists are an implementation detail of hyperstacks.
#;
(provide #/contract-out
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
      [_ (ds) (dim-sys-dimlist/c ds)])])

(provide #/contract-out
  
  [hyperstack? (-> any/c boolean?)]
  [hyperstack/c (-> dim-sys? contract?)]
  [hyperstack-dim-sys (-> hyperstack? dim-sys?)]
  [hyperstack-dimension
    (->i ([h hyperstack?])
      [_ (h) (dim-sys-dim/c #/hyperstack-dim-sys h)])]
  [hyperstack-peek
    (->i
      (
        [h hyperstack?]
        [i (h)
          (w- ds (hyperstack-dim-sys h)
          #/dim-sys-dim</c ds #/hyperstack-dimension h)])
      [_ any/c])]
  
  ; TODO: If we ever need these exports, document and uncomment them.
  ; For now, dimension-indexed lists are an implementation detail of
  ; hyperstacks.
  #;
  [make-hyperstack-dimlist
    (->i ([ds dim-sys?] [elems (ds) (dim-sys-dimlist/c ds)])
      [_ (ds) (hyperstack/c ds)])]
  #;
  [hyperstack-push-dimlist
    (->i
      (
        [h hyperstack?]
        [elems-to-push (h)
          (dim-sys-dimlist/c #/hyperstack-dim-sys h)])
      [_ (h) (hyperstack/c #/hyperstack-dim-sys h)])]
  #;
  [hyperstack-pop-dimlist
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
  
  [make-hyperstack
    (->i
      ([ds dim-sys?] [dimension (ds) (dim-sys-dim/c ds)] [elem any/c])
      [_ (ds) (hyperstack/c ds)])]
  [hyperstack-push
    (->i
      (
        [bump-degree (h) (dim-sys-dim/c #/hyperstack-dim-sys h)]
        [h hyperstack?]
        [elem any/c])
      [_ (h) (hyperstack/c #/hyperstack-dim-sys h)])]
  [hyperstack-pop
    (->i
      (
        [i (h)
          (w- ds (hyperstack-dim-sys h)
          #/dim-sys-dim</c ds #/hyperstack-dimension h)]
        [h hyperstack?]
        [elem any/c])
      [_ (h) (list/c any/c (hyperstack/c #/hyperstack-dim-sys h))])]
  [make-hyperstack-trivial
    (->i ([ds dim-sys?] [dimension (ds) (dim-sys-dim/c ds)])
      [_ (ds) (hyperstack/c ds)])]
  [hyperstack-pop-trivial
    (->i
      (
        [i (h)
          (w- ds (hyperstack-dim-sys h)
          #/dim-sys-dim</c ds #/hyperstack-dimension h)]
        [h hyperstack?])
      [_ (h) (hyperstack/c #/hyperstack-dim-sys h)])]
  
  )


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

(define (hyperstack-dimension h)
  (dissect h (hyperstack ds rep)
  #/dim-sys-dimlist-length ds rep))

(define (hyperstack-peek h i)
  (dissect h (hyperstack ds rep)
  #/dissect (dim-sys-dimlist-ref-and-call ds rep i)
    (list elem suspended-chevron)
    elem))


(define (make-hyperstack-dimlist ds elems)
  (hyperstack ds #/dim-sys-dimlist-map ds elems #/fn elem
    (list elem #/dim-sys-dimlist-zero ds)))

(define (hyperstack-push-dimlist h elems-to-push)
  (dissect h (hyperstack ds rep)
  #/hyperstack ds #/dim-sys-dimlist-shadow ds
    (dim-sys-dimlist-zip-map ds
      elems-to-push
      (dim-sys-dimlist-chevrons ds rep)
      (fn elem rep-chevron
        (list elem rep-chevron)))
    rep))

(define (hyperstack-pop-dimlist h elems-to-push)
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


(define (make-hyperstack ds dimension elem)
  (make-hyperstack-dimlist ds
  #/dim-sys-dimlist-uniform ds dimension elem))

(define (hyperstack-push bump-degree h elem)
  (w- ds (hyperstack-dim-sys h)
  #/hyperstack-push-dimlist h
  #/dim-sys-dimlist-uniform ds bump-degree elem))

(define (hyperstack-pop i h elem)
  (w- ds (hyperstack-dim-sys h)
  #/hyperstack-pop-dimlist h #/dim-sys-dimlist-uniform ds i elem))


(define (make-hyperstack-trivial ds dimension)
  (make-hyperstack ds dimension #/trivial))

(define (hyperstack-pop-trivial i h)
  (w- ds (hyperstack-dim-sys h)
  #/dissect (hyperstack-pop i h #/trivial) (list elem rest)
  #/expect elem (trivial)
    (raise-arguments-error 'hyperstack-pop-trivial
      "expected the popped element to be a trivial value"
      "elem" elem)
    rest))
