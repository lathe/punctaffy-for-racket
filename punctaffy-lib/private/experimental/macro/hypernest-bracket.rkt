#lang parendown racket/base

; hypernest-bracket.rkt
;
; A baseline syntax for opening and closing brackets for
; hypersnippet-shaped code regions.

;   Copyright 2018-2019, 2021 The Lathe Authors
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

(require #/for-syntax #/only-in syntax/parse
  exact-positive-integer id syntax-parse)

(require #/for-syntax #/only-in lathe-comforts
  dissect expect fn mat w- w-loop)
(require #/for-syntax #/only-in lathe-comforts/list list-map)
(require #/for-syntax #/only-in lathe-comforts/maybe just just-value)
(require #/for-syntax #/only-in lathe-comforts/trivial trivial)

(require #/for-syntax #/only-in punctaffy/hypersnippet/dim
  dim-sys-dim<? dim-sys-dim<=? dim-sys-dim=? dim-sys-dim=0?
  dim-sys-dim-max dim-sys-morphism-sys-morph-dim
  extended-with-top-dim-infinite extended-with-top-dim-sys
  extend-with-top-dim-sys-morphism-sys nat-dim-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypernest
  hnb-labeled hnb-open hnb-unlabeled hypernest-coil-bump
  hypernest-coil-hole hypernest-from-brackets hypernest-furl
  hypernest-join-list-and-tail-along-0 hypernest-shape
  hypernest-snippet-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypertee
  hypertee-snippet-format-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/snippet
  selected snippet-sys-shape-snippet-sys snippet-sys-snippet-degree
  snippet-sys-snippet-done snippet-sys-snippet-each
  snippet-sys-snippet-join-selective snippet-sys-snippet-map
  snippet-sys-snippet-map-selective
  snippet-sys-snippet-select-if-degree< snippet-sys-snippet-undone
  unselected)
(require #/for-syntax #/only-in
  punctaffy/private/experimental/macro/hypernest-macro
  hn-tag-0-s-expr-stx hn-tag-1-list hn-tag-nest
  hn-tag-unmatched-closing-bracket s-expr-stx->hn-expr
  simple-hn-builder-syntax)

; NOTE DEBUGGABILITY: These are here for debugging.
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
  (require #/for-syntax lathe-debugging)
  (require #/for-syntax 'private/lathe-debugging/placebo))


(provide ^< ^>)



; NOTE DEBUGGABILITY: These are here for debugging.
(ifc debugging-in-inexpensive-ways
  (begin
    ; TODO: Make these use `only-in`.
    (require #/for-syntax racket/contract)
    (require #/for-syntax lathe-comforts/contract)
    (require #/for-syntax punctaffy/hypersnippet/hypernest)
    (require #/for-syntax punctaffy/hypersnippet/hypertee)
    (require #/for-syntax punctaffy/hypersnippet/snippet)
    (begin-for-syntax #/define/contract (verify-ht ht)
      (->
        (and/c hypertee?
          (by-own-method/c ht #/hypertee/c #/hypertee-get-dim-sys ht))
        any/c)
      ht)
    (begin-for-syntax #/define/contract (verify-hn hn)
      (->
        (and/c hypernest?
          (by-own-method/c hn
            (hypernest/c (hypertee-snippet-format-sys)
              (hypernest-get-dim-sys hn))))
        any/c)
      hn))
  (begin
    (begin-for-syntax #/define-syntax-rule (verify-ht ht) ht)
    (begin-for-syntax #/define-syntax-rule (verify-hn hn) hn)))


(define-for-syntax (datum->syntax-with-everything stx-example datum)
  (w- ctxt stx-example
  #/w- srcloc stx-example
  #/w- prop stx-example
  #/datum->syntax ctxt datum srcloc prop))

(define-for-syntax
  (hypernest-from-brackets-n-d* ds n-d degree brackets)
  (w- n-d (fn d #/dim-sys-morphism-sys-morph-dim n-d d)
  #/hypernest-from-brackets ds degree
    (list-map brackets #/fn bracket
      (mat bracket (hnb-open d data) (hnb-open (n-d d) data)
      #/mat bracket (hnb-labeled d data) (hnb-labeled (n-d d) data)
      #/mat bracket (hnb-unlabeled d) (hnb-unlabeled (n-d d))
      #/hnb-unlabeled (n-d bracket)))))

(define-for-syntax (hn-bracs-n-d* ds n-d degree . brackets)
  (hypernest-from-brackets-n-d* ds n-d degree brackets))

(define-for-syntax (hn-bracs-n-d ds n-d degree . brackets)
  (hypernest-from-brackets-n-d* ds n-d
    (dim-sys-morphism-sys-morph-dim n-d degree)
    brackets))

(define-for-syntax (hypernest-join-0 ds n-d d elems)
  (hypernest-join-list-and-tail-along-0 ds elems
    (hn-bracs-n-d ds n-d d #/hnb-labeled 0 #/trivial)))


(define-for-syntax en-ds (extended-with-top-dim-sys #/nat-dim-sys))
(define-for-syntax en-n-d
  (extend-with-top-dim-sys-morphism-sys #/nat-dim-sys))


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
(define-for-syntax (unmatched-brackets->holes opening-degree hn-expr)
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



(define-for-syntax (helper-for-^<-and-^> stx bump-value)
  (dlog 'hqq-f2
  #/w- ds en-ds
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/w- n-d en-n-d
  #/dlog 'hqq-f3
  #/syntax-parse stx
    [op:id
      ; If this syntax transformer is used in an identifier position,
      ; we just expand as though the identifier isn't bound to a
      ; syntax transformer at all.
      ;
      ; TODO: See if we'll ever need to rely on this functionality.
      ;
      (hn-bracs-n-d ds n-d 1 (hnb-open 0 #/hn-tag-0-s-expr-stx stx)
      #/hnb-labeled 0 #/trivial)]
  #/ (op:id degree-stx:exact-positive-integer interpolation ...)
  #/w- degree
    (dim-sys-morphism-sys-morph-dim n-d #/syntax-e #'degree-stx)
  #/dlog 'hqq-f4
  #/w- interior-and-closing-brackets
    (verify-hn #/unmatched-brackets->holes degree
    #/hypernest-join-0 ds n-d 1
    #/list-map (syntax->list #'(interpolation ...)) #/fn interpolation
      (verify-hn #/s-expr-stx->hn-expr interpolation))
  #/dlog 'hqq-f5
  #/w- closing-brackets
    (hypernest-shape ss interior-and-closing-brackets)
  #/dlog 'hqq-f6
  #/hypernest-furl ds
  #/dlog 'hqq-f7
  #/hypernest-coil-bump
    (dim-sys-morphism-sys-morph-dim n-d 1)
    bump-value
    (extended-with-top-dim-infinite)
    ; This is the syntax for the bracket itself, everything in the
    ; interior of the bump this bracket represents (noted at
    ; NOTE INSIDE), and everything beyond the closing brackets of this
    ; bracket (noted at NOTE BEYOND).
    (dlog 'hqq-f8
    #/snippet-sys-snippet-join-selective ss
    #/hn-bracs-n-d* ds n-d (extended-with-top-dim-infinite)
      (hnb-open 1
        (hn-tag-1-list #/datum->syntax-with-everything stx #/list))
      
      (hnb-open 0 #/hn-tag-0-s-expr-stx #'op)
      (hnb-open 0 #/hn-tag-0-s-expr-stx #'degree-stx)
      
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

(define-syntax ^< #/simple-hn-builder-syntax #/fn stx
  (dlog 'hqq-f1
  #/helper-for-^<-and-^> stx #/hn-tag-nest))

(define-syntax ^> #/simple-hn-builder-syntax #/fn stx
  (helper-for-^<-and-^> stx #/hn-tag-unmatched-closing-bracket))
