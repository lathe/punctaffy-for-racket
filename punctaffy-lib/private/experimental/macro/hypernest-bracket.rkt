#lang parendown racket/base

; hypernest-bracket.rkt
;
; A baseline syntax for opening and closing brackets for
; hypersnippet-shaped code regions.

;   Copyright 2018, 2019 The Lathe Authors
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
  dim-successors-sys-dim-from-int dim-successors-sys-dim-plus-int
  dim-successors-sys-dim-sys dim-sys-dim<? dim-sys-dim<=?
  dim-sys-dim=? dim-sys-dim=0? dim-sys-dim-max nat-dim-successors-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypernest
  hnb-labeled hnb-open hn-bracs-dss hypernest-append-zero
  hypernest-coil-bump hypernest-coil-hole hypernest-contour
  hypernest-degree hypernest-drop1 hypernest-dv-map-all-degrees
  hypernest-increase-degree-to hypernest-join-all-degrees
  hypernest-join-one-degree hypernest->maybe-hypertee hypernest-plus1
  hypernest-truncate-to-hypertee)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypertee
  hypertee-contour hypertee-degree hypertee-dv-map-all-degrees
  hypertee-uncontour)
(require #/for-syntax #/only-in
  punctaffy/private/experimental/macro/hypernest-macro
  hn-tag-0-s-expr-stx hn-tag-1-list hn-tag-nest
  hn-tag-unmatched-closing-bracket s-expr-stx->hn-expr
  simple-hn-builder-syntax)


(provide ^< ^>)



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
  (w- ds (dim-successors-sys-dim-sys dss)
  #/expect (dim-successors-sys-dim-from-int dss 1) (just _)
    (error "Expected at least 1 successor to exist for the zero dimension")
  #/w- n-d (fn n #/just-value #/dim-successors-sys-dim-from-int dss n)
  #/expect (dim-sys-dim=? ds (hypernest-degree hn-expr) (n-d 1))
    #t
    (error "Expected hn-expr to be a hypernest of degree 1")
  #/w- first-d-not-to-process opening-degree
  #/w-loop next
    hn-expr hn-expr
    target-d opening-degree
    first-d-to-process (n-d 1)
    
    (w- dropped (hypernest-drop1 hn-expr)
    #/mat dropped (hypernest-coil-hole d data tails)
      (hypernest-plus1 ds #/hypernest-coil-hole target-d data
      #/hypertee-dv-map-all-degrees tails #/fn d tail
        (next tail target-d
          (dim-sys-dim-max ds first-d-to-process d)))
    #/dissect dropped
      (hypernest-coil-bump overall-degree data bracket-degree-plus-two
        interior-and-bracket-and-tails)
    #/w- ignore
      (fn
        (hypernest-plus1 ds #/hypernest-coil-bump
          target-d
          data
          bracket-degree-plus-two
        #/next
          (hypernest-dv-map-all-degrees interior-and-bracket-and-tails
          #/fn d tail
            (if
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
      (hypernest->maybe-hypertee interior-and-bracket-and-tails)
      (just bracket-and-tails)
      (error "Encountered an hn-tag-unmatched-closing-bracket bump with a bump in it")
    #/expect (hypertee-uncontour dss bracket-and-tails)
      (just #/list bracket-syntax bracket-interior-and-tails)
      (error "Encountered an hn-tag-unmatched-closing-bracket bump which wasn't a contour")
    #/expect (hypertee-uncontour dss bracket-interior-and-tails)
      (just #/list bracket-interior tails)
      (error "Encountered an hn-tag-unmatched-closing-bracket bump which wasn't a contour of a contour")
    #/hypernest-plus1 ds #/hypernest-coil-hole target-d
      (list bracket-syntax bracket-interior)
    #/hypertee-dv-map-all-degrees tails #/fn d tail
      (next tail target-d
        (dim-sys-dim-max ds first-d-to-process d)))))



(define-for-syntax (helper-for-^<-and-^> stx bump-value)
  (w- dss (nat-dim-successors-sys)
  #/w- ds (dim-successors-sys-dim-sys dss)
  #/w- n-d (fn n #/just-value #/dim-successors-sys-dim-from-int dss n)
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
  #/w- interior-and-closing-brackets
    (unmatched-brackets->holes dss degree
    #/hypernest-append-zero ds (n-d 1)
    #/list-map (syntax->list #'(interpolation ...)) #/fn interpolation
      (s-expr-stx->hn-expr dss interpolation))
  #/w- closing-brackets
    (hypernest-truncate-to-hypertee interior-and-closing-brackets)
  #/hypernest-plus1 ds
  #/hypernest-coil-bump (n-d 1) bump-value degree-plus-two
  #/hypernest-contour dss
    ; This is the syntax for the bracket itself.
    (hypernest-join-one-degree (n-d 1)
    #/hn-bracs-dss dss degree-plus-one
      (hnb-open 1 #/hn-tag-1-list #/datum->syntax stx #/list)
      
      (hnb-open 0 #/hn-tag-0-s-expr-stx #'op)
      (hnb-open 0 #/hn-tag-0-s-expr-stx #'degree-stx)
      
      (hnb-labeled 1
      #/hypernest-join-all-degrees
      #/hypernest-contour dss
        (hypernest-contour dss (trivial)
        #/hypertee-dv-map-all-degrees closing-brackets #/fn d data
          (trivial))
      #/hypertee-dv-map-all-degrees closing-brackets #/fn d data
        (if (dim-sys-dim=0? ds d)
          (dissect data (trivial)
          #/hn-bracs-dss dss degree-plus-one
          #/hnb-labeled 0 #/trivial)
        #/dissect data (list bracket-syntax tail)
        ; TODO: See if we need this `hypernest-increase-degree-to`
        ; call.
        #/hypernest-increase-degree-to degree-plus-one
          bracket-syntax))
      0
      
      0
    #/hnb-labeled 0 #/trivial)
  #/hypertee-contour dss
    ; This is everything inside of the bracket.
    (hypernest-dv-map-all-degrees interior-and-closing-brackets
    #/fn d data
      (trivial))
  ; This is everything after the bracket's closing brackets. These
  ; things are outside of the bracket.
  #/hypertee-dv-map-all-degrees closing-brackets #/fn d data
    (if (dim-sys-dim=0? ds d)
      (dissect data (trivial)
      #/hn-bracs-dss dss 1 #/hnb-labeled 0 #/trivial)
    #/dissect data (list bracket-syntax tail)
      tail)))

(define-syntax ^< #/simple-hn-builder-syntax #/fn stx
  (helper-for-^<-and-^> stx #/hn-tag-nest))

(define-syntax ^> #/simple-hn-builder-syntax #/fn stx
  (helper-for-^<-and-^> stx #/hn-tag-unmatched-closing-bracket))
