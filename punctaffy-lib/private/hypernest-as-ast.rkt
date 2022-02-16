#lang parendown racket/base

; punctaffy/private/hypernest-as-ast
;
; A data structure for encoding hypersnippet notations that can nest
; with themselves (represented in an AST style).

;   Copyright 2018-2022 The Lathe Authors
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
(require #/only-in racket/contract/combinator coerce-contract)
(require #/only-in racket/math natural?)
(require #/only-in racket/struct make-constructor-style-printer)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/hash hash-kv-each hash-ref-maybe)
(require #/only-in lathe-comforts/list
  list-each list-foldr list-kv-map list-map)
(require #/only-in lathe-comforts/match match/c)
(require #/only-in lathe-comforts/maybe
  just maybe? maybe/c maybe-map nothing)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-struct struct-easy)
(require #/only-in lathe-comforts/trivial trivial)
(require #/only-in lathe-morphisms/in-fp/mediary/set ok/c)

(require punctaffy/private/shim)
(init-shim)

(require #/only-in punctaffy/hypersnippet/dim
  dim-successors-sys? dim-sys? dim-successors-sys-dim-from-int
  dim-successors-sys-dim-sys dim-sys-dim<? dim-sys-dim<=?
  dim-sys-dim=? dim-sys-dim=0? dim-sys-dim/c dim-sys-0<dim/c
  dim-sys-dim-max dim-sys-dim-zero)
(require #/only-in punctaffy/hypersnippet/hyperstack
  hyperstack-dimension hyperstack-peek hyperstack-pop hyperstack-push
  make-hyperstack)
(require #/only-in punctaffy/private/hypertee-as-brackets
  htb-labeled htb-unlabeled hypertee? hypertee/c hypertee-coil-hole
  hypertee-coil-zero hypertee-contour hypertee-degree hypertee-dim-sys
  hypertee-done hypertee-dv-fold-map-any-all-degrees
  hypertee-dv-map-all-degrees hypertee-each-all-degrees hypertee-furl
  hypertee-get-brackets hypertee-get-hole-zero
  hypertee-low-degree-holes-zip-map hypertee-selective-holes-zip-map
  hypertee-set-degree-and-bind-all-degrees hypertee-unfurl)
(require #/only-in punctaffy/private/hypertee-unsafe
  unsafe-hypertee-from-brackets)
(require #/only-in punctaffy/private/suppress-internal-errors
  punctaffy-suppress-internal-errors)


(provide
  hnb-open)
(provide #/contract-out
  [hnb-open? (-> any/c boolean?)]
  [hnb-open-degree (-> hnb-open? any/c)]
  [hnb-open-data (-> hnb-open? any/c)])
(provide
  hnb-labeled)
(provide #/contract-out
  [hnb-labeled? (-> any/c boolean?)]
  [hnb-labeled-degree (-> hnb-labeled? any/c)]
  [hnb-labeled-data (-> hnb-labeled? any/c)])
(provide
  hnb-unlabeled)
(provide #/contract-out
  [hnb-unlabeled? (-> any/c boolean?)]
  [hnb-unlabeled-degree (-> hnb-unlabeled? any/c)])
(provide #/contract-out
  [hypernest-bracket? (-> any/c boolean?)]
  [hypernest-bracket/c (-> contract? contract?)])
(provide
  hypernest-coil-zero)
(provide #/contract-out
  [hypernest-coil-zero? (-> any/c boolean?)])
(provide
  hypernest-coil-hole)
(provide #/contract-out
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where there's an extra
  ; `hypernest-coil-hole-hole` field.
  [hypernest-coil-hole? (-> any/c boolean?)]
  [hypernest-coil-hole-overall-degree (-> hypernest-coil-hole? any/c)]
  [hypernest-coil-hole-data (-> hypernest-coil-hole? any/c)]
  [hypernest-coil-hole-tails-hypertee
    (-> hypernest-coil-hole? any/c)])
(provide
  hypernest-coil-bump)
(provide #/contract-out
  [hypernest-coil-bump? (-> any/c boolean?)]
  [hypernest-coil-bump-overall-degree (-> hypernest-coil-bump? any/c)]
  [hypernest-coil-bump-data (-> hypernest-coil-bump? any/c)]
  [hypernest-coil-bump-bump-degree (-> hypernest-coil-bump? any/c)]
  [hypernest-coil-bump-tails-hypernest
    (-> hypernest-coil-bump? any/c)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it's not exported.
  [hypernest-bracket-degree (-> hypernest-bracket? any/c)]
  [hypernest? (-> any/c boolean?)]
  ; TODO PARITY: Bring `hypernest-dim-sys` into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it's called
  ; `hypernest-get-dim-sys` and it's exported.
  ; TODO PARITY: Bring `hypernest-coil` into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it's called
  ; `hypernest-get-coil` and it's exported.
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it takes an extra `ds`
  ; argument and it's not exported.
  [hypernest-degree
    (->i ([hn hypernest?])
      [_ (hn) (dim-sys-dim/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it takes an extra `sfs`
  ; argument. (Actually, `punctaffy/hypersnippet/hypernest`'s
  ; implementation of hypernests might be a straightforward successor
  ; of this one.)
  ; TODO DOCS: Consider more expressive hypernest contract combinators
  ; than `hypernest/c`, and come up with a new name for it.
  [hypernest/c (-> dim-sys? flat-contract?)]
  ; TODO PARITY: Bring `punctaffy/hypersnippet/hypernest`'s
  ; `hypernestof/ob-c`, `hypernest-snippet-sys`,
  ; `hypernest-snippet-format-sys`,
  ; `hypertee-bracket->hypernest-bracket`, and
  ; `compatible-hypernest-bracket->hypertee-bracket` into parity with
  ; this module, where they don't exist.
  [hypernest-coil/c (-> dim-sys? flat-contract?)]
  [hypernest-from-brackets
    (->i
      (
        [ds dim-sys?]
        [degree (ds) (dim-sys-dim/c ds)]
        [brackets (ds)
          (listof #/hypernest-bracket/c #/dim-sys-dim/c ds)])
      [_ (ds) (hypernest/c ds)])]
  [hn-bracs
    (->i ([ds dim-sys?] [degree (ds) (dim-sys-dim/c ds)])
      #:rest
      [brackets (ds)
        (w- dim/c (dim-sys-dim/c ds)
        #/listof #/or/c
          (hypernest-bracket/c dim/c)
          (and/c (not/c hypernest-bracket?) dim/c))]
      [_ (ds) (hypernest/c ds)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist.
  [hn-bracs-dss
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
          (hypernest-bracket/c dim/c)
          (and/c (not/c hypernest-bracket?) dim/c))]
      [_ (dss) (hypernest/c #/dim-successors-sys-dim-sys dss)])]
  [hypernest-get-brackets
    (->i ([hn hypernest?])
      [_ (hn)
        (w- ds (hypernest-dim-sys hn)
        #/listof #/hypernest-bracket/c #/dim-sys-dim/c ds)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. If it
  ; did exist, it would use a more specific contract that asserted the
  ; result was of the requested degree.
  [hypernest-increase-degree-to
    (->i
      (
        [new-degree (hn) (dim-sys-dim/c #/hypernest-dim-sys hn)]
        [hn hypernest?])
      [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. If it
  ; did exist, it would use a more specific contract that asserted the
  ; result was of the requested degree.
  [hypernest-set-degree-force
    (->i
      (
        [new-degree (hn) (dim-sys-0<dim/c #/hypernest-dim-sys hn)]
        [hn hypernest?])
      [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypernest-snippet-sys` and
  ; `snippet-sys-shape->snippet`. If it did exist, it would use a more
  ; specific contract that asserted that the input abided by its own
  ; dimension system and that the result abided by the same dimension
  ; system and was of the same degree.
  [hypertee->hypernest (-> hypertee? hypernest?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypernest-snippet-sys` and
  ; `snippet-sys-snippet->maybe-shape`. If it did exist, it would use
  ; a more specific contract that asserted that the input abided by
  ; its own dimension system and that the result abided by the same
  ; dimension system and was of the same degree.
  [hypernest->maybe-hypertee (-> hypernest? #/maybe/c hypertee?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it's called
  ; `hypernest-shape` and takes an `hypernest-snippet-sys?` along with
  ; its other argument.
  [hypernest-filter-to-hypertee
    (->i ([hn hypernest?])
      [_ (hn) (hypertee/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist.
  ; Lately, we've preferred `snippet-sys-snippet-done` for this
  ; purpose rather than associating dimensions with successors.
  [hypernest-contour
    (->i
      (
        [dss dim-successors-sys?]
        [hole-value any/c]
        [ht (dss) (hypertee/c #/dim-successors-sys-dim-sys dss)])
      [_ (dss) (hypernest/c #/dim-successors-sys-dim-sys dss)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypernest-snippet-sys` and
  ; `snippet-sys-snippet-zip-map`. If it did exist, it would be called
  ; `hypernest-zip-map`, it would allow its hypertee argument to have
  ; a degree less than that of its hypernest argument, it would allow
  ; the transformer function to return a maybe value for early
  ; exiting, and it would use a more specific contract that asserted
  ; the result was of the same degree as the hypernest argument.
  [hypernest-holes-zip-map
    (->i
      (
        [ht (hn) (hypertee/c #/hypernest-dim-sys hn)]
        [hn hypernest?]
        [func (hn)
          (-> (hypertee/c #/hypernest-dim-sys hn) any/c any/c any/c)])
      [_ (hn) (maybe/c #/hypernest/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it's called
  ; `hypernest-get-coil`.
  [hypernest-unfurl
    (->i ([hn hypernest?])
      [_ (hn) (hypernest-coil/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypernest-snippet-sys` and `snippet-sys-snippet-map`. If it did
  ; exist, it would be called `hypernest-map`, it would pass its
  ; callback a hole shape rather than merely a degree, and it would
  ; use a more specific contract that asserted the result was of the
  ; same degree as the original.
  [hypernest-dv-map-all-degrees
    (->i
      (
        [hn hypernest?]
        [func (hn)
          (-> (dim-sys-dim/c #/hypernest-dim-sys hn) any/c any/c)])
      [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypernest-snippet-sys`, `snippet-sys-snippet-select-if-degree`,
  ; and `snippet-sys-snippet-map-selective`. If it did exist, it would
  ; be called `hypernest-map-if-degree=`, it would pass its callback a
  ; hole shape in addition to the value, and it would use a more
  ; specific contract that asserted the result was of the same degree
  ; as the original.
  [hypernest-v-map-one-degree
    (->i
      (
        [degree (hn) (dim-sys-dim/c #/hypernest-dim-sys hn)]
        [hn hypernest?]
        [func (-> any/c any/c)])
      [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])])
(provide
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/snippet`, where it's called `selected`.
  hypernest-join-selective-interpolation)
(provide #/contract-out
  [hypernest-join-selective-interpolation? (-> any/c boolean?)]
  [hypernest-join-selective-interpolation-val
    (-> hypernest-join-selective-interpolation? any/c)])
(provide
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/snippet`, where it's called `unselected`.
  hypernest-join-selective-non-interpolation)
(provide #/contract-out
  [hypernest-join-selective-non-interpolation? (-> any/c boolean?)]
  [hypernest-join-selective-non-interpolation-val
    (-> hypernest-join-selective-interpolation? any/c)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypernest-snippet-sys` and
  ; `snippet-sys-snippet-join-selective`. If it did exist, it would be
  ; called `hypernest-join-selective`, and it would use a much more
  ; specific contract.
  [hypernest-join-all-degrees-selective (-> hypernest? hypernest?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypernest-snippet-sys` and
  ; `snippet-sys-snippet-map`. If it did exist, it would be called
  ; `hypernest-map`, and it would use a much more specific contract.
  [hypernest-map-all-degrees
    (-> hypernest? (-> hypertee? any/c any/c) hypernest?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypernest-snippet-sys` and
  ; `snippet-sys-snippet-done`. If it did exist, it would pass the
  ; hole shape argument before the data argument, and it would use a
  ; more specific contract that asserted the result was of the
  ; requested degree.
  [hypernest-done
    (->i
      (
        [degree (hole) (dim-sys-dim/c #/hypertee-dim-sys hole)]
        [data any/c]
        [hole hypertee?])
      [_ (hole) (hypernest/c #/hypertee-dim-sys hole)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it's called
  ; `hypernest-get-hole-zero-maybe` and has a more specific contract.
  [hypernest-get-hole-zero (-> hypernest? maybe?)]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypernest-snippet-sys` and
  ; `snippet-sys-snippet-join`. If it did exist, it would be called
  ; `hypernest-join`, and it would use a much more specific contract.
  [hypernest-join-all-degrees
    (->i ([hn hypernest?])
      [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypernest-snippet-sys` and `snippet-sys-snippet-bind`. If it did
  ; exist, it would be called `hypernest-bind`, it would pass its
  ; callback a hole shape rather than merely a degree, and it would
  ; use a much more specific contract.
  [hypernest-dv-bind-all-degrees
    (->i
      (
        [hn hypernest?]
        [dv-to-hn (hn)
          (w- ds (hypernest-dim-sys hn)
          #/-> (dim-sys-dim/c ds) any/c (hypernest/c ds))])
      [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypernest-snippet-sys` and
  ; `snippet-sys-snippet-bind`. If it did exist, it would be called
  ; `hypernest-bind`, and it would use a much more specific contract.
  [hypernest-bind-all-degrees
    (->i
      (
        [hn hypernest?]
        [hole-to-hn (hn)
          (w- ds (hypernest-dim-sys hn)
          #/-> (hypertee/c ds) any/c (hypernest/c ds))])
      [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypernest-snippet-sys`,
  ; `snippet-sys-snippet-select-if-degree`, and
  ; `snippet-sys-snippet-bind-selective`. If it did exist, it would be
  ; called `hypernest-bind-if-degree=`, and it would use a much more
  ; specific contract.
  [hypernest-bind-one-degree
    (->i
      (
        [degree (hn) (dim-sys-dim/c #/hypernest-dim-sys hn)]
        [hn hypernest?]
        [hole-to-hn (hn)
          (w- ds (hypernest-dim-sys hn)
          #/-> (hypertee/c ds) any/c (hypernest/c ds))])
      [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would be accommodated through a mix of `hypernest-snippet-sys`,
  ; `snippet-sys-snippet-select-if-degree`, and
  ; `snippet-sys-snippet-join-selective`. If it did exist, it would be
  ; called `hypernest-join-if-degree=`, and it would use a much more
  ; specific contract.
  [hypernest-join-one-degree
    (->i
      (
        [degree (hn) (dim-sys-dim/c #/hypernest-dim-sys hn)]
        [hn hypernest?])
      [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypernest-snippet-sys`, `snippet-sys-snippet-bind`, and
  ; `snippet-sys-snippet-set-degree-maybe`. If it did exist, it might
  ; be called `hypernest-set-degree-and-bind`, and it would use a much
  ; more specific contract.
  [hypernest-set-degree-and-bind-highest-degrees
    (->i
      (
        [new-degree (hn) (dim-sys-0<dim/c #/hypernest-dim-sys hn)]
        [hn hypernest?]
        [hole-to-hn (hn)
          (w- ds (hypernest-dim-sys hn)
          #/-> (hypertee/c ds) any/c (hypernest/c ds))])
      [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypernest-snippet-sys`, `snippet-sys-snippet-join`, and
  ; `snippet-sys-snippet-set-degree-maybe`. If it did exist, it might
  ; be called `hypernest-set-degree-and-join`, and it would use a much
  ; more specific contract.
  [hypernest-set-degree-and-join-all-degrees
    (->i
      (
        [new-degree (hn) (dim-sys-0<dim/c #/hypernest-dim-sys hn)]
        [hn hypernest?])
      [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't exist. It
  ; would probably be accommodated through a mix of
  ; `hypernest-snippet-sys` and the not-yet-exported
  ; `snippet-sys-snippet-join-list-and-tail-along-0`. If it did exist,
  ; it might be called `hypernest-join-list-and-tail-along-0`, it
  ; wouldn't take a `degree` argument, it would take a `last-snippet`
  ; argument, and it would use a much more specific contract.
  [hypernest-append-zero
    (->i
      (
        [ds dim-sys?]
        [degree (ds) (dim-sys-0<dim/c ds)]
        [hns (ds) (listof #/hypernest/c ds)])
      [_ (ds) (hypernest/c ds)])]
  ; TODO PARITY: Bring this into parity with
  ; `punctaffy/hypersnippet/hypernest`, where it doesn't have as
  ; strict a result contract and it has a match expander.
  [hypernest-furl
    (->i ([ds dim-sys?] [coil (ds) (hypernest-coil/c ds)])
      [_ (ds) (hypernest/c ds)])])


; ===== Hypernests ===================================================

(define-imitation-simple-struct (hypernest-coil-zero?)
  hypernest-coil-zero
  'hypernest-coil-zero (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct
  (hypernest-coil-hole?
    hypernest-coil-hole-overall-degree
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

(define-imitation-simple-struct
  (hypernest? hypernest-dim-sys hypernest-coil)
  hypernest
  'hypernest (current-inspector) (auto-equal)
  (#:prop prop:custom-write #/make-constructor-style-printer
    ; We write hypernests using a sequence-of-brackets representation.
    (fn self 'hn-bracs)
    (fn self
      (list* (hypernest-dim-sys self) (hypernest-degree self)
      #/list-map (hypernest-get-brackets self) #/fn bracket
        (expect bracket (hnb-unlabeled bracket) bracket
        #/if (hypernest-bracket? bracket)
          (hnb-unlabeled bracket)
          bracket)))))

(define (hypernest/c ds)
  (rename-contract (match/c hypernest (ok/c ds) any/c)
    `(hypernest/c ,ds)))

; TODO PARITY: Bring this into parity with
; `punctaffy/hypersnippet/hypernest`, where it checks that the tails
; in the tails hypertee and tails hypernest fit into the holes they're
; in.
;
(define (hypernest-coil/c ds)
  (rename-contract
    (or/c
      (match/c hypernest-coil-zero)
      (match/c hypernest-coil-hole (dim-sys-0<dim/c ds) any/c
        (hypertee/c ds))
      (match/c hypernest-coil-bump
        (dim-sys-0<dim/c ds)
        any/c
        (dim-sys-dim/c ds)
        (hypernest/c ds)))
    `(hypernest-coil/c ,ds)))

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

(define (hypernest-bracket? v)
  (or (hnb-open? v) (hnb-labeled? v) (hnb-unlabeled? v)))

(define (hypernest-bracket/c dim/c)
  (w- dim/c (coerce-contract 'hypernest-bracket/c dim/c)
  #/rename-contract
    (or/c
      (match/c hnb-open dim/c any/c)
      (match/c hnb-labeled dim/c any/c)
      (match/c hnb-unlabeled dim/c))
    `(hypernest-bracket/c ,(contract-name dim/c))))

(define (hypernest-bracket-degree bracket)
  (mat bracket (hnb-open d data) d
  #/mat bracket (hnb-labeled d data) d
  #/dissect bracket (hnb-unlabeled d) d))

; NOTE: This is a procedure we call only from within this module. It
; may seem like a synonym of `hypernest`, but when we're debugging
; this module, we can change it to be a synonym of `hypernest-furl`.
(define (hypernest-careful ds coil)
  (hypernest ds coil))

(define (explicit-hypernest-from-brackets err-name ds degree brackets)
  
  (struct-easy (parent-same-part should-annotate-as-nontrivial))
  (struct-easy (parent-new-part))
  (struct-easy (parent-part i should-annotate-as-trivial))
  
  (struct-easy
    (part-state
      is-hypernest
      first-nontrivial-degree
      first-non-interpolation-degree
      overall-degree
      rev-brackets))
  
  (w- opening-degree degree
  #/if (dim-sys-dim=0? ds opening-degree)
    (expect brackets (list)
      (error "Expected brackets to be empty since degree was zero")
    #/hypernest-careful ds #/hypernest-coil-zero)
  #/expect brackets (cons first-bracket brackets)
    (error "Expected brackets to be nonempty since degree was nonzero")
  #/w- root-i 'root
  #/w- stack (make-hyperstack ds opening-degree #/parent-same-part #t)
  #/dissect
    (mat first-bracket (hnb-open bump-degree data)
      (list
        (fn root-part
          (hypernest-careful ds #/hypernest-coil-bump
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
          "first-bracket" first-bracket
          "brackets" brackets)
      #/dissect (hyperstack-pop hole-degree stack #/parent-new-part)
        (list (parent-same-part #t) stack)
      #/list
        (fn root-part
          (hypernest-careful ds #/hypernest-coil-hole
            opening-degree data root-part))
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
            (hypernest-dv-map-all-degrees
              (hypernest-from-brackets ds overall-degree
              #/reverse rev-brackets)
            #/fn d data
              (get-subpart d data))
            (hypertee-dv-map-all-degrees
              (unsafe-hypertee-from-brackets ds overall-degree
              #/reverse #/list-map rev-brackets #/fn closing-bracket
                (mat closing-bracket (hnb-labeled d data)
                  (htb-labeled d data)
                #/dissect closing-bracket (hnb-unlabeled d)
                  (htb-unlabeled d)))
            #/fn d data
              (get-subpart d data))))
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

(define (hypernest-from-brackets ds degree brackets)
  (explicit-hypernest-from-brackets 'hypernest-from-brackets
    ds degree brackets))

(define (hn-bracs ds degree . brackets)
  (explicit-hypernest-from-brackets 'hn-bracs ds degree
  #/list-map brackets #/fn bracket
    (if (hypernest-bracket? bracket)
      bracket
      (hnb-unlabeled bracket))))

(define (hn-bracs-dss dss degree . brackets)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/w- n-d
    (fn n
      (expect (natural? n) #t n
      #/mat (dim-successors-sys-dim-from-int dss n) (just d) d
      #/raise-arguments-error 'hn-bracs-dss
        "expected the given number of successors to exist for the zero dimension"
        "n" n
        "dss" dss))
  #/hypernest-from-brackets ds (n-d degree)
  #/list-map brackets #/fn bracket
    (mat bracket (hnb-open d data) (hnb-open (n-d d) data)
    #/mat bracket (hnb-labeled d data) (hnb-labeled (n-d d) data)
    #/mat bracket (hnb-unlabeled d) (hnb-unlabeled (n-d d))
    #/hnb-unlabeled (n-d bracket))))

(define (assert-valid-hypernest-coil err-name ds coil)
  (mat coil (hypernest-coil-zero) (void)
  #/mat coil
    (hypernest-coil-hole overall-degree hole-value tails-hypertee)
    ; NOTE: We don't validate `hole-value`.
    (expect
      (dim-sys-dim<? ds
        (hypertee-degree tails-hypertee)
        overall-degree)
      #t
      (raise-arguments-error err-name
        "expected the tails of a hypernest-coil-hole to be a hypertee of degree strictly less than the overall degree"
        "tails-hypertee" tails-hypertee
        "overall-degree" overall-degree)
    #/hypertee-each-all-degrees tails-hypertee #/fn hole tail
      (w- hole-degree (hypertee-degree hole)
      #/expect (hypernest? tail) #t
        (raise-arguments-error err-name
          "expected each tail of a hypernest-coil-hole to be a hypernest"
          "tail" tail)
      #/expect
        (dim-sys-dim=? ds (hypernest-degree tail) overall-degree)
        #t
        (raise-arguments-error err-name
          "expected each tail of a hypernest-coil-hole to be a hypernest of the same degree as the overall degree"
          "tail" tail
          "overall-degree" overall-degree)
      #/expect
        (hypertee-low-degree-holes-zip-map hole
          (hypernest-filter-to-hypertee tail)
        #/fn hole-hole hole-data tail-data
          (expect tail-data (trivial)
            (raise-arguments-error err-name
              "expected each tail of a hypernest-coil-hole to have trivial values in its low-degree holes"
              "tail-data" tail-data)
          #/trivial))
        (just zipped)
        (raise-arguments-error err-name
          "expected each tail of a hypernest-coil-hole to match up with the hole it occurred in"
          "tail" tail
          "overall-degree" overall-degree)
      #/void))
  #/dissect coil
    (hypernest-coil-bump
      overall-degree bump-value bump-degree tails-hypernest)
    ; NOTE: We don't validate `bump-value`.
    (expect
      (dim-sys-dim=? ds
        (dim-sys-dim-max ds overall-degree bump-degree)
        (hypernest-degree tails-hypernest))
      #t
      (raise-arguments-error err-name
        "expected the tails of a hypernest-coil-bump to be a hypernest of degree equal to the max of the overall degree and the bump degree"
        "tails-hypernest" tails-hypernest
        "overall-degree" overall-degree
        "bump-degree" bump-degree)
    #/hypernest-each-all-degrees tails-hypernest #/fn hole data
      (w- hole-degree (hypertee-degree hole)
      #/when (dim-sys-dim<? ds hole-degree bump-degree)
        (expect (hypernest? data) #t
          (raise-arguments-error err-name
            "expected each tail of a hypernest-coil-bump to be a hypernest"
            "tail" data)
        #/expect
          (dim-sys-dim=? ds
            (hypernest-degree data)
            (dim-sys-dim-max ds hole-degree overall-degree))
          #t
          (raise-arguments-error err-name
            "expected each tail of a hypernest-coil-bump to be a hypernest of the same degree as the overall degree or of the same degree as the hole it occurred in, whichever was greater"
            "tail" data
            "hole-degree" hole-degree
            "overall-degree" overall-degree)
        #/expect
          (hypertee-low-degree-holes-zip-map hole
            (hypernest-filter-to-hypertee data)
          #/fn hole-hole hole-data tail-data
            (expect tail-data (trivial)
              (raise-arguments-error err-name
                "expected each tail of a hypernest-coil-bump to have trivial values in its low-degree holes"
                "tail-data" tail-data)
            #/trivial))
          (just zipped)
          (raise-arguments-error err-name
            "expected each tail of a hypernest-coil-bump to match up with the hole it occurred in"
            "tail" data
            "hole" hole)
        #/void)))))

; TODO: See if we'll ever use this. For now, we just have it here as
; an analogue to `unsafe-hypertee-from-brackets`.
(define/own-contract (unsafe-hypernest-furl ds coil)
  (-> dim-sys? any/c any)
  (unless (punctaffy-suppress-internal-errors)
    ; NOTE: At this point we don't expect
    ; `assert-valid-hypernest-coil` itself to be very buggy. Since its
    ; implementation involves the construction of other hypertees and
    ; hypernests, we can save a *lot* of time by constructing those
    ; without verification. Otherwise the verification can end up
    ; doing some rather catastrophic recursion.
    (parameterize ([punctaffy-suppress-internal-errors #t])
      (assert-valid-hypernest-coil 'unsafe-hypernest-furl ds coil)))
  (hypernest ds coil))

(define (hypernest-furl ds coil)
  ; NOTE: At this point we don't expect `assert-valid-hypernest-coil`
  ; itself to be very buggy. Since its implementation involves the
  ; construction of other hypertees and hypernests, we can save a
  ; *lot* of time by constructing those without verification.
  ; Otherwise the verification can end up doing some rather
  ; catastrophic recursion.
  (parameterize ([punctaffy-suppress-internal-errors #t])
    (assert-valid-hypernest-coil 'hypernest-furl ds coil))
  (hypernest ds coil))

(define (hypernest-degree hn)
  (dissect hn (hypernest ds coil)
  #/mat coil (hypernest-coil-zero) (dim-sys-dim-zero ds)
  #/mat coil (hypernest-coil-hole d data tails) d
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    overall-degree))

(define (hypernest-get-brackets hn)
  (dissect hn (hypernest ds coil)
  #/w- interleave
    (fn overall-degree bump-degree tails #/let ()
      
      (struct-easy (state-in-root))
      (struct-easy (state-in-interpolation i))
      
      (w-loop next
        
        root-brackets (list-kv-map tails #/fn k v #/list k v)
        interpolations (make-immutable-hasheq)
        
        hist
        (list (state-in-root)
          (make-hyperstack ds
            (dim-sys-dim-max ds overall-degree bump-degree)
            (state-in-root)))
        
        rev-result (list)
        
        (define (finish root-brackets interpolations rev-result)
          (expect root-brackets (list)
            (error "Internal error: Encountered the end of a hypernest hole or bump tail in a region of degree 0 before getting to the end of the hole or bump itself")
          #/void)
          (hash-kv-each interpolations #/fn i interpolation-brackets
            (expect interpolation-brackets (list)
              (error "Internal error: Encountered the end of a hypernest hole or bump bracket system before getting to the end of its tails")
            #/void))
          (reverse rev-result))
        
        (define (pop-interpolation-bracket interpolations i)
          (expect (hash-ref interpolations i) (cons bracket rest)
            (list interpolations #/nothing)
            (list (hash-set interpolations i rest) #/just bracket)))
        
        (dissect hist (list state histories)
        #/mat state (state-in-interpolation interpolation-i)
          
          ; We read from the interpolation's bracket stream.
          (dissect
            (pop-interpolation-bracket interpolations interpolation-i)
            (list interpolations maybe-bracket)
          #/expect maybe-bracket (just bracket)
            ; TODO: We used to make this check here, back when this
            ; code was part of `hypertee-join-all-degrees`. However,
            ; since we can have a bump of degree 0, and a
            ; non-interpolation such as a bump causes us to push
            ; rather than pop the hyperstack, we can have a hyperstack
            ; of degree other than 0 at the end here. See if there's
            ; some other check we should make. This was an internal
            ; error anyway, so maybe not.
;            (expect
;              (dim-sys-dim=0? ds #/hyperstack-dimension histories)
;              #t
;              (error "Internal error: A hypernest tail ran out of brackets before reaching a region of degree 0")
            (begin
            ; The interpolation has no more brackets, and we're in a
            ; region of degree 0, so we end the loop.
            #/finish root-brackets interpolations rev-result)
          #/w- d (hypernest-bracket-degree bracket)
          #/if
            (mat bracket (hnb-open d data) #t
              (dim-sys-dim<=? ds (hyperstack-dimension histories) d))
            ; We begin a non-interpolation in an interpolation.
            (w- histories (hyperstack-push d histories state)
            #/w- hist (list state histories)
            #/next root-brackets interpolations hist
              (cons bracket rev-result))
          #/dissect (hyperstack-pop d histories state)
            (list state histories)
          #/w- hist (list state histories)
          #/mat state (state-in-root)
            
            ; We've moved out of the interpolation through a
            ; low-degree hole and arrived at the root. Now we proceed
            ; by processing the root's brackets instead of the
            ; interpolation's brackets.
            ;
            (dissect root-brackets
              (cons (list root-bracket-i root-bracket) root-brackets)
            #/begin
              (mat bracket (hnb-labeled d data)
                (expect data (trivial)
                  (error "Internal error: A hypernest hole or bump had a tail with a low-degree hole where the value wasn't a trivial value")
                #/void)
              #/void)
            #/next root-brackets interpolations hist
              (cons (hnb-unlabeled d) rev-result))
          #/dissect state (state-in-interpolation i)
            
            ; We just moved out of a non-interpolation of the
            ; interpolation, so we're still in the interpolation, and
            ; we continue to proceed by processing the interpolation's
            ; brackets.
            ;
            (next root-brackets interpolations hist
              (cons bracket rev-result)))
        
        ; We read from the root's bracket stream.
        #/expect root-brackets (cons root-bracket root-brackets)
          ; TODO: We used to make this check here, back when this code
          ; was part of `hypertee-join-all-degrees`. However, since we
          ; can have a bump of degree 0, and a non-interpolation such
          ; as a bump causes us to push rather than pop the
          ; hyperstack, we can have a hyperstack of degree other than
          ; 0 at the end here. See if there's some other check we
          ; should make. This was an internal error anyway, so maybe
          ; not.
;          (expect (dim-sys-dim=0? ds #/hyperstack-dimension histories)
;            #t
;            (error "Internal error: A hypernest hole or bump ran out of brackets before reaching a region of degree 0")
          (begin
          ; The root has no more brackets, and we're in a region of
          ; degree 0, so we end the loop.
          #/finish root-brackets interpolations rev-result)
        #/dissect root-bracket (list root-bracket-i bracket)
        #/w- d (hypernest-bracket-degree bracket)
        #/if
          (mat bracket (hnb-open _ _) #t
          #/mat bracket (hnb-labeled d _)
            (dim-sys-dim<=? ds bump-degree d)
          #/dissect bracket (hnb-unlabeled _)
            #f)
          ; We begin a non-interpolation in the root.
          (w- histories (hyperstack-push d histories state)
          #/w- hist (list state histories)
          #/next root-brackets interpolations hist
            (cons bracket rev-result))
        #/expect (dim-sys-dim<? ds d #/hyperstack-dimension histories)
          #t
          (error "Internal error: Expected each hole of a hypernest hole or bump to be of a degree less than the current region's degree")
        #/w- old-d (hyperstack-dimension histories)
        #/dissect (hyperstack-pop d histories state)
          (list state histories)
        #/expect bracket (hnb-labeled d data)
          (w- hist (list state histories)
          #/mat state (state-in-root)
            ; We just moved out of a non-interpolation of the root, so
            ; we're still in the root.
            (next root-brackets interpolations hist
              (cons bracket rev-result))
          #/dissect state (state-in-interpolation i)
            ; We resume an interpolation in the root.
            (dissect (pop-interpolation-bracket interpolations i)
              (list interpolations #/just interpolation-bracket)
            #/next root-brackets interpolations hist
              (cons (hnb-unlabeled d) rev-result)))
        ; We begin an interpolation in the root.
        #/expect data (list data-d data-brackets)
          (error "Internal error: Expected each hypernest bump or hole tail to be converted to brackets already")
        #/expect
          (dim-sys-dim=? ds
            data-d
            (dim-sys-dim-max ds overall-degree d))
          #t
          (error "Internal error: Expected each hypernest bump or hole tail to have the same degree as the root or the bump, whichever was greater")
        #/next root-brackets
          (hash-set interpolations root-bracket-i data-brackets)
          (list (state-in-interpolation root-bracket-i) histories)
          (cons (hnb-unlabeled d) rev-result))))
  #/mat coil (hypernest-coil-zero) (list)
  #/mat coil (hypernest-coil-hole overall-degree data tails)
    (w- hole-degree (hypertee-degree tails)
    #/w- tails
      (hypertee-get-brackets
      #/hypertee-dv-map-all-degrees tails #/fn d tail
        (list
          (hypernest-degree tail)
          (hypernest-get-brackets tail)))
    #/cons (hnb-labeled hole-degree data)
    #/interleave overall-degree hole-degree
    #/list-map tails #/fn closing-bracket
      (mat closing-bracket (htb-labeled d data) (hnb-labeled d data)
      #/dissect closing-bracket (htb-unlabeled d) (hnb-unlabeled d)))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (cons (hnb-open bump-degree data)
    #/interleave overall-degree bump-degree
      (hypernest-get-brackets
      #/hypernest-dv-map-all-degrees tails #/fn d data
        (if (dim-sys-dim<? ds d bump-degree)
          (list
            (hypernest-degree data)
            (hypernest-get-brackets data))
          data)))))

; Takes a hypernest of any nonzero degree N and upgrades it to any
; degree N or greater, while leaving its bumps and holes the way they
; are.
(define (hypernest-increase-degree-to new-degree hn)
  (dissect hn (hypernest ds coil)
  #/mat coil (hypernest-coil-zero)
    (error "Expected hn to be a hypernest of nonzero degree")
  #/expect (dim-sys-dim<=? ds (hypernest-degree hn) new-degree) #t
    (raise-arguments-error 'hypernest-increase-degree-to
      "expected hn to be a hypernest of degree no greater than new-degree"
      "new-degree" new-degree
      "hn" hn)
  #/mat coil (hypernest-coil-hole d data tails)
    (if (dim-sys-dim=? ds d new-degree) hn
    #/hypernest-careful ds #/hypernest-coil-hole new-degree data
    #/hypertee-dv-map-all-degrees tails #/fn d tail
      (hypernest-increase-degree-to new-degree tail))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (if (dim-sys-dim=? ds overall-degree new-degree) hn
    #/hypernest-careful ds
    #/hypernest-coil-bump new-degree data bump-degree
    #/hypernest-increase-degree-to
      (dim-sys-dim-max ds new-degree bump-degree)
    #/hypernest-dv-map-all-degrees tails #/fn d data
      (if (dim-sys-dim<? ds d bump-degree)
        (hypernest-increase-degree-to
          (dim-sys-dim-max ds d new-degree)
          data)
        data))))

; Takes a nonzero-degree hypernest with no holes of degree N or
; greater and returns a degree-N hypernest with the same bumps and
; holes.
(define (hypernest-set-degree-force new-degree hn)
  (dissect hn (hypernest ds coil)
  #/mat coil (hypernest-coil-zero)
    (error "Expected hn to be a hypernest of nonzero degree")
  #/mat coil (hypernest-coil-hole d data tails)
    (if (dim-sys-dim=? ds d new-degree) hn
    #/expect (dim-sys-dim<? ds (hypertee-degree tails) new-degree) #t
      (raise-arguments-error 'hypernest-set-degree-force
        "expected hn to have no holes of degree new-degree or greater"
        "hn" hn
        "new-degree" new-degree
        "hole-degree" (hypertee-degree tails)
        "data" data)
    #/hypernest-careful ds #/hypernest-coil-hole new-degree data
    #/hypertee-dv-map-all-degrees tails #/fn d tail
      (hypernest-set-degree-force new-degree tail))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (if (dim-sys-dim=? ds overall-degree new-degree) hn
    #/hypernest-careful ds
    #/hypernest-coil-bump new-degree data bump-degree
    #/hypernest-dv-map-all-degrees
      (hypernest-set-degree-force
        (dim-sys-dim-max ds new-degree bump-degree)
        tails)
    #/fn d data
      (if (dim-sys-dim<? ds d bump-degree)
        (hypernest-set-degree-force (dim-sys-dim-max ds d new-degree)
          data)
        data))))

(define (hypertee->hypernest ht)
  (w- ds (hypertee-dim-sys ht)
  #/hypernest-careful ds
  #/expect (hypertee-unfurl ht)
    (hypertee-coil-hole overall-degree data tails)
    (hypernest-coil-zero)
  #/hypernest-coil-hole overall-degree data
  #/hypertee-dv-map-all-degrees tails #/fn d tail
    (hypertee->hypernest tail)))

(define (hypernest->maybe-hypertee hn)
  (dissect hn (hypernest ds coil)
  #/mat coil (hypernest-coil-zero)
    (just #/hypertee-furl ds #/hypertee-coil-zero)
  #/mat coil (hypernest-coil-hole d data tails)
    (dissect
      (hypertee-dv-fold-map-any-all-degrees (trivial) tails
      #/fn state d tail
        (list state #/hypernest->maybe-hypertee tail))
      (list (trivial) maybe-tails)
    #/maybe-map maybe-tails #/fn tails
    #/hypertee-furl ds #/hypertee-coil-hole d data tails)
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (nothing)))

(define (hypernest-filter-to-hypertee hn)
  (dissect hn (hypernest ds coil)
  #/mat coil (hypernest-coil-zero)
    (hypertee-furl ds #/hypertee-coil-zero)
  #/mat coil (hypernest-coil-hole d data tails)
    (hypertee-furl ds #/hypertee-coil-hole d data
    #/hypertee-dv-map-all-degrees tails #/fn d tail
      (hypernest-filter-to-hypertee tail))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (hypertee-set-degree-and-bind-all-degrees overall-degree
      (hypernest-filter-to-hypertee tails)
    #/fn hole data
      (if (dim-sys-dim<? ds (hypertee-degree hole) bump-degree)
        (hypernest-filter-to-hypertee data)
        (hypertee-done overall-degree data hole)))))

; Takes a hypertee of any degree N and returns a hypernest of degree
; N+1 with all the same degree-less-than-N holes as well as a single
; degree-N hole in the shape of the original hypertee. This should
; be useful as something like a monadic return.
(define (hypernest-contour dss hole-value ht)
  (hypertee->hypernest #/hypertee-contour dss hole-value ht))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/own-contract
  (hypernest-dv-fold-map-any-all-degrees state hn on-hole)
  (->i
    (
      [state any/c]
      [hn hypernest?]
      [on-hole (hn)
        (-> any/c (dim-sys-dim/c #/hypernest-dim-sys hn) any/c
          (list/c any/c #/maybe/c any/c))])
    [_ (hn)
      (list/c any/c #/maybe/c #/hypernest/c #/hypernest-dim-sys hn)])
  (dissect hn (hypernest ds coil)
  #/mat coil (hypernest-coil-zero)
    (list state #/just #/hypernest-careful ds #/hypernest-coil-zero)
  #/mat coil (hypernest-coil-hole d data tails)
    (dissect (on-hole state (hypertee-degree tails) data)
      (list state maybe-data)
    #/expect maybe-data (just data) (list state #/nothing)
    #/dissect
      (hypertee-dv-fold-map-any-all-degrees state tails
      #/fn state tails-hole-d tail
        (hypernest-dv-fold-map-any-all-degrees state tail
        #/fn state tail-hole-d data
          (if (dim-sys-dim<? ds tail-hole-d tails-hole-d)
            (dissect data (trivial)
            #/list state #/just #/trivial)
          #/on-hole state tail-hole-d data)))
      (list state maybe-tails)
    #/expect maybe-tails (just tails) (list state #/nothing)
    #/list state
      (just
      #/hypernest-careful ds #/hypernest-coil-hole d data tails))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (dissect
      (hypernest-dv-fold-map-any-all-degrees state tails
      #/fn state tails-hole-d data
        (if (dim-sys-dim<? ds tails-hole-d bump-degree)
          (hypernest-dv-fold-map-any-all-degrees state data
          #/fn state tail-hole-d data
            (if (dim-sys-dim<? ds tail-hole-d tails-hole-d)
              (dissect data (trivial)
              #/list state #/just #/trivial)
            #/on-hole state tail-hole-d data))
          (on-hole state tails-hole-d data)))
      (list state maybe-tails)
    #/expect maybe-tails (just tails) (list state #/nothing)
    #/list state
      (just #/hypernest-careful ds
      #/hypernest-coil-bump overall-degree data bump-degree tails))))

; This zips a degree-N hypertee with a same-degree-or-higher hypernest
; if they have the same holes when certain holes of the hypernest are
; removed -- namely, the holes of degree N or greater and the holes
; that don't match the given predicate.
;
; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
(define/own-contract
  (hypernest-selective-holes-zip-map smaller bigger should-zip? func)
  (->i
    (
      [smaller (bigger) (hypertee/c #/hypernest-dim-sys bigger)]
      [bigger hypernest?]
      [should-zip? (bigger)
        (-> (hypertee/c #/hypernest-dim-sys bigger) any/c boolean?)]
      [func (bigger)
        (-> (hypertee/c #/hypernest-dim-sys bigger) any/c any/c
          any/c)])
    [_ (bigger) (maybe/c #/hypernest/c #/hypernest-dim-sys bigger)])
  (w- ds (hypernest-dim-sys bigger)
  #/expect
    (dim-sys-dim<=? ds
      (hypertee-degree smaller)
      (hypernest-degree bigger))
    #t
    (error "Expected smaller to be a hypertee of degree no greater than bigger's degree")
  #/dissect
    (hypernest-dv-fold-map-any-all-degrees 0 bigger #/fn i d data
      (list (add1 i) #/just #/list i data))
    (list _ #/just bigger)
  #/maybe-map
    (hypertee-selective-holes-zip-map
      smaller
      (hypernest-filter-to-hypertee bigger)
      (fn hole entry
        (dissect entry (list i data)
        #/should-zip? hole data))
      (fn hole smaller-data entry
        (dissect entry (list i bigger-data)
        #/list i #/func hole smaller-data bigger-data)))
  #/fn zipped
  #/dissect
    (hypertee-dv-fold-map-any-all-degrees
      (make-immutable-hasheq)
      zipped
    #/fn hash d entry
      (dissect entry (list i data)
      #/list (hash-set hash i data) #/just entry))
    (list hash #/just _)
  #/hypernest-dv-map-all-degrees bigger #/fn d entry
    (dissect entry (list i original-data)
    #/mat (hash-ref-maybe hash i) (just zipped-data) zipped-data
      original-data)))

; This zips a degree-N hypertee with a same-degree-or-higher hypernest
; if they have the same holes when truncated to degree N.
;
; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
(define/own-contract
  (hypernest-low-degree-holes-zip-map smaller bigger func)
  (->i
    (
      [smaller (bigger) (hypertee/c #/hypernest-dim-sys bigger)]
      [bigger hypernest?]
      [func (bigger)
        (-> (hypertee/c #/hypernest-dim-sys bigger) any/c any/c
          any/c)])
    [_ (bigger) (maybe/c #/hypernest/c #/hypernest-dim-sys bigger)])
  (hypernest-selective-holes-zip-map
    smaller bigger (fn hole data #t) func))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define (hypernest-holes-zip-map ht hn func)
  (w- ds (hypernest-dim-sys hn)
  #/expect
    (dim-sys-dim=? ds (hypertee-degree ht) (hypernest-degree hn))
    #t
    (error "Expected the hypertee and the hypernest to have the same degree")
  #/hypernest-low-degree-holes-zip-map ht hn func))

(define (hypernest-unfurl hn)
  (dissect hn (hypernest ds coil)
    coil))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/own-contract (hypernest-dgv-map-all-degrees hn func)
  (->i
    (
      [hn hypernest?]
      [func (hn)
        (w- ds (hypernest-dim-sys hn)
        #/-> (dim-sys-dim/c ds) (-> #/hypertee/c ds) any/c any/c)])
    [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])
  (dissect hn (hypernest ds coil)
  #/mat coil (hypernest-coil-zero)
    (hypernest-careful ds #/hypernest-coil-zero)
  #/mat coil (hypernest-coil-hole d data tails)
    (hypernest-careful ds #/hypernest-coil-hole d
      (func
        (hypertee-degree tails)
        (fn #/hypertee-dv-map-all-degrees tails #/fn d tail #/trivial)
        data)
    #/hypertee-dv-map-all-degrees tails #/fn tails-hole-d tail
      (hypernest-dgv-map-all-degrees tail
      #/fn tail-hole-d get-tail-hole data
        (if (dim-sys-dim<? ds tail-hole-d tails-hole-d)
          (dissect data (trivial)
          #/trivial)
        #/func tail-hole-d get-tail-hole data)))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (hypernest-careful ds
    #/hypernest-coil-bump overall-degree data bump-degree
    #/hypernest-dgv-map-all-degrees tails
    #/fn tails-hole-d get-tails-hole data
      (if (dim-sys-dim<? ds tails-hole-d bump-degree)
        (hypernest-dgv-map-all-degrees data
        #/fn tail-hole-d get-tail-hole data
          (if (dim-sys-dim<? ds tail-hole-d tails-hole-d)
            (dissect data (trivial)
            #/trivial)
          #/func tail-hole-d get-tail-hole data))
        (func tails-hole-d get-tails-hole data)))))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define (hypernest-dv-map-all-degrees hn func)
  (hypernest-dgv-map-all-degrees hn #/fn d get-hole data
    (func d data)))

(define (hypernest-v-map-one-degree degree hn func)
  (w- ds (hypernest-dim-sys hn)
  #/hypernest-dv-map-all-degrees hn #/fn hole-degree data
    (if (dim-sys-dim=? ds degree hole-degree)
      (func data)
      data)))

; TODO IMPLEMENT: Implement operations analogous to `hypertee-fold`.

(define-imitation-simple-struct
  (hypernest-join-selective-interpolation?
    hypernest-join-selective-interpolation-val)
  hypernest-join-selective-interpolation
  'hypernest-join-selective-interpolation
  (current-inspector)
  (auto-write)
  (auto-equal))
(define-imitation-simple-struct
  (hypernest-join-selective-non-interpolation?
    hypernest-join-selective-non-interpolation-val)
  hypernest-join-selective-non-interpolation
  'hypernest-join-selective-non-interpolation
  (current-inspector)
  (auto-write)
  (auto-equal))

; This takes a hypernest of degree N where each hole value of each
; degree M is either a `hypernest-join-selective-interpolation`
; containing another degree-N hypernest to be interpolated or a
; `hypernest-join-selective-non-interpolation`. In those interpolated
; hypernests, each value of a hole of degree L is either a
; `hypernest-join-selective-non-interpolation` or, if L is less than
; M, possibly a `hypernest-join-selective-interpolation` of a
; `trivial` value. This returns a single degree-N hypernest which has
; holes for all the non-interpolations of the interpolations and the
; non-interpolations of the root.
;
; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
(define (hypernest-join-all-degrees-selective hn)
  (dissect hn (hypernest ds coil)
  #/mat coil (hypernest-coil-zero)
    (hypernest-careful ds #/hypernest-coil-zero)
  #/w- result-degree (hypernest-degree hn)
  #/w- verify-hole-value
    (fn root-hole-degree data
      (mat data (hypernest-join-selective-interpolation interpolation)
        (expect (hypernest? interpolation) #t
          (raise-arguments-error 'hypernest-join-all-degrees-selective
            "expected each interpolation to be a hypernest"
            "hn" hn
            "root-hole-degree" root-hole-degree
            "interpolation" interpolation)
        #/expect
          (dim-sys-dim=? ds
            result-degree
            (hypernest-degree interpolation))
          #t
          (raise-arguments-error 'hypernest-join-all-degrees-selective
            "expected every interpolation to have the same degree as the root hypernest"
            "hn" hn
            "root-hole-degree" root-hole-degree
            "interpolation" interpolation)
        #/void)
      #/mat data (hypernest-join-selective-non-interpolation _) (void)
      #/raise-arguments-error 'hypernest-join-all-degrees-selective
        "expected each of the root's hole values to be a hypernest-join-selective-interpolation or a hypernest-join-selective-non-interpolation"
        "hn" hn
        ; TODO: See if we should display a full hole shape here.
        "root-hole-degree" root-hole-degree
        "data" data))
  #/w- double-non-interpolations
    (fn data
      (mat data (hypernest-join-selective-interpolation interpolation)
        ; TODO: See if there's some user input which makes
        ; `interpolation` a value other than a hypernest.
        (hypernest-join-selective-interpolation
        #/hypernest-dv-map-all-degrees interpolation #/fn d data
          (mat data (hypernest-join-selective-interpolation data)
            ; TODO: See if `data` is always a trivial value here.
            (hypernest-join-selective-interpolation data)
          ; TODO: See if there's some user input which makes this
          ; `dissect` fail.
          #/dissect data
            (hypernest-join-selective-non-interpolation data)
            (hypernest-join-selective-non-interpolation
            #/hypernest-join-selective-non-interpolation data)))
      ; TODO: See if there's some user input which makes this
      ; `dissect` fail.
      #/dissect data (hypernest-join-selective-non-interpolation data)
        (hypernest-join-selective-non-interpolation
        #/hypernest-join-selective-non-interpolation data)))
  #/mat coil (hypernest-coil-hole overall-degree data tails)
    (begin (verify-hole-value (hypertee-degree tails) data)
    #/mat data (hypernest-join-selective-interpolation interpolation)
      ; TODO: Make sure the recursive calls to
      ; `hypernest-join-all-degrees-selective` we make here always
      ; terminate. If they don't, we need to take a different
      ; approach.
      (expect
        (hypernest-selective-holes-zip-map tails interpolation
          (fn hole data
            (mat data (hypernest-join-selective-interpolation _)
              #t
              #f))
        #/fn tails-hole tail interpolation-data
          (expect interpolation-data
            (hypernest-join-selective-interpolation #/trivial)
            (error "Expected each low-degree hole of each interpolation to contain an interpolation of a trivial value")
          #/hypernest-join-selective-interpolation
          #/hypernest-join-all-degrees-selective
          #/hypernest-dv-map-all-degrees tail
          #/fn tail-hole-degree tail-data
            (if
              (dim-sys-dim<? ds
                tail-hole-degree
                (hypertee-degree tails-hole))
              (dissect tail-data (trivial)
              #/hypernest-join-selective-non-interpolation
              #/hypernest-join-selective-interpolation #/trivial)
            #/double-non-interpolations tail-data)))
        (just interpolation)
        (raise-arguments-error 'hypernest-join-all-degrees-selective
          "expected each interpolation to have the right shape for the hole it occurred in"
          "hn" hn
          ; TODO: See if we should display `tails` transformed so its
          ; holes contain trivial values here.
          "root-hole-degree" (hypertee-degree tails)
          "interpolation" interpolation)
      #/hypernest-join-all-degrees-selective interpolation)
    #/dissect data (hypernest-join-selective-non-interpolation data)
      (hypernest-careful ds
      #/hypernest-coil-hole overall-degree data
      #/hypertee-dv-map-all-degrees tails #/fn tails-hole-degree tail
        (hypernest-join-all-degrees-selective
        #/hypernest-dv-map-all-degrees tail #/fn tail-hole-degree data
          (if (dim-sys-dim<? ds tail-hole-degree tails-hole-degree)
            (dissect data (trivial)
            #/hypernest-join-selective-non-interpolation #/trivial)
            data))))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    ; TODO: Make sure the recursive calls to
    ; `hypernest-join-all-degrees-selective` we make here always
    ; terminate. If they don't, we need to take a different approach.
    (hypernest-careful ds
    #/hypernest-coil-bump overall-degree data bump-degree
    #/hypernest-join-all-degrees-selective
    #/hypernest-dv-map-all-degrees tails #/fn tails-hole-degree data
      (expect (dim-sys-dim<? ds tails-hole-degree bump-degree) #t
        (begin (verify-hole-value tails-hole-degree data)
        #/mat data
          (hypernest-join-selective-interpolation interpolation)
          (hypernest-join-selective-interpolation
          ; TODO: See if we really need this
          ; `hypernest-increase-degree-to` call.
          #/hypernest-increase-degree-to
            (dim-sys-dim-max ds bump-degree overall-degree)
            interpolation)
        #/dissect data
          (hypernest-join-selective-non-interpolation data)
          (hypernest-join-selective-non-interpolation data))
      #/hypernest-join-selective-non-interpolation
      #/hypernest-join-all-degrees-selective
      #/hypernest-dv-map-all-degrees data #/fn tail-hole-degree data
        (if (dim-sys-dim<? ds tail-hole-degree tails-hole-degree)
          (dissect data (trivial)
            (hypernest-join-selective-non-interpolation #/trivial))
          data)))))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define (hypernest-map-all-degrees hn func)
  (hypernest-dgv-map-all-degrees hn #/fn d get-hole data
    (func (get-hole) data)))

; TODO IMPLEMENT: Implement operations analogous to these:
;
;   hypertee-map-one-degree
;   hypertee-map-pred-degree
;   hypertee-map-highest-degree

(define (hypernest-done degree data hole)
  (w- ds (hypertee-dim-sys hole)
  #/expect (dim-sys-dim<? ds (hypertee-degree hole) degree) #t
    (raise-arguments-error 'hypernest-done
      "expected hole to be a hypertee of degree strictly less than the given degree"
      "degree" degree
      "hole" hole)
  #/hypertee->hypernest #/hypertee-done degree data hole))

(define (hypernest-get-hole-zero hn)
  (dissect hn (hypernest ds coil)
  #/mat coil (hypernest-coil-zero)
    (nothing)
  #/mat coil (hypernest-coil-hole d data tails)
    (expect (hypertee-get-hole-zero tails) (just tail)
      (just data)
    #/hypernest-get-hole-zero tail)
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (dissect (hypernest-get-hole-zero tails) (just tail)
    #/if (dim-sys-dim=0? ds bump-degree)
      (just tail)
    #/hypernest-get-hole-zero tail)))

; TODO IMPLEMENT: Implement operations analogous to these:
;
;   hypertee-bind-pred-degree
;   hypertee-bind-highest-degree

; This takes a hypernest of degree N where each hole value of each
; degree M is another degree-N hypernest to be interpolated. In those
; interpolated hypertees, the values of holes of degree less than M
; must be `trivial` values. This returns a single degree-N hypernest
; which has holes for all the degree-M-or-greater holes of the
; interpolations of each degree M.
;
; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
(define (hypernest-join-all-degrees hn)
  (w- ds (hypernest-dim-sys hn)
  #/hypernest-join-all-degrees-selective
  #/hypernest-dv-map-all-degrees hn #/fn root-hole-degree data
    (expect (hypernest? data) #t
      (error "Expected each interpolation of a hypernest join to be a hypernest")
    #/hypernest-join-selective-interpolation
    #/hypernest-dv-map-all-degrees data
    #/fn interpolation-hole-degree data
      (expect
        (dim-sys-dim<? ds interpolation-hole-degree root-hole-degree)
        #t
        (hypernest-join-selective-non-interpolation data)
      #/hypernest-join-selective-interpolation data))))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
; TODO IMPLEMENT: See if we should implement a corresponding
; `hypertee-dv-bind-all-degrees`. Would it actually be more efficient
; at all?
;
(define (hypernest-dv-bind-all-degrees hn dv-to-hn)
  (hypernest-join-all-degrees
  #/hypernest-dv-map-all-degrees hn dv-to-hn))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define (hypernest-bind-all-degrees hn hole-to-hn)
  (hypernest-join-all-degrees
  #/hypernest-map-all-degrees hn hole-to-hn))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define (hypernest-bind-one-degree degree hn func)
  (w- ds (hypernest-dim-sys hn)
  #/hypernest-bind-all-degrees hn #/fn hole data
    (if (dim-sys-dim=? ds degree #/hypertee-degree hole)
      (func hole data)
      (hypernest-done (hypernest-degree hn) data hole))))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define (hypernest-join-one-degree degree hn)
  (hypernest-bind-one-degree degree hn #/fn hole data
    data))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/own-contract
  (hypernest-set-degree-and-bind-all-degrees new-degree hn hole-to-hn)
  (->i
    (
      [new-degree (hn) (dim-sys-0<dim/c #/hypernest-dim-sys hn)]
      [hn hypernest?]
      [hole-to-hn (hn)
        (w- ds (hypernest-dim-sys hn)
        #/-> (hypertee/c ds) any/c (hypernest/c ds))])
    [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])
  (w- ds (hypernest-dim-sys hn)
  #/w- intermediate-degree
    (dim-sys-dim-max ds new-degree (hypernest-degree hn))
  #/hypernest-set-degree-force new-degree
  #/hypernest-bind-all-degrees
    (hypernest-increase-degree-to intermediate-degree hn)
  #/fn hole data
    (w- hole-degree (hypertee-degree hole)
    #/w- result (hole-to-hn hole data)
    #/expect
      (dim-sys-dim=? ds (hypernest-degree result)
        (dim-sys-dim-max ds new-degree hole-degree))
      #t
      (raise-arguments-error
        'hypernest-set-degree-and-bind-all-degrees
        "expected each result of hole-to-hn to be a hypernest of the same degree as new-degree or the degree of the hole it appeared in, whichever was greater"
        "new-degree" new-degree
        "hole-degree" hole-degree
        "hole-to-hn-result" result)
    #/hypernest-increase-degree-to intermediate-degree result)))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
; TODO IMPLEMENT: Implement an operation analogous to this, but for
; hypertees instead of hypernests.
;
(define
  (hypernest-set-degree-and-bind-highest-degrees
    new-degree hn hole-to-hn)
  (w- ds (hypernest-dim-sys hn)
  #/hypernest-set-degree-and-bind-all-degrees new-degree hn
  #/fn hole data
    (if (dim-sys-dim<=? ds new-degree (hypertee-degree hole))
      (hole-to-hn hole data)
      (hypernest-done new-degree data hole))))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
; TODO IMPLEMENT: Implement an operation analogous to this, but for
; hypertees instead of hypernests.
;
(define/own-contract
  (hypernest-set-degree-and-dv-bind-all-degrees
    new-degree hn dv-to-hn)
  (->i
    (
      [new-degree (hn) (dim-sys-0<dim/c #/hypernest-dim-sys hn)]
      [hn hypernest?]
      [dv-to-hn (hn)
        (w- ds (hypernest-dim-sys hn)
        #/-> (dim-sys-dim/c ds) any/c (hypernest/c ds))])
    [_ (hn) (hypernest/c #/hypernest-dim-sys hn)])
  (w- ds (hypernest-dim-sys hn)
  #/w- intermediate-degree
    (dim-sys-dim-max ds new-degree (hypernest-degree hn))
  #/hypernest-set-degree-force new-degree
  #/hypernest-dv-bind-all-degrees
    (hypernest-increase-degree-to intermediate-degree hn)
  #/fn hole-degree data
    (w- result (dv-to-hn hole-degree data)
    #/expect
      (dim-sys-dim=? ds (hypernest-degree result)
        (dim-sys-dim-max ds new-degree hole-degree))
      #t
      (raise-arguments-error
        'hypernest-set-degree-and-dv-bind-all-degrees
        "expected each result of dv-to-hn to be a hypernest of the same degree as new-degree or the degree of the hole it appeared in, whichever was greater"
        "new-degree" new-degree
        "hole-degree" hole-degree
        "dv-to-hn-result" result)
    #/hypernest-increase-degree-to intermediate-degree result)))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
; TODO IMPLEMENT: Implement an operation analogous to this, but for
; hypertees instead of hypernests.
;
(define (hypernest-set-degree-and-join-all-degrees new-degree hn)
  (w- ds (hypernest-dim-sys hn)
  #/hypernest-set-degree-and-dv-bind-all-degrees new-degree hn
  #/fn hole-degree data
    ; TODO: See if we can give a better error message when `data`
    ; doesn't conform to the contract `(hypernest/c ds)`.
    (expect
      (dim-sys-dim=? ds (hypernest-degree data)
        (dim-sys-dim-max ds new-degree hole-degree))
      #t
      (raise-arguments-error
        'hypernest-set-degree-and-dv-bind-all-degrees
        "expected each hole of hn to contain a hypernest of the same degree as new-degree or the degree of the hole, whichever was greater"
        "new-degree" new-degree
        "hole-degree" hole-degree
        "data" data)
      data)))

(define (hypernest-append-zero ds degree hns)
  (begin
    ; TODO DOCS: See if we can verify these things in the contract.
    (list-each hns #/fn hn
      (expect (dim-sys-dim=? ds degree (hypernest-degree hn)) #t
        (raise-arguments-error 'hypernest-append-zero
          "expected each element of hns to be a hypertee of the given degree"
          "degree" degree
          "hn" hn)
      #/w- hole-value (hypernest-get-hole-zero hn)
      #/expect hole-value (just #/trivial)
        (raise-arguments-error 'hypernest-append-zero
          "expected each element of hns to have a trivial value in its degree-zero hole"
          "hole-value" hole-value
          "hn" hn)
      #/void))
  ; Now we know that the elements of `hns` are hypernests of degree
  ; `degree` andthat  their degree-0 holes have trivial values as
  ; contents. We return their degree-0 concatenation.
  #/list-foldr hns
    (hn-bracs ds degree #/hnb-labeled (dim-sys-dim-zero ds) #/trivial)
  #/fn hn tail
    (hypernest-bind-one-degree (dim-sys-dim-zero ds) hn #/fn hole data
      (dissect data (trivial)
        tail))))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/own-contract (hypernest-dv-any-all-degrees hn func)
  (->i
    (
      [hn hypernest?]
      [func (hn)
        (-> (dim-sys-dim/c #/hypernest-dim-sys hn) any/c any/c)])
    [_ any/c])
  (dissect
    (hypernest-dv-fold-map-any-all-degrees (trivial) hn
    #/fn state d data
      (w- result (func d data)
      #/list result
        (if result
          (just data)
          (nothing))))
    (list result maybe-mapped)
  #/expect maybe-mapped (just mapped) #f
    result))

; TODO IMPLEMENT: Implement operations analogous to these:
;
;   hypertee-v-any-one-degree
;   hypertee-any-all-degrees
;   hypertee-dv-all-all-degrees
;   hypertee-all-all-degrees

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/own-contract (hypernest-dv-each-all-degrees hn body)
  (->i
    (
      [hn hypernest?]
      [func (hn)
        (-> (dim-sys-dim/c #/hypernest-dim-sys hn) any/c any)])
    [_ void?])
  (hypernest-dv-any-all-degrees hn #/fn d data #/begin
    (body d data)
    #f)
  (void))

; TODO IMPLEMENT: Implement operations analogous to these:
;
;   hypertee-v-each-one-degree

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/own-contract (hypernest-each-all-degrees hn body)
  (-> hypernest? (-> hypertee? any/c any) void?)
  (hypernest-dv-each-all-degrees
    (hypernest-map-all-degrees hn #/fn hole data
      (list hole data))
  #/fn d entry
    (dissect entry (list hole data)
    #/body hole data)))

; TODO IMPLEMENT: Implement operations analogous to these:
;
;   hypertee-contour?
;   hypertee-uncontour
;   hypertee-filter
;   hypertee-filter-degree-to
