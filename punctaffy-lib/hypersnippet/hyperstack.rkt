#lang parendown racket/base

; punctaffy/hypersnippet/hyperstack
;
; Data structures to help with traversing a sequence of brackets of
; various degrees to manipulate hypersnippet-shaped data.

;   Copyright 2018-2020, 2022 The Lathe Authors
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
  -> ->i any/c contract? list/c rename-contract)
(require #/only-in racket/math natural?)

(require #/only-in lathe-comforts dissect dissectfn expect fn w-)
(require #/only-in lathe-comforts/match match/c)
(require #/only-in lathe-comforts/struct
  auto-write define-imitation-simple-struct)
(require #/only-in lathe-comforts/trivial trivial)
(require #/only-in lathe-morphisms/in-fp/mediary/set ok/c)

(require #/only-in punctaffy/hypersnippet/dim
  dim-sys? dim-sys-dim<? dim-sys-dim<=? dim-sys-dim=? dim-sys-dim/c
  dim-sys-dim</c dim-sys-dim-max dim-sys-dim-zero)

(require punctaffy/private/shim)
(init-shim)


; TODO: If we ever need these exports, document and uncomment them,
; and move them to the `punctaffy/hypersnippet/dim` module. For now,
; dimension-indexed lists are an implementation detail of hyperstacks.
#;
(provide #/own-contract-out
  dim-sys-dimlist/c
  dim-sys-dimlist-build
  dim-sys-dimlist-uniform
  dim-sys-dimlist-length
  dim-sys-dimlist-map
  dim-sys-dimlist-zip-map
  dim-sys-dimlist-zero
  dim-sys-dimlist-chevrons)

(provide #/own-contract-out
  
  hyperstack?
  hyperstack/c
  hyperstack-dim-sys
  hyperstack-dimension
  hyperstack-peek
  
  ; TODO: If we ever need these exports, document and uncomment them.
  ; For now, dimension-indexed lists are an implementation detail of
  ; hyperstacks.
  #;
  make-hyperstack-dimlist
  #;
  hyperstack-push-dimlist
  #;
  hyperstack-pop-dimlist
  
  make-hyperstack
  hyperstack-push
  hyperstack-pop
  make-hyperstack-trivial
  hyperstack-pop-trivial
  
  )


(define-imitation-simple-struct
  (dimlist? dimlist-dim-sys dimlist-length dimlist-func)
  dimlist 'dimlist (current-inspector) (auto-write))

(define/own-contract (dim-sys-dimlist/c ds)
  (-> dim-sys? contract?)
  (rename-contract (match/c dimlist (ok/c ds) any/c any/c)
    `(dim-sys-dimlist/c ,ds)))

(define/own-contract (dim-sys-dimlist-build ds length func)
  (->i
    (
      [ds dim-sys?]
      [length (ds) (dim-sys-dim/c ds)]
      [func (ds) (-> (dim-sys-dim/c ds) any/c)])
    [_ (ds) (dim-sys-dimlist/c ds)])
  (dimlist ds length func))

(define/own-contract (dim-sys-dimlist-uniform ds length elem)
  (->i ([ds dim-sys?] [length (ds) (dim-sys-dim/c ds)] [elem any/c])
    [_ (ds) (dim-sys-dimlist/c ds)])
  (dim-sys-dimlist-build ds length #/dissectfn _ elem))

(define (dim-sys-dimlist-ref-and-call ds lst i)
  (dissect lst (dimlist ds length func)
  #/func i))

(define/own-contract (dim-sys-dimlist-length ds lst)
  (->i ([ds dim-sys?] [lst (ds) (dim-sys-dimlist/c ds)])
    [_ (ds) (dim-sys-dim/c ds)])
  (dimlist-length lst))

(define/own-contract (dim-sys-dimlist-map ds lst v->v)
  (->i
    (
      [ds dim-sys?]
      [lst (ds) (dim-sys-dimlist/c ds)]
      [v->v (-> any/c any/c)])
    [_ (ds) (dim-sys-dimlist/c ds)])
  (dissect lst (dimlist ds length func)
  #/dimlist ds length #/fn i #/v->v #/func i))

(define/own-contract (dim-sys-dimlist-zip-map ds a b func)
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
    
    [_ (ds) (dim-sys-dimlist/c ds)])
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

(define/own-contract (dim-sys-dimlist-zero ds)
  (->i ([ds dim-sys?]) [_ (ds) (dim-sys-dimlist/c ds)])
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
(define/own-contract (dim-sys-dimlist-chevrons ds lst)
  ; TODO SPECIFIC: See if we should make this contract more specific.
  ; The result value is a dimension-indexed list of dimension-indexed
  ; lists.
  (->i ([ds dim-sys?] [lst (ds) (dim-sys-dimlist/c ds)])
    [_ (ds) (dim-sys-dimlist/c ds)])
  (dim-sys-dimlist-uniform ds (dim-sys-dimlist-length ds lst) lst))


(define-imitation-simple-struct
  (hyperstack? hyperstack-dim-sys hyperstack-rep)
  hyperstack 'hyperstack (current-inspector) (auto-write))
(ascribe-own-contract hyperstack? (-> any/c boolean?))
(ascribe-own-contract hyperstack-dim-sys (-> hyperstack? dim-sys?))

(define/own-contract (hyperstack/c ds)
  (-> dim-sys? contract?)
  (rename-contract (match/c hyperstack (ok/c ds) any/c)
    `(hyperstack/c ,ds)))

(define/own-contract (hyperstack-dimension stack)
  (->i ([stack hyperstack?])
    [_ (stack) (dim-sys-dim/c #/hyperstack-dim-sys stack)])
  (dissect stack (hyperstack ds rep)
  #/dim-sys-dimlist-length ds rep))

(define/own-contract (hyperstack-peek stack i)
  (->i
    (
      [stack hyperstack?]
      [i (stack)
        (w- ds (hyperstack-dim-sys stack)
        #/dim-sys-dim</c ds #/hyperstack-dimension stack)])
    [_ any/c])
  (dissect stack (hyperstack ds rep)
  #/dissect (dim-sys-dimlist-ref-and-call ds rep i)
    (list elem suspended-chevron)
    elem))


(define/own-contract (make-hyperstack-dimlist ds elems)
  (->i ([ds dim-sys?] [elems (ds) (dim-sys-dimlist/c ds)])
    [_ (ds) (hyperstack/c ds)])
  (hyperstack ds #/dim-sys-dimlist-map ds elems #/fn elem
    (list elem #/dim-sys-dimlist-zero ds)))

(define/own-contract (hyperstack-push-dimlist stack elems-to-push)
  (->i
    (
      [stack hyperstack?]
      [elems-to-push (stack)
        (dim-sys-dimlist/c #/hyperstack-dim-sys stack)])
    [_ (stack) (hyperstack/c #/hyperstack-dim-sys stack)])
  (dissect stack (hyperstack ds rep)
  #/hyperstack ds #/dim-sys-dimlist-shadow ds
    (dim-sys-dimlist-zip-map ds
      elems-to-push
      (dim-sys-dimlist-chevrons ds rep)
      (fn elem rep-chevron
        (list elem rep-chevron)))
    rep))

(define/own-contract (hyperstack-pop-dimlist stack elems-to-push)
  (->i
    (
      [stack hyperstack?]
      [elems-to-push (stack)
        (dim-sys-dimlist/c #/hyperstack-dim-sys stack)])
    
    #:pre (stack elems-to-push)
    (w- ds (hyperstack-dim-sys stack)
    #/dim-sys-dim<? ds
      (dim-sys-dimlist-length ds elems-to-push)
      (hyperstack-dimension stack))
    
    [_ (stack)
      (list/c any/c (hyperstack/c #/hyperstack-dim-sys stack))])
  (dissect stack (hyperstack ds rep)
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


(define/own-contract (make-hyperstack ds dimension elem)
  (->i
    ([ds dim-sys?] [dimension (ds) (dim-sys-dim/c ds)] [elem any/c])
    [_ (ds) (hyperstack/c ds)])
  (make-hyperstack-dimlist ds
  #/dim-sys-dimlist-uniform ds dimension elem))

(define/own-contract (hyperstack-push bump-degree stack elem)
  (->i
    (
      [bump-degree (stack) (dim-sys-dim/c #/hyperstack-dim-sys stack)]
      [stack hyperstack?]
      [elem any/c])
    [_ (stack) (hyperstack/c #/hyperstack-dim-sys stack)])
  (w- ds (hyperstack-dim-sys stack)
  #/hyperstack-push-dimlist stack
  #/dim-sys-dimlist-uniform ds bump-degree elem))

(define/own-contract (hyperstack-pop i stack elem)
  (->i
    (
      [i (stack)
        (w- ds (hyperstack-dim-sys stack)
        #/dim-sys-dim</c ds #/hyperstack-dimension stack)]
      [stack hyperstack?]
      [elem any/c])
    [_ (stack)
      (list/c any/c (hyperstack/c #/hyperstack-dim-sys stack))])
  (w- ds (hyperstack-dim-sys stack)
  #/hyperstack-pop-dimlist stack #/dim-sys-dimlist-uniform ds i elem))


(define/own-contract (make-hyperstack-trivial ds dimension)
  (->i ([ds dim-sys?] [dimension (ds) (dim-sys-dim/c ds)])
    [_ (ds) (hyperstack/c ds)])
  (make-hyperstack ds dimension #/trivial))

(define/own-contract (hyperstack-pop-trivial i stack)
  (->i
    (
      [i (stack)
        (w- ds (hyperstack-dim-sys stack)
        #/dim-sys-dim</c ds #/hyperstack-dimension stack)]
      [stack hyperstack?])
    [_ (stack) (hyperstack/c #/hyperstack-dim-sys stack)])
  (w- ds (hyperstack-dim-sys stack)
  #/dissect (hyperstack-pop i stack #/trivial) (list elem rest)
  #/expect elem (trivial)
    (raise-arguments-error 'hyperstack-pop-trivial
      "expected the popped element to be a trivial value"
      "elem" elem)
    rest))
