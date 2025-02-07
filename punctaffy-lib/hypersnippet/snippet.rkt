#lang parendown racket/base

; punctaffy/hypersnippet/snippet
;
; An interface for data structures that are hypersnippet-shaped.

;   Copyright 2019-2022 The Lathe Authors
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

; TODO: Consider writing some abstractions or organization techniques
; that would help with the places marked as "NOTE DEBUGGABILITY" and
; the more urgent "TODO DEBUGGABILITY".
;
; It's hard to overstate how much we should keep this debugging
; scaffolding in place for the next time we need it.
; Hypersnippet-related bugs are rather confusing, and they can involve
; violations of rather intricate contracts -- contracts which
; themselves rely on the very operations that might be buggy.
;
; Note that we usually won't want to activate all the debug
; scaffolding at the same time. If we enable contract checking on
; basic hypersnippet-processing operations like
; `snippet-sys-snippet-map`, performance can degrade dramatically,
; taking the tests in `punctaffy/tests/test-hypernest-2` from under a
; minute to over two hours in length. Somewhat surprisingly, they
; still terminate, but the recursive feedback between the contracts
; and the operations they're protecting/using seems to lead to
; diabolically long execution times.

; NOTE DEBUGGABILITY: These are here for debugging.
(require #/for-syntax #/only-in racket/syntax syntax-local-eval)
(define-for-syntax debugging-in-inexpensive-ways #f)
(define-for-syntax debugging-with-contracts
  debugging-in-inexpensive-ways)
(define-for-syntax debugging-with-prints
  debugging-in-inexpensive-ways)
(define-for-syntax debugging-with-expensive-splice-contract #f)
(define-for-syntax debugging-with-expensive-map-contract #f)
(define-for-syntax debugging-with-expensive-hypertee-furl-contract #f)
(define-for-syntax debugging-with-prints-for-get-brackets
  debugging-in-inexpensive-ways)
(define-for-syntax debugging-with-prints-for-hypernest-furl
  debugging-in-inexpensive-ways)
(define-for-syntax debugging-with-prints-for-hypernest-qq
  debugging-in-inexpensive-ways)
(define-for-syntax debugging-with-safe-mode-printing
  ; NOTE: Generally, if we're debugging this module, the usual
  ; `prop:custom-write` behavior of hypertees and hypernests is likely
  ; to make our debug prints terribly recursive. To avoid that, we
  ; activate a safer (if far less readable) printing behavior that
  ; corresponds to the shapes of the underlying data structures.
  debugging-in-inexpensive-ways)
(define-for-syntax
  debugging-with-prints-for-unextend-finite-finite-dim
  debugging-in-inexpensive-ways)
(define-syntax (ifc stx)
  (syntax-protect
  #/syntax-case stx () #/ (_ condition then else)
  #/if (syntax-local-eval #'condition)
    #'then
    #'else))

; NOTE DEBUGGABILITY: These are here for debugging, as are all the
; `dlog` and `dlogr` calls throughout this file.
;
; NOTE DEBUGGABILITY: We could also do
; `(require lathe-debugging/placebo)` instead of defining this
; submodule, but that would introduce a package dependency on
; `lathe-debugging`, which at this point still isn't a published
; package.
;
(module private/lathe-debugging/placebo racket/base
  (provide #/all-defined-out)
  (define-syntax-rule (dlog value ... body) body)
  (define-syntax-rule (dlogr value ... body) body))
(ifc debugging-with-prints
  (require lathe-debugging)
  (require 'private/lathe-debugging/placebo))
(ifc debugging-with-prints-for-get-brackets
  (require #/prefix-in 2: lathe-debugging)
  (require #/prefix-in 2: 'private/lathe-debugging/placebo))
(ifc debugging-with-prints-for-hypernest-furl
  (require #/prefix-in 3: lathe-debugging)
  (require #/prefix-in 3: 'private/lathe-debugging/placebo))
(ifc debugging-with-prints-for-hypernest-qq
  (require #/prefix-in 4: lathe-debugging)
  (require #/prefix-in 4: 'private/lathe-debugging/placebo))
(ifc debugging-with-prints-for-unextend-finite-finite-dim
  (require #/prefix-in 5: lathe-debugging)
  (require #/prefix-in 5: 'private/lathe-debugging/placebo))
(require #/for-syntax #/only-in racket/format ~a)
(require #/only-in racket/contract/base contract)


(require #/for-syntax racket/base)
(require #/for-syntax #/only-in syntax/parse expr syntax-parse)

(require #/for-syntax #/only-in lathe-comforts fn)

; NOTE: The Racket documentation says `get/build-late-neg-projection`
; is in `racket/contract/combinator`, but it isn't. It's in
; `racket/contract/base`. Since it's also in `racket/contract` and the
; documentation correctly says it is, we require it from there.
(require #/only-in racket/contract
  get/build-late-neg-projection struct-type-property/c)
(require #/only-in racket/contract/base
  -> ->i and/c any any/c contract? contract-name flat-contract?
  flat-contract-predicate list/c listof none/c not/c or/c
  rename-contract)
(require #/only-in racket/contract/combinator
  blame-add-context coerce-contract contract-first-order-passes?
  make-contract make-flat-contract raise-blame-error)
(require #/only-in racket/contract/region define/contract)
(require #/only-in racket/match define-match-expander)
(require #/only-in racket/struct make-constructor-style-printer)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/contract
  by-own-method/c chaperone-obstinacy flat-obstinacy
  impersonator-obstinacy obstinacy? obstinacy-contract/c
  obstinacy-get-coerce-contract-for-id obstinacy-get-make-contract
  value-name-for-contract)
(require #/only-in lathe-comforts/list list-foldr list-map)
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

(require punctaffy/private/shim)
(init-shim)
(module+ private/hypertee
  (require punctaffy/private/shim)
  (init-shim))
(module+ private/hypernest
  (require punctaffy/private/shim)
  (init-shim))

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
  extended-with-top-dim-infinite extended-with-top-finite-dim-sys
  extend-with-top-dim-sys-morphism-sys
  functor-from-dim-sys-sys-apply-to-morphism
  natural-transformation-from-from-dim-sys-sys-apply-to-morphism
  unextend-with-top-dim-sys-morphism-sys)
(require #/only-in punctaffy/hypersnippet/hyperstack
  hyperstack-dimension hyperstack-peek hyperstack-pop hyperstack-push
  make-hyperstack)

(provide
  unselected)
(provide #/own-contract-out
  unselected?
  unselected-value)
(provide
  selected)
(provide #/own-contract-out
  selected?
  selected-value
  selectable?
  selectable/c
  selectable-map)
; TODO DEBUGGABILITY: Provide a contract-protected version instead.
; We're currently defining this as a macro instead of a function, to
; help with debugging this file, but when the debug scaffolding is
; deactivated, this is unprotected.
(provide
  snippet-sys-snippet-degree)
; TODO DEBUGGABILITY: Provide a contract-protected version instead.
; See the note on the `snippet-sys-snippet-degree` macro export.
(provide
  snippet-sys-snippet-done)
; TODO DEBUGGABILITY: Provide a contract-protected version instead.
; See the note on the `snippet-sys-snippet-degree` macro export.
(provide
  snippet-sys-snippet-splice)
(provide #/own-contract-out
  snippet-sys?
  snippet-sys-impl?
  snippet-sys-snippet/c
  snippet-sys-dim-sys
  snippet-sys-shape-snippet-sys
  ; TODO DEBUGGABILITY: Provide a contract-protected version like this
  ; commented-out export instead. See the note on the
  ; `snippet-sys-snippet-degree` macro export.
  #;
  snippet-sys-snippet-degree
  snippet-sys-snippet-with-degree/c
  snippet-sys-snippet-with-degree</c
  snippet-sys-snippet-with-degree=/c
  snippet-sys-snippet-with-0<degree/c
  snippet-sys-snippetof/ob-c
  snippet-sys-unlabeled-snippet/c
  snippet-sys-unlabeled-shape/c
  snippet-sys-snippet-zip-selective/ob-c
  snippet-sys-snippet-fitting-shape/c
  snippet-sys-shape->snippet
  snippet-sys-snippet->maybe-shape
  snippet-sys-snippet-set-degree-maybe
  ; TODO DEBUGGABILITY: Provide a contract-protected version like this
  ; commented-out export instead. See the note on the
  ; `snippet-sys-snippet-degree` macro export.
  #;
  snippet-sys-snippet-done
  snippet-sys-snippet-undone
  snippet-sys-snippet-select-everything
  ; TODO DEBUGGABILITY: Provide a contract-protected version like this
  ; commented-out export instead. See the note on the
  ; `snippet-sys-snippet-degree` macro export.
  #;
  snippet-sys-snippet-splice
  snippet-sys-snippet-zip-map-selective
  snippet-sys-snippet-zip-map
  snippet-sys-snippet-any?
  snippet-sys-snippet-all?
  snippet-sys-snippet-each
  snippet-sys-snippet-map-maybe
  snippet-sys-snippet-map
  snippet-sys-snippet-map-selective
  snippet-sys-snippet-select
  snippet-sys-snippet-select-if-degree
  snippet-sys-snippet-select-if-degree<
  snippet-sys-snippet-bind-selective
  snippet-sys-snippet-join-selective
  snippet-sys-snippet-bind
  snippet-sys-snippet-join
  prop:snippet-sys
  ; TODO: See if we can come up with a better name or interface for
  ; this.
  make-snippet-sys-impl-from-various-1
  
  snippet-sys-morphism-sys?
  snippet-sys-morphism-sys-impl?
  snippet-sys-morphism-sys-source
  snippet-sys-morphism-sys-replace-source
  snippet-sys-morphism-sys-target
  snippet-sys-morphism-sys-replace-target
  snippet-sys-morphism-sys-dim-sys-morphism-sys
  snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
  snippet-sys-morphism-sys-morph-snippet
  snippet-sys-morphism-sys/c
  prop:snippet-sys-morphism-sys
  make-snippet-sys-morphism-sys-impl-from-morph
  snippet-sys-morphism-sys-identity
  snippet-sys-morphism-sys-chain-two)

(provide
  snippet-sys-category-sys)
(provide #/own-contract-out
  snippet-sys-category-sys?)

(provide #/own-contract-out
  functor-from-dim-sys-to-snippet-sys-sys?
  make-functor-from-dim-sys-to-snippet-sys-sys-impl-from-apply
  
  functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
  make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-apply
  
  ; A `snippet-format-sys?` is a wrapped functor from the `dim-sys?`
  ; category to the `snippet-sys?` category that guarantees the
  ; resulting `snippet-sys` systems and morphisms make use of the same
  ; `dym-sys` systems and functors that were given. That is, when we
  ; compose an extension's functor with the functor represented by the
  ; combination of `snippet-sys-dim-sys` and
  ; `snippet-sys-morphism-sys-dim-sys-morphism-sys`, we get an
  ; identity functor.
  ;
  ; We've already mentioned this in the docs, but we mention it again
  ; here as a reminder.
  ;
  snippet-format-sys?
  snippet-format-sys-impl?
  snippet-format-sys-functor
  prop:snippet-format-sys
  make-snippet-format-sys-impl-from-functor
  
  snippet-format-sys-morphism-sys?
  snippet-format-sys-morphism-sys-impl?
  snippet-format-sys-morphism-sys-source
  snippet-format-sys-morphism-sys-replace-source
  snippet-format-sys-morphism-sys-target
  snippet-format-sys-morphism-sys-replace-target
  snippet-format-sys-morphism-sys-functor-morphism
  snippet-format-sys-morphism-sys/c
  prop:snippet-format-sys-morphism-sys
  make-snippet-format-sys-morphism-sys-impl-from-morph
  snippet-format-sys-morphism-sys-identity
  snippet-format-sys-morphism-sys-chain-two)

(provide
  snippet-format-sys-category-sys)
(provide #/own-contract-out
  snippet-format-sys-category-sys?)

(provide #/own-contract-out
  snippet-format-sys-endofunctor-sys?
  make-snippet-format-sys-endofunctor-sys-impl-from-apply)

(module+ private/hypertee #/provide
  hypertee-coil-zero)
(module+ private/hypertee #/provide #/own-contract-out
  hypertee-coil-zero?)
(module+ private/hypertee #/provide
  hypertee-coil-hole)
(module+ private/hypertee #/provide #/own-contract-out
  hypertee-coil-hole?
  hypertee-coil-hole-overall-degree
  hypertee-coil-hole-hole
  hypertee-coil-hole-data
  hypertee-coil-hole-tails)
(module+ private/hypertee #/provide #/own-contract-out
  hypertee-coil/c)
(module+ private/hypertee #/provide
  hypertee-furl)
(module+ private/hypertee #/provide #/own-contract-out
  hypertee?
  hypertee-get-dim-sys
  hypertee-get-coil
  hypertee/c)
(module+ private/hypertee #/provide
  hypertee-snippet-sys)
(module+ private/hypertee #/provide #/own-contract-out
  hypertee-snippet-sys?
  hypertee-snippet-sys-dim-sys)
(module+ private/hypertee #/provide
  hypertee-snippet-format-sys)
(module+ private/hypertee #/provide #/own-contract-out
  hypertee-snippet-format-sys?
  hypertee-get-hole-zero-maybe)

(module+ private/hypertee #/provide
  htb-labeled)
(module+ private/hypertee #/provide #/own-contract-out
  htb-labeled?
  htb-labeled-degree
  htb-labeled-data)
(module+ private/hypertee #/provide
  htb-unlabeled)
(module+ private/hypertee #/provide #/own-contract-out
  htb-unlabeled?
  htb-unlabeled-degree)
(module+ private/hypertee #/provide #/own-contract-out
  hypertee-bracket?
  hypertee-bracket/c
  ; TODO: Uncomment this export if we ever need it.
;  hypertee-bracket-degree
  hypertee-from-brackets
  ht-bracs
  hypertee-get-brackets)

(module+ private/hypernest #/provide #/own-contract-out
  hypernest?
  hypernest/c
  hypernestof/ob-c
  hypernest-get-dim-sys)
(module+ private/hypernest #/provide
  hypernest-snippet-sys)
(module+ private/hypernest #/provide #/own-contract-out
  hypernest-snippet-sys?
  hypernest-snippet-sys-snippet-format-sys
  hypernest-snippet-sys-dim-sys)
(module+ private/hypernest #/provide
  hypernest-snippet-format-sys)
(module+ private/hypernest #/provide #/own-contract-out
  hypernest-snippet-format-sys?
  hypernest-snippet-format-sys-original)
(module+ private/hypernest #/provide #/own-contract-out
  hypernest-shape
  hypernest-get-hole-zero-maybe
  hypernest-join-list-and-tail-along-0)

(module+ private/hypernest #/provide
  hypernest-coil-zero)
(module+ private/hypernest #/provide #/own-contract-out
  hypernest-coil-zero?)
(module+ private/hypernest #/provide
  hypernest-coil-hole)
(module+ private/hypernest #/provide #/own-contract-out
  hypernest-coil-hole?
  hypernest-coil-hole-overall-degree
  hypernest-coil-hole-hole
  hypernest-coil-hole-data
  hypernest-coil-hole-tails-hypertee)
(module+ private/hypernest #/provide
  hypernest-coil-bump)
(module+ private/hypernest #/provide #/own-contract-out
  hypernest-coil-bump?
  hypernest-coil-bump-overall-degree
  hypernest-coil-bump-data
  hypernest-coil-bump-bump-degree
  hypernest-coil-bump-tails-hypernest)
(module+ private/hypernest #/provide #/own-contract-out
  hypernest-coil/c)
(module+ private/hypernest #/provide
  hypernest-furl)
(module+ private/hypernest #/provide #/own-contract-out
  hypernest-get-coil)

(module+ private/hypernest #/provide
  hnb-open)
(module+ private/hypernest #/provide #/own-contract-out
  hnb-open?
  hnb-open-degree
  hnb-open-data)
(module+ private/hypernest #/provide
  hnb-labeled)
(module+ private/hypernest #/provide #/own-contract-out
  hnb-labeled?
  hnb-labeled-degree
  hnb-labeled-data)
(module+ private/hypernest #/provide
  hnb-unlabeled)
(module+ private/hypernest #/provide #/own-contract-out
  hnb-unlabeled?
  hnb-unlabeled-degree)
(module+ private/hypernest #/provide #/own-contract-out
  hypernest-bracket?
  hypernest-bracket/c
  ; TODO: Uncomment this export if we ever need it.
;  hypernest-bracket-degree
  hypertee-bracket->hypernest-bracket
  compatible-hypernest-bracket->hypertee-bracket
  hypernest-from-brackets
  hn-bracs
  hypernest-get-brackets)

(module+ private/test #/provide
  snippet-sys-snippet-filter-maybe)



; TODO: See if we'll use this.
; TODO: See if we should export this from Lathe Comforts. It may just
; be an implementation detail of `obstinacy-late-contract-projector`.
(define
  (obstinacy-project-late ob project-v-and-late-party v late-party)
  (w- next-v (project-v-and-late-party v late-party)
  #/mat ob (impersonator-obstinacy) next-v
  #/mat ob (chaperone-obstinacy) next-v
  #/dissect ob (flat-obstinacy) v))

; TODO: See if we'll use this.
; TODO: See if we should export this from Lathe Comforts. It doesn't
; seem as universally useful as `obstinacy-project-late`, since
; usually the contract `c` is known before `missing-party` is.
(define
  (obstinacy-late-contract-projector ob coerce blame missing-party)
  (fn c v context
    (w- c-proj
      (
        (get/build-late-neg-projection #/coerce c)
        (blame-add-context blame context))
    #/obstinacy-project-late ob c-proj v missing-party)))


(define-imitation-simple-struct
  (unselected? unselected-value)
  unselected
  'unselected (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract unselected? (-> any/c boolean?))
(ascribe-own-contract unselected-value (-> unselected? any/c))

(define-imitation-simple-struct
  (selected? selected-value)
  selected
  'selected (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract selected? (-> any/c boolean?))
(ascribe-own-contract selected-value (-> selected? any/c))

(define/own-contract (selectable? v)
  (-> any/c boolean?)
  (or (unselected? v) (selected? v)))

(define/own-contract (selectable/c unselected/c selected/c)
  (-> contract? contract? contract?)
  (w- unselected/c (coerce-contract 'selectable/c unselected/c)
  #/w- selected/c (coerce-contract 'selectable/c selected/c)
  #/rename-contract
    (or/c
      (match/c unselected unselected/c)
      (match/c selected selected/c))
    `(selectable/c
       ,(contract-name unselected/c)
       ,(contract-name selected/c))))

(define/own-contract (selectable-map s v-to-v)
  (-> selectable? (-> any/c any/c) selectable?)
  (mat s (unselected v) (unselected v)
  #/dissect s (selected v) (selected #/v-to-v v)))


(define-imitation-simple-generics snippet-sys? snippet-sys-impl?
  (#:method snippet-sys-snippet/c (#:this))
  (#:method snippet-sys-dim-sys (#:this))
  (#:method snippet-sys-shape-snippet-sys (#:this))
  (#:method unguarded-snippet-sys-snippet-degree (#:this) ())
  (#:method snippet-sys-shape->snippet (#:this) ())
  (#:method snippet-sys-snippet->maybe-shape (#:this) ())
  (#:method snippet-sys-snippet-set-degree-maybe (#:this) () ())
  (#:method unguarded-snippet-sys-snippet-done (#:this) () () ())
  (#:method snippet-sys-snippet-undone (#:this) ())
  (#:method unguarded-snippet-sys-snippet-splice (#:this) () ())
  (#:method snippet-sys-snippet-zip-map-selective (#:this) () () ())
  prop:snippet-sys make-snippet-sys-impl-from-various-1
  'snippet-sys 'snippet-sys-impl (list))
(ascribe-own-contract snippet-sys? (-> any/c boolean?))
(ascribe-own-contract snippet-sys-impl? (-> any/c boolean?))
(ascribe-own-contract snippet-sys-snippet/c
  (-> snippet-sys? flat-contract?))
(ascribe-own-contract snippet-sys-dim-sys (-> snippet-sys? dim-sys?))
(ascribe-own-contract snippet-sys-shape-snippet-sys
  (-> snippet-sys? snippet-sys?))
; TODO DEBUGGABILITY: Provide a contract-protected version like this
; commented-out ascription instead. See the note on the
; `snippet-sys-snippet-degree` macro export.
#;
(ascribe-own-contract snippet-sys-snippet-degree
  (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
    [_ (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]))
(ascribe-own-contract snippet-sys-shape->snippet
  (->i
    (
      [ss snippet-sys?]
      [shape (ss)
        (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)])
    [_ (ss shape)
      (snippet-sys-snippet-with-degree=/c ss
        (snippet-sys-snippet-degree
          (snippet-sys-shape-snippet-sys ss)
          shape))]))
(ascribe-own-contract snippet-sys-snippet->maybe-shape
  ; TODO SPECIFIC: See if the result contract should be more specific.
  ; The result should always be of the same degree as the input.
  (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
    [_ (ss snippet)
      (maybe/c
        (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss))]))
(ascribe-own-contract snippet-sys-snippet-set-degree-maybe
  ; TODO SPECIFIC: See if the result contract should be more specific.
  ; The result should always exist if the snippet already has the
  ; given degree, and it should always exist if the given degree is
  ; greater than that degree and that degree is nonzero.
  (->i
    (
      [ss snippet-sys?]
      [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
      [snippet (ss) (snippet-sys-snippet/c ss)])
    [_ (ss degree)
      (maybe/c #/snippet-sys-snippet-with-degree=/c ss degree)]))
; TODO DEBUGGABILITY: Provide a contract-protected version like this
; commented-out ascription instead. See the note on the
; `snippet-sys-snippet-degree` macro export.
#;
(ascribe-own-contract snippet-sys-snippet-done
  (->i
    (
      [ss snippet-sys?]
      [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
      [shape (ss degree)
        (snippet-sys-snippet-with-degree</c
          (snippet-sys-shape-snippet-sys ss)
          degree)]
      [data any/c])
    [_ (ss degree) (snippet-sys-snippet-with-degree=/c ss degree)]))
(ascribe-own-contract snippet-sys-snippet-undone
  (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
    [_ (ss snippet)
      (maybe/c #/list/c
        (dim-sys-dim/c #/snippet-sys-dim-sys ss)
        (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)
        any/c)]))
; TODO DEBUGGABILITY: Provide a contract-protected version like this
; commented-out ascription instead. See the note on the
; `snippet-sys-snippet-degree` macro export.
#;
(ascribe-own-contract snippet-sys-snippet-splice
  (->i
    (
      [ss snippet-sys?]
      [snippet (ss) (snippet-sys-snippet/c ss)]
      [hv-to-splice (ss snippet)
        (w- has-d/c
          (snippet-sys-snippet-with-degree=/c ss
            (snippet-sys-snippet-degree ss snippet))
        #/->i
          (
            [prefix-hole (snippet-sys-unlabeled-shape/c ss)]
            [data any/c])
          [_ (prefix-hole)
            (maybe/c #/selectable/c any/c #/and/c
              has-d/c
              (snippet-sys-snippet-fitting-shape/c ss
                prefix-hole))])])
    [_ (ss snippet)
      (maybe/c
        (snippet-sys-snippet-with-degree=/c ss
          (snippet-sys-snippet-degree ss snippet)))]))
(ascribe-own-contract snippet-sys-snippet-zip-map-selective
  (->i
    (
      [ss snippet-sys?]
      [shape (ss)
        (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)]
      [snippet (ss)
        (snippet-sys-snippetof/ob-c ss (flat-obstinacy) #/fn hole
          selectable?)]
      [hvv-to-maybe-v (ss)
        (-> (snippet-sys-unlabeled-shape/c ss) any/c any/c maybe?)])
    [_ (ss snippet)
      (maybe/c
        (snippet-sys-snippet-with-degree=/c ss
          (snippet-sys-snippet-degree ss snippet)))]))
(ascribe-own-contract prop:snippet-sys
  (struct-type-property/c snippet-sys-impl?))
(ascribe-own-contract make-snippet-sys-impl-from-various-1
  (->
    ; snippet-sys-snippet/c
    (-> snippet-sys? flat-contract?)
    ; snippet-sys-dim-sys
    (-> snippet-sys? dim-sys?)
    ; snippet-sys-shape-snippet-sys
    (-> snippet-sys? snippet-sys?)
    ; snippet-sys-snippet-degree
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)])
    ; snippet-sys-shape->snippet
    (->i
      (
        [ss snippet-sys?]
        [shape (ss)
          (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)])
      [_ (ss shape)
        (snippet-sys-snippet-with-degree=/c ss
        #/snippet-sys-snippet-degree
          (snippet-sys-shape-snippet-sys ss)
          shape)])
    ; snippet-sys-snippet->maybe-shape
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss snippet)
        (maybe/c
          (snippet-sys-snippet/c
            (snippet-sys-shape-snippet-sys ss)))])
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
      [_ (ss degree) (snippet-sys-snippet-with-degree=/c ss degree)])
    ; snippet-sys-snippet-undone
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss snippet)
        (maybe/c #/list/c
          (dim-sys-dim/c #/snippet-sys-dim-sys ss)
          (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)
          any/c)])
    ; snippet-sys-snippet-splice
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss) (snippet-sys-snippet/c ss)]
        [hv-to-splice (ss snippet)
          (w- has-d/c
            (snippet-sys-snippet-with-degree=/c ss
              (snippet-sys-snippet-degree ss snippet))
          #/->i
            (
              [prefix-hole (snippet-sys-unlabeled-shape/c ss)]
              [data any/c])
            [_ (prefix-hole)
              (maybe/c #/selectable/c any/c #/and/c
                has-d/c
                (snippet-sys-snippet-fitting-shape/c ss
                  prefix-hole))])])
      [_ (ss snippet)
        (maybe/c
          (snippet-sys-snippet-with-degree=/c ss
            (snippet-sys-snippet-degree ss snippet)))])
    ; snippet-sys-snippet-zip-map-selective
    (->i
      (
        [ss snippet-sys?]
        [shape (ss)
          (snippet-sys-snippet/c
            (snippet-sys-shape-snippet-sys ss))]
        [snippet (ss)
          (snippet-sys-snippetof/ob-c ss (flat-obstinacy) #/fn hole
            selectable?)]
        [hvv-to-maybe-v (ss)
          (-> (snippet-sys-unlabeled-shape/c ss) any/c any/c maybe?)])
      [_ (ss snippet)
        (maybe/c
          (snippet-sys-snippet-with-degree=/c ss
          #/snippet-sys-snippet-degree ss snippet))])
    snippet-sys-impl?))

; NOTE DEBUGGABILITY: This is here for debugging. If not for
; debugging, we would rename `unguarded-snippet-sys-snippet-degree` to
; be `snippet-sys-snippet-degree`.
(define/own-contract
  (attenuated-fn-snippet-sys-snippet-degree ss snippet)
  (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
    [_ (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)])
  (unguarded-snippet-sys-snippet-degree ss snippet))
(define-syntax (snippet-sys-snippet-degree stx)
  (syntax-case stx () #/ (_ ss snippet)
    #`(dlog 'm1 #,(~a stx)
        (attenuated-fn-snippet-sys-snippet-degree ss snippet))))

; NOTE DEBUGGABILITY: This is here for debugging. If not for
; debugging, we would rename `unguarded-snippet-sys-snippet-done` to
; be `snippet-sys-snippet-done`.
(define/own-contract
  (attenuated-fn-snippet-sys-snippet-done ss degree shape data)
  (->i
    (
      [ss snippet-sys?]
      [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
      [shape (ss degree)
        (snippet-sys-snippet-with-degree</c
          (snippet-sys-shape-snippet-sys ss)
          degree)]
      [data any/c])
    [_ (ss degree) (snippet-sys-snippet-with-degree=/c ss degree)])
  (unguarded-snippet-sys-snippet-done ss degree shape data))
(define-syntax (snippet-sys-snippet-done stx)
  (syntax-case stx () #/ (_ ss degree shape data)
    #`(dlog 'm3 #,(~a stx)
        (attenuated-fn-snippet-sys-snippet-done
          ss degree shape data))))

; NOTE DEBUGGABILITY: This is here for debugging.
(define/own-contract
  (attenuated-snippet-sys-snippet-undone ss snippet)
  (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
    [_ (ss snippet)
      (maybe/c #/list/c
        (dim-sys-dim/c #/snippet-sys-dim-sys ss)
        (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)
        any/c)])
  (snippet-sys-snippet-undone ss snippet))

; NOTE DEBUGGABILITY: This is here for debugging. If not for
; debugging, we would rename `unguarded-snippet-sys-snippet-splice` to
; be `snippet-sys-snippet-splice`.
(define/contract
  (attenuated-fn-snippet-sys-snippet-splice ss snippet hv-to-splice)
  (ifc debugging-with-expensive-splice-contract
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss) (snippet-sys-snippet/c ss)]
        [hv-to-splice (ss snippet)
          (w- has-d/c
            (snippet-sys-snippet-with-degree=/c ss
              (snippet-sys-snippet-degree ss snippet))
          #/->i
            (
              [prefix-hole (snippet-sys-unlabeled-shape/c ss)]
              [data any/c])
            [_ (prefix-hole)
              (maybe/c #/selectable/c any/c #/and/c
                has-d/c
                (snippet-sys-snippet-fitting-shape/c ss
                  prefix-hole))])])
      [_ (ss snippet)
        (maybe/c
          (snippet-sys-snippet-with-degree=/c ss
            (snippet-sys-snippet-degree ss snippet)))])
    any/c)
  (unguarded-snippet-sys-snippet-splice ss snippet hv-to-splice))
(define-syntax (snippet-sys-snippet-splice stx)
  (syntax-case stx () #/ (_ ss snippet hv-to-splice)
    #`(dlog 'm4 #,(~a stx)
        (attenuated-fn-snippet-sys-snippet-splice
          ss snippet hv-to-splice))))

; TODO: See if we should have a way to implement this that doesn't
; involve constructing another snippet along the way, since we just
; end up ignoring it.
(define/own-contract (snippet-sys-snippet-all? ss snippet check-hv?)
  (->i
    (
      [ss snippet-sys?]
      [snippet (ss) (snippet-sys-snippet/c ss)]
      [check-hv? (ss)
        (-> (snippet-sys-unlabeled-shape/c ss) any/c boolean?)])
    [_ boolean?])
  (dlog 'zn1 check-hv?
  #/just? #/snippet-sys-snippet-splice ss snippet #/fn hole data
    (dlog 'zn2
    #/if (check-hv? hole data)
      (just #/unselected data)
      (nothing))))

; TODO: Use the things that use this.
(define/own-contract (snippet-sys-snippet-any? ss snippet check-hv?)
  (->i
    (
      [ss snippet-sys?]
      [snippet (ss) (snippet-sys-snippet/c ss)]
      [check-hv? (ss)
        (-> (snippet-sys-unlabeled-shape/c ss) any/c boolean?)])
    [_ boolean?])
  (not #/snippet-sys-snippet-all? ss snippet #/fn hole data
    (not #/check-hv? hole data)))

; TODO: Use the things that use this.
(define/own-contract (snippet-sys-snippet-each ss snippet visit-hv)
  (->i
    (
      [ss snippet-sys?]
      [snippet (ss) (snippet-sys-snippet/c ss)]
      [visit-hv (ss)
        (-> (snippet-sys-unlabeled-shape/c ss) any/c any)])
    [_ void?])
  (begin
    (snippet-sys-snippet-all? ss snippet #/fn hole data
      (begin (visit-hv hole data)
        #t))
  #/void))

(define/own-contract
  (snippet-sys-snippet-map-maybe ss snippet hv-to-maybe-v)
  (->i
    (
      [ss snippet-sys?]
      [snippet (ss) (snippet-sys-snippet/c ss)]
      [hv-to-maybe-v (ss)
        (-> (snippet-sys-unlabeled-shape/c ss) any/c maybe?)])
    [_ (ss snippet)
      (maybe/c
        (snippet-sys-snippet-with-degree=/c ss
          (snippet-sys-snippet-degree ss snippet)))])
  (snippet-sys-snippet-splice ss snippet #/fn hole data
    (dlog 'o1 hv-to-maybe-v
    #/maybe-map (hv-to-maybe-v hole data) #/fn data
      (unselected data))))

; NOTE DEBUGGABILITY: This is a `define/contract` for debugging.
(define snippet-sys-snippet-map/explicit-sig-c
  (->i
    (
      [ss snippet-sys?]
      [snippet (ss) (snippet-sys-snippet/c ss)]
      [hv-to-v (ss)
        (-> (snippet-sys-unlabeled-shape/c ss) any/c any/c)])
    [_ (ss snippet)
      (snippet-sys-snippet-with-degree=/c ss
        (snippet-sys-snippet-degree ss snippet))]))
(define/contract (snippet-sys-snippet-map ss snippet hv-to-v)
  (ifc debugging-with-expensive-map-contract
    snippet-sys-snippet-map/explicit-sig-c
    any/c)
  (dlog 'd1
  #/just-value
  #/snippet-sys-snippet-map-maybe ss snippet #/fn hole data
    (dlog 'd1.1 hv-to-v
    #/just #/hv-to-v hole data)))
(ascribe-own-contract snippet-sys-snippet-map
  snippet-sys-snippet-map/explicit-sig-c)

(define/own-contract (snippet-sys-snippet-select ss snippet check-hv?)
  (->i
    (
      [ss snippet-sys?]
      [snippet (ss) (snippet-sys-snippet/c ss)]
      [check-hv? (ss)
        (-> (snippet-sys-unlabeled-shape/c ss) any/c boolean?)])
    [_ (ss snippet)
      (and/c
        (snippet-sys-snippet-with-degree=/c ss
          (snippet-sys-snippet-degree ss snippet))
        (snippet-sys-snippetof/ob-c ss (flat-obstinacy) #/fn hole
          selectable?))])
  (snippet-sys-snippet-map ss snippet #/fn hole data
    (if (check-hv? hole data)
      (selected data)
      (unselected data))))

(define/own-contract (snippet-sys-snippet-select-everything ss snippet)
  (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
    [_ (ss snippet)
      (and/c
        (snippet-sys-snippet-with-degree=/c ss
          (snippet-sys-snippet-degree ss snippet))
        (snippet-sys-snippetof/ob-c ss (flat-obstinacy) #/fn hole
          selected?))])
  (snippet-sys-snippet-select ss snippet #/fn hole data #t))

; TODO: See if this should have the question mark in its name.
;
; TODO: Export this.
;
; TODO: See if the places that call this should also specify a
; condition to check for the unselected holes. Currently, we just
; accept the unselected holes regardless of what they contain.
;
(define
  (snippet-sys-snippet-zip-all-selective? ss shape snippet check-hvv?)
  (w- snippet
    (snippet-sys-snippet-map ss snippet #/fn hole data
      (mat data (selected data) (selected data)
      #/dissect data (unselected data)
        (unselected #/unselected data)))
  #/expect
    (snippet-sys-snippet-zip-map-selective ss shape snippet
    #/fn hole shape-data snippet-data
      (just #/selected #/list shape-data snippet-data))
    (just zipped)
    #f
  #/snippet-sys-snippet-all? ss zipped #/fn hole data
    (mat data (unselected data) #t
    #/dissect data (selected #/list shape-data snippet-data)
    #/check-hvv? hole shape-data snippet-data)))

(define/own-contract (snippet-sys-snippet-with-degree/c ss degree/c)
  (-> snippet-sys? flat-contract? flat-contract?)
  (w- degree/c
    (coerce-contract 'snippet-sys-snippet-with-degree/c degree/c)
  #/w- name
    `(snippet-sys-snippet-with-degree/c ,ss ,(contract-name degree/c))
  #/w- snippet-contract (snippet-sys-snippet/c ss)
  #/make-flat-contract
    
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
        (begin
          (snippet-contract-projection v missing-party)
          (degree/c-projection (snippet-sys-snippet-degree ss v)
            missing-party)
          v)))))

(define/own-contract (snippet-sys-snippet-with-degree</c ss degree)
  (->i
    (
      [ss snippet-sys?]
      [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)])
    [_ flat-contract?])
  (rename-contract
    (snippet-sys-snippet-with-degree/c ss
      (dim-sys-dim</c (snippet-sys-dim-sys ss) degree))
    `(snippet-sys-snippet-with-degree</c ,ss ,degree)))

(define/own-contract (snippet-sys-snippet-with-degree=/c ss degree)
  (->i
    (
      [ss snippet-sys?]
      [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)])
    [_ flat-contract?])
  (rename-contract
    (snippet-sys-snippet-with-degree/c ss
      (dim-sys-dim=/c (snippet-sys-dim-sys ss) degree))
    `(snippet-sys-snippet-with-degree=/c ,ss ,degree)))

(define/own-contract (snippet-sys-snippet-with-0<degree/c ss)
  (-> snippet-sys? flat-contract?)
  (rename-contract
    (snippet-sys-snippet-with-degree/c ss
      (dim-sys-0<dim/c #/snippet-sys-dim-sys ss))
    `(snippet-sys-snippet-with-0<degree/c ,ss)))

(define/own-contract (snippet-sys-snippetof/ob-c ss ob h-to-value/c)
  (->i
    (
      [ss snippet-sys?]
      [ob obstinacy?]
      [h-to-value/c (ss ob)
        ; NOTE: Via the definition of `snippet-sys-unlabeled-shape/c`,
        ; `snippet-sys-snippetof/ob-c` basically appears in its own
        ; contract.
        (-> (snippet-sys-unlabeled-shape/c ss)
          (obstinacy-contract/c ob))])
    [_ (ob) (obstinacy-contract/c ob)])
  (w- name `(snippet-sys-snippetof/ob-c ,ss ,ob ,h-to-value/c)
  #/w- coerce
    (obstinacy-get-coerce-contract-for-id ob
      'snippet-sys-snippetof/ob-c)
  #/w- snippet-contract (snippet-sys-snippet/c ss)
  #/w- first-order
    (fn v
      (and ((flat-contract-predicate snippet-contract) v)
      #/snippet-sys-snippet-all? ss v #/fn hole data
        (w- value/c (coerce #/h-to-value/c hole)
        #/contract-first-order-passes? value/c data)))
  #/ (obstinacy-get-make-contract ob)
    
    #:name name
    
    #:first-order first-order
    
    #:late-neg-projection
    (fn blame
      (w- snippet-contract-projection
        (
          (get/build-late-neg-projection snippet-contract)
          (blame-add-context blame "the initial snippet check of"))
      #/fn v missing-party
        (begin (snippet-contract-projection v missing-party)
        #/w- process-hole
          (fn hole data
            (w- value/c (coerce #/h-to-value/c hole)
            #/
              (
                (get/build-late-neg-projection value/c)
                (blame-add-context blame "a hole value of"))
              data
              missing-party))
        #/mat ob (flat-obstinacy)
          (begin (snippet-sys-snippet-each ss v process-hole)
            v)
          (snippet-sys-snippet-map ss v process-hole))))))

(define/own-contract (snippet-sys-unlabeled-snippet/c ss)
  (-> snippet-sys? flat-contract?)
  (rename-contract
    (snippet-sys-snippetof/ob-c ss (flat-obstinacy) #/fn hole
      trivial?)
    `(snippet-sys-unlabeled-snippet/c ,ss)))

(define/own-contract (snippet-sys-unlabeled-shape/c ss)
  (-> snippet-sys? flat-contract?)
  (rename-contract
    (snippet-sys-unlabeled-snippet/c
      (snippet-sys-shape-snippet-sys ss))
    `(snippet-sys-unlabeled-shape/c ,ss)))

(define/own-contract
  (snippet-sys-snippet-zip-selective/ob-c
    ss ob shape check-subject-hv? hvv-to-subject-v/c)
  (->i
    (
      [ss snippet-sys?]
      [ob obstinacy?]
      [shape (ss)
        (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)]
      [check-subject-hv? (ss)
        (-> (snippet-sys-unlabeled-shape/c ss) any/c boolean?)]
      [hvv-to-subject-v/c (ss ob)
        (-> (snippet-sys-unlabeled-shape/c ss) any/c any/c
          (obstinacy-contract/c ob))])
    [_ (ob) (obstinacy-contract/c ob)])
  (w- name
    `(snippet-sys-snippet-zip-selective/ob-c
      ,ss ,ob ,shape ,check-subject-hv? ,hvv-to-subject-v/c)
  #/w- coerce
    (obstinacy-get-coerce-contract-for-id ob
      'snippet-sys-snippet-zip-selective/ob-c)
  #/w- snippet-contract (snippet-sys-snippet/c ss)
  #/w- first-order
    (fn v
      (dlogr 'zg1
      #/and (contract-first-order-passes? snippet-contract v)
      #/snippet-sys-snippet-zip-all-selective? ss shape
        (snippet-sys-snippet-select ss v #/fn hole data
          (check-subject-hv? hole data))
      #/fn hole shape-data subject-data
        (w- value/c
          (coerce #/hvv-to-subject-v/c hole shape-data subject-data)
        #/contract-first-order-passes? value/c subject-data)))
  #/ (obstinacy-get-make-contract ob)
    
    #:name name
    
    #:first-order first-order
    
    #:late-neg-projection
    (fn blame
      (w- snippet-contract-projection
        (
          (get/build-late-neg-projection snippet-contract)
          (blame-add-context blame "the initial snippet check of"))
      #/fn v missing-party
        (dlog 'zg2 check-subject-hv?
        #/dlog 'zg2.1 shape
        #/dlog 'zg2.2 v
        #/begin (snippet-contract-projection v missing-party)
        #/expect
          (snippet-sys-snippet-zip-map-selective ss shape
            (snippet-sys-snippet-select ss v #/fn hole data
              (check-subject-hv? hole data))
          #/fn hole shape-data subject-data
            (w- value/c
              (coerce
                (hvv-to-subject-v/c hole shape-data subject-data))
            #/just #/
              (
                (get/build-late-neg-projection value/c)
                (blame-add-context blame "a hole value of"))
              subject-data
              missing-party))
          (just result)
          (dlog 'zg3
          #/raise-blame-error blame #:missing-party missing-party v
            '(expected: "~e" given: "~e")
            name v)
        #/mat ob (flat-obstinacy)
          v
          result)))))

(define/own-contract (snippet-sys-snippet-fitting-shape/c ss shape)
  (->i
    (
      [ss snippet-sys?]
      [shape (ss) (snippet-sys-unlabeled-shape/c ss)])
    [_ flat-contract?])
  (w- ds (snippet-sys-dim-sys ss)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/w- shape-d (snippet-sys-snippet-degree shape-ss shape)
  #/rename-contract
    ; What this means is that this should be a snippet whose
    ; low-degree holes correspond to the holes of `shape` and contain
    ; `trivial?` values.
    (snippet-sys-snippet-zip-selective/ob-c ss (flat-obstinacy) shape
      (fn hole subject-data
        (w- hole-d (snippet-sys-snippet-degree shape-ss hole)
        #/dim-sys-dim<? ds hole-d shape-d))
      (fn hole shape-data subject-data trivial?))
    `(snippet-sys-snippet-fitting-shape/c ,ss ,shape)))


; TODO: Use the things that use this.
(define/own-contract
  (snippet-sys-snippet-select-if-degree ss snippet check-degree?)
  (->i
    (
      [ss snippet-sys?]
      [snippet (ss) (snippet-sys-snippet/c ss)]
      [check-degree? (ss)
        (-> (dim-sys-dim/c #/snippet-sys-dim-sys ss) boolean?)])
    [_ (ss snippet)
      (and/c
        (snippet-sys-snippet-with-degree=/c ss
          (snippet-sys-snippet-degree ss snippet))
        (snippet-sys-snippetof/ob-c ss (flat-obstinacy) #/fn hole
          selectable?))])
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/snippet-sys-snippet-select ss snippet #/fn hole data
    (check-degree? #/snippet-sys-snippet-degree shape-ss hole)))

; TODO: Use the things that use this.
(define/own-contract
  (snippet-sys-snippet-select-if-degree< ss degree snippet)
  (->i
    (
      [ss snippet-sys?]
      [degreee (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
      [snippet (ss) (snippet-sys-snippet/c ss)])
    [_ (ss snippet)
      (and/c
        (snippet-sys-snippet-with-degree=/c ss
          (snippet-sys-snippet-degree ss snippet))
        (snippet-sys-snippetof/ob-c ss (flat-obstinacy) #/fn hole
          selectable?))])
  (w- ds (snippet-sys-dim-sys ss)
  #/snippet-sys-snippet-select-if-degree ss snippet #/fn actual-degree
    (dim-sys-dim<? ds actual-degree degree)))

; TODO: Use the things that use this.
(define/own-contract
  (snippet-sys-snippet-bind-selective ss prefix hv-to-suffix)
  (->i
    (
      [ss snippet-sys?]
      [prefix (ss) (snippet-sys-snippet/c ss)]
      [hv-to-suffix (ss prefix)
        (w- has-d/c
          (snippet-sys-snippet-with-degree=/c ss
            (snippet-sys-snippet-degree ss prefix))
        #/->i
          (
            [prefix-hole (snippet-sys-unlabeled-shape/c ss)]
            [data any/c])
          [_ (prefix-hole)
            (selectable/c any/c #/and/c
              has-d/c
              (snippet-sys-snippet-fitting-shape/c ss
                prefix-hole))])])
    [_ (ss prefix)
      (snippet-sys-snippet-with-degree=/c ss
        (snippet-sys-snippet-degree ss prefix))])
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/dlog 'd2 prefix
  #/just-value #/dlog 'd2.1 #/snippet-sys-snippet-splice ss prefix #/fn hole data
    (just #/hv-to-suffix hole data)))

; TODO: Use this.
(define/own-contract (snippet-sys-snippet-join-selective ss snippet)
  (->i
    (
      [ss snippet-sys?]
      [snippet (ss)
        (and/c (snippet-sys-snippet/c ss)
        #/by-own-method/c #:obstinacy (flat-obstinacy) snippet
        #/w- has-d/c
          (snippet-sys-snippet-with-degree=/c ss
            (snippet-sys-snippet-degree ss snippet))
        #/snippet-sys-snippetof/ob-c ss (flat-obstinacy)
          (fn prefix-hole
            (selectable/c any/c #/and/c
              has-d/c
              (snippet-sys-snippet-fitting-shape/c
                ss prefix-hole))))])
    [_ (ss snippet)
      (snippet-sys-snippet-with-degree=/c ss
        (snippet-sys-snippet-degree ss snippet))])
  (snippet-sys-snippet-bind-selective ss snippet #/fn hole data data))

; TODO: Use the things that use this.
(define/own-contract (snippet-sys-snippet-bind ss prefix hv-to-suffix)
  (->i
    (
      [ss snippet-sys?]
      [prefix (ss) (snippet-sys-snippet/c ss)]
      [hv-to-suffix (ss prefix)
        (w- has-d/c
          (snippet-sys-snippet-with-degree=/c ss
            (snippet-sys-snippet-degree ss prefix))
        #/->i
          (
            [prefix-hole (snippet-sys-unlabeled-shape/c ss)]
            [data any/c])
          [_ (prefix-hole)
            (and/c
              has-d/c
              (snippet-sys-snippet-fitting-shape/c ss
                prefix-hole))])])
    [_ (ss prefix)
      (snippet-sys-snippet-with-degree=/c ss
        (snippet-sys-snippet-degree ss prefix))])
  (snippet-sys-snippet-bind-selective ss prefix #/fn hole data
    (selected #/hv-to-suffix hole data)))

; TODO: Use this.
(define/own-contract (snippet-sys-snippet-join ss snippet)
  (->i
    (
      [ss snippet-sys?]
      [snippet (ss)
        (and/c (snippet-sys-snippet/c ss)
        #/by-own-method/c #:obstinacy (flat-obstinacy) snippet
        #/w- has-d/c
          (snippet-sys-snippet-with-degree=/c ss
            (snippet-sys-snippet-degree ss snippet))
        #/snippet-sys-snippetof/ob-c ss (flat-obstinacy)
          (fn prefix-hole
            (and/c
              has-d/c
              (snippet-sys-snippet-fitting-shape/c
                ss prefix-hole))))])
    [_ (ss snippet)
      (snippet-sys-snippet-with-degree=/c ss
        (snippet-sys-snippet-degree ss snippet))])
  (snippet-sys-snippet-bind ss snippet #/fn hole data data))


; TODO: Consider exporting this.
(define
  (snippet-sys-snippet-join-list-and-tail-along-0
    sfs uds snippet-cons snippet-null past-snippets last-snippet)
  (w- eds (extended-with-top-dim-sys #/extended-with-top-dim-sys uds)
  #/w- ffdstsss (snippet-format-sys-functor sfs)
  #/w- uss (functor-sys-apply-to-object ffdstsss uds)
  #/w- ess (functor-sys-apply-to-object ffdstsss eds)
  #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
  #/w- extend
    (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
      (dim-sys-morphism-sys-chain-two
        (extend-with-top-dim-sys-morphism-sys uds)
        (extend-with-top-dim-sys-morphism-sys
          (extended-with-top-dim-sys uds))))
  #/w- unextend
    (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
      (dim-sys-morphism-sys-chain-two
        (unextend-with-top-dim-sys-morphism-sys
          (extended-with-top-finite-dim-sys uds))
        (unextend-with-top-dim-sys-morphism-sys uds)))
  #/w- original-degree (snippet-sys-snippet-degree uss last-snippet)
  #/w- extend-one-snippet
    (fn snippet
      (dissect
        (snippet-sys-snippet-set-degree-maybe ess
          (extended-with-top-dim-infinite)
          (snippet-sys-morphism-sys-morph-snippet extend snippet))
        (just extended-snippet)
        extended-snippet))
  #/w- unextend-one-snippet
    (fn snippet
      (dissect
        (snippet-sys-snippet-set-degree-maybe ess
          (extended-with-top-dim-finite
            (extended-with-top-dim-finite original-degree))
          snippet)
        (just snippet-with-original-degree)
      #/5:dlog 'zr1
      #/snippet-sys-morphism-sys-morph-snippet unextend
        snippet-with-original-degree))
  #/w- extended-past-snippets
    (list-map past-snippets #/fn snippet #/extend-one-snippet snippet)
  #/w- extended-last-snippet (extend-one-snippet last-snippet)
  
  ; NOTE: We could simply fold over `past-snippets` and perform a
  ; series of multiple concatenations, but we anticipate that that
  ; approach could be a painter's algorithm for certain snippet
  ; systems. Instead, we fold over them to construct a simple snippet
  ; that holds them all, using some `snippet-cons` and `snippet-null`
  ; operations the caller provides, which we assume to be efficient
  ; (namely, that `snippet-cons` operates in time that doesn't depend
  ; on the size of the tail). Then we use that to
  ; `snippet-sys-snippet-join` everything in one final step.
  ;
  #/unextend-one-snippet #/snippet-sys-snippet-join ess
    (list-foldr extended-past-snippets
      (snippet-null eds (extended-with-top-dim-infinite)
        extended-last-snippet)
    #/fn snippet tail
      (snippet-cons eds
        (extended-with-top-dim-infinite)
        (extended-with-top-dim-finite
          (extended-with-top-dim-infinite))
        snippet
        tail))))


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
(ascribe-own-contract snippet-sys-morphism-sys? (-> any/c boolean?))
(ascribe-own-contract snippet-sys-morphism-sys-impl? (-> any/c boolean?))
(ascribe-own-contract snippet-sys-morphism-sys-source
  (-> snippet-sys-morphism-sys? snippet-sys?))
(ascribe-own-contract snippet-sys-morphism-sys-replace-source
  (-> snippet-sys-morphism-sys? snippet-sys?
    snippet-sys-morphism-sys?))
(ascribe-own-contract snippet-sys-morphism-sys-target
  (-> snippet-sys-morphism-sys? snippet-sys?))
(ascribe-own-contract snippet-sys-morphism-sys-replace-target
  (-> snippet-sys-morphism-sys? snippet-sys?
    snippet-sys-morphism-sys?))
(ascribe-own-contract snippet-sys-morphism-sys-dim-sys-morphism-sys
  (-> snippet-sys-morphism-sys? dim-sys-morphism-sys?))
(ascribe-own-contract snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
  (-> snippet-sys-morphism-sys? snippet-sys-morphism-sys?))
(ascribe-own-contract snippet-sys-morphism-sys-morph-snippet
  (->i
    (
      [ms snippet-sys-morphism-sys?]
      [s (ms)
        (snippet-sys-snippet/c #/snippet-sys-morphism-sys-source ms)])
    [_ (ms)
      (snippet-sys-snippet/c #/snippet-sys-morphism-sys-target ms)]))
(ascribe-own-contract prop:snippet-sys-morphism-sys
  (struct-type-property/c snippet-sys-morphism-sys-impl?))
(ascribe-own-contract make-snippet-sys-morphism-sys-impl-from-morph
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
        (snippet-sys-snippet/c #/snippet-sys-morphism-sys-target ms)])
    snippet-sys-morphism-sys-impl?))

(define/own-contract (snippet-sys-morphism-sys/c source/c target/c)
  (-> contract? contract? contract?)
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
(define/own-contract (snippet-sys-morphism-sys-identity endpoint)
  (->i ([endpoint snippet-sys?])
    [_ (endpoint)
      (snippet-sys-morphism-sys/c (ok/c endpoint) (ok/c endpoint))])
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
(define/own-contract (snippet-sys-morphism-sys-chain-two a b)
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
        (ok/c #/snippet-sys-morphism-sys-target b))])
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
(ascribe-own-contract snippet-sys-category-sys? (-> any/c boolean?))


(define/own-contract (functor-from-dim-sys-to-snippet-sys-sys? v)
  (-> any/c boolean?)
  (
    (flat-contract-predicate
      (functor-sys/c dim-sys-category-sys? snippet-sys-category-sys?))
    v))

(define/own-contract
  (make-functor-from-dim-sys-to-snippet-sys-sys-impl-from-apply
    apply-to-dim-sys
    apply-to-dim-sys-morphism-sys)
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
    functor-sys-impl?)
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


(define/own-contract
  (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys? v)
  (-> any/c boolean?)
  (
    (flat-contract-predicate
      (natural-transformation-sys/c
        dim-sys? snippet-sys? any/c any/c))
    v))

(define/own-contract
  (make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-apply
    source
    replace-source
    target
    replace-target
    apply-to-dim-sys-morphism-sys)
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
    natural-transformation-sys-impl?)
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
  snippet-format-sys?
  snippet-format-sys-impl?
  (#:method snippet-format-sys-functor (#:this))
  prop:snippet-format-sys
  make-snippet-format-sys-impl-from-functor
  'snippet-format-sys 'snippet-format-sys-impl (list))
(ascribe-own-contract snippet-format-sys? (-> any/c boolean?))
(ascribe-own-contract snippet-format-sys-impl? (-> any/c boolean?))
(ascribe-own-contract snippet-format-sys-functor
  (-> snippet-format-sys? functor-from-dim-sys-to-snippet-sys-sys?))
(ascribe-own-contract prop:snippet-format-sys
  (struct-type-property/c snippet-format-sys-impl?))
(ascribe-own-contract make-snippet-format-sys-impl-from-functor
  (->
    (-> snippet-format-sys? functor-from-dim-sys-to-snippet-sys-sys?)
    snippet-format-sys-impl?))


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
(ascribe-own-contract snippet-format-sys-morphism-sys?
  (-> any/c boolean?))
(ascribe-own-contract snippet-format-sys-morphism-sys-impl?
  (-> any/c boolean?))
(ascribe-own-contract snippet-format-sys-morphism-sys-source
  (-> snippet-format-sys-morphism-sys? snippet-format-sys?))
(ascribe-own-contract snippet-format-sys-morphism-sys-replace-source
  (-> snippet-format-sys-morphism-sys? snippet-format-sys?
    snippet-format-sys-morphism-sys?))
(ascribe-own-contract snippet-format-sys-morphism-sys-target
  (-> snippet-format-sys-morphism-sys? snippet-format-sys?))
(ascribe-own-contract snippet-format-sys-morphism-sys-replace-target
  (-> snippet-format-sys-morphism-sys? snippet-format-sys?
    snippet-format-sys-morphism-sys?))
(ascribe-own-contract snippet-format-sys-morphism-sys-functor-morphism
  (-> snippet-format-sys-morphism-sys?
    functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?))
(ascribe-own-contract prop:snippet-format-sys-morphism-sys
  (struct-type-property/c snippet-format-sys-morphism-sys-impl?))
(ascribe-own-contract
  make-snippet-format-sys-morphism-sys-impl-from-morph
  (->
    (-> snippet-format-sys-morphism-sys? snippet-format-sys?)
    (-> snippet-format-sys-morphism-sys? snippet-format-sys?
      snippet-format-sys-morphism-sys?)
    (-> snippet-format-sys-morphism-sys? snippet-format-sys?)
    (-> snippet-format-sys-morphism-sys? snippet-format-sys?
      snippet-format-sys-morphism-sys?)
    (-> snippet-format-sys-morphism-sys?
      functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?)
    snippet-format-sys-morphism-sys-impl?))

(define/own-contract
  (snippet-format-sys-morphism-sys/c source/c target/c)
  (-> contract? contract? contract?)
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
(define/own-contract
  (snippet-format-sys-morphism-sys-identity endpoint)
  (->i ([endpoint snippet-format-sys?])
    [_ (endpoint)
      (snippet-format-sys-morphism-sys/c
        (ok/c endpoint)
        (ok/c endpoint))])
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
(define/own-contract (snippet-format-sys-morphism-sys-chain-two a b)
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
        (ok/c #/snippet-format-sys-morphism-sys-target b))])
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
(ascribe-own-contract snippet-format-sys-category-sys?
  (-> any/c boolean?))


(define/own-contract (snippet-format-sys-endofunctor-sys? v)
  (-> any/c boolean?)
  (
    (flat-contract-predicate
      (functor-sys/c
        snippet-format-sys-category-sys?
        snippet-format-sys-category-sys?))
    v))

(define/own-contract
  (make-snippet-format-sys-endofunctor-sys-impl-from-apply
    apply-to-snippet-format-sys
    apply-to-snippet-format-sys-morphism-sys)
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
    functor-sys-impl?)
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


; NOTE: The original purpose of the `selective-snippet?` data
; structure was an implementation strategy for hypernests. However,
; selective snippets have a pretty critical flaw for that purpose:
; They can't have unselected holes of degree N occurring beyond the
; holes of an unselected hole of degree M for (N > M). At this point,
; we're keeping around our selective snippet implementation just
; because it demonstrates how to define a
; `snippet-format-sys-endofunctor-sys?` (in this case,
; `selective-snippet-format-sys-endofunctor-sys`). Someday we may want
; to define a `snippet-format-sys-endofunctor-sys?` for the
; "hypernest" functor that takes a snippet format system (usually the
; hypertee snippet format system) to a hypernest snippet format
; system.

(define-imitation-simple-struct
  (selective-snippet-zero? selective-snippet-zero-content)
  selective-snippet-zero
  'selective-snippet-zero (current-inspector)
  (auto-write)
  (auto-equal))

(define-imitation-simple-struct
  (selective-snippet-nonzero?
    selective-snippet-nonzero-degree
    selective-snippet-nonzero-content)
  selective-snippet-nonzero
  'selective-snippet-nonzero (current-inspector)
  (auto-write)
  (auto-equal))

; NOTE DEBUGGABILITY: This is here for debugging. Unlike the
; unattenuated version, this one has extra `sfs` and `uds` arguments.
(define/own-contract
  (attenuated-selective-snippet-nonzero sfs uds d content)
  (->i
    (
      [sfs snippet-format-sys?]
      [uds dim-sys?]
      [d (uds) (dim-sys-0<dim/c uds)]
      [content (sfs uds d)
        (w- eds (extended-with-top-dim-sys uds)
        #/w- ffdstsss (snippet-format-sys-functor sfs)
        #/w- ess (functor-sys-apply-to-object ffdstsss eds)
        #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
        #/and/c
          (snippet-sys-snippet-with-degree=/c ess
            (extended-with-top-dim-infinite))
          (snippet-sys-snippetof/ob-c ess (flat-obstinacy) #/fn hole
            (dlog 'zdr1 (snippet-sys-snippet-degree shape-ess hole) d
              (dim-sys-dim<? eds
                (snippet-sys-snippet-degree shape-ess hole)
                (extended-with-top-dim-finite d))
            #/selectable/c any/c
              (if
                (dim-sys-dim<? eds
                  (snippet-sys-snippet-degree shape-ess hole)
                  (extended-with-top-dim-finite d))
                any/c
                none/c))))])
    [_ any/c])
  (selective-snippet-nonzero d content))

(define (selective-snippet? v)
  (or
    (selective-snippet-zero? v)
    (selective-snippet-nonzero? v)))

(define (selective-snippet/c sfs uds h-to-unselected/c)
  (w- eds (extended-with-top-dim-sys uds)
  #/w- ffdstsss (snippet-format-sys-functor sfs)
  #/w- uss (functor-sys-apply-to-object ffdstsss uds)
  #/w- ess (functor-sys-apply-to-object ffdstsss eds)
  #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
  #/w- unextend-hole
    (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
      (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
        (unextend-with-top-dim-sys-morphism-sys uds)))
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
      (by-own-method/c #:obstinacy (flat-obstinacy)
        (selective-snippet-nonzero d content)
      #/match/c selective-snippet-nonzero any/c
        (snippet-sys-snippetof/ob-c ess (flat-obstinacy) #/fn hole
          (dlog 'r1 (snippet-sys-snippet-degree shape-ess hole) d
            (dim-sys-dim<? eds
              (snippet-sys-snippet-degree shape-ess hole)
              (extended-with-top-dim-finite d))
            h-to-unselected/c
          #/selectable/c
            (h-to-unselected/c
              (snippet-sys-morphism-sys-morph-snippet
                unextend-hole hole))
            (if
              (dim-sys-dim<? eds
                (snippet-sys-snippet-degree shape-ess hole)
                (extended-with-top-dim-finite d))
              any/c
              none/c)))))
    `(selective-snippet/c ,sfs ,uds ,h-to-unselected/c)))

(define (selective-snippet-get-dim-sys s content-get-dim-sys)
  (mat s (selective-snippet-zero content)
    (content-get-dim-sys content)
  #/dissect s (selective-snippet-nonzero d content)
    (dissect (content-get-dim-sys content)
      (extended-with-top-dim-sys ds)
      ds)))

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
      (dlogr 'b1
      #/dissect ss (selective-snippet-sys sfs uds _)
      #/expect snippet (selective-snippet-nonzero d content)
        (dim-sys-dim-zero uds)
        d))
    ; snippet-sys-shape->snippet
    (fn ss shape
      (dlog 'zj1
      #/dissect ss (selective-snippet-sys sfs uds _)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- uss (functor-sys-apply-to-object ffdstsss uds)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/w- unextended-snippet (snippet-sys-shape->snippet uss shape)
      #/w- d (snippet-sys-snippet-degree uss unextended-snippet)
      #/dlog 'zj2
      #/if (dim-sys-dim=0? uds d)
        (dlog 'zj3
        #/selective-snippet-zero unextended-snippet)
      #/w- extended-snippet
        (dlog 'zj4
        #/snippet-sys-morphism-sys-morph-snippet
          (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
            (extend-with-top-dim-sys-morphism-sys uds))
          unextended-snippet)
      #/dlog 'zj5
      #/expect
        (snippet-sys-snippet-set-degree-maybe ess
          (extended-with-top-dim-infinite)
          extended-snippet)
        (just content)
        ; TODO: Improve this error. If this can occur at all, it must
        ; occur when one of the systems involved doesn't obey its
        ; laws.
        (error "Expected an extended-with-top snippet-sys to always allow setting the degree of a snippet to infinity")
      #/dlog 'zj6
      #/attenuated-selective-snippet-nonzero sfs uds d
        (snippet-sys-snippet-select-everything ess content)))
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
      #/just #/attenuated-selective-snippet-nonzero sfs uds new-degree content))
    ; snippet-sys-snippet-done
    (fn ss degree shape data
      (dlogr 'zb1 ss degree shape
      #/dissect ss (selective-snippet-sys sfs uds _)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/w- extend
        (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
          (extend-with-top-dim-sys-morphism-sys uds))
      #/expect
        (snippet-sys-snippet-set-degree-maybe ess
          (extended-with-top-dim-infinite)
          (dlog 'zb3
          #/snippet-sys-snippet-select-everything ess
            (dlog 'zb4
            #/snippet-sys-snippet-done ess
              (extended-with-top-dim-finite degree)
              (snippet-sys-morphism-sys-morph-snippet
                (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
                  extend)
                shape)
              data)))
        (just content)
        ; TODO: Improve this error. If this can occur at all, it must
        ; occur when one of the systems involved doesn't obey its
        ; laws.
        (error "Expected an extended-with-top snippet-sys to always allow setting the degree of a nonzero-degree snippet to infinity")
      #/attenuated-selective-snippet-nonzero sfs uds degree content))
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
      #/dlog 'i1 #/attenuated-snippet-sys-snippet-undone uss
        (snippet-sys-morphism-sys-morph-snippet
          (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
            (unextend-with-top-dim-sys-morphism-sys uds))
          content)))
    ; snippet-sys-snippet-splice
    (fn ss snippet hv-to-splice
      (dlog 'e1
      #/dissect ss (selective-snippet-sys sfs uds _)
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
          ; TODO: Test this.
          (mat data (unselected data)
            (just #/unselected #/unselected data)
          #/dissect data (selected data)
          #/w- extended-hole-degree
            (snippet-sys-snippet-degree ess extended-hole)
          #/w- unextended-hole
            (snippet-sys-morphism-sys-morph-snippet
              unextend-hole extended-hole)
          #/maybe-map (hv-to-splice unextended-hole data) #/fn splice
            (mat splice (unselected data) (unselected #/selected data)
            #/dissect splice
              (selected #/selective-snippet-nonzero d suffix)
            #/selected
              (snippet-sys-snippet-map-selective ess
                (snippet-sys-snippet-select-if-degree< ess
                  extended-hole-degree
                  suffix)
                (fn hole data
                  (mat data (unselected data)
                    (unselected data)
                  #/dissect data (selected data)
                  #/mat data (unselected data)
                    (selected data)
                  #/dissect data (selected #/trivial)
                    (trivial)))))))
      #/fn snippet
        (attenuated-selective-snippet-nonzero sfs uds d snippet)))
    ; snippet-sys-snippet-zip-map-selective
    (fn ss shape snippet hvv-to-maybe-v
      (dlog 'zm1
      #/dissect ss (selective-snippet-sys sfs uds _)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds (extended-with-top-dim-sys uds)
      #/w- uss (functor-sys-apply-to-object ffdstsss uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/mat snippet (selective-snippet-zero subject)
        (dlog 'zm2
        #/maybe-map
          (snippet-sys-snippet-zip-map-selective uss shape subject
            hvv-to-maybe-v)
        #/fn snippet
          (selective-snippet-zero snippet))
      #/dissect snippet (selective-snippet-nonzero d subject)
      #/w- unextend-hole
        (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
          (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
            (unextend-with-top-dim-sys-morphism-sys uds)))
      #/dlog 'zm3
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
          #/dlog 'zm4
          #/maybe-map
            (hvv-to-maybe-v unextended-hole shape-data subject-data)
          #/fn result-data
            (selected result-data)))
      #/fn snippet
        (attenuated-selective-snippet-nonzero sfs uds d snippet)))))

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
    (attenuated-selective-snippet-nonzero
      (snippet-format-sys-morphism-sys-target sfsms)
      (dim-sys-morphism-sys-target dsms)
      (dim-sys-morphism-sys-morph-dim
        (snippet-sys-morphism-sys-dim-sys-morphism-sys
          (make-ssms dsms))
        d)
      (snippet-sys-morphism-sys-morph-snippet
        (make-ssms #/extended-with-top-dim-sys-morphism-sys dsms)
        content))))

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

; TODO: See if this has a good design. The interface seems a little
; sloppy since `content-shape` is set up to take any snippet system,
; but we only supply it with some specific snippet systems.
(define (selective-snippet-shape ss s content-shape)
  (dlog 'zc13
  #/dissect ss (selective-snippet-sys sfs uds _)
  #/w- eds (extended-with-top-dim-sys uds)
  #/w- ffdstsss (snippet-format-sys-functor sfs)
  #/w- uss (functor-sys-apply-to-object ffdstsss uds)
  #/w- ess (functor-sys-apply-to-object ffdstsss eds)
  #/w- e-shape-ss (snippet-sys-shape-snippet-sys ess)
  #/mat s (selective-snippet-zero content) (content-shape uss content)
  #/dlog 'zc14
  #/dissect s (selective-snippet-nonzero d content)
    (dlog 'zc14.1 d content
    #/dlog 'zc14.2 (attenuated-selective-snippet-nonzero sfs uds d content)
    #/dissect (snippet-sys-snippet-filter-maybe ess content)
      (just filtered-content)
    #/dlog 'zc15 eds d filtered-content
    #/dissect
      (dlog 'zc15.1
      #/snippet-sys-snippet-set-degree-maybe e-shape-ss
        (extended-with-top-dim-finite d)
        (dlogr 'zc16
        #/content-shape ess filtered-content))
      (just shape)
    #/dlog 'zc16
    #/snippet-sys-morphism-sys-morph-snippet
      (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
        (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
          (unextend-with-top-dim-sys-morphism-sys uds)))
      shape)))


; TODO: Consider rearranging everything in this file, but especially
; the things below. Currently the file is in three parts: The things
; needed for `selective-snippet-sys?` (which we used to use to
; implement `hypernest-snippet-sys?`), the things needed for
; `hypertee-snippet-sys?`, and the things needed for
; `hypernest-snippet-sys?`. Each time, some generic `snippet-sys?`
; utilities are added, but as we have more code that uses
; `snippet-sys?` values, we'll probably want to maintain all the
; generic `snippet-sys?` utilities in one place.


; TODO: Export this.
; TODO: Use the things that use this.
(define/own-contract
  (snippet-sys-snippet-zip-map ss shape snippet hvv-to-maybe-v)
  (->i
    (
      [ss snippet-sys?]
      [shape (ss)
        (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)]
      [snippet (ss) (snippet-sys-snippet/c ss)]
      [hvv-to-maybe-v (ss)
        (-> (snippet-sys-unlabeled-shape/c ss) any/c any/c maybe?)])
    [_ (ss snippet)
      (maybe/c
        (snippet-sys-snippet-with-degree=/c ss
          (snippet-sys-snippet-degree ss snippet)))])
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
  #/snippet-sys-snippet-splice ss snippet #/fn hole data
    (mat data (selected data) (just #/unselected data)
    #/dissect data (unselected data)
    #/maybe-map
      (snippet-sys-snippet-set-degree-maybe ss d
        (snippet-sys-shape->snippet ss hole))
    #/fn patch
      (selected patch))))

; TODO: Use the things that use this.
(define/own-contract
  (snippet-sys-snippet-map-selective ss snippet hv-to-v)
  (->i
    (
      [ss snippet-sys?]
      [snippet (ss)
        (snippet-sys-snippetof/ob-c ss (flat-obstinacy) #/fn hole
          selectable?)]
      [hv-to-v (ss)
        (-> (snippet-sys-unlabeled-shape/c ss) any/c any/c)])
    [_ (ss snippet)
      (snippet-sys-snippet-with-degree=/c ss
        (snippet-sys-snippet-degree ss snippet))])
  (snippet-sys-snippet-map ss snippet #/fn hole data
    (mat data (unselected data) data
    #/dissect data (selected data) (hv-to-v hole data))))


; TODO: Use the things that use these.
(define-imitation-simple-struct
  (hypertee-coil-zero?)
  hypertee-coil-zero
  'hypertee-coil-zero (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hypertee-coil-zero? (-> any/c boolean?))
(define-imitation-simple-struct
  (hypertee-coil-hole?
    hypertee-coil-hole-overall-degree
    hypertee-coil-hole-hole
    hypertee-coil-hole-data
    hypertee-coil-hole-tails)
  hypertee-coil-hole
  'hypertee-coil-hole (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hypertee-coil-hole? (-> any/c boolean?))
(ascribe-own-contract hypertee-coil-hole-overall-degree
  (-> hypertee-coil-hole? any/c))
(ascribe-own-contract hypertee-coil-hole-hole
  (-> hypertee-coil-hole? any/c))
(ascribe-own-contract hypertee-coil-hole-data
  (-> hypertee-coil-hole? any/c))
(ascribe-own-contract hypertee-coil-hole-tails
  (-> hypertee-coil-hole? any/c))

; NOTE DEBUGGABILITY: This is here for debugging.
(define/own-contract
  (attenuated-fn-hypertee-coil-hole ds overall-degree hole data tails)
  (->i
    (
      [ds dim-sys?]
      [overall-degree (ds) (dim-sys-0<dim/c ds)]
      [hole (ds overall-degree)
        (w- ss (hypertee-snippet-sys ds)
        #/and/c
          (snippet-sys-unlabeled-snippet/c ss)
          (snippet-sys-snippet-with-degree</c ss overall-degree))]
      [data any/c]
      [tails (ds overall-degree hole)
        (w- ss (hypertee-snippet-sys ds)
        #/snippet-sys-snippet-zip-selective/ob-c ss (flat-obstinacy)
          hole
          (fn hole subject-data #t)
          (fn hole shape-data subject-data
            (and/c
              (snippet-sys-snippet-with-degree=/c ss overall-degree)
              (snippet-sys-snippet-fitting-shape/c ss hole))))])
    [_ any/c])
  (hypertee-coil-hole overall-degree hole data tails))
(define-syntax (attenuated-hypertee-coil-hole stx)
  (syntax-case stx () #/ (_ ds overall-degree hole data tails)
    #`(dlog 'm2 #,(~a stx)
        (
          #,@
          (if debugging-with-contracts
            #'(attenuated-fn-hypertee-coil-hole ds)
            #'(hypertee-coil-hole))
          overall-degree hole data tails))))

(define/own-contract (hypertee-coil/c ds)
  (-> dim-sys? flat-contract?)
  (w- ss (hypertee-snippet-sys ds)
  #/rename-contract
    (or/c
      hypertee-coil-zero?
      (and/c
        (match/c hypertee-coil-hole
          (dim-sys-0<dim/c ds)
          (snippet-sys-unlabeled-snippet/c ss)
          any/c
          any/c)
        (by-own-method/c #:obstinacy (flat-obstinacy)
          (hypertee-coil-hole overall-degree hole data tails)
          (match/c hypertee-coil-hole
            any/c
            (snippet-sys-snippet-with-degree</c ss overall-degree)
            any/c
            (snippet-sys-snippet-zip-selective/ob-c ss
              (flat-obstinacy)
              hole
              (fn hole subject-data #t)
              (fn hole shape-data subject-data
                (and/c
                  (snippet-sys-snippet-with-degree=/c
                    ss overall-degree)
                  (snippet-sys-snippet-fitting-shape/c ss hole))))))))
    `(hypertee-coil/c ,(value-name-for-contract ds))))

; TODO: Use the things that use these.
(define-imitation-simple-struct
  (hypertee? hypertee-get-dim-sys hypertee-get-coil)
  ; NOTE DEBUGGABILITY: For debugging, we've set up a system where we
  ; currently rename this from `unguarded-hypertee-furl` to
  ; `unguarded-hypertee-furl-orig` and define
  ; `unguarded-hypertee-furl` to be either the guarded version or the
  ; unguarded version (according to the
  ; `debugging-with-expensive-hypertee-furl-contract` branch below).
  unguarded-hypertee-furl-orig
  'hypertee (current-inspector) (auto-equal)
  (#:prop prop:custom-write
    (ifc debugging-with-safe-mode-printing
      (make-constructor-style-printer
        (fn ht 'hypertee)
        (dissectfn (unguarded-hypertee-furl-orig ds coil)
          (list ds coil)))
      (make-constructor-style-printer
        (fn ht 'ht-bracs)
        (fn ht
          (w- ds (hypertee-get-dim-sys ht)
          #/list* ds (hypertee-degree ds ht)
            (list-map (hypertee-get-brackets ht) #/fn bracket
              (mat bracket (htb-labeled d data) (htb-labeled d data)
              #/dissect bracket (htb-unlabeled d)
                (if (hypertee-bracket? d)
                  (htb-unlabeled d)
                  d)))))))))
(ascribe-own-contract hypertee? (-> any/c boolean?))
(ascribe-own-contract hypertee-get-dim-sys (-> hypertee? dim-sys?))
(ascribe-own-contract hypertee-get-coil
  (->i ([ht hypertee?])
    [_ (ht) (hypertee-coil/c #/hypertee-get-dim-sys ht)]))
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
      (->i ([ds dim-sys?] [coil (ds) (hypertee-coil/c ds)])
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
(ifc debugging-with-expensive-hypertee-furl-contract
  (define-match-expander-from-match-and-make
    unguarded-hypertee-furl
    hypertee-furl
    hypertee-furl
    hypertee-furl-dlog)
  (define-match-expander-from-match-and-make
    unguarded-hypertee-furl
    unguarded-hypertee-furl-orig
    unguarded-hypertee-furl-orig
    unguarded-hypertee-furl-orig))

; TODO: Use the things that use this.
(define/own-contract (hypertee/c ds)
  (-> dim-sys? flat-contract?)
  (rename-contract (match/c unguarded-hypertee-furl (ok/c ds) any/c)
    `(hypertee/c ,(value-name-for-contract ds))))

(define (hypertee-degree ds ht)
  (dissect ht (unguarded-hypertee-furl _ coil)
  #/mat coil (hypertee-coil-zero) (dim-sys-dim-zero ds)
  #/dissect coil (hypertee-coil-hole d hole data tails) d))

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
  #/then state #/unguarded-hypertee-furl ds
    (attenuated-hypertee-coil-hole ds d hole data tails)))

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
  #/maybe-bind (hvv-to-maybe-v shape-hole shape-data snippet-data)
  #/fn result-data
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
  #/just #/unguarded-hypertee-furl ds
    (attenuated-hypertee-coil-hole ds snippet-d shape-hole result-data
      result-tails)))

; TODO: See if we should export this.
; TODO: Use the things that use this.
(define (hypertee-map-dim dsms ht)
  (w- target-ds (dim-sys-morphism-sys-target dsms)
  #/w- target-ss (hypertee-snippet-sys target-ds)
  #/dissect ht (unguarded-hypertee-furl _ coil)
  #/unguarded-hypertee-furl target-ds
    (mat coil (hypertee-coil-zero) (hypertee-coil-zero)
    #/dissect coil (hypertee-coil-hole d hole data tails)
    #/attenuated-hypertee-coil-hole target-ds
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
      (dlogr 'b2 snippet
      #/dissect ss (hypertee-snippet-sys ds)
      #/hypertee-degree ds snippet))
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
        (unguarded-hypertee-furl ds
          (attenuated-hypertee-coil-hole ds degree hole data tails))))
    ; snippet-sys-snippet-done
    (fn ss degree shape data
      (dissect ss (hypertee-snippet-sys ds)
      #/unguarded-hypertee-furl ds #/attenuated-hypertee-coil-hole ds
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
          (maybe-bind (dlog 'i2 #/attenuated-snippet-sys-snippet-undone ss tail)
          #/dissectfn (list tail-d tail-shape data)
          #/expect
            (and
              (dlog 'h5 #/dim-sys-dim=? ds d tail-d)
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
      (dlog 'e2
      #/dissect ss (hypertee-snippet-sys ds)
      #/w-loop next
        snippet snippet
        first-nontrivial-d (dim-sys-dim-zero ds)
        
        (dlog 'e2.1
        #/dissect snippet (unguarded-hypertee-furl _ coil)
        #/mat coil (hypertee-coil-zero)
          (dlog 'e2.2
          #/just #/unguarded-hypertee-furl ds #/hypertee-coil-zero)
        #/dlogr 'e2.3
        #/dissect coil (hypertee-coil-hole d hole data tails)
        #/w- hole-d (snippet-sys-snippet-degree ss hole)
        #/maybe-bind
          (dlogr 'e2.3.1
          #/if
            (dlog 'e2.3.2
            #/dim-sys-dim<? ds hole-d first-nontrivial-d)
            (dlog 'e2.3.3
            #/dissect data (trivial)
              (just #/unselected #/trivial))
            (dlog 'e2.3.4 hv-to-splice
            #/hv-to-splice hole data))
        #/fn splice
        #/dlog 'e2.4
        #/maybe-bind
          (snippet-sys-snippet-map-maybe ss tails #/fn hole tail
            (dlog 'e2.5 (hypertee-get-dim-sys snippet) (hypertee-get-dim-sys tail)
            #/next tail
              (dim-sys-dim-max ds
                first-nontrivial-d
                (snippet-sys-snippet-degree ss hole))))
        #/fn tails
        #/dlog 'e2.6
        #/mat splice (unselected data)
          (just #/unguarded-hypertee-furl ds
            (attenuated-hypertee-coil-hole ds d hole data tails))
        #/dissect splice (selected suffix)
        #/dlog 'e2.7
        #/w- suffix
          (dlog 'e2.8
          #/snippet-sys-snippet-map ss
            (snippet-sys-snippet-select-if-degree< ss hole-d suffix)
          #/fn hole data
            (mat data (selected data) (selected data)
            #/dissect data (unselected data)
              (unselected #/unselected data)))
        #/maybe-map
          (snippet-sys-snippet-zip-map-selective ss tails suffix
          #/fn hole tail data
            (dissect data (trivial)
            #/just #/selected tail))
        #/fn suffix
          (dlog 'e2.9
          #/snippet-sys-snippet-join-selective ss suffix))))
    ; TODO: Figure out why the following variation of
    ; `snippet-sys-snippet-splice` was breaking.
    #;
    (fn ss snippet hv-to-splice
      (dlog 'e2
      #/dissect ss (hypertee-snippet-sys ds)
      #/dissect snippet (unguarded-hypertee-furl _ coil)
      #/mat coil (hypertee-coil-zero)
        (dlog 'e2.2
        #/just #/unguarded-hypertee-furl ds #/hypertee-coil-zero)
      #/dlogr 'e2.3
      #/dissect coil (hypertee-coil-hole d hole data tails)
      #/maybe-bind
        (dlog 'e2.3.1 hv-to-splice
        #/hv-to-splice hole data)
      #/fn splice
      #/dlog 'e2.4
      #/maybe-bind
        (snippet-sys-snippet-map-maybe ss tails #/fn hole tail
          (dlog 'e2.5 (hypertee-get-dim-sys snippet) (hypertee-get-dim-sys tail)
          #/w- hole-d (snippet-sys-snippet-degree ss hole)
          #/snippet-sys-snippet-splice ss tail #/fn tail-hole data
            (dlog 'e2.5.1
            #/if
              (dim-sys-dim<? ds
                (snippet-sys-snippet-degree ss tail-hole)
                hole-d)
              (3:dlog 'e2.5.1.1 coil
              #/3:dlog 'e2.5.1.2 tail
              #/3:dlog 'e2.5.1.3 data
              #/dissect data (trivial)
              #/just #/unselected #/trivial)
            #/hv-to-splice tail-hole data)))
      #/fn tails
      #/dlog 'e2.6 splice
      #/mat splice (unselected data)
        (dlog 'e2.6.1
        #/just #/unguarded-hypertee-furl ds
          (dlog 'e2.6.2
          #/attenuated-hypertee-coil-hole ds d hole data tails))
      #/dissect splice (selected suffix)
        (dlog 'e2.7 tails
        #/w- hole-d (snippet-sys-snippet-degree ss hole)
        ; TODO: This `dissect` is the place the errors occur when we
        ; use this approach. Figure out what's going on here. It
        ; doesn't appear that using `maybe-bind` helps here (although
        ; it makes this a little closer to the working variation,
        ; which uses `maybe-map` here).
        #/dissect
;        #/maybe-bind
          (if (dim-sys-dim=0? ds hole-d)
            (just suffix)
          #/snippet-sys-snippet-zip-map ss tails suffix
            (fn hole tail data
              (dissect data (trivial)
              #/just tail)))
          (just suffix)
;        #/fn suffix
        #/dlog 'e2.9
        #/just
          (snippet-sys-snippet-join-selective ss
            (snippet-sys-snippet-select-if-degree< ss hole-d
              suffix)))))
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
      
      (dlog 'zp1
      #/dissect ss (hypertee-snippet-sys ds)
      #/mat shape (unguarded-hypertee-furl _ #/hypertee-coil-zero)
        (snippet-sys-snippet-map-maybe ss snippet #/fn hole data
          (mat data (selected data) (nothing)
          #/dissect data (unselected data) (just data)))
      #/w- numbered-snippet
        (hypertee-map-cps ds 0 snippet
          (fn state hole data then
            (mat data (unselected data)
              (then state #/unselected data)
            #/dissect data (selected data)
              (then (add1 state) #/selected #/list state data)))
        #/fn state numbered-snippet
          numbered-snippet)
      #/dlog 'zp2-shape shape
      #/maybe-bind
        (snippet-sys-snippet-filter-maybe ss numbered-snippet)
      #/fn filtered-numbered-snippet
      #/dlog 'zp2.1-snippet snippet
      #/dlog 'zp3-filtered-numbered-snippet filtered-numbered-snippet
      #/maybe-bind
        (hypertee-zip-map ds shape filtered-numbered-snippet
        #/fn hole shape-data snippet-data
          (dissect snippet-data (list i snippet-data)
          #/maybe-map (hvv-to-maybe-v hole shape-data snippet-data)
          #/fn result-data
            (list i result-data)))
      #/fn filtered-numbered-result
      #/dlog 'zp4
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
(ascribe-own-contract hypertee-snippet-sys? (-> any/c boolean?))
(ascribe-own-contract hypertee-snippet-sys-dim-sys
  (-> hypertee-snippet-sys? dim-sys?))
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
(ascribe-own-contract hypertee-snippet-format-sys?
  (-> any/c boolean?))

(define/own-contract (hypertee-get-hole-zero-maybe ht)
  (->
    (and/c hypertee?
      (by-own-method/c #:obstinacy (flat-obstinacy) ht
        (hypertee/c #/hypertee-get-dim-sys ht)))
    maybe?)
  (4:dlog 'hqq-j4
  #/dissect ht (unguarded-hypertee-furl ds coil)
  #/w- ss (hypertee-snippet-sys ds)
  #/mat coil (hypertee-coil-zero)
    (nothing)
  #/dissect coil (hypertee-coil-hole d hole data tails)
    (if (dim-sys-dim=0? ds (snippet-sys-snippet-degree ss tails))
      (just data)
    #/maybe-bind (hypertee-get-hole-zero-maybe tails) #/fn tail-zero
    #/hypertee-get-hole-zero-maybe tail-zero)))


; TODO: Find a better name for this.
;
; TODO: Export this.
;
; TODO: See if we'll ever use this. We used to use it to implement
; `hypernest-snippet-sys?`.
;
(define
  (make-snippet-sys-impl-from-conversions
    snippet-sys-snippet/c ss-> ->ds ->shape-ss degree-> ->degree
    shape-> ->shape snippet-> ->snippet)
  (make-snippet-sys-impl-from-various-1
    ; snippet-sys-snippet/c
    snippet-sys-snippet/c
    ; snippet-sys-dim-sys
    (fn ss
      (->ds #/snippet-sys-dim-sys #/ss-> ss))
    ; snippet-sys-shape-snippet-sys
    (fn ss
      (->shape-ss #/snippet-sys-shape-snippet-sys #/ss-> ss))
    ; snippet-sys-snippet-degree
    (fn ss snippet
      (dlogr 'b3 ss
      #/->degree ss
        (snippet-sys-snippet-degree (ss-> ss)
          (snippet-> ss snippet))))
    ; snippet-sys-shape->snippet
    (fn ss shape
      (dlog 'zi1
      #/->snippet ss
        (dlog 'zi2
        #/snippet-sys-shape->snippet (dlog 'zi3 #/ss-> ss) (dlog 'zi4 #/shape-> ss shape))))
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
        (dlog 'i3 #/attenuated-snippet-sys-snippet-undone (ss-> ss) (snippet-> ss snippet))
      #/dissectfn (list d hole data)
        (list (->degree ss d) (->shape ss hole) data)))
    ; snippet-sys-snippet-splice
    (fn ss snippet hv-to-splice
      (dlog 'e3 snippet hv-to-splice
      #/maybe-map
        (snippet-sys-snippet-splice (ss-> ss) (snippet-> ss snippet)
        #/fn hole data
          (maybe-map (hv-to-splice (->shape ss hole) data) #/fn data
            (selectable-map data #/fn suffix
              (snippet-> ss suffix))))
      #/fn snippet
        (->snippet ss snippet)))
    ; snippet-sys-snippet-zip-map-selective
    (fn ss shape snippet hvv-to-maybe-v
      (dlog 'n18
      #/maybe-map
        (dlog 'n19
        #/snippet-sys-snippet-zip-map-selective (ss-> ss)
          (dlog 'n20
          #/shape-> ss shape)
          (dlog 'n21
          #/snippet-> ss snippet)
          (fn hole shape-data snippet-data
            (dlog 'n22
            #/hvv-to-maybe-v
              (->shape ss hole)
              shape-data
              snippet-data)))
      #/fn snippet
        (->snippet ss snippet)))))


(define hn-printer
  (make-constructor-style-printer
    (fn hn 'hn-bracs)
    (fn hn
      (w- ds (hypernest-get-dim-sys hn)
      #/list* ds (hypernest-degree ds hn)
        (list-map (hypernest-get-brackets hn) #/fn bracket
          (mat bracket (hnb-open d data) (hnb-open d data)
          #/mat bracket (hnb-labeled d data) (hnb-labeled d data)
          #/dissect bracket (hnb-unlabeled d)
            (if (hypertee-bracket? d)
              (hnb-unlabeled d)
              d)))))))

; TODO: Export these.
; TODO: Use these.
; TODO: Define `hypernest-zero` in terms of
; `hypernest-zero-unchecked`.
(define-imitation-simple-struct
  (hypernest-zero? hypernest-zero-content)
  hypernest-zero-unchecked
  'hypernest-zero (current-inspector) (auto-equal)
  (#:prop prop:custom-write
    (ifc debugging-with-safe-mode-printing
      (make-constructor-style-printer
        (fn hn 'hypernest-zero)
        (dissectfn (hypernest-zero-unchecked content) #/list content))
      hn-printer)))

; TODO: Export these.
; TODO: Use these.
; TODO: Define `hypernest-nonzero` in terms of
; `hypernest-zero-unchecked`.
(define-imitation-simple-struct
  (hypernest-nonzero?
    hypernest-nonzero-degree
    hypernest-nonzero-content)
  hypernest-nonzero-unchecked
  'hypernest-nonzero (current-inspector) (auto-equal)
  (#:prop prop:custom-write
    (ifc debugging-with-safe-mode-printing
      (make-constructor-style-printer
        (fn hn 'hypernest-nonzero)
        (dissectfn (hypernest-nonzero-unchecked d content)
          (list d content)))
      hn-printer)))

; TODO: Export this.
; TODO: Use the things that use this.
(define/own-contract (hypernest? v)
  (-> any/c boolean?)
  (or
    (hypernest-zero? v)
    (hypernest-nonzero? v)))

; TODO: See if we should export this.
; TODO: Use the things that use this.
(define (hypernestof-lazy/ob-c sfs uds ob b-to-value/c h-to-value/c)
  (w- ffdstsss (snippet-format-sys-functor sfs)
  #/w- eds (extended-with-top-dim-sys #/extended-with-top-dim-sys uds)
  #/w- uss (functor-sys-apply-to-object ffdstsss uds)
  #/w- ess (functor-sys-apply-to-object ffdstsss eds)
  #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
  #/w- unextend-dim
    (dim-sys-morphism-sys-chain-two
      (unextend-with-top-dim-sys-morphism-sys
        (extended-with-top-finite-dim-sys uds))
      (unextend-with-top-dim-sys-morphism-sys uds))
  #/w- unextend-snippet
    (functor-from-dim-sys-sys-apply-to-morphism ffdstsss unextend-dim)
  #/w- unextend-shape
    (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
      unextend-snippet)
  #/rename-contract
    (or/c
      (match/c hypernest-zero-unchecked
        (snippet-sys-snippet-with-degree=/c uss
          (dim-sys-dim-zero uds)))
      (and/c
        (match/c hypernest-nonzero-unchecked
          (dim-sys-0<dim/c uds)
          any/c)
      #/by-own-method/c #:obstinacy (flat-obstinacy)
        (hypernest-nonzero-unchecked d _)
      #/match/c hypernest-nonzero-unchecked
        any/c
        (and/c
          (snippet-sys-snippet-with-degree=/c ess
            (extended-with-top-dim-infinite))
          (snippet-sys-snippetof/ob-c ess ob #/fn hole
            (mat (snippet-sys-snippet-degree shape-ess hole)
              (extended-with-top-dim-finite
                (extended-with-top-dim-finite hole-d))
              (if (dim-sys-dim<? uds hole-d d)
                (h-to-value/c #/fn
                  (5:dlog 'zr2
                  #/snippet-sys-morphism-sys-morph-snippet
                    unextend-shape
                    hole))
                none/c)
            #/expect (attenuated-snippet-sys-snippet-undone ess hole)
              (just undone-result)
              none/c
            #/dissect undone-result
              (list
                (extended-with-top-dim-finite
                  (extended-with-top-dim-infinite))
                bump-interior-shape
                (trivial))
              (b-to-value/c #/fn
                (5:dlog 'zr3
                #/snippet-sys-morphism-sys-morph-snippet unextend-shape
                  bump-interior-shape)))))))
    `(hypernestof-lazy/ob-c
       ,sfs ,uds ,ob ,b-to-value/c ,h-to-value/c)))

; TODO: Use the things that use this.
(define/own-contract (hypernest/c sfs uds)
  (-> snippet-format-sys? dim-sys? flat-contract?)
  (rename-contract
    (hypernestof-lazy/ob-c sfs uds (flat-obstinacy)
      (fn get-bump-interior-shape any/c)
      (fn get-hole any/c))
    `(hypernest/c ,sfs ,uds)))

; TODO: Use the things that use this.
(define/own-contract
  (hypernestof/ob-c sfs uds ob b-to-value/c h-to-value/c)
  (->i
    (
      [sfs snippet-format-sys?]
      [ds dim-sys?]
      [ob obstinacy?]
      [b-to-value/c (sfs ds ob)
        (w- ffdstsss (snippet-format-sys-functor sfs)
        #/w- ss (functor-sys-apply-to-object ffdstsss ds)
        #/-> (snippet-sys-unlabeled-shape/c ss)
          (obstinacy-contract/c ob))]
      [h-to-value/c (sfs ds ob)
        (w- ffdstsss (snippet-format-sys-functor sfs)
        #/w- ss (functor-sys-apply-to-object ffdstsss ds)
        #/-> (snippet-sys-unlabeled-shape/c ss)
          (obstinacy-contract/c ob))])
    [_ (ob) (obstinacy-contract/c ob)])
  (rename-contract
    (hypernestof-lazy/ob-c sfs uds ob
      (fn get-bump-interior-shape
        (b-to-value/c #/get-bump-interior-shape))
      (fn get-hole #/h-to-value/c #/get-hole))
    `(hypernestof/ob-c ,sfs ,uds ,ob ,b-to-value/c ,h-to-value/c)))

(define/own-contract (hypernest-get-dim-sys hn)
  (-> hypernest? dim-sys?)
  (dlog 'zk1 hn
  #/mat hn (hypernest-zero-unchecked content)
    (hypertee-get-dim-sys content)
  #/dissect hn (hypernest-nonzero-unchecked d hn-extended)
  #/dissect
    (dlog 'zk2
    #/hypertee-get-dim-sys hn-extended)
    (extended-with-top-dim-sys #/extended-with-top-dim-sys ds)
    ds))

(define (hypernest-degree ds hn)
  (mat hn (hypernest-zero-unchecked content) (dim-sys-dim-zero ds)
  #/dissect hn (hypernest-nonzero-unchecked d hn-extended) d))

; TODO: See if we should export this.
; TODO: Use the things that use this.
(define (hypernest-map-dim sfs dsms hn)
  (w- ffdstsss (snippet-format-sys-functor sfs)
  #/w- original-map-dim
    (fn dsms snippet
      (snippet-sys-morphism-sys-morph-snippet
        (functor-from-dim-sys-sys-apply-to-morphism ffdstsss dsms)
        snippet))
  #/mat hn (hypernest-zero-unchecked content)
    (hypernest-zero-unchecked #/original-map-dim dsms content)
  #/dissect hn (hypernest-nonzero-unchecked d hn-extended)
    (hypernest-nonzero-unchecked
      (dim-sys-morphism-sys-morph-dim dsms d)
      (original-map-dim
        (extended-with-top-dim-sys-morphism-sys
          (extended-with-top-dim-sys-morphism-sys dsms))
        hn-extended))))

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
  (#:prop prop:snippet-sys #/make-snippet-sys-impl-from-various-1
    ; snippet-sys-snippet/c
    (dissectfn (hypernest-snippet-sys sfs uds)
      (hypernest/c sfs uds))
    ; snippet-sys-dim-sys
    (dissectfn (hypernest-snippet-sys sfs uds)
      uds)
    ; snippet-sys-shape-snippet-sys
    (dissectfn (hypernest-snippet-sys sfs uds)
      (w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- uss (functor-sys-apply-to-object ffdstsss uds)
      #/snippet-sys-shape-snippet-sys uss))
    ; snippet-sys-snippet-degree
    (fn ss snippet
      (dissect ss (hypernest-snippet-sys sfs uds)
      #/hypernest-degree uds snippet))
    ; snippet-sys-shape->snippet
    (fn ss shape
      (dissect ss (hypernest-snippet-sys sfs uds)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- uss (functor-sys-apply-to-object ffdstsss uds)
      #/w- shape-uss (snippet-sys-shape-snippet-sys uss)
      #/w- d (snippet-sys-snippet-degree shape-uss shape)
      #/w- shape-as-snippet (snippet-sys-shape->snippet uss shape)
      #/if (dim-sys-dim=0? uds d)
        (hypernest-zero-unchecked shape-as-snippet)
      #/w- eds
        (extended-with-top-dim-sys #/extended-with-top-dim-sys uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/hypernest-nonzero-unchecked d
        (just-value #/snippet-sys-snippet-set-degree-maybe ess
          (extended-with-top-dim-infinite)
          (snippet-sys-morphism-sys-morph-snippet
            (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
              (dim-sys-morphism-sys-chain-two
                (extend-with-top-dim-sys-morphism-sys uds)
                (extend-with-top-dim-sys-morphism-sys
                  (extended-with-top-dim-sys uds))))
            shape-as-snippet))))
    ; snippet-sys-snippet->maybe-shape
    (fn ss snippet
      (dissect ss (hypernest-snippet-sys sfs uds)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/mat snippet (hypernest-zero-unchecked content)
        (w- uss (functor-sys-apply-to-object ffdstsss uds)
        #/snippet-sys-snippet->maybe-shape uss content)
      #/dissect snippet (hypernest-nonzero-unchecked d hn-extended)
      #/w- eds
        (extended-with-top-dim-sys #/extended-with-top-dim-sys uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
      #/dlogr 'zs1
      #/maybe-map (snippet-sys-snippet->maybe-shape ess hn-extended)
      #/fn shape
        (dissect
          (snippet-sys-snippet-set-degree-maybe shape-ess
            (extended-with-top-dim-finite
              (extended-with-top-dim-finite d))
            shape)
          (just shape)
        #/5:dlog 'zr4
        #/snippet-sys-morphism-sys-morph-snippet
          (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
            (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
              (dim-sys-morphism-sys-chain-two
                (unextend-with-top-dim-sys-morphism-sys
                  (extended-with-top-finite-dim-sys uds))
                (unextend-with-top-dim-sys-morphism-sys uds))))
          shape)))
    ; snippet-sys-snippet-set-degree-maybe
    (fn ss new-degree snippet
      (dissect ss (hypernest-snippet-sys sfs uds)
      #/w- new-degree-is-zero (dim-sys-dim=0? uds new-degree)
      #/mat snippet (hypernest-zero-unchecked content)
        ; TODO: See if we should at least attempt setting the degree
        ; of the content. If we do, and if the attempt is successful,
        ; we may need to return a `hypernest-nonzero-unchecked`.
        (maybe-if new-degree-is-zero #/fn snippet)
      #/dissect snippet (hypernest-nonzero-unchecked d hn-extended)
      #/if new-degree-is-zero
        ; TODO: See if we should at least attempt setting the degree
        ; of the content. If we do, and if the attempt is successful,
        ; we may need to return a `hypernest-zero-unchecked`.
        (nothing)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds
        (extended-with-top-dim-sys #/extended-with-top-dim-sys uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/dissect
        (snippet-sys-snippet-filter-maybe ess
          (snippet-sys-snippet-select-if-degree< ess
            (extended-with-top-dim-finite
              (extended-with-top-dim-infinite))
            hn-extended))
        (just hn-unextended)
      #/maybe-map
        (snippet-sys-snippet-set-degree-maybe ess
          (extended-with-top-dim-finite
            (extended-with-top-dim-finite new-degree))
          hn-unextended)
      #/dissectfn _
        (hypernest-nonzero-unchecked new-degree hn-extended)))
    ; snippet-sys-snippet-done
    (fn ss degree shape data
      (dissect ss (hypernest-snippet-sys sfs uds)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds
        (extended-with-top-dim-sys #/extended-with-top-dim-sys uds)
      #/w- uss (functor-sys-apply-to-object ffdstsss uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/hypernest-nonzero-unchecked degree
        (just-value #/snippet-sys-snippet-set-degree-maybe ess
          (extended-with-top-dim-infinite)
          (snippet-sys-morphism-sys-morph-snippet
            (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
              (dim-sys-morphism-sys-chain-two
                (extend-with-top-dim-sys-morphism-sys uds)
                (extend-with-top-dim-sys-morphism-sys
                  (extended-with-top-dim-sys uds))))
            (snippet-sys-snippet-done uss degree shape data)))))
    ; snippet-sys-snippet-undone
    (fn ss snippet
      (dissect ss (hypernest-snippet-sys sfs uds)
      #/mat snippet (hypernest-zero-unchecked content)
        (nothing)
      #/dissect snippet (hypernest-nonzero-unchecked d hn-extended)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds
        (extended-with-top-dim-sys #/extended-with-top-dim-sys uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
      #/dlog 'zq2
      #/maybe-map (snippet-sys-snippet-undone ess hn-extended)
      #/dissectfn (list (extended-with-top-dim-infinite) shape data)
        (list
          d
          (5:dlog 'zr5
          #/snippet-sys-morphism-sys-morph-snippet
            (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
              (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
                (dim-sys-morphism-sys-chain-two
                  (unextend-with-top-dim-sys-morphism-sys
                    (extended-with-top-finite-dim-sys uds))
                  (unextend-with-top-dim-sys-morphism-sys uds))))
            shape)
          data)))
    ; snippet-sys-snippet-splice
    (fn ss snippet hv-to-splice
      (dissect ss (hypernest-snippet-sys sfs uds)
      #/mat snippet (hypernest-zero-unchecked content)
        (just snippet)
      #/dissect snippet (hypernest-nonzero-unchecked d hn-extended)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- eds
        (extended-with-top-dim-sys #/extended-with-top-dim-sys uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
      #/maybe-map
        (snippet-sys-snippet-splice ess hn-extended #/fn hole data
          (dlog 'zq1
          #/expect
            (dim-sys-dim<? eds
              (snippet-sys-snippet-degree shape-ess hole)
              (extended-with-top-dim-finite
                (extended-with-top-dim-infinite)))
            #t
            (just #/unselected data)
          #/maybe-map
            (hv-to-splice
              (5:dlog 'zr6
              #/snippet-sys-morphism-sys-morph-snippet
                (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
                  (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
                    (dim-sys-morphism-sys-chain-two
                      (unextend-with-top-dim-sys-morphism-sys
                        (extended-with-top-finite-dim-sys uds))
                      (unextend-with-top-dim-sys-morphism-sys uds))))
                hole)
              data)
          #/fn splice
            (mat splice (unselected data) (unselected data)
            #/dissect splice
              (selected
                (hypernest-nonzero-unchecked _ suffix-extended))
              (selected suffix-extended))))
      #/fn result-extended
        (hypernest-nonzero-unchecked d result-extended)))
    ; snippet-sys-snippet-zip-map-selective
    (fn ss shape snippet hvv-to-maybe-v
      (dissect ss (hypernest-snippet-sys sfs uds)
      #/w- ffdstsss (snippet-format-sys-functor sfs)
      #/w- extended-hvv-to-maybe-v
        (fn hole shape-data snippet-data
          (hvv-to-maybe-v
            (5:dlog 'zr7
            #/snippet-sys-morphism-sys-morph-snippet
              (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
                (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
                  (dim-sys-morphism-sys-chain-two
                    (unextend-with-top-dim-sys-morphism-sys
                      (extended-with-top-finite-dim-sys uds))
                    (unextend-with-top-dim-sys-morphism-sys uds))))
              hole)
            shape-data
            snippet-data))
      #/mat snippet (hypernest-zero-unchecked content)
        (w- uss (functor-sys-apply-to-object ffdstsss uds)
        #/maybe-map
          (snippet-sys-snippet-zip-map-selective uss shape content
            extended-hvv-to-maybe-v)
        #/fn content
          (hypernest-zero-unchecked content))
      #/dissect snippet (hypernest-nonzero-unchecked d hn-extended)
      #/w- eds
        (extended-with-top-dim-sys #/extended-with-top-dim-sys uds)
      #/w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
      #/w- extend-selection
        (fn hn-extended
          (snippet-sys-snippet-map ess hn-extended #/fn hole data
            (if
              (dim-sys-dim<? eds
                (snippet-sys-snippet-degree shape-ess hole)
                (extended-with-top-dim-finite
                  (extended-with-top-dim-infinite)))
              data
              (unselected data))))
      #/maybe-map
        (snippet-sys-snippet-zip-map-selective ess
          (snippet-sys-morphism-sys-morph-snippet
            (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
              (functor-from-dim-sys-sys-apply-to-morphism ffdstsss
                (dim-sys-morphism-sys-chain-two
                  (extend-with-top-dim-sys-morphism-sys uds)
                  (extend-with-top-dim-sys-morphism-sys
                    (extended-with-top-dim-sys uds)))))
            shape)
          (extend-selection hn-extended)
          extended-hvv-to-maybe-v)
      #/fn result-extended
        (hypernest-nonzero-unchecked d result-extended)))))
(ascribe-own-contract hypernest-snippet-sys? (-> any/c boolean?))
(ascribe-own-contract hypernest-snippet-sys-snippet-format-sys
  (-> hypernest-snippet-sys? snippet-format-sys?))
(ascribe-own-contract hypernest-snippet-sys-dim-sys
  (-> hypernest-snippet-sys? dim-sys?))
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

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (hypernest-map-dim-snippet-sys-morphism-sys?
    hypernest-map-dim-snippet-sys-morphism-sys-snippet-format-sys
    hypernest-map-dim-snippet-sys-morphism-sys-dim-sys-morphism-sys)
  hypernest-map-dim-snippet-sys-morphism-sys
  'hypernest-map-dim-snippet-sys-morphism-sys
  (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (hypernest-map-dim-snippet-sys-morphism-sys sfs dsms)
        (match/c hypernest-map-dim-snippet-sys-morphism-sys
          (ok/c sfs)
          (ok/c dsms)))))
  (#:prop prop:snippet-sys-morphism-sys
    (make-snippet-sys-morphism-sys-impl-from-morph
      ; snippet-sys-morphism-sys-source
      (dissectfn (hypernest-map-dim-snippet-sys-morphism-sys sfs dsms)
        (hypernest-snippet-sys sfs
          (dim-sys-morphism-sys-source dsms)))
      ; snippet-sys-morphism-sys-replace-source
      (fn ms new-s
        (dissect ms
          (hypernest-map-dim-snippet-sys-morphism-sys sfs dsms)
        #/expect new-s (hypernest-snippet-sys new-s-sfs new-s-ds)
          (w- s
            (hypernest-snippet-sys sfs
              (dim-sys-morphism-sys-source dsms))
          #/raise-arguments-error
            'snippet-sys-morphism-sys-replace-source
            "tried to replace the source with a source that was rather different"
            "ms" ms
            "s" s
            "new-s" new-s)
        #/expect (equal? sfs new-s-sfs) #t
          (raise-arguments-error
            'snippet-sys-morphism-sys-replace-source
            "tried to replace the source with a source that had a different snippet functor system (in terms of `equal?`)"
            "ms" ms
            "sfs" sfs
            "new-s-sfs" new-s-sfs)
        #/hypernest-map-dim-snippet-sys-morphism-sys new-s-sfs
          (dim-sys-morphism-sys-replace-source dsms new-s-ds)))
      ; snippet-sys-morphism-sys-target
      (dissectfn (hypernest-map-dim-snippet-sys-morphism-sys sfs dsms)
        (hypernest-snippet-sys sfs
          (dim-sys-morphism-sys-target dsms)))
      ; snippet-sys-morphism-sys-replace-target
      (fn ms new-t
        (dissect ms
          (hypernest-map-dim-snippet-sys-morphism-sys sfs dsms)
        #/expect new-t (hypernest-snippet-sys new-t-sfs new-t-ds)
          (w- t
            (hypernest-snippet-sys sfs
              (dim-sys-morphism-sys-target dsms))
          #/raise-arguments-error
            'snippet-sys-morphism-sys-replace-target
            "tried to replace the target with a target that was rather different"
            "ms" ms
            "t" t
            "new-t" new-t)
        #/expect (equal? sfs new-t-sfs) #t
          (raise-arguments-error
            'snippet-sys-morphism-sys-replace-target
            "tried to replace the target with a target that had a different snippet functor system (in terms of `equal?`)"
            "ms" ms
            "sfs" sfs
            "new-t-sfs" new-t-sfs)
        #/hypernest-map-dim-snippet-sys-morphism-sys new-t-sfs
          (dim-sys-morphism-sys-replace-target dsms new-t-ds)))
      ; snippet-sys-morphism-sys-dim-sys-morphism-sys
      (dissectfn (hypernest-map-dim-snippet-sys-morphism-sys sfs dsms)
        dsms)
      ; snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
      (fn ms ms)
      ; snippet-sys-morphism-sys-morph-snippet
      (fn ms s
        (dissect ms
          (hypernest-map-dim-snippet-sys-morphism-sys sfs dsms)
        #/hypernest-map-dim sfs dsms s)))))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (hypernest-functor-from-dim-sys-to-snippet-sys-sys?
    hypernest-functor-from-dim-sys-to-snippet-sys-sys-snippet-functor-sys)
  hypernest-functor-from-dim-sys-to-snippet-sys-sys
  'hypernest-functor-from-dim-sys-to-snippet-sys-sys
  (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn
        (hypernest-functor-from-dim-sys-to-snippet-sys-sys sfs)
        (match/c hypernest-functor-from-dim-sys-to-snippet-sys-sys
          (ok/c sfs)))))
  (#:prop prop:functor-sys
    (make-functor-from-dim-sys-to-snippet-sys-sys-impl-from-apply
      (fn fs ds
        (dissect fs
          (hypernest-functor-from-dim-sys-to-snippet-sys-sys sfs)
        #/hypernest-snippet-sys sfs ds))
      (fn fs ms
        (dissect fs
          (hypernest-functor-from-dim-sys-to-snippet-sys-sys sfs)
        #/hypernest-map-dim-snippet-sys-morphism-sys sfs ms)))))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (hypernest-snippet-format-sys?
    hypernest-snippet-format-sys-original)
  unguarded-hypernest-snippet-format-sys
  'hypernest-snippet-format-sys (current-inspector)
  (auto-write)
  (auto-equal)
  (#:prop prop:atomic-set-element-sys
    (make-atomic-set-element-sys-impl-from-contract
      ; atomic-set-element-sys-accepts/c
      (dissectfn (hypernest-snippet-format-sys orig-sfs)
        (match/c hypernest-snippet-format-sys #/ok/c orig-sfs))))
  (#:prop prop:snippet-format-sys
    (make-snippet-format-sys-impl-from-functor
      ; snippet-format-sys-functor
      (dissectfn (hypernest-snippet-format-sys orig-sfs)
        (hypernest-functor-from-dim-sys-to-snippet-sys-sys
          orig-sfs)))))
(ascribe-own-contract hypernest-snippet-format-sys?
  (-> any/c boolean?))
(ascribe-own-contract hypernest-snippet-format-sys-original
  (-> hypernest-snippet-format-sys? snippet-format-sys?))
(define-match-expander-attenuated
  attenuated-hypernest-snippet-format-sys
  unguarded-hypernest-snippet-format-sys
  [original snippet-format-sys?]
  #t)
(define-match-expander-from-match-and-make
  hypernest-snippet-format-sys
  unguarded-hypernest-snippet-format-sys
  attenuated-hypernest-snippet-format-sys
  attenuated-hypernest-snippet-format-sys)

(define/own-contract (hypernest-shape ss hn)
  ; TODO SPECIFIC: See if the result contract should be more specific.
  ; The result should always be of the same degree as the input.
  (->i
    ([ss hypernest-snippet-sys?] [hn (ss) (snippet-sys-snippet/c ss)])
    [_ (ss)
      (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)])
  (dlogr 'zc10
  #/dissect ss (hypernest-snippet-sys sfs uds)
  #/mat hn (hypernest-zero-unchecked content)
    (dissect (snippet-sys-snippet->maybe-shape ss hn) (just shape)
      shape)
  #/dissect hn (hypernest-nonzero-unchecked d hn-extended)
  #/w- ffdstsss (snippet-format-sys-functor sfs)
  #/w- eds (extended-with-top-dim-sys #/extended-with-top-dim-sys uds)
  #/w- ess (functor-sys-apply-to-object ffdstsss eds)
  #/dissect
    (snippet-sys-snippet-filter-maybe ess
      (snippet-sys-snippet-select-if-degree< ess
        (extended-with-top-dim-finite
          (extended-with-top-dim-infinite))
        hn-extended))
    (just hn-unextended)
  #/dlogr 'zc11 ss hn-unextended
  #/dissect
    (snippet-sys-snippet->maybe-shape ss
      (hypernest-nonzero-unchecked d hn-unextended))
    (just shape)
    shape))

(define/own-contract (hypernest-get-hole-zero-maybe hn)
  (->
    (and/c hypernest?
      (by-own-method/c #:obstinacy (flat-obstinacy) hn
        (hypernest/c (hypertee-snippet-format-sys)
          (hypernest-get-dim-sys hn))))
    maybe?)
  (4:dlog 'hqq-j1
  #/mat hn (hypernest-zero-unchecked content)
    (nothing)
  #/4:dlog 'hqq-j2
  #/dissect hn (hypernest-nonzero-unchecked d hn-extended)
    (4:dlog 'hqq-j3
    #/hypertee-get-hole-zero-maybe hn-extended)))

(define/own-contract
  (hypernest-join-list-and-tail-along-0 ds past-snippets last-snippet)
  (->i
    (
      [ds dim-sys?]
      [past-snippets (ds last-snippet)
        (w- ss
          (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
        #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
        #/listof #/and/c
          (snippet-sys-snippet-with-degree=/c ss
            (snippet-sys-snippet-degree ss last-snippet))
          (snippet-sys-snippetof/ob-c ss (flat-obstinacy) #/fn hole
            (if
              (dim-sys-dim=0? ds
                (snippet-sys-snippet-degree shape-ss hole))
              trivial?
              any/c)))]
      [last-snippet (ds)
        (w- ss
          (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
        #/snippet-sys-snippet-with-0<degree/c ss)])
    [_ (ds last-snippet)
      (w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
      #/snippet-sys-snippet-with-degree=/c ss
        (snippet-sys-snippet-degree ss last-snippet))])
  (w- sfs (hypernest-snippet-format-sys #/hypertee-snippet-format-sys)
  #/w- ffdstsss (snippet-format-sys-functor sfs)
  #/w- shape-zero
    (fn eds
      (unguarded-hypertee-furl eds #/hypertee-coil-zero))
  #/snippet-sys-snippet-join-list-and-tail-along-0 sfs ds
    (fn eds overall-d hole-d extended-past-snippet tail
      (w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/w- shape-ess (snippet-sys-shape-snippet-sys ess)
      #/snippet-sys-snippet-join-selective ess
        (snippet-sys-snippet-done ess overall-d
          (snippet-sys-snippet-done shape-ess hole-d (shape-zero eds)
            (selected tail))
          (unselected extended-past-snippet))))
    (fn eds overall-d extended-last-snippet
      (w- ess (functor-sys-apply-to-object ffdstsss eds)
      #/snippet-sys-snippet-done ess overall-d (shape-zero eds)
        extended-last-snippet))
    past-snippets
    last-snippet))


; TODO: Use the things that use these.
(define-imitation-simple-struct
  (hypernest-coil-zero?)
  hypernest-coil-zero
  'hypernest-coil-zero (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hypernest-coil-zero? (-> any/c boolean?))
(define-imitation-simple-struct
  (hypernest-coil-hole?
    hypernest-coil-hole-overall-degree
    hypernest-coil-hole-hole
    hypernest-coil-hole-data
    hypernest-coil-hole-tails-hypertee)
  hypernest-coil-hole
  'hypernest-coil-hole (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hypernest-coil-hole? (-> any/c boolean?))
(ascribe-own-contract hypernest-coil-hole-overall-degree
  (-> hypernest-coil-hole? any/c))
(ascribe-own-contract hypernest-coil-hole-hole
  (-> hypernest-coil-hole? any/c))
(ascribe-own-contract hypernest-coil-hole-data
  (-> hypernest-coil-hole? any/c))
(ascribe-own-contract hypernest-coil-hole-tails-hypertee
  (-> hypernest-coil-hole? any/c))
(define-imitation-simple-struct
  (hypernest-coil-bump?
    hypernest-coil-bump-overall-degree
    hypernest-coil-bump-data
    hypernest-coil-bump-bump-degree
    hypernest-coil-bump-tails-hypernest)
  hypernest-coil-bump
  'hypernest-coil-bump (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hypernest-coil-bump? (-> any/c boolean?))
(ascribe-own-contract hypernest-coil-bump-overall-degree
  (-> hypernest-coil-bump? any/c))
(ascribe-own-contract hypernest-coil-bump-data
  (-> hypernest-coil-bump? any/c))
(ascribe-own-contract hypernest-coil-bump-bump-degree
  (-> hypernest-coil-bump? any/c))
(ascribe-own-contract hypernest-coil-bump-tails-hypernest
  (-> hypernest-coil-bump? any/c))

; NOTE DEBUGGABILITY: This is here for debugging. Unlike the
; unattenuated version, this one has an extra `ds` argument.
(define/own-contract
  (attenuated-hypernest-coil-hole
    ds overall-degree hole data tails-hypertee)
  (->i
    (
      [ds dim-sys?]
      [overall-degree (ds) (dim-sys-0<dim/c ds)]
      [hole (ds overall-degree)
        (w- ss
          (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
        #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
        #/and/c
          (snippet-sys-unlabeled-shape/c ss)
          (snippet-sys-snippet-with-degree</c
            shape-ss overall-degree))]
      [data any/c]
      [tails-hypertee (ds overall-degree hole)
        (w- ss
          (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
        #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
        #/snippet-sys-snippet-zip-selective/ob-c shape-ss
          (flat-obstinacy)
          hole
          (fn hole subject-data #t)
          (fn hole shape-data subject-data
            (and/c
              (snippet-sys-snippet-with-degree=/c ss overall-degree)
              (snippet-sys-snippet-fitting-shape/c ss hole))))])
    [_ any/c])
  (hypernest-coil-hole overall-degree hole data tails-hypertee))

(define/own-contract (hypernest-coil/c ds)
  (-> dim-sys? flat-contract?)
  (w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/rename-contract
    (or/c
      hypernest-coil-zero?
      (and/c
        (match/c hypernest-coil-hole
          (dim-sys-0<dim/c ds)
          (snippet-sys-unlabeled-shape/c ss)
          any/c
          any/c)
        (by-own-method/c #:obstinacy (flat-obstinacy)
          (hypernest-coil-hole
            overall-degree hole data tails-hypertee)
          (match/c hypernest-coil-hole
            any/c
            (snippet-sys-snippet-with-degree</c
              shape-ss overall-degree)
            any/c
            (snippet-sys-snippet-zip-selective/ob-c shape-ss
              (flat-obstinacy)
              hole
              (fn hole subject-data #t)
              (fn hole shape-data subject-data
                (and/c
                  (snippet-sys-snippet-with-degree=/c
                    ss overall-degree)
                  (snippet-sys-snippet-fitting-shape/c ss hole)))))))
      (and/c
        (match/c hypernest-coil-bump
          (dim-sys-0<dim/c ds)
          any/c
          (dim-sys-dim/c ds)
          any/c)
        (by-own-method/c #:obstinacy (flat-obstinacy)
          (hypernest-coil-bump
            overall-degree data bump-degree tails-hypernest)
          (match/c hypernest-coil-bump
            any/c
            any/c
            any/c
            (and/c
              (snippet-sys-snippet-with-degree=/c ss
                (dim-sys-dim-max ds overall-degree bump-degree))
              (snippet-sys-snippetof/ob-c ss (flat-obstinacy)
                (fn hole
                  (w- hole-d
                    (snippet-sys-snippet-degree shape-ss hole)
                  #/expect (dim-sys-dim<? ds hole-d bump-degree) #t
                    any/c
                  #/and/c
                    (snippet-sys-snippet-with-degree=/c ss
                      
                      ; TODO: Almost all of the unit tests in
                      ; test-hypernest-2.rkt, with the exception of
                      ; the `sample-hn-expr-shape-as-ast` test,
                      ; continue to work if we just use
                      ; `overall-degree` here. We should write more
                      ; tests for this case (that is, the situation
                      ; where a hypernest has a bump with a hole of
                      ; degree greater than the overall hypernest).
                      ;
                      (dim-sys-dim-max ds overall-degree hole-d))
                    (snippet-sys-snippet-fitting-shape/c ss
                      hole)))))))))
    `(hypernest-coil/c ,(value-name-for-contract ds))))

; NOTE DEBUGGABILITY: This is a `define/own-contract` for debugging.
(define/own-contract (unguarded-fn-hypernest-furl ds coil)
  (->i ([ds dim-sys?] [coil (ds) (hypernest-coil/c ds)])
    [_ hypernest?])
  (dlog 'l1
  #/w- uds ds
  #/w- eds (extended-with-top-dim-sys #/extended-with-top-dim-sys uds)
  #/w- ehtss (hypertee-snippet-sys eds)
  #/w- extend-dim
    (dim-sys-morphism-sys-chain-two
      (extend-with-top-dim-sys-morphism-sys uds)
      (extend-with-top-dim-sys-morphism-sys
        (extended-with-top-dim-sys uds)))
  #/mat coil (hypernest-coil-zero)
    (hypernest-zero-unchecked
      (unguarded-hypertee-furl uds #/hypertee-coil-zero))
  #/mat coil
    (hypernest-coil-hole overall-degree hole data tails-hypertee)
    (dlog 'l1.1 overall-degree tails-hypertee
    #/hypernest-nonzero-unchecked overall-degree
      (dlogr 'l1.2
      #/unguarded-hypertee-furl eds #/hypertee-coil-hole
        (extended-with-top-dim-infinite)
        (hypertee-map-dim extend-dim hole)
        data
        (dlog 'l1.3
        #/snippet-sys-snippet-map ehtss
          (dlog 'l1.4
          #/hypertee-map-dim extend-dim tails-hypertee)
          (fn hole tail
            (dissect tail
              (hypernest-nonzero-unchecked _ tail-extended)
              tail-extended)))))
  #/dissect coil
    (hypernest-coil-bump
      overall-degree data bump-degree tails-hypernest)
    (dlog 'l1.5
    #/dissect tails-hypernest
      (hypernest-nonzero-unchecked _ tails-extended)
    #/dlog 'l1.6
    #/dissect
      (if (dim-sys-dim=0? uds bump-degree)
        (just #/unguarded-hypertee-furl uds #/hypertee-coil-zero)
        (maybe-bind
          (snippet-sys-snippet-filter-maybe ehtss
            (snippet-sys-snippet-select-if-degree< ehtss
              (extended-with-top-dim-finite
                (extended-with-top-dim-finite bump-degree))
              tails-extended))
        #/fn tails-shape
        #/dlog 'l1.7 bump-degree tails-shape
        #/snippet-sys-snippet-set-degree-maybe ehtss
          (extended-with-top-dim-finite
            (extended-with-top-dim-finite bump-degree))
          tails-shape))
      (just truncated-tails-shape)
    #/dlog 'l1.8
    #/3:dlog 'zo1 data
    #/w- interior
      (4:dlog 'hqq-e1
      #/snippet-sys-snippet-map-selective ehtss
        ; TODO: We're computing this once already, during the
        ; computation of `truncated-tails-shape`. Let's deduplicate
        ; this effort.
        (snippet-sys-snippet-select-if-degree< ehtss
          (extended-with-top-dim-finite
            (extended-with-top-dim-finite bump-degree))
          tails-extended)
        (fn hole tail
          (trivial)))
    #/w- tails-assembled
      (4:dlog 'hqq-e2
      #/snippet-sys-snippet-done ehtss
        (extended-with-top-dim-finite
          (extended-with-top-dim-infinite))
        (4:dlog 'hqq-e3
        #/snippet-sys-snippet-map ehtss truncated-tails-shape
          (fn hole tail
            (4:dlog 'hqq-e4 overall-degree bump-degree (snippet-sys-snippet-degree ehtss hole)
            #/dissect tail
              (hypernest-nonzero-unchecked _ tail-extended)
              tail-extended)))
        interior)
    #/dlog 'l1.9 data
    #/3:dlog 'zo4
    #/hypernest-nonzero-unchecked overall-degree
      (4:dlog 'hqq-e5
      #/hypertee-furl eds #/4:dlog 'hqq-e6 #/attenuated-hypertee-coil-hole eds
        (extended-with-top-dim-infinite)
        (4:dlog 'hqq-e7
        #/snippet-sys-snippet-map ehtss tails-assembled #/fn hole tail
          (trivial))
        data
        tails-assembled))))

(define/own-contract (hypernest-get-coil hn)
  (->i ([hn hypernest?])
    [_ (hn) (hypernest-coil/c #/hypernest-get-dim-sys hn)])
  (let-syntax
    (
      [dlog
        (if debugging-with-prints-for-hypernest-qq
          (syntax-local-value #'4:dlog)
          (syntax-local-value #'dlog))])
  #/dlog 'n2 hn (hypernest-get-dim-sys hn)
  #/mat hn (hypernest-zero-unchecked content)
    (dissect content (unguarded-hypertee-furl _ #/hypertee-coil-zero)
    #/hypernest-coil-zero)
  #/dissect hn
    (hypernest-nonzero-unchecked overall-degree
      (unguarded-hypertee-furl eds hn-extended-coil))
  #/dlog 'n3
  #/dissect hn-extended-coil
    (hypertee-coil-hole (extended-with-top-dim-infinite)
      hole data tails)
  #/dlog 'n4
  #/dissect eds
    (extended-with-top-dim-sys #/extended-with-top-dim-sys uds)
  #/w- htss (hypertee-snippet-sys uds)
  #/w- ehtss (hypertee-snippet-sys eds)
  #/w- hnss (hypernest-snippet-sys (hypertee-snippet-format-sys) uds)
  #/w- unextend-dim
    (dim-sys-morphism-sys-chain-two
      (unextend-with-top-dim-sys-morphism-sys
        (extended-with-top-finite-dim-sys uds))
      (unextend-with-top-dim-sys-morphism-sys uds))
  #/dlog 'n5
  #/dissect (snippet-sys-snippet-degree ehtss tails)
    (extended-with-top-dim-finite half-extended-hole-degree)
  #/dlog 'n6
  #/mat half-extended-hole-degree
    (extended-with-top-dim-finite hole-degree)
    (dlog 'n7
    #/attenuated-hypernest-coil-hole uds
      overall-degree
      (hypertee-map-dim unextend-dim hole)
      data
      (snippet-sys-snippet-map htss
        (hypertee-map-dim unextend-dim tails)
        (fn hole tail
          (dlog 'n8
          #/hypernest-nonzero-unchecked overall-degree tail))))
  #/dissect half-extended-hole-degree (extended-with-top-dim-infinite)
    (dlog 'n9 tails
    #/dissect (dlog 'i5 #/attenuated-snippet-sys-snippet-undone ehtss tails)
      (just #/list
        (extended-with-top-dim-finite
          (extended-with-top-dim-infinite))
        tails
        interior)
    #/dlog 'n10
    #/dissect (snippet-sys-snippet-degree ehtss tails)
      (extended-with-top-dim-finite
        (extended-with-top-dim-finite bump-degree))
    #/dlog 'n11
    #/w- interior-hypernest
      (dlogr 'n12 bump-degree interior
      #/hypernest-nonzero-unchecked
        (dim-sys-dim-max uds overall-degree bump-degree)
        interior)
    #/dlog 'n11.1 (hypertee-map-dim unextend-dim tails) interior-hypernest
    #/dissect
      (dlog 'n13 hnss ; interior-hypernest
      #/if (dim-sys-dim=0? uds bump-degree)
        (just interior-hypernest)
      #/snippet-sys-snippet-zip-map-selective hnss
        (dlogr 'n14 tails
        #/hypertee-map-dim unextend-dim tails)
        (snippet-sys-snippet-select-if-degree<
          hnss bump-degree interior-hypernest)
        (fn hole tail interior-data
          (dlog 'n15 overall-degree
          #/dissect interior-data (trivial)
          #/dlog 'n16 tail
          #/just #/hypernest-nonzero-unchecked
            (dim-sys-dim-max uds overall-degree
              (snippet-sys-snippet-degree htss hole))
            tail)))
      (just tails-hypernest)
    #/dlog 'n17 overall-degree bump-degree tails tails-hypernest
    #/hypernest-coil-bump
      overall-degree data bump-degree tails-hypernest)))

; TODO: See if we need to rename this to `hypernest-furl` for better
; error messages. If so, we might need to put it in a submodule to
; avoid a namespace collision.
(define-match-expander match-hypernest-furl #/fn stx
  ; TODO: We should really use a syntax class for match patterns
  ; rather than `expr` here, but it doesn't look like one exists yet.
  (syntax-protect
  #/syntax-parse stx #/ (_ ds:expr coil:expr)
    #'(app
        (fn v
          (4:dlog 'hqq-i1
          #/maybe-if (hypernest? v) #/fn
          #/4:dlog 'hqq-i2
          #/list (4:dlog 'hqq-i3 #/hypernest-get-dim-sys v) (4:dlog 'hqq-i4 #/dlog 'n1 #/hypernest-get-coil v)))
        (just #/list ds coil))))

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
    (define/contract (hypernest-furl ds coil)
      (->i ([ds dim-sys?] [coil (ds) (hypernest-coil/c ds)])
        [_ hypernest?])
      (unguarded-hypernest-furl ds coil))
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


; TODO: Use these.
(define-imitation-simple-struct
  (htb-labeled? htb-labeled-degree htb-labeled-data)
  htb-labeled
  'htb-labeled (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract htb-labeled? (-> any/c boolean?))
(ascribe-own-contract htb-labeled-degree (-> htb-labeled? any/c))
(ascribe-own-contract htb-labeled-data (-> htb-labeled? any/c))
(define-imitation-simple-struct
  (htb-unlabeled? htb-unlabeled-degree)
  htb-unlabeled
  'htb-unlabeled (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract htb-unlabeled? (-> any/c boolean?))
(ascribe-own-contract htb-unlabeled-degree (-> htb-unlabeled? any/c))

; TODO: Use this.
(define/own-contract (hypertee-bracket? v)
  (-> any/c boolean?)
  (or (htb-labeled? v) (htb-unlabeled? v)))

; TODO: Use this.
(define/own-contract (hypertee-bracket/c dim/c)
  (-> contract? contract?)
  (w- dim/c (coerce-contract 'hypertee-bracket/c dim/c)
  #/rename-contract
    (or/c
      (match/c htb-labeled dim/c any/c)
      (match/c htb-unlabeled dim/c))
    `(hypertee-bracket/c ,(contract-name dim/c))))

; TODO: Use this.
(define/own-contract (hypertee-bracket-degree bracket)
  (-> hypertee-bracket? any/c)
  (mat bracket (htb-labeled d data) d
  #/dissect bracket (htb-unlabeled d) d))

; TODO: Use these.
(define-imitation-simple-struct
  (hnb-open? hnb-open-degree hnb-open-data)
  hnb-open
  'hnb-open (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hnb-open? (-> any/c boolean?))
(ascribe-own-contract hnb-open-degree (-> hnb-open? any/c))
(ascribe-own-contract hnb-open-data (-> hnb-open? any/c))
(define-imitation-simple-struct
  (hnb-labeled? hnb-labeled-degree hnb-labeled-data)
  hnb-labeled
  'hnb-labeled (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hnb-labeled? (-> any/c boolean?))
(ascribe-own-contract hnb-labeled-degree (-> hnb-labeled? any/c))
(ascribe-own-contract hnb-labeled-data (-> hnb-labeled? any/c))
(define-imitation-simple-struct
  (hnb-unlabeled? hnb-unlabeled-degree)
  hnb-unlabeled
  'hnb-unlabeled (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hnb-unlabeled? (-> any/c boolean?))
(ascribe-own-contract hnb-unlabeled-degree (-> hnb-unlabeled? any/c))

; TODO: Use this.
(define/own-contract (hypernest-bracket? v)
  (-> any/c boolean?)
  (or (hnb-open? v) (hnb-labeled? v) (hnb-unlabeled? v)))

; TODO: Use this.
(define/own-contract (hypernest-bracket/c dim/c)
  (-> contract? contract?)
  (w- dim/c (coerce-contract 'hypernest-bracket/c dim/c)
  #/rename-contract
    (or/c
      (match/c hnb-open dim/c any/c)
      (match/c hnb-labeled dim/c any/c)
      (match/c hnb-unlabeled dim/c))
    `(hypernest-bracket/c ,(contract-name dim/c))))

; TODO: Use this.
(define/own-contract (hypernest-bracket-degree bracket)
  (-> hypernest-bracket? any/c)
  (mat bracket (hnb-open d data) d
  #/mat bracket (hnb-labeled d data) d
  #/dissect bracket (hnb-unlabeled d) d))

; TODO: Use this.
(define/own-contract (hypertee-bracket->hypernest-bracket bracket)
  (-> hypertee-bracket? (or/c hnb-labeled? hnb-unlabeled?))
  (mat bracket (htb-labeled d data) (hnb-labeled d data)
  #/dissect bracket (htb-unlabeled d) (hnb-unlabeled d)))

; TODO: Use this.
(define/own-contract
  (compatible-hypernest-bracket->hypertee-bracket bracket)
  (-> (or/c hnb-labeled? hnb-unlabeled?) hypernest-bracket?)
  (mat bracket (hnb-labeled d data) (htb-labeled d data)
  #/dissect bracket (hnb-unlabeled d) (htb-unlabeled d)))

(define
  (explicit-hypernest-from-hyperstack-and-brackets
    err-name err-normalize-bracket orig-brackets ds stack orig-d
    bumps-allowed brackets)
  (w- htss (hypertee-snippet-sys ds)
  #/w- hnss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- current-d (hyperstack-dimension stack)
  #/expect brackets (cons bracket brackets-remaining)
    (expect (dlog 'zc4
            #/dim-sys-dim=0? ds current-d) #t
      (raise-arguments-error err-name
        "encountered the end of the brackets when the current degree was nonzero"
        "current-d" current-d
        "brackets" (map err-normalize-bracket orig-brackets))
    #/unguarded-hypernest-furl ds #/hypernest-coil-zero)
  #/w- process-hole
    (fn hole-degree data was-labeled
      (dlog 'zc5
      #/expect (dim-sys-dim<? ds hole-degree current-d) #t
        (raise-arguments-error err-name
          "encountered a closing bracket of degree too high for where it occurred"
          "current-d" current-d
          "bracket" (err-normalize-bracket bracket)
          "brackets-remaining"
          (map err-normalize-bracket brackets-remaining)
          "brackets" (map err-normalize-bracket orig-brackets))
      #/dissect
        (hyperstack-pop hole-degree stack #/list #f bumps-allowed)
        (list (list should-have-been-labeled bumps-now-allowed) stack)
      #/dlog 'zc6
      #/if (and was-labeled (not should-have-been-labeled))
        (raise-arguments-error err-name
          "encountered an annotated closing bracket where only an unannotated closing bracket was expected"
          "current-d" current-d
          "bracket" (err-normalize-bracket bracket)
          "brackets-remaining"
          (map err-normalize-bracket brackets-remaining)
          "brackets" (map err-normalize-bracket orig-brackets))
      #/if (and should-have-been-labeled (not was-labeled))
        (raise-arguments-error err-name
          "encountered an unannotated closing bracket where only an annotated closing bracket was expected"
          "current-d" current-d
          "bracket" (err-normalize-bracket bracket)
          "brackets-remaining"
          (map err-normalize-bracket brackets-remaining)
          "brackets" (map err-normalize-bracket orig-brackets))
      #/dlog 'zc7
      #/w- recursive-result
        (explicit-hypernest-from-hyperstack-and-brackets
          err-name err-normalize-bracket orig-brackets ds stack orig-d
          bumps-now-allowed brackets-remaining)
      #/dlog 'zc8 hnss recursive-result
      #/dlog 'zc9 current-d hole-degree was-labeled orig-d orig-brackets brackets-remaining
      
      ; We truncate the shape of `recursive-result` to just the holes
      ; that are smaller than `hole-degree`.
      ;
      #/w- recursive-result-with-selections
        (snippet-sys-snippet-select-if-degree<
          hnss hole-degree recursive-result)
      #/dlog 'zc9.1
      #/dissect
        (if (dim-sys-dim=0? ds hole-degree)
          (just #/unguarded-hypertee-furl ds #/hypertee-coil-zero)
          (w- shape-with-selections
            (hypernest-shape hnss recursive-result-with-selections)
          #/dlog 'zc9.2 shape-with-selections
          #/maybe-bind
            (snippet-sys-snippet-filter-maybe
              htss shape-with-selections)
          #/fn truncated-shape
          #/dlog 'zc9.3
;          #/begin (displayln (format "~a ~a ~a ~a" current-d hole-degree (hyperstack-dimension stack) (snippet-sys-snippet-degree htss truncated-shape)))
          #/snippet-sys-snippet-set-degree-maybe htss hole-degree
            truncated-shape))
        (just truncated-shape)
      
      ; Then we make a `hypernest-coil-hole`-based hypernest out of
      ; that, with the data in the hole being either `data` or
      ; `recursive-result` with its holes smaller than `hole-degree`
      ; replaced with trivial values. This way, all the tails carried
      ; by the recursive result in holes of degree smaller than
      ; `hole-degree` are incorporated into the snippet content of
      ; this result.
      ;
      #/dlog 'zc9.4
      #/unguarded-hypernest-furl ds
        (attenuated-hypernest-coil-hole ds
          current-d
          (snippet-sys-snippet-map htss truncated-shape #/fn hole tail
            (trivial))
          (if was-labeled
            data
            (dlog 'zc9.8
            #/snippet-sys-snippet-map-selective hnss
              recursive-result-with-selections
            #/fn hole data
              (trivial)))
          truncated-shape)))
  #/mat bracket (hnb-open bump-degree data)
    (expect bumps-allowed #t
      (raise-arguments-error err-name
        "encountered an opening bracket in a hole"
        "current-d" current-d
        "bracket" (err-normalize-bracket bracket)
        "brackets-remaining"
        (map err-normalize-bracket brackets-remaining)
        "brackets" (map err-normalize-bracket orig-brackets))
    #/w- stack
      (hyperstack-push bump-degree stack #/list #f bumps-allowed)
    #/w- recursive-result
      (explicit-hypernest-from-hyperstack-and-brackets
        err-name err-normalize-bracket orig-brackets ds stack orig-d
        bumps-allowed brackets-remaining)
    #/dlog 'ze1 brackets-remaining brackets recursive-result
    ; TODO DEBUGGABILITY: Come up with a way to automatically change
    ; this to a `hypernest-furl` call when we activate one of the
    ; debugging modes. For now, it's just a commented-out alternative.
;    #/hypernest-furl ds #/hypernest-coil-bump
    #/unguarded-hypernest-furl ds #/hypernest-coil-bump
      current-d data bump-degree recursive-result)
  #/mat bracket (hnb-labeled hole-degree data)
    (process-hole hole-degree data #t)
  #/dissect bracket (hnb-unlabeled hole-degree)
    (process-hole hole-degree (trivial) #f)))

(define
  (explicit-hypernest-from-brackets
    err-name err-normalize-bracket ds degree brackets)
  (w- hnss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/dlog 'zc2
  #/explicit-hypernest-from-hyperstack-and-brackets
    err-name err-normalize-bracket brackets ds
    (make-hyperstack ds degree #/list #t #f)
    degree #t brackets))

; TODO: Use this.
(define/own-contract (hypernest-from-brackets ds degree brackets)
  (->i
    (
      [ds dim-sys?]
      [degree (ds) (dim-sys-dim/c ds)]
      [brackets (ds)
        (listof #/hypernest-bracket/c #/dim-sys-dim/c ds)])
    [_ (ds) (hypernest/c (hypertee-snippet-format-sys) ds)])
  (explicit-hypernest-from-brackets
    'hypernest-from-brackets (fn hnb hnb) ds degree brackets))

; TODO: Use this.
(define/own-contract (hn-bracs ds degree . brackets)
  (->i ([ds dim-sys?] [degree (ds) (dim-sys-dim/c ds)])
    #:rest
    [brackets (ds)
      (w- dim/c (dim-sys-dim/c ds)
      #/listof #/or/c
        (hypernest-bracket/c dim/c)
        (and/c (not/c hypernest-bracket?) dim/c))]
    [_ (ds) (hypernest/c (hypertee-snippet-format-sys) ds)])
  (4:dlog 'hqq-d1
  #/explicit-hypernest-from-brackets 'hn-bracs (fn hnb hnb) ds degree
    (list-map brackets #/fn closing-bracket
      (if (hypernest-bracket? closing-bracket)
        closing-bracket
        (hnb-unlabeled closing-bracket)))))

(define (explicit-hypertee-from-brackets err-name ds degree brackets)
  (dlog 'd3
  #/just-value
    (snippet-sys-snippet->maybe-shape
      (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
      (dlog 'zc1
      #/explicit-hypernest-from-brackets
        err-name
        (fn hnb #/compatible-hypernest-bracket->hypertee-bracket hnb)
        ds
        degree
        (list-map brackets #/fn htb
          (hypertee-bracket->hypernest-bracket htb))))))

; TODO: Use this.
(define/own-contract (hypertee-from-brackets ds degree brackets)
  (->i
    (
      [ds dim-sys?]
      [degree (ds) (dim-sys-dim/c ds)]
      [brackets (ds)
        (listof #/hypertee-bracket/c #/dim-sys-dim/c ds)])
    [_ (ds) (hypertee/c ds)])
  (explicit-hypertee-from-brackets
    'hypertee-from-brackets ds degree brackets))

; TODO: Use this.
(define/own-contract (ht-bracs ds degree . brackets)
  (->i ([ds dim-sys?] [degree (ds) (dim-sys-dim/c ds)])
    #:rest
    [brackets (ds)
      (w- dim/c (dim-sys-dim/c ds)
      #/listof #/or/c
        (hypertee-bracket/c dim/c)
        (and/c (not/c hypertee-bracket?) dim/c))]
    [_ (ds) (hypertee/c ds)])
  (explicit-hypertee-from-brackets 'ht-bracs ds degree
    (list-map brackets #/fn closing-bracket
      (if (hypertee-bracket? closing-bracket)
        closing-bracket
        (htb-unlabeled closing-bracket)))))


(define (hyperstack-and-hypernest-get-brackets stack orig-d hn)
  (dlog 'zh0 hn
  #/w- ds (hypernest-get-dim-sys hn)
  #/dlog 'zh0.0.1
  #/w- htss (hypertee-snippet-sys ds)
  #/w- hnss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- coil (hypernest-get-coil hn)
  #/dlog 'zh0.1
  #/mat coil (hypernest-coil-zero) (list)
  #/dlog 'zh0.2
  #/mat coil (hypernest-coil-hole current-d shape data tails)
    (w- hole-degree (snippet-sys-snippet-degree htss shape)
    #/dlog 'zh1
    #/dissect (hyperstack-pop hole-degree stack #f)
      (list should-be-labeled stack)
    #/w- updated-d (hyperstack-dimension stack)
    #/dlog 'zh1.1
    #/w- recursive-result
      (dlog 'zh1.2
      #/hyperstack-and-hypernest-get-brackets stack orig-d
        (if should-be-labeled
          (dlog 'zh1.3
          #/snippet-sys-shape->snippet hnss
            (just-value
              (dlog 'zh1.4
              #/snippet-sys-snippet-set-degree-maybe
                htss updated-d tails)))
          (dlog 'zh1.5 tails data
          #/if (dim-sys-dim=0? ds hole-degree)
            data
            (just-value
              (snippet-sys-snippet-zip-map-selective hnss
                tails
                (snippet-sys-snippet-select-if-degree<
                  hnss hole-degree data)
                (fn hole tail data
                  (dlog 'zh2
                  #/dissect data (trivial)
                  #/just tail)))))))
    #/cons
      (if should-be-labeled
        (hnb-labeled hole-degree data)
        (hnb-unlabeled hole-degree))
      recursive-result)
  #/dlog 'zh3
  #/dissect coil
    (hypernest-coil-bump current-d data bump-degree tails-hypernest)
    (w- stack (hyperstack-push bump-degree stack #f)
    #/w- recursive-result
      (2:dlog 'zh4 current-d (hyperstack-dimension stack) (build-list (hyperstack-dimension stack) #/fn i #/hyperstack-peek stack i)
      #/hyperstack-and-hypernest-get-brackets
        stack orig-d tails-hypernest)
    #/cons (hnb-open bump-degree data) recursive-result)))

(define/own-contract (hypernest-get-brackets hn)
  (->i ([hn hypernest?])
    [_ (hn)
      (w- ds (hypernest-get-dim-sys hn)
      #/listof #/hypernest-bracket/c #/dim-sys-dim/c ds)])
  (dlog 'zl1 hn
  #/w- ds (hypernest-get-dim-sys hn)
  #/w- hnss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- degree (snippet-sys-snippet-degree hnss hn)
  #/hyperstack-and-hypernest-get-brackets
    (make-hyperstack ds degree #t)
    degree hn))

; TODO: Export this.
; TODO: Use this.
(define/own-contract (hypertee-get-brackets ht)
  (->i ([ht hypertee?])
    [_ (ht)
      (w- ds (hypertee-get-dim-sys ht)
      #/listof #/hypertee-bracket/c #/dim-sys-dim/c ds)])
  (dissect ht (unguarded-hypertee-furl ds coil)
  #/list-map
    (hypernest-get-brackets #/snippet-sys-shape->snippet
      (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
      ht)
  #/fn hnb
    (compatible-hypernest-bracket->hypertee-bracket hnb)))
