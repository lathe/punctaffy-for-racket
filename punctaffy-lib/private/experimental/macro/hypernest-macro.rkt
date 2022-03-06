#lang parendown racket/base

; hypernest-macro.rkt
;
; A framework for macros which take hypersnippet-shaped syntax.

;   Copyright 2018-2019, 2021-2022 The Lathe Authors
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


; NOTE DEBUGGABILITY: These are here for debugging.
(require #/for-syntax racket/base)
(require #/for-syntax #/only-in racket/syntax syntax-local-eval)
(define-for-syntax debugging-in-inexpensive-ways #f)
(define-for-syntax debugging-with-prints
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

(require #/only-in racket/contract/base
  -> ->i and/c any/c flat-contract? list/c listof none/c or/c
  rename-contract)
(require #/only-in racket/math natural?)
(require #/only-in racket/set set)
(require #/only-in syntax/parse
  exact-positive-integer id syntax-parse)

(require #/only-in lathe-comforts dissect expect fn mat w- w-loop)
(require #/only-in lathe-comforts/contract flat-obstinacy)
(require #/only-in lathe-comforts/list list-map)
(require #/only-in lathe-comforts/match
  define-match-expander-attenuated
  define-match-expander-from-match-and-make)
(require #/only-in lathe-comforts/maybe
  just just? maybe? maybe-bind maybe/c maybe-if maybe-map nothing)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct)
(require #/only-in lathe-comforts/trivial trivial trivial?)

(require punctaffy/private/shim)
(init-shim)

(require #/only-in punctaffy/hypersnippet/dim
  dim-sys? dim-sys-dim<? dim-sys-dim<=? dim-sys-dim=? dim-sys-dim=0?
  dim-sys-dim/c dim-sys-dim-max dim-sys-morphism-sys-morph-dim
  extended-with-top-dim-infinite extended-with-top-dim-sys
  extend-with-top-dim-sys-morphism-sys nat-dim-sys)
(require #/only-in punctaffy/hypersnippet/hypernest
  hnb-labeled hnb-open hnb-unlabeled hypernest-coil-bump
  hypernest-coil-hole hypernest-from-brackets hypernest-furl
  hypernest-get-hole-zero-maybe
  hypernest-join-list-and-tail-along-0 hypernest? hypernestof/ob-c
  hypernest-shape hypernest-snippet-sys)
(require #/only-in punctaffy/hypersnippet/hypertee
  htb-labeled htb-unlabeled hypertee-coil-hole hypertee-coil-zero
  hypertee-from-brackets hypertee-furl hypertee-snippet-format-sys)
(require #/only-in punctaffy/hypersnippet/snippet
  selectable-map selected snippet-sys-dim-sys
  snippet-sys-shape-snippet-sys snippet-sys-snippet-bind-selective
  snippet-sys-snippet-degree snippet-sys-snippet-done
  snippet-sys-snippet-each snippet-sys-snippet-join-selective
  snippet-sys-snippet-map snippet-sys-snippet-map-selective
  snippet-sys-snippet->maybe-shape snippet-sys-snippetof/ob-c
  snippet-sys-snippet-select-if-degree
  snippet-sys-snippet-select-if-degree<
  snippet-sys-snippet-set-degree-maybe snippet-sys-snippet-undone
  snippet-sys-snippet-with-degree=/c snippet-sys-snippet-zip-map
  unselected)
(require #/only-in punctaffy/private/util
  datum->syntax-with-everything)
(require #/only-in punctaffy/syntax-object/token-of-syntax
  syntax->token-of-syntax token-of-syntax-substitute
  token-of-syntax->syntax-list token-of-syntax-with-free-vars<=/c)
(require #/only-in punctaffy/taffy-notation
  taffy-notation? taffy-notation-akin-to-^<>d?
  taffy-notation-akin-to-^<>d-parse)

(provide
  hn-tag-0-s-expr-stx)
(provide #/own-contract-out
  hn-tag-0-s-expr-stx?
  hn-tag-0-s-expr-stx-stx)
(provide
  hn-tag-1-box)
(provide #/own-contract-out
  hn-tag-1-box?
  hn-tag-1-box-stx-example)
(provide
  hn-tag-1-list)
(provide #/own-contract-out
  hn-tag-1-list?
  hn-tag-1-list-stx-example)
(provide
  hn-tag-1-vector)
(provide #/own-contract-out
  hn-tag-1-vector?
  hn-tag-1-vector-stx-example)
(provide
  hn-tag-1-prefab)
(provide #/own-contract-out
  hn-tag-1-prefab?
  hn-tag-1-prefab-key
  hn-tag-1-prefab-stx-example)
(provide
  hn-tag-1-token-of-syntax)
(provide #/own-contract-out
  hn-tag-1-token-of-syntax?
  hn-tag-1-token-of-syntax-token)
(provide
  hn-tag-2-list*)
(provide #/own-contract-out
  hn-tag-2-list*?
  hn-tag-2-list*-stx-example)
(provide
  hn-tag-unmatched-closing-bracket)
(provide #/own-contract-out
  hn-tag-unmatched-closing-bracket?)
(provide
  hn-tag-nest)
(provide #/own-contract-out
  hn-tag-nest?)
(provide
  hn-tag-other)
(provide #/own-contract-out
  hn-tag-other?
  hn-tag-other-val
  parse-list*-tag
  hn-expr/c
  unlabeled-hn-expr-with-degree-1/c
  s-expr-stx->hn-expr
  hn-expr-forget-nests
  hn-expr->s-expr-stx-list)


; NOTE DEBUGGABILITY: These are here for debugging.
(ifc debugging-in-inexpensive-ways
  (begin
    ; TODO: Make these use `only-in`.
    (require racket/contract)
    (require lathe-comforts/contract)
    (require punctaffy/hypersnippet/hypernest)
    (require punctaffy/hypersnippet/hypertee)
    (require punctaffy/hypersnippet/snippet)
    (define/own-contract (verify-ht ht)
      (->
        (and/c hypertee?
          (by-own-method/c ht #/hypertee/c #/hypertee-get-dim-sys ht))
        any/c)
      ht)
    (define/own-contract (verify-hn hn)
      (->
        (and/c hypernest?
          (by-own-method/c hn
            (hypernest/c (hypertee-snippet-format-sys)
              (hypernest-get-dim-sys hn))))
        any/c)
      hn))
  (begin
    (define-syntax-rule (verify-ht ht) ht)
    (define-syntax-rule (verify-hn hn) hn)))


; We're taking this approach:
;
;
; Conceptually, we treat the program's syntax as a degree-1 hypernest
; built up from a sequential encoding. That is, the program's syntax
; is an arrangement of bumps and holes, and each of the bumps can have
; its own bumps and holes, and each of the holes can have its own
; holes (but not bumps). Bumps can be of any degree, and holes can be
; of any degree less than the degree of their containing bump (if any)
; or of any degree less than the degree of the overall degree-1
; hypernest (so degree 0). These conditions ensure that the bumps and
; holes can always be flattened into a sequence of degree-annotated
; opening and closing brackets. Each bump will be associated with a
; data value. The only overall hole in the hypernest -- the degree-0
; one -- will essentially represent "end of file" and will only be
; associated with a trivial data value.
;
; Since we're in Racket, our syntax transformers will take
; s-expression-shaped syntax objects as input like usual. When we
; write a syntax transformer where we care to process
; higher-dimensional syntax, we will explicitly convert these syntax
; objects to degree-1 hypernests using a special macroexpansion
; procedure called `s-expr-stx->hn-expr`. We call the degree-1
; hypernests "hn-expressions" when we use them for syntax this way.
; (Note that s-expressions have a degree-1 hypersnippet shape already,
; so the business with the degree-0 hole -- the fact that it will only
; contain a trivial value -- can be kept implicit.)
;
; We could design `s-expr-stx->hn-expr` to understand specific
; syntaxes as higher-dimensional brackets, but we don't do that.
; Instead, we perform a kind of macroexpansion, allowing users to
; define their own syntax-object-to-hn-expression transformers. These
; are a lot like reader extensions, since they create
; higher-dimensional syntax out of a lower-dimensional encoding.
;
;
; Of all the Racket syntax transformers that will invoke
; `s-expr-stx->hn-expr`, the most familiar will be ones that imitate
; `quasiquote` or `quasisyntax`. Unfortunately, these aren't
; necessarily the easiest examples to talk about because they run up
; against some additional concerns:
;
;   - While the `quasiquote` and `quasisyntax` operators have degree-2
;     hypersnippet syntax as the literal part of their input, their
;     completed result values are still degree-1 s-expression-shaped
;     data. When trying to understand the concept of a degree-2
;     hypersnippet, the degree-1 result data may be a red herring.
;
;   - Since `quasiquote` and `quasisyntax` are operations that are
;     useful in Racket code, and since they're operations that are
;     meant for quoting Racket code, they should be able to quote
;     themselves. This confronts us with the need to nest hypernests,
;     which hypernests are capable of, but it also confronts us with
;     the need to preserve the exact syntax that was used to specify
;     the nested operation's brackets, since that syntax needs to be
;     incorporated verbatim into the degree-1 result data. After all,
;     it is being *quoted*.
;
; If we could pick another operation to focus on instead, we might be
; able to take a more straightforward path. However, `quasiquote` and
; `quasisyntax` really are the main motivating examples, so we're
; facing these issues head-on.
;
; For the quotation to work, our hn-expressions' higher-dimensional
; structure is going to *preserve* the s-expressions we built it up
; out of. This way, operators like `quasiquote` and `quasisyntax` can
; round-trip them back to s-expressions.
;
; It's not just `quasiquote` and `quasisyntax` that will benefit from
; this round-tripping. The Racket compiler and just about all existing
; Racket syntaxes are designed to take s-expressions as input, so
; programmers will still have many reasons to generate them.
;
;
; To incorporate that round-tripping data into our hypernest format,
; we will treat occurrences of opening brackets as bumps just like we
; would otherwise, but the data we associate with a degree-N bump will
; generally include a degree-infinity hypernest with a single degree-N
; hole shaped like the bump, and with each hole of that hole
; containing a single hole of the same shape. This is just the right
; shape to be degree-N-concatenated in between the bump's interior and
; the surrounding hypernest data in order to flatten the bumps back
; into s-expression-shaped data.
;
; (The notion of infinity we're using here is that of
; `extended-with-top-dim-sys`.)
;
; When we interpret an s-expression as a hypernest, the data we can
; usually encode in an s-expression also remains. Our hypernest-based
; encoding has analogues for:
;
;   - Embedded datums. We represent these with another kind of
;     degree-0 bump.
;
;   - Brackets introducing lists, improper lists, vectors, and
;     prefabricated structs. We represent these with other kinds of
;     degree-1 bump.
;
; These bumps have interiors like any other bumps, but they're empty
; and can be safely ignored; they contan no bumps of their own.



; TODO: See if we should add this to Lathe Comforts.
(define (maybe-or a get-b)
  (mat a (just a) (just a)
  #/get-b))

(define/own-contract (syntax-local-maybe identifier)
  (-> any/c maybe?)
  (if (identifier? identifier)
    (w- dummy (box #/trivial)
    #/w- local (syntax-local-value identifier #/fn dummy)
    #/if (eq? local dummy)
      (nothing)
      (just local))
    (nothing)))

(define (ht-bracs-n-d ds n-d degree . brackets)
  (w- n-d (fn d #/dim-sys-morphism-sys-morph-dim n-d d)
  #/hypertee-from-brackets ds (n-d degree)
    (list-map brackets #/fn bracket
      (mat bracket (htb-labeled d data) (htb-labeled (n-d d) data)
      #/mat bracket (htb-unlabeled d) (htb-unlabeled (n-d d))
      #/htb-unlabeled (n-d bracket)))))

(define (hypernest-from-brackets-n-d* ds n-d degree brackets)
  (w- n-d (fn d #/dim-sys-morphism-sys-morph-dim n-d d)
  #/hypernest-from-brackets ds degree
    (list-map brackets #/fn bracket
      (mat bracket (hnb-open d data) (hnb-open (n-d d) data)
      #/mat bracket (hnb-labeled d data) (hnb-labeled (n-d d) data)
      #/mat bracket (hnb-unlabeled d) (hnb-unlabeled (n-d d))
      #/hnb-unlabeled (n-d bracket)))))

(define (hn-bracs-n-d* ds n-d degree . brackets)
  (hypernest-from-brackets-n-d* ds n-d degree brackets))

(define (hn-bracs-n-d ds n-d degree . brackets)
  (hypernest-from-brackets-n-d* ds n-d
    (dim-sys-morphism-sys-morph-dim n-d degree)
    brackets))

(define (hypernest-join-0 ds n-d d elems)
  (hypernest-join-list-and-tail-along-0 ds elems
    (hn-bracs-n-d ds n-d d #/hnb-labeled 0 #/trivial)))

(define
  (snippet-sys-snippet-set-degree-and-bind-highest-degrees
    ss d snippet hv-to-suffix)
  (w- ds (snippet-sys-dim-sys ss)
  #/w- intermediate-d (snippet-sys-snippet-degree ss snippet)
  #/dissect
    (snippet-sys-snippet-set-degree-maybe ss d
      (snippet-sys-snippet-bind-selective ss
        (snippet-sys-snippet-select-if-degree ss snippet
        #/fn candidate
          (dim-sys-dim<=? ds d candidate))
      #/fn hole data
        (selectable-map data #/fn data
          (dissect
            (snippet-sys-snippet-set-degree-maybe ss intermediate-d
              (hv-to-suffix hole data))
            (just suffix)
            suffix))))
    (just result)
    result))



(define en-ds (extended-with-top-dim-sys #/nat-dim-sys))
(define en-n-d (extend-with-top-dim-sys-morphism-sys #/nat-dim-sys))


; This structure type property indicates a syntax's behavior as the
; kind of macro expected by `s-expr-stx->hn-expr`.
(define-imitation-simple-generics
  dedicated-hn-builder-syntax?
  hn-builder-syntax-impl?
  (#:method dedicated-hn-builder-syntax-expand (#:this) () ())
  prop:hn-builder-syntax
  make-hn-builder-syntax-impl
  'hn-builder-syntax
  'hn-builder-syntax-impl
  (list))


; Each of these tags can occur as a bump of the indicated degree. They
; represent data that was carried over from the original
; s-expression-shaped Racket syntax objects when they were converted
; to hn-expressions. The `hn-tag-0-s-expr-stx` can potentially contain
; an entire subtree in Racket syntax object form, but usually the
; layers are broken up into separate `hn-tag-1-list` nodes. Instead,
; an `hn-tag-0-s-expr-syntax` is usually used just for miscellaneous
; atomic values occurring in the syntax, like symbols and datums.
;
(define-imitation-simple-struct
  (hn-tag-0-s-expr-stx? hn-tag-0-s-expr-stx-stx)
  unguarded-hn-tag-0-s-expr-stx
  'hn-tag-0-s-expr-stx (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hn-tag-0-s-expr-stx? (-> any/c boolean?))
(ascribe-own-contract hn-tag-0-s-expr-stx-stx
  (-> hn-tag-0-s-expr-stx? syntax?))
(define-match-expander-attenuated
  attenuated-hn-tag-0-s-expr-stx
  unguarded-hn-tag-0-s-expr-stx
  [stx syntax?]
  #t)
(define-match-expander-from-match-and-make
  hn-tag-0-s-expr-stx
  unguarded-hn-tag-0-s-expr-stx
  attenuated-hn-tag-0-s-expr-stx
  attenuated-hn-tag-0-s-expr-stx)
(define-imitation-simple-struct
  (hn-tag-1-box? hn-tag-1-box-stx-example)
  unguarded-hn-tag-1-box
  'hn-tag-1-box (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hn-tag-1-box? (-> any/c boolean?))
(ascribe-own-contract hn-tag-1-box-stx-example
  (-> hn-tag-1-box? syntax?))
(define-match-expander-attenuated
  attenuated-hn-tag-1-box
  unguarded-hn-tag-1-box
  [stx-example syntax?]
  #t)
(define-match-expander-from-match-and-make
  hn-tag-1-box
  unguarded-hn-tag-1-box
  attenuated-hn-tag-1-box
  attenuated-hn-tag-1-box)
(define-imitation-simple-struct
  (hn-tag-1-list? hn-tag-1-list-stx-example)
  unguarded-hn-tag-1-list
  'hn-tag-1-list (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hn-tag-1-list? (-> any/c boolean?))
(ascribe-own-contract hn-tag-1-list-stx-example
  (-> hn-tag-1-list? syntax?))
(define-match-expander-attenuated
  attenuated-hn-tag-1-list
  unguarded-hn-tag-1-list
  [stx-example syntax?]
  #t)
(define-match-expander-from-match-and-make
  hn-tag-1-list
  unguarded-hn-tag-1-list
  attenuated-hn-tag-1-list
  attenuated-hn-tag-1-list)
(define-imitation-simple-struct
  (hn-tag-1-vector? hn-tag-1-vector-stx-example)
  unguarded-hn-tag-1-vector
  'hn-tag-1-vector (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hn-tag-1-vector? (-> any/c boolean?))
(ascribe-own-contract hn-tag-1-vector-stx-example
  (-> hn-tag-1-vector? syntax?))
(define-match-expander-attenuated
  attenuated-hn-tag-1-vector
  unguarded-hn-tag-1-vector
  [stx-example syntax?]
  #t)
(define-match-expander-from-match-and-make
  hn-tag-1-vector
  unguarded-hn-tag-1-vector
  attenuated-hn-tag-1-vector
  attenuated-hn-tag-1-vector)
(define-imitation-simple-struct
  (hn-tag-1-prefab? hn-tag-1-prefab-key hn-tag-1-prefab-stx-example)
  unguarded-hn-tag-1-prefab
  'hn-tag-1-prefab (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hn-tag-1-prefab? (-> any/c boolean?))
(ascribe-own-contract hn-tag-1-prefab-key
  (-> hn-tag-1-prefab? prefab-key?))
(ascribe-own-contract hn-tag-1-prefab-stx-example
  (-> hn-tag-1-prefab? syntax?))
(define-match-expander-attenuated
  attenuated-hn-tag-1-prefab
  unguarded-hn-tag-1-prefab
  [key prefab-key?]
  [stx-example syntax?]
  #t)
(define-match-expander-from-match-and-make
  hn-tag-1-prefab
  unguarded-hn-tag-1-prefab
  attenuated-hn-tag-1-prefab
  attenuated-hn-tag-1-prefab)
(define-imitation-simple-struct
  (hn-tag-1-token-of-syntax? hn-tag-1-token-of-syntax-token)
  unguarded-hn-tag-1-token-of-syntax
  'hn-tag-1-token-of-syntax (current-inspector)
  (auto-write)
  (auto-equal))
(ascribe-own-contract hn-tag-1-token-of-syntax? (-> any/c boolean?))
(ascribe-own-contract hn-tag-1-token-of-syntax-token
  (-> hn-tag-1-token-of-syntax?
    (token-of-syntax-with-free-vars<=/c #/set 'contents)))
(define-match-expander-attenuated
  attenuated-hn-tag-1-token-of-syntax
  unguarded-hn-tag-1-token-of-syntax
  [token (token-of-syntax-with-free-vars<=/c #/set 'contents)]
  #t)
(define-match-expander-from-match-and-make
  hn-tag-1-token-of-syntax
  unguarded-hn-tag-1-token-of-syntax
  attenuated-hn-tag-1-token-of-syntax
  attenuated-hn-tag-1-token-of-syntax)
(define-imitation-simple-struct
  (hn-tag-2-list*? hn-tag-2-list*-stx-example)
  unguarded-hn-tag-2-list*
  'hn-tag-2-list* (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hn-tag-2-list*? (-> any/c boolean?))
(ascribe-own-contract hn-tag-2-list*-stx-example
  (-> hn-tag-2-list*? syntax?))
(define-match-expander-attenuated
  attenuated-hn-tag-2-list*
  unguarded-hn-tag-2-list*
  [stx-example syntax?]
  #t)
(define-match-expander-from-match-and-make
  hn-tag-2-list*
  unguarded-hn-tag-2-list*
  attenuated-hn-tag-2-list*
  attenuated-hn-tag-2-list*)

; The `hn-tag-unmatched-closing-bracket` tag can occur as a bump of
; degree infinity (in the sense of `(extended-with-top-dim-infinite)`
; in the system `(extended-with-top-dim-sys (nat-dim-sys))`). It
; represents a closing bracket of some degree N. The bump should
; contain the syntax that was parsed to create this closing bracket.
; Its shape (filtering out the content) should be a
; `snippet-sys-snippet-done` for a degree-N hole, and beyond that hole
; should be the syntax that lies beyond this closing bracket.
;
; These tags usually only appear in the intermediate stages of
; expanding an hn-expression. A successful expansion will eventually
; replace them all with `hn-tag-nest` bumps. If any
; `hn-tag-unmatched-closing-bracket` bump remains after that, that's
; an indication that there's an unmatched bracket error.
;
(define-imitation-simple-struct
  (hn-tag-unmatched-closing-bracket?)
  hn-tag-unmatched-closing-bracket
  'hn-tag-unmatched-closing-bracket (current-inspector)
  (auto-write)
  (auto-equal))
(ascribe-own-contract hn-tag-unmatched-closing-bracket?
  (-> any/c boolean?))

; The `hn-tag-nest` tag can occur as a bump of degree infinity
; (in the sense of `(extended-with-top-dim-infinite)` in the system
; `(extended-with-top-dim-sys (nat-dim-sys))`). It represents an
; unlabeled nested region of some degree N. The bump should contain
; the syntax that was parsed to create the brackets around this nested
; region. Its shape (filtering out that content) should be a
; `snippet-sys-snippet-dine` for a degree-N hole, and beyond that hole
; should be the syntax that lies in the interior of this region.
;
; These are essentially supposed to represent bumps in the hypernest,
; but they're represented in a slightly higher-dimensional format to
; let us round-trip the bracket syntax back to s-expressions when
; desired. If the preserved s-expression syntax (the interior of the
; bump) is removed from all of these, they can be replaced with
; degree-N hypernest bumps.
;
(define-imitation-simple-struct
  (hn-tag-nest?)
  hn-tag-nest
  'hn-tag-nest (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hn-tag-nest? (-> any/c boolean?))

; This is a value designated to let hn-expression users put custom
; kinds of data into an hn-expression. It can occur as a bump or a
; hole of any degree.
(define-imitation-simple-struct
  (hn-tag-other? hn-tag-other-val)
  hn-tag-other
  'hn-tag-other (current-inspector) (auto-write) (auto-equal))
(ascribe-own-contract hn-tag-other? (-> any/c boolean?))
(ascribe-own-contract hn-tag-other-val (-> hn-tag-other? any/c))

(define example-list*-shape
  (w- ds en-ds
  #/w- n-d en-n-d
  #/ht-bracs-n-d ds n-d 2
    (htb-labeled 1 #/trivial)
    0
    (htb-labeled 1 #/trivial)
    0
    (htb-labeled 0 #/trivial)))

(define (is-list*-shape? bump-interior-shape)
  (w- ds en-ds
  #/w- sfs (hypertee-snippet-format-sys)
  #/w- ss (hypernest-snippet-sys sfs ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/dlog 'hqq-k1 bump-interior-shape example-list*-shape
  #/just? #/snippet-sys-snippet-zip-map shape-ss
    bump-interior-shape
    example-list*-shape
    (fn hole bump-data example-data
      (dlog 'hqq-k2
      #/dissect example-data (trivial)
      #/just #/trivial))))

(define/own-contract (parse-list*-tag bump-degree tag tails)
  
  ; TODO SPECIFIC: We should constrain this contract more. It should
  ; be
  ;
  ; (->i
  ;   (
  ;     [bump-degree (dim-sys-dim/c en-ds)]
  ;     [tag any/c]
  ;     [tails (bump-degree)
  ;       (w- ss (hypernest-snippet-sys en-sfs en-ds)
  ;       #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  ;       #/and/c (snippet-sys-snippetof/c ss)
  ;       #/by-own-method/c #:obstinacy (flat-obstinacy) tails
  ;       #/w- d (snippet-sys-snippet-degree ss tails)
  ;       #/w- has-d/c (snippet-sys-snippet-with-degree/c ss d)
  ;       #/snippet-sys-snippetof/ob-c ss (flat-obstinacy) #/fn hole
  ;         (if
  ;           (dim-sys-dim<? en-ds
  ;             (snippet-sys-snippet-degree shape-ss hole)
  ;             bump-degree)
  ;           (and/c
  ;             has-d/c
  ;             (snippet-sys-snippet-fitting-shape/c ss hole))
  ;           any/c))]
  ;   [_ (bump-degree tails)
  ;     (w- ss (hypernest-snippet-sys en-sfs en-ds)
  ;     #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  ;     #/w- d (snippet-sys-snippet-degree ss tails)
  ;     #/w- has-d/c (snippet-sys-snippet-with-degree/c ss d)
  ;     #/w- exprlike/c
  ;       (and/c has-d/c
  ;         (snippet-sys-snippetof/ob-c ss (flat-obstinacy) #/fn hole
  ;           (if
  ;             (dim-sys-dim=0? en-ds
  ;               (snippet-sys-snippet-degree shape-ss hole))
  ;             trivial?
  ;             any/c)))
  ;     #/maybe/c #/list/c syntax?
  ;       (and/c exprlike/c exprlike/c has-d/c))])
  ;
  ; In order for this to make complete sense as a contract, we should
  ; probably be exporting `en-sfs` and `en-ds`. We might want to
  ; export the derived `ss` and `shape-ss` as well.
  ;
  (-> any/c any/c any/c
    (maybe/c #/list/c syntax? any/c any/c any/c))
  
  (w- ds en-ds
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- n-d en-n-d
  #/expect tag (hn-tag-2-list* stx-example) (nothing)
  #/expect
    (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 2)
      bump-degree)
    #t
    (error "Encountered an hn-tag-2-list* bump with a degree other than 2")
  #/expect (snippet-sys-snippet->maybe-shape ss tails)
    (just tails)
    (error "Encountered an hn-tag-2-list* bump with contents in its interior")
  
  ; TODO: This begs for an abstraction. Perhaps ideally, there would
  ; be a match pattern that had hyperbrackets so we could write
  ; something like...
  ;
  ;   #/expect tails
  ;     (taffy-hn-expr-shape
  ;       (^<d 2 (^>d 1 list*-elems) (^>d 1 list*-tail))
  ;       tail)
  ;     (error "Encountered...")
  ;
  #/expect (is-list*-shape? tails) #t
    (error "Encountered an hn-tag-2-list* bump which didn't have precisely two degree-1 holes")
  #/dissect tails
    (hypertee-furl _ #/hypertee-coil-hole _ _ list*-elems
      (hypertee-furl _ #/hypertee-coil-hole _ _ tails
        (hypertee-furl _ #/hypertee-coil-zero)))
  #/dissect tails
    (hypertee-furl _ #/hypertee-coil-hole _ _ list*-tail
      (hypertee-furl _ #/hypertee-coil-hole _ _ tails
        (hypertee-furl _ #/hypertee-coil-zero)))
  #/dissect tails
    (hypertee-furl _ #/hypertee-coil-hole _ _ tail
      (hypertee-furl _ #/hypertee-coil-zero))
  
  #/just #/list stx-example list*-elems list*-tail tail))

(define/own-contract (hn-expr/c)
  (-> flat-contract?)
  (w- ds en-ds
  #/w- n-d en-n-d
  #/w- sfs (hypertee-snippet-format-sys)
  #/w- ss (hypernest-snippet-sys sfs ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/rename-contract
    (hypernestof/ob-c sfs ds (flat-obstinacy)
      (fn bump-interior-shape
        (w- d
          (snippet-sys-snippet-degree shape-ss bump-interior-shape)
        #/or/c hn-tag-other?
          (if (dim-sys-dim=0? ds d)
            hn-tag-0-s-expr-stx?
          #/if
            (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 1)
              d)
            (or/c
              hn-tag-1-box?
              hn-tag-1-list?
              hn-tag-1-vector?
              hn-tag-1-prefab?
              hn-tag-1-token-of-syntax?)
          #/if
            (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 2)
              d)
            (if (is-list*-shape? bump-interior-shape)
              hn-tag-2-list*?
              none/c)
          #/if (dim-sys-dim=? ds (extended-with-top-dim-infinite) d)
            (expect
              (snippet-sys-snippet-undone shape-ss
                bump-interior-shape)
              (just undone)
              none/c
            #/dissect undone
              (list
                (extended-with-top-dim-infinite)
                represented-bump-interior-shape
                (trivial))
            #/or/c
              hn-tag-unmatched-closing-bracket?
              hn-tag-nest?)
            none/c)))
      (fn hole any/c))
    '(hn-expr/c)))

(define/own-contract (unlabeled-hn-expr-with-degree-1/c)
  (-> flat-contract?)
  (w- ds en-ds
  #/w- n-d en-n-d
  #/w- sfs (hypertee-snippet-format-sys)
  #/w- ss (hypernest-snippet-sys sfs ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/rename-contract
    (and/c
      (snippet-sys-snippet-with-degree=/c ss
        (dim-sys-morphism-sys-morph-dim n-d 1))
      (hn-expr/c)
      (snippet-sys-snippetof/ob-c ss (flat-obstinacy) #/fn hole
        (if
          (dim-sys-dim=0? ds
            (snippet-sys-snippet-degree shape-ss hole))
          trivial?
          none/c)))
    `(unlabeled-hn-expr-with-degree-1/c)))


; This recursively converts the given Racket syntax object into a
; degree-1 hypernest. It performs a kind of macroexpansion on lists
; that begin with an identifier with an appropriate
; `syntax-local-value` binding. For everything else, it uses
; particular data structures in the bumps of the result hypernest to
; represent the other atoms, proper lists, improper lists, vectors,
; and prefab structs it encounters.
;
(define/own-contract (s-expr-stx->hn-expr err-dsl-stx stx)
  (-> syntax? syntax? #/unlabeled-hn-expr-with-degree-1/c)
  (dlog 'hqq-b1
  #/w- ds en-ds
  #/w- n-d en-n-d
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- invoke-expand
    (fn expand err-dsl-stx stx
      ; TODO: See if we can call this more like a Racket syntax
      ; transformer. If we can, we'll want to approximate this
      ; process:
      ;
      ;   - Disarm `stx`.
      ;
      ;   - Remove any `'taint-mode` and `'certify-mode` syntax
      ;     properties from `stx`.
      ;
      ;   - Rearm the result, and apply syntax properties to the
      ;     result that correspond to the syntax properties of `stx`.
      ;     It's not really clear how this would be performed, since
      ;     the result is an hn-expression that may "contain" several
      ;     encoded Racket syntax objects (their trees encoded as
      ;     concentric degree-1 bumps and their leaves as degree-0
      ;     bumps) that are peers of each other, as well as several
      ;     bumps that have nothing to do with this encoding of Racket
      ;     syntax objects.
      ;
      (expand err-dsl-stx stx))
  
  ; If `stx` is shaped like `op` or `(op . args)` where `op` is bound
  ; to a suitable syntax transformer according to
  ; `syntax-local-value`, then we invoke it on `stx`. (Note that we
  ; don't consider anything to be a suitable syntax transformer if
  ; `stx` is shaped like `op`, but we do consider certain syntax
  ; transformers to be reserving an opportunity to have behavior here
  ; in the future, so we treat those as an error.)
  ;
  #/mat
    (syntax-parse stx
      [ (op:id . args)
        (dlog 'hqq-b1.1 #'op
        #/w- op-stx #'op
        #/maybe-bind (syntax-local-maybe op-stx) #/fn op-val
        #/assert-known-hn-builder-syntax-maybe
          err-dsl-stx op-stx op-val)]
      [op:id
        (dlog 'hqq-b1.2
        #/w- op-stx #'op
        #/maybe-bind (syntax-local-maybe op-stx) #/fn op-val
        #/begin
          (assert-not-hn-builder-syntax err-dsl-stx op-stx op-val)
        #/nothing)]
      [_ (nothing)])
    (just expand)
    (dlog 'hqq-b1.3
    #/invoke-expand expand err-dsl-stx stx)
  
  #/dlog 'hqq-b2
  #/w- process-list
    (fn elems
      (list-map elems #/fn elem
        (s-expr-stx->hn-expr err-dsl-stx elem)))
  ; NOTE: We go to some trouble to detect improper lists here. This is
  ; so we can preserve the metadata of syntax objects occurring in
  ; tail positions partway through the list, which we would lose track
  ; of if we simply used `syntax->list` or `syntax-parse` with a
  ; pattern of `(elem ...)` or `(elem ... . tail)`.
  #/w- s (syntax-e stx)
  #/w- stx-example (datum->syntax-with-everything stx #/list)
  #/dlog 'hqq-b3
  #/w- make-list-layer
    (fn metadata elems
      ; When we call this, `elems` is a list of degree-1 hypernests,
      ; and their degree-0 holes have trivial contents. We
      ; degree-0-concatenate them, and then we degree-1-concatenate a
      ; degree-1 bump around that, holding the given metadata. We
      ; return the degree-1 hypernest that results.
      (dlog 'hqq-c1
      #/snippet-sys-snippet-set-degree-and-bind-highest-degrees ss
        (dim-sys-morphism-sys-morph-dim n-d 1)
        (dlog 'hqq-c2
        #/hn-bracs-n-d ds n-d 2
          (hnb-open 1 metadata)
          (hnb-labeled 1 #/trivial)
          0
          0
        #/hnb-labeled 0 #/trivial)
      #/fn hole data
        (dlog 'hqq-c3
        #/hypernest-join-0 ds n-d 1 elems)))
  
  ; We traverse into boxes.
  #/mat s (box elem)
    (w- elem (s-expr-stx->hn-expr err-dsl-stx elem)
    #/make-list-layer (hn-tag-1-box stx-example) #/list elem)
  
  ; We traverse into proper and improper lists.
  #/dlog 'hqq-b3.1
  #/mat s (list)
    (make-list-layer (hn-tag-1-list stx-example) #/list)
  #/mat s (cons first-elem rest)
    (dlog 'hqq-b3.2
    #/dissect
      (w-loop next
        rev-elems (list #/s-expr-stx->hn-expr err-dsl-stx first-elem)
        rest rest
        
        (mat rest (cons op-stx args)
          (mat
            (maybe-bind (syntax-local-maybe op-stx) #/fn op-val
            #/begin
              (assert-not-hn-builder-syntax err-dsl-stx op-stx op-val)
            #/nothing)
            (just expand)
            (list
              rev-elems
              ; TODO: See if we should convert `rest` to be `syntax?`
              ; here. Note that at the moment, this case should be
              ; unreachable since we the condition always returns
              ; `nothing`. Someday, if and when there's any syntax
              ; transformer we consider to be suitable for processing
              ; in positions other than the first element of their
              ; surrounding list, we might use this code.
              ;
              (just #/invoke-expand expand err-dsl-stx rest))
            (next
              (cons (s-expr-stx->hn-expr err-dsl-stx op-stx)
                rev-elems)
              args))
        #/mat rest (list)
          (list rev-elems (nothing))
          (list
            rev-elems
            ; NOTE: Even though we call the full `s-expr-stx->hn-expr`
            ; operation here, we already know `#'tail` can't be
            ; cons-shaped. Usually it'll be wrapped up as an atom.
            ; However, it could still be expanded as an identifier
            ; syntax, processed as a vector, or processed as a prefab
            ; struct.
            (just #/s-expr-stx->hn-expr err-dsl-stx rest))))
      (list rev-elems maybe-tail)
    #/w- elems (reverse rev-elems)
    #/expect maybe-tail (just tail)
      ; The metadata we pass in here represents the `list` operation,
      ; so its data contains the metadata of `stx` so that clients
      ; processing this hypernest-based encoding of this Racket syntax
      ; can recover this layer of information about it.
      (dlog 'hqq-b3.5
      #/make-list-layer (dlog 'hqq-b3.5.1 #/hn-tag-1-list stx-example) elems)
      ; This is like the proper list case, but this time the metadata
      ; represents an improper list operation (`list*`) rather than a
      ; proper list operation (`list`).
      (snippet-sys-snippet-set-degree-and-bind-highest-degrees ss
        (dim-sys-morphism-sys-morph-dim n-d 1)
        (dlog 'hqq-c2
        #/hn-bracs-n-d ds n-d 2
          
          (hnb-open 2 #/hn-tag-2-list* stx-example)
          1
            (hnb-labeled 1 #/hypernest-join-0 ds n-d 1 elems)
            0
          0
          1
            (hnb-labeled 1 tail)
            0
          0
          0
          
          (hnb-labeled 0 #/trivial))
      #/fn hole data
        data))
  
  ; We traverse into prefab structs.
  #/dlog 'hqq-b4
  #/w- key (prefab-struct-key s)
  #/if key
    (make-list-layer (hn-tag-1-prefab key stx-example)
    #/process-list #/cdr #/vector->list #/struct->vector s)
  
  #/dlog 'hqq-b5
  #/syntax-parse stx
    ; We traverse into vectors.
    [ #(elem ...)
      (w- elems (process-list #/syntax->list #'(elem ...))
        ; This is like the proper list case, but this time the
        ; metadata represents a vector operation (`vector`) rather
        ; than a proper list operation (`list`).
        (make-list-layer (hn-tag-1-vector stx-example) elems))]
    
    [_
      ; We return a degree-1 hypernest with trivial contents in its
      ; degree-0 hole and with a single degree-0 bump that contains
      ; `stx` itself (put in a container so that it can be
      ; distinguished from degree-0 bumps that a user-defined syntax
      ; introduces for a different reason).
      (hn-bracs-n-d ds n-d 1
        (hnb-open 0 #/hn-tag-0-s-expr-stx stx)
        (hnb-labeled 0 #/trivial))]))

; This recursively converts the given Racket syntax object into an
; degree-1 hypernest just like `s-expr-stx->hn-expr`, but it expects
; the outermost layer of the syntax object to be a proper list, and it
; does not represent that list in the result, so the result will
; "splice" all the list's elements in whatever place it's inserted.
;
; TODO: See if we'll ever use this. Right now it's just here as a
; reminder that hn-expressions aren't quite "expressions" so much as
; snippets of expression-like data.
;
(define/own-contract (splicing-s-expr-stx->hn-expr err-dsl-stx stx)
  (-> syntax? syntax? #/hn-expr/c)
  (w- ds en-ds
  #/w- n-d en-n-d
  #/hypernest-join-0 ds n-d 1 #/list-map (syntax->list stx) #/fn elem
    (s-expr-stx->hn-expr err-dsl-stx elem)))

; Given an hn-expression of any degree, removes its `hn-tag-nest`
; bumps, leaving their bracket syntax in their place. This is
; generally useful when parts of the hn-expression may appear in
; quoted contexts, so that they can appear approximately as they did
; before.
;
; TODO: However, if they appear in non-quoted contexts, this can cause
; the hyperbrackets to have to be parsed all over again. This is
; probably going to be rather regrettable for performance. We should
; think about whether there's a way to encode hypernest structure as
; a data structure in syntax; generally, the problem will be that
; syntax taints and scopes won't be propagated into whatever data
; structure we use... unless the data structure we use is made of
; cons-cell-based Racket syntax objects.
;
(define/own-contract (hn-expr-forget-nests hn)
  (-> (hn-expr/c) #/hn-expr/c)
  (dlog 'hqq-l1
  #/w- ds en-ds
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/dissect hn (hypernest-furl _ dropped)
  #/dlog 'hqq-l2
  #/mat dropped (hypernest-coil-hole d tails-shape data tails)
    (dlog 'hqq-l3
    #/hypernest-furl ds #/hypernest-coil-hole d tails-shape data
      (dlog 'hqq-l4
      #/snippet-sys-snippet-map shape-ss tails #/fn d tail
        (hn-expr-forget-nests tail)))
  #/dissect dropped (hypernest-coil-bump d data bump-degree tails)
  #/dlog 'hqq-l5
  #/mat data (hn-tag-nest)
    (dlog 'hqq-l6
    #/dissect
      (snippet-sys-snippet-set-degree-maybe ss d
        (snippet-sys-snippet-bind-selective ss tails #/fn hole data
          (w- hole-degree (snippet-sys-snippet-degree shape-ss hole)
          #/if (dim-sys-dim<? ds hole-degree bump-degree)
            (dissect
              (snippet-sys-snippet-set-degree-maybe ss
                (extended-with-top-dim-infinite)
                data)
              (just tail)
              (selected tail))
            (unselected data))))
      (just tails)
      (hn-expr-forget-nests tails))
    (dlog 'hqq-l7
    #/hypernest-furl ds #/hypernest-coil-bump d data bump-degree
      (dlog 'hqq-l8
      #/w- tails (hn-expr-forget-nests tails)
      #/snippet-sys-snippet-map ss tails #/fn hole data
        (w- hole-degree (snippet-sys-snippet-degree shape-ss hole)
        #/if (dim-sys-dim<? ds hole-degree bump-degree)
          (hn-expr-forget-nests data)
          data)))))

; This converts an hn-expression back into a list of syntax objects,
; as long as it doesn't have any `hn-tag-nest` bumps.
(define/own-contract (hn-expr->s-expr-stx-list hn)
  (-> (unlabeled-hn-expr-with-degree-1/c) #/listof syntax?)
  (w- ds en-ds
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/w- n-d en-n-d
  #/expect
    (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 1)
      (snippet-sys-snippet-degree ss hn))
    #t
    (raise-arguments-error 'hn-expr->s-expr-stx-list
      "expected an hn-expr of degree 1"
      "hn" hn)
  #/dissect hn (hypernest-furl _ dropped)
  #/mat dropped (hypernest-coil-hole _ _ data tails)
    (expect data (trivial)
      (error "Expected an hn-expr with a trivial value in its degree-0 hole")
    #/list)
  #/dissect dropped (hypernest-coil-bump _ data bump-degree tails)
  #/mat data (hn-tag-0-s-expr-stx stx)
    (expect (dim-sys-dim=0? ds bump-degree) #t
      (error "Encountered an hn-tag-0-s-expr-stx bump with a degree other than 0")
    #/cons stx #/hn-expr->s-expr-stx-list tails)
  #/w- process-splicing-stx-listlike
    (fn list->syntax-list
      (expect
        (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 1)
          bump-degree)
        #t
        (error "Encountered a list-like hn-tag-1-... bump with a degree other than 1")
      #/w- elems
        (snippet-sys-snippet-map-selective ss
          (snippet-sys-snippet-select-if-degree ss tails #/fn d
            (dim-sys-dim=0? ds d))
        #/fn hole tail
          (trivial))
      #/dissect (hypernest-get-hole-zero-maybe tails) (just tail)
      #/append
        (list->syntax-list #/hn-expr->s-expr-stx-list elems)
        (hn-expr->s-expr-stx-list tail)))
  #/w- process-listlike
    (fn stx-example list->whatever
      (process-splicing-stx-listlike #/fn lst
        (list #/datum->syntax-with-everything stx-example
          (list->whatever lst))))
  #/mat data (hn-tag-1-box stx-example)
    (process-listlike stx-example #/fn lst
      (expect lst (list elem)
        (error "Expected an hn-tag-1-box bump to have exactly one Racket syntax object in the box")
      #/box-immutable elem))
  #/mat data (hn-tag-1-list stx-example)
    (process-listlike stx-example #/fn lst lst)
  #/mat data (hn-tag-1-vector stx-example)
    (process-listlike stx-example #/fn lst
      (vector->immutable-vector #/list->vector lst))
  #/mat data (hn-tag-1-prefab key stx-example)
    (process-listlike stx-example #/fn lst
      (apply make-prefab-struct key lst))
  #/mat data (hn-tag-1-token-of-syntax token-of-syntax)
    (process-splicing-stx-listlike #/fn lst
      (token-of-syntax->syntax-list token-of-syntax
        (hash 'contents lst)))
  #/mat (parse-list*-tag bump-degree data tails)
    (just #/list stx-example list*-elems list*-tail tail)
    (w- list*-elems (hn-expr->s-expr-stx-list list*-elems)
    #/expect (hn-expr->s-expr-stx-list list*-tail)
      (list list*-tail)
      (error "Expected an hn-tag-2-list* bump to have exactly one Racket syntax object in its tail when converting an hn-expression to a list of Racket syntax objects")
    #/cons
      (datum->syntax-with-everything stx-example
        ; NOTE: Ironically, we don't actually use `list*` here.
        (append list*-elems list*-tail))
      (hn-expr->s-expr-stx-list tail))
  #/mat data (hn-tag-nest)
    (error "Encountered an hn-tag-nest bump when converting an hn-expression to a list of Racket syntax objects")
  #/error "Encountered an unsupported bump when converting an hn-expression to a list of Racket syntax objects"))


; This takes an hn-expression which may contain
; `hn-tag-unmatched-closing-bracket` values on some of its bumps
; (which, by the structure of an hn-expression, must have interiors
; shaped like `snippet-sys-snippet-done` snippets for holes of various
; degrees N), and it returns a degree-(`opening-degree`) hypernest
; where each such bump with a corresponding degree N that's greater
; than zero and less than `opening-degree` is converted to a hole of
; degree N. Each of the new holes of degree N contains a
; degree-infinity hypernest encoding the syntactic details of the
; closing bracket itself, and in that one's degree-N hole is a
; degree-N hypernest encoding the area beyond the closing bracket.
;
; The resulting hypernest is similar to an hn-expression except for
; the fact that its degree may be greater than 1 and it may have these
; extra holes of degree greater than 0.
;
(define (unmatched-brackets->holes opening-degree hn-expr)
  (dlog 'hqq-g1
  #/w- ds en-ds
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/w- n-d en-n-d
  #/expect
    (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 1)
      (snippet-sys-snippet-degree ss hn-expr))
    #t
    (error "Expected hn-expr to be a hypernest of degree 1")
  #/w- first-d-not-to-process opening-degree
  #/w-loop next
    hn-expr hn-expr
    target-d opening-degree
    first-d-to-process (dim-sys-morphism-sys-morph-dim n-d 1)
    
    (dlog 'hqq-g2
    #/begin (verify-hn hn-expr)
    #/dissect hn-expr (hypernest-furl _ dropped)
    #/mat dropped (hypernest-coil-hole d tails-shape data tails)
      (hypernest-furl ds #/hypernest-coil-hole target-d
        tails-shape
        data
        (snippet-sys-snippet-map shape-ss tails #/fn hole tail
          (w- d (snippet-sys-snippet-degree shape-ss hole)
          #/next tail target-d
            (dim-sys-dim-max ds first-d-to-process d))))
    #/dissect dropped
      (hypernest-coil-bump overall-degree data bump-degree
        bracket-and-tails)
    #/dlog 'hqq-g3 overall-degree bump-degree (snippet-sys-snippet-degree ss bracket-and-tails)
    #/begin (verify-hn bracket-and-tails)
    #/begin
      (snippet-sys-snippet-each ss bracket-and-tails
      #/fn hole tail #/begin0 (void)
        (w- d (snippet-sys-snippet-degree shape-ss hole)
        #/when (dim-sys-dim<? ds d bump-degree)
          (dlog 'hqq-g3.1 (snippet-sys-snippet-degree ss tail)
          #/verify-hn tail)))
    #/w- ignore
      (fn
        (hypernest-furl ds #/hypernest-coil-bump
          target-d
          data
          bump-degree
        #/next
          (snippet-sys-snippet-map ss bracket-and-tails #/fn hole tail
            (w- d (snippet-sys-snippet-degree shape-ss hole)
            #/if
              (and
                (dim-sys-dim<=? ds bump-degree d)
                (dim-sys-dim<? ds d first-d-to-process))
              tail
            #/next tail
              (dim-sys-dim-max ds target-d d)
              (dim-sys-dim-max ds first-d-to-process d)))
          (dim-sys-dim-max ds target-d bump-degree)
          (dim-sys-dim-max ds first-d-to-process bump-degree)))
    #/expect data (hn-tag-unmatched-closing-bracket) (ignore)
    #/expect
      (dim-sys-dim=? ds (extended-with-top-dim-infinite) bump-degree)
      #t
      (error "Encountered an hn-tag-unmatched-closing-bracket bump of finite degree")
    #/expect
      (snippet-sys-snippet-undone shape-ss
        (hypernest-shape ss bracket-and-tails))
      (just undone-tails)
      (error "Encountered an hn-tag-unmatched-closing-bracket bump whose interior wasn't shaped like a snippet system identity element")
    #/dissect undone-tails
      (list
        (extended-with-top-dim-infinite)
        other-tails
        represented-exterior-tail)
    #/w- represented-bump-degree
      (snippet-sys-snippet-degree shape-ss other-tails)
    ; NOTE: By mapping selectively here, we keep the
    ; `represented-exterior-tail` value intact in `bracket-syntax`.
    #/w- bracket-syntax
      (snippet-sys-snippet-map-selective ss
        (snippet-sys-snippet-select-if-degree<
          ss represented-bump-degree bracket-and-tails)
        (fn hole data
          (trivial)))
    #/expect
      (and
        (dim-sys-dim<=? ds
          first-d-to-process
          represented-bump-degree)
        (dim-sys-dim<? ds
          represented-bump-degree
          first-d-not-to-process))
      #t
      (ignore)
    #/hypernest-furl ds #/hypernest-coil-hole target-d
      (snippet-sys-snippet-map shape-ss other-tails #/fn hole tail
        (trivial))
      bracket-syntax
      (snippet-sys-snippet-map shape-ss other-tails #/fn hole tail
        (w- d (snippet-sys-snippet-degree shape-ss hole)
        #/next tail target-d
          (dim-sys-dim-max ds first-d-to-process d))))))

(define (^<>d-expand op err-dsl-stx stx)
  (dlog 'hqq-f2
  #/w- ds en-ds
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/w- n-d en-n-d
  #/dlog 'hqq-f3
  #/syntax-parse stx
    [_:id
      ; If this syntax transformer is used in an identifier position,
      ; we just expand as though the identifier isn't bound to a
      ; syntax transformer at all.
      ;
      ; TODO: See if we'll ever need to rely on this functionality.
      ;
      (hn-bracs-n-d ds n-d 1 (hnb-open 0 #/hn-tag-0-s-expr-stx stx)
      #/hnb-labeled 0 #/trivial)]
  #/ (_:id . _)
  #/dissect (taffy-notation-akin-to-^<>d-parse op stx)
    (hash-table
      ['lexical-context lexical-context-stx]
      ['direction direction]
      ['degree degree-stx]
      ['contents contents]
      ['token-of-syntax token-of-syntax])
  #/w- degree
    (dim-sys-morphism-sys-morph-dim n-d #/syntax-e degree-stx)
  #/dlog 'hqq-f4
  #/w- interior-and-closing-brackets
    (verify-hn #/unmatched-brackets->holes degree
    #/hypernest-join-0 ds n-d 1
    #/list-map contents #/fn item
      (verify-hn #/s-expr-stx->hn-expr err-dsl-stx item))
  #/dlog 'hqq-f5
  #/w- closing-brackets
    (hypernest-shape ss interior-and-closing-brackets)
  #/dlog 'hqq-f6
  #/hypernest-furl ds
  #/dlog 'hqq-f7
  #/hypernest-coil-bump
    (dim-sys-morphism-sys-morph-dim n-d 1)
    (mat direction '< (hn-tag-nest)
      (dissect direction '> (hn-tag-unmatched-closing-bracket)))
    (extended-with-top-dim-infinite)
    ; This is the syntax for the bracket itself, everything in the
    ; interior of the bump this bracket represents (noted at
    ; NOTE INSIDE), and everything beyond the closing brackets of this
    ; bracket (noted at NOTE BEYOND).
    (dlog 'hqq-f8
    #/snippet-sys-snippet-join-selective ss
    #/hn-bracs-n-d* ds n-d (extended-with-top-dim-infinite)
      (hnb-open 1 #/hn-tag-1-token-of-syntax
        (token-of-syntax-substitute token-of-syntax
          (hash
            
            'lexical-context
            (syntax->token-of-syntax lexical-context-stx)
            
            'degree (syntax->token-of-syntax degree-stx))))
      
      (hnb-labeled 1
      #/selected
      #/snippet-sys-snippet-join-selective ss
      #/snippet-sys-snippet-done ss (extended-with-top-dim-infinite)
        (snippet-sys-snippet-map shape-ss closing-brackets
          (fn hole data
            (w- d (snippet-sys-snippet-degree shape-ss hole)
            #/if (dim-sys-dim=0? ds d)
              (dissect data (trivial)
              #/unselected #/trivial)
            ; NOTE BEYOND: At this point `data` must be a
            ; degree-infinity hypernest representing the syntax of a
            ; closing bracket, and it must be shaped like a
            ; `snippet-sys-snippet-done` for a degree-`d` hole that
            ; contains a degree-`d` hypernest. That degree-`d`
            ; hypernest represents the content beyond this closing
            ; bracket.
            #/selected data)))
        (unselected
          ; NOTE INTERIOR: This is everything in the interior of the
          ; bump this bracket represents.
          (snippet-sys-snippet-map ss interior-and-closing-brackets
          #/fn hole data
            (trivial))))
      0
      
      0
      (hnb-labeled 0 #/unselected
        (hn-bracs-n-d ds n-d 1 #/hnb-labeled 0 #/trivial)))))


(define (hn-builder-syntax-maybe v)
  (if (dedicated-hn-builder-syntax? v)
    (just #/fn err-dsl-stx stx
      (dedicated-hn-builder-syntax-expand v err-dsl-stx stx))
  #/if (taffy-notation-akin-to-^<>d? v)
    (just #/fn err-dsl-stx stx
      (dlog 'hqq-f1
      #/^<>d-expand v err-dsl-stx stx))
    (nothing)))

(define (assert-known-hn-builder-syntax-maybe err-dsl-stx op-stx v)
  (maybe-or (hn-builder-syntax-maybe v) #/fn
  #/maybe-if (taffy-notation? v) #/fn
    (raise-syntax-error #f
      "not a Punctaffy notation recognized by this DSL"
      err-dsl-stx op-stx)))

(define (assert-not-hn-builder-syntax err-dsl-stx op-stx v)
  (expect (assert-known-hn-builder-syntax-maybe err-dsl-stx op-stx v)
    (nothing)
    (raise-syntax-error #f
      "not a Punctaffy notation this DSL permits in this location"
      err-dsl-stx op-stx)
  #/void))
