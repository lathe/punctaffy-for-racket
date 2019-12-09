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
  -> ->i and/c any/c contract? contract-name contract-out list/c
  none/c or/c rename-contract)
(require #/only-in racket/contract/combinator
  blame-add-context coerce-contract contract-first-order-passes?
  make-contract raise-blame-error)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/list list-map)
(require #/only-in lathe-comforts/match match/c)
(require #/only-in lathe-comforts/maybe
  just just? just-value maybe? maybe-bind maybe/c maybe-map nothing)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct)
(require #/only-in lathe-comforts/trivial trivial trivial?)

(require #/only-in punctaffy/hypersnippet/dim
  dim-successors-sys-accepts/c dim-successors-sys-dim=plus-int?
  dim-successors-sys-dim-plus-int dim-successors-sys-dim-sys dim-sys?
  dim-sys-accepts/c dim-sys-dim<? dim-sys-dim<=? dim-sys-dim=?
  dim-sys-dim=0? dim-sys-dim/c dim-sys-dim</c dim-sys-dim=/c
  dim-sys-dim-max dim-sys-dim-zero dim-sys-morphism-sys?
  dim-sys-morphism-sys-accepts/c dim-sys-morphism-sys-morph-dim
  dim-sys-morphism-sys-put-source dim-sys-morphism-sys-put-target
  dim-sys-morphism-sys-source dim-sys-morphism-sys-target)
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
  [snippet-sys-accepts/c (-> snippet-sys? contract?)]
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
            (fn hole trivial?))]
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
      ; snippet-sys-accepts/c
      (-> snippet-sys? contract?)
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
              (fn hole trivial?))]
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
  [snippet-sys-morphism-sys-accepts/c
    (-> snippet-sys-morphism-sys? contract?)]
  [snippet-sys-morphism-sys-source
    (-> snippet-sys-morphism-sys? snippet-sys?)]
  [snippet-sys-morphism-sys-put-source
    (-> snippet-sys-morphism-sys? snippet-sys?
      snippet-sys-morphism-sys?)]
  [snippet-sys-morphism-sys-target
    (-> snippet-sys-morphism-sys? snippet-sys?)]
  [snippet-sys-morphism-sys-put-target
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
      (-> snippet-sys-morphism-sys? contract?)
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
          (snippet-sys-accepts/c
            (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
              (dim-sys-morphism-sys-source ms)))
          (snippet-sys-accepts/c
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
            (snippet-sys-accepts/c
              (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
                (dim-sys-morphism-sys-source ms)))
            (snippet-sys-accepts/c
              (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
                (dim-sys-morphism-sys-target ms))))])
      functor-from-dim-sys-to-snippet-sys-sys-impl?)]
  
  ; TODO:
  ;
  ; An `extension-from-dim-sys-to-snippet-sys-sys?` is a wrapped
  ; functor that guarantees the resulting `dim-sys` systems and
  ; morphisms make use of the same `dym-sys` systems and functors that
  ; were given. That is, when we compose an extension's functor with
  ; the functor represented by the combination of
  ; `snippet-sys-dim-sys` and
  ; `snippet-sys-morphism-sys-dim-sys-morphism-sys`, we get an
  ; identity functor.
  ;
  ; When we document the `extension-from-dim-sys-to-snippet-sys-sys?`
  ; type, make sure to explain this.
  ;
  [extension-from-dim-sys-to-snippet-sys-sys? (-> any/c boolean?)]
  [extension-from-dim-sys-to-snippet-sys-sys-impl?
    (-> any/c boolean?)]
  [extension-from-dim-sys-to-snippet-sys-sys-accepts/c
    (-> extension-from-dim-sys-to-snippet-sys-sys? contract?)]
  [extension-from-dim-sys-to-snippet-sys-sys-functor
    (-> extension-from-dim-sys-to-snippet-sys-sys?
      functor-from-dim-sys-to-snippet-sys-sys?)]
  [prop:extension-from-dim-sys-to-snippet-sys-sys
    (struct-type-property/c
      extension-from-dim-sys-to-snippet-sys-sys-impl?)]
  [make-extension-from-dim-sys-to-snippet-sys-sys-impl-from-functor
    (->
      (-> extension-from-dim-sys-to-snippet-sys-sys? contract?)
      (-> extension-from-dim-sys-to-snippet-sys-sys?
        functor-from-dim-sys-to-snippet-sys-sys?)
      extension-from-dim-sys-to-snippet-sys-sys-impl?)]
  
  [extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?
    (-> any/c boolean?)]
  [extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl?
    (-> any/c boolean?)]
  [extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-accepts/c
    (-> extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?
      contract?)]
  [extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
    (-> extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?
      extension-from-dim-sys-to-snippet-sys-sys?)]
  [extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-put-source
    (->
      extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?
      extension-from-dim-sys-to-snippet-sys-sys?
      extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?)]
  [extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
    (-> extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?
      extension-from-dim-sys-to-snippet-sys-sys?)]
  [extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-put-target
    (->
      extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?
      extension-from-dim-sys-to-snippet-sys-sys?
      extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?)]
  [extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-transfer-to-snippet-sys-morphism-sys
    (->i
      (
        [ms extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?]
        [ds dim-sys?])
      [_ (ms ds)
        (snippet-sys-morphism-sys/c
          (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
            (extension-from-dim-sys-to-snippet-sys-sys-functor
              (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
                ms))
            ds)
          (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
            (extension-from-dim-sys-to-snippet-sys-sys-functor
              (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
                ms))
            ds))])]
  [extension-from-dim-sys-to-snippet-sys-sys-morphism-sys/c
    (-> contract? contract? contract?)]
  [prop:extension-from-dim-sys-to-snippet-sys-sys-morphism-sys
    (struct-type-property/c
      extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl?)]
  [make-extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-morph
    (->
      (-> extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        contract?)
      (-> extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        extension-from-dim-sys-to-snippet-sys-sys?)
      (->
        extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        extension-from-dim-sys-to-snippet-sys-sys?
        extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?)
      (-> extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        extension-from-dim-sys-to-snippet-sys-sys?)
      (->
        extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        extension-from-dim-sys-to-snippet-sys-sys?
        extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?)
      (->i
        (
          [ms extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?]
          [ds dim-sys?])
        [_ (ms ds)
          (snippet-sys-morphism-sys/c
            (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
              (extension-from-dim-sys-to-snippet-sys-sys-functor
                (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
                  ms))
              ds)
            (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
              (extension-from-dim-sys-to-snippet-sys-sys-functor
                (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
                  ms))
              ds))])
      extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl?)]
  
  [extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys?
    (-> any/c boolean?)]
  [extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-impl?
    (-> any/c boolean?)]
  [extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-accepts/c
    (-> extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys?
      contract?)]
  [extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-morph-extension-from-dim-sys-to-snippet-sys-sys
    (->
      extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys?
      extension-from-dim-sys-to-snippet-sys-sys?
      extension-from-dim-sys-to-snippet-sys-sys?)]
  [extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-morph-extension-from-dim-sys-to-snippet-sys-sys-morphism-sys
    (->i
      (
        [es
          extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys?]
        [ms extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?])
      [_ (ms)
        (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys/c
          (extension-from-dim-sys-to-snippet-sys-sys-accepts/c
            (extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-morph-extension-from-dim-sys-to-snippet-sys-sys
              (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
                ms)))
          (extension-from-dim-sys-to-snippet-sys-sys-accepts/c
            (extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-morph-extension-from-dim-sys-to-snippet-sys-sys
              (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-target ms))))])]
  [prop:extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys
    (struct-type-property/c
      extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-impl?)]
  [make-extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-impl-from-morph
    (->
      (-> extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys?
        contract?)
      (->
        extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys?
        extension-from-dim-sys-to-snippet-sys-sys?
        extension-from-dim-sys-to-snippet-sys-sys?)
      (->i
        (
          [es
            extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys?]
          [ms
            extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?])
        [_ (ms)
          (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys/c
            (extension-from-dim-sys-to-snippet-sys-sys-accepts/c
              (extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-morph-extension-from-dim-sys-to-snippet-sys-sys
                (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
                  ms)))
            (extension-from-dim-sys-to-snippet-sys-sys-accepts/c
              (extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-morph-extension-from-dim-sys-to-snippet-sys-sys
                (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
                  ms))))])
      extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-impl?)]
  
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
  (#:method snippet-sys-accepts/c (#:this))
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
(define (snippet-sys-snippet-bind ss prefix hv-to-suffix)
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/just-value #/snippet-sys-snippet-splice ss prefix #/fn hole data
    (just #/selected #/snippet-sys-snippet-select-if-degree< ss
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
  (#:method snippet-sys-morphism-sys-accepts/c (#:this))
  (#:method snippet-sys-morphism-sys-source (#:this))
  (#:method snippet-sys-morphism-sys-put-source (#:this) ())
  (#:method snippet-sys-morphism-sys-target (#:this))
  (#:method snippet-sys-morphism-sys-put-target (#:this) ())
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
  #/w- first-order
    (fn v
      (and
        (snippet-sys-morphism-sys? v)
        (contract-first-order-passes? source/c
          (snippet-sys-morphism-sys-source v))
        (contract-first-order-passes? target/c
          (snippet-sys-morphism-sys-target v))))
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
          (snippet-sys-morphism-sys-put-source v
            (source/c-projection (snippet-sys-morphism-sys-source v)
              missing-party))
        #/w- v
          (snippet-sys-morphism-sys-put-target v
            (target/c-projection (snippet-sys-morphism-sys-target v)
              missing-party))
          v)))))


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
  extension-from-dim-sys-to-snippet-sys-sys?
  extension-from-dim-sys-to-snippet-sys-sys-impl?
  (#:method extension-from-dim-sys-to-snippet-sys-sys-accepts/c
    (#:this))
  (#:method extension-from-dim-sys-to-snippet-sys-sys-functor
    (#:this))
  prop:extension-from-dim-sys-to-snippet-sys-sys
  make-extension-from-dim-sys-to-snippet-sys-sys-impl-from-functor
  'extension-from-dim-sys-to-snippet-sys-sys
  'extension-from-dim-sys-to-snippet-sys-sys-impl
  (list))


(define-imitation-simple-generics
  extension-from-dim-sys-to-snippet-sys-sys-morphism-sys?
  extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl?
  (#:method
    extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-accepts/c
    (#:this))
  (#:method
    extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
    (#:this))
  (#:method
    extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-put-source
    (#:this)
    ())
  (#:method
    extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
    (#:this))
  (#:method
    extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-put-target
    (#:this)
    ())
  (#:method
    extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-transfer-to-snippet-sys-morphism-sys
    (#:this)
    ())
  prop:extension-from-dim-sys-to-snippet-sys-sys-morphism-sys
  make-extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-morph
  'extension-from-dim-sys-to-snippet-sys-sys-morphism-sys
  'extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl
  (list))

(define (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys/c source/c target/c)
  (w- source/c
    (coerce-contract
      'extension-from-dim-sys-to-snippet-sys-sys-morphism-sys/c
      source/c)
  #/w- target/c
    (coerce-contract
      'extension-from-dim-sys-to-snippet-sys-sys-morphism-sys/c
      target/c)
  #/w- name
    `(extension-from-dim-sys-to-snippet-sys-sys-morphism-sys/c
       ,(contract-name source/c)
       ,(contract-name target/c))
  #/w- first-order
    (fn v
      (and
        (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys? v)
        (contract-first-order-passes? source/c
          (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
            v))
        (contract-first-order-passes? target/c
          (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
            v))))
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
          (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-put-source
            v
            (source/c-projection
              (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-source
                v)
              missing-party))
        #/w- v
          (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-put-target
            v
            (target/c-projection
              (extension-from-dim-sys-to-snippet-sys-sys-morphism-sys-target
                v)
              missing-party))
          v)))))


(define-imitation-simple-generics
  extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys?
  extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-impl?
  (#:method
    extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-accepts/c
    (#:this))
  (#:method
    extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-morph-extension-from-dim-sys-to-snippet-sys-sys
    (#:this)
    ())
  (#:method
    extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-morph-extension-from-dim-sys-to-snippet-sys-sys-morphism-sys
    (#:this)
    ())
  prop:extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys
  make-extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-impl-from-morph
  'extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys
  'extension-from-dim-sys-to-snippet-sys-sys-endofunctor-sys-impl
  (list))


; TODO: Export these.
; TODO: Use the things that use these.
(define-imitation-simple-struct
  (selective-snippet?
    selective-snippet-degree
    selective-snippet-content)
  selective-snippet
  'selective-snippet (current-inspector) (auto-write) (auto-equal))

; TODO: Export this.
; TODO: Use the things that use this.
(define (selective-snippet/c efdstsss uds h-to-unselected/c)
  (w- eds (extended-with-top-dim-sys uds)
  #/w- ess
    (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
      (extension-from-dim-sys-to-snippet-sys-sys-functor efdstsss)
      eds)
  #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
  #/rename-contract
    (and/c
      (match/c selective-snippet
        (dim-sys-dim/c eds)
        (snippet-sys-snippet-with-degree/c ess
          (extended-with-top-dim-infinite)))
      (by-own-method/c (selective-snippet d content)
      #/match/c selective-snippet any/c
        (snippet-sys-snippetof ess #/fn hole
          (selectable/c
            (if
              (dim-sys-dim<? eds
                (snippet-sys-snippet-degree shape-ess hole)
                (extended-with-top-dim-finite d))
              (h-to-unselected/c hole)
              none/c)
            any/c))))
    `(selective-snippet/c ,efdstsss ,uds ,h-to-unselected/c)))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (selective-snippet-sys?
    selective-snippet-sys-extension-from-dim-sys-to-snippet-sys-sys
    selective-snippet-sys-dim-sys
    selective-snippet-sys-h-to-unselected/c)
  selective-snippet-sys
  'selective-snippet-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:snippet-sys #/make-snippet-sys-impl-from-various-1
    ; snippet-sys-accepts/c
    (dissectfn (selective-snippet-sys efdstsss uds h-to-unselected/c)
      (match/c selective-snippet-sys
        (extension-from-dim-sys-to-snippet-sys-sys-accepts/c efdstsss)
        (dim-sys-accepts/c uds)
        any/c))
    ; snippet-sys-snippet/c
    (dissectfn (selective-snippet-sys efdstsss uds h-to-unselected/c)
      (selective-snippet/c efdstsss uds h-to-unselected/c))
    ; snippet-sys-dim-sys
    (dissectfn (selective-snippet-sys efdstsss uds _)
      uds)
    ; snippet-sys-shape-snippet-sys
    (dissectfn (selective-snippet-sys efdstsss uds _)
      (w- uss
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          (extension-from-dim-sys-to-snippet-sys-sys-functor efdstsss)
          uds)
      #/snippet-sys-shape-snippet-sys uss))
    ; snippet-sys-snippet-degree
    (fn ss snippet
      (dissect snippet (selective-snippet d content)
        d))
    ; snippet-sys-shape->snippet
    (fn ss shape
      (dissect ss (selective-snippet-sys efdstsss uds _)
      #/w- ffdstsss
        (extension-from-dim-sys-to-snippet-sys-sys-functor efdstsss)
      #/w- uss
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss uds)
      #/w- eds (extended-with-top-dim-sys ds)
      #/w- ess
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss eds)
      #/w- unextended-snippet (snippet-sys-shape->snippet uss shape)
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
      #/selective-snippet
        (snippet-sys-snippet-degree uss unextended-snippet)
        content))
    ; snippet-sys-snippet->maybe-shape
    (fn ss snippet
      (dissect ss (selective-snippet-sys efdstsss uds _)
      #/dissect snippet (selective-snippet d content)
      #/w- ffdstsss
        (extension-from-dim-sys-to-snippet-sys-sys-functor efdstsss)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- ess
        (functor-from-dim-sys-to-snippet-sys-sys-morph-dim-sys
          ffdstsss eds)
      #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
      #/maybe-bind (snippet-sys-snippet->maybe-shape ess content)
      #/fn shape
      #/maybe-bind
        (snippet-sys-snippet-map-maybe shape-ss shape #/fn hole data
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
    ; TODO NOW: From here.
    ; snippet-sys-snippet-set-degree-maybe
    (fn ss degree snippet
      (dissect ss (selective-snippet-sys ss _)
      #/dissect snippet (selective-snippet snippet)
      #/maybe-map
        (snippet-sys-snippet-set-degree-maybe ss degree snippet)
      #/fn snippet
        (selective-snippet snippet)))
    ; snippet-sys-snippet-done
    (fn ss degree shape data
      (dissect ss (selective-snippet-sys ss _)
      #/selective-snippet #/snippet-sys-snippet-select-everything
        (snippet-sys-snippet-done ss degree shape data)))
    ; snippet-sys-snippet-undone
    (fn ss snippet
      (dissect ss (selective-snippet-sys ss _)
      #/dissect snippet (selective-snippet snippet)
      #/maybe-bind
        (snippet-sys-snippet-map-maybe ss snippet #/fn hole data
          (expect data (selected data) (nothing)
          #/just data))
      #/fn snippet
      #/snippet-sys-snippet-undone ss snippet))
    ; snippet-sys-snippet-splice
    (fn ss snippet hv-to-splice
      (dissect ss (selective-snippet-sys ss _)
      #/dissect snippet (selective-snippet snippet)
      #/maybe-map
        (snippet-sys-snippet-splice ss snippet #/fn hole data
          (mat data (unselected data)
            (just #/unselected #/unselected data)
          #/dissect data (selected data)
          #/maybe-map (hv-to-splice hole data) #/fn splice
            (mat splice (unselected data)
              (just #/unselected #/selected data)
            #/dissect splice (selected #/selective-snippet suffix)
            #/just #/selected
              (snippet-sys-snippet-map ss suffix #/fn hole data
                (mat data (unselected data)
                  (unselected #/unselected data)
                #/dissect data (selected data)
                #/mat data (unselected data)
                  (unselected #/selected data)
                #/dissect data (selected #/trivial)
                #/selected #/trivial)))))
      #/fn snippet
        (selective-snippet snippet)))
    ; snippet-sys-snippet-zip-map-selective
    (fn ss shape snippet hvv-to-maybe-v
      (dissect ss (selective-snippet-sys ss _)
      #/dissect snippet (selective-snippet snippet)
      #/maybe-map
        (snippet-sys-snippet-zip-map-selective ss shape
          (snippet-sys-snippet-map ss snippet #/fn hole data
            (mat data (unselected data) (unselected #/unselected data)
            #/dissect data (selected data)
            #/mat data (unselected data) (unselected #/selected data)
            #/dissect data (selected data) (selected data)))
        #/fn hole shape-data subject-data
          (maybe-map (hvv-to-maybe-v hole shape-data subject-data)
          #/fn result-data
            (selected result-data)))
      #/fn snippet
        (selective-snippet snippet)))))


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
  (rename-contract
    (match/c hypertee-furl-unchecked (dim-sys-accepts/c ds) any/c)
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
  (#:prop prop:snippet-sys #/make-snippet-sys-impl-from-various-1
    ; snippet-sys-accepts/c
    (dissectfn (hypertee-snippet-sys ds)
      (match/c hypertee-snippet-sys #/dim-sys-accepts/c ds))
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
        #/maybe-bind
          (snippet-sys-snippet-zip-map-selective ss tails suffix
          #/fn hole tail data
            (w- d (snippet-sys-snippet-degree ss hole)
            #/dissect data (trivial)
            #/selected
              (snippet-sys-snippet-select-if-degree< ss d tail)))
        #/fn suffix
        #/snippet-sys-snippet-splice ss suffix #/fn hole data data)))
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
  (#:prop prop:snippet-sys-morphism-sys
    (make-snippet-sys-morphism-sys-impl-from-morph
      ; snippet-sys-morphism-sys-accepts/c
      (dissectfn (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        (match/c hypertee-map-dim-snippet-sys-morphism-sys
          (dim-sys-morphism-sys-accepts/c dsms)))
      ; snippet-sys-morphism-sys-source
      (dissectfn (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        (hypertee-snippet-sys #/dim-sys-morphism-sys-source dsms))
      ; snippet-sys-morphism-sys-put-source
      (fn ms new-s
        (dissect ms (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        #/expect new-s (hypertee-snippet-sys new-s)
          (w- s
            (hypertee-snippet-sys #/dim-sys-morphism-sys-source dsms)
          #/raise-arguments-error 'dim-sys-morphism-sys-put-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/hypertee-map-dim-snippet-sys-morphism-sys
          (dim-sys-morphism-sys-put-source dsms new-s)))
      ; snippet-sys-morphism-sys-target
      (dissectfn (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        (hypertee-snippet-sys #/dim-sys-morphism-sys-target dsms))
      ; snippet-sys-morphism-sys-put-target
      (fn ms new-t
        (dissect ms (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        #/expect new-t (hypertee-snippet-sys new-t)
          (w- t
            (hypertee-snippet-sys #/dim-sys-morphism-sys-target dsms)
          #/raise-arguments-error 'dim-sys-morphism-sys-put-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/hypertee-map-dim-snippet-sys-morphism-sys
          (dim-sys-morphism-sys-put-target dsms new-t)))
      ; snippet-sys-morphism-sys-dim-sys-morphism-sys
      (dissectfn (hypertee-map-dim-snippet-sys-morphism-sys dsms)
        dsms)
      ; snippet-sys-morphism-sys-shape-dim-sys-morphism-sys
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
  (hypertee-extension-from-dim-sys-to-snippet-sys-sys?)
  hypertee-extension-from-dim-sys-to-snippet-sys-sys
  'hypertee-extension-from-dim-sys-to-snippet-sys-sys
  (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:extension-from-dim-sys-to-snippet-sys-sys
    (make-extension-from-dim-sys-to-snippet-sys-sys-impl-from-functor
      ; extension-from-dim-sys-to-snippet-sys-sys-accepts/c
      (dissectfn _
        hypertee-extension-from-dim-sys-to-snippet-sys-sys?)
      ; extension-from-dim-sys-to-snippet-sys-sys-functor
      (dissectfn _
        (hypertee-functor-from-dim-sys-to-snippet-sys-sys)))))


; TODO: Find a better name for this.
; TODO: Export this.
; TODO: Use the things that use this.
(define
  (make-snippet-sys-impl-from-conversions
    snippet-sys-accepts/c snippet-sys-snippet/c ss-> snippet->
    ->snippet)
  (make-snippet-sys-impl-from-various-1
    ; snippet-sys-accepts/c
    snippet-sys-accepts/c
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
(define (hypernest-selective-snippet-sys dss shape-ss)
  ; TODO: See if we should verify that
  ; `(dim-successors-sys-dim-sys dss)` and
  ; `(snippet-sys-dim-sys shape-ss)` return the same value.
  (selective-snippet-sys shape-ss #/fn hole
    (expect (snippet-sys-snippet-undone shape-ss hole)
      (just undone-hole)
      none/c
    #/if
      (dim-successors-sys-dim=plus-int? dss
        (snippet-sys-snippet-degree shape-ss hole)
        (snippet-sys-snippet-degree shape-ss undone-hole)
        1)
      any/c
      none/c)))

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
(define (hypernest/c dss shape-ss)
  ; TODO: See if we should verify that
  ; `(dim-successors-sys-dim-sys dss)` and
  ; `(snippet-sys-dim-sys shape-ss)` return the same value.
  (rename-contract
    (match/c hypernest-unchecked #/snippet-sys-snippet/c
      (hypernest-selective-snippet-sys dss shape-ss))
    `(hypernest/c ,dss ,shape-ss)))

; TODO: Export these.
;
; TODO: Use these.
;
; TODO: See if we should verify that
; `(dim-successors-sys-dim-sys dss)` and
; `(snippet-sys-dim-sys shape-ss)` return the same value.
;
(define-imitation-simple-struct
  (hypernest-snippet-sys?
    hypersnippet-snippet-sys-dim-successors-sys
    hypernest-snippet-sys-shape-snippet-sys)
  hypernest-snippet-sys
  'hypernest-snippet-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:snippet-sys #/make-snippet-sys-impl-from-conversions
    ; snippet-sys-accepts/c
    (dissectfn (hypernest-snippet-sys dss shape-ss)
      (match/c hypernest-snippet-sys
        (dim-successors-sys-accepts/c dss)
        (snippet-sys-accepts/c shape-ss)))
    ; snippet-sys-snippet/c
    (dissectfn (hypernest-snippet-sys dss shape-ss)
      (hypernest/c dss shape-ss))
    ; ss->
    (dissectfn (hypernest-snippet-sys dss shape-ss)
      (hypernest-selective-snippet-sys dss shape-ss))
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

; TODO HYPERNEST-2-FROM-BRACKETS: Finish implementing this.
; TODO: Export this.
; TODO: Use this.
(define
  (explicit-hypernest-from-brackets err-name dss degree brackets)
  
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
  
  (w- ds (dim-successors-sys-dim-sys dss)
  #/w- htss (hypertee-snippet-sys ds)
  #/w- hnss (hypernest-snippet-sys dss htss)
  #/w- opening-degree degree
  #/if (dim-sys-dim=0? ds opening-degree)
    (expect brackets (list)
      (error "Expected brackets to be empty since degree was zero")
    #/hypernest-unchecked #/selective-snippet
      (hypertee-furl-unchecked ds #/hypertee-coil-zero))
  #/expect brackets (cons first-bracket brackets)
    (error "Expected brackets to be nonempty since degree was nonzero")
  #/w- root-i 'root
  #/w- stack (make-hyperstack ds opening-degree #/parent-same-part #t)
  #/dissect
    (mat first-bracket (hnb-open bump-degree data)
      (expect (dim-successors-sys-dim-plus-int dss bump-degree 1)
        (just bump-degree-plus-one)
        (error "Expected each opening bracket's bump degree to have a successor")
      #/list
        (fn root-part
          (dissect root-part
            (hypernest-unchecked #/selective-snippet
              root-part-selective)
          #/dissect
            (snippet-sys-snippet-filter-maybe
              htss root-part-selective)
            (just root-part-shape)
          #/w- root-part
            ; TODO: See if we should be passing in `htss` instead.
            (snippet-sys-snippet-select-nothing hnss root-part)
          #/hypernest-unchecked #/selective-snippet
            (hypertee-furl-unchecked ds #/hypertee-coil-hole
              opening-degree
              (snippet-sys-snippet-done
                htss
                bump-degree-plus-one
                (snippet-sys-snippet-map htss root-part-shape
                  (fn hole data
                    (trivial)))
                (trivial))
              (unselected data)
              ; TODO HYPERNEST-2-FROM-BRACKETS: Implement this. First,
              ; we probably need to refactor the way hypernests work
              ; so that they use a dimension system that acts like a
              ; given dimension system but adds successors for each
              ; dimension and a single infinity.
              'TODO)))
        (part-state #t (dim-sys-dim-zero ds) bump-degree
          (dim-sys-dim-max ds opening-degree bump-degree)
          (list))
        (hyperstack-push bump-degree stack #/parent-new-part))
    #/mat first-bracket (hnb-labeled hole-degree data)
      (expect (dim-sys-dim<? ds hole-degree opening-degree) #t
        (raise-arguments-error err-name
          "encountered a closing bracket of degree too high for where it occurred, and it was the first bracket"
          "overall-degree" opening-degree
          "first-bracket" first-bracket
          "brackets" brackets)
      #/dissect (hyperstack-pop hole-degree stack #/parent-new-part)
        (list (parent-same-part #t) stack)
      #/list
        (fn root-part
          (hypernest-unchecked #/selective-snippet
            (hypertee-furl-unchecked ds #/hypertee-coil-hole
              opening-degree
              (snippet-sys-snippet-map htss root-part #/fn hole data
                (trivial))
              (selected data)
              root-part)))
        (part-state
          #f (dim-sys-dim-zero ds) hole-degree hole-degree (list))
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
      (expect (dim-sys-dim=0? ds current-d) #t
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
                  (dim-sys-dim<=? ds first-nontrivial-degree d)
                  (dim-sys-dim<? ds d first-non-interpolation-degree))
                (get-part data)
                data))
          #/if is-hypernest
            (snippet-sys-snippet-map hnss
              (hypernest-from-brackets dss overall-degree
                (reverse rev-brackets))
              (fn hole data
                (get-subpart
                  (snippet-sys-snippet-degree htss hole)
                  data)))
            (snippet-sys-snippet-map htss
              (hypertee-from-brackets ds overall-degree
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
    #/expect (dim-sys-dim<? ds hole-degree current-d) #t
      (raise-arguments-error err-name
        "encountered a closing bracket of degree too high for where it occurred"
        "current-d" current-d
        "bracket" bracket
        "brackets-remaining" brackets-remaining
        "brackets" brackets)
    #/w- parent (hyperstack-peek stack hole-degree)
    #/begin
      (mat bracket (hnb-labeled hole-degree hole-value)
        (expect parent (parent-same-part #t)
          (raise-arguments-error err-name
            "encountered an annotated closing bracket of degree too low for where it occurred"
            "current-d" current-d
            "bracket" bracket
            "brackets-remaining" brackets-remaining
            "brackets" brackets)
        #/void)
        (mat parent (parent-same-part #t)
          (raise-arguments-error err-name
            "encountered an unannotated closing bracket of degree too high for where it occurred"
            "current-d" current-d
            "bracket" bracket
            "brackets-remaining" brackets-remaining
            "brackets" brackets)
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
            (dim-sys-dim-max ds opening-degree hole-degree)
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

; TODO HYPERNEST-2-FROM-BRACKETS: Implement these.
(define (hypernest-from-brackets dss d brackets)
  'TODO)
(define (hypertee-from-brackets ds d brackets)
  'TODO)
