#lang parendown racket/base

; punctaffy/hypersnippet/snippet
;
; An interface for data structures that are hypersnippet-shaped.

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
  -> ->i and/c any/c contract? contract-name contract-out
  flat-contract? list/c none/c not/c or/c rename-contract)
(require #/only-in racket/contract/combinator
  blame-add-context coerce-contract contract-first-order-passes?
  make-contract make-flat-contract raise-blame-error)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/contract by-own-method/c)
(require #/only-in lathe-comforts/list list-map)
(require #/only-in lathe-comforts/match match/c)
(require #/only-in lathe-comforts/maybe
  just just? just-value maybe? maybe-bind maybe/c maybe-if maybe-map
  nothing)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct)
(require #/only-in lathe-comforts/trivial trivial trivial?)
(require #/only-in lathe-morphisms/in-fp/mediary/set
  make-atomic-set-element-sys-impl-from-contract ok/c
  prop:atomic-set-element-sys)

(require #/only-in punctaffy/hypersnippet/dim
  dim-sys? dim-sys-dim<? dim-sys-dim<=? dim-sys-dim=? dim-sys-dim=0?
  dim-sys-dim/c dim-sys-dim</c dim-sys-dim=/c dim-sys-dim-max
  dim-sys-dim-zero dim-sys-morphism-sys?
  dim-sys-morphism-sys-chain-two dim-sys-morphism-sys-identity
  dim-sys-morphism-sys-morph-dim dim-sys-morphism-sys-replace-source
  dim-sys-morphism-sys-replace-target dim-sys-morphism-sys-source
  dim-sys-morphism-sys-target extended-with-top-dim-sys
  extended-with-top-dim-sys-morphism-sys extended-with-top-dim-finite
  extended-with-top-dim-infinite extend-with-top-dim-sys-morphism-sys
  fin-multiplied-dim fin-multiplied-dim-sys
  unextend-with-top-dim-sys-morphism-sys)
(require #/only-in punctaffy/hypersnippet/hyperstack
  hyperstack-dimension hyperstack-peek hyperstack-pop hyperstack-push
  make-hyperstack)

; TODO: Document all of these exports.
(provide
  unselected)
(provide #/contract-out
  [unselected? (-> any/c boolean?)]
  [unselected-value (-> unselected? any/c)])
(provide
  selected)
(provide #/contract-out
  [selected? (-> any/c boolean?)]
  [selected-value (-> selected? any/c)])
(provide #/contract-out
  [selectable? (-> any/c boolean?)]
  [selectable/c (-> contract? contract? contract?)]
  [snippet-sys? (-> any/c boolean?)]
  [snippet-sys-impl? (-> any/c boolean?)]
  [snippet-sys-snippet/c (-> snippet-sys? contract?)]
  [snippet-sys-dim-sys (-> snippet-sys? dim-sys?)]
  [snippet-sys-shape-snippet-sys (-> snippet-sys? snippet-sys?)]
  [snippet-sys-snippet-degree
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)])]
  [snippet-sys-snippet-with-degree/c
    (-> snippet-sys? contract? contract?)]
  [snippet-sys-snippet-with-degree</c
    (->i
      (
        [ss snippet-sys?]
        [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)])
      [_ contract?])]
  [snippet-sys-snippet-with-degree=/c
    (->i
      (
        [ss snippet-sys?]
        [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)])
      [_ contract?])]
  [snippet-sys-snippetof
    (->i
      (
        [ss snippet-sys?]
        [h-to-value/c (ss)
          (->
            ; TODO: See if the fact we're using
            ; `snippet-sys-snippetof` inside its own contract will
            ; cause any problems.
            (snippet-sys-snippetof
              (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            contract?)])
      [_ contract?])]
  [snippet-sys-snippet-zip-selective/c
    (->i
      (
        [ss snippet-sys?]
        [shape (ss)
          (snippet-sys-snippetof
            (snippet-sys-shape-snippet-sys ss)
            (fn hole trivial?))]
        [check-subject-hv? (ss)
          (->
            (snippet-sys-snippetof
              (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            any/c
            boolean?)]
        [hvv-to-subject-v/c (ss)
          (->
            (snippet-sys-snippetof
              (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            any/c
            any/c
            contract?)])
      [_ contract?])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting snippet should always be of the same shape as the input
  ; shape.
  [snippet-sys-shape->snippet
    (->i
      (
        [ss snippet-sys?]
        [shape (ss)
          (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)])
      [_ (ss shape)
        (snippet-sys-snippet-with-degree=/c ss
        #/snippet-sys-snippet-degree
          (snippet-sys-shape-snippet-sys ss)
          shape)])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting shape should always be of the same shape as the input
  ; snippet.
  [snippet-sys-snippet->maybe-shape
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss snippet)
        (maybe/c
          (snippet-sys-snippet-with-degree=/c
            (snippet-sys-shape-snippet-sys ss)
          #/snippet-sys-snippet-degree ss snippet))])]
  ; TODO: See if the result contract should be more specific. The
  ; should always exist if the given degree is equal to the degree
  ; returned by `snippet-sys-snippet-undone`, and it should always
  ; exist if the given degree is greater than that degree and that
  ; degree is nonzero.
  [snippet-sys-snippet-set-degree-maybe
    (->i
      (
        [ss snippet-sys?]
        [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
        [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss degree)
        (maybe/c #/snippet-sys-snippet-with-degree=/c ss degree)])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting snippet should always be of the same shape as the given
  ; shape in its low-degree holes.
  [snippet-sys-snippet-done
    (->i
      (
        [ss snippet-sys?]
        [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
        [shape (ss degree)
          (snippet-sys-snippet-with-degree</c
            (snippet-sys-shape-snippet-sys ss)
            degree)]
        [data any/c])
      [_ (ss degree) (snippet-sys-snippet-with-degree=/c ss degree)])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting shape should always be of the same shape as the given
  ; snippet's low-degree holes.
  [snippet-sys-snippet-undone
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss snippet)
        (maybe/c #/list/c
          (dim-sys-dim=/c (snippet-sys-dim-sys ss)
            (snippet-sys-snippet-degree ss snippet))
          (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)
          any/c)])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting snippet should always be of the same shape as the given
  ; one.
  [snippet-sys-snippet-select-everything
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss snippet)
        (and/c
          (snippet-sys-snippet-with-degree=/c ss
            (snippet-sys-snippet-degree ss snippet))
          (snippet-sys-snippetof ss #/fn hole selected?))])]
  [snippet-sys-snippet-splice
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss) (snippet-sys-snippet/c ss)]
        [hv-to-splice (ss snippet)
          (w- d (snippet-sys-snippet-degree ss snippet)
          #/->i
            (
              [hole
                (snippet-sys-snippetof
                  (snippet-sys-shape-snippet-sys ss)
                  (fn hole trivial?))]
              [data any/c])
            [_ (hole)
              (maybe/c #/selectable/c any/c
                ; What this means is that this should be a snippet
                ; which contains a `selected` or `unselected` entry in
                ; each hole, and its `selected` holes should
                ; correspond to the holes of `hole` and contain
                ; `trivial?` values.
                (and/c
                  (snippet-sys-snippet-with-degree=/c ss d)
                  (snippet-sys-snippetof ss #/fn hole
                    (selectable/c any/c trivial?))
                  (snippet-sys-snippet-zip-selective/c ss hole
                    (fn hole subject-data #/selected? subject-data)
                    (fn hole shape-data subject-data any/c))))])])
      [_ (ss snippet)
        (maybe/c
          (snippet-sys-snippet-with-degree=/c ss
          #/snippet-sys-snippet-degree ss snippet))])]
  [snippet-sys-snippet-zip-map-selective
    (->i
      (
        [ss snippet-sys?]
        [shape (ss)
          (snippet-sys-snippetof
            (snippet-sys-shape-snippet-sys ss)
            (fn hole any/c))]
        [snippet (ss)
          (snippet-sys-snippetof ss #/fn hole selectable?)]
        [hvv-to-maybe-v (ss)
          (->
            (snippet-sys-snippetof
              (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            any/c
            any/c
            maybe?)])
      [_ (ss) (maybe/c #/snippet-sys-snippet/c ss)])]
  [prop:snippet-sys (struct-type-property/c snippet-sys-impl?)]
  ; TODO: See if we can come up with a better name or interface for
  ; this.
  [make-snippet-sys-impl-from-various-1
    (->
      ; snippet-sys-snippet/c
      (-> snippet-sys? contract?)
      ; snippet-sys-dim-sys
      (-> snippet-sys? dim-sys?)
      ; snippet-sys-shape-snippet-sys
      (-> snippet-sys? snippet-sys?)
      ; snippet-sys-snippet-degree
      (->i
        ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
        [_ (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)])
      ; snippet-sys-shape->snippet
      (->i
        (
          [ss snippet-sys?]
          [shape (ss)
            (snippet-sys-snippet/c
              (snippet-sys-shape-snippet-sys ss))])
        [_ (ss shape)
          (snippet-sys-snippet-with-degree=/c ss
          #/snippet-sys-snippet-degree
            (snippet-sys-shape-snippet-sys ss)
            shape)])
      ; snippet-sys-snippet->maybe-shape
      (->i
        (
          [ss snippet-sys?]
          [snippet (ss) (snippet-sys-snippet/c ss)])
        [_ (ss snippet)
          (maybe/c
            (snippet-sys-snippet-with-degree=/c
              (snippet-sys-shape-snippet-sys ss)
            #/snippet-sys-snippet-degree ss snippet))])
      ; snippet-sys-snippet-set-degree-maybe
      (->i
        (
          [ss snippet-sys?]
          [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
          [snippet (ss) (snippet-sys-snippet/c ss)])
        [_ (ss degree)
          (maybe/c #/snippet-sys-snippet-with-degree=/c ss degree)])
      ; snippet-sys-snippet-done
      (->i
        (
          [ss snippet-sys?]
          [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
          [shape (ss degree)
            (snippet-sys-snippet-with-degree</c
              (snippet-sys-shape-snippet-sys ss)
              degree)]
          [data any/c])
        [_ (ss degree)
          (snippet-sys-snippet-with-degree=/c ss degree)])
      ; snippet-sys-snippet-undone
      (->i
        ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
        [_ (ss snippet)
          (maybe/c #/list/c
            (dim-sys-dim=/c (snippet-sys-dim-sys ss)
              (snippet-sys-snippet-degree ss snippet))
            (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)
            any/c)])
      ; snippet-sys-snippet-splice
      (->i
        (
          [ss snippet-sys?]
          [snippet (ss) (snippet-sys-snippet/c ss)]
          [hv-to-splice (ss snippet)
            (w- d (snippet-sys-snippet-degree ss snippet)
            #/->i
              (
                [hole
                  (snippet-sys-snippetof
                    (snippet-sys-shape-snippet-sys ss)
                    (fn hole trivial?))]
                [data any/c])
              [_ (hole)
                (maybe/c #/selectable/c any/c
                  ; What this means is that this should be a snippet
                  ; which contains a `selected` or `unselected` entry
                  ; in each hole, and its `selected` holes should
                  ; correspond to the holes of `hole` and contain
                  ; `trivial?` values.
                  (and/c
                    (snippet-sys-snippet-with-degree=/c ss d)
                    (snippet-sys-snippetof ss #/fn hole
                      (selectable/c any/c trivial?))
                    (snippet-sys-snippet-zip-selective/c ss hole
                      (fn hole subject-data #/selected? subject-data)
                      (fn hole shape-data subject-data any/c))))])])
        [_ (ss snippet)
          (maybe/c
            (snippet-sys-snippet-with-degree=/c ss
            #/snippet-sys-snippet-degree ss snippet))])
      ; snippet-sys-snippet-zip-map-selective
      (->i
        (
          [ss snippet-sys?]
          [shape (ss)
            (snippet-sys-snippetof
              (snippet-sys-shape-snippet-sys ss)
              (fn hole any/c))]
          [snippet (ss)
            (snippet-sys-snippetof ss #/fn hole selectable?)]
          [hvv-to-maybe-v (ss)
            (->
              (snippet-sys-snippetof
                (snippet-sys-shape-snippet-sys ss)
                (fn hole trivial?))
              any/c
              any/c
              maybe?)])
        [_ (ss) (maybe/c #/snippet-sys-snippet/c ss)])
      snippet-sys-impl?)]
  
  [snippet-sys-morphism-sys? (-> any/c boolean?)]
  [snippet-sys-morphism-sys-impl? (-> any/c boolean?)]
  [snippet-sys-morphism-sys-source
    (-> snippet-sys-morphism-sys? snippet-sys?)]
  [snippet-sys-morphism-sys-replace-source
    (-> snippet-sys-morphism-sys? snippet-sys?
      snippet-sys-morphism-sys?)]
  [snippet-sys-morphism-sys-target
    (-> snippet-sys-morphism-sys? snippet-sys?)]
  [snippet-sys-morphism-sys-replace-target
    (-> snippet-sys-morphism-sys? snippet-sys?
      snippet-sys-morphism-sys?)]
  [snippet-sys-morphism-sys-dim-sys-morphism-sys
    (-> snippet-sys-morphism-sys? dim-sys-morphism-sys?)]
  [snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
    (-> snippet-sys-morphism-sys? snippet-sys-morphism-sys?)]
  [snippet-sys-morphism-sys-morph-snippet
    (->i
      (
        [ms snippet-sys-morphism-sys?]
        [s (ms)
          (snippet-sys-snippet/c
            (snippet-sys-morphism-sys-source ms))])
      [_ (ms)
        (snippet-sys-snippet/c
          (snippet-sys-morphism-sys-target ms))])]
  [snippet-sys-morphism-sys/c (-> contract? contract? contract?)]
  [prop:snippet-sys-morphism-sys
    (struct-type-property/c snippet-sys-morphism-sys-impl?)]
  [make-snippet-sys-morphism-sys-impl-from-morph
    (->
      (-> snippet-sys-morphism-sys? snippet-sys?)
      (-> snippet-sys-morphism-sys? snippet-sys?
        snippet-sys-morphism-sys?)
      (-> snippet-sys-morphism-sys? snippet-sys?)
      (-> snippet-sys-morphism-sys? snippet-sys?
        snippet-sys-morphism-sys?)
      (-> snippet-sys-morphism-sys? dim-sys-morphism-sys?)
      (-> snippet-sys-morphism-sys? snippet-sys-morphism-sys?)
      (->i
        (
          [ms snippet-sys-morphism-sys?]
          [s (ms)
            (snippet-sys-snippet/c
              (snippet-sys-morphism-sys-source ms))])
        [_ (ms)
          (snippet-sys-snippet/c
            (snippet-sys-morphism-sys-target ms))])
      snippet-sys-morphism-sys-impl?)]
  [snippet-sys-morphism-sys-chain-two
    (->i
      (
        [a snippet-sys-morphism-sys?]
        [b (a)
          (snippet-sys-morphism-sys/c
            (ok/c #/snippet-sys-morphism-sys-target a)
            any/c)])
      [_ (a b)
        (snippet-sys-morphism-sys/c
          (ok/c #/snippet-sys-morphism-sys-source a)
          (ok/c #/snippet-sys-morphism-sys-target b))])]
  
  [functor-from-dim-sys-to-snippet-sys-sys? (-> any/c boolean?)]
  [functor-from-dim-sys-to-snippet-sys-sys-impl? (-> any/c boolean?)]
  [functor-from-dim-sys-to-snippet-sys-sys-accepts/c
    (-> functor-from-dim-sys-to-snippet-sys-sys? contract?)]
  [functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
    (-> functor-from-dim-sys-to-snippet-sys-sys? dim-sys?
      snippet-sys?)]
  [functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys-morphism-sys
    (->i
      (
        [fs functor-from-dim-sys-to-snippet-sys-sys?]
        [ms dim-sys-morphism-sys?])
      [_ (ms)
        (snippet-sys-morphism-sys/c
          (ok/c
            (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
              (dim-sys-morphism-sys-source ms)))
          (ok/c
            (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
              (dim-sys-morphism-sys-target ms))))])]
  [prop:functor-from-dim-sys-to-snippet-sys-sys
    (struct-type-property/c
      functor-from-dim-sys-to-snippet-sys-sys-impl?)]
  [make-functor-from-dim-sys-to-snippet-sys-sys-impl-from-morph
    (->
      (-> functor-from-dim-sys-to-snippet-sys-sys? contract?)
      (-> functor-from-dim-sys-to-snippet-sys-sys? dim-sys?
        snippet-sys?)
      (->i
        (
          [fs functor-from-dim-sys-to-snippet-sys-sys?]
          [ms dim-sys-morphism-sys?])
        [_ (ms)
          (snippet-sys-morphism-sys/c
            (ok/c
              (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
                (dim-sys-morphism-sys-source ms)))
            (ok/c
              (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
                (dim-sys-morphism-sys-target ms))))])
      functor-from-dim-sys-to-snippet-sys-sys-impl?)]
  
  ; TODO:
  ;
  ; A `snippet-format-sys?` is a wrapped functor from the `dim-sys?`
  ; category to the `snippet-sys?` category that guarantees the
  ; resulting `snippet-sys` systems and morphisms make use of the same
  ; `dym-sys` systems and functors that were given. That is, when we
  ; compose an extension's functor with the functor represented by the
  ; combination of `snippet-sys-dim-sys` and
  ; `snippet-sys-morphism-sys-dim-sys-morphism-sys`, we get an
  ; identity functor.
  ;
  ; When we document the `snippet-format-sys?` type, make sure to
  ; explain this.
  ;
  [snippet-format-sys? (-> any/c boolean?)]
  [snippet-format-sys-impl? (-> any/c boolean?)]
  [snippet-format-sys-functor
    (-> snippet-format-sys? functor-from-dim-sys-to-snippet-sys-sys?)]
  [prop:snippet-format-sys
    (struct-type-property/c snippet-format-sys-impl?)]
  [make-snippet-format-sys-impl-from-functor
    (->
      (-> snippet-format-sys?
        functor-from-dim-sys-to-snippet-sys-sys?)
      snippet-format-sys-impl?)]
  
  [functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
    (-> any/c boolean?)]
  [functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl?
    (-> any/c boolean?)]
  [functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-accepts/c
    (-> functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
      contract?)]
  [functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
    (-> functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
      functor-from-dim-sys-to-snippet-sys-sys?)]
  [functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-replace-source
    (-> functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
      functor-from-dim-sys-to-snippet-sys-sys?
      functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?)]
  [functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
    (-> functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
      functor-from-dim-sys-to-snippet-sys-sys?)]
  [functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-replace-target
    (->
      functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
      functor-from-dim-sys-to-snippet-sys-sys?
      functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?)]
  [functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-transfer-to-snippet-sys-morphism-sys
    (->i
      (
        [ms functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?]
        [ds dim-sys?])
      [_ (ms ds)
        (snippet-sys-morphism-sys/c
          (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
            (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
              ms)
            ds)
          (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
            (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
              ms)
            ds))])]
  [functor-from-dim-sys-to-snippet-sys-sys-morphism-sys/c
    (-> contract? contract? contract?)]
  [prop:functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
    (struct-type-property/c
      functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl?)]
  [make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-transfer
    (->
      (-> functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        contract?)
      (-> functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        functor-from-dim-sys-to-snippet-sys-sys?)
      (->
        functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        functor-from-dim-sys-to-snippet-sys-sys?
        functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?)
      (-> functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        functor-from-dim-sys-to-snippet-sys-sys?)
      (->
        functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        functor-from-dim-sys-to-snippet-sys-sys?
        functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?)
      (->i
        (
          [ms functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?]
          [ds dim-sys?])
        [_ (ms ds)
          (snippet-sys-morphism-sys/c
            (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
              (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
                ms)
              ds)
            (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
              (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
                ms)
              ds))])
      functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl?)]
  
  [snippet-format-sys-morphism-sys? (-> any/c boolean?)]
  [snippet-format-sys-morphism-sys-impl? (-> any/c boolean?)]
  [snippet-format-sys-morphism-sys-source
    (-> snippet-format-sys-morphism-sys? snippet-format-sys?)]
  [snippet-format-sys-morphism-sys-replace-source
    (-> snippet-format-sys-morphism-sys? snippet-format-sys?
      snippet-format-sys-morphism-sys?)]
  [snippet-format-sys-morphism-sys-target
    (-> snippet-format-sys-morphism-sys? snippet-format-sys?)]
  [snippet-format-sys-morphism-sys-replace-target
    (-> snippet-format-sys-morphism-sys? snippet-format-sys?
      snippet-format-sys-morphism-sys?)]
  [snippet-format-sys-morphism-sys-functor-morphism
    (-> snippet-format-sys-morphism-sys?
      functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?)]
  [snippet-format-sys-morphism-sys/c
    (-> contract? contract? contract?)]
  [prop:snippet-format-sys-morphism-sys
    (struct-type-property/c snippet-format-sys-morphism-sys-impl?)]
  [make-snippet-format-sys-morphism-sys-impl-from-morph
    (->
      (-> snippet-format-sys-morphism-sys? snippet-format-sys?)
      (-> snippet-format-sys-morphism-sys? snippet-format-sys?
        snippet-format-sys-morphism-sys?)
      (-> snippet-format-sys-morphism-sys? snippet-format-sys?)
      (-> snippet-format-sys-morphism-sys? snippet-format-sys?
        snippet-format-sys-morphism-sys?)
      (-> snippet-format-sys-morphism-sys?
        functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?)
      snippet-format-sys-morphism-sys-impl?)]
  
  [snippet-format-sys-endofunctor-sys? (-> any/c boolean?)]
  [snippet-format-sys-endofunctor-sys-impl? (-> any/c boolean?)]
  [snippet-format-sys-endofunctor-sys-accepts/c
    (-> snippet-format-sys-endofunctor-sys? contract?)]
  [snippet-format-sys-endofunctor-sys-morph-snippet-format-sys
    (-> snippet-format-sys-endofunctor-sys? snippet-format-sys?
      snippet-format-sys?)]
  [snippet-format-sys-endofunctor-sys-morph-snippet-format-sys-morphism-sys
    (->i
      (
        [es snippet-format-sys-endofunctor-sys?]
        [ms snippet-format-sys-morphism-sys?])
      [_ (ms)
        (snippet-format-sys-morphism-sys/c
          (ok/c
            (snippet-format-sys-endofunctor-sys-morph-snippet-format-sys
              (snippet-format-sys-morphism-sys-source ms)))
          (ok/c
            (snippet-format-sys-endofunctor-sys-morph-snippet-format-sys
              (snippet-format-sys-morphism-sys-target ms))))])]
  [prop:snippet-format-sys-endofunctor-sys
    (struct-type-property/c snippet-format-sys-endofunctor-sys-impl?)]
  [make-snippet-format-sys-endofunctor-sys-impl-from-morph
    (->
      (-> snippet-format-sys-endofunctor-sys? contract?)
      (-> snippet-format-sys-endofunctor-sys? snippet-format-sys?
        snippet-format-sys?)
      (->i
        (
          [es snippet-format-sys-endofunctor-sys?]
          [ms snippet-format-sys-morphism-sys?])
        [_ (ms)
          (snippet-format-sys-morphism-sys/c
            (ok/c
              (snippet-format-sys-endofunctor-sys-morph-snippet-format-sys
                (snippet-format-sys-morphism-sys-source ms)))
            (ok/c
              (snippet-format-sys-endofunctor-sys-morph-snippet-format-sys
                (snippet-format-sys-morphism-sys-target ms))))])
      snippet-format-sys-endofunctor-sys-impl?)]
  
  )


(define-imitation-simple-struct
  (unselected? unselected-value)
  unselected
  'unselected (current-inspector) (auto-write) (auto-equal))

(define-imitation-simple-struct
  (selected? selected-value)
  selected
  'selected (current-inspector) (auto-write) (auto-equal))

(define (selectable? v)
  (or (unselected? v) (selected? v)))

(define (selectable/c unselected/c selected/c)
  (w- unselected/c (coerce-contract 'selectable/c unselected/c)
  #/w- selected/c (coerce-contract 'selectable/c selected/c)
  #/rename-contract
    (or/c
      (match/c unselected unselected/c)
      (match/c selected selected/c))
    `(selectable/c
       ,(contract-name unselected/c)
       ,(contract-name selected/c))))


(define-imitation-simple-generics snippet-sys? snippet-sys-impl?
  (#:method snippet-sys-snippet/c (#:this))
  (#:method snippet-sys-dim-sys (#:this))
  (#:method snippet-sys-shape-snippet-sys (#:this))
  (#:method snippet-sys-snippet-degree (#:this) ())
  (#:method snippet-sys-shape->snippet (#:this) ())
  (#:method snippet-sys-snippet->maybe-shape (#:this) ())
  (#:method snippet-sys-snippet-set-degree-maybe (#:this) () ())
  (#:method snippet-sys-snippet-done (#:this) () () ())
  (#:method snippet-sys-snippet-undone (#:this) ())
  (#:method snippet-sys-snippet-splice (#:this) () ())
  (#:method snippet-sys-snippet-zip-map-selective (#:this) () () ())
  prop:snippet-sys make-snippet-sys-impl-from-various-1
  'snippet-sys 'snippet-sys-impl (list))

; TODO: See if this should have the question mark in its name.
; TODO: See if we should have a way to implement this that doesn't
; involve constructing another snippet along the way, since we just
; end up ignoring it.
; TODO: Export this.
(define (snippet-sys-snippet-all? ss snippet check-hv?)
  (just? #/snippet-sys-snippet-splice ss snippet #/fn hole data
    (if (check-hv? hole data)
      (just #/unselected data)
      (nothing))))

; TODO: Export this.
(define (snippet-sys-snippet-map-maybe ss snippet hv-to-maybe-v)
  (snippet-sys-snippet-splice ss snippet #/fn hole data
    (maybe-map (hv-to-maybe-v hole data) #/fn data
      (unselected data))))

; TODO: Export this.
(define (snippet-sys-snippet-map ss snippet hv-to-v)
  (just-value
  #/snippet-sys-snippet-map-maybe ss snippet #/fn hole data
    (just #/hv-to-v hole data)))

; TODO: Export this.
(define (snippet-sys-snippet-select ss snippet check-hv?)
  (snippet-sys-snippet-map ss snippet #/fn hole data
    (if (check-hv? hole data)
      (selected data)
      (unselected data))))

(define (snippet-sys-snippet-select-everything ss snippet)
  (snippet-sys-snippet-select ss snippet #/fn hole data #t))

; TODO: See if this should have the question mark in its name.
; TODO: Export this.
(define
  (snippet-sys-snippet-zip-all-selective? ss shape snippet check-hvv?)
  (expect
    (snippet-sys-snippet-zip-map-selective ss shape snippet
    #/fn hole shape-data snippet-data
      (just #/list shape-data snippet-data))
    (just zipped)
    #f
  #/snippet-sys-snippet-all? ss zipped #/fn hole data
    (dissect data (list shape-data snippet-data)
    #/check-hvv? shape-data snippet-data)))

(define (snippet-sys-snippet-with-degree/c ss degree/c)
  (w- degree/c
    (coerce-contract 'snippet-sys-snippet-with-degree/c degree/c)
  #/w- name
    `(snippet-sys-snippet-with-degree/c ,ss ,(contract-name degree/c))
  #/w- snippet-contract (snippet-sys-snippet/c ss)
  #/w- first-order
    (fn v
      (and
        (contract-first-order-passes? snippet-contract v)
        (contract-first-order-passes? degree/c
          (snippet-sys-snippet-degree ss v))))
  #/make-contract #:name name #:first-order first-order
    
    #:late-neg-projection
    (fn blame
      (w- snippet-contract-projection
        (
          (get/build-late-neg-projection snippet-contract)
          (blame-add-context blame "initial snippet check of"))
      #/w- degree/c-projection
        (
          (get/build-late-neg-projection degree/c)
          (blame-add-context blame "degree check of"))
      #/fn v missing-party
        (w- v (snippet-contract-projection v missing-party)
        #/begin
          (degree/c-projection (snippet-sys-snippet-degree ss v)
            missing-party)
          v)))))

(define (snippet-sys-snippet-with-degree</c ss degree)
  (rename-contract
    (snippet-sys-snippet-with-degree/c ss
      (dim-sys-dim</c (snippet-sys-dim-sys ss) degree))
    `(snippet-sy-ssnippet-with-degree</c ,ss ,degree)))

(define (snippet-sys-snippet-with-degree=/c ss degree)
  (rename-contract
    (snippet-sys-snippet-with-degree/c ss
      (dim-sys-dim=/c (snippet-sys-dim-sys ss) degree))
    `(snippet-sy-ssnippet-with-degree=/c ,ss ,degree)))

(define (snippet-sys-snippetof ss h-to-value/c)
  (w- name `(snippet-sys-snippetof ,ss ,h-to-value/c)
  #/w- snippet-contract (snippet-sys-snippet/c ss)
  #/w- first-order
    (fn v
      (and (contract-first-order-passes? snippet-contract v)
      #/snippet-sys-snippet-all? ss v #/fn hole data
        (contract-first-order-passes? (h-to-value/c hole) data)))
  #/make-contract #:name name #:first-order first-order
    
    #:late-neg-projection
    (fn blame
      (w- snippet-contract-projection
        (
          (get/build-late-neg-projection snippet-contract)
          (blame-add-context blame "initial snippet check of"))
      #/fn v missing-party
        (w- v (snippet-contract-projection v missing-party)
        #/snippet-sys-snippet-map ss v #/fn hole data
          (
            (
              (get/build-late-neg-projection #/h-to-value/c hole)
              (blame-add-context blame "hole value of"))
            data
            missing-party))))))

(define
  (snippet-sys-snippet-zip-selective/c
    ss shape check-subject-hv? hvv-to-subject-v/c)
  (w- name
    `(snippet-sys-snippet-zip-selective/c
      ,ss ,shape ,check-subject-hv? ,hvv-to-subject-v/c)
  #/w- snippet-contract (snippet-sys-snippet/c ss)
  #/w- first-order
    (fn v
      (and (contract-first-order-passes? snippet-contract v)
      #/snippet-sys-snippet-zip-all-selective? ss shape
        (snippet-sys-snippet-select ss v #/fn hole data
          (check-subject-hv? hole data))
      #/fn hole shape-data subject-data
        (contract-first-order-passes?
          (hvv-to-subject-v/c hole shape-data subject-data)
          subject-data)))
  #/make-contract #:name name #:first-order first-order
    
    #:late-neg-projection
    (fn blame
      (w- snippet-contract-projection
        (
          (get/build-late-neg-projection snippet-contract)
          (blame-add-context blame "initial snippet check of"))
      #/fn v missing-party
        (w- v (snippet-contract-projection v missing-party)
        #/expect
          (snippet-sys-snippet-zip-map-selective ss shape
            (snippet-sys-snippet-select ss v #/fn hole data
              (check-subject-hv? hole data))
          #/fn hole shape-data subject-data
            (just #/
              (
                (get/build-late-neg-projection
                  (hvv-to-subject-v/c hole shape-data subject-data))
                (blame-add-context blame "hole value of"))
              subject-data
              missing-party))
          (just result)
          (raise-blame-error blame #:missing-party missing-party v
            '(expected: "~e" given: "~e")
            name v)
          result)))))


; TODO: Export this.
; TODO: Use the things that use this.
(define
  (snippet-sys-snippet-select-if-degree ss snippet check-degree?)
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/snippet-sys-snippet-select ss snippet #/fn hole data
    (check-degree? #/snippet-sys-snippet-degree shape-ss hole)))

; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-select-if-degree< ss degree snippet)
  (w- ds (snippet-sys-dim-sys ss)
  #/snippet-sys-snippet-select-if-degree ss snippet #/fn actual-degree
    (dim-sys-dim<? ds actual-degree degree)))

; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-splice-sure ss snippet hv-to-splice)
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/just-value #/snippet-sys-snippet-splice ss snippet #/fn hole data
    (just #/hv-to-splice hole data)))

; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-bind ss prefix hv-to-suffix)
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/snippet-sys-snippet-splice-sure ss prefix #/fn hole data
    (selected #/snippet-sys-snippet-select-if-degree< ss
      (snippet-sys-snippet-degree shape-ss hole)
      (hv-to-suffix hole data))))

; TODO: Export this.
; TODO: Use this.
(define (snippet-sys-snippet-join ss snippet)
  (snippet-sys-snippet-bind ss snippet #/fn hole data data))

; TODO: See if this should have the question mark in its name.
; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-any? ss snippet check-hv?)
  (not #/snippet-sys-snippet-all? ss snippet #/fn hole data
    (not #/check-hv? hole data)))


(define-imitation-simple-generics
  snippet-sys-morphism-sys? snippet-sys-morphism-sys-impl?
  (#:method snippet-sys-morphism-sys-source (#:this))
  (#:method snippet-sys-morphism-sys-replace-source (#:this) ())
  (#:method snippet-sys-morphism-sys-target (#:this))
  (#:method snippet-sys-morphism-sys-replace-target (#:this) ())
  (#:method snippet-sys-morphism-sys-dim-sys-morphism-sys (#:this))
  (#:method snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
    (#:this))
  (#:method snippet-sys-morphism-sys-morph-snippet (#:this) ())
  prop:snippet-sys-morphism-sys
  make-snippet-sys-morphism-sys-impl-from-morph
  'snippet-sys-morphism-sys 'snippet-sys-morphism-sys-impl (list))

(define (snippet-sys-morphism-sys/c source/c target/c)
  (w- source/c (coerce-contract 'snippet-sys-morphism-sys/c source/c)
  #/w- target/c (coerce-contract 'snippet-sys-morphism-sys/c target/c)
  #/w- name
    `(snippet-sys-morphism-sys/c
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
        (snippet-sys-morphism-sys? v)
        (contract-first-order-passes? source/c
          (snippet-sys-morphism-sys-source v))
        (contract-first-order-passes? target/c
          (snippet-sys-morphism-sys-target v))))
    
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
            snippet-sys-morphism-sys-replace-source
            snippet-sys-morphism-sys-source
            v)
        #/w- v
          (replace-if-not-flat
            target/c
            target/c-projection
            snippet-sys-morphism-sys-replace-target
            snippet-sys-morphism-sys-target
            v)
          v)))))

(define-imitation-simple-struct
  (identity-snippet-sys-morphism-sys?
    identity-snippet-sys-morphism-sys-endpoint)
  identity-snippet-sys-morphism-sys
  'identity-snippet-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (identity-snippet-sys-morphism-sys e)
        (match/c identity-snippet-sys-morphism-sys #/ok/c e))))
  (#:prop prop:snippet-sys-morphism-sys
    (make-snippet-sys-morphism-sys-impl-from-morph
      ; snippet-sys-morphism-sys-source
      (dissectfn (identity-snippet-sys-morphism-sys e) e)
      ; snippet-sys-morphism-sys-replace-source
      (fn ms new-s #/identity-snippet-sys-morphism-sys new-s)
      ; snippet-sys-morphism-sys-target
      (dissectfn (identity-snippet-sys-morphism-sys e) e)
      ; snippet-sys-morphism-sys-replace-target
      (fn ms new-t #/identity-snippet-sys-morphism-sys new-t)
      ; snippet-sys-morphism-sys-dim-sys-morphism-sys
      (dissectfn (identity-snippet-sys-morphism-sys e)
        (dim-sys-morphism-sys-identity #/snippet-sys-dim-sys e))
      ; snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
      (dissectfn (identity-snippet-sys-morphism-sys e)
        (identity-snippet-sys-morphism-sys
          (snippet-sys-shape-snippet-sys e)))
      ; snippet-sys-morphism-sys-morph-snippet
      (fn ms s s))))

; TODO: Export this.
; TODO: Use this.
(define (snippet-sys-morphism-sys-identity endpoint)
  (identity-snippet-sys-morphism-sys endpoint))

(define-imitation-simple-struct
  (chain-two-snippet-sys-morphism-sys?
    chain-two-snippet-sys-morphism-sys-first
    chain-two-snippet-sys-morphism-sys-second)
  chain-two-snippet-sys-morphism-sys
  'chain-two-snippet-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (chain-two-snippet-sys-morphism-sys a b)
        (match/c chain-two-snippet-sys-morphism-sys
          (ok/c a)
          (ok/c b)))))
  (#:prop prop:snippet-sys-morphism-sys
    (make-snippet-sys-morphism-sys-impl-from-morph
      ; snippet-sys-morphism-sys-source
      (dissectfn (chain-two-snippet-sys-morphism-sys a b)
        (snippet-sys-morphism-sys-source a))
      ; snippet-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms (chain-two-snippet-sys-morphism-sys a b)
        #/chain-two-snippet-sys-morphism-sys
          (snippet-sys-morphism-sys-replace-source a new-s)
          b))
      ; snippet-sys-morphism-sys-target
      (dissectfn (chain-two-snippet-sys-morphism-sys a b)
        (snippet-sys-morphism-sys-target b))
      ; snippet-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms (chain-two-snippet-sys-morphism-sys a b)
        #/chain-two-snippet-sys-morphism-sys
          a
          (snippet-sys-morphism-sys-replace-target b new-t)))
      ; snippet-sys-morphism-sys-dim-sys-morphism-sys
      (dissectfn (chain-two-snippet-sys-morphism-sys a b)
        (dim-sys-morphism-sys-chain-two
          (snippet-sys-morphism-sys-dim-sys-morphism-sys a)
          (snippet-sys-morphism-sys-dim-sys-morphism-sys b)))
      ; snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
      (dissectfn (chain-two-snippet-sys-morphism-sys a b)
        (dim-sys-morphism-sys-chain-two
          (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys a)
          (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
            b)))
      ; snippet-sys-morphism-sys-morph-snippet
      (fn ms s
        (dissect ms (chain-two-snippet-sys-morphism-sys a b)
        #/snippet-sys-morphism-sys-morph-snippet b
          (snippet-sys-morphism-sys-morph-snippet a s))))))

; TODO: Export this.
; TODO: Use this.
(define (snippet-sys-morphism-sys-chain-two a b)
  (chain-two-snippet-sys-morphism-sys a b))


(define-imitation-simple-generics
  functor-from-dim-sys-to-snippet-sys-sys?
  functor-from-dim-sys-to-snippet-sys-sys-impl?
  (#:method functor-from-dim-sys-to-snippet-sys-sys-accepts/c
    (#:this))
  (#:method functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
    (#:this)
    ())
  (#:method
    functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys-morphism-sys
    (#:this)
    ())
  prop:functor-from-dim-sys-to-snippet-sys-sys
  make-functor-from-dim-sys-to-snippet-sys-sys-impl-from-morph
  'functor-from-dim-sys-to-snippet-sys-sys
  'functor-from-dim-sys-to-snippet-sys-sys-impl
  (list))


(define-imitation-simple-generics
  snippet-format-sys?
  snippet-format-sys-impl?
  (#:method snippet-format-sys-functor (#:this))
  prop:snippet-format-sys
  make-snippet-format-sys-impl-from-functor
  'snippet-format-sys 'snippet-format-sys-impl (list))


(define-imitation-simple-generics
  functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
  functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl?
  (#:method
    functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-accepts/c
    (#:this))
  (#:method
    functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
    (#:this))
  (#:method
    functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-replace-source
    (#:this)
    ())
  (#:method
    functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
    (#:this))
  (#:method
    functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-replace-target
    (#:this)
    ())
  (#:method
    functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-transfer-to-snippet-sys-morphism-sys
    (#:this)
    ())
  prop:functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
  make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-transfer
  'functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
  'functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl
  (list))

(define (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys/c source/c target/c)
  (w- source/c
    (coerce-contract
      'functor-from-dim-sys-to-snippet-sys-sys-morphism-sys/c
      source/c)
  #/w- target/c
    (coerce-contract
      'functor-from-dim-sys-to-snippet-sys-sys-morphism-sys/c
      target/c)
  #/w- name
    `(functor-from-dim-sys-to-snippet-sys-sys-morphism-sys/c
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
        (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys? v)
        (contract-first-order-passes? source/c
          (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
            v))
        (contract-first-order-passes? target/c
          (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
            v))))
    
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
            functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-replace-source
            functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
            v)
        #/w- v
          (replace-if-not-flat
            target/c
            target/c-projection
            functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-replace-target
            functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
            v)
          v)))))

(define-imitation-simple-struct
  (identity-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
    identity-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-endpoint)
  identity-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
  'identity-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
  (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
    (make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-transfer
      ; functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-accepts/c
      (dissectfn
        (identity-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          e)
        (match/c
          identity-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          (functor-from-dim-sys-to-snippet-sys-sys-accepts/c e)))
      ; functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
      (dissectfn
        (identity-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          e)
        e)
      ; functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-replace-source
      (fn ms new-s
        (identity-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          new-s))
      ; functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
      (dissectfn
        (identity-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          e)
        e)
      ; functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-replace-target
      (fn ms new-t
        (identity-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          new-t))
      ; functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-transfer-to-snippet-sys-morphism-sys
      (fn ms ds
        (dissect ms
          (identity-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
            e)
        #/snippet-sys-morphism-sys-identity
          (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
            ds))))))

; TODO: Export this.
; TODO: Use this.
(define
  (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-identity
    endpoint)
  (identity-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
    endpoint))


(define-imitation-simple-generics
  snippet-format-sys-morphism-sys?
  snippet-format-sys-morphism-sys-impl?
  (#:method snippet-format-sys-morphism-sys-source (#:this))
  (#:method snippet-format-sys-morphism-sys-replace-source
    (#:this)
    ())
  (#:method snippet-format-sys-morphism-sys-target (#:this))
  (#:method snippet-format-sys-morphism-sys-replace-target
    (#:this)
    ())
  (#:method snippet-format-sys-morphism-sys-functor-morphism (#:this))
  prop:snippet-format-sys-morphism-sys
  make-snippet-format-sys-morphism-sys-impl-from-morph
  'snippet-format-sys-morphism-sys
  'snippet-format-sys-morphism-sys-impl
  (list))

(define (snippet-format-sys-morphism-sys/c source/c target/c)
  (w- source/c
    (coerce-contract 'snippet-format-sys-morphism-sys/c source/c)
  #/w- target/c
    (coerce-contract 'snippet-format-sys-morphism-sys/c target/c)
  #/w- name
    `(snippet-format-sys-morphism-sys/c
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
        (snippet-format-sys-morphism-sys? v)
        (contract-first-order-passes? source/c
          (snippet-format-sys-morphism-sys-source v))
        (contract-first-order-passes? target/c
          (snippet-format-sys-morphism-sys-target v))))
    
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
            snippet-format-sys-morphism-sys-replace-source
            snippet-format-sys-morphism-sys-source
            v)
        #/w- v
          (replace-if-not-flat
            target/c
            target/c-projection
            snippet-format-sys-morphism-sys-replace-target
            snippet-format-sys-morphism-sys-target
            v)
          v)))))

(define-imitation-simple-struct
  (identity-snippet-format-sys-morphism-sys?
    identity-snippet-format-sys-morphism-sys-endpoint)
  identity-snippet-format-sys-morphism-sys
  'identity-snippet-format-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (identity-snippet-format-sys-morphism-sys e)
        (match/c identity-snippet-format-sys-morphism-sys #/ok/c e))))
  (#:prop prop:snippet-format-sys-morphism-sys
    (make-snippet-format-sys-morphism-sys-impl-from-morph
      ; snippet-format-sys-morphism-sys-source
      (dissectfn (identity-snippet-format-sys-morphism-sys e) e)
      ; snippet-format-sys-morphism-sys-replace-source
      (fn ms new-s #/identity-snippet-format-sys-morphism-sys new-s)
      ; snippet-format-sys-morphism-sys-target
      (dissectfn (identity-snippet-format-sys-morphism-sys e) e)
      ; snippet-format-sys-morphism-sys-replace-target
      (fn ms new-t #/identity-snippet-format-sys-morphism-sys new-t)
      ; snippet-format-sys-morphism-sys-morph-snippet-functor-morphism
      (dissectfn (identity-snippet-format-sys-morphism-sys e)
        (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-identity
          (snippet-format-sys-functor e))))))

; TODO: Export this.
; TODO: Use this.
(define (snippet-format-sys-morphism-sys-identity endpoint)
  (identity-snippet-format-sys-morphism-sys endpoint))


(define-imitation-simple-generics
  snippet-format-sys-endofunctor-sys?
  snippet-format-sys-endofunctor-sys-impl?
  (#:method snippet-format-sys-endofunctor-sys-accepts/c (#:this))
  (#:method
    snippet-format-sys-endofunctor-sys-morph-snippet-format-sys
    (#:this)
    ())
  (#:method
    snippet-format-sys-endofunctor-sys-morph-snippet-format-sys-morphism-sys
    (#:this)
    ())
  prop:snippet-format-sys-endofunctor-sys
  make-snippet-format-sys-endofunctor-sys-impl-from-morph
  'snippet-format-sys-endofunctor-sys
  'snippet-format-sys-endofunctor-sys-impl
  (list))


; TODO: Export these.
; TODO: Use the things that use these.
(define-imitation-simple-struct
  (selective-snippet-zero? selective-snippet-zero-content)
  selective-snippet-zero
  'selective-snippet-zero (current-inspector)
  (auto-write)
  (auto-equal))

; TODO: Export these.
; TODO: Use the things that use these.
(define-imitation-simple-struct
  (selective-snippet-nonzero?
    selective-snippet-nonzero-degree
    selective-snippet-nonzero-content)
  selective-snippet-nonzero
  'selective-snippet-nonzero (current-inspector)
  (auto-write)
  (auto-equal))

; TODO: Export this.
; TODO: Use the things that use this.
(define (selective-snippet? v)
  (or
    (selective-snippet-zero? v)
    (selective-snippet-nonzero? v)))

; TODO: Export this.
; TODO: Use the things that use this.
(define (selective-snippet/c sfs uds h-to-unselected/c)
  (w- eds (extended-with-top-dim-sys uds)
  #/w- ffdstsss (snippet-format-sys-functor sfs)
  #/w- uss
    (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
      ffdstsss uds)
  #/w- ess
    (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
      ffdstsss eds)
  #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
  #/rename-contract
    (or/c
      (match/c selective-snippet-zero
        (snippet-sys-snippet-with-degree/c uss
          (dim-sys-dim-zero uds)))
    #/and/c
      (match/c selective-snippet-nonzero
        (and/c
          (dim-sys-dim/c uds)
          (not/c #/dim-sys-dim=/c eds #/dim-sys-dim-zero uds))
        (snippet-sys-snippet-with-degree/c ess
          (extended-with-top-dim-infinite)))
      (by-own-method/c (selective-snippet-nonzero d maybe-content)
      #/match/c selective-snippet-nonzero any/c
        (snippet-sys-snippetof ess #/fn hole
          (selectable/c
            (if
              (dim-sys-dim<? eds
                (snippet-sys-snippet-degree shape-ess hole)
                (extended-with-top-dim-finite d))
              (h-to-unselected/c hole)
              none/c)
            any/c))))
    `(selective-snippet/c ,sfs ,uds ,h-to-unselected/c)))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (selective-snippet-sys?
    selective-snippet-sys-snippet-format-sys
    selective-snippet-sys-dim-sys
    selective-snippet-sys-h-to-unselected/c)
  selective-snippet-sys
  'selective-snippet-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (selective-snippet-sys sfs uds h-to-unselected/c)
        (match/c selective-snippet-sys (ok/c sfs) (ok/c uds) any/c))))
  (#:prop prop:snippet-sys #/make-snippet-sys-impl-from-various-1
    ; snippet-sys-snippet/c
    (dissectfn (selective-snippet-sys sfs uds h-to-unselected/c)
      (selective-snippet/c sfs uds h-to-unselected/c))
    ; snippet-sys-dim-sys
    (dissectfn (selective-snippet-sys sfs uds _)
      uds)
    ; snippet-sys-shape-snippet-sys
    (dissectfn (selective-snippet-sys sfs uds _)
      (w- uss
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          (snippet-format-sys-functor sfs)
          uds)
      #/snippet-sys-shape-snippet-sys uss))
    ; snippet-sys-snippet-degree
    (fn ss snippet
      (dissect ss (selective-snippet-sys sfs uds _)
      #/expect snippet (selective-snippet-nonzero d content)
        (dim-sys-dim-zero uds)
        d))
    ; snippet-sys-shape->snippet
    (fn ss shape
      (dissect ss (selective-snippet-sys sfs uds _)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- uss
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss uds)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- ess
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss eds)
      #/w- unextended-snippet (snippet-sys-shape->snippet uss shape)
      #/w- d (snippet-sys-snippet-degree uss unextended-snippet)
      #/if (dim-sys-dim=0? uds d)
        (selective-snippet-zero unextended-snippet)
      #/w- extended-snippet
        (snippet-sys-morphism-sys-morph-snippet
          (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys-morphism-sys
            ffdstsss
            (extend-with-top-dim-sys-morphism-sys uds))
          unextended-snippet)
      #/expect
        (snippet-sys-snippet-set-degree-maybe ess
          (extended-with-top-dim-infinite)
          extended-snippet)
        (just content)
        ; TODO: Improve this error. If this can occur at all, it must
        ; occur when one of the systems involved doesn't obey its
        ; laws.
        (error "Expected an extended-with-top snippet-sys to always allow setting the degree of a snippet to infinity")
      #/selective-snippet-nonzero d content))
    ; snippet-sys-snippet->maybe-shape
    (fn ss snippet
      (dissect ss (selective-snippet-sys sfs uds _)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- uss
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss uds)
      #/w- ess
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss eds)
      #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
      #/mat snippet (selective-snippet-zero content)
        (snippet-sys-snippet->maybe-shape uss content)
      #/dissect snippet (selective-snippet-nonzero d content)
      #/maybe-bind (snippet-sys-snippet->maybe-shape ess content)
      #/fn shape
      #/maybe-bind
        (snippet-sys-snippet-map-maybe shape-ess shape #/fn hole data
          (expect data (selected data) (nothing)
          #/just data))
      #/fn shape
      #/expect
        (snippet-sys-snippet-set-degree-maybe shape-ess
          (extended-with-top-dim-finite d)
          shape)
        (just shape)
        ; TODO: Improve this error. If this can occur at all, it must
        ; occur when one of the systems involved doesn't obey its
        ; laws.
        (error "Expected an extended-with-top snippet-sys to always allow setting the degree of a snippet to a finite degree if that snippet had holes of only lesser degree")
      #/snippet-sys-morphism-sys-morph-snippet
        (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
          (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys-morphism-sys
            ffdstsss
            (unextend-with-top-dim-sys-morphism-sys uds)))
        shape))
    ; snippet-sys-snippet-set-degree-maybe
    (fn ss new-degree snippet
      (dissect ss (selective-snippet-sys sfs uds _)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- ess
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss eds)
      #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
      #/expect snippet (selective-snippet-nonzero d content)
        (maybe-if (dim-sys-dim=0? uds new-degree) #/fn snippet)
      #/expect (dim-sys-dim=0? uds new-degree) #f (nothing)
      #/expect
        (snippet-sys-snippet-all? ess content #/fn hole data
          (expect data (selected data) #t
          #/dim-sys-dim<? eds
            (snippet-sys-snippet-degree shape-ess hole)
            (extended-with-top-dim-finite new-degree)))
        #t
        (nothing)
      #/just #/selective-snippet-nonzero new-degree content))
    ; snippet-sys-snippet-done
    (fn ss degree shape data
      (dissect ss (selective-snippet-sys sfs uds _)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- ess
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss eds)
      #/w- extend
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys-morphism-sys
          ffdstsss
          (extend-with-top-dim-sys-morphism-sys uds))
      #/expect
        (snippet-sys-snippet-set-degree-maybe ess
          (extended-with-top-dim-infinite)
          (snippet-sys-morphism-sys-morph-snippet extend
            (snippet-sys-snippet-select-everything
              (snippet-sys-snippet-done ess degree
                (snippet-sys-morphism-sys-morph-snippet
                  (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
                    extend)
                  shape)
                data))))
        (just content)
        ; TODO: Improve this error. If this can occur at all, it must
        ; occur when one of the systems involved doesn't obey its
        ; laws.
        (error "Expected an extended-with-top snippet-sys to always allow setting the degree of a nonzero-degree snippet to infinity")
      #/selective-snippet-nonzero degree content))
    ; snippet-sys-snippet-undone
    (fn ss snippet
      (dissect ss (selective-snippet-sys sfs uds _)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- uss
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss uds)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- ess
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss eds)
      #/expect snippet (selective-snippet-nonzero d content) (nothing)
      #/maybe-bind
        (snippet-sys-snippet-map-maybe ess content #/fn hole data
          (expect data (selected data) (nothing)
          #/just data))
      #/fn content
      #/snippet-sys-snippet-undone uss
        (snippet-sys-morphism-sys-morph-snippet
          (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys-morphism-sys
            ffdstsss
            (unextend-with-top-dim-sys-morphism-sys uds))
          content)))
    ; snippet-sys-snippet-splice
    (fn ss snippet hv-to-splice
      (dissect ss (selective-snippet-sys sfs uds _)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- ess
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss eds)
      #/expect snippet (selective-snippet-nonzero d prefix)
        (just snippet)
      #/w- unextend-hole
        (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
          (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys-morphism-sys
            ffdstsss
            (unextend-with-top-dim-sys-morphism-sys uds)))
      #/maybe-map
        (snippet-sys-snippet-splice ess prefix
        #/fn extended-hole data
          (mat data (unselected data)
            (just #/unselected #/unselected data)
          #/dissect data (selected data)
          #/w- unextended-hole
            (snippet-sys-morphism-sys-morph-snippet
              unextend-hole extended-hole)
          #/maybe-map (hv-to-splice unextended-hole data) #/fn splice
            (mat splice (unselected data) (unselected #/selected data)
            #/dissect splice
              (selected #/selective-snippet-nonzero d suffix)
            #/selected
              (snippet-sys-snippet-map ess suffix #/fn hole data
                (mat data (unselected data)
                  (unselected #/unselected data)
                #/dissect data (selected data)
                #/mat data (unselected data)
                  (unselected #/selected data)
                #/dissect data (selected #/trivial)
                #/selected #/trivial)))))
      #/fn snippet
        (selective-snippet-nonzero d snippet)))
    ; snippet-sys-snippet-zip-map-selective
    (fn ss shape snippet hvv-to-maybe-v
      (dissect ss (selective-snippet-sys sfs uds _)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- uss
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss uds)
      #/w- ess
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss eds)
      #/mat snippet (selective-snippet-zero subject)
        (maybe-map
          (snippet-sys-snippet-zip-map-selective uss shape subject
            hvv-to-maybe-v)
        #/fn snippet
          (selective-snippet-zero snippet))
      #/dissect snippet (selective-snippet-nonzero d subject)
      #/w- unextend-hole
        (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
          (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys-morphism-sys
            ffdstsss
            (unextend-with-top-dim-sys-morphism-sys uds)))
      #/maybe-map
        (snippet-sys-snippet-zip-map-selective ess
          (snippet-sys-morphism-sys-morph-snippet
            (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
              (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys-morphism-sys
                ffdstsss
                (extend-with-top-dim-sys-morphism-sys uds)))
            shape)
          (snippet-sys-snippet-map ess subject #/fn hole data
            (mat data (unselected data) (unselected #/unselected data)
            #/dissect data (selected data)
            #/mat data (unselected data) (unselected #/selected data)
            #/dissect data (selected data) (selected data)))
        #/fn extended-hole shape-data subject-data
          (w- unextended-hole
            (snippet-sys-morphism-sys-morph-snippet
              unextend-hole extended-hole)
          #/maybe-map
            (hvv-to-maybe-v unextended-hole shape-data subject-data)
          #/fn result-data
            (selected result-data)))
      #/fn snippet
        (selective-snippet-nonzero d snippet)))))

; TODO: Export this.
; TODO: Use the things that use this.
;
; TODO: See if there's a more specific term than "apply to" we can use
; here. This isn't whiskering, is it?
;
; TODO: See if we should place this somewhere else in the file, e.g.
; closer to `snippet-format-sys-morphism-sys?`.
;
(define
  (snippet-format-sys-morphism-sys-apply-to-dim-sys-morphism-sys
    sfsms dsms)
  (snippet-sys-morphism-sys-chain-two
    (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-transfer-to-snippet-sys-morphism-sys
      (snippet-format-sys-morphism-sys-functor-morphism sfsms)
      (dim-sys-morphism-sys-source dsms))
    (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys-morphism-sys
      (snippet-format-sys-functor
        (snippet-format-sys-morphism-sys-target sfsms))
      dsms)))

; TODO: Export this.
; TODO: Use the things that use this.
(define (selective-snippet-map-all sfsms dsms s)
  (w- make-ssms
    (fn dsms
      (snippet-format-sys-morphism-sys-apply-to-dim-sys-morphism-sys
        sfsms dsms))
  #/mat s (selective-snippet-zero content)
    (selective-snippet-zero
      (snippet-sys-morphism-sys-morph-snippet (make-ssms dsms)
        content))
  #/dissect s (selective-snippet-nonzero d content)
    (selective-snippet-nonzero
      (dim-sys-morphism-sys-morph-dim
        (snippet-sys-morphism-sys-dim-sys-morphism-sys
          (make-ssms dsms))
        d)
      (snippet-sys-morphism-sys-morph-snippet
        (make-ssms #/extended-with-top-dim-sys-morphism-sys dsms)
        content))))

; TODO: Export these.
; TODO: Use these.
;
; TODO: See if this can somehow have endpoints with meaningful
; `h-to-unselected/c` information.
;
(define-imitation-simple-struct
  (selective-map-all-snippet-sys-morphism-sys?
    selective-map-all-snippet-sys-morphism-sys-snippet-format-sys-morphism-sys
    selective-map-all-snippet-sys-morphism-sys-dim-sys-morphism-sys)
  selective-map-all-snippet-sys-morphism-sys
  'selective-map-all-snippet-sys-morphism-sys
  (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn
        (selective-map-all-snippet-sys-morphism-sys sfsms dsms)
        (match/c selective-map-all-snippet-sys-morphism-sys
          (ok/c sfsms)
          (ok/c dsms)))))
  (#:prop prop:snippet-sys-morphism-sys
    (make-snippet-sys-morphism-sys-impl-from-morph
      ; snippet-sys-morphism-sys-source
      (dissectfn
        (selective-map-all-snippet-sys-morphism-sys sfsms dsms)
        (selective-snippet-sys
          (snippet-format-sys-morphism-sys-source sfsms)
          (dim-sys-morphism-sys-source dsms)
          (fn hole any/c)))
      ; snippet-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms
          (selective-map-all-snippet-sys-morphism-sys sfsms dsms)
        #/expect new-s (selective-snippet-sys new-s-sfs new-s-ds _)
          (w- s
            (selective-snippet-sys
              (snippet-format-sys-morphism-sys-source sfsms)
              (dim-sys-morphism-sys-source dsms)
              (fn hole any/c))
          #/raise-arguments-error
            'snippet-sys-morphism-sys-replace-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/selective-map-all-snippet-sys-morphism-sys
          (snippet-format-sys-morphism-sys-replace-source
            sfsms new-s-sfs)
          (dim-sys-morphism-sys-replace-source dsms new-s-ds)))
      ; snippet-sys-morphism-sys-target
      (dissectfn
        (selective-map-all-snippet-sys-morphism-sys sfsms dsms)
        (selective-snippet-sys
          (snippet-format-sys-morphism-sys-target sfsms)
          (dim-sys-morphism-sys-target dsms)
          (fn hole any/c)))
      ; snippet-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms
          (selective-map-all-snippet-sys-morphism-sys sfsms dsms)
        #/expect new-t (selective-snippet-sys new-t-sfs new-t-ds _)
          (w- t
            (selective-snippet-sys
              (snippet-format-sys-morphism-sys-target sfsms)
              (dim-sys-morphism-sys-target dsms)
              (fn hole any/c))
          #/raise-arguments-error
            'snippet-sys-morphism-sys-replace-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/selective-map-all-snippet-sys-morphism-sys
          (snippet-format-sys-morphism-sys-replace-target
            sfsms new-t-sfs)
          (dim-sys-morphism-sys-replace-target dsms new-t-ds)))
      ; snippet-sys-morphism-sys-dim-sys-morphism-sys
      (dissectfn
        (selective-map-all-snippet-sys-morphism-sys sfsms dsms)
        dsms)
      ; snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
      (dissectfn
        (selective-map-all-snippet-sys-morphism-sys sfsms dsms)
        (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
          (snippet-format-sys-morphism-sys-apply-to-dim-sys-morphism-sys
            sfsms dsms)))
      ; snippet-sys-morphism-sys-morph-snippet
      (fn ms s
        (dissect ms
          (selective-map-all-snippet-sys-morphism-sys sfsms dsms)
        #/selective-snippet-map-all sfsms dsms s)))))

; TODO: Export these.
; TODO: Use these.
;
; TODO: See if this can somehow involve meaningful `h-to-unselected/c`
; information.
;
(define-imitation-simple-struct
  (selective-functor-from-dim-sys-to-snippet-sys-sys?
    selective-functor-from-dim-sys-to-snippet-sys-sys-snippet-format-sys)
  selective-functor-from-dim-sys-to-snippet-sys-sys
  'selective-functor-from-dim-sys-to-snippet-sys-sys
  (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:functor-from-dim-sys-to-snippet-sys-sys
    (make-functor-from-dim-sys-to-snippet-sys-sys-impl-from-morph
      ; functor-from-dim-sys-to-snippet-sys-sys-accepts/c
      (dissectfn
        (selective-functor-from-dim-sys-to-snippet-sys-sys sfs)
        (match/c selective-functor-from-dim-sys-to-snippet-sys-sys
          (ok/c sfs)))
      ; functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
      (fn fs ds
        (dissect fs
          (selective-functor-from-dim-sys-to-snippet-sys-sys sfs)
        #/selective-snippet-sys sfs ds (fn h any/c)))
      ; functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys-morphism-sys
      (fn fs dsms
        (dissect fs
          (selective-functor-from-dim-sys-to-snippet-sys-sys sfs)
        #/selective-map-all-snippet-sys-morphism-sys
          (snippet-format-sys-morphism-sys-identity sfs)
          dsms)))))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (selective-snippet-format-sys?
    selective-snippet-format-sys-original)
  selective-snippet-format-sys
  'selective-snippet-format-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (selective-snippet-format-sys orig-sfs)
        (match/c selective-snippet-format-sys #/ok/c orig-sfs))))
  (#:prop prop:snippet-format-sys
    (make-snippet-format-sys-impl-from-functor
      ; snippet-format-sys-functor
      (dissectfn (selective-snippet-format-sys orig-sfs)
        (selective-functor-from-dim-sys-to-snippet-sys-sys
          orig-sfs)))))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
    selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-snippet-format-sys-morphism-sys)
  selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
  'selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
  (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
    (make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-transfer
      ; functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-accepts/c
      (dissectfn
        (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          sfsms)
        (match/c
          selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          (ok/c sfsms)))
      ; functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
      (dissectfn
        (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          sfsms)
        (selective-functor-from-dim-sys-to-snippet-sys-sys
          (snippet-format-sys-morphism-sys-source sfsms)))
      ; functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms
          (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
            sfsms)
        #/expect new-s
          (selective-functor-from-dim-sys-to-snippet-sys-sys new-s)
          (w- s
            (selective-functor-from-dim-sys-to-snippet-sys-sys
              (snippet-format-sys-morphism-sys-source sfsms))
          #/raise-arguments-error
            'functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-replace-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          (snippet-format-sys-morphism-sys-replace-source
            sfsms new-s)))
      ; functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
      (dissectfn
        (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          sfsms)
        (selective-functor-from-dim-sys-to-snippet-sys-sys
          (snippet-format-sys-morphism-sys-target sfsms)))
      ; functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms
          (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
            sfsms)
        #/expect new-t
          (selective-functor-from-dim-sys-to-snippet-sys-sys new-t)
          (w- t
            (selective-functor-from-dim-sys-to-snippet-sys-sys
              (snippet-format-sys-morphism-sys-target sfsms))
          #/raise-arguments-error 'functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-replace-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          (snippet-format-sys-morphism-sys-replace-target
            sfsms new-t)))
      ; functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-transfer-to-snippet-sys-morphism-sys
      (fn ms ds
        (dissect ms
          (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
            sfsms)
        #/selective-map-all-snippet-sys-morphism-sys
          sfsms
          (dim-sys-morphism-sys-identity ds))))))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (selective-snippet-format-sys-morphism-sys?
    selective-snippet-format-sys-morphism-sys-original)
  selective-snippet-format-sys-morphism-sys
  'selective-snippet-format-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn
        (selective-snippet-format-sys-morphism-sys orig-sfsms)
        (match/c selective-snippet-format-sys-morphism-sys
          (ok/c orig-sfsms)))))
  (#:prop prop:snippet-format-sys-morphism-sys
    (make-snippet-format-sys-morphism-sys-impl-from-morph
      ; snippet-format-sys-morphism-sys-source
      (dissectfn
        (selective-snippet-format-sys-morphism-sys orig-sfsms)
        (selective-snippet-format-sys
          (snippet-format-sys-morphism-sys-source orig-sfsms)))
      ; snippet-format-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms
          (selective-snippet-format-sys-morphism-sys orig-sfsms)
        #/expect new-s (selective-snippet-format-sys new-s)
          (w- s
            (selective-snippet-format-sys
              (snippet-format-sys-morphism-sys-source orig-sfsms))
          #/raise-arguments-error
            'snippet-format-sys-morphism-sys-replace-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/selective-snippet-format-sys-morphism-sys
          (snippet-format-sys-morphism-sys-replace-source
            orig-sfsms new-s)))
      ; snippet-format-sys-morphism-sys-target
      (dissectfn
        (selective-snippet-format-sys-morphism-sys orig-sfsms)
        (selective-snippet-format-sys
          (snippet-format-sys-morphism-sys-target orig-sfsms)))
      ; snippet-format-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms
          (selective-snippet-format-sys-morphism-sys orig-sfsms)
        #/expect new-t (selective-snippet-format-sys new-t)
          (w- t
            (selective-snippet-format-sys
              (snippet-format-sys-morphism-sys-target orig-sfsms))
          #/raise-arguments-error
            'snippet-format-sys-morphism-sys-replace-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/selective-snippet-format-sys-morphism-sys
          (snippet-format-sys-morphism-sys-replace-target
            orig-sfsms new-t)))
      ; snippet-format-sys-morphism-sys-morph-snippet-functor-morphism
      (dissectfn
        (selective-snippet-format-sys-morphism-sys orig-sfsms)
        (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          orig-sfsms)))))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (selective-snippet-format-sys-endofunctor-sys?)
  selective-snippet-format-sys-endofunctor-sys
  'selective-snippet-format-sys-endofunctor-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:snippet-format-sys-endofunctor-sys
    (make-snippet-format-sys-endofunctor-sys-impl-from-morph
      ; snippet-format-sys-endofunctor-sys-accepts/c
      (fn es selective-snippet-format-sys-endofunctor-sys?)
      ; snippet-format-sys-endofunctor-sys-morph-snippet-format-sys
      (fn es sfs #/selective-snippet-format-sys sfs)
      ; snippet-format-sys-endofunctor-sys-morph-snippet-format-sys-morphism-sys
      (fn es ms #/selective-snippet-format-sys-morphism-sys ms))))


; TODO: Consider rearranging everything in this file, but especially
; the things below. Currently the file is in three parts: The things
; needed for `selective-snippet-sys?`, the things needed for
; `hypertee-snippet-sys?`, and the things needed for
; `hypernest-snippet-sys?`. Each time, some generic `snippet-sys?`
; utilities are added, but as we have more code that uses
; `snippet-sys?` values, we'll probably want to maintain all the
; generic `snippet-sys?` utilities in one place.


; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-zip-map ss shape snippet hvv-to-maybe-v)
  (w- snippet (snippet-sys-snippet-select-everything ss snippet)
  #/snippet-sys-snippet-zip-map-selective
    ss shape snippet hvv-to-maybe-v))

; TODO: See if this should have the question mark in its name.
; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-zip-all? ss shape snippet check-hvv?)
  (w- snippet (snippet-sys-snippet-select-everything ss snippet)
  #/snippet-sys-snippet-zip-all-selective?
    ss shape snippet check-hvv?))

; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-shape=? ss a b hvv=?)
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/snippet-sys-snippet-zip-all? shape-ss a b #/fn hole a-data b-data
    (hvv=? hole a-data b-data)))

; TODO: Find a better name for this.
; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-filter-maybe ss snippet)
  (w- ds (snippet-sys-dim-sys ss)
  #/w- d (snippet-sys-snippet-degree ss snippet)
  #/snippet-sys-snippet-splice ss snippet #/fn hole data
    (mat data (selected data) (just #/unselected data)
    #/dissect data (unselected data)
    #/maybe-map
      (snippet-sys-snippet-set-degree-maybe ss d
        (snippet-sys-shape->snippet ss hole))
    #/fn patch
      (selected #/snippet-sys-snippet-select-everything ss patch))))

; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-map-selective ss snippet hv-to-v)
  (snippet-sys-snippet-map ss snippet #/fn hole data
    (mat data (unselected data) data
    #/dissect data (selected data) (hv-to-v hole data))))


; TODO: Export these.
; TODO: Use the things that use these.
(define-imitation-simple-struct
  (hypertee-coil-zero?)
  hypertee-coil-zero
  'hypertee-coil-zero (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct
  (hypertee-coil-hole?
    hypertee-coil-hole-overall-degree
    hypertee-coil-hole-hole
    hypertee-coil-hole-data
    hypertee-coil-hole-tails)
  hypertee-coil-hole
  'hypertee-coil-hole (current-inspector) (auto-write) (auto-equal))
; TODO: Define `hypertee-furl` in terms of `hypertee-furl-unchecked`.
; TODO: Change the way a `hypertee?` is written using
; `gen:custom-write`.
(define-imitation-simple-struct
  (hypertee? hypertee-dim-sys hypertee-unfurl)
  hypertee-furl-unchecked
  'hypertee (current-inspector) (auto-write) (auto-equal))

; TODO: Export this.
; TODO: Use the things that use this.
(define (hypertee/c ds)
  (rename-contract (match/c hypertee-furl-unchecked (ok/c ds) any/c)
    `(hypertee/c ,ds)))

; TODO: See if we should export this.
; TODO: Use the things that use this.
(define (hypertee-map-cps ds state ht on-hole then)
  (w- ss (hypertee-snippet-sys ds)
  #/dissect ht (hypertee-furl-unchecked _ coil)
  #/mat coil (hypertee-coil-zero)
    (then state #/hypertee-furl-unchecked ds #/hypertee-coil-zero)
  #/dissect coil (hypertee-coil-hole d hole data tails)
  #/on-hole state hole data #/fn state data
  #/hypertee-map-cps ds state tails
    (fn state hole tail then
      (w- d (snippet-sys-snippet-degree ss hole)
      #/hypertee-map-cps ds state tail
        (fn state hole data then
          (if
            (dim-sys-dim<? ds
              (snippet-sys-snippet-degree ss hole)
              d)
            (dissect data (trivial)
              (then state #/trivial))
            (on-hole state hole data then)))
        then))
  #/fn state tails
  #/then state #/hypertee-furl-unchecked ds
    (hypertee-coil-hole d hole data tails)))

; TODO: See if we should export this.
; TODO: Use the things that use this.
(define (hypertee-each-cps ds state ht on-hole then)
  
  ; TODO: Pick just one of these implementations.
  
  #;
  (hypertee-map-cps ds state ht
    (fn state hole data then
      (on-hole state hole data #/fn state
      #/then state data))
  #/fn state mapped
  #/then state)
  
  (w- ss (hypertee-snippet-sys ds)
  #/dissect ht (hypertee-furl-unchecked _ coil)
  #/mat coil (hypertee-coil-zero) (then state)
  #/dissect coil (hypertee-coil-hole d hole data tails)
  #/on-hole state hole data #/fn state
  #/hypertee-each-cps ds state tails
    (fn state hole tail then
      (w- d (snippet-sys-snippet-degree ss hole)
      #/hypertee-each-cps ds state tail
        (fn state hole data then
          (if
            (dim-sys-dim<? ds
              (snippet-sys-snippet-degree ss hole)
              d)
            (dissect data (trivial)
              (then state))
            (on-hole state hole data then)))
        then))
      then))

; TODO: See if we should export this.
; TODO: Use the things that use this.
(define (hypertee-each-ltr ds state ht on-hole)
  (hypertee-each-cps ds state ht
    (fn state hole data then #/then #/on-hole state hole data)
  #/fn state
    state))

(define (hypertee-zip-map ds shape snippet hvv-to-maybe-v)
  (w- ss (hypertee-snippet-sys ds)
  #/dissect shape (hypertee-furl-unchecked _ shape-coil)
  #/dissect snippet (hypertee-furl-unchecked _ snippet-coil)
  #/mat shape-coil (hypertee-coil-zero)
    (expect snippet-coil (hypertee-coil-zero) (nothing)
    #/just #/hypertee-furl-unchecked ds #/hypertee-coil-zero)
  #/dissect shape-coil
    (hypertee-coil-hole shape-d shape-hole shape-data shape-tails)
  #/expect snippet-coil
    (hypertee-coil-hole
      snippet-d snippet-hole snippet-data snippet-tails)
    (nothing)
  #/expect (dim-sys-dim=? ds shape-d snippet-d) #t (nothing)
  #/expect
    (snippet-sys-shape=? ss shape-hole snippet-hole
    #/fn hole shape-data snippet-data
      (dissect shape-data (trivial)
      #/dissect snippet-data (trivial)
        #t))
    #t
    (nothing)
  #/maybe-bind (hvv-to-maybe-v shape-hole shape-data snippet-data)
  #/fn result-data
  #/maybe-bind
    (snippet-sys-snippet-zip-map ss shape-tails snippet-tails
    #/fn hole shape-tail snippet-tail
      (w- d (snippet-sys-snippet-degree ss hole)
      #/snippet-sys-snippet-zip-map-selective ss
        shape-tail
        (snippet-sys-snippet-map ss snippet-tail #/fn hole data
          (if
            (dim-sys-dim<? ds (snippet-sys-snippet-degree ss hole) d)
            (dissect data (trivial)
              (selected #/trivial))
            data))
      #/fn hole shape-data snippet-data
        (if (dim-sys-dim<? ds (snippet-sys-snippet-degree ss hole) d)
          (dissect shape-data (trivial)
          #/dissect snippet-data (trivial)
            (just #/trivial))
          (hvv-to-maybe-v hole shape-data snippet-data))))
  #/fn result-tails
  #/just #/hypertee-furl-unchecked ds
    (hypertee-coil-hole shape-d shape-hole result-data result-tails)))

; TODO: See if we should export this.
; TODO: Use the things that use this.
(define (hypertee-map-dim dsms ht)
  (w- target-ds (dim-sys-morphism-sys-target dsms)
  #/w- target-ss (hypertee-snippet-sys target-ds)
  #/dissect ht (hypertee-furl-unchecked _ coil)
  #/hypertee-furl-unchecked target-ds
    (mat coil (hypertee-coil-zero) (hypertee-coil-zero)
    #/dissect coil (hypertee-coil-hole d hole data tails)
    #/hypertee-coil-hole
      (dim-sys-morphism-sys-morph-dim dsms d)
      (hypertee-map-dim dsms hole)
      data
      (snippet-sys-snippet-map target-ss (hypertee-map-dim dsms tails)
        (fn hole tail #/hypertee-map-dim dsms tail)))))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (hypertee-snippet-sys? hypertee-snippet-sys-dim-sys)
  hypertee-snippet-sys
  'hypertee-snippet-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (hypertee-snippet-sys ds)
        (match/c hypertee-snippet-sys #/ok/c ds))))
  (#:prop prop:snippet-sys #/make-snippet-sys-impl-from-various-1
    ; snippet-sys-snippet/c
    (dissectfn (hypertee-snippet-sys ds)
      (hypertee/c ds))
    ; snippet-sys-dim-sys
    (dissectfn (hypertee-snippet-sys ds)
      ds)
    ; snippet-sys-shape-snippet-sys
    (fn ss
      ss)
    ; snippet-sys-snippet-degree
    (fn ss snippet
      (dissect ss (hypertee-snippet-sys ds)
      #/dissect snippet (hypertee-furl-unchecked _ coil)
      #/mat coil (hypertee-coil-zero) (dim-sys-dim-zero ds)
      #/dissect coil (hypertee-coil-hole d hole data tails) d))
    ; snippet-sys-shape->snippet
    (fn ss shape
      shape)
    ; snippet-sys-snippet->maybe-shape
    (fn ss snippet
      (just snippet))
    ; snippet-sys-snippet-set-degree-maybe
    (fn ss degree snippet
      (dissect ss (hypertee-snippet-sys ds)
      #/dissect snippet (hypertee-furl-unchecked _ coil)
      #/mat coil (hypertee-coil-zero)
        (expect (dim-sys-dim=0? ds degree) #t (nothing)
        #/just #/hypertee-furl-unchecked ds #/hypertee-coil-zero)
      #/dissect coil (hypertee-coil-hole d hole data tails)
        (expect
          (and
            (not #/dim-sys-dim=0? ds degree)
            (dim-sys-dim<? ds
              (snippet-sys-snippet-degree ss hole)
              degree))
          #t
          (nothing)
        #/maybe-map
          (snippet-sys-snippet-map-maybe ss tails #/fn hole tail
            (snippet-sys-snippet-set-degree-maybe ss degree tail))
        #/fn tails
          (hypertee-furl-unchecked ds
            (hypertee-coil-hole d hole data tails)))))
    ; snippet-sys-snippet-done
    (fn ss degree shape data
      (dissect ss (hypertee-snippet-sys ds)
      #/hypertee-furl-unchecked ds #/hypertee-coil-hole
        degree
        (snippet-sys-snippet-map ss shape #/fn hole data #/trivial)
        data
        (snippet-sys-snippet-map ss shape #/fn hole data
          (snippet-sys-snippet-done ss degree hole data))))
    ; snippet-sys-snippet-undone
    (fn ss snippet
      (dissect ss (hypertee-snippet-sys ds)
      #/dissect snippet (hypertee-furl-unchecked _ coil)
      #/expect coil (hypertee-coil-hole d hole data tails) (nothing)
      #/maybe-map
        (snippet-sys-snippet-map-maybe ss tails #/fn hole tail
          (maybe-bind (snippet-sys-snippet-undone ss tail)
          #/dissectfn (list tail-d tail-shape data)
          #/expect
            (and
              (dim-sys-dim=? ds d tail-d)
              (snippet-sys-shape=? ss hole tail-shape
              #/fn hole hole-data tail-shape-data
                (dissect hole-data (trivial)
                #/dissect tail-shape-data (trivial)
                  #t)))
            #t
            (nothing)
          #/just data))
      #/fn shape
        (list d shape data)))
    ; snippet-sys-snippet-splice
    (fn ss snippet hv-to-splice
      (dissect ss (hypertee-snippet-sys ds)
      #/w-loop next
        snippet snippet
        first-nontrivial-d (dim-sys-dim-zero ds)
        
        (dissect snippet (hypertee-furl-unchecked _ coil)
        #/mat coil (hypertee-coil-zero)
          (just #/hypertee-furl-unchecked ds #/hypertee-coil-zero)
        #/dissect coil (hypertee-coil-hole d hole data tails)
        #/maybe-bind
          (if
            (dim-sys-dim<? ds
              (snippet-sys-snippet-degree ss hole)
              first-nontrivial-d)
            (dissect data (trivial)
              (unselected #/trivial))
            (hv-to-splice hole data))
        #/fn splice
        #/mat splice (unselected data)
          (maybe-bind
            (snippet-sys-snippet-map ss tails #/fn hole tail
              (next tail
                (dim-sys-dim-max ds
                  first-nontrivial-d
                  (snippet-sys-snippet-degree ss hole))))
          #/fn tails
          #/just #/hypertee-furl-unchecked ds
            (hypertee-coil-hole d hole data tails))
        #/dissect splice (selected suffix)
        #/w- suffix
          (snippet-sys-snippet-map ss suffix #/fn hole data
            (expect data (unselected data) data
            #/unselected #/unselected data))
        #/maybe-map
          (snippet-sys-snippet-zip-map-selective ss tails suffix
          #/fn hole tail data
            (dissect data (trivial)
              tail))
        #/fn suffix
          (snippet-sys-snippet-bind ss suffix #/fn hole data data))))
    ; snippet-sys-snippet-zip-map-selective
    (fn ss shape snippet hvv-to-maybe-v
      
      ; TODO: See if we can implement this in a more direct style like
      ; `hypertee-zip-map` rather than using `hypertee-map-cps`.
      ;
      ; When the first hole was `selected`, the implementation would
      ; be just like `hypertee-zip-map`.
      ;
      ; When the first hole was `unselected`, we would have to do
      ; something like this: Join the `tails` as a `selective-snippet`
      ; with some unselected holes in between, zip it again that way,
      ; and then parse those unselected holes to turn the result back
      ; into a replacement for `tails`.
      
      (dissect ss (hypertee-snippet-sys ds)
      #/w- numbered-snippet
        (hypertee-map-cps ds 0 snippet
          (fn state hole data then
            (mat data (unselected data)
              (then state #/unselected data)
            #/dissect data (selected data)
              (then (add1 state) #/selected #/list state data)))
        #/fn state numbered-snippet
          numbered-snippet)
      #/maybe-bind
        (snippet-sys-snippet-filter-maybe ss numbered-snippet)
      #/fn filtered-numbered-snippet
      #/maybe-bind
        (hypertee-zip-map ds shape filtered-numbered-snippet
        #/fn hole shape-data snippet-data
          (dissect snippet-data (list i snippet-data)
          #/maybe-map (hvv-to-maybe-v shape-data snippet-data)
          #/fn result-data
            (list i result-data)))
      #/fn filtered-numbered-result
      #/w- env
        (hypertee-each-ltr ds (make-immutable-hasheq)
          filtered-numbered-result
        #/fn env hole data
          (dissect data (list i data)
          #/hash-set env i data))
      #/snippet-sys-snippet-map-selective ss numbered-snippet
      #/fn hole data
        (dissect data (list i data)
        #/hash-ref env i)))))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (hypertee-map-dim-snippet-sys-morphism-sys?
    hypertee-map-dim-snippet-sys-morphism-sys-dim-sys-morphism-sys)
  hypertee-map-dim-snippet-sys-morphism-sys
  'hypertee-map-dim-snippet-sys-morphism-sys
  (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        (match/c hypertee-map-dim-snippet-sys-morphism-sys
          (ok/c dsms)))))
  (#:prop prop:snippet-sys-morphism-sys
    (make-snippet-sys-morphism-sys-impl-from-morph
      ; snippet-sys-morphism-sys-source
      (dissectfn (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        (hypertee-snippet-sys #/dim-sys-morphism-sys-source dsms))
      ; snippet-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        #/expect new-s (hypertee-snippet-sys new-s)
          (w- s
            (hypertee-snippet-sys #/dim-sys-morphism-sys-source dsms)
          #/raise-arguments-error
            'snippet-sys-morphism-sys-replace-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/hypertee-map-dim-snippet-sys-morphism-sys
          (dim-sys-morphism-sys-replace-source dsms new-s)))
      ; snippet-sys-morphism-sys-target
      (dissectfn (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        (hypertee-snippet-sys #/dim-sys-morphism-sys-target dsms))
      ; snippet-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        #/expect new-t (hypertee-snippet-sys new-t)
          (w- t
            (hypertee-snippet-sys #/dim-sys-morphism-sys-target dsms)
          #/raise-arguments-error
            'snippet-sys-morphism-sys-replace-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/hypertee-map-dim-snippet-sys-morphism-sys
          (dim-sys-morphism-sys-replace-target dsms new-t)))
      ; snippet-sys-morphism-sys-dim-sys-morphism-sys
      (dissectfn (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        dsms)
      ; snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
      (fn ms ms)
      ; snippet-sys-morphism-sys-morph-snippet
      (fn ms s
        (dissect ms (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        #/hypertee-map-dim dsms s)))))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (hypertee-functor-from-dim-sys-to-snippet-sys-sys?)
  hypertee-functor-from-dim-sys-to-snippet-sys-sys
  'hypertee-functor-from-dim-sys-to-snippet-sys-sys
  (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:functor-from-dim-sys-to-snippet-sys-sys
    (make-functor-from-dim-sys-to-snippet-sys-sys-impl-from-morph
      ; functor-from-dim-sys-to-snippet-sys-sys-accepts/c
      (dissectfn _ hypertee-functor-from-dim-sys-to-snippet-sys-sys?)
      ; functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
      (fn fs ds #/hypertee-snippet-sys ds)
      ; functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys-morphism-sys
      (fn fs ms #/hypertee-map-dim-snippet-sys-morphism-sys ms))))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (hypertee-snippet-format-sys?)
  hypertee-snippet-format-sys
  'hypertee-snippet-format-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn _ hypertee-snippet-format-sys?)))
  (#:prop prop:snippet-format-sys
    (make-snippet-format-sys-impl-from-functor
      ; snippet-format-sys-functor
      (dissectfn _
        (hypertee-functor-from-dim-sys-to-snippet-sys-sys)))))


; TODO: Find a better name for this.
; TODO: Export this.
; TODO: Use the things that use this.
(define
  (make-snippet-sys-impl-from-conversions
    snippet-sys-snippet/c ss-> snippet-> ->snippet)
  (make-snippet-sys-impl-from-various-1
    ; snippet-sys-snippet/c
    snippet-sys-snippet/c
    ; snippet-sys-dim-sys
    (fn ss
      (snippet-sys-dim-sys #/ss-> ss))
    ; snippet-sys-shape-snippet-sys
    (fn ss
      (snippet-sys-shape-snippet-sys #/ss-> ss))
    ; snippet-sys-snippet-degree
    (fn ss snippet
      (snippet-sys-snippet-degree (ss-> ss) (snippet-> snippet)))
    ; snippet-sys-shape->snippet
    (fn ss shape
      (->snippet #/snippet-sys-shape->snippet (ss-> ss) shape))
    ; snippet-sys-snippet->maybe-shape
    (fn ss snippet
      (snippet-sys-snippet->maybe-shape (ss-> ss)
        (snippet-> snippet)))
    ; snippet-sys-snippet-set-degree-maybe
    (fn ss degree snippet
      (maybe-map
        (snippet-sys-snippet-set-degree-maybe (ss-> ss) degree
          (snippet-> snippet))
      #/fn selective
        (->snippet selective)))
    ; snippet-sys-snippet-done
    (fn ss degree shape data
      (->snippet #/snippet-sys-snippet-done (ss-> ss)
        degree shape data))
    ; snippet-sys-snippet-undone
    (fn ss snippet
      (snippet-sys-snippet-undone (ss-> ss) (snippet-> snippet)))
    ; snippet-sys-snippet-splice
    (fn ss snippet hv-to-splice
      (maybe-map
        (snippet-sys-snippet-splice (ss-> ss) (snippet-> snippet)
        #/fn hole data
          (maybe-map (hv-to-splice hole data) #/fn data
            (mat data (unselected data) (unselected data)
            #/dissect data (selected suffix)
            #/selected #/snippet-> suffix)))
      #/fn snippet
        (snippet-> snippet)))
    ; snippet-sys-snippet-zip-map-selective
    (fn ss shape snippet hvv-to-maybe-v
      (maybe-map
        (snippet-sys-snippet-zip-map-selective (ss-> ss)
          shape (snippet-> snippet) hvv-to-maybe-v)
      #/fn selective
        (snippet-> selective)))))


; TODO: Export this.
; TODO: Use the things that use this.
(define (hypernest-selective-snippet-sys sfs uds)
  (w- ffdstsss (snippet-format-sys-functor sfs)
  #/w- eds (fin-multiplied-dim-sys 2 uds)
  #/w- ess
    (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
      ffdstsss eds)
  #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
  #/selective-snippet-sys sfs eds #/fn hole
    (expect (snippet-sys-snippet-undone shape-ess hole)
      (just undone-hole)
      none/c
    #/expect (snippet-sys-snippet-degree shape-ess hole)
      (fin-multiplied-dim 1 hole-d)
      none/c
    #/expect (snippet-sys-snippet-degree shape-ess undone-hole)
      (fin-multiplied-dim 0 undone-hole-d)
      none/c
    #/expect (dim-sys-dim=? uds hole-d undone-hole-d) #t
      none/c
      any/c)))

; TODO: Export these.
; TODO: Use these.
; TODO: Define `hypernest` in terms of `hypernest-unchecked`.
; TODO: Change the way a `hypernest?` is written using
; `gen:custom-write`.
(define-imitation-simple-struct
  (hypernest? hypernest-selective-snippet)
  hypernest-unchecked
  'hypernest (current-inspector) (auto-write) (auto-equal))

; TODO: Export this.
; TODO: Use the things that use this.
(define (hypernest/c sfs uds)
  (w- ffdstsss (snippet-format-sys-functor sfs)
  #/w- eds (fin-multiplied-dim-sys 2 uds)
  #/w- ess
    (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
      ffdstsss eds)
  #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
  #/rename-contract
    (match/c hypernest-unchecked
      (and/c
        (snippet-sys-snippet-with-degree/c ess #/fn d
          (mat d (fin-multiplied-dim 0 d) #t #f))
        (snippet-sys-snippetof
          (hypernest-selective-snippet-sys sfs uds)
          (fn hole
            (expect (snippet-sys-snippet-degree shape-ess hole)
              (fin-multiplied-dim 0 d)
              none/c
              any/c)))))
    `(hypernest/c ,sfs ,uds)))

; TODO: Export these.
;
; TODO: Use these.
;
(define-imitation-simple-struct
  (hypernest-snippet-sys?
    hypernest-snippet-sys-snippet-format-sys
    hypernest-snippet-sys-dim-sys)
  hypernest-snippet-sys
  'hypernest-snippet-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (hypernest-snippet-sys sfs uds)
        (match/c hypernest-snippet-sys (ok/c sfs) (ok/c uds)))))
  (#:prop prop:snippet-sys #/make-snippet-sys-impl-from-conversions
    ; snippet-sys-snippet/c
    (dissectfn (hypernest-snippet-sys sfs uds)
      (hypernest/c sfs uds))
    ; ss->
    (dissectfn (hypernest-snippet-sys sfs uds)
      (hypernest-selective-snippet-sys sfs uds))
    ; snippet->
    (dissectfn (hypernest-unchecked selective)
      selective)
    ; ->snippet
    (fn selective
      (hypernest-unchecked selective))))


; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-select-nothing ss snippet)
  (snippet-sys-snippet-select ss snippet #/fn hole data #f))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (htb-labeled? htb-labeled-degree htb-labeled-data)
  htb-labeled
  'htb-labeled (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct
  (htb-unlabeled? htb-unlabeled-degree)
  htb-unlabeled
  'htb-unlabeled (current-inspector) (auto-write) (auto-equal))

; TODO: Export this.
; TODO: Use this.
(define (hypertee-bracket? v)
  (or (htb-labeled? v) (htb-unlabeled? v)))

; TODO: Export this.
; TODO: Use this.
(define (hypertee-bracket/c dim/c)
  (w- dim/c (coerce-contract 'hypertee-bracket/c dim/c)
  #/rename-contract
    (or/c
      (match/c htb-labeled dim/c any/c)
      (match/c htb-unlabeled dim/c))
    `(hypertee-bracket/c ,(contract-name dim/c))))

; TODO: Export this.
; TODO: Use this.
(define (hypertee-bracket-degree bracket)
  (mat bracket (htb-labeled d data) d
  #/dissect bracket (htb-unlabeled d) d))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (hnb-open? hnb-open-degree hnb-open-data)
  hnb-open
  'hnb-open (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct
  (hnb-labeled? hnb-labeled-degree hnb-labeled-data)
  hnb-labeled
  'hnb-labeled (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct
  (hnb-unlabeled? hnb-unlabeled-degree)
  hnb-unlabeled
  'hnb-unlabeled (current-inspector) (auto-write) (auto-equal))

; TODO: Export this.
; TODO: Use this.
(define (hypernest-bracket? v)
  (or (hnb-open? v) (hnb-labeled? v) (hnb-unlabeled? v)))

; TODO: Export this.
; TODO: Use this.
(define (hypernest-bracket/c dim/c)
  (w- dim/c (coerce-contract 'hypernest-bracket/c dim/c)
  #/rename-contract
    (or/c
      (match/c hnb-open dim/c any/c)
      (match/c hnb-labeled dim/c any/c)
      (match/c hnb-unlabeled dim/c))
    `(hypernest-bracket/c ,(contract-name dim/c))))

; TODO: Export this.
; TODO: Use this.
(define (hypernest-bracket-degree bracket)
  (mat bracket (hnb-open d data) d
  #/mat bracket (hnb-labeled d data) d
  #/dissect bracket (hnb-unlabeled d) d))

; TODO: Export this.
; TODO: Use this.
(define (hypertee-bracket->hypernest-bracket bracket)
  (mat bracket (htb-labeled d data) (hnb-labeled d data)
  #/dissect bracket (htb-unlabeled d) (hnb-unlabeled d)))

; TODO: Export this.
; TODO: Use this.
(define (compatible-hypernest-bracket->hypertee-bracket bracket)
  (mat bracket (hnb-labeled d data) (htb-labeled d data)
  #/dissect bracket (hnb-unlabeled d) (htb-unlabeled d)))

(define
  (explicit-hypernest-from-brackets
    err-name err-normalize-bracket uds degree brackets)
  
  (struct parent-same-part (should-annotate-as-nontrivial))
  (struct parent-new-part ())
  (struct parent-part (i should-annotate-as-trivial))
  
  (struct part-state
    (
      is-hypernest
      first-nontrivial-degree
      first-non-interpolation-degree
      overall-degree
      rev-brackets))
  
  (w- mds (fin-multiplied-dim-sys 2 uds)
  #/w- emds (extended-with-top-dim-sys mds)
  #/w- htss (hypertee-snippet-sys emds)
  #/w- hnss (hypernest-snippet-sys (hypertee-snippet-format-sys) uds)
  #/w- opening-degree degree
  #/if (dim-sys-dim=0? uds opening-degree)
    (expect brackets (list)
      (error "Expected brackets to be empty since degree was zero")
    #/hypernest-unchecked #/selective-snippet-zero
      (hypertee-furl-unchecked mds #/hypertee-coil-zero))
  #/expect brackets (cons first-bracket brackets)
    (error "Expected brackets to be nonempty since degree was nonzero")
  #/w- root-i 'root
  #/w- stack
    (make-hyperstack uds opening-degree #/parent-same-part #t)
  #/dissect
    (mat first-bracket (hnb-open bump-degree data)
      (list
        (fn root-part
          (dissect root-part
            (hypernest-unchecked #/selective-snippet-nonzero _
              root-part-selective)
          #/dissect
            (snippet-sys-snippet-filter-maybe htss
              root-part-selective)
            (just root-part-shape)
          #/w- root-part-assembled
            
            ; We construct the overall hypertee to use as the
            ; representation of the resulting hypernest.
            ;
            ; This hypertee begins with at least one hole,
            ; representing the bump we parsed from the brackets.
            ;
            ; It also contains other holes representing the rest of
            ; the bumps and holes of the hypernest. We add in the rest
            ; of those holes by using appropriate tails in a
            ; `snippet-sys-snippet-splice-sure`. The `root-part` and
            ; each of the (hypernest) tails carried in its holes gives
            ; us what we need for one of those (hypertee) tails.
            ;
            ; TODO: See if it's simpler to keep the tails as
            ; hypernests and use them for a
            ; `(snippet-sys-snippet-splice-sure hnss ...)` instead.
            ;
            (snippet-sys-snippet-splice-sure htss
              (snippet-sys-snippet-done
                htss
                (extended-with-top-dim-infinite)
                
                ; We construct the shape of the hole that we're using
                ; to represent the bump. This hole is shaped like a
                ; "done" around the shape of the hole's interior
                ; (`root-part`).
                ;
                ; As expected by our `snippet-sys-snippet-splice-sure`
                ; call, the elements in the holes this snippet are
                ; `selectable?` values, and the selected ones are tail
                ; snippets whose own holes contain
                ; `(selectable/c any/c trivial?)` values.
                ;
                (snippet-sys-snippet-done
                  htss
                  (extended-with-top-dim-finite
                    (fin-multiplied-dim 1 bump-degree))
                  (snippet-sys-snippet-map htss root-part-shape
                    (fn hole tail
                      (w- prefix-d
                        (snippet-sys-snippet-degree htss hole)
                      #/dissect tail
                        (hypernest-unchecked
                          (selective-snippet-nonzero _ tail))
                      #/selected
                        (snippet-sys-snippet-map htss tail
                          (fn hole selectable-tail-tail
                            (mat selectable-tail-tail
                              (unselected data)
                              (just #/unselected #/unselected data)
                            #/dissect selectable-tail-tail
                              (selected tail-tail)
                            #/w- suffix-d
                              (snippet-sys-snippet-degree htss hole)
                            #/if
                              (dim-sys-dim<? emds suffix-d prefix-d)
                              (dissect tail-tail (trivial)
                              #/just #/selected #/trivial)
                            #/just #/unselected
                              (selected tail-tail)))))))
                  (selected
                    (snippet-sys-snippet-map htss root-part-selective
                      (fn hole selectable-tail
                        (mat selectable-tail (unselected data)
                          (just #/unselected #/unselected data)
                        #/dissect selectable-tail (selected tail)
                          (just #/selected #/trivial))))))
                (unselected #/unselected data))
              (fn hole splice splice))
          
          #/hypernest-unchecked #/selective-snippet-nonzero
            (fin-multiplied-dim 0 opening-degree)
            root-part-assembled))
        (part-state #t (dim-sys-dim-zero uds) bump-degree
          (dim-sys-dim-max uds opening-degree bump-degree)
          (list))
        (hyperstack-push bump-degree stack #/parent-new-part))
    #/mat first-bracket (hnb-labeled hole-degree data)
      (expect (dim-sys-dim<? uds hole-degree opening-degree) #t
        (raise-arguments-error err-name
          "encountered a closing bracket of degree too high for where it occurred, and it was the first bracket"
          "overall-degree" opening-degree
          "first-bracket" (err-normalize-bracket first-bracket)
          "brackets" (map err-normalize-bracket brackets))
      #/dissect (hyperstack-pop hole-degree stack #/parent-new-part)
        (list (parent-same-part #t) stack)
      #/list
        (fn root-part
          (hypernest-unchecked #/selective-snippet-nonzero
            (fin-multiplied-dim 0 opening-degree)
            (hypertee-furl-unchecked emds #/hypertee-coil-hole
              (extended-with-top-dim-infinite)
              (snippet-sys-snippet-map htss root-part #/fn hole data
                (trivial))
              (selected data)
              root-part)))
        (part-state
          #f (dim-sys-dim-zero uds) hole-degree hole-degree (list))
        stack)
    #/error "Expected the first bracket of a hypernest to be annotated")
    (list finish root-part stack)
  #/w-loop next
    brackets-remaining brackets
    parts (hash-set (make-immutable-hasheq) root-i root-part)
    stack stack
    current-i root-i
    new-i 0
    (dissect (hash-ref parts current-i)
      (part-state
        current-is-hypernest
        current-first-nontrivial-degree
        current-first-non-interpolation-degree
        current-overall-degree
        current-rev-brackets)
    #/w- current-d (hyperstack-dimension stack)
    #/expect brackets-remaining (cons bracket brackets-remaining)
      (expect (dim-sys-dim=0? uds current-d) #t
        (error "Expected more closing brackets")
      #/let ()
        (define (get-part i)
          (dissect (hash-ref parts i)
            (part-state
              is-hypernest
              first-nontrivial-degree
              first-non-interpolation-degree
              overall-degree
              rev-brackets)
          #/w- get-subpart
            (fn d data
              (if
                (and
                  (dim-sys-dim<=? uds first-nontrivial-degree d)
                  (dim-sys-dim<? uds d first-non-interpolation-degree))
                (get-part data)
                data))
          #/if is-hypernest
            (snippet-sys-snippet-map hnss
              (hypernest-from-brackets uds overall-degree
                (reverse rev-brackets))
              (fn hole data
                (get-subpart
                  (snippet-sys-snippet-degree htss hole)
                  data)))
            (snippet-sys-snippet-map htss
              (hypertee-from-brackets uds overall-degree
                (reverse #/list-map rev-brackets #/fn closing-bracket
                  (mat closing-bracket (hnb-labeled d data)
                    (htb-labeled d data)
                  #/dissect closing-bracket (hnb-unlabeled d)
                    (htb-unlabeled d))))
              (fn hole data
                (get-subpart
                  (snippet-sys-snippet-degree htss hole)
                  data)))))
      #/finish #/get-part root-i)
    
    #/mat bracket (hnb-open bump-degree bump-value)
      (expect current-is-hypernest #t
        (error "Encountered a bump inside a hole")
      #/next
        brackets-remaining
        (hash-set parts current-i
          (part-state
            current-is-hypernest
            current-first-nontrivial-degree
            current-first-non-interpolation-degree
            current-overall-degree
            (cons bracket current-rev-brackets)))
        (hyperstack-push bump-degree stack #/parent-same-part #f)
        current-i
        new-i)
    #/dissect
      (mat bracket (hnb-labeled hole-degree hole-value)
        (list hole-degree hole-value)
      #/dissect bracket (hnb-unlabeled hole-degree)
        (list hole-degree (trivial)))
      (list hole-degree hole-value)
    #/expect (dim-sys-dim<? uds hole-degree current-d) #t
      (raise-arguments-error err-name
        "encountered a closing bracket of degree too high for where it occurred"
        "current-d" current-d
        "bracket" (err-normalize-bracket bracket)
        "brackets-remaining"
        (map err-normalize-bracket brackets-remaining)
        "brackets" (map err-normalize-bracket brackets))
    #/w- parent (hyperstack-peek stack hole-degree)
    #/begin
      (mat bracket (hnb-labeled hole-degree hole-value)
        (expect parent (parent-same-part #t)
          (raise-arguments-error err-name
            "encountered an annotated closing bracket of degree too low for where it occurred"
            "current-d" current-d
            "bracket" (err-normalize-bracket bracket)
            "brackets-remaining"
            (map err-normalize-bracket brackets-remaining)
            "brackets" (map err-normalize-bracket brackets))
        #/void)
        (mat parent (parent-same-part #t)
          (raise-arguments-error err-name
            "encountered an unannotated closing bracket of degree too high for where it occurred"
            "current-d" current-d
            "bracket" (err-normalize-bracket bracket)
            "brackets-remaining"
            (map err-normalize-bracket brackets-remaining)
            "brackets" (map err-normalize-bracket brackets))
        #/void))
    #/mat parent (parent-same-part should-annotate-as-nontrivial)
      (dissect
        (hyperstack-pop hole-degree stack #/parent-same-part #f)
        (list _ updated-stack)
      #/dissect
        (eq? should-annotate-as-nontrivial
          (mat bracket (hnb-labeled hole-degree hole-value)
            #t
            #f))
        #t
      #/w- parts
        (hash-set parts current-i
          (part-state
            current-is-hypernest
            current-first-nontrivial-degree
            current-first-non-interpolation-degree
            current-overall-degree
            (cons bracket current-rev-brackets)))
      #/next brackets-remaining parts updated-stack current-i new-i)
    #/mat parent (parent-new-part)
      (dissect
        (hyperstack-pop hole-degree stack #/parent-part current-i #t)
        (list _ updated-stack)
      #/mat bracket (hnb-labeled hole-degree hole-value)
        ; TODO: Is this really an internal error, or is there some way
        ; to cause it with an incorrect sequence of input brackets?
        (error "Internal error: Expected the beginning of an interpolation to be unannotated")
      #/w- parent-i new-i
      #/w- new-i (add1 new-i)
      #/w- parts
        (hash-set parts current-i
          (part-state
            current-is-hypernest
            current-first-nontrivial-degree
            current-first-non-interpolation-degree
            current-overall-degree
            (cons (hnb-labeled hole-degree parent-i)
              current-rev-brackets)))
      #/w- parts
        (hash-set parts parent-i
          (part-state #t hole-degree hole-degree
            (dim-sys-dim-max uds opening-degree hole-degree)
            (list)))
      #/next brackets-remaining parts updated-stack parent-i new-i)
    #/dissect parent (parent-part parent-i should-annotate-as-trivial)
      (dissect hole-value (trivial)
      #/dissect
        (hyperstack-pop hole-degree stack #/parent-part current-i #f)
        (list _ updated-stack)
      #/dissect (hash-ref parts parent-i)
        (part-state
          parent-is-hypernest
          parent-first-nontrivial-degree
          parent-first-non-interpolation-degree
          parent-overall-degree
          parent-rev-brackets)
      #/w- parts
        (hash-set parts current-i
          (part-state
            current-is-hypernest
            current-first-nontrivial-degree
            current-first-non-interpolation-degree
            current-overall-degree
            (cons
              (if should-annotate-as-trivial
                (hnb-labeled hole-degree (trivial))
                (hnb-unlabeled hole-degree))
              current-rev-brackets)))
      #/w- parts
        (hash-set parts parent-i
          (part-state
            parent-is-hypernest
            parent-first-nontrivial-degree
            parent-first-non-interpolation-degree
            parent-overall-degree
            (cons (hnb-unlabeled hole-degree) parent-rev-brackets)))
      #/next brackets-remaining parts updated-stack parent-i new-i))))

; TODO: Export this.
; TODO: Use this.
(define (hypernest-from-brackets ds degree brackets)
  (explicit-hypernest-from-brackets
    'hypernest-from-brackets (fn hnb hnb) ds degree brackets))

; TODO: Export this.
; TODO: Use this.
(define (hypertee-from-brackets ds degree brackets)
  (explicit-hypernest-from-brackets
    'hypertee-from-brackets
    (fn hnb #/compatible-hypernest-bracket->hypertee-bracket hnb)
    ds
    degree
    (list-map brackets #/fn htb
      (hypertee-bracket->hypernest-bracket htb))))


; TODO: Export this.
; TODO: Use this.
(define (hypernest-brackets hn)
  (dissect hn (hypernest-unchecked hn-selective)
  #/mat hn-selective (selective-snippet-zero ht) (list)
  #/dissect hn-selective (selective-snippet-nonzero _ ht)
  #/dissect ht (hypertee-furl-unchecked emds _)
  #/dissect emds (extended-with-top-dim-sys mds)
  #/dissect mds (fin-multiplied-dim-sys 2 uds)
  #/w- hnss (hypernest-snippet-sys (hypertee-snippet-format-sys) uds)
  #/w- htss (hypertee-snippet-sys emds)
  #/w- prepend
    (fn hnb rest
      (snippet-sys-snippet-splice-sure htss
        (hypertee-from-brackets emds
          (extended-with-top-dim-infinite)
          (list
            (htb-labeled
              (extended-with-top-dim-finite
                (fin-multiplied-dim 1 #/dim-sys-dim-zero uds))
              (unselected hnb))
            (htb-unlabeled #/dim-sys-dim-zero emds)
            (htb-labeled (dim-sys-dim-zero emds)
              (selected #/snippet-sys-snippet-select-nothing htss
                rest))))
        (fn hole splice splice)))
  #/w- ht->list
    (fn ht
      (w-loop next ht ht rev-result (list)
        (dissect ht
          (hypertee-furl-unchecked _
            (hypertee-coil-hole
              (extended-with-top-dim-infinite)
              hole
              data
              (hypertee-furl-unchecked _ tails-coil)))
        #/mat tails-coil (hypertee-coil-zero)
          (dissect data (trivial)
          #/reverse rev-result)
        #/dissect tails-coil
          (hypertee-coil-hole
            (extended-with-top-dim-finite #/fin-multiplied-dim 1 d)
            tails-hole
            tail
            (hypertee-furl-unchecked _ #/hypertee-coil-zero))
        #/dissect (dim-sys-dim=0? uds d) #t
        #/next tail #/cons data rev-result)))
  #/ht->list #/snippet-sys-snippet-splice-sure htss
    (w-loop next ht ht
      (dissect ht
        (hypertee-furl-unchecked _
          (hypertee-coil-hole (extended-with-top-dim-infinite)
            hole data tails))
      #/dissect (snippet-sys-snippet-degree htss tails)
        (extended-with-top-dim-finite d)
      #/mat d (fin-multiplied-dim 1 d)
        (dissect (snippet-sys-snippet-undone uds tails)
          (just #/list
            (extended-with-top-dim-finite
              (fin-multiplied-dim 1 d-again))
            tails
            interior)
        #/dissect (dim-sys-dim=? uds d d-again) #t
        #/dissect (snippet-sys-snippet-degree htss tails)
          (extended-with-top-dim-finite
            (fin-multiplied-dim 0 d-again))
        #/dissect (dim-sys-dim=? uds d d-again) #t
        #/dissect data (unselected data)
        #/prepend (unselected #/hnb-open d data)
          (snippet-sys-snippet-splice-sure htss
            (snippet-sys-snippet-zip-map-selective htss
              tails
              (snippet-sys-snippet-select htss (next interior)
                (fn hole data
                  (selected? data)))
            #/fn hole tail data
              (dissect data (selected #/trivial)
              #/dissect (snippet-sys-snippet-degree htss hole)
                (extended-with-top-dim-finite
                  (fin-multiplied-dim 0 d))
              #/selected
                (prepend (unselected #/hnb-unlabeled d) (next tail))))
            (fn hole splice splice)))
      #/dissect d (fin-multiplied-dim 0 d)
        (dissect data (selected data)
        #/hypertee-coil-hole (extended-with-top-dim-infinite)
          hole
          (selected data)
          (snippet-sys-snippet-map htss tails #/fn hole tail
            (dissect (snippet-sys-snippet-degree htss hole)
              (extended-with-top-dim-finite #/fin-multiplied-dim 0 d)
            #/prepend (unselected #/hnb-unlabeled d) (next tail))))))
    (fn hole selectable-data
      (dissect (snippet-sys-snippet-degree htss hole)
        (extended-with-top-dim-finite d)
      #/mat d (fin-multiplied-dim 1 d)
        (dissect selectable-data (unselected data)
        #/unselected data)
      #/dissect d (fin-multiplied-dim 0 d)
        (dissect selectable-data (selected data)
        #/dissect
          (snippet-sys-snippet-set-degree-maybe htss
            (extended-with-top-dim-infinite)
            hole)
          (just rest)
        #/selected #/snippet-sys-snippet-select-if-degree< htss
          (extended-with-top-dim-finite #/fin-multiplied-dim 0 d)
          (prepend (hnb-labeled d data) rest))))))

; TODO: Export this.
; TODO: Use this.
(define (hypertee-brackets ht)
  (dissect ht (hypertee-furl-unchecked ds coil)
  #/list-map
    (hypernest-brackets #/snippet-sys-shape->snippet
      (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
      ht)
  #/fn hnb
    (compatible-hypernest-bracket->hypertee-bracket hnb)))
