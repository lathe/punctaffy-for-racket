#lang parendown racket/base

; punctaffy/private/hypertee-as-brackets
;
; A data structure for encoding the kind of higher-order structure
; that occurs in higher quasiquotation (represented in a
; sequence-of-brackets style).

;   Copyright 2017-2020, 2022 The Lathe Authors
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
  -> ->i and/c any any/c contract? contract-name contract-out
  flat-contract? list/c listof not/c or/c rename-contract)
(require #/only-in racket/contract/combinator
  coerce-contract contract-first-order-passes?)
(require #/only-in racket/math natural?)
(require #/only-in racket/struct make-constructor-style-printer)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/hash hash-kv-each)
(require #/only-in lathe-comforts/list
  list-all list-any list-bind list-each list-foldl list-foldr
  list-kv-map list-map)
(require #/only-in lathe-comforts/match
  define-match-expander-attenuated
  define-match-expander-from-match-and-make match/c)
(require #/only-in lathe-comforts/maybe
  just maybe? maybe/c maybe-map nothing)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-struct struct-easy)
(require #/only-in lathe-comforts/trivial trivial)
(require #/only-in lathe-morphisms/in-fp/mediary/set ok/c)

(require punctaffy/private/shim)
(init-shim)

(require #/only-in punctaffy/hypersnippet/dim
  dim-successors-sys? dim-successors-sys-dim-from-int
  dim-successors-sys-dim-plus-int dim-successors-sys-dim=plus-int?
  dim-successors-sys-dim-sys dim-sys? dim-sys-dim<? dim-sys-dim<=?
  dim-sys-dim=? dim-sys-dim=0? dim-sys-dim/c dim-sys-0<dim/c
  dim-sys-dim-max dim-sys-dim-zero)
(require #/only-in punctaffy/hypersnippet/hyperstack
  hyperstack-dimension hyperstack-pop-trivial hyperstack-pop
  hyperstack-push make-hyperstack-trivial make-hyperstack)
(require #/only-in punctaffy/private/suppress-internal-errors
  punctaffy-suppress-internal-errors)


(provide
  htb-labeled)
(provide #/contract-out
  [htb-labeled? (-> any/c boolean?)]
  [htb-labeled-degree (-> htb-labeled? any/c)]
  [htb-labeled-data (-> htb-labeled? any/c)])
(provide
  htb-unlabeled)
(provide #/contract-out
  [htb-unlabeled? (-> any/c boolean?)]
  [htb-unlabeled-degree (-> htb-unlabeled? any/c)])
(provide #/contract-out
  [hypertee-bracket? (-> any/c boolean?)]
  [hypertee-bracket/c (-> contract? contract?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it's not exported.
  [hypertee-bracket-degree (-> hypertee-bracket? any/c)]
  [hypertee? (-> any/c boolean?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it's called
  ; `hypertee-get-dim-sys`.
  [hypertee-dim-sys (-> hypertee? dim-sys?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it isn't exported.
  [hypertee-degree
    (->i ([ht hypertee?])
      [_ (ht) (dim-sys-dim/c #/hypertee-dim-sys ht)])]
  ; TODO DOCS: Consider more expressive hypertee contract combinators
  ; than `hypertee/c`, and come up with a new name for it.
  [hypertee/c (-> dim-sys? flat-contract?)])
(module+ unsafe #/provide #/contract-out
  [unsafe-hypertee-from-brackets (-> dim-sys? any/c any/c any)])
(provide #/contract-out
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
        #/listof #/or/c
          (hypertee-bracket/c dim/c)
          (and/c (not/c hypertee-bracket?) dim/c))]
      [_ (ds) (hypertee/c ds)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist.
  [ht-bracs-dss
    (->i
      (
        [dss dim-successors-sys?]
        [degree (dss)
          (or/c natural?
          #/dim-sys-dim/c #/dim-successors-sys-dim-sys dss)])
      #:rest
      [brackets (dss)
        (w- dim/c
          (or/c natural?
          #/dim-sys-dim/c #/dim-successors-sys-dim-sys dss)
        #/listof #/or/c
          (hypertee-bracket/c dim/c)
          (and/c (not/c hypertee-bracket?) dim/c))]
      [_ (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)])]
  [hypertee-get-brackets
    (->i ([ht hypertee?])
      [_ (ht)
        (w- ds (hypertee-dim-sys ht)
        #/listof #/hypertee-bracket/c #/dim-sys-dim/c ds)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. If it
  ; did exist, it would use a more specific contract that asserted the
  ; result was of the requested degree.
  [hypertee-increase-degree-to
    (->i
      (
        [new-degree (ht) (dim-sys-dim/c #/hypertee-dim-sys ht)]
        [ht hypertee?])
      [_ (ht) (hypertee/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. If it
  ; did exist, it would use a more specific contract that asserted the
  ; result was of the requested degree.
  [hypertee-set-degree-maybe
    (->i
      (
        [new-degree (ht) (dim-sys-0<dim/c #/hypertee-dim-sys ht)]
        [ht hypertee?])
      [_ (ht) (maybe/c #/hypertee/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. If it
  ; did exist, it would use a more specific contract that asserted the
  ; result was of the requested degree.
  [hypertee-set-degree-force
    (->i
      (
        [new-degree (ht) (dim-sys-0<dim/c #/hypertee-dim-sys ht)]
        [ht hypertee?])
      [_ (ht) (hypertee/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. Lately,
  ; we've preferred `snippet-sys-snippet-done` for this purpose rather
  ; than associating dimensions with successors.
  [hypertee-contour
    (->i
      (
        [dss dim-successors-sys?]
        [hole-value any/c]
        [ht (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)])
      [_ (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)])])
(provide
  hypertee-coil-zero)
(provide #/contract-out
  [hypertee-coil-zero? (-> any/c boolean?)])
(provide
  hypertee-coil-hole)
(provide #/contract-out
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where there's an extra
  ; `hypertee-coil-hole-hole` field and
  ; `hypertee-coil-hole-tails-hypertee` is called
  ; `hypertee-coil-hole-tails`.
  [hypertee-coil-hole? (-> any/c boolean?)]
  [hypertee-coil-hole-overall-degree (-> hypertee-coil-hole? any/c)]
  [hypertee-coil-hole-data (-> hypertee-coil-hole? any/c)]
  [hypertee-coil-hole-tails-hypertee
    (-> hypertee-coil-hole? any/c)])
(provide #/contract-out
  [hypertee-coil/c (-> dim-sys? flat-contract?)])
(provide #/contract-out
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it's called
  ; `hypertee-get-coil`.
  [hypertee-unfurl
    (->i ([ht hypertee?])
      [_ (ht) (hypertee-coil/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist.  It
  ; would probably be accommodated through a mix of
  ; `hypertee-snippet-sys` and `snippet-sys-snippet-map`. If it did
  ; exist, it would be called `hypertee-map`, it would pass its
  ; callback a hole shape rather than merely a degree, and it would
  ; use a more specific contract that asserted the result was of the
  ; same degree as the original.
  [hypertee-dv-map-all-degrees
    (->i
      (
        [ht hypertee?]
        [func (ht)
          (-> (dim-sys-dim/c #/hypertee-dim-sys ht) any/c any/c)])
      [_ (ht) (hypertee/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring `punctaffy/hypersnippet/hypertee`'s
  ; `hypertee-snippet-sys` and `hypertee-snippet-format-sys` into
  ; parity with this module, where they don't exist.
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypertee-snippet-sys`, `snippet-sys-snippet-select-if-degree`,
  ; and `snippet-sys-snippet-map-selective`. If it did exist, it would
  ; be called `hypertee-map-if-degree=`, it would pass its callback a
  ; hole shape in addition to the value, and it would use a more
  ; specific contract that asserted the result was of the same degree
  ; as the original.
  [hypertee-v-map-one-degree
    (->i
      (
        [degree (ht) (dim-sys-dim/c #/hypertee-dim-sys ht)]
        [ht hypertee?]
        [func (-> any/c any/c)])
      [_ (ht) (hypertee/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist.
  [hypertee-v-map-highest-degree
    (->i
      (
        [dss dim-successors-sys?]
        [ht (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)]
        [func (-> any/c any/c)])
      [_ (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist.
  [hypertee-fold
    (->i
      (
        [first-nontrivial-d (ht)
          (dim-sys-dim/c #/hypertee-dim-sys ht)]
        [ht hypertee?]
        [on-zero (-> any/c)]
        [on-hole (ht)
          (w- ds (hypertee-dim-sys ht)
          #/-> (dim-sys-dim/c ds) any/c (hypertee/c ds) any/c)])
      [_ any/c])])
(provide
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/snippet`, where it's called `selected`.
  hypertee-join-selective-interpolation)
(provide #/contract-out
  [hypertee-join-selective-interpolation? (-> any/c boolean?)]
  [hypertee-join-selective-interpolation-val
    (-> hypertee-join-selective-interpolation? any/c)])
(provide
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/snippet`, where it's called `unselected`.
  hypertee-join-selective-non-interpolation)
(provide #/contract-out
  [hypertee-join-selective-non-interpolation? (-> any/c boolean?)]
  [hypertee-join-selective-non-interpolation-val
    (-> hypertee-join-selective-interpolation? any/c)])
(provide #/contract-out
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypertee-snippet-sys` and
  ; `snippet-sys-snippet-join-selective`. If it did exist, it would be
  ; called `hypertee-join-selective`, and it would use a much more
  ; specific contract.
  [hypertee-join-all-degrees-selective (-> hypertee? hypertee?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. If it
  ; did exist, it would be called `hypertee-map`, and it would use a
  ; much more specific contract.
  [hypertee-map-all-degrees
    (-> hypertee? (-> hypertee? any/c any/c) hypertee?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypertee-snippet-sys`,
  ; `snippet-sys-snippet-select-if-degree`, and
  ; `snippet-sys-snippet-map-selective`. If it did exist, it would be
  ; called `hypertee-map-if-degree=`, and it would use a more specific
  ; contract that asserted the result was of the same degree as the
  ; original.
  [hypertee-map-one-degree
    (->i
      (
        [degree (ht) (dim-sys-dim/c #/hypertee-dim-sys ht)]
        [ht hypertee?]
        [func (ht) (-> (hypertee/c #/hypertee-dim-sys ht) any/c any/c)])
      [_ (ht) (hypertee/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist.
  [hypertee-map-highest-degree
    (->i
      (
        [dss dim-successors-sys?]
        [ht (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)]
        [func (dss)
          (-> (hypertee/c #/dim-successors-sys-dim-sys dss) any/c
            any/c)])
      [_ (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypertee-snippet-sys` and
  ; `snippet-sys-snippet-done`. If it did exist, it would pass the
  ; hole shape argument before the data argument, and it would use a
  ; more specific contract that asserted the result was of the
  ; requested degree.
  [hypertee-done
    (->i
      (
        [degree (hole) (dim-sys-dim/c #/hypertee-dim-sys hole)]
        [data any/c]
        [hole hypertee?])
      [_ (hole) (hypertee/c #/hypertee-dim-sys hole)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it's called
  ; `hypertee-get-hole-zero-maybe` and has a more specific contract.
  [hypertee-get-hole-zero (-> hypertee? maybe?)]
  [hypertee-furl
    (->i
      (
        [ds dim-sys?]
        [coil (ds) (hypertee-coil/c ds)])
      [_ (ds) (hypertee/c ds)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypertee-snippet-sys` and
  ; `snippet-sys-snippet-join`. If it did exist, it would be called
  ; `hypertee-join`, and it would use a much more specific contract.
  [hypertee-join-all-degrees (-> hypertee? hypertee?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypertee-snippet-sys` and
  ; `snippet-sys-snippet-bind`. If it did exist, it would be called
  ; `hypertee-bind`, and it would use a much more specific contract.
  [hypertee-bind-all-degrees
    (->i
      (
        [ht hypertee?]
        [func (ht)
          (-> (hypertee/c #/hypertee-dim-sys ht) any/c
            (hypertee/c #/hypertee-dim-sys ht))])
      [_ (ht) (hypertee/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypertee-snippet-sys`,
  ; `snippet-sys-snippet-select-if-degree`, and
  ; `snippet-sys-snippet-bind-selective`. If it did exist, it would be
  ; called `hypertee-bind-if-degree=`, and it would use a much more
  ; specific contract.
  [hypertee-bind-one-degree
    (->i
      (
        [degree (ht) (dim-sys-dim/c #/hypertee-dim-sys ht)]
        [ht hypertee?]
        [func (ht)
          (-> (hypertee/c #/hypertee-dim-sys ht) any/c
            (hypertee/c #/hypertee-dim-sys ht))])
      [_ (ht) (hypertee/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist.
  [hypertee-bind-pred-degree
    (->i
      (
        [dss dim-successors-sys?]
        [degree (dss) (dim-sys-dim/c #/dim-successors-sys-dim-sys dss)]
        [ht hypertee?]
        [func (dss)
          (w- ds (dim-successors-sys-dim-sys dss)
          #/-> (hypertee/c ds) any/c (hypertee/c ds))])
      [_ (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypertee-snippet-sys`,
  ; `snippet-sys-snippet-select-if-degree`, and
  ; `snippet-sys-snippet-join-selective`. If it did exist, it would be
  ; called `hypertee-join-if-degree=`, and it would use a much more
  ; specific contract.
  [hypertee-join-one-degree
    (->i
      (
        [degree (ht) (dim-sys-dim/c #/hypertee-dim-sys ht)]
        [ht hypertee?])
      [_ (ht) (hypertee/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypertee-snippet-sys`, `snippet-sys-snippet-bind`, and
  ; `snippet-sys-snippet-set-degree-maybe`. If it did exist, it might
  ; be called `hypertee-set-degree-and-bind`, and it would use a much
  ; more specific contract.
  [hypertee-set-degree-and-bind-all-degrees
    (->i
      (
        [new-degree (ht) (dim-sys-0<dim/c #/hypertee-dim-sys ht)]
        [ht hypertee?]
        [hole-to-ht (ht)
          (w- ds (hypertee-dim-sys ht)
          #/-> (hypertee/c ds) any/c (hypertee/c ds))])
      [_ (ht) (hypertee/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypertee-snippet-sys` and the not-yet-exported
  ; `snippet-sys-snippet-join-list-and-tail-along-0`. If it did exist,
  ; it might be called `hypertee-join-list-and-tail-along-0`, it
  ; wouldn't take a `degree` argument, it would take a `last-snippet`
  ; argument, and it would use a much more specific contract.
  [hypertee-append-zero
    (->i
      (
        [ds dim-sys?]
        [degree (ds) (dim-sys-0<dim/c ds)]
        [hts (ds) (listof #/hypertee/c ds)])
      [_ (ds) (hypertee/c ds)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypertee-snippet-sys` and `snippet-sys-snippet-any?`. If it did
  ; exist, it would be called `hypertee-any?`, it would pass its
  ; callback a hole shape rather than merely a degree, and it wouldn't
  ; allow non-boolean results.
  [hypertee-dv-any-all-degrees
    (->i
      (
        [ht hypertee?]
        [func (ht)
          (-> (dim-sys-dim/c #/hypertee-dim-sys ht) any/c any/c)])
      [_ any/c])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypertee-snippet-sys` and `snippet-sys-snippet-all?`. If it did
  ; exist, it would be called `hypertee-all?`, it would pass its
  ; callback a hole shape rather than merely a degree, and it wouldn't
  ; allow non-boolean results.
  [hypertee-dv-all-all-degrees
    (->i
      (
        [ht hypertee?]
        [func (ht)
          (-> (dim-sys-dim/c #/hypertee-dim-sys ht) any/c any/c)])
      [_ any/c])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypertee-snippet-sys` and `snippet-sys-snippet-each` or through
  ; the not-yet-exported `hypertee-each-ltr`. If it did exist, it
  ; would be called `hypertee-each` or `hypertee-each-ltr`, and it
  ; would pass its callback a hole shape rather than merely a degree.
  [hypertee-dv-each-all-degrees
    (->i
      (
        [ht hypertee?]
        [func (ht)
          (-> (dim-sys-dim/c #/hypertee-dim-sys ht) any/c any)])
      [_ void?])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypertee-snippet-sys` and `snippet-sys-snippet-each` or through
  ; the not-yet-exported `hypertee-each-ltr`. If it did exist, it
  ; would be called `hypertee-each-if-degree=` or
  ; `hypertee-each-ltr-if-degree=`, and it would pass its callback a
  ; hole shape in addition to the value.
  [hypertee-v-each-one-degree
    (->i
      (
        [degree (ht) (dim-sys-dim/c #/hypertee-dim-sys ht)]
        [ht hypertee?]
        [body (ht) (-> any/c any)])
      [_ void?])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypertee-snippet-sys` and `snippet-sys-snippet-each` or through
  ; the not-yet-exported `hypertee-each-ltr`. If it did exist, it
  ; would be called `hypertee-each` or `hypertee-each-ltr`, and it
  ; would use a more specific contract.
  [hypertee-each-all-degrees
    (-> hypertee? (-> hypertee? any/c any) void?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. Lately,
  ; we've preferred `snippet-sys-snippet-undone` for this purpose
  ; rather than associating dimensions with successors.
  [hypertee-uncontour
    (->i
      (
        [dss dim-successors-sys?]
        [ht (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)])
      [_ (dss)
        (maybe/c #/list/c
          any/c
          (hypertee/c #/dim-successors-sys-dim-sys dss))])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypertee-snippet-sys`, `snippet-sys-snippet-select`, and the
  ; not-yet-exported `snippet-sys-snippet-filter-maybe`. If it did
  ; exist, `hypertee-filter` is a fair name for it, and
  ; `snippet-sys-snippet-filter-maybe` would probably be called
  ; something else.
  [hypertee-filter
    (-> hypertee? (-> hypertee? any/c boolean?) hypertee?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypertee-snippet-sys`, `snippet-sys-snippet-select-if-degree<`,
  ; and the not-yet-exported `snippet-sys-snippet-filter-maybe`. If it
  ; did exist, it would use a more specific contract that asserted the
  ; result was of the requested degree.
  [hypertee-filter-degree-to
    (->i
      (
        [new-degree (ht) (dim-sys-dim/c #/hypertee-dim-sys ht)]
        [ht hypertee?])
      [_ (ht) (hypertee/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; might be related to the not-yet-exported `hypertee-map-cps` and
  ; `hypertee-each-cps`.
  [hypertee-dv-fold-map-any-all-degrees
    (->i
      (
        [state any/c]
        [ht hypertee?]
        [on-hole (ht)
          (-> any/c (dim-sys-dim/c #/hypertee-dim-sys ht) any/c
            (list/c any/c #/maybe/c any/c))])
      [_ (ht)
        (list/c any/c #/maybe/c #/hypertee/c #/hypertee-dim-sys ht)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypertee-snippet-sys` and
  ; `snippet-sys-snippet-zip-map-selective`. If it did exist, it would
  ; be called `hypertee-zip-map-selective`, it would allow its smaller
  ; argument to have a degree less than that of its bigger argument,
  ; it would expect its bigger argument to contain `selectable?`
  ; values instead of taking a separate predicate, it would allow the
  ;  transformer function to return a maybe value for early exiting,
  ; and it would use a more specific contract that asserted the result
  ; was of the same degree as the bigger argument.
  [hypertee-selective-holes-zip-map
    (->i
      (
        [smaller (bigger) (hypertee/c #/hypertee-dim-sys bigger)]
        [bigger hypertee?]
        [should-zip? (bigger)
          (-> (hypertee/c #/hypertee-dim-sys bigger) any/c
            boolean?)]
        [func (bigger)
          (-> (hypertee/c #/hypertee-dim-sys bigger) any/c any/c
            any/c)])
      [_ (bigger) (maybe/c #/hypertee/c #/hypertee-dim-sys bigger)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypertee`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypertee-snippet-sys`,
  ; `snippet-sys-snippet-select-if-degree<`, and
  ; `snippet-sys-snippet-zip-map-selective`. If it did exist, it would
  ; be called `hypertee-zip-map-if-degree<`, it would allow its
  ; smaller argument to have a degree less than that of its bigger
  ; argument, it would allow the transformer function to return a
  ; maybe value for early exiting, and it would use a much more
  ; specific contract.
  [hypertee-low-degree-holes-zip-map
    (-> hypertee? hypertee? (-> hypertee? any/c any/c any/c)
      (maybe/c hypertee?))])


; ===== Hypertees ====================================================

; Intuitively, what we want to represent are higher-order snippets of
; data. A degree-1 snippet is everything after one point in the data,
; except for everything after another point. A degree-2 snippet is
; everything inside one degree-1 snippet, except for everything inside
; some other degree-1 snippets inside it, and so on. Extrapolating
; backwards, a degree-0 snippet is "everything after one point."
; Collectively, we'll call these hypersnippets.
;
; Here's an example of a degree-4 hypersnippet shape -- just the
; shape, omitting whatever data is contained inside:
;
;    ^4( ~3( ~2( ~2( ,( ,( ,( ,( ) ) ) ) ) ) ) )
;
; This has one degree-3 hole, one degree-2 hole, one degree-1 hole,
; and one degree-0 hole. If we remove the solitary degree-3 hole, we
; end up with a degree-4 hypersnippet that simply has no degree-3
; holes, but that kind of hypersnippet *could* be demoted to degree 3:
;
;    ^3(         ~2( ,(       ,( )     ) )     )
;
; And so on, we can eliminate high-degree holes and demote until we
; have to stop at a degree-0 snippet:
;
;    ^2(                      ,( )             )
;      (                                       )
;      ;
;
; Most discussions of "expressions with holes" refer to degree-1
; holes for our purposes, because standard lambda calculus notation
; represents an expression using data that fits snugly in a degree-1
; hypersnippet of text.
;
; To represent hypersnippet-shaped data, we'll use a simpler building
; block we call a "hypertee." A hypertee has the shape of a
; hypersnippet, but it contains precisely one first-class value per
; hole. So if a hypertee had the shape "^2( ,( ) )" it would have two
; values, one for the ",( )" hole and another for the ")" hole at the
; end. And if a hypertee is degree 1, then it's always of the shape
; "( )", so it always has a single value corresponding to the ")".
;
; The name "hypertee" refers to the way it's like a T-shaped coupling.
; It's not exactly a symmetrical branch like the nodes of an everyday
; tree, because some of the holes shoot off in a different dimension
; from all the others.
;
; The values of a hypertee's holes represent information about what's
; on the other side of that hole, rather than telling us something
; about the *inside* of the hypersnippet region of that shape. If we
; want to represent simple data inside that shape, we can simply pair
; the hypertee with a second value representing that data.
;
; Sometimes, the data of a hypersnippet isn't so simple that it can
; be represented using a single first-class value. For instance,
; consider the data in an interpolated string:
;
;     "Hello, ${name}! It's ${weather} today."
;
; The string content of this interpolated string is a degree-1
; hypersnippet with two degree-1 holes (and a degree-0 hole). Here's
; that hypersnippet's shape:
;
;   ^2(       ,(    )       ,(       )       )
;
; On the other side of the degree-1 holes are the expressions `name`
; and `weather`. We can use a hypertee to carry those two expressions
; in a way that keeps track of which hole they each belong to, but
; that doesn't help us carry the strings "Hello, " and "! It's " and
; " today.". We can carry those by moving to a more sophisticated
; representation built out of hypertees.
;
; Above, we were taking a hypersnippet shape, removing its high-degree
; holes, and demoting it to successively lower degrees to visualize
; its structure better. We'll use another way we can demote a
; hypersnippet shape to lower-degree shapes, and this one doesn't lose
; any information.
;
; We'll divide it into stripes, where every other stripe (a "lake")
; represents a hole in the original, and the others ("islands")
; represent pieces of the hypersnippet in between those holes:
;
;   ^2(       ,(    )       ,(       )       )
;
;     (        )
;              (    )
;                   (        )
;                            (       )
;                                    (       )
;
; This can be extrapolated to other degrees. Here's a degree-3
; hypersnippet shape divided into degree-2 stripes:
;
;   ^3( ,( ) ~2(  ,( ,( ) )     ,( ,( ) ) ) )
;
;   ^2( ,( )  ,(                          ) )
;            ^2(  ,(      )     ,(      ) )
;                ^2( ,( ) )    ^2( ,( ) )
;
; Note that in an island, some of the highest-degree holes are
; standing in for holes of the next degree, so they contain lakes,
; but others just represent holes of their own degree. Lower-degree
; holes always represent themselves, never lakes. These rules
; characterize the structure of our stripe-divided data.
;
; Once we divide a hypersnippet shape up this way, we can represent
; each island as a pair of a data value and the hypertee of lakes and
; non-lake hole contents beyond, while we represent each lake as a
; pair of its hole contents and the hypertee of islands beyond.
;
; So in particular, for our interpolated string example, we represent
; the data like this, placing each string segment in a different
; island's data:
;
;  An island representing "Hello, ${name}! It's ${weather} today."
;   |
;   |-- First part: The string "Hello, "
;   |
;   `-- Rest: Hypertee of shape "( )"
;        |
;        `-- Hole of shape ")": A lake representing "${name}! It's ${weather} today."
;             |
;             |-- Hole content: The expression `name`
;             |
;             `-- Rest: Hypertee of shape "( )"
;                  |
;                  `-- Hole of shape ")": An island representing "! It's ${weather} today."
;                       |
;                       |-- First part: The string "! It's "
;                       |
;                       `-- Rest: Hypertee of shape "( )"
;                            |
;                            `-- Hole of shape ")": A lake representing "${weather} today."
;                                 |
;                                 |-- Hole content: The expression `weather`
;                                 |
;                                 `-- Rest: Hypertee of shape "( )"
;                                      |
;                                      `-- Hole of shape ")": Interpolated string expression " today."
;                                           |
;                                           |-- First part: The string " today."
;                                           |
;                                           `-- Rest: Hypertee of shape "( )"
;                                                |
;                                                `-- Hole of shape ")": A non-lake
;                                                     |
;                                                     `-- An ignored trivial value
;
; We call this representation a "hyprid" ("hyper" + "hybrid") since it
; stores both hypersnippet information and the hypertee information
; beyond the holes. Actually, hyprids generalize this striping a bit
; further by allowing the stripes to be striped, and so on. Each
; iteration of the striping works the same way, but the concept of
; "hypertee of shape S" is replaced with "stripes that collapse to a
; hypertee of shape S."
;
; (TODO: This documentation is a bit old now. We still implement
; hyprids in `punctaffy/private/experimental/hyprid`, but we're taking
; a different approach now, "hypernests" (implemented in
; `punctaffy/hyprsnippet/hypernest`), where string pieces like these
; can be represented as degree-1 nested hypernests. Whereas a hypertee
; is a series of labeled closing brackets of various degrees, a
; hypernest is a series of labeled closing brackets and labeled
; opening brackets of various degrees. Once we update this
; documentation, we should probably move this example into
; `punctaffy/private/experimental/hyprid` rather than just tossing it
; out.)
;
; A hyprid can have a number of striping iterations strictly less than
; the degree it has when collapsed to a hypertee. For instance, adding
; even one degree of striping to a degree-1 hyprid doesn't work, since
; an island stripe of degree 0 would have no holes to carry a lake
; stripe in at all.
;
; For circumstances where we're willing to discard the string
; information of our interpolated string, we can use the operation
; `hyprid-destripe-once` to get back a simpler hypertee:
;
;   Hypertee of shape "^2( ,( ) ,( ) )"
;    |
;    |-- First hole of shape ",( )": The expression `name`
;    |
;    |-- Second hole of shape ",( )": The expression `weather`
;    |
;    `-- Hole of shape ")": An ignored trivial value
;
; Technically, `hyprid-destripe-once` returns a hyprid of one less
; stripe iteration. We also offer an operation that collapses all
; degrees of stripes at once, `hyprid-fully-destripe`, which always
; results in a hypertee value.
;
; Note that it would not be so easy to represent hypersnippet data
; without building it out of hypertees. If we have hypertees, we can
; do something like a "flatmap" operation where we process the holes
; to generate more hypertees and then join them all together into one
; combined hypertee. If we were to write an operation like that for
; interpolated strings, we would have to pass in (or assume) a string
; concatenation operation so that "foo${"bar"}baz" could properly
; turn into "foobarbaz". Higher degrees of hypersnippets will likely
; need to use higher-degree notions of concatenation in order to be
; flatmapped, and we haven't explored these yet (TODO).
;
;
; == Verifying hypersnippet shapes ==
;
; So now that we know how to represent hypersnippet-shaped information
; using hypertees, the trickiest part of the implementation of
; hypertees is how to represent the shape itself.
;
; As above, here's an example of a degree-4 hypersnippet shape along
; with variations where its high-degree holes are removed so that it's
; easier to see its matching structure at a glance:
;
;     ;
;     (                                       )
;   ^2(                      ,( )             )
;   ^3(         ~2( ,(       ,( )     ) )     )
;   ^4( ~3( ~2( ~2( ,( ,( ,( ,( ) ) ) ) ) ) ) )
;
; And here's an example of running an algorithm from left to right across the sequence of brackets to verify that it's properly balanced:
;
;      | 4
;          | 3 (4, 4, 4)
;              | 4 (3 (4, 4, *), 3 (4, 4, 4))
;                  | 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))
;                     | 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))
;                        | 3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))))
;                           | 4 (3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))))
;                              | 1 (4 (3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))))))
;                                | 4 (3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))))
;                                  | 3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))))
;                                    | 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))
;                                      | 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))
;                                        | 4 (3 (4, 4, *), 3 (4, 4, 4))
;                                          | 3 (4, 4, 4)
;                                            | 4
;                                              | 0
;
; We needed a bunch of specialized notation just for this
; demonstration. The notation "|" represents the cursor as it runs
; through the brackets shown above. The notation "*" represents parts
; of the state that are unnecessary to keep track of. The notation "4"
; by itself is shorthand for "4 ()". A notation like "4 ()" which has
; a shorter list than the number declared is also shorthand; its list
; represents only the lowest-degree parts of a full 4-element list,
; which could be written as
; "4 (3 (*, *, *), 2 (*, *), 1 (*, *), 0 ())". The implicit
; higher-degree slots are filled in with lists of the same length as
; their degree. Once fully expanded, the numbers are superfluous; they
; just represent the length of the list that follows, which
; corresponds with the degree of the current region in the syntax.
;
; In general, these lists in the history represent what history states
; will be "restored" (perhaps for the first time) when a closing
; bracket of that degree is encountered.
;
; The algorithm proceeds by consuming a bracket, restoring the
; corresponding element of the history (counting from the right to the
; left in this example), and finally replacing each element of the
; looked-up state with the previous state if it's a slot of lower
; degree than the bracket is. (That's why so many parts of the history
; are "*"; if they're ever used, those parts will necessarily be
; overwritten anyway.)
;
; If we introduce a shorthand ">" that means "this element is a
; duplicate of the element to the right," we can display that example
; more economically:
;
;   ^4( ~3( ~2( ~2( ,( ,( ,( ,( ) ) ) ) ) ) ) )
;
;      | 4
;          | 3 (>, >, 4)
;              | 4 (>, 3 (>, >, 4))
;                  | 2 (>, 4 (>, 3 (>, >, 4)))
;                     | 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))
;                        | 3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4)))))
;                           | 4 (3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))))
;                              | 1 (4 (3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4)))))))
;                                | 4 (3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))))
;                                  | 3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4)))))
;                                    | 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))
;                                      | 2 (>, 4 (>, 3 (>, >, 4)))
;                                        | 4 (>, 3 (>, >, 4))
;                                          | 3 (>, >, 4)
;                                            | 4
;                                              | 0
;
; In fact, the actual implementation in
; `assert-valid-hypertee-brackets` represents the history lists in
; reverse order. Here, the slots are displayed from highest to lowest
; degree so that history tends to be appended to and removed from the
; left side (where the cursor is).
;
; If we tried to enforce all of the bracket-balancing in a more
; incremental, structured way, it would be rather difficult. Here's a
; sketch of what the hypertee type itself would look like if we were
; to define it as a correct-by-construction algebraic data type:
;
;   data Hypertee :
;     (n : Nat) ->
;     ( (i : Fin n) ->
;       Hypertee (finToNat i) (\i iEdge -> ()) ->
;       Type) ->
;     Type
;   where
;     HyperteeZ : Hypertee 0 finAbsurd
;     HyperteeS :
;       {n : Nat} ->
;       {m : Fin n} ->
;       {v :
;         (i : Fin n) ->
;         Hypertee (finToNat i) (\i iEdge -> ()) ->
;         Type} ->
;       (edge :
;         Hypertee finToNat m \i iEdge ->
;           (fill : Hypertee n \j jEdge ->
;             if finToNat j < finToNat i
;               then ()
;               else v j) *
;           (hyperteeFilterDegreeTo (finToNat i) fill = iEdge)) ->
;       v m (hyperteeMapAllDegrees edge \i iEdge val -> ()) ->
;       Hypertee v
;
; This type must be defined as part of an induction-recursion with the
; functions `hyperteeFilterDegreeTo` (which would remove the
; highest-degree holes from a hypertee and lower its degree, as we
; provide here under the name `hypertee-filter-degree-to`) and
; `hyperteeMapAllDegrees`, which seem to end up depending on quite a
; lot of other constructions.



(define-imitation-simple-struct
  (htb-labeled? htb-labeled-degree htb-labeled-data)
  htb-labeled
  'htb-labeled (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct
  (htb-unlabeled? htb-unlabeled-degree)
  htb-unlabeled
  'htb-unlabeled (current-inspector) (auto-write) (auto-equal))

(define (hypertee-bracket? v)
  (or (htb-labeled? v) (htb-unlabeled? v)))

(define (hypertee-bracket/c dim/c)
  (w- dim/c (coerce-contract 'hypertee-bracket/c dim/c)
  #/rename-contract
    (or/c
      (match/c htb-labeled dim/c any/c)
      (match/c htb-unlabeled dim/c))
    `(hypertee-bracket/c ,(contract-name dim/c))))

(define (hypertee-bracket-degree closing-bracket)
  (mat closing-bracket (htb-labeled d data) d
  #/dissect closing-bracket (htb-unlabeled d) d))

(define
  (assert-valid-hypertee-brackets
    err-name ds opening-degree closing-brackets)
  (w- final-region-degree
    (hyperstack-dimension #/list-foldl
      (make-hyperstack-trivial ds opening-degree)
      closing-brackets
    #/fn histories closing-bracket
      (w- closing-degree (hypertee-bracket-degree closing-bracket)
      #/expect
        (dim-sys-dim<? ds closing-degree
          (hyperstack-dimension histories))
        #t
        (error "Encountered a closing bracket of degree higher than the current region's degree")
      #/w- restored-history
        (hyperstack-pop-trivial closing-degree histories)
      #/begin
        (if
          (dim-sys-dim=? ds closing-degree
            (hyperstack-dimension restored-history))
          ; NOTE: We don't validate `hole-value`.
          (expect closing-bracket
            (htb-labeled closing-degree hole-value)
            (raise-arguments-error err-name
              "expected a closing bracket that began a hole to be annotated with a data value"
              "opening-degree" opening-degree
              "closing-brackets" closing-brackets
              "closing-bracket" closing-bracket)
          #/void)
          (mat closing-bracket (htb-labeled closing-degree hole-value)
            (raise-arguments-error err-name
              "expected a closing bracket that did not begin a hole to have no data value annotation"
              "opening-degree" opening-degree
              "closing-brackets" closing-brackets
              "closing-bracket" closing-bracket)
          #/void))
        restored-history))
  #/expect (dim-sys-dim=0? ds final-region-degree) #t
    (raise-arguments-error err-name
      "expected more closing brackets"
      "opening-degree" opening-degree
      "closing-brackets" closing-brackets
      "final-region-degree" final-region-degree)
  #/void))


(define-imitation-simple-struct
  (hypertee?
    hypertee-dim-sys hypertee-degree hypertee-closing-brackets)
  unguarded-hypertee 'hypertee (current-inspector)
  (auto-equal)
  (#:prop prop:custom-write #/make-constructor-style-printer
    ; We write hypernests using a sequence-of-brackets representation
    ; (which happens to be the same way we represent them).
    (fn self 'ht-bracs)
    (fn self
      (list* (hypertee-dim-sys self) (hypertee-degree self)
      #/list-map (hypertee-get-brackets self) #/fn bracket
        (expect bracket (htb-unlabeled bracket) bracket
        #/if (hypertee-bracket? bracket)
          (htb-unlabeled bracket)
          bracket)))))

(define-match-expander-attenuated
  attenuated-hypertee unguarded-hypertee
  [ds any/c]
  [degree any/c]
  [closing-brackets any/c]
  (begin0 #t
    (unless (punctaffy-suppress-internal-errors)
      (assert-valid-hypertee-brackets 'attenuated-hypertee
        ds degree closing-brackets))))

(define-match-expander-from-match-and-make
  hypertee unguarded-hypertee attenuated-hypertee attenuated-hypertee)

(define (hypertee/c ds)
  (rename-contract (match/c hypertee (ok/c ds) any/c any/c)
    `(hypertee/c ,ds)))

(define (unsafe-hypertee-from-brackets ds degree closing-brackets)
  (unless (punctaffy-suppress-internal-errors)
    (assert-valid-hypertee-brackets 'unsafe-hypertee-from-brackets
      ds degree closing-brackets))
  (unguarded-hypertee ds degree closing-brackets))

(define (explicit-hypertee-from-brackets err-name ds degree brackets)
  (assert-valid-hypertee-brackets err-name ds degree brackets)
  (unguarded-hypertee ds degree brackets))

(define (hypertee-from-brackets ds degree brackets)
  (explicit-hypertee-from-brackets 'hypertee-from-brackets
    ds degree brackets))

(define (ht-bracs ds degree . brackets)
  (explicit-hypertee-from-brackets 'ht-bracs ds degree
  #/list-map brackets #/fn closing-bracket
    (if (hypertee-bracket? closing-bracket)
      closing-bracket
      (htb-unlabeled closing-bracket))))

(define (ht-bracs-dss dss degree . brackets)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/w- n-d
    (fn n
      (expect (natural? n) #t n
      #/mat (dim-successors-sys-dim-from-int dss n) (just d) d
      #/raise-arguments-error 'ht-bracs-dss
        "expected the given number of successors to exist for the zero dimension"
        "n" n
        "dss" dss))
  #/hypertee-from-brackets ds (n-d degree)
  #/list-map brackets #/fn bracket
    (mat bracket (htb-labeled d data) (htb-labeled (n-d d) data)
    #/mat bracket (htb-unlabeled d) (htb-unlabeled (n-d d))
    #/htb-unlabeled (n-d bracket))))

(define (hypertee-get-brackets ht)
  (dissect ht (hypertee ds d closing-brackets)
    closing-brackets))

; Takes a hypertee of any nonzero degree N and upgrades it to any
; degree N or greater, while leaving its holes the way they are.
(define (hypertee-increase-degree-to new-degree ht)
  (dissect ht (hypertee ds d closing-brackets)
  #/if (dim-sys-dim=0? ds d)
    (raise-arguments-error 'hypertee-increase-degree-to
      "expected ht to be a hypertee of nonzero degree"
      "ht" ht)
  #/expect (dim-sys-dim<=? ds d new-degree) #t
    (raise-arguments-error 'hypertee-increase-degree-to
      "expected ht to be a hypertee of degree no greater than new-degree"
      "new-degree" new-degree
      "ht" ht)
  #/hypertee ds new-degree closing-brackets))

; Takes a nonzero-degree hypertee and returns a `just` of a degree-N
; hypertee with the same holes if possible. If this isn't possible
; (because some holes in the original are of degree N or greater),
; this returns `(nothing)`.
(define (hypertee-set-degree-maybe new-degree ht)
  (dissect ht (hypertee ds d closing-brackets)
  #/if (dim-sys-dim=0? ds d)
    (raise-arguments-error 'hypertee-set-degree-maybe
      "expected ht to be a hypertee of nonzero degree"
      "ht" ht)
  #/if
    (or (dim-sys-dim<=? ds d new-degree)
    #/list-all closing-brackets #/fn closing-bracket
      (expect closing-bracket (htb-labeled d data) #t
      #/dim-sys-dim<? ds d new-degree))
    (just #/hypertee ds new-degree closing-brackets)
    (nothing)))

; Takes a nonzero-degree hypertee with no holes of degree N or greater
; and returns a degree-N hypertee with the same holes.
(define (hypertee-set-degree-force new-degree ht)
  (expect (hypertee-set-degree-maybe new-degree ht) (just result)
    (error "Expected ht to have no holes of degree new-degree or greater")
    result))

; Takes a hypertee of any degree N and returns a hypertee of degree
; N+1 with all the same degree-less-than-N holes as well as a single
; degree-N hole in the shape of the original hypertee. This should
; be useful as something like a monadic return.
(define (hypertee-contour dss hole-value ht)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/expect
    (dim-successors-sys-dim-plus-int dss (hypertee-degree ht) 1)
    (just succ-d)
    (raise-arguments-error 'hypertee-contour
      "expected the given hypertee to be of a degree that had a a successor"
      "ht" ht)
  #/hypertee-done succ-d hole-value ht))

(define-imitation-simple-struct (hypertee-coil-zero?)
  hypertee-coil-zero
  'hypertee-coil-zero (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct
  (hypertee-coil-hole?
    hypertee-coil-hole-overall-degree
    hypertee-coil-hole-data
    hypertee-coil-hole-tails-hypertee)
  hypertee-coil-hole
  'hypertee-coil-hole (current-inspector) (auto-write) (auto-equal))

; TODO PARITY: Bring this into parity with
; `punctaffy/hypersnippet/hypertee`, where it checks that the tails in
; the tails hypertee fit into the holes they're in.
;
(define (hypertee-coil/c ds)
  (rename-contract
    (or/c
      (match/c hypertee-coil-zero)
      (match/c hypertee-coil-hole (dim-sys-0<dim/c ds) any/c
        (hypertee/c ds)))
    `(hypertee-coil/c ,ds)))

(define (hypertee-unfurl ht)
  
  (struct-easy (loc-outside))
  (struct-easy (loc-dropped))
  (struct-easy (loc-interpolation-uninitialized))
  (struct-easy (loc-interpolation i d))
  
  (struct-easy
    (interpolation-state-in-progress
      rev-brackets interpolation-hyperstack))
  (struct-easy (interpolation-state-finished result))
  
  (dissect ht (hypertee ds d-root closing-brackets)
  #/expect closing-brackets (cons first rest) (hypertee-coil-zero)
  #/dissect first (htb-labeled d-dropped data-dropped)
  #/hypertee-coil-hole d-root data-dropped
  ; NOTE: This special case is necessary. Most of the code below goes
  ; smoothly for a `d-dropped` equal to 0, but the fold ends with a
  ; location of `(loc-dropped)` instead of `(loc-outside)`.
  #/if (dim-sys-dim=0? ds d-dropped)
    (hypertee ds (dim-sys-dim-zero ds) #/list)
  #/w- stack (make-hyperstack ds d-root #/loc-outside)
  #/dissect
    (hyperstack-pop d-dropped stack #/loc-interpolation-uninitialized)
    (list (loc-outside) stack)
  #/w-loop next
    root-brackets (list-kv-map rest #/fn k v #/list k v)
    interpolations (make-immutable-hasheq)
    hist (list (loc-dropped) stack)
    rev-result (list)
    
    (define (push-interpolation-bracket interpolations i bracket)
      (w- d (hypertee-bracket-degree bracket)
      #/dissect (hash-ref interpolations i)
        (interpolation-state-in-progress
          rev-brackets interpolation-hyperstack)
      #/dissect (hyperstack-pop d interpolation-hyperstack #f)
        (list popped-the-root? interpolation-hyperstack)
      #/hash-set interpolations i
        (interpolation-state-in-progress
          (cons (if popped-the-root? bracket (htb-unlabeled d))
            rev-brackets)
          interpolation-hyperstack)))
    
    (define
      (push-interpolation-bracket-and-possibly-finish
        interpolations i bracket)
      (w- interpolations
        (push-interpolation-bracket interpolations i bracket)
      #/dissect (hash-ref interpolations i)
        (interpolation-state-in-progress
          rev-brackets interpolation-hyperstack)
      #/hash-set interpolations i
        (if
          (dim-sys-dim=0? ds
            (hyperstack-dimension interpolation-hyperstack))
          (interpolation-state-finished
            (hypertee ds d-root #/reverse rev-brackets))
          (interpolation-state-in-progress
            rev-brackets interpolation-hyperstack))))
    
    (expect root-brackets (cons root-bracket root-brackets)
      (dissect hist (list (loc-outside) stack)
      #/dissect (dim-sys-dim=0? ds #/hyperstack-dimension stack) #t
      ; We look up all the indexes stored in `rev-result` and make a
      ; hypertee out of it.
      #/hypertee ds d-dropped #/reverse
      #/list-map rev-result #/fn bracket
        (expect bracket (htb-labeled d i) bracket
        #/dissect (hash-ref interpolations i)
          (interpolation-state-finished tail)
        #/htb-labeled d tail))
    #/dissect root-bracket (list new-i closing-bracket)
    #/dissect hist (list loc stack)
    #/w- d-bracket (hypertee-bracket-degree closing-bracket)
    #/dissect (hyperstack-pop d-bracket stack loc)
      (list tentative-new-loc tentative-new-stack)
    #/mat loc (loc-outside)
      (dissect tentative-new-loc (loc-interpolation i d)
      #/next root-brackets
        (push-interpolation-bracket interpolations i closing-bracket)
        (list tentative-new-loc tentative-new-stack)
        rev-result)
    #/mat loc (loc-dropped)
      (mat tentative-new-loc (loc-interpolation-uninitialized)
        (next root-brackets
          (hash-set interpolations new-i
            (interpolation-state-in-progress (list)
              (make-hyperstack ds d-root #t)))
          (list (loc-interpolation new-i d-bracket)
            tentative-new-stack)
          (cons (htb-labeled d-bracket new-i) rev-result))
      #/dissect tentative-new-loc (loc-interpolation i d)
        (next root-brackets
          (push-interpolation-bracket interpolations i
            closing-bracket)
          (list tentative-new-loc tentative-new-stack)
          (cons closing-bracket rev-result)))
    #/mat loc (loc-interpolation i d)
      (mat tentative-new-loc (loc-outside)
        (next root-brackets
          (push-interpolation-bracket-and-possibly-finish
            interpolations i closing-bracket)
          (list tentative-new-loc tentative-new-stack)
          rev-result)
      #/dissect tentative-new-loc (loc-dropped)
        (next root-brackets
          (push-interpolation-bracket-and-possibly-finish
            interpolations i
            (htb-labeled d-bracket #/trivial))
          (list tentative-new-loc tentative-new-stack)
          (cons closing-bracket rev-result)))
    #/error "Internal error: Entered an unexpected kind of region in hypertee-unfurl")))

(define (hypertee-dv-map-all-degrees ht func)
  (dissect ht (hypertee ds degree closing-brackets)
  #/hypertee ds degree #/list-map closing-brackets #/fn bracket
    (expect bracket (htb-labeled d data) bracket
    #/htb-labeled d #/func d data)))

(define (hypertee-v-map-one-degree degree ht func)
  (w- ds (hypertee-dim-sys ht)
  #/hypertee-dv-map-all-degrees ht #/fn hole-degree data
    (if (dim-sys-dim=? ds degree hole-degree)
      (func data)
      data)))

(define/own-contract (hypertee-v-map-pred-degree dss degree ht func)
  (->i
    (
      [dss dim-successors-sys?]
      [degree (dss) (dim-sys-dim/c #/dim-successors-sys-dim-sys dss)]
      [ht (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)]
      [func (-> any/c any/c)])
    [_ (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)])
  
  ; If the degree is 0 or something like a limit ordinal, we're done.
  ; No hole's degree has the given degree as its successor, so there
  ; are no holes to process.
  (expect (dim-successors-sys-dim-plus-int dss degree -1)
    (just pred-degree)
    ht
  
  #/hypertee-v-map-one-degree pred-degree ht func))

(define (hypertee-v-map-highest-degree dss ht func)
  (hypertee-v-map-pred-degree dss (hypertee-degree ht) ht func))

(define (hypertee-fold first-nontrivial-d ht on-zero on-hole)
  (w- ds (hypertee-dim-sys ht)
  #/expect (hypertee-unfurl ht)
    (hypertee-coil-hole overall-degree data tails)
    (on-zero)
  #/on-hole first-nontrivial-d data
  #/hypertee-dv-map-all-degrees tails #/fn hole-degree tail
    (hypertee-fold (dim-sys-dim-max ds first-nontrivial-d hole-degree)
      tail on-zero on-hole)))

; TODO: See if we can simplify the implementation of
; `hypertee-join-all-degrees` to something like this now that we have
; `hypertee-fold`. There are a few potential circular dependecy
; problems: The implementations of `hypertee-furl`,
; `hypertee-map-all-degrees`, `hypertee-filter-degree-to`, and
; `hypertee-low-degree-holes-zip-map` depend on
; `hypertee-join-all-degrees`.
;
#;
(define (hypertee-join-all-degrees ht)
  (w- ds (hypertee-dim-sys ht)
  #/hypertee-fold (dim-sys-dim-zero ds) ht (fn ht)
  #/fn first-nontrivial-d suffix tails
    (w- d (hypertee-degree tails)
    #/if (dim-sys-dim<? ds d first-nontrivial-d)
      (dissect suffix (trivial)
      ; TODO: See if this is correct.
      #/hypertee-furl ds
      #/hypertee-coil-hole (hypertee-degree ht) (trivial) tails)
    #/expect
      (and
        (hypertee? suffix)
        (dim-sys-dim<? ds
          (hypertee-degree tails)
          (hypertee-degree suffix)))
      #t
      (error "Expected each interpolation of a hypertee join to be a hypertee of the right shape for its interpolation context")
    #/expect
      (hypertee-low-degree-holes-zip-map tails suffix
      #/fn hole tail suffix
        (dissect suffix (trivial)
          tail))
      (just zipped)
      (error "Expected each interpolation of a hypertee join to be a hypertee of the right shape for its interpolation context")
    #/hypertee-join-all-degrees zipped)))

; TODO: See if we should switch to this implementation for
; `hypertee-map-all-degrees`.
;
#;
(define (hypertee-map-all-degrees ht func)
  (w- ds (hypertee-dim-sys ht)
  #/hypertee-fold (dim-sys-dim-zero ds) ht (fn ht)
  #/fn first-nontrivial-d data tails
    (w- d (hypertee-degree tails)
    #/if (dim-sys-dim<? ds d first-nontrivial-d)
      (dissect data (trivial)
      #/hypertee-furl ds
      #/hypertee-coil-hole (hypertee-degree ht) (trivial) tails)
    #/w- hole
      (hypertee-dv-map-all-degrees tails #/fn d data #/trivial)
    #/hypertee-furl ds
    #/hypertee-coil-hole (hypertee-degree ht) (func hole data)
      tails)))

(define-imitation-simple-struct
  (hypertee-join-selective-interpolation?
    hypertee-join-selective-interpolation-val)
  hypertee-join-selective-interpolation
  'hypertee-join-selective-interpolation
  (current-inspector)
  (auto-write)
  (auto-equal))
(define-imitation-simple-struct
  (hypertee-join-selective-non-interpolation?
    hypertee-join-selective-non-interpolation-val)
  hypertee-join-selective-non-interpolation
  'hypertee-join-selective-non-interpolation
  (current-inspector)
  (auto-write)
  (auto-equal))

; This takes a hypertee of degree N where each hole value of each
; degree M is either a `hypertee-join-selective-interpolation`
; containing another degree-N hypertee to be interpolated or a
; `hypertee-join-selective-non-interpolation`. In those interpolated
; hypertees, each value of a hole of degree L is either a
; `hypertee-join-selective-non-interpolation` or, if L is less than M,
; possibly a `hypertee-join-selective-interpolation` of a `trivial`
; value. This returns a single degree-N hypertee which has holes for
; all the non-interpolations of the interpolations and the
; non-interpolations of the root.
;
(define (hypertee-join-all-degrees-selective ht)
  
  (struct-easy (state-in-root))
  (struct-easy (state-in-interpolation i))
  
  (dissect ht (hypertee ds overall-degree closing-brackets)
  #/w-loop next
    root-brackets (list-kv-map closing-brackets #/fn k v #/list k v)
    interpolations (make-immutable-hasheq)
    hist
      (list (state-in-root)
      #/make-hyperstack ds overall-degree #/state-in-root)
    rev-result (list)
    
    (define (finish root-brackets interpolations rev-result)
      (expect root-brackets (list)
        (error "Internal error: Encountered the end of a hypertee join interpolation in a region of degree 0 before getting to the end of the root")
      #/void)
      (hash-kv-each interpolations #/fn i interpolation-brackets
        (expect interpolation-brackets (list)
          (error "Internal error: Encountered the end of a hypertee join root before getting to the end of its interpolations")
        #/void))
      
      ; NOTE: It's possible for this to throw errors, particularly if
      ; some of the things we've joined together include annotated
      ; holes in places where holes of that degree shouldn't be
      ; annotated (because they're closing another hole). Despite the
      ; fact that the errors this raises aren't associated with
      ; `hypertee-join-all-degrees-selective` or caught earlier during
      ; this process, I've found them to be surprisingly helpful since
      ; it's easy to modify this code to log the fully constructed
      ; list of brackets.
      ;
      (hypertee ds overall-degree #/reverse rev-result))
    
    (define (pop-interpolation-bracket interpolations i)
      (expect (hash-ref interpolations i) (cons bracket rest)
        (list interpolations #/nothing)
        (list (hash-set interpolations i rest) #/just bracket)))
    
    (define (verify-bracket-degree d closing-bracket)
      (unless
        (dim-sys-dim=? ds d (hypertee-bracket-degree closing-bracket))
        (raise-arguments-error 'hypertee-join-all-degrees-selective
          "expected each interpolation of a hypertee join to be the right shape for its interpolation context"
          "expected-closing-bracket-degree" d
          "actual-closing-bracket" closing-bracket
          "ht" ht)))
    
    (dissect hist (list state histories)
    #/mat state (state-in-interpolation interpolation-i)
      
      ; We read from the interpolation's closing bracket stream.
      (dissect
        (pop-interpolation-bracket interpolations interpolation-i)
        (list interpolations maybe-bracket)
      #/expect maybe-bracket (just closing-bracket)
        ; TODO: We used to make this check here. However, since we can
        ; have a non-interpolation of degree 0, and a
        ; non-interpolation causes us to push rather than pop the
        ; hyperstack, we can have a hyperstack of degree other than 0
        ; at the end here. See if there's some other check we should
        ; make. This was an internal error anyway, so maybe not.
;        (expect (dim-sys-dim=0? ds #/hyperstack-dimension histories)
;          #t
;          (error "Internal error: A hypertee join interpolation ran out of brackets before reaching a region of degree 0")
        (begin
        ; The interpolation has no more closing brackets, and we're in
        ; a region of degree 0, so we end the loop.
        #/finish root-brackets interpolations rev-result)
      #/mat closing-bracket
        (htb-labeled d
          (hypertee-join-selective-non-interpolation data))
        ; We begin a non-interpolation in an interpolation.
        (w- histories (hyperstack-push d histories state)
        #/w- hist (list state histories)
        #/next root-brackets interpolations hist
          (cons (htb-labeled d data) rev-result))
      #/w- closing-bracket
        (expect closing-bracket (htb-labeled d data) closing-bracket
        #/expect data (hypertee-join-selective-interpolation data)
          (error "Expected each hole of a hypertee join interpolation to contain a hypertee-join-selective-interpolation or a hypertee-join-selective-non-interpolation")
        #/htb-labeled d data)
      #/w- d (hypertee-bracket-degree closing-bracket)
      #/expect (dim-sys-dim<? ds d #/hyperstack-dimension histories)
        #t
        (error "Expected each high-degree hole of a hypertee join interpolation to be a hypertee-join-selective-non-interpolation")
      #/dissect (hyperstack-pop d histories state)
        (list state histories)
      #/w- hist (list state histories)
      #/mat state (state-in-root)
        
        ; We've moved out of the interpolation through a low-degree
        ; hole and arrived at the root. Now we proceed by processing
        ; the root's brackets instead of the interpolation's brackets.
        ;
        (dissect root-brackets
          (cons (list root-bracket-i root-bracket) root-brackets)
        #/begin
          (verify-bracket-degree d root-bracket)
          (mat closing-bracket (htb-labeled d data)
            (expect data (trivial)
              ; TODO: Make more of the errors like this one.
              (raise-arguments-error
                'hypertee-join-all-degrees-selective
                "a hypertee join interpolation had an interpolation of low degree where the value wasn't a trivial value"
                "ht" ht
                "closing-bracket" closing-bracket
                "data" data)
            #/void)
          #/void)
        #/next root-brackets interpolations hist rev-result)
      #/dissect state (state-in-interpolation i)
        
        ; We just moved out of a non-interpolation of the
        ; interpolation, so we're still in the interpolation, and we
        ; continue to proceed by processing the interpolation's
        ; brackets.
        ;
        (next root-brackets interpolations hist
          (cons closing-bracket rev-result)))
    
    ; We read from the root's closing bracket stream.
    #/expect root-brackets (cons root-bracket root-brackets)
      ; TODO: We used to make this check here. However, since we can
      ; have a non-interpolation of degree 0, and a non-interpolation
      ; causes us to push rather than pop the hyperstack, we can have
      ; a hyperstack of degree other than 0 at the end here. See if
      ; there's some other check we should make. This was an internal
      ; error anyway, so maybe not.
;      (expect (dim-sys-dim=0? ds #/hyperstack-dimension histories) #t
;        (error "Internal error: A hypertee join root ran out of brackets before reaching a region of degree 0")
      (begin
      ; The root has no more closing brackets, and we're in a region
      ; of degree 0, so we end the loop.
      #/finish root-brackets interpolations rev-result)
    #/dissect root-bracket (list root-bracket-i closing-bracket)
    #/mat closing-bracket
      (htb-labeled d #/hypertee-join-selective-non-interpolation data)
      ; We begin a non-interpolation in the root.
      (w- histories (hyperstack-push d histories state)
      #/w- hist (list state histories)
      #/next root-brackets interpolations hist
        (cons (htb-labeled d data) rev-result))
    #/w- closing-bracket
      (expect closing-bracket (htb-labeled d data) closing-bracket
      #/expect data (hypertee-join-selective-interpolation data)
        (error "Expected each hole of a hypertee join root to contain a hypertee-join-selective-interpolation or a hypertee-join-selective-non-interpolation")
      #/htb-labeled d data)
    #/w- d (hypertee-bracket-degree closing-bracket)
    #/expect (dim-sys-dim<? ds d #/hyperstack-dimension histories) #t
      (error "Internal error: Expected the next closing bracket of a hypertee join root to be of a degree less than the current region's degree")
    #/dissect (hyperstack-pop d histories state)
      (list state histories)
    #/mat closing-bracket (htb-unlabeled d)
      (w- hist (list state histories)
      #/mat state (state-in-root)
        ; We just moved out of a non-interpolation of the root, so
        ; we're still in the root.
        (next root-brackets interpolations hist
          (cons closing-bracket rev-result))
      #/dissect state (state-in-interpolation i)
        ; We resume an interpolation in the root.
        (dissect (pop-interpolation-bracket interpolations i)
          (list interpolations #/just interpolation-bracket)
        #/begin (verify-bracket-degree d interpolation-bracket)
        #/next root-brackets interpolations hist rev-result))
    ; We begin an interpolation in the root.
    #/dissect closing-bracket (htb-labeled d data)
    #/expect data (hypertee data-ds data-d data-closing-brackets)
      (raise-arguments-error 'hypertee-join-all-degrees-selective
        "expected each hypertee join interpolation to be a hypertee"
        "ht" ht
        "closing-bracket" closing-bracket
        "data" data)
    #/expect (contract-first-order-passes? (ok/c ds) data-ds) #t
      (raise-arguments-error 'hypertee-join-all-degrees-selective
        "expected each hypertee join interpolation to be a hypertee with a compatible dimension system"
        "ht" ht
        "closing-bracket" closing-bracket
        "data" data)
    #/expect (dim-sys-dim=? ds data-d overall-degree) #t
      (raise-arguments-error 'hypertee-join-all-degrees-selective
        "expected each hypertee join interpolation to have the same degree as the root"
        "ht" ht
        "closing-bracket" closing-bracket
        "data" data)
    #/next root-brackets
      (hash-set interpolations root-bracket-i data-closing-brackets)
      (list (state-in-interpolation root-bracket-i) histories)
      rev-result)))

(define (hypertee-map-all-degrees ht func)
  (dissect ht (hypertee ds overall-degree closing-brackets)
  ; NOTE: This special case is necessary. Most of the code below goes
  ; smoothly for an `overall-degree` equal to `0`, but the loop ends
  ; with a `maybe-current-hole` of `(nothing)`.
  #/if (dim-sys-dim=0? ds overall-degree)
    (hypertee ds (dim-sys-dim-zero ds) #/list)
  #/w- result
    (list-kv-map closing-brackets #/fn i closing-bracket
      (expect closing-bracket (htb-labeled d data) closing-bracket
      #/htb-labeled d #/list data i))
  #/dissect
    (list-foldl
      (list
        (list-foldl (make-immutable-hasheq) result
        #/fn hole-states closing-bracket
          (expect closing-bracket (htb-labeled d data) hole-states
          #/dissect data (list data i)
          #/hash-set hole-states i
            (list (list) (make-hyperstack-trivial ds d))))
        (list (nothing)
          (make-hyperstack ds overall-degree #/nothing)))
      result
    #/fn state closing-bracket
      (dissect state
        (list hole-states #/list maybe-current-hole histories)
      #/w- d (hypertee-bracket-degree closing-bracket)
      #/expect (dim-sys-dim<? ds d #/hyperstack-dimension histories)
        #t
        (error "Internal error: Encountered a closing bracket of degree higher than the root's current region")
      #/dissect (hyperstack-pop d histories maybe-current-hole)
        (list maybe-restored-hole histories)
      #/w- update-hole-state
        (fn hole-states i
          (dissect (hash-ref hole-states i) (list rev-brackets hist)
          #/expect (dim-sys-dim<? ds d #/hyperstack-dimension hist) #t
            (error "Internal error: Encountered a closing bracket of degree higher than the hole's current region")
          #/w- hist (hyperstack-pop-trivial d hist)
          #/hash-set hole-states i
            (list
              (cons
                (if (dim-sys-dim=? ds d #/hyperstack-dimension hist)
                  (htb-labeled d #/trivial)
                  (htb-unlabeled d))
                rev-brackets)
              hist)))
      #/mat maybe-current-hole (just i)
        (mat maybe-restored-hole (just i)
          (error "Internal error: Went directly from one hole to another in progress")
        #/mat closing-bracket (htb-labeled d #/list data i)
          (error "Internal error: Went directly from one hole to another's beginning")
        #/list (update-hole-state hole-states i)
          (list (nothing) histories))
      #/mat maybe-restored-hole (just i)
        (mat closing-bracket (htb-labeled d #/list data i)
          (error "Internal error: Went into two holes at once")
        #/list (update-hole-state hole-states i)
          (list (just i) histories))
      #/mat closing-bracket (htb-labeled d #/list data state)
        ; NOTE: We don't need to `update-hole-state` here because as
        ; far as this hole's state is concerned, this bracket is the
        ; opening bracket of the hole, not a closing bracket.
        (list hole-states #/list (just state) histories)
      #/error "Internal error: Went directly from the root to the root without passing through a hole"))
    (list hole-states #/list maybe-current-hole histories)
  #/expect (dim-sys-dim=0? ds #/hyperstack-dimension histories) #t
    (error "Internal error: Ended hypertee-map-all-degrees without being in a zero-degree region")
  #/expect maybe-current-hole (just i)
    (error "Internal error: Ended hypertee-map-all-degrees without being in a hole")
  #/expect (hash-ref hole-states i) (list (list) state-hist)
    (error "Internal error: Ended hypertee-map-all-degrees without being in the zero-degree hole")
  #/expect (dim-sys-dim=0? ds #/hyperstack-dimension state-hist) #t
    (error "Internal error: Ended hypertee-map-all-degrees without being in the zero-degree hole")
  #/hypertee ds overall-degree #/list-map result #/fn closing-bracket
    (expect closing-bracket (htb-labeled d #/list data i)
      closing-bracket
    #/dissect (hash-ref hole-states i) (list rev-brackets hist)
    #/expect (dim-sys-dim=0? ds #/hyperstack-dimension hist) #t
      (error "Internal error: Failed to exhaust the history of a hole while doing hypertee-map-all-degrees")
    #/htb-labeled d
      (func (hypertee ds d #/reverse rev-brackets) data))))

(define (hypertee-map-one-degree degree ht func)
  (w- ds (hypertee-dim-sys ht)
  #/hypertee-map-all-degrees ht #/fn hole data
    (if (dim-sys-dim=? ds degree #/hypertee-degree hole)
      (func hole data)
      data)))

(define/own-contract (hypertee-map-pred-degree dss degree ht func)
  (->i
    (
      [dss dim-successors-sys?]
      [degree (dss) (dim-sys-dim/c #/dim-successors-sys-dim-sys dss)]
      [ht (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)]
      [func (dss)
        (-> (hypertee/c #/dim-successors-sys-dim-sys dss) any/c
          any/c)])
    [_ (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)])
  
  ; If the degree is 0 or something like a limit ordinal, we're done.
  ; No hole's degree has the given degree as its successor, so there
  ; are no holes to process.
  (expect (dim-successors-sys-dim-plus-int dss degree -1)
    (just pred-degree)
    ht
  
  #/hypertee-map-one-degree pred-degree ht func))

(define (hypertee-map-highest-degree dss ht func)
  (hypertee-map-pred-degree dss (hypertee-degree ht) ht func))

(define (hypertee-done degree data hole)
  (dissect hole (hypertee ds old-degree closing-brackets)
  #/expect (dim-sys-dim<? ds old-degree degree) #t
    (raise-arguments-error 'hypertee-done
      "expected hole to be a hypertee of degree strictly less than the given degree"
      "degree" degree
      "hole" hole)
  #/hypertee ds degree
  #/cons (htb-labeled old-degree data)
  #/list-bind closing-brackets #/fn closing-bracket
    (list
      (htb-unlabeled #/hypertee-bracket-degree closing-bracket)
      closing-bracket)))

(define (hypertee-get-hole-zero ht)
  (dissect ht (hypertee ds degree closing-brackets)
  #/if (dim-sys-dim=0? ds degree) (nothing)
  #/dissect (reverse closing-brackets) (cons (htb-labeled d data) _)
  #/dissect (dim-sys-dim=0? ds d) #t
  #/just data))

; This takes a hypertee of degree N where each hole value of each
; degree M is another degree-N hypertee to be interpolated. In those
; interpolated hypertees, the values of holes of degree less than M
; must be `trivial` values. This returns a single degree-N hypertee
; which has holes for all the degree-M-or-greater holes of the
; interpolations of each degree M.
;
(define (hypertee-join-all-degrees ht)
  (w- ds (hypertee-dim-sys ht)
  #/hypertee-join-all-degrees-selective
  #/hypertee-dv-map-all-degrees ht #/fn root-hole-degree data
    (expect (hypertee? data) #t
      (error "Expected each interpolation of a hypertee join to be a hypertee")
    #/hypertee-join-selective-interpolation
    #/hypertee-dv-map-all-degrees data
    #/fn interpolation-hole-degree data
      (expect
        (dim-sys-dim<? ds interpolation-hole-degree root-hole-degree)
        #t
        (hypertee-join-selective-non-interpolation data)
      #/hypertee-join-selective-interpolation data))))

(define (hypertee-bind-all-degrees ht hole-to-ht)
  (hypertee-join-all-degrees
  #/hypertee-map-all-degrees ht hole-to-ht))

(define (hypertee-bind-one-degree degree ht func)
  (w- ds (hypertee-dim-sys ht)
  #/hypertee-bind-all-degrees ht #/fn hole data
    (if (dim-sys-dim=? ds degree #/hypertee-degree hole)
      (func hole data)
      (hypertee-done (hypertee-degree ht) data hole))))

(define (hypertee-bind-pred-degree dss degree ht func)
  
  ; If the degree is 0 or something like a limit ordinal, we're done.
  ; No hole's degree has the given degree as its successor, so there
  ; are no holes to process.
  (expect (dim-successors-sys-dim-plus-int dss degree -1)
    (just pred-degree)
    ht
  
  #/hypertee-bind-one-degree pred-degree ht func))

(define/own-contract (hypertee-bind-highest-degree dss ht func)
  (->i
    (
      [dss dim-successors-sys?]
      [ht (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)]
      [func (dss)
        (w- ds (dim-successors-sys-dim-sys dss)
        #/-> (hypertee/c ds) any/c (hypertee/c ds))])
    [_ (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)])
  (hypertee-bind-pred-degree dss (hypertee-degree ht) ht func))

(define (hypertee-join-one-degree degree ht)
  (hypertee-bind-one-degree degree ht #/fn hole data
    data))

(define
  (hypertee-set-degree-and-bind-all-degrees new-degree ht hole-to-ht)
  (w- ds (hypertee-dim-sys ht)
  #/w- intermediate-degree
    (dim-sys-dim-max ds new-degree (hypertee-degree ht))
  #/hypertee-set-degree-force new-degree
  #/hypertee-bind-all-degrees
    (hypertee-increase-degree-to intermediate-degree ht)
  #/fn hole data
    (w- hole-degree (hypertee-degree hole)
    #/w- result (hole-to-ht hole data)
    #/expect
      (dim-sys-dim=? ds (hypertee-degree result)
        (dim-sys-dim-max ds new-degree hole-degree))
      #t
      (raise-arguments-error 'hypertee-set-degree-and-bind-all-degrees
        "expected each result of hole-to-ht to be a hypertee of the same degree as new-degree or the degree of the hole it appeared in, whichever was greater"
        "new-degree" new-degree
        "hole-degree" hole-degree
        "hole-to-ht-result" result)
    #/hypertee-increase-degree-to intermediate-degree result)))

(define (hypertee-append-zero ds degree hts)
  (begin
    ; TODO DOCS: See if we can verify these things in the contract.
    (list-each hts #/fn ht
      (expect (dim-sys-dim=? ds degree (hypertee-degree ht)) #t
        (raise-arguments-error 'hypertee-append-zero
          "expected each element of hts to be a hypertee of the given degree"
          "degree" degree
          "ht" ht)
      #/w- hole-value (hypertee-get-hole-zero ht)
      #/expect hole-value (just #/trivial)
        (raise-arguments-error 'hypertee-append-zero
          "expected each element of hts to have a trivial value in its degree-zero hole"
          "hole-value" hole-value
          "ht" ht)
      #/void))
  ; Now we know that the elements of `hts` are hypertees of degree
  ; `degree` and that their degree-0 holes have trivial values as
  ; contents. We return their degree-0 concatenation.
  #/list-foldr hts
    (ht-bracs ds degree #/htb-labeled (dim-sys-dim-zero ds) #/trivial)
  #/fn ht tail
    (hypertee-bind-one-degree (dim-sys-dim-zero ds) ht #/fn hole data
      (dissect data (trivial)
        tail))))

(define (hypertee-dv-any-all-degrees ht func)
  (dissect ht (hypertee ds degree closing-brackets)
  #/list-any closing-brackets #/fn bracket
    (expect bracket (htb-labeled d data) #f
    #/func d data)))

; TODO: See if we'll use this.
(define/own-contract (hypertee-v-any-one-degree degree ht func)
  (->i
    (
      [degree (ht) (dim-sys-dim/c #/hypertee-dim-sys ht)]
      [ht hypertee?]
      [func (ht) (-> any/c any/c)])
    [_ any/c])
  (w- ds (hypertee-dim-sys ht)
  #/hypertee-dv-any-all-degrees ht #/fn d data
    (and (dim-sys-dim=? ds degree d)
    #/func data)))

(define/own-contract (hypertee-any-all-degrees ht func)
  (-> hypertee? (-> hypertee? any/c any/c) any/c)
  (hypertee-dv-any-all-degrees
    (hypertee-map-all-degrees ht #/fn hole data
      (list hole data))
  #/fn d hole-and-data
    (dissect hole-and-data (list hole data)
    #/func hole data)))

(define (hypertee-dv-all-all-degrees ht func)
  (dissect ht (hypertee ds degree closing-brackets)
  #/list-all closing-brackets #/fn bracket
    (expect bracket (htb-labeled d data) #t
    #/func d data)))

(define/own-contract (hypertee-all-all-degrees ht func)
  (-> hypertee? (-> hypertee? any/c any/c) any/c)
  (hypertee-dv-all-all-degrees
    (hypertee-map-all-degrees ht #/fn hole data
      (list hole data))
  #/fn d hole-and-data
    (dissect hole-and-data (list hole data)
    #/func hole data)))

(define (hypertee-dv-each-all-degrees ht body)
  (hypertee-dv-any-all-degrees ht #/fn d data #/begin
    (body d data)
    #f)
  (void))

(define (hypertee-v-each-one-degree degree ht body)
  (w- ds (hypertee-dim-sys ht)
  #/hypertee-dv-each-all-degrees ht #/fn d data
    (when (dim-sys-dim=? ds degree d)
      (body data))))

(define (hypertee-each-all-degrees ht body)
  (hypertee-any-all-degrees ht #/fn hole data #/begin
    (body hole data)
    #f)
  (void))

(define (hypertee-furl ds coil)
  (expect coil (hypertee-coil-hole degree data tails)
    (hypertee ds (dim-sys-dim-zero ds) #/list)
  #/expect (dim-sys-dim<? ds (hypertee-degree tails) degree) #t
    (error "Expected the tails of a hypertee-coil-hole to be a hypertee with degree less than the overall degree")
  #/begin
    (hypertee-dv-each-all-degrees tails #/fn d tail
      (unless
        (and (hypertee? tail)
          (dim-sys-dim=? ds degree #/hypertee-degree tail))
        (error "Expected the tails of a hypertee-coil-hole to be a hypertee with hypertees of the given degree in its holes")))
  #/begin
    (hypertee-dv-each-all-degrees tails #/fn d tail
      (hypertee-dv-each-all-degrees tail #/fn d2 data
        (when (dim-sys-dim<? ds d2 d)
        #/expect data (trivial)
          (error "Expected the tails of a hypertee-coil-hole to be a hypertee containing hypertees such that a hypertee in a hole of degree N contained only trivial values at degrees less than N")
        #/void)))
  #/hypertee-join-all-degrees #/hypertee-done degree
    (hypertee-done degree data
    #/hypertee-dv-map-all-degrees tails #/fn d tail
      (trivial))
    tails))

(define/own-contract (hypertee-contour? dss ht)
  (->i
    (
      [dss dim-successors-sys?]
      [ht (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)])
    [_ boolean?])
  (w- ds (dim-successors-sys-dim-sys dss)
  #/w- expected-succ-hole-degree (hypertee-degree ht)
  #/w- is-expected-degree
    (fn hole-degree
      (dim-successors-sys-dim=plus-int? dss
        expected-succ-hole-degree hole-degree 1))
  #/w-loop next is-expected-degree is-expected-degree ht ht
    (dissect (hypertee-unfurl ht)
      (hypertee-coil-hole overall-degree data tails)
    #/and (is-expected-degree #/hypertee-degree tails)
    #/hypertee-dv-all-all-degrees tails #/fn d tail
      (next (fn d2 #/dim-sys-dim=? ds d d2) tail))))

(define (hypertee-uncontour dss ht)
  (expect (hypertee-contour? dss ht) #t (nothing)
  #/dissect (hypertee-unfurl ht)
    (hypertee-coil-hole overall-degree data tails)
  #/just #/list data #/hypertee-dv-map-all-degrees tails #/fn d data
    (dissect (dim-successors-sys-dim-plus-int dss d 1) (just succ-d)
    #/dissect
      (hypertee-uncontour dss #/hypertee-set-degree-force succ-d data)
      (just #/list hole-value ht)
      hole-value)))

; TODO:
;
; See if we should define a higher-dimensional "reverse" operation. A
; hypertee reversal could swap any hole with, as long as the hole was
; otherwise of the same shape as the outside. More generally, we would
; have to designate a hole H1, and in each of H1's holes H2, designate
; another hole H3 of the same shape as H2. This could go recursively
; (needing to designate holes H5, H7, etc.), except that H2 already
; has a particular set of holes in spite of whatever we designate.
;
; Given a designation of those things, we could look at the bracket
; sequence and notice that we've split it up into bracket sequences
; that can be reversed individually.
;
; Is there any point to this operation? It's probably related to
; adjoint functors, right? The original motivation for this was to
; simplify our algorithms so they wouldn't have to use hyperstacks,
; but it's not clear that would happen.

; This takes a hypertee and removes all holes which don't satisfy the
; given predicate.
(define (hypertee-filter ht should-keep?)
  (dissect ht (hypertee ds d closing-brackets)
  #/hypertee-bind-all-degrees ht #/fn hole data
    (if (should-keep? hole data)
      (hypertee-done d data hole)
    #/if (dim-sys-dim=0? ds #/hypertee-degree hole)
      (error "Expected should-keep? to accept the degree-zero hole")
      (hypertee-increase-degree-to d hole))))

; This takes a hypertee, removes all holes of degree equal to or
; greater than a given degree, and demotes the hypertee to that
; degree. The given degree must not be greater than the hypertee's
; existing degree.
(define (hypertee-filter-degree-to new-degree ht)
  (dissect ht (hypertee ds d closing-brackets)
  #/expect (dim-sys-dim<=? ds new-degree d) #t
    (error "Expected ht to be a hypertee of degree no less than new-degree")
  #/if (dim-sys-dim=0? ds new-degree)
    ; NOTE: Since `hypertee-filter` can't filter out the degree-zero
    ; hole, we treat truncation to degree zero as a special case.
    (hypertee ds (dim-sys-dim-zero ds) #/list)
  #/dissect
    (hypertee-filter ht #/fn hole data
      (dim-sys-dim<? ds (hypertee-degree hole) new-degree))
    (hypertee ds d closing-brackets)
  #/hypertee ds new-degree closing-brackets))

(define/own-contract (hypertee-zip-map a b func)
  (->i
    (
      [a (b) (hypertee/c #/hypertee-dim-sys b)]
      [b hypertee?]
      [func (b)
        (-> (hypertee/c #/hypertee-dim-sys b) any/c any/c any/c)])
    [_ (b) (maybe/c #/hypertee/c #/hypertee-dim-sys b)])
  (dissect a (hypertee _ d-a closing-brackets-a)
  #/dissect b (hypertee ds d-b closing-brackets-b)
  #/expect (dim-sys-dim=? ds d-a d-b) #t
    (error "Expected hypertees a and b to have the same degree")
  #/expect (= (length closing-brackets-a) (length closing-brackets-b))
    #t
    (nothing)
  #/maybe-map
    (w-loop next
      
      closing-brackets
      (map list closing-brackets-a closing-brackets-b)
      
      rev-zipped (list)
      
      (expect closing-brackets (cons entry closing-brackets)
        (just #/reverse rev-zipped)
      #/dissect entry (list a b)
      #/mat a (htb-labeled d-a data-a)
        (mat b (htb-labeled d-b data-b)
          (expect (dim-sys-dim=? ds d-a d-b) #t (nothing)
          #/next closing-brackets
            (cons (htb-labeled d-a #/list data-a data-b) rev-zipped))
          (nothing))
      #/dissect a (htb-unlabeled d-a)
        (mat b (htb-labeled d-b data-b)
          (nothing)
        #/dissect b (htb-unlabeled d-b)
          (expect (dim-sys-dim=? ds d-a d-b) #t (nothing)
          #/next closing-brackets (cons a rev-zipped)))))
  #/fn zipped-closing-brackets
  #/hypertee-map-all-degrees (hypertee ds d-a zipped-closing-brackets)
  #/fn hole data
    (dissect data (list a b)
    #/func hole a b)))

; TODO: See if we should add this to Lathe Comforts.
(define/own-contract (list-fold-map-any state lst on-elem)
  (-> any/c list? (-> any/c any/c #/list/c any/c #/maybe/c any/c)
    (list/c any/c #/maybe/c list?))
  (w-loop next state state lst lst rev-result (list)
    (expect lst (cons elem lst)
      (list state #/just #/reverse rev-result)
    #/dissect (on-elem state elem) (list state maybe-elem)
    #/expect maybe-elem (just elem) (list state #/nothing)
    #/next state lst (cons elem rev-result))))

(define (hypertee-dv-fold-map-any-all-degrees state ht on-hole)
  (dissect ht (hypertee ds d closing-brackets)
  #/dissect
    (list-fold-map-any state closing-brackets #/fn state bracket
      (expect bracket (htb-labeled d data) (list state #/just bracket)
      #/dissect (on-hole state d data) (list state maybe-data)
      #/expect maybe-data (just data) (list state #/nothing)
      #/list state #/just #/htb-labeled d data))
    (list state maybe-closing-brackets)
  #/list state
    (maybe-map maybe-closing-brackets #/fn closing-brackets
      (hypertee ds d closing-brackets))))

; This zips a degree-N hypertee with a same-degree-or-higher hypertee
; if the hypertees have the same shape when certain holes of the
; higher-degree hypertee are removed -- namely, the holes of degree N
; or greater and the holes that don't match the given predicate.
(define
  (hypertee-selective-holes-zip-map smaller bigger should-zip? func)
  (dissect smaller (hypertee _ d-smaller closing-brackets-smaller)
  #/dissect bigger (hypertee ds d-bigger closing-brackets-bigger)
  #/expect (dim-sys-dim<=? ds d-smaller d-bigger) #t
    (error "Expected smaller to be a hypertee of degree no greater than bigger's degree")
  #/w- prepared-bigger
    (hypertee ds d-bigger
    #/list-kv-map closing-brackets-bigger #/fn i bracket
      (expect bracket (htb-labeled d data) bracket
      #/htb-labeled d #/list data i))
  #/w- prepared-bigger
    (hypertee-map-all-degrees prepared-bigger #/fn hole data
      (dissect data (list data i)
      #/list data i
        (and
          (dim-sys-dim<? ds (hypertee-degree hole) d-smaller)
          (should-zip? hole data))))
  #/w- filtered-bigger
    (hypertee-filter
      (hypertee-filter-degree-to d-smaller prepared-bigger)
    #/fn hole data
      (dissect data (list data i should-zip)
        should-zip))
  #/maybe-map
    (hypertee-zip-map smaller filtered-bigger #/fn hole smaller bigger
      (dissect bigger (list data i #t)
        (list (func hole smaller data) i)))
  #/dissectfn (hypertee _ zipped-filtered-d zipped-filtered-brackets)
  #/w- env
    (list-foldl (make-immutable-hasheq) zipped-filtered-brackets
    #/fn env bracket
      (expect bracket (htb-labeled d data) env
      #/dissect data (list data i)
      #/hash-set env i data))
  #/hypertee-dv-map-all-degrees prepared-bigger #/fn d data
    (dissect data (list data i should-zip)
    #/if should-zip
      (hash-ref env i)
      data)))

; This zips a degree-N hypertee with a same-degree-or-higher hypertee
; if the hypertees have the same shape when truncated to degree N.
(define (hypertee-low-degree-holes-zip-map smaller bigger func)
  (hypertee-selective-holes-zip-map
    smaller bigger (fn hole data #t) func))
