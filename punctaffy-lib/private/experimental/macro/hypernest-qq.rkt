#lang parendown racket/base

; hypernest-qq.rkt
;
; A quasiquotation operator which allows for user-defined escape
; sequences which can generalize unquotation and nested
; quasiquotation.

;   Copyright 2018 The Lathe Authors
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

(require #/for-syntax #/only-in lathe-comforts
  dissect expect fn mat w- w-loop)
(require #/for-syntax #/only-in lathe-comforts/list
  list-foldr list-map)
(require #/for-syntax #/only-in lathe-comforts/maybe just)
(require #/for-syntax #/only-in lathe-comforts/trivial trivial)
(require #/for-syntax #/only-in lathe-ordinals
  onum<? onum<=? onum-plus onum-pred-maybe onum-max)

(require #/for-syntax #/only-in punctaffy/hypersnippet/hypernest
  degree-and-brackets->hypernest hypernest-bind-one-degree
  hypernest-contour hypernest-degree hypernest-drop1
  hypernest-drop1-result-bump hypernest-drop1-result-hole
  hypernest-join-all-degrees hypernest-join-one-degree
  hypernest-map-all-degrees hypernest->maybe-hypertee
  hypernest-promote hypernest-pure hypernest-pure-bump
  hypernest-truncate-to-hypertee)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypertee
  hypertee-contour hypertee-degree hypertee-map-all-degrees
  hypertee-uncontour)
(require #/for-syntax #/only-in
  punctaffy/private/experimental/macro/hypernest-macro
  hn-tag-1-s-expr-stx hn-tag-2-list hn-tag-nest
  hn-tag-unmatched-closing-bracket s-expr-stx->hn-expr
  simple-hn-builder-syntax)

(require #/for-syntax #/only-in syntax/parse
  exact-positive-integer id syntax-parse)


; TODO:
;
; Salvage anything from qq.rkt that makes sense to salvage for this
; file.
;
; Compared to qq.rkt, this whole file's design needs to be rethought
; now that we're using hypernests instead of hypertees. The syntax we
; use for quasiquotation should no longer be this:
;
;   (my-quasiquote uq #/qq
;     (a b
;       (my-quasiquote uq #/qq
;         (c d
;           (uq
;             (e f
;               (uq
;                 (+ 4 5))))))))
;
; Instead, it should be something like this, with new
; operators ^< and ^> that signify opening brackets and closing
; brackets of explicit degrees:
;
;   (my-quasiquote #/^< 2
;     (a b
;       (my-quasiquote #/^< 2
;         (c d
;           (^> 1 #/my-unquote
;             (e f
;               (^> 1 #/my-unquote
;                 (+ 4 5))))))))
;
; The ^< and ^> syntaxes should be defined in and provided from some
; module that makes them look as much like language builtins as
; reasonably possible. (In particular, `(require punctaffy)` should
; get them.) Most programmers will be able to treat them as
; parentheses; like parentheses, they're a notation that most programs
; don't need to extend or parse in custom ways.
;
; The `my-quasiquote` and `my-unquote` syntaxes should be defined only
; in terms of `s-expr-stx->ht-expr`, the structs of the hn-expression
; format, and the hypernest and hypertee utilities. Even these won't
; need to extend or parse the higher-order paren notation in custom
; ways.
;
; Users of `my-quasiquote` and `my-unquote` will only need to import
; those two operations and ^< and ^> but will not usually need to
; understand them any more deeply than the traditional `quasiquote`
; and `unquote`. Even if they define another quasiquotation syntax, it
; will interoperate seamlessly with `my-quasiquote` and `my-unquote`
; if it makes similar use of `s-expr-stx->ht-expr`.
;
; If people define custom parentheses very often, quotation operators
; will typically fail to preserve their meaning since code generated
; for different lexical contexts could have different sets of custom
; parentheses available. That's why we should decide on a minimalistic
; set of operators like ^< and ^> that can express the full range of
; hn-expressions and provide these as the baseline that other syntaxes
; are typically built around.


(define-for-syntax (n-hn degree . brackets)
  (degree-and-brackets->hypernest degree brackets))

(define-for-syntax (n-hn-append0 degree hns)
  ; When we call this, the elements of `hns` are degree-1 hypernests,
  ; and their degree-0 holes have trivial values as contents. We
  ; return their degree-0 concatenation.
  (list-foldr hns (n-hn degree #/list 0 #/trivial) #/fn hn tail
    (hypernest-bind-one-degree 0 hn #/fn hole data
      (dissect data (trivial)
        tail))))


(define-for-syntax (unmatched-brackets->holes opening-degree hn-expr)
  (expect (hypernest-degree hn-expr) 1
    (error "Expected hn-expr to be a hypernest of degree 1")
  #/w-loop next first-nontrivial-d 1 hn-expr hn-expr
    (w- dropped (hypernest-drop1 hn-expr)
    #/mat dropped (hypernest-drop1-result-hole data tails)
      (hypernest-pure opening-degree data
      #/hypertee-map-all-degrees tails #/fn hole tail
        (next (onum-max first-nontrivial-d #/hypertee-degree hole)
          tail))
    #/dissect dropped
      (hypernest-drop1-result-bump
        data interior-and-bracket-and-tails)
    #/w- ignore
      (fn
        (hypernest-pure-bump opening-degree data
        #/hypernest-map-all-degrees interior-and-bracket-and-tails
        #/fn hole tail
          (next (onum-max first-nontrivial-d #/hypertee-degree hole)
            tail)))
    #/expect data (hn-tag-unmatched-closing-bracket) (ignore)
    #/w- bump-degree-plus-two
      (hypernest-degree interior-and-bracket-and-tails)
    #/expect
      (onum<? bump-degree-plus-two #/onum-plus opening-degree 2)
      #t
      (ignore)
    #/expect (onum-pred-maybe bump-degree-plus-two)
      (just bump-degree-plus-one)
      (error "Internal error: Encountered a degree-0 bump")
      ; TODO: Use this error message instead if we ever add support
      ; for hypertees and hypernests of dimension greater than omega.
;      (error "Encountered an hn-tag-unmatched-closing-bracket on a degree-N bump where N was a limit ordinal, rather than a degree-(N + 2) bump for any N")
    #/expect (onum-pred-maybe bump-degree-plus-one) (just bump-degree)
      (error "Encountered an hn-tag-unmatched-closing-bracket on a degree-1 hole")
      ; TODO: Use this error message instead if we ever add support
      ; for hypertees and hypernests of dimension greater than omega.
;      (error "Encountered an hn-tag-unmatched-closing-bracket on a degree-1 bump or a degree-(N + 1) hole where N was a limit ordinal, rather than a degree-(N + 2) bump for any N")
    #/expect (onum<=? first-nontrivial-d bump-degree) #t
      (error "Encountered a not-yet-processed hn-tag-unmatched-closing-bracket in a region of too high degree to process it now")
    #/expect
      (hypernest->maybe-hypertee interior-and-bracket-and-tails)
      (just bracket-and-tails)
      (error "Encountered an hn-tag-unmatched-closing-bracket with a bump in it")
    #/expect (hypertee-uncontour bracket-and-tails)
      (just #/list bracket-syntax bracket-interior-and-tails)
      (error "Encountered an hn-tag-unmatched-closing-bracket which wasn't a contour")
    #/expect (hypertee-uncontour bracket-interior-and-tails)
      (just #/list bracket-interior tails)
      (error "Encountered an hn-tag-unmatched-closing-bracket which wasn't a contour of a contour")
    ; TODO: Once we're sure we don't need to zip these, delete this
    ; commented-out code.
;    #/expect
;      (hypernest-zip
;        (hypertee-map-all-degrees bracket-interior-and-tails
;        #/fn hole data
;          (if (equal? bump-degree-plus-one #/hypertee-degree hole)
;            data
;            (trivial)))
;        bracket-syntax
;      #/fn hole bracket-interior-data bracket-syntax-data
;        (dissect bracket-syntax-data (trivial)
;          bracket-interior-data))
;      (just zipped-bracket)
;      (error "Internal error: Expected bracket-syntax and bracket-interior-and-tails to be of compatible shapes since bracket-syntax was a tail of an hn-tag-unmatched-closing-bracket bump and this tail was located in the contour of bracket-interior-and-tails")
    #/hypernest-pure opening-degree
      (list bracket-syntax bracket-interior)
    #/hypertee-map-all-degrees tails #/fn hole tail
      (next (onum-max first-nontrivial-d #/hypertee-degree hole)
        tail))))

(define-for-syntax (helper-for-^<-and-^> stx bump-value)
  (syntax-parse stx
    [op:id
      ; If this syntax transformer is used in an identifier position,
      ; we just expand as though the identifier isn't bound to a
      ; syntax transformer at all.
      (n-hn 1 (list 1 #/hn-tag-1-s-expr-stx stx) 0
      #/list 0 #/trivial)]
  #/ (op:id degree-stx:exact-positive-integer interpolation ...)
  #/w- degree (syntax-e #'degree-stx)
  #/w- degree-plus-one (onum-plus degree 1)
  #/w- interior-and-closing-brackets
    (unmatched-brackets->holes degree #/n-hn-append0 1
    #/list-map (syntax->list #'(interpolation ...)) #/fn interpolation
      (s-expr-stx->hn-expr interpolation))
  #/w- closing-brackets
    (hypernest-truncate-to-hypertee interior-and-closing-brackets)
  #/hypernest-pure-bump 1 bump-value
  #/hypernest-contour
    ; This is the syntax for the bracket itself.
    (hypernest-join-one-degree 1
    #/n-hn degree-plus-one
      (list 'open 2 #/hn-tag-2-list #/datum->syntax stx #/list)
      
      (list 'open 1 #/hn-tag-1-s-expr-stx #'op)
      0
      (list 'open 1 #/hn-tag-1-s-expr-stx #'degree-stx)
      0
      
      (list 1
      #/hypernest-join-all-degrees
      #/hypernest-contour
        (hypernest-contour (trivial)
        #/hypertee-map-all-degrees closing-brackets #/fn hole data
          (trivial))
      #/hypertee-map-all-degrees closing-brackets #/fn hole data
        (dissect data (list bracket-syntax tail)
        ; TODO: See if we need this `hypernest-promote` call.
        #/hypernest-promote degree-plus-one
          bracket-syntax))
      0
      
      0
    #/list 0 #/trivial)
  #/hypertee-contour
    ; This is everything inside of the bracket.
    (hypernest-map-all-degrees interior-and-closing-brackets
    #/fn hole data
      (trivial))
  ; This is everything after the bracket's closing brackets. These
  ; things are outside of the bracket.
  #/hypertee-map-all-degrees closing-brackets #/fn hole data
    (dissect data (list bracket-syntax tail)
      tail)))

(define-syntax ^< #/simple-hn-builder-syntax #/fn stx
  (helper-for-^<-and-^> stx #/hn-tag-nest))

(define-syntax ^> #/simple-hn-builder-syntax #/fn stx
  (helper-for-^<-and-^> stx #/hn-tag-unmatched-closing-bracket))
