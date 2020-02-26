#lang parendown racket/base

; TODO NOW: Remove these imports and all the places they're used.
(require lathe-debugging/placebo)
(require #/for-syntax #/only-in racket/format ~a)

; punctaffy/hypersnippet/snippet
;
; An interface for data structures that are hypersnippet-shaped.

;   Copyright 2019, 2020 The Lathe Authors
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


(require #/for-syntax racket/base)
(require #/for-syntax #/only-in syntax/parse expr syntax-parse)

; NOTE: The Racket documentation says `get/build-late-neg-projection`
; is in `racket/contract/combinator`, but it isn't. It's in
; `racket/contract/base`. Since it's also in `racket/contract` and the
; documentation correctly says it is, we require it from there.
(require #/only-in racket/contract
  get/build-late-neg-projection struct-type-property/c)
(require #/only-in racket/contract/base
  -> ->i and/c any/c contract? contract-name contract-out
  flat-contract? flat-contract-predicate list/c listof none/c or/c
  rename-contract)
(require #/only-in racket/contract/combinator
  blame-add-context coerce-contract contract-first-order-passes?
  make-contract make-flat-contract raise-blame-error)
(require #/only-in racket/contract/region define/contract)
(require #/only-in racket/match define-match-expander)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/contract
  by-own-method/c value-name-for-contract)
(require #/only-in lathe-comforts/list list-map)
(require #/only-in lathe-comforts/match
  define-match-expander-attenuated
  define-match-expander-from-match-and-make match/c)
(require #/only-in lathe-comforts/maybe
  just just? just-value maybe? maybe-bind maybe/c maybe-if maybe-map
  nothing)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct)
(require #/only-in lathe-comforts/trivial trivial trivial?)
(require #/only-in lathe-morphisms/in-fp/set
  makeshift-set-sys-from-contract)
(require #/only-in lathe-morphisms/in-fp/category
  functor-sys-apply-to-object functor-sys/c functor-sys-impl?
  make-category-sys-impl-from-chain-two
  make-functor-sys-impl-from-apply
  make-natural-transformation-sys-impl-from-apply
  natural-transformation-sys/c natural-transformation-sys-chain-two
  natural-transformation-sys-identity natural-transformation-sys-impl?
  natural-transformation-sys-source natural-transformation-sys-target
  prop:category-sys prop:functor-sys prop:natural-transformation-sys)
(require #/only-in lathe-morphisms/in-fp/mediary/set
  make-atomic-set-element-sys-impl-from-contract ok/c
  prop:atomic-set-element-sys)

(require #/only-in punctaffy/hypersnippet/dim
  dim-sys? dim-sys-category-sys dim-sys-category-sys? dim-sys-dim<?
  dim-sys-dim<=? dim-sys-dim=? dim-sys-dim=0? dim-sys-dim/c
  dim-sys-0<dim/c dim-sys-dim</c dim-sys-dim=/c dim-sys-dim-max
  dim-sys-dim-zero dim-sys-morphism-sys?
  dim-sys-morphism-sys-chain-two dim-sys-morphism-sys-identity
  dim-sys-morphism-sys-morph-dim dim-sys-morphism-sys-replace-source
  dim-sys-morphism-sys-replace-target dim-sys-morphism-sys-source
  dim-sys-morphism-sys-target extended-with-top-dim-sys
  extended-with-top-dim-sys-morphism-sys extended-with-top-dim-finite
  extended-with-top-dim-infinite extend-with-top-dim-sys-morphism-sys
  fin-multiplied-dim fin-multiplied-dim-sys
  fin-times-dim-sys-morphism-sys fin-untimes-dim-sys-morphism-sys
  functor-from-dim-sys-sys-apply-to-morphism
  natural-transformation-from-from-dim-sys-sys-apply-to-morphism
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
    (-> snippet-sys? flat-contract? contract?)]
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
          (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)]
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
  ; result should always exist if the given degree is equal to the
  ; degree returned by `snippet-sys-snippet-undone`, and it should
  ; always exist if the given degree is greater than that degree and
  ; that degree is nonzero.
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
  [snippet-sys-snippet-any?
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss) (snippet-sys-snippet/c ss)]
        [check-hv? (ss)
          (->
            (snippet-sys-snippetof (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            any/c
            boolean?)])
      [_ boolean?])]
  [snippet-sys-snippet-all?
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss) (snippet-sys-snippet/c ss)]
        [check-hv? (ss)
          (->
            (snippet-sys-snippetof (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            any/c
            boolean?)])
      [_ boolean?])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting snippet should always be of the same shape as the given
  ; one.
  [snippet-sys-snippet-map-maybe
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss) (snippet-sys-snippet/c ss)]
        [hv-to-maybe-v (ss)
          (->
            (snippet-sys-snippetof (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            any/c
            maybe?)])
      [_ (ss snippet)
        (maybe/c
          (snippet-sys-snippet-with-degree=/c ss
            (snippet-sys-snippet-degree ss snippet)))])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting snippet should always be of the same shape as the given
  ; one.
  [snippet-sys-snippet-map
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss) (snippet-sys-snippet/c ss)]
        [hv-to-v (ss)
          (->
            (snippet-sys-snippetof (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            any/c
            any/c)])
      [_ (ss snippet)
        (snippet-sys-snippet-with-degree=/c ss
          (snippet-sys-snippet-degree ss snippet))])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting snippet should always be of the same shape as the given
  ; one.
  [snippet-sys-snippet-select
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss) (snippet-sys-snippet/c ss)]
        [check-hv? (ss)
          (->
            (snippet-sys-snippetof (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            any/c
            boolean?)])
      [_ (ss snippet)
        (snippet-sys-snippet-with-degree=/c ss
          (snippet-sys-snippet-degree ss snippet))])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting snippet should always be of the same shape as the given
  ; one.
  [snippet-sys-snippet-select-if-degree
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss) (snippet-sys-snippet/c ss)]
        [check-degree? (ss)
          (-> (dim-sys-dim/c #/snippet-sys-dim-sys ss) boolean?)])
      [_ (ss snippet)
        (snippet-sys-snippet-with-degree=/c ss
          (snippet-sys-snippet-degree ss snippet))])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting snippet should always be of the same shape as the given
  ; one.
  [snippet-sys-snippet-select-if-degree<
    (->i
      (
        [ss snippet-sys?]
        [degreee (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
        [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss snippet)
        (snippet-sys-snippet-with-degree=/c ss
          (snippet-sys-snippet-degree ss snippet))])]
  [snippet-sys-snippet-bind-selective
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
              (selectable/c any/c
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
        (snippet-sys-snippet-with-degree=/c ss
        #/snippet-sys-snippet-degree ss snippet)])]
  [snippet-sys-snippet-bind-selective-prefix
    (->i
      (
        [ss snippet-sys?]
        [prefix (ss) (snippet-sys-snippet/c ss)]
        [hv-to-suffix (ss prefix)
          (w- ds (snippet-sys-dim-sys ss)
          #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
          #/w- d (snippet-sys-snippet-degree ss prefix)
          #/->i
            (
              [prefix-hole
                (snippet-sys-snippetof shape-ss #/fn hole trivial?)]
              [data any/c])
            [_ (prefix-hole)
              (w- prefix-hole-d
                (snippet-sys-snippet-degree shape-ss prefix-hole)
              #/selectable/c any/c
                
                ; What this means is that this should be a snippet
                ; whose low-degree holes correspond to the holes of
                ; `prefix-hole` and contain `trivial?` values.
                ;
                ; TODO: See if we can factor out a
                ; `snippet-sys-snippet-zip-low-degree-holes/c` or
                ; something out of this.
                ;
                (and/c
                  (snippet-sys-snippet-with-degree=/c ss d)
                  (snippet-sys-snippet-zip-selective/c ss prefix-hole
                    (fn suffix-hole subject-data
                      (w- suffix-hole-d
                        (snippet-sys-snippet-degree
                          shape-ss suffix-hole)
                      #/dim-sys-dim<? ds suffix-hole-d prefix-hole-d))
                    (fn hole shape-data subject-data trivial?))))])])
      [_ (ss prefix)
        (snippet-sys-snippet-with-degree=/c ss
        #/snippet-sys-snippet-degree ss prefix)])]
  [snippet-sys-snippet-join-selective
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss)
          (w- ds (snippet-sys-dim-sys ss)
          #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
          #/and/c (snippet-sys-snippet/c ss)
          #/by-own-method/c snippet
          #/w- d (snippet-sys-snippet-degree ss snippet)
          #/snippet-sys-snippetof ss #/fn prefix-hole
            (w- prefix-hole-d
              (snippet-sys-snippet-degree shape-ss prefix-hole)
            #/by-own-method/c data
            #/selectable/c any/c
              ; What this means is that this should be a snippet which
              ; contains a `selected` or `unselected` entry in each
              ; hole, and its `selected` holes should correspond to
              ; the holes of `hole` and contain `trivial?` values.
              (and/c
                (snippet-sys-snippet-with-degree=/c ss d)
                (snippet-sys-snippetof ss #/fn hole
                  (selectable/c any/c trivial?))
                (snippet-sys-snippet-zip-selective/c ss prefix-hole
                  (fn suffix-hole subject-data
                    (selected? subject-data))
                  (fn hole shape-data subject-data any/c)))))])
      [_ (ss snippet)
        (snippet-sys-snippet-with-degree=/c ss
        #/snippet-sys-snippet-degree ss snippet)])]
  [snippet-sys-snippet-join-selective-prefix
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss)
          (w- ds (snippet-sys-dim-sys ss)
          #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
          #/and/c (snippet-sys-snippet/c ss)
          #/by-own-method/c snippet
          #/w- d (snippet-sys-snippet-degree ss snippet)
          #/snippet-sys-snippetof ss #/fn prefix-hole
            (w- prefix-hole-d
              (snippet-sys-snippet-degree shape-ss prefix-hole)
            #/by-own-method/c data
            #/selectable/c any/c
              
              ; What this means is that this should be a snippet whose
              ; low-degree holes correspond to the holes of
              ; `prefix-hole` and contain `trivial?` values.
              ;
              ; TODO: See if we can factor out a
              ; `snippet-sys-snippet-zip-low-degree-holes/c` or
              ; something out of this.
              ;
              (and/c
                (snippet-sys-snippet-with-degree=/c ss d)
                (snippet-sys-snippet-zip-selective/c ss prefix-hole
                  (fn suffix-hole subject-data
                    (w- suffix-hole-d
                      (snippet-sys-snippet-degree
                        shape-ss suffix-hole)
                    #/dim-sys-dim<? ds suffix-hole-d prefix-hole-d))
                  (fn hole shape-data subject-data trivial?)))))])
      [_ (ss snippet)
        (snippet-sys-snippet-with-degree=/c ss
        #/snippet-sys-snippet-degree ss snippet)])]
  [snippet-sys-snippet-bind
    (->i
      (
        [ss snippet-sys?]
        [prefix (ss) (snippet-sys-snippet/c ss)]
        [hv-to-suffix (ss prefix)
          (w- ds (snippet-sys-dim-sys ss)
          #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
          #/w- d (snippet-sys-snippet-degree ss prefix)
          #/->i
            (
              [prefix-hole
                (snippet-sys-snippetof shape-ss #/fn hole trivial?)]
              [data any/c])
            [_ (prefix-hole)
              (w- prefix-hole-d
                (snippet-sys-snippet-degree shape-ss prefix-hole)
              
              ; What this means is that this should be a snippet
              ; whose low-degree holes correspond to the holes of
              ; `prefix-hole` and contain `trivial?` values.
              ;
              ; TODO: See if we can factor out a
              ; `snippet-sys-snippet-zip-low-degree-holes/c` or
              ; something out of this.
              ;
              #/and/c
                (snippet-sys-snippet-with-degree=/c ss d)
                (snippet-sys-snippet-zip-selective/c ss prefix-hole
                  (fn suffix-hole subject-data
                    (w- suffix-hole-d
                      (snippet-sys-snippet-degree
                        shape-ss suffix-hole)
                    #/dim-sys-dim<? ds suffix-hole-d prefix-hole-d))
                  (fn hole shape-data subject-data trivial?)))])])
      [_ (ss prefix)
        (snippet-sys-snippet-with-degree=/c ss
        #/snippet-sys-snippet-degree ss prefix)])]
  [snippet-sys-snippet-join
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss)
          (w- ds (snippet-sys-dim-sys ss)
          #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
          #/and/c (snippet-sys-snippet/c ss)
          #/by-own-method/c snippet
          #/w- d (snippet-sys-snippet-degree ss snippet)
          #/snippet-sys-snippetof ss #/fn prefix-hole
            (w- prefix-hole-d
              (snippet-sys-snippet-degree shape-ss prefix-hole)
            #/by-own-method/c data
            
            ; What this means is that this should be a snippet whose
            ; low-degree holes correspond to the holes of
            ; `prefix-hole` and contain `trivial?` values.
            ;
            ; TODO: See if we can factor out a
            ; `snippet-sys-snippet-zip-low-degree-holes/c` or
            ; something out of this.
            ;
            #/and/c
              (snippet-sys-snippet-with-degree=/c ss d)
              (snippet-sys-snippet-zip-selective/c ss prefix-hole
                (fn suffix-hole subject-data
                  (w- suffix-hole-d
                    (snippet-sys-snippet-degree
                      shape-ss suffix-hole)
                  #/dim-sys-dim<? ds suffix-hole-d prefix-hole-d))
                (fn hole shape-data subject-data trivial?))))])
      [_ (ss snippet)
        (snippet-sys-snippet-with-degree=/c ss
        #/snippet-sys-snippet-degree ss snippet)])]
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
  [snippet-sys-morphism-sys-identity
    (->i ([endpoint snippet-sys?])
      [_ (endpoint)
        (snippet-sys-morphism-sys/c
          (ok/c endpoint)
          (ok/c endpoint))])]
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
          (ok/c #/snippet-sys-morphism-sys-target b))])])

(provide
  snippet-sys-category-sys)
(provide #/contract-out
  [snippet-sys-category-sys? (-> any/c boolean?)])

(provide #/contract-out
  [functor-from-dim-sys-to-snippet-sys-sys? (-> any/c boolean?)]
  [make-functor-from-dim-sys-to-snippet-sys-sys-impl-from-apply
    (->
      (-> functor-from-dim-sys-to-snippet-sys-sys? dim-sys?
        snippet-sys?)
      (->i
        (
          [fs functor-from-dim-sys-to-snippet-sys-sys?]
          [ms dim-sys-morphism-sys?])
        [_ (fs ms)
          (snippet-sys-morphism-sys/c
            (ok/c
              (functor-sys-apply-to-object fs
                (dim-sys-morphism-sys-source ms)))
            (ok/c
              (functor-sys-apply-to-object fs
                (dim-sys-morphism-sys-target ms))))])
      functor-sys-impl?)]
  
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
  [make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-apply
    (->
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
          [dsms dim-sys-morphism-sys?])
        [_ (ms dsms)
          (snippet-sys-morphism-sys/c
            (functor-sys-apply-to-object
              (natural-transformation-sys-source ms)
              (dim-sys-morphism-sys-source dsms))
            (functor-sys-apply-to-object
              (natural-transformation-sys-target ms)
              (dim-sys-morphism-sys-target dsms)))])
      natural-transformation-sys-impl?)]
  
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
  [snippet-format-sys-morphism-sys-identity
    (->i ([endpoint snippet-format-sys?])
      [_ (endpoint)
        (snippet-format-sys-morphism-sys/c
          (ok/c endpoint)
          (ok/c endpoint))])]
  [snippet-format-sys-morphism-sys-chain-two
    (->i
      (
        [a snippet-format-sys-morphism-sys?]
        [b (a)
          (snippet-format-sys-morphism-sys/c
            (ok/c #/snippet-format-sys-morphism-sys-target a)
            any/c)])
      [_ (a b)
        (snippet-format-sys-morphism-sys/c
          (ok/c #/snippet-format-sys-morphism-sys-source a)
          (ok/c #/snippet-format-sys-morphism-sys-target b))])])

(provide
  snippet-format-sys-category-sys)
(provide #/contract-out
  [snippet-format-sys-category-sys? (-> any/c boolean?)])

(provide #/contract-out
  [snippet-format-sys-endofunctor-sys? (-> any/c boolean?)]
  [make-snippet-format-sys-endofunctor-sys-impl-from-apply
    (->
      (-> snippet-format-sys-endofunctor-sys? snippet-format-sys?
        snippet-format-sys?)
      (->i
        (
          [es snippet-format-sys-endofunctor-sys?]
          [ms snippet-format-sys-morphism-sys?])
        [_ (es ms)
          (snippet-format-sys-morphism-sys/c
            (ok/c
              (functor-sys-apply-to-object es
                (snippet-format-sys-morphism-sys-source ms)))
            (ok/c
              (functor-sys-apply-to-object es
                (snippet-format-sys-morphism-sys-target ms))))])
      functor-sys-impl?)])

(module+ private/hypertee #/provide
  hypertee-coil-zero)
(module+ private/hypertee #/provide #/contract-out
  [hypertee-coil-zero? (-> any/c boolean?)])
(module+ private/hypertee #/provide
  hypertee-coil-hole)
(module+ private/hypertee #/provide #/contract-out
  [hypertee-coil-hole? (-> any/c boolean?)]
  [hypertee-coil-hole-overall-degree (-> hypertee-coil-hole? any/c)]
  [hypertee-coil-hole-hole (-> hypertee-coil-hole? any/c)]
  [hypertee-coil-hole-data (-> hypertee-coil-hole? any/c)]
  [hypertee-coil-hole-tails (-> hypertee-coil-hole? any/c)])
(module+ private/hypertee #/provide #/contract-out
  [hypertee-coil/c (-> dim-sys? contract?)])
(module+ private/hypertee #/provide
  hypertee-furl)
(module+ private/hypertee #/provide #/contract-out
  [hypertee? (-> any/c boolean?)]
  [hypertee-dim-sys (-> hypertee? dim-sys?)]
  [hypertee-coil
    (->i ([ht hypertee?])
      [_ (ht) (hypertee-coil/c #/hypertee-dim-sys ht)])]
  [hypertee/c (-> dim-sys? contract?)])
(module+ private/hypertee #/provide
  hypertee-snippet-sys)
(module+ private/hypertee #/provide #/contract-out
  [hypertee-snippet-sys? (-> any/c boolean?)]
  [hypertee-snippet-sys-dim-sys (-> hypertee-snippet-sys? dim-sys?)])

(module+ private/hypertee #/provide
  htb-labeled)
(module+ private/hypertee #/provide #/contract-out
  [htb-labeled? (-> any/c boolean?)]
  [htb-labeled-degree (-> htb-labeled? any/c)]
  [htb-labeled-data (-> htb-labeled? any/c)])
(module+ private/hypertee #/provide
  htb-unlabeled)
(module+ private/hypertee #/provide #/contract-out
  [htb-unlabeled? (-> any/c boolean?)]
  [htb-unlabeled-degree (-> htb-unlabeled? any/c)])
(module+ private/hypertee #/provide #/contract-out
  [hypertee-bracket? (-> any/c boolean?)]
  [hypertee-bracket/c (-> contract? contract?)]
  [hypertee-bracket-degree (-> hypertee-bracket? any/c)]
  [hypertee-from-brackets
    (->i
      (
        [ds dim-sys?]
        [degree (ds) (dim-sys-dim/c ds)]
        [brackets (ds)
          (listof #/hypertee-bracket/c #/dim-sys-dim/c ds)])
      [_ (ds) (hypertee/c ds)])]
  [ht-bracs
    (->i ([ds dim-sys?] [degree (ds) (dim-sys-dim/c ds)])
      #:rest
      [brackets (ds)
        (w- dim/c (dim-sys-dim/c ds)
        #/listof #/or/c (hypertee-bracket/c dim/c) dim/c)]
      [_ (ds) (hypertee/c ds)])])

(module+ private/hypernest #/provide #/contract-out
  [hypernest? (-> any/c boolean?)]
  [hypernest/c (-> dim-sys? contract?)])
(module+ private/hypernest #/provide
  hypernest-snippet-sys)
(module+ private/hypernest #/provide #/contract-out
  [hypernest-snippet-sys? (-> any/c boolean?)]
  [hypernest-snippet-sys-snippet-format-sys
    (-> hypernest-snippet-sys? snippet-format-sys?)]
  [hypernest-snippet-sys-dim-sys
    (-> hypernest-snippet-sys? dim-sys?)])

(module+ private/hypernest #/provide
  hypernest-coil-zero)
(module+ private/hypernest #/provide #/contract-out
  [hypernest-coil-zero? (-> any/c boolean?)])
(module+ private/hypernest #/provide
  hypernest-coil-hole)
(module+ private/hypernest #/provide #/contract-out
  [hypernest-coil-hole? (-> any/c boolean?)]
  [hypernest-coil-hole-overall-degree (-> hypernest-coil-hole? any/c)]
  [hypernest-coil-hole-hole (-> hypernest-coil-hole? any/c)]
  [hypernest-coil-hole-data (-> hypernest-coil-hole? any/c)]
  [hypernest-coil-hole-tails-hypertee
    (-> hypernest-coil-hole? any/c)])
(module+ private/hypernest #/provide
  hypernest-coil-bump)
(module+ private/hypernest #/provide #/contract-out
  [hypernest-coil-bump? (-> any/c boolean?)]
  [hypernest-coil-bump-overall-degree (-> hypernest-coil-bump? any/c)]
  [hypernest-coil-bump-data (-> hypernest-coil-bump? any/c)]
  [hypernest-coil-bump-bump-degree (-> hypernest-coil-hole? any/c)]
  [hypernest-coil-bump-tails-hypernest
    (-> hypernest-coil-hole? any/c)])
(module+ private/hypernest #/provide #/contract-out
  [hypernest-coil/c (-> dim-sys? contract?)])
(module+ private/hypernest #/provide
  hypernest-furl)

(module+ private/hypernest #/provide
  hnb-open)
(module+ private/hypernest #/provide #/contract-out
  [hnb-open? (-> any/c boolean?)]
  [hnb-open-degree (-> hnb-open? any/c)]
  [hnb-open-data (-> hnb-open? any/c)])
(module+ private/hypernest #/provide
  hnb-labeled)
(module+ private/hypernest #/provide #/contract-out
  [hnb-labeled? (-> any/c boolean?)]
  [hnb-labeled-degree (-> hnb-labeled? any/c)]
  [hnb-labeled-data (-> hnb-labeled? any/c)])
(module+ private/hypernest #/provide
  hnb-unlabeled)
(module+ private/hypernest #/provide #/contract-out
  [hnb-unlabeled? (-> any/c boolean?)]
  [hnb-unlabeled-degree (-> hnb-unlabeled? any/c)])
(module+ private/hypernest #/provide #/contract-out
  [hypernest-bracket? (-> any/c boolean?)]
  [hypernest-bracket/c (-> contract? contract?)]
  [hypernest-bracket-degree (-> hypernest-bracket? any/c)]
  [hypertee-bracket->hypernest-bracket
    (-> hypertee-bracket? (or/c hnb-labeled? hnb-unlabeled?))]
  [compatible-hypernest-bracket->hypertee-bracket
    (-> (or/c hnb-labeled? hnb-unlabeled?) hypernest-bracket?)]
  [hypernest-from-brackets
    (->i
      (
        [ds dim-sys?]
        [degree (ds) (dim-sys-dim/c ds)]
        [brackets (ds)
          (listof #/hypernest-bracket/c #/dim-sys-dim/c ds)])
      [_ (ds) (hypernest/c (hypertee-snippet-format-sys) ds)])]
  [hn-bracs
    (->i ([ds dim-sys?] [degree (ds) (dim-sys-dim/c ds)])
      #:rest
      [brackets (ds)
        (w- dim/c (dim-sys-dim/c ds)
        #/listof #/or/c (hypernest-bracket/c dim/c) dim/c)]
      [_ (ds) (hypernest/c (hypertee-snippet-format-sys) ds)])])

(module+ private/test #/provide
  snippet-sys-snippet-filter-maybe)



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

; TODO: See if we should export this.
(define (selectable-map s v-to-v)
  (mat s (unselected v) (unselected v)
  #/dissect s (selected v) (selected #/v-to-v v)))


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

; TODO: See if we should have a way to implement this that doesn't
; involve constructing another snippet along the way, since we just
; end up ignoring it.
(define (snippet-sys-snippet-all? ss snippet check-hv?)
  (just? #/snippet-sys-snippet-splice ss snippet #/fn hole data
    (if (check-hv? hole data)
      (just #/unselected data)
      (nothing))))

; TODO: Use the things that use this.
(define (snippet-sys-snippet-any? ss snippet check-hv?)
  (not #/snippet-sys-snippet-all? ss snippet #/fn hole data
    (not #/check-hv? hole data)))

(define (snippet-sys-snippet-map-maybe ss snippet hv-to-maybe-v)
  (dlog 'n1 ss snippet hv-to-maybe-v
  #/snippet-sys-snippet-splice ss snippet #/fn hole data
    (maybe-map (hv-to-maybe-v hole data) #/fn data
      (unselected data))))

(define (snippet-sys-snippet-map ss snippet hv-to-v)
  (dlog 'n2 ss snippet hv-to-v
  #/just-value
  #/snippet-sys-snippet-map-maybe ss snippet #/fn hole data
    (just #/hv-to-v hole data)))

(define (snippet-sys-snippet-select ss snippet check-hv?)
  (dlog 'j2 ss snippet check-hv?
  #/snippet-sys-snippet-map ss snippet #/fn hole data
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
    #/check-hvv? hole shape-data snippet-data)))

(define (snippet-sys-snippet-with-degree/c ss degree/c)
  (w- degree/c
    (coerce-contract 'snippet-sys-snippet-with-degree/c degree/c)
  #/w- name
    `(snippet-sys-snippet-with-degree/c ,ss ,(contract-name degree/c))
  #/w- snippet-contract (snippet-sys-snippet/c ss)
  #/
    (if (flat-contract? snippet-contract)
      make-flat-contract
      make-contract)
    
    #:name name
    
    #:first-order
    (fn v
      (and
        (contract-first-order-passes? snippet-contract v)
        (contract-first-order-passes? degree/c
          (snippet-sys-snippet-degree ss v))))
    
    #:late-neg-projection
    (fn blame
      (w- snippet-contract-projection
        (
          (get/build-late-neg-projection snippet-contract)
          (blame-add-context blame "the initial snippet check of"))
      #/w- degree/c-projection
        (
          (get/build-late-neg-projection degree/c)
          (blame-add-context blame "the degree check of"))
      #/fn v missing-party
        (w- v
          (w- next-v (snippet-contract-projection v missing-party)
          #/if (flat-contract? snippet-contract)
            v
            next-v)
        #/begin
          (degree/c-projection (snippet-sys-snippet-degree ss v)
            missing-party)
          v)))))

(define (snippet-sys-snippet-with-degree</c ss degree)
  (rename-contract
    (snippet-sys-snippet-with-degree/c ss
      (dim-sys-dim</c (snippet-sys-dim-sys ss) degree))
    `(snippet-sys-snippet-with-degree</c ,ss ,degree)))

(define (snippet-sys-snippet-with-degree=/c ss degree)
  (rename-contract
    (snippet-sys-snippet-with-degree/c ss
      (dim-sys-dim=/c (snippet-sys-dim-sys ss) degree))
    `(snippet-sys-snippet-with-degree=/c ,ss ,degree)))

(define (snippet-sys-snippetof ss h-to-value/c)
  (w- name `(snippet-sys-snippetof ,ss ,h-to-value/c)
  #/w- snippet-contract (snippet-sys-snippet/c ss)
  #/w- first-order
    (fn v
      (and (contract-first-order-passes? snippet-contract v)
      #/snippet-sys-snippet-all? ss v #/fn hole data
        (w- value/c
          (coerce-contract 'snippet-sys-snippetof #/h-to-value/c hole)
        #/contract-first-order-passes? value/c data)))
  #/make-contract #:name name #:first-order first-order
    
    #:late-neg-projection
    (fn blame
      (w- snippet-contract-projection
        (
          (get/build-late-neg-projection snippet-contract)
          (blame-add-context blame "the initial snippet check of"))
      #/fn v missing-party
        (w- v (snippet-contract-projection v missing-party)
        #/snippet-sys-snippet-map ss v #/fn hole data
          (w- value/c
            (coerce-contract 'snippet-sys-snippetof
              (h-to-value/c hole))
          #/
            (
              (get/build-late-neg-projection value/c)
              (blame-add-context blame "a hole value of"))
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
        (w- value/c
          (coerce-contract 'snippet-sys-snippet-zip-selective/c
            (hvv-to-subject-v/c hole shape-data subject-data))
        #/contract-first-order-passes? value/c subject-data)))
  #/make-contract #:name name #:first-order first-order
    
    #:late-neg-projection
    (fn blame
      (w- snippet-contract-projection
        (
          (get/build-late-neg-projection snippet-contract)
          (blame-add-context blame "the initial snippet check of"))
      #/fn v missing-party
        (w- v (snippet-contract-projection v missing-party)
        #/expect
          (dlogr 'c1 ss shape check-subject-hv? hvv-to-subject-v/c v
          #/snippet-sys-snippet-zip-map-selective ss shape
            (snippet-sys-snippet-select ss v #/fn hole data
              (check-subject-hv? hole data))
          #/fn hole shape-data subject-data
            (dlog 'p1 hvv-to-subject-v/c
            #/w- value/c
              (coerce-contract 'snippet-sys-snippet-zip-selective/c
                (hvv-to-subject-v/c hole shape-data subject-data))
            #/just #/
              (
                (get/build-late-neg-projection value/c)
                (blame-add-context blame "a hole value of"))
              subject-data
              missing-party))
          (just result)
          (raise-blame-error blame #:missing-party missing-party v
            '(expected: "~e" given: "~e")
            name v)
          result)))))


; TODO: Use the things that use this.
(define
  (snippet-sys-snippet-select-if-degree ss snippet check-degree?)
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/snippet-sys-snippet-select ss snippet #/fn hole data
    (check-degree? #/snippet-sys-snippet-degree shape-ss hole)))

; TODO: Use the things that use this.
(define (snippet-sys-snippet-select-if-degree< ss degree snippet)
  (w- ds (snippet-sys-dim-sys ss)
  #/dlog 'j1
  #/snippet-sys-snippet-select-if-degree ss snippet #/fn actual-degree
    (dim-sys-dim<? ds actual-degree degree)))

; TODO: Use the things that use this.
(define (snippet-sys-snippet-bind-selective ss snippet hv-to-splice)
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/just-value #/snippet-sys-snippet-splice ss snippet #/fn hole data
    (dlog 'i1 hv-to-splice
    #/just #/hv-to-splice hole data)))

; TODO: Use the things that use this.
(define
  (snippet-sys-snippet-bind-selective-prefix ss prefix hv-to-suffix)
  (dlog 'm1
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/snippet-sys-snippet-bind-selective ss prefix #/fn hole data
    (dlog 'i2 hv-to-suffix
    #/selectable-map (hv-to-suffix hole data) #/fn suffix
      (dlog 'i2.1 suffix
      #/snippet-sys-snippet-select-if-degree< ss
        (snippet-sys-snippet-degree shape-ss hole)
        suffix))))

; TODO: Use this.
(define (snippet-sys-snippet-join-selective ss snippet)
  (dlog 'm2 ss snippet
  #/snippet-sys-snippet-bind-selective ss snippet #/fn hole data data))

; TODO: Use this.
(define (snippet-sys-snippet-join-selective-prefix ss snippet)
  (dlog 'm2.1 ss snippet
  #/snippet-sys-snippet-bind-selective-prefix ss snippet #/fn hole data
    data))

; TODO: Use the things that use this.
(define (snippet-sys-snippet-bind ss prefix hv-to-suffix)
  (dlog 'm3
  #/snippet-sys-snippet-bind-selective-prefix ss prefix #/fn hole data
    (dlog 'i3 hv-to-suffix
    #/selected #/hv-to-suffix hole data)))

; TODO: Use this.
(define (snippet-sys-snippet-join ss snippet)
  (dlog 'm4
  #/snippet-sys-snippet-bind ss snippet #/fn hole data data))


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
          (blame-add-context blame "the source of"))
      #/w- target/c-projection
        (
          (get/build-late-neg-projection target/c)
          (blame-add-context blame "the target of"))
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

; TODO: Use this.
(define (snippet-sys-morphism-sys-chain-two a b)
  (chain-two-snippet-sys-morphism-sys a b))


(define-imitation-simple-struct
  (snippet-sys-category-sys?)
  snippet-sys-category-sys
  'snippet-sys-category-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn _ snippet-sys-category-sys?)))
  (#:prop prop:category-sys
    (make-category-sys-impl-from-chain-two
      ; category-sys-object-set-sys
      (fn cs
        (makeshift-set-sys-from-contract
          ; makeshift-set-sys-element/c
          (fn snippet-sys?)
          ; makeshift-set-sys-element-accepts/c
          (fn element #/ok/c element)))
      ; category-sys-morphism-set-sys
      (fn cs s t
        (makeshift-set-sys-from-contract
          ; makeshift-set-sys-element/c
          (fn #/snippet-sys-morphism-sys/c (ok/c s) (ok/c t))
          ; makeshift-set-sys-element-accepts/c
          (fn element #/ok/c element)))
      ; category-sys-object-identity-morphism
      (fn cs endpoint
        (snippet-sys-morphism-sys-identity endpoint))
      ; category-sys-morphism-chain-two
      (fn cs a b c ab bc
        (snippet-sys-morphism-sys-chain-two ab bc)))))


(define (functor-from-dim-sys-to-snippet-sys-sys? v)
  (
    (flat-contract-predicate
      (functor-sys/c dim-sys-category-sys? snippet-sys-category-sys?))
    v))

(define
  (make-functor-from-dim-sys-to-snippet-sys-sys-impl-from-apply
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
    (fn fs #/snippet-sys-category-sys)
    ; functor-sys-replace-target
    (fn fs new-t
      (expect (snippet-sys-category-sys? new-t) #t
        (raise-arguments-error 'functor-sys-replace-target
          "tried to replace the target with a target that was rather different"
          "fs" fs
          "t" (snippet-sys-category-sys)
          "new-t" new-t)
        fs))
    ; functor-sys-apply-to-object
    (fn fs ds #/apply-to-dim-sys fs ds)
    ; functor-sys-apply-to-morphism
    (fn fs a b ms #/apply-to-dim-sys-morphism-sys fs ms)))


(define-imitation-simple-generics
  snippet-format-sys?
  snippet-format-sys-impl?
  (#:method snippet-format-sys-functor (#:this))
  prop:snippet-format-sys
  make-snippet-format-sys-impl-from-functor
  'snippet-format-sys 'snippet-format-sys-impl (list))


(define (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys? v)
  (
    (flat-contract-predicate
      (natural-transformation-sys/c
        dim-sys? snippet-sys? any/c any/c))
    v))

(define
  (make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-apply
    source
    replace-source
    target
    replace-target
    apply-to-dim-sys-morphism-sys)
  (make-natural-transformation-sys-impl-from-apply
    ; functor-sys-endpoint-source
    (fn nts #/dim-sys-category-sys)
    ; functor-sys-replace-endpoint-source
    (fn nts new-es
      (expect (dim-sys-category-sys? new-es) #t
        (raise-arguments-error
          'natural-transformation-sys-replace-endpoint-source
          "tried to replace the endpoint source with an endpoint source that was rather different"
          "nts" nts
          "es" (dim-sys-category-sys)
          "new-es" new-es)
        nts))
    ; functor-sys-endpoint-target
    (fn nts #/snippet-sys-category-sys)
    ; functor-sys-replace-endpoint-target
    (fn nts new-et
      (expect (snippet-sys-category-sys? new-et) #t
        (raise-arguments-error
          'natural-transformation-sys-replace-endpoint-target
          "tried to replace the endpoint target with an endpoint target that was rather different"
          "nts" nts
          "et" (snippet-sys-category-sys)
          "new-et" new-et)
        nts))
    ; functor-sys-source
    (fn nts #/source nts)
    ; functor-sys-replace-source
    (fn nts new-s #/replace-source nts new-s)
    ; functor-sys-target
    (fn nts #/target nts)
    ; functor-sys-replace-target
    (fn nts new-t #/replace-target nts new-t)
    ; functor-sys-apply-to-morphism
    (fn nts a b ms #/apply-to-dim-sys-morphism-sys nts ms)))


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
          (blame-add-context blame "the source of"))
      #/w- target/c-projection
        (
          (get/build-late-neg-projection target/c)
          (blame-add-context blame "the target of"))
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
      ; snippet-format-sys-morphism-sys-functor-morphism
      (dissectfn (identity-snippet-format-sys-morphism-sys e)
        (natural-transformation-sys-identity
          (snippet-format-sys-functor e))))))

; TODO: Use this.
(define (snippet-format-sys-morphism-sys-identity endpoint)
  (identity-snippet-format-sys-morphism-sys endpoint))

(define-imitation-simple-struct
  (chain-two-snippet-format-sys-morphism-sys?
    chain-two-snippet-format-sys-morphism-sys-first
    chain-two-snippet-format-sys-morphism-sys-second)
  chain-two-snippet-format-sys-morphism-sys
  'chain-two-snippet-format-sys-morphism-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (chain-two-snippet-format-sys-morphism-sys a b)
        (match/c chain-two-snippet-format-sys-morphism-sys
          (ok/c a)
          (ok/c b)))))
  (#:prop prop:snippet-format-sys-morphism-sys
    (make-snippet-format-sys-morphism-sys-impl-from-morph
      ; snippet-format-sys-morphism-sys-source
      (dissectfn (chain-two-snippet-format-sys-morphism-sys a b)
        (snippet-format-sys-morphism-sys-source a))
      ; snippet-format-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms (chain-two-snippet-format-sys-morphism-sys a b)
        #/chain-two-snippet-format-sys-morphism-sys
          (snippet-format-sys-morphism-sys-replace-source a new-s)
          b))
      ; snippet-format-sys-morphism-sys-target
      (dissectfn (chain-two-snippet-format-sys-morphism-sys a b)
        (snippet-format-sys-morphism-sys-target b))
      ; snippet-format-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms (chain-two-snippet-format-sys-morphism-sys a b)
        #/chain-two-snippet-format-sys-morphism-sys
          a
          (snippet-format-sys-morphism-sys-replace-target b new-t)))
      ; snippet-format-sys-morphism-sys-functor-morphism
      (dissectfn (chain-two-snippet-format-sys-morphism-sys a b)
        (natural-transformation-sys-chain-two
          (snippet-format-sys-morphism-sys-functor-morphism a)
          (snippet-format-sys-morphism-sys-functor-morphism b))))))

; TODO: Use this.
(define (snippet-format-sys-morphism-sys-chain-two a b)
  (chain-two-snippet-format-sys-morphism-sys a b))


(define-imitation-simple-struct
  (snippet-format-sys-category-sys?)
  snippet-format-sys-category-sys
  'snippet-format-sys-category-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn _ snippet-format-sys-category-sys?)))
  (#:prop prop:category-sys
    (make-category-sys-impl-from-chain-two
      ; category-sys-object-set-sys
      (fn cs
        (makeshift-set-sys-from-contract
          ; makeshift-set-sys-element/c
          (fn snippet-format-sys?)
          ; makeshift-set-sys-element-accepts/c
          (fn element #/ok/c element)))
      ; category-sys-morphism-set-sys
      (fn cs s t
        (makeshift-set-sys-from-contract
          ; makeshift-set-sys-element/c
          (fn #/snippet-format-sys-morphism-sys/c (ok/c s) (ok/c t))
          ; makeshift-set-sys-element-accepts/c
          (fn element #/ok/c element)))
      ; category-sys-object-identity-morphism
      (fn cs endpoint
        (snippet-format-sys-morphism-sys-identity endpoint))
      ; category-sys-morphism-chain-two
      (fn cs a b c ab bc
        (snippet-format-sys-morphism-sys-chain-two ab bc)))))


(define (snippet-format-sys-endofunctor-sys? v)
  (
    (flat-contract-predicate
      (functor-sys/c
        snippet-format-sys-category-sys?
        snippet-format-sys-category-sys?))
    v))

(define
  (make-snippet-format-sys-endofunctor-sys-impl-from-apply
    apply-to-snippet-format-sys
    apply-to-snippet-format-sys-morphism-sys)
  (make-functor-sys-impl-from-apply
    ; functor-sys-source
    (fn fs #/snippet-format-sys-category-sys)
    ; functor-sys-replace-source
    (fn fs new-s
      (expect (snippet-format-sys-category-sys? new-s) #t
        (raise-arguments-error 'functor-sys-replace-source
          "tried to replace the source with a source that was rather different"
          "fs" fs
          "s" (snippet-format-sys-category-sys)
          "new-s" new-s)
        fs))
    ; functor-sys-target
    (fn fs #/snippet-format-sys-category-sys)
    ; functor-sys-replace-target
    (fn fs new-t
      (expect (snippet-format-sys-category-sys? new-t) #t
        (raise-arguments-error 'functor-sys-replace-target
          "tried to replace the target with a target that was rather different"
          "fs" fs
          "t" (snippet-format-sys-category-sys)
          "new-t" new-t)
        fs))
    ; functor-sys-apply-to-object
    (fn fs ds #/apply-to-snippet-format-sys fs ds)
    ; functor-sys-apply-to-morphism
    (fn fs a b ms #/apply-to-snippet-format-sys-morphism-sys fs ms)))


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
  #/w- uss (functor-sys-apply-to-object ffdstsss uds)
  #/w- ess (functor-sys-apply-to-object ffdstsss eds)
  #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
  #/rename-contract
    (or/c
      (match/c selective-snippet-zero
        (snippet-sys-snippet-with-degree=/c uss
          (dim-sys-dim-zero uds)))
    #/and/c
      (match/c selective-snippet-nonzero
        (dim-sys-0<dim/c uds)
        (snippet-sys-snippet-with-degree=/c ess
          (extended-with-top-dim-infinite)))
      (by-own-method/c (selective-snippet-nonzero d content)
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
        (functor-sys-apply-to-object (snippet-format-sys-functor sfs)
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
      #/w- uss (functor-sys-apply-to-object ffdstsss uds)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/w- unextended-snippet (snippet-sys-shape->snippet uss shape)
      #/w- d (snippet-sys-snippet-degree uss unextended-snippet)
      #/if (dim-sys-dim=0? uds d)
        (selective-snippet-zero unextended-snippet)
      #/w- extended-snippet
        (snippet-sys-morphism-sys-morph-snippet
          (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
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
      #/w- uss (functor-sys-apply-to-object ffdstsss uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
      #/mat snippet (selective-snippet-zero content)
        (snippet-sys-snippet->maybe-shape uss content)
      #/dissect snippet (selective-snippet-nonzero d content)
      #/maybe-bind (snippet-sys-snippet->maybe-shape ess content)
      #/fn shape
      #/maybe-bind
        (snippet-sys-snippet-map-maybe shape-ess shape #/fn hole data
          (mat data (unselected data) (nothing)
          #/dissect data (selected data) (just data)))
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
      #/just
        (snippet-sys-morphism-sys-morph-snippet
          (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
            (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
              (unextend-with-top-dim-sys-morphism-sys uds)))
          shape)))
    ; snippet-sys-snippet-set-degree-maybe
    (fn ss new-degree snippet
      (dissect ss (selective-snippet-sys sfs uds _)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
      #/expect snippet (selective-snippet-nonzero d content)
        (maybe-if (dim-sys-dim=0? uds new-degree) #/fn snippet)
      #/expect (dim-sys-dim=0? uds new-degree) #f (nothing)
      #/expect
        (snippet-sys-snippet-all? ess content #/fn hole data
          (mat data (unselected data) #t
          #/dissect data (selected data)
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
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/w- extend
        (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
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
      #/w- uss (functor-sys-apply-to-object ffdstsss uds)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/expect snippet (selective-snippet-nonzero d content) (nothing)
      #/maybe-bind
        (snippet-sys-snippet-map-maybe ess content #/fn hole data
          (mat data (unselected data) (nothing)
          #/dissect data (selected data) (just data)))
      #/fn content
      #/snippet-sys-snippet-undone uss
        (snippet-sys-morphism-sys-morph-snippet
          (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
            (unextend-with-top-dim-sys-morphism-sys uds))
          content)))
    ; snippet-sys-snippet-splice
    (fn ss snippet hv-to-splice
      (dissect ss (selective-snippet-sys sfs uds _)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/expect snippet (selective-snippet-nonzero d prefix)
        (just snippet)
      #/w- unextend-hole
        (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
          (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
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
      #/w- uss (functor-sys-apply-to-object ffdstsss uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/mat snippet (selective-snippet-zero subject)
        (maybe-map
          (snippet-sys-snippet-zip-map-selective uss shape subject
            hvv-to-maybe-v)
        #/fn snippet
          (selective-snippet-zero snippet))
      #/dissect snippet (selective-snippet-nonzero d subject)
      #/w- unextend-hole
        (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
          (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
            (unextend-with-top-dim-sys-morphism-sys uds)))
      #/maybe-map
        (snippet-sys-snippet-zip-map-selective ess
          (snippet-sys-morphism-sys-morph-snippet
            (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
              (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
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
  (natural-transformation-from-from-dim-sys-sys-apply-to-morphism
    (snippet-format-sys-morphism-sys-functor-morphism sfsms)
    dsms))

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
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn
        (selective-functor-from-dim-sys-to-snippet-sys-sys sfs)
        (match/c selective-functor-from-dim-sys-to-snippet-sys-sys
          (ok/c sfs)))))
  (#:prop prop:functor-sys
    (make-functor-from-dim-sys-to-snippet-sys-sys-impl-from-apply
      (fn fs ds
        (dissect fs
          (selective-functor-from-dim-sys-to-snippet-sys-sys sfs)
        #/selective-snippet-sys sfs ds (fn h any/c)))
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
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn
        (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          sfsms)
        (match/c
          selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          (ok/c sfsms)))))
  (#:prop prop:natural-transformation-sys
    (make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-apply
      ; natural-transformation-sys-source
      (dissectfn
        (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          sfsms)
        (selective-functor-from-dim-sys-to-snippet-sys-sys
          (snippet-format-sys-morphism-sys-source sfsms)))
      ; natural-transformation-sys-replace-source
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
            'natural-transformation-sys-replace-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          (snippet-format-sys-morphism-sys-replace-source
            sfsms new-s)))
      ; natural-transformation-sys-target
      (dissectfn
        (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          sfsms)
        (selective-functor-from-dim-sys-to-snippet-sys-sys
          (snippet-format-sys-morphism-sys-target sfsms)))
      ; natural-transformation-sys-replace-target
      (fn ms new-t
        (dissect ms
          (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
            sfsms)
        #/expect new-t
          (selective-functor-from-dim-sys-to-snippet-sys-sys new-t)
          (w- t
            (selective-functor-from-dim-sys-to-snippet-sys-sys
              (snippet-format-sys-morphism-sys-target sfsms))
          #/raise-arguments-error
            'natural-transformation-sys-replace-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
          (snippet-format-sys-morphism-sys-replace-target
            sfsms new-t)))
      ; natural-transformation-sys-apply-to-morphism
      (fn ms a b dsms
        (dissect ms
          (selective-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys
            sfsms)
        #/selective-map-all-snippet-sys-morphism-sys sfsms dsms)))))

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
      ; snippet-format-sys-morphism-sys-functor-morphism
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
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn _ selective-snippet-format-sys-endofunctor-sys?)))
  (#:prop prop:functor-sys
    (make-snippet-format-sys-endofunctor-sys-impl-from-apply
      (fn es sfs #/selective-snippet-format-sys sfs)
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
;
; TODO: Export this, and stop exporting it from the `private/test`
; submodule once we do. Make sure to export it with a contract.
;
; TODO: Use the things that use this.
;
(define (snippet-sys-snippet-filter-maybe ss snippet)
  (w- ds (snippet-sys-dim-sys ss)
  #/w- d (snippet-sys-snippet-degree ss snippet)
  #/dlog 'g1
  #/snippet-sys-snippet-splice ss snippet #/fn hole data
    (dlog 'g1.1 hole data
    #/mat data (selected data) (just #/unselected data)
    #/dissect data (unselected data)
    #/dlog 'g2 hole
    #/maybe-map
      (snippet-sys-snippet-set-degree-maybe ss d
        (snippet-sys-shape->snippet ss hole))
    #/fn patch
      (dlog 'g3
      #/selected #/snippet-sys-snippet-select-everything ss patch))))

; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-map-selective ss snippet hv-to-v)
  (snippet-sys-snippet-map ss snippet #/fn hole data
    (mat data (unselected data) data
    #/dissect data (selected data) (hv-to-v hole data))))


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

; TODO: See if we can get this to return a flat contract. It's likely
; the only thing in our way is `by-own-method/c`.
(define (hypertee-coil/c ds)
  (w- ss (hypertee-snippet-sys ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/rename-contract
    (or/c
      hypertee-coil-zero?
      (and/c
        (match/c hypertee-coil-hole
          (dim-sys-0<dim/c ds)
          (snippet-sys-snippetof ss #/fn hole trivial?)
          any/c
          any/c)
        (by-own-method/c
          (hypertee-coil-hole overall-degree hole data tails)
          (match/c hypertee-coil-hole
            any/c
            any/c
            any/c
            (snippet-sys-snippet-zip-selective/c ss hole
              (fn hole subject-data #t)
              (fn hole shape-data subject-data
                (w- hole-d (snippet-sys-snippet-degree shape-ss hole)
                
                ; What this means is that this should be a snippet
                ; whose low-degree holes correspond to the holes of
                ; `hole` and contain `trivial?` values.
                ;
                ; TODO: See if we can factor out a
                ; `snippet-sys-snippet-zip-low-degree-holes/c` or
                ; something out of this.
                ;
                #/dlog 'p2 overall-degree
                #/and/c
                  (snippet-sys-snippet-with-degree=/c
                    ss overall-degree)
                  (snippet-sys-snippet-zip-selective/c ss hole
                    (fn tail-hole subject-data
                      (w- tail-hole-d
                        (snippet-sys-snippet-degree
                          shape-ss tail-hole)
                      #/dim-sys-dim<? ds tail-hole-d hole-d))
                    (fn hole shape-data subject-data trivial?)))))))))
    `(hypertee-coil/c ,(value-name-for-contract ds))))

; TODO: Use the things that use these.
; TODO: Change the way a `hypertee?` is written using
; `gen:custom-write`.
(define-imitation-simple-struct
  (hypertee? hypertee-dim-sys hypertee-coil)
  ; TODO NOW: While we debug this module, we've set up a system where
  ; we currently rename this from `unguarded-hypertee-furl` to
  ; `unguarded-hypertee-furl-orig` and define
  ; `unguarded-hypertee-furl` to be either the guarded version or the
  ; unguarded version (according to whichever definition is not
  ; commented out below). Change it back when the tests pass.
  unguarded-hypertee-furl-orig
  'hypertee (current-inspector) (auto-write) (auto-equal))
; TODO: We have a dilemma. The `define/contract` version of
; `attenuated-hypertee-furl` will give less precise source location
; information in its errors, and it won't catch applications with
; incorrect arity. On the other hand, the
; `define-match-expander-attenuated` version can't express a fully
; precise contract for `coil`, namely `(hypertee-coil/c dim-sys)`.
; Dependent contracts would be difficult to make matchers for, but
; perhaps we could implement an alternative to
; `define-match-expander-attenuated` that just defined the
; function-like side and not actually the match expander.
(define attenuated-hypertee-furl
  (let ()
    (define/contract (hypertee-furl dim-sys coil)
      (->i
        (
          [dim-sys dim-sys?]
          [coil (dim-sys) (hypertee-coil/c dim-sys)])
        [_ hypertee?])
      (unguarded-hypertee-furl-orig dim-sys coil))
    hypertee-furl))
#;
(define-match-expander-attenuated
  attenuated-hypertee-furl
  unguarded-hypertee-furl-orig
  [dim-sys dim-sys?]
  [coil any/c]
  #t)
(define-match-expander-from-match-and-make
  hypertee-furl
  unguarded-hypertee-furl-orig
  attenuated-hypertee-furl
  attenuated-hypertee-furl)
(define-syntax (hypertee-furl-dlog stx)
  (syntax-case stx () #/ (_ args ...)
    #`(dlog 'a1 #,(~a stx)
        (hypertee-furl args ...))))
#;
(define-match-expander-from-match-and-make
  unguarded-hypertee-furl
  hypertee-furl
  hypertee-furl
  hypertee-furl-dlog)
(define-match-expander-from-match-and-make
  unguarded-hypertee-furl
  unguarded-hypertee-furl-orig
  unguarded-hypertee-furl-orig
  unguarded-hypertee-furl-orig)

; TODO: Use the things that use this.
(define (hypertee/c ds)
  (rename-contract (match/c unguarded-hypertee-furl (ok/c ds) any/c)
    `(hypertee/c ,(value-name-for-contract ds))))

; TODO: See if we should export this.
; TODO: Use the things that use this.
(define (hypertee-map-cps ds state ht on-hole then)
  (w- ss (hypertee-snippet-sys ds)
  #/dissect ht (unguarded-hypertee-furl _ coil)
  #/mat coil (hypertee-coil-zero)
    (then state #/unguarded-hypertee-furl ds #/hypertee-coil-zero)
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
  #/then state #/dlog 'q1 #/unguarded-hypertee-furl ds
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
  #/dissect ht (unguarded-hypertee-furl _ coil)
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
  #/dissect shape (unguarded-hypertee-furl _ shape-coil)
  #/dissect snippet (unguarded-hypertee-furl _ snippet-coil)
  #/mat shape-coil (hypertee-coil-zero)
    (expect snippet-coil (hypertee-coil-zero) (nothing)
    #/just #/unguarded-hypertee-furl ds #/hypertee-coil-zero)
  #/dissect shape-coil
    (hypertee-coil-hole shape-d shape-hole shape-data shape-tails)
  #/expect snippet-coil
    (hypertee-coil-hole
      snippet-d snippet-hole snippet-data snippet-tails)
    (nothing)
  #/expect
    (snippet-sys-shape=? ss shape-hole snippet-hole
    #/fn hole shape-data snippet-data
      (dissect shape-data (trivial)
      #/dissect snippet-data (trivial)
        #t))
    #t
    (nothing)
  #/dlog 'e1 hvv-to-maybe-v
  #/maybe-bind (hvv-to-maybe-v shape-hole shape-data snippet-data)
  #/fn result-data
  #/dlog 'e2
  #/maybe-bind
    (hypertee-zip-map ds shape-tails snippet-tails
    #/fn hole shape-tail snippet-tail
      (w- d (snippet-sys-snippet-degree ss hole)
      #/hypertee-zip-map ds shape-tail snippet-tail
      #/fn hole shape-data snippet-data
        (if (dim-sys-dim<? ds (snippet-sys-snippet-degree ss hole) d)
          (dissect shape-data (trivial)
          #/dissect snippet-data (trivial)
            (just #/trivial))
          (hvv-to-maybe-v hole shape-data snippet-data))))
  #/fn result-tails
  #/just #/dlog 'q2 #/unguarded-hypertee-furl ds
    (hypertee-coil-hole snippet-d shape-hole result-data
      result-tails)))

; TODO: See if we should export this.
; TODO: Use the things that use this.
(define (hypertee-map-dim dsms ht)
  (w- target-ds (dim-sys-morphism-sys-target dsms)
  #/w- target-ss (hypertee-snippet-sys target-ds)
  #/dissect ht (unguarded-hypertee-furl _ coil)
  #/dlog 'q3 #/unguarded-hypertee-furl target-ds
    (mat coil (hypertee-coil-zero) (hypertee-coil-zero)
    #/dissect coil (hypertee-coil-hole d hole data tails)
    #/hypertee-coil-hole
      (dim-sys-morphism-sys-morph-dim dsms d)
      (hypertee-map-dim dsms hole)
      data
      (snippet-sys-snippet-map target-ss (hypertee-map-dim dsms tails)
        (fn hole tail #/hypertee-map-dim dsms tail)))))

; TODO: Use these.
(define-imitation-simple-struct
  (hypertee-snippet-sys? hypertee-snippet-sys-dim-sys)
  unguarded-hypertee-snippet-sys
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
      #/dissect snippet (unguarded-hypertee-furl _ coil)
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
      #/dissect snippet (unguarded-hypertee-furl _ coil)
      #/mat coil (hypertee-coil-zero)
        (expect (dim-sys-dim=0? ds degree) #t (nothing)
        #/just #/unguarded-hypertee-furl ds #/hypertee-coil-zero)
      #/dissect coil (hypertee-coil-hole d hole data tails)
      #/expect
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
        (dlog 'q4 #/unguarded-hypertee-furl ds
          (hypertee-coil-hole degree hole data tails))))
    ; snippet-sys-snippet-done
    (fn ss degree shape data
      (dissect ss (hypertee-snippet-sys ds)
      #/dlog 'q5 #/unguarded-hypertee-furl ds #/hypertee-coil-hole
        degree
        (snippet-sys-snippet-map ss shape #/fn hole data #/trivial)
        data
        (snippet-sys-snippet-map ss shape #/fn hole data
          (snippet-sys-snippet-done ss degree hole data))))
    ; snippet-sys-snippet-undone
    (fn ss snippet
      (dissect ss (hypertee-snippet-sys ds)
      #/dissect snippet (unguarded-hypertee-furl _ coil)
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
      #/dlog 'h0 ss snippet hv-to-splice
      #/w-loop next
        snippet snippet
        first-nontrivial-d (dim-sys-dim-zero ds)
        
        (dlog 'h0.1
        #/dissect snippet (unguarded-hypertee-furl _ coil)
        #/mat coil (hypertee-coil-zero)
          (just #/unguarded-hypertee-furl ds #/hypertee-coil-zero)
        #/dissect coil (hypertee-coil-hole d hole data tails)
        #/dlog 'h0.2 hv-to-splice data
        #/dlog 'h0.2.1 tails
        #/maybe-bind
          (if
            (dim-sys-dim<? ds
              (snippet-sys-snippet-degree ss hole)
              first-nontrivial-d)
            (dissect data (trivial)
              (just #/unselected #/trivial))
            (hv-to-splice hole data))
        #/fn splice
        #/maybe-bind
          (dlog 'h1
          #/snippet-sys-snippet-map-maybe ss tails #/fn hole tail
            (dlog 'h2 tail
            #/next tail
              (dim-sys-dim-max ds
                first-nontrivial-d
                (snippet-sys-snippet-degree ss hole))))
        #/fn tails
        #/dlog 'h0.3 splice
        #/mat splice (unselected data)
          (just #/dlog 'q6 #/unguarded-hypertee-furl ds
            (hypertee-coil-hole d hole data tails))
        #/dissect splice (selected suffix)
        #/dlog 'h3 suffix
        #/w- suffix
          (snippet-sys-snippet-map ss suffix #/fn hole data
            (mat data (selected data) (selected data)
            #/dissect data (unselected data)
              (unselected #/unselected data)))
        #/maybe-map
          (snippet-sys-snippet-zip-map-selective ss tails suffix
          #/fn hole tail data
            (dissect data (trivial)
            #/just #/selected tail))
        #/fn suffix
          (dlog 'h4 suffix
          #/snippet-sys-snippet-join-selective-prefix ss suffix))))
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
      #/dlog 'd1 ss shape snippet hvv-to-maybe-v
      #/mat shape (unguarded-hypertee-furl _ #/hypertee-coil-zero)
        (snippet-sys-snippet-map-maybe ss snippet #/fn hole data
          (mat data (selected data) (nothing)
          #/dissect data (unselected data) (just data)))
      #/dlog 'd2
      #/w- numbered-snippet
        (hypertee-map-cps ds 0 snippet
          (fn state hole data then
            (mat data (unselected data)
              (then state #/unselected data)
            #/dissect data (selected data)
              (then (add1 state) #/selected #/list state data)))
        #/fn state numbered-snippet
          numbered-snippet)
      #/dlog 'd2.1 numbered-snippet
      #/maybe-bind
        (snippet-sys-snippet-filter-maybe ss numbered-snippet)
      #/fn filtered-numbered-snippet
      #/dlog 'd3 hvv-to-maybe-v shape filtered-numbered-snippet
      #/maybe-bind
        (hypertee-zip-map ds shape filtered-numbered-snippet
        #/fn hole shape-data snippet-data
          (dissect snippet-data (list i snippet-data)
          #/dlog 'e3 hvv-to-maybe-v
          #/maybe-map (hvv-to-maybe-v hole shape-data snippet-data)
          #/fn result-data
            (list i result-data)))
      #/fn filtered-numbered-result
      #/dlog 'd4
      #/w- env
        (hypertee-each-ltr ds (make-immutable-hasheq)
          filtered-numbered-result
        #/fn env hole data
          (dissect data (list i data)
          #/hash-set env i data))
      #/just #/snippet-sys-snippet-map-selective ss numbered-snippet
      #/fn hole data
        (dissect data (list i data)
        #/hash-ref env i)))))
(define-match-expander-attenuated
  attenuated-hypertee-snippet-sys
  unguarded-hypertee-snippet-sys
  [dim-sys dim-sys?]
  #t)
(define-match-expander-from-match-and-make
  hypertee-snippet-sys
  unguarded-hypertee-snippet-sys
  attenuated-hypertee-snippet-sys
  attenuated-hypertee-snippet-sys)

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
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn _
        hypertee-functor-from-dim-sys-to-snippet-sys-sys?)))
  (#:prop prop:functor-sys
    (make-functor-from-dim-sys-to-snippet-sys-sys-impl-from-apply
      (fn fs ds #/hypertee-snippet-sys ds)
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
    snippet-sys-snippet/c ss-> degree-> ->degree shape-> ->shape
    snippet-> ->snippet)
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
      (->degree ss
        (snippet-sys-snippet-degree (ss-> ss)
          (snippet-> ss snippet))))
    ; snippet-sys-shape->snippet
    (fn ss shape
      (->snippet ss
        (snippet-sys-shape->snippet (ss-> ss) (shape-> ss shape))))
    ; snippet-sys-snippet->maybe-shape
    (fn ss snippet
      (maybe-map
        (snippet-sys-snippet->maybe-shape (ss-> ss)
          (snippet-> ss snippet))
      #/fn shape
        (->shape ss shape)))
    ; snippet-sys-snippet-set-degree-maybe
    (fn ss degree snippet
      (maybe-map
        (snippet-sys-snippet-set-degree-maybe (ss-> ss)
          (degree-> ss degree)
          (snippet-> ss snippet))
      #/fn selective
        (->snippet ss selective)))
    ; snippet-sys-snippet-done
    (fn ss degree shape data
      (->snippet ss
        (snippet-sys-snippet-done (ss-> ss)
          (degree-> ss degree)
          (shape-> ss shape)
          data)))
    ; snippet-sys-snippet-undone
    (fn ss snippet
      (maybe-map
        (snippet-sys-snippet-undone (ss-> ss) (snippet-> ss snippet))
      #/dissectfn (list d hole data)
        (list (->degree ss d) (->shape ss hole) data)))
    ; snippet-sys-snippet-splice
    (fn ss snippet hv-to-splice
      (maybe-map
        (snippet-sys-snippet-splice (ss-> ss) (snippet-> ss snippet)
        #/fn hole data
          (maybe-map (hv-to-splice (->shape ss hole) data) #/fn data
            (selectable-map data #/fn suffix
              (snippet-> ss suffix))))
      #/fn snippet
        (->snippet ss snippet)))
    ; snippet-sys-snippet-zip-map-selective
    (fn ss shape snippet hvv-to-maybe-v
      (maybe-map
        (snippet-sys-snippet-zip-map-selective (ss-> ss)
          (shape-> ss shape)
          (snippet-> ss snippet)
          (fn hole shape-data snippet-data
            (hvv-to-maybe-v
              (->shape ss hole)
              shape-data
              snippet-data)))
      #/fn snippet
        (->snippet ss snippet)))))


; TODO: Export this.
; TODO: Use the things that use this.
(define (hypernest-selective-snippet-sys sfs uds)
  (w- ffdstsss (snippet-format-sys-functor sfs)
  #/w- eds (fin-multiplied-dim-sys 2 uds)
  #/w- ess (functor-sys-apply-to-object ffdstsss eds)
  #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
  #/selective-snippet-sys sfs eds #/fn hole
    (expect (snippet-sys-snippet-undone shape-ess hole)
      (just #/list _ undone-hole _)
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
  #/w- ess (functor-sys-apply-to-object ffdstsss eds)
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

(define-imitation-simple-struct
  (hypernest-snippet-sys?
    hypernest-snippet-sys-snippet-format-sys
    hypernest-snippet-sys-dim-sys)
  unguarded-hypernest-snippet-sys
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
    ; degree->
    (fn ss degree
      (dissect ss (hypernest-snippet-sys sfs uds)
      #/w- dsms (fin-times-dim-sys-morphism-sys 2 uds #/fn d 0)
      #/dim-sys-morphism-sys-morph-dim dsms degree))
    ; ->degree
    (fn ss degree
      (dissect ss (hypernest-snippet-sys sfs uds)
      #/w- dsms (fin-untimes-dim-sys-morphism-sys 2 uds)
      #/dim-sys-morphism-sys-morph-dim dsms degree))
    ; shape->
    (fn ss shape
      (dissect ss (hypernest-snippet-sys sfs uds)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- dsms (fin-times-dim-sys-morphism-sys 2 uds #/fn d 0)
      #/w- ssms
        (functor-from-dim-sys-sys-apply-to-morphism ffdstsss dsms)
      #/w- shape-ssms
        (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys ssms)
      #/snippet-sys-morphism-sys-morph-snippet shape-ssms shape))
    ; ->shape
    (fn ss shape
      (dissect ss (hypernest-snippet-sys sfs uds)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- dsms (fin-untimes-dim-sys-morphism-sys 2 uds)
      #/w- ssms
        (functor-from-dim-sys-sys-apply-to-morphism ffdstsss dsms)
      #/w- shape-ssms
        (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys ssms)
      #/snippet-sys-morphism-sys-morph-snippet shape-ssms shape))
    ; snippet->
    (fn ss snippet
      (dissect snippet (hypernest-unchecked selective)
        selective))
    ; ->snippet
    (fn ss selective
      (hypernest-unchecked selective))))
(define-match-expander-attenuated
  attenuated-hypernest-snippet-sys
  unguarded-hypernest-snippet-sys
  [snippet-format-sys snippet-format-sys?]
  [dim-sys dim-sys?]
  #t)
(define-match-expander-from-match-and-make
  hypernest-snippet-sys
  unguarded-hypernest-snippet-sys
  attenuated-hypernest-snippet-sys
  attenuated-hypernest-snippet-sys)


; TODO: Use the things that use these.
(define-imitation-simple-struct
  (hypernest-coil-zero?)
  hypernest-coil-zero
  'hypernest-coil-zero (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct
  (hypernest-coil-hole?
    hypernest-coil-hole-overall-degree
    hypernest-coil-hole-hole
    hypernest-coil-hole-data
    hypernest-coil-hole-tails-hypertee)
  hypernest-coil-hole
  'hypernest-coil-hole (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct
  (hypernest-coil-bump?
    hypernest-coil-bump-overall-degree
    hypernest-coil-bump-data
    hypernest-coil-bump-bump-degree
    hypernest-coil-bump-tails-hypernest)
  hypernest-coil-bump
  'hypernest-coil-bump (current-inspector) (auto-write) (auto-equal))

; TODO: See if we can get this to return a flat contract. It's likely
; the only thing in our way is `by-own-method/c`.
(define (hypernest-coil/c ds)
  (w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/rename-contract
    (or/c
      hypernest-coil-zero?
      (and/c
        (match/c hypernest-coil-hole
          (dim-sys-0<dim/c ds)
          (snippet-sys-snippetof ss #/fn hole trivial?)
          any/c
          any/c)
        (by-own-method/c
          (hypernest-coil-hole
            overall-degree hole data tails-hypertee)
          (match/c hypernest-coil-hole
            any/c
            any/c
            any/c
            (snippet-sys-snippet-zip-selective/c shape-ss hole
              (fn hole subject-data #t)
              (fn hole shape-data subject-data
                (w- hole-d (snippet-sys-snippet-degree shape-ss hole)
                
                ; What this means is that this should be a snippet
                ; whose low-degree holes correspond to the holes of
                ; `hole` and contain `trivial?` values.
                ;
                ; TODO: See if we can factor out a
                ; `snippet-sys-snippet-zip-low-degree-holes/c` or
                ; something out of this.
                ;
                #/dlog 'p2.1 overall-degree
                #/and/c
                  (snippet-sys-snippet-with-degree=/c
                    ss overall-degree)
                  (snippet-sys-snippet-zip-selective/c ss hole
                    (fn tail-hole subject-data
                      (w- tail-hole-d
                        (snippet-sys-snippet-degree
                          shape-ss tail-hole)
                      #/dim-sys-dim<? ds tail-hole-d hole-d))
                    (fn hole shape-data subject-data trivial?))))))))
      (and/c
        (match/c hypernest-coil-bump
          (dim-sys-0<dim/c ds)
          any/c
          (dim-sys-dim/c ds)
          any/c)
        (by-own-method/c
          (hypernest-coil-bump
            overall-degree data bump-degree tails-hypernest)
          (match/c hypernest-coil-bump
            any/c
            any/c
            any/c
            (and/c
              (snippet-sys-snippet-with-degree=/c ss
                (dim-sys-dim-max ds overall-degree bump-degree))
              (snippet-sys-snippetof ss #/fn hole
                (w- hole-d
                  (snippet-sys-snippet-degree shape-ss hole)
                
                ; What this means is that this should be a snippet
                ; whose low-degree holes correspond to the holes of
                ; `hole` and contain `trivial?` values.
                ;
                ; TODO: See if we can factor out a
                ; `snippet-sys-snippet-zip-low-degree-holes/c` or
                ; something out of this.
                ;
                #/dlog 'p2.2 overall-degree
                #/and/c
                  (snippet-sys-snippet-with-degree=/c
                    ss overall-degree)
                  (snippet-sys-snippet-zip-selective/c ss hole
                    (fn tail-hole subject-data
                      (w- tail-hole-d
                        (snippet-sys-snippet-degree
                          shape-ss tail-hole)
                      #/dim-sys-dim<? ds tail-hole-d hole-d))
                    (fn hole shape-data subject-data trivial?)))))))))
    `(hypernest-coil/c ,(value-name-for-contract ds))))

(define (unguarded-fn-hypernest-furl dim-sys coil)
  (w- uds dim-sys
  #/w- mds (fin-multiplied-dim-sys 2 uds)
  #/w- emds (extended-with-top-dim-sys mds)
  #/w- emhtss (hypertee-snippet-sys emds)
  #/w- extend-dim
    (dim-sys-morphism-sys-chain-two
      (fin-times-dim-sys-morphism-sys 2 uds #/fn d 0)
      (extend-with-top-dim-sys-morphism-sys mds))
  #/mat coil (hypernest-coil-zero)
    (hypernest-unchecked #/selective-snippet-zero
      (unguarded-hypertee-furl mds #/hypertee-coil-zero))
  #/mat coil
    (hypernest-coil-hole overall-degree hole data tails-hypertee)
    (hypernest-unchecked #/selective-snippet-nonzero
      (fin-multiplied-dim 0 overall-degree)
      (unguarded-hypertee-furl emds #/hypertee-coil-hole
        (extended-with-top-dim-infinite)
        (hypertee-map-dim extend-dim hole)
        (selected data)
        (snippet-sys-snippet-map emhtss
          (hypertee-map-dim extend-dim tails-hypertee)
          (fn hole tail
            (dissect tail
              (hypernest-unchecked #/selective-snippet-nonzero
                (fin-multiplied-dim 0 _)
                tail-selective)
            #/snippet-sys-snippet-map-selective emhtss
              (snippet-sys-snippet-select-if-degree< emhtss
                (snippet-sys-snippet-degree emhtss hole)
                tail-selective)
            #/fn hole data
              (dissect data (selected #/trivial)
              #/trivial))))))
  #/dissect coil
    (hypernest-coil-bump
      overall-degree data bump-degree tails-hypernest)
    (dissect tails-hypernest
      (hypernest-unchecked #/selective-snippet-nonzero _
        tails-selective)
    #/dissect
      (snippet-sys-snippet-filter-maybe emhtss tails-selective)
      (just tails-shape)
    #/w- tails-assembled
      
      ; We construct the overall hypertee to use as the representation
      ; of the resulting hypernest.
      ;
      ; This hypertee begins with at least one hole, representing the
      ; bump of the `hypernest-coil-bump` coil.
      ;
      ; It also contains other holes representing the rest of the
      ; bumps and holes of the hypernest. We add in the rest of those
      ; holes by using appropriate tails in a
      ; `snippet-sys-snippet-bind-selective`. The `tails-hypernest`
      ; and each of the (hypernest) tails carried in its holes gives
      ; us what we need for one of those (hypertee) tails.
      ;
      ; TODO: See if it's simpler to keep the tails as hypernests and
      ; use them for a `(snippet-sys-snippet-bind-selective hnss ...)`
      ; instead.
      ;
      (snippet-sys-snippet-bind-selective emhtss
        (snippet-sys-snippet-done
          emhtss
          (extended-with-top-dim-infinite)
          
          ; We construct the shape of the hole that we're using to
          ; represent the bump. This hole is shaped like a "done"
          ; around the shape (`tails-shape`) of the bump's interior.
          ;
          ; As expected by our `snippet-sys-snippet-bind-selective`
          ; call, the elements in the holes this snippet are
          ; `selectable?` values, and the selected ones are tail
          ; snippets whose own holes contain
          ; `(selectable/c any/c trivial?)` values.
          ;
          (snippet-sys-snippet-done
            emhtss
            (extended-with-top-dim-finite
              (fin-multiplied-dim 1 bump-degree))
            (snippet-sys-snippet-map emhtss tails-shape
              (fn hole tail
                (w- prefix-d (snippet-sys-snippet-degree emhtss hole)
                #/dissect tail
                  (hypernest-unchecked
                    (selective-snippet-nonzero _ tail))
                #/selected
                  (snippet-sys-snippet-map emhtss tail
                    (fn hole selectable-tail-tail
                      (mat selectable-tail-tail
                        (unselected data)
                        (just #/unselected #/unselected data)
                      #/dissect selectable-tail-tail
                        (selected tail-tail)
                      #/w- suffix-d
                        (snippet-sys-snippet-degree emhtss hole)
                      #/if (dim-sys-dim<? emds suffix-d prefix-d)
                        (dissect tail-tail (trivial)
                        #/just #/selected #/trivial)
                      #/just #/unselected #/selected tail-tail))))))
            (selected
              (snippet-sys-snippet-map emhtss tails-selective
                (fn hole selectable-tail
                  (mat selectable-tail (unselected data)
                    (just #/unselected #/unselected data)
                  #/dissect selectable-tail (selected tail)
                    (just #/selected #/trivial))))))
          (unselected #/unselected data))
        (fn hole splice splice))
    
    #/hypernest-unchecked #/selective-snippet-nonzero
      (fin-multiplied-dim 0 overall-degree)
      tails-assembled)))

(define (hypernest-unfurl hn)
  (dissect hn (hypernest-unchecked hn-selective)
  #/mat hn-selective (selective-snippet-zero _)
    (hypernest-coil-zero)
  #/dissect hn-selective
    (selective-snippet-nonzero overall-degree
      (unguarded-hypertee-furl uds
        (hypertee-coil-hole (extended-with-top-dim-infinite)
          hole data tails)))
  #/w- mds (fin-multiplied-dim-sys 2 uds)
  #/w- emds (extended-with-top-dim-sys mds)
  #/w- htss (hypertee-snippet-sys uds)
  #/w- emhtss (hypertee-snippet-sys emds)
  #/w- hnss (hypernest-snippet-sys (hypertee-snippet-format-sys) uds)
  #/w- unextend-dim
    (dim-sys-morphism-sys-chain-two
      (unextend-with-top-dim-sys-morphism-sys mds)
      (fin-untimes-dim-sys-morphism-sys 2 uds))
  #/dissect (snippet-sys-snippet-degree emhtss tails)
    (extended-with-top-dim-finite
      (fin-multiplied-dim i bump-degree))
  #/mat i 0
    (dissect data (selected data)
    #/hypernest-coil-hole
      overall-degree
      (hypertee-map-dim unextend-dim hole)
      data
      (snippet-sys-snippet-map htss
        (hypertee-map-dim unextend-dim tails)
        (fn hole tail
          (hypernest-unchecked #/selective-snippet-nonzero
            (fin-multiplied-dim 0 overall-degree)
            (snippet-sys-snippet-map-selective htss
              (snippet-sys-snippet-select-if-degree< htss
                (snippet-sys-snippet-degree htss hole)
                tail)
              (fn hole data
                (dissect data (trivial)
                #/selected #/trivial)))))))
  #/dissect i 1
    (dissect (snippet-sys-snippet-undone emhtss tails)
      (just #/list _ tails interior)
    #/dissect (snippet-sys-snippet-degree emhtss tails)
      (extended-with-top-dim-finite
        (fin-multiplied-dim 0 bump-degree-again))
    #/dissect (dim-sys-dim=? uds bump-degree bump-degree-again) #t
    #/dissect data (unselected data)
    #/dissect
      (snippet-sys-snippet-zip-map hnss
        (hypertee-map-dim unextend-dim tails)
        (hypernest-unchecked interior)
        (fn tail interior-data
          (dissect interior-data (trivial)
          #/just #/hypernest-unchecked tail)))
      (just tails-hypernest)
    #/hypernest-coil-bump
      overall-degree data bump-degree tails-hypernest)))

; TODO: See if we need to rename this to `hypernest-furl` for better
; error messages. If so, we might need to put it in a submodule to
; avoid a namespace collision.
(define-match-expander (match-hypernest-furl stx)
  ; TODO: We should really use a syntax class for match patterns
  ; rather than `expr` here, but it doesn't look like one exists yet.
  (syntax-protect
  #/syntax-parse stx #/ (_ arg:expr)
    #'(app hypernest-unfurl arg)))

(define-match-expander-from-match-and-make
  unguarded-hypernest-furl
  match-hypernest-furl
  unguarded-fn-hypernest-furl
  unguarded-fn-hypernest-furl)

; TODO: We have a dilemma. The `define/contract` version of
; `attenuated-hypertee-furl` will give less precise source location
; information in its errors, and it won't catch applications with
; incorrect arity. On the other hand, the
; `define-match-expander-attenuated` version can't express a fully
; precise contract for `coil`, namely `(hypertee-coil/c dim-sys)`.
; Dependent contracts would be difficult to make matchers for, but
; perhaps we could implement an alternative to
; `define-match-expander-attenuated` that just defined the
; function-like side and not actually the match expander.
(define attenuated-fn-hypernest-furl
  (let ()
    (define/contract (hypernest-furl dim-sys coil)
      (->i
        (
          [dim-sys dim-sys?]
          [coil (dim-sys) (hypernest-coil/c dim-sys)])
        [_ hypertee?])
      (unguarded-hypernest-furl dim-sys coil))
    hypernest-furl))
#;
(define-match-expander-attenuated
  attenuated-hypernest-furl
  unguarded-hypernest-furl
  [dim-sys dim-sys?]
  [coil any/c]
  #t)
(define-match-expander-from-match-and-make
  hypernest-furl
  unguarded-hypernest-furl
  attenuated-fn-hypernest-furl
  attenuated-fn-hypernest-furl)


; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-select-nothing ss snippet)
  (snippet-sys-snippet-select ss snippet #/fn hole data #f))

; TODO: Use these.
(define-imitation-simple-struct
  (htb-labeled? htb-labeled-degree htb-labeled-data)
  htb-labeled
  'htb-labeled (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct
  (htb-unlabeled? htb-unlabeled-degree)
  htb-unlabeled
  'htb-unlabeled (current-inspector) (auto-write) (auto-equal))

; TODO: Use this.
(define (hypertee-bracket? v)
  (or (htb-labeled? v) (htb-unlabeled? v)))

; TODO: Use this.
(define (hypertee-bracket/c dim/c)
  (w- dim/c (coerce-contract 'hypertee-bracket/c dim/c)
  #/rename-contract
    (or/c
      (match/c htb-labeled dim/c any/c)
      (match/c htb-unlabeled dim/c))
    `(hypertee-bracket/c ,(contract-name dim/c))))

; TODO: Use this.
(define (hypertee-bracket-degree bracket)
  (mat bracket (htb-labeled d data) d
  #/dissect bracket (htb-unlabeled d) d))

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

; TODO: Use this.
(define (hypernest-bracket? v)
  (or (hnb-open? v) (hnb-labeled? v) (hnb-unlabeled? v)))

; TODO: Use this.
(define (hypernest-bracket/c dim/c)
  (w- dim/c (coerce-contract 'hypernest-bracket/c dim/c)
  #/rename-contract
    (or/c
      (match/c hnb-open dim/c any/c)
      (match/c hnb-labeled dim/c any/c)
      (match/c hnb-unlabeled dim/c))
    `(hypernest-bracket/c ,(contract-name dim/c))))

; TODO: Use this.
(define (hypernest-bracket-degree bracket)
  (mat bracket (hnb-open d data) d
  #/mat bracket (hnb-labeled d data) d
  #/dissect bracket (hnb-unlabeled d) d))

; TODO: Use this.
(define (hypertee-bracket->hypernest-bracket bracket)
  (mat bracket (htb-labeled d data) (hnb-labeled d data)
  #/dissect bracket (htb-unlabeled d) (hnb-unlabeled d)))

; TODO: Use this.
(define (compatible-hypernest-bracket->hypertee-bracket bracket)
  (mat bracket (hnb-labeled d data) (htb-labeled d data)
  #/dissect bracket (hnb-unlabeled d) (htb-unlabeled d)))

(define
  (explicit-hypernest-from-brackets
    err-name err-normalize-bracket ds degree brackets)
  
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
  
  (w- htss (hypertee-snippet-sys ds)
  #/w- hnss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- opening-degree degree
  #/if (dim-sys-dim=0? ds opening-degree)
    (expect brackets (list)
      (error "Expected brackets to be empty since degree was zero")
    #/unguarded-hypernest-furl ds #/hypernest-coil-zero)
  #/expect brackets (cons first-bracket brackets)
    (error "Expected brackets to be nonempty since degree was nonzero")
  #/w- root-i 'root
  #/w- stack (make-hyperstack ds opening-degree #/parent-same-part #t)
  #/dissect
    (mat first-bracket (hnb-open bump-degree data)
      (list
        (fn root-part
          (unguarded-hypernest-furl ds #/hypernest-coil-bump
            opening-degree data bump-degree root-part))
        (part-state #t (dim-sys-dim-zero ds) bump-degree
          (dim-sys-dim-max ds opening-degree bump-degree)
          (list))
        (hyperstack-push bump-degree stack #/parent-new-part))
    #/mat first-bracket (hnb-labeled hole-degree data)
      (expect (dim-sys-dim<? ds hole-degree opening-degree) #t
        (raise-arguments-error err-name
          "encountered a closing bracket of degree too high for where it occurred, and it was the first bracket"
          "overall-degree" opening-degree
          "first-bracket" (err-normalize-bracket first-bracket)
          "brackets" (map err-normalize-bracket brackets))
      #/dissect (hyperstack-pop hole-degree stack #/parent-new-part)
        (list (parent-same-part #t) stack)
      #/list
        (fn root-part
          (unguarded-hypernest-furl ds #/hypernest-coil-hole
            opening-degree
            (snippet-sys-snippet-map htss root-part #/fn hole tail
              (trivial))
            data
            root-part))
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
              (hypernest-from-brackets ds overall-degree
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

; TODO: Use this.
(define (hypernest-from-brackets ds degree brackets)
  (explicit-hypernest-from-brackets
    'hypernest-from-brackets (fn hnb hnb) ds degree brackets))

; TODO: Use this.
(define (hn-bracs ds degree . brackets)
  (explicit-hypernest-from-brackets 'hn-bracs (fn hnb hnb) ds degree
    (list-map brackets #/fn closing-bracket
      (if (hypernest-bracket? closing-bracket)
        closing-bracket
        (hnb-unlabeled closing-bracket)))))

(define (explicit-hypertee-from-brackets err-name ds degree brackets)
  (just-value
    (snippet-sys-snippet->maybe-shape
      (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
      (explicit-hypernest-from-brackets
        err-name
        (fn hnb #/compatible-hypernest-bracket->hypertee-bracket hnb)
        ds
        degree
        (list-map brackets #/fn htb
          (hypertee-bracket->hypernest-bracket htb))))))

; TODO: Use this.
(define (hypertee-from-brackets ds degree brackets)
  (explicit-hypertee-from-brackets
    'hypertee-from-brackets ds degree brackets))

; TODO: Use this.
(define (ht-bracs ds degree . brackets)
  (explicit-hypertee-from-brackets 'ht-bracs ds degree
    (list-map brackets #/fn closing-bracket
      (if (hypertee-bracket? closing-bracket)
        closing-bracket
        (htb-unlabeled closing-bracket)))))


; TODO: Export this.
; TODO: Use this.
(define (hypernest-brackets hn)
  (dissect hn (hypernest-unchecked hn-selective)
  #/mat hn-selective (selective-snippet-zero ht) (list)
  #/dissect hn-selective (selective-snippet-nonzero _ ht)
  #/dissect ht (unguarded-hypertee-furl emds _)
  #/dissect emds (extended-with-top-dim-sys mds)
  #/dissect mds (fin-multiplied-dim-sys 2 uds)
  #/w- hnss (hypernest-snippet-sys (hypertee-snippet-format-sys) uds)
  #/w- emhtss (hypertee-snippet-sys emds)
  #/w- prepend
    (fn hnb rest
      (snippet-sys-snippet-bind-selective emhtss
        (hypertee-from-brackets emds
          (extended-with-top-dim-infinite)
          (list
            (htb-labeled
              (extended-with-top-dim-finite
                (fin-multiplied-dim 1 #/dim-sys-dim-zero uds))
              (unselected hnb))
            (htb-unlabeled #/dim-sys-dim-zero emds)
            (htb-labeled (dim-sys-dim-zero emds)
              (selected #/snippet-sys-snippet-select-nothing emhtss
                rest))))
        (fn hole splice splice)))
  #/w- ht->list
    (fn ht
      (w-loop next ht ht rev-result (list)
        (dissect ht
          (unguarded-hypertee-furl _
            (hypertee-coil-hole
              (extended-with-top-dim-infinite)
              hole
              data
              (unguarded-hypertee-furl _ tails-coil)))
        #/mat tails-coil (hypertee-coil-zero)
          (dissect data (trivial)
          #/reverse rev-result)
        #/dissect tails-coil
          (hypertee-coil-hole
            (extended-with-top-dim-finite #/fin-multiplied-dim 1 d)
            tails-hole
            tail
            (unguarded-hypertee-furl _ #/hypertee-coil-zero))
        #/dissect (dim-sys-dim=0? uds d) #t
        #/next tail #/cons data rev-result)))
  #/ht->list #/snippet-sys-snippet-bind-selective emhtss
    (w-loop next ht ht
      ; TODO: See if this can use `hypernest-unfurl` somehow, since it
      ; duplicates some of its behavior (particularly the
      ; `snippet-sys-snippet-undone` call and some of the surrounding
      ; code).
      (dissect ht
        (unguarded-hypertee-furl _
          (hypertee-coil-hole (extended-with-top-dim-infinite)
            hole data tails))
      #/dissect (snippet-sys-snippet-degree emhtss tails)
        (extended-with-top-dim-finite d)
      #/mat d (fin-multiplied-dim 1 d)
        (dissect (snippet-sys-snippet-undone emhtss tails)
          (just #/list
            (extended-with-top-dim-finite
              (fin-multiplied-dim 1 d-again))
            tails
            interior)
        #/dissect (dim-sys-dim=? uds d d-again) #t
        #/dissect (snippet-sys-snippet-degree emhtss tails)
          (extended-with-top-dim-finite
            (fin-multiplied-dim 0 d-again))
        #/dissect (dim-sys-dim=? uds d d-again) #t
        #/dissect data (unselected data)
        #/prepend (unselected #/hnb-open d data)
          (snippet-sys-snippet-bind-selective emhtss
            (snippet-sys-snippet-zip-map-selective emhtss
              tails
              (snippet-sys-snippet-select emhtss (next interior)
                (fn hole data
                  (selected? data)))
            #/fn hole tail data
              (dissect data (selected #/trivial)
              #/dissect (snippet-sys-snippet-degree emhtss hole)
                (extended-with-top-dim-finite
                  (fin-multiplied-dim 0 d))
              #/just
                (selected
                  (prepend
                    (unselected #/hnb-unlabeled d)
                    (next tail)))))
            (fn hole splice splice)))
      #/dissect d (fin-multiplied-dim 0 d)
        (dissect data (selected data)
        #/dlog 'q8 #/unguarded-hypertee-furl emds #/hypertee-coil-hole
          (extended-with-top-dim-infinite)
          hole
          (selected data)
          (snippet-sys-snippet-map emhtss tails #/fn hole tail
            (dissect (snippet-sys-snippet-degree emhtss hole)
              (extended-with-top-dim-finite #/fin-multiplied-dim 0 d)
            #/prepend (unselected #/hnb-unlabeled d) (next tail))))))
    (fn hole selectable-data
      (dissect (snippet-sys-snippet-degree emhtss hole)
        (extended-with-top-dim-finite d)
      #/mat d (fin-multiplied-dim 1 d)
        (dissect selectable-data (unselected data)
        #/unselected data)
      #/dissect d (fin-multiplied-dim 0 d)
        (dissect selectable-data (selected data)
        #/dissect
          (snippet-sys-snippet-set-degree-maybe emhtss
            (extended-with-top-dim-infinite)
            hole)
          (just rest)
        #/selected #/snippet-sys-snippet-select-if-degree< emhtss
          (extended-with-top-dim-finite #/fin-multiplied-dim 0 d)
          (prepend (hnb-labeled d data) rest))))))

; TODO: Export this.
; TODO: Use this.
(define (hypertee-brackets ht)
  (dissect ht (unguarded-hypertee-furl ds coil)
  #/list-map
    (hypernest-brackets #/snippet-sys-shape->snippet
      (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
      ht)
  #/fn hnb
    (compatible-hypernest-bracket->hypertee-bracket hnb)))
