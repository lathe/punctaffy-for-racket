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

(require #/for-syntax #/only-in racket/math natural?)
(require #/for-syntax #/only-in syntax/parse
  exact-positive-integer id syntax-parse)

(require #/for-syntax #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/for-syntax #/only-in lathe-comforts/list list-map)
(require #/for-syntax #/only-in lathe-comforts/maybe
  just just-value maybe-bind maybe-if)
(require #/for-syntax #/only-in lathe-comforts/trivial trivial)

(require #/for-syntax #/only-in punctaffy/hypersnippet/dim
  dim-successors-sys-dim-from-int dim-successors-sys-dim-plus-int
  dim-successors-sys-dim=plus-int? dim-successors-sys-dim-sys
  dim-sys-dim<? dim-sys-dim<=? dim-sys-dim=? dim-sys-dim=0?
  dim-sys-dim-max nat-dim-successors-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypernest-2
  hnb-labeled hn-bracs hnb-open hnb-unlabeled hypernest-coil-bump
  hypernest-coil-hole hypernest-from-brackets hypernest-furl
  hypernest-join-list-and-tail-along-0 hypernest-shape
  hypernest-snippet-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypertee-2
  hypertee-snippet-format-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/snippet
  selected snippet-sys-shape-snippet-sys snippet-sys-snippet-degree
  snippet-sys-snippet-done snippet-sys-snippet-each
  snippet-sys-snippet-join snippet-sys-snippet-join-selective
  snippet-sys-snippet-map snippet-sys-snippet->maybe-shape
  snippet-sys-snippet-set-degree-maybe snippet-sys-snippet-undone
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
    (require #/for-syntax punctaffy/hypersnippet/hypernest-2)
    (require #/for-syntax punctaffy/hypersnippet/hypertee-2)
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


(define-for-syntax (snippet-sys-snippet-uncontour dss ss snippet)
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/maybe-bind (snippet-sys-snippet-undone ss snippet)
  #/dissectfn (list original-degree hole data)
  #/w- d (snippet-sys-snippet-degree shape-ss hole)
  #/maybe-if
    (dim-successors-sys-dim=plus-int? dss original-degree d 1)
    (fn #/list hole data)))

(define-for-syntax (hypernest-join-0 ds n-d d elems)
  (hypernest-join-list-and-tail-along-0 ds elems
    (hn-bracs ds (n-d d) #/hnb-labeled (n-d 0) #/trivial)))

(define-for-syntax (hn-bracs-dss dss degree . brackets)
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
    (list-map brackets #/fn bracket
      (mat bracket (hnb-open d data) (hnb-open (n-d d) data)
      #/mat bracket (hnb-labeled d data) (hnb-labeled (n-d d) data)
      #/mat bracket (hnb-unlabeled d) (hnb-unlabeled (n-d d))
      #/hnb-unlabeled (n-d bracket)))))


; TODO NOW: Store `hn-tag-unmatched-closing-bracket` and `hn-tag-nest`
; in degree-infinity holes instead of degree-(N + 2) holes.

; This takes a degree-1 hypernest which may contain
; `hn-tag-unmatched-closing-bracket` values at certain
; degree-3-or-greater bumps, and it returns a
; degree-(`opening-degree`) hypernest where such bumps of degree
; (N + 2) are converted to holes of degree N, for each N greater than
; zero and less than `opening-degree`. Each of the new holes of degree
; N contains a two-element list where the first element is a
; degree-(N + 1) hypernest encoding the syntactic details of the
; closing bracket itself and the second element is a degree-N
; hypernest encoding the area beyond the closing bracket. (TODO: They
; actually are degree-(N + 1) and degree-N, right?)
;
; In the input, no bump of degree less than 3 may contain an
; `hn-tag-unmatched-closing-bracket` value. The degree-0 hole's value
; will be preserved in the result, but we expect it to be a `trivial`
; value.
;
(define-for-syntax
  (unmatched-brackets->holes dss opening-degree hn-expr)
  (dlog 'hqq-g1
  #/w- ds (dim-successors-sys-dim-sys dss)
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/expect (dim-successors-sys-dim-from-int dss 1) (just _)
    (error "Expected at least 1 successor to exist for the zero dimension")
  #/w- n-d (fn n #/just-value #/dim-successors-sys-dim-from-int dss n)
  #/expect
    (dim-sys-dim=? ds (snippet-sys-snippet-degree ss hn-expr) (n-d 1))
    #t
    (error "Expected hn-expr to be a hypernest of degree 1")
  #/w- first-d-not-to-process opening-degree
  #/w-loop next
    hn-expr hn-expr
    target-d opening-degree
    first-d-to-process (n-d 1)
    
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
      (hypernest-coil-bump overall-degree data bracket-degree-plus-two
        interior-and-bracket-and-tails)
    #/dlog 'hqq-g3 overall-degree bracket-degree-plus-two (snippet-sys-snippet-degree ss interior-and-bracket-and-tails)
    #/begin (verify-hn interior-and-bracket-and-tails)
    #/begin
      (snippet-sys-snippet-each ss interior-and-bracket-and-tails
      #/fn hole tail #/begin0 (void)
        (w- d (snippet-sys-snippet-degree shape-ss hole)
        #/when (dim-sys-dim<? ds d bracket-degree-plus-two)
          (dlog 'hqq-g3.1 (snippet-sys-snippet-degree ss tail)
          #/verify-hn tail)))
    #/w- ignore
      (fn
        (hypernest-furl ds #/hypernest-coil-bump
          target-d
          data
          bracket-degree-plus-two
        #/next
          (snippet-sys-snippet-map ss interior-and-bracket-and-tails
          #/fn hole tail
            (w- d (snippet-sys-snippet-degree shape-ss hole)
            #/if
              (and
                (dim-sys-dim<=? ds bracket-degree-plus-two d)
                (dim-sys-dim<? ds d first-d-to-process))
              tail
            #/next tail
              (dim-sys-dim-max ds target-d d)
              (dim-sys-dim-max ds first-d-to-process d)))
          (dim-sys-dim-max ds target-d bracket-degree-plus-two)
          (dim-sys-dim-max ds
            first-d-to-process bracket-degree-plus-two)))
    #/expect data (hn-tag-unmatched-closing-bracket) (ignore)
    #/expect
      (and
        (expect
          (dim-successors-sys-dim-plus-int dss first-d-to-process 2)
          (just first-d-to-process-plus-two)
          ; TODO: See if returning `#f` here is correct.
          #f
        #/dim-sys-dim<=? ds
          first-d-to-process-plus-two bracket-degree-plus-two)
        (expect
          (dim-successors-sys-dim-plus-int dss
            first-d-not-to-process 2)
          (just first-d-not-to-process-plus-two)
          ; TODO: See if returning `#f` here is correct.
          #f
        #/dim-sys-dim<? ds
          bracket-degree-plus-two first-d-not-to-process-plus-two))
      #t
      (ignore)
    #/expect
      (dim-successors-sys-dim-plus-int dss bracket-degree-plus-two -1)
      (just bracket-degree-plus-one)
      (error "Encountered a matching hn-tag-unmatched-closing-bracket bump of a degree that did not have two predecessors (or even one)")
    #/expect
      (dim-successors-sys-dim-plus-int dss bracket-degree-plus-one -1)
      (just bracket-degree)
      (error "Encountered a matching hn-tag-unmatched-closing-bracket bump of a degree that did not have two predecessors (but did have one)")
    #/expect
      (snippet-sys-snippet->maybe-shape ss
        interior-and-bracket-and-tails)
      (just bracket-and-tails)
      (error "Encountered an hn-tag-unmatched-closing-bracket bump with a bump in it")
    #/expect
      (snippet-sys-snippet-uncontour dss shape-ss bracket-and-tails)
      (just #/list bracket-interior-and-tails bracket-syntax)
      (error "Encountered an hn-tag-unmatched-closing-bracket bump which wasn't a contour")
    #/expect
      (snippet-sys-snippet-uncontour dss shape-ss
        bracket-interior-and-tails)
      (just #/list tails bracket-interior)
      (error "Encountered an hn-tag-unmatched-closing-bracket bump which wasn't a contour of a contour")
    #/hypernest-furl ds #/hypernest-coil-hole target-d
      (snippet-sys-snippet-map shape-ss tails #/fn hole tail
        (trivial))
      (list (dlog 'hqq-g4 #/verify-hn bracket-syntax) bracket-interior)
      (snippet-sys-snippet-map shape-ss tails #/fn hole tail
        (w- d (snippet-sys-snippet-degree shape-ss hole)
        #/next tail target-d
          (dim-sys-dim-max ds first-d-to-process d))))))



(define-for-syntax (helper-for-^<-and-^> stx bump-value)
  (dlog 'hqq-f2
  #/w- dss (nat-dim-successors-sys)
  #/w- ds (dim-successors-sys-dim-sys dss)
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/w- n-d (fn n #/just-value #/dim-successors-sys-dim-from-int dss n)
  #/dlog 'hqq-f3
  #/syntax-parse stx
    [op:id
      ; If this syntax transformer is used in an identifier position,
      ; we just expand as though the identifier isn't bound to a
      ; syntax transformer at all.
      ;
      ; TODO: See if we'll ever need to rely on this functionality.
      ;
      (hn-bracs-dss dss 1 (hnb-open 0 #/hn-tag-0-s-expr-stx stx)
      #/hnb-labeled 0 #/trivial)]
  #/ (op:id degree-stx:exact-positive-integer interpolation ...)
  #/w- degree (syntax-e #'degree-stx)
  #/w- degree-plus-one (+ degree 1)
  #/w- degree-plus-two (+ degree 2)
  #/dlog 'hqq-f4
  #/w- interior-and-closing-brackets
    (verify-hn #/unmatched-brackets->holes dss degree
    #/hypernest-join-0 ds n-d 1
    #/list-map (syntax->list #'(interpolation ...)) #/fn interpolation
      (verify-hn #/s-expr-stx->hn-expr ds n-d interpolation))
  #/dlog 'hqq-f5
  #/w- closing-brackets
    (hypernest-shape ss interior-and-closing-brackets)
  #/dlog 'hqq-f6
  #/hypernest-furl ds
  #/dlog 'hqq-f7
  #/hypernest-coil-bump (n-d 1) bump-value degree-plus-two
  #/dlog 'hqq-f8
  #/snippet-sys-snippet-done ss degree-plus-two
    (snippet-sys-snippet-done shape-ss degree-plus-one
      ; This is everything after the bracket's closing brackets. These
      ; things are outside of the bracket.
      (snippet-sys-snippet-map shape-ss closing-brackets
      #/fn hole data
        (w- d (snippet-sys-snippet-degree shape-ss hole)
        #/if (dim-sys-dim=0? ds d)
          (dissect data (trivial)
          #/hn-bracs-dss dss 1 #/hnb-labeled 0 #/trivial)
        #/dissect data (list bracket-syntax tail)
          tail))
      ; This is everything inside of the bracket.
      (snippet-sys-snippet-map ss interior-and-closing-brackets
      #/fn hole data
        (trivial)))
    ; This is the syntax for the bracket itself.
    (snippet-sys-snippet-join-selective ss
    #/hn-bracs-dss dss degree-plus-one
      (hnb-open 1 #/hn-tag-1-list #/datum->syntax stx #/list)
      
      (hnb-open 0 #/hn-tag-0-s-expr-stx #'op)
      (hnb-open 0 #/hn-tag-0-s-expr-stx #'degree-stx)
      
      (hnb-labeled 1
      #/selected
      #/snippet-sys-snippet-join ss
      #/snippet-sys-snippet-done ss degree-plus-one
        (snippet-sys-snippet-map shape-ss closing-brackets
        #/fn hole data
          (w- d (snippet-sys-snippet-degree shape-ss hole)
          #/if (dim-sys-dim=0? ds d)
            (dissect data (trivial)
            #/hn-bracs-dss dss degree-plus-one
            #/hnb-labeled 0 #/trivial)
          #/dissect data (list bracket-syntax tail)
          ; TODO: See if we need this
          ; `snippet-sys-snippet-set-degree-maybe` call.
          #/dissect
            (dlog 'hqq-f9 degree-plus-one (snippet-sys-snippet-degree ss bracket-syntax) #;bracket-syntax
            #/begin (verify-hn bracket-syntax)
            #/dlog 'hqq-f10
            #/snippet-sys-snippet-set-degree-maybe ss degree-plus-one
              bracket-syntax)
            (just bracket-syntax)
            bracket-syntax))
        (snippet-sys-snippet-done ss degree-plus-one
          (snippet-sys-snippet-map shape-ss closing-brackets
            (fn hole data
              (trivial)))
          (trivial)))
      0
      
      0
    #/hnb-labeled 0 #/unselected #/trivial)))

(define-syntax ^< #/simple-hn-builder-syntax #/fn stx
  (dlog 'hqq-f1
  #/helper-for-^<-and-^> stx #/hn-tag-nest))

(define-syntax ^> #/simple-hn-builder-syntax #/fn stx
  (helper-for-^<-and-^> stx #/hn-tag-unmatched-closing-bracket))
