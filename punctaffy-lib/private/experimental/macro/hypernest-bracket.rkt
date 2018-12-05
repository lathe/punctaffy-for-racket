#lang parendown racket/base

; hypernest-bracket.rkt
;
; A baseline syntax for opening and closing brackets for
; hypersnippet-shaped code regions.

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

(require #/for-syntax #/only-in syntax/parse
  exact-positive-integer id syntax-parse)

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
  hypernest-coil-bump hypernest-coil-hole hypernest-contour
  hypernest-degree hypernest-drop1 hypernest-dv-map-all-degrees
  hypernest-join-all-degrees hypernest-join-one-degree
  hypernest->maybe-hypertee hypernest-plus1 hypernest-promote
  hypernest-set-degree hypernest-truncate-to-hypertee)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypertee
  hypertee-contour hypertee-degree hypertee-dv-map-all-degrees
  hypertee-uncontour)
(require #/for-syntax #/only-in
  punctaffy/private/experimental/macro/hypernest-macro
  hn-tag-0-s-expr-stx hn-tag-1-list hn-tag-nest
  hn-tag-unmatched-closing-bracket s-expr-stx->hn-expr
  simple-hn-builder-syntax)


(provide ^< ^>)



(define-for-syntax (n-hn degree . brackets)
  (degree-and-brackets->hypernest degree brackets))

(define-for-syntax (n-hn-append0 degree hns)
  ; When we call this, the elements of `hns` are hypernests of degree
  ; `degree`, and their degree-0 holes have trivial values as
  ; contents. We return their degree-0 concatenation.
  (list-foldr hns (n-hn degree #/list 0 #/trivial) #/fn hn tail
    (hypernest-bind-one-degree 0 hn #/fn hole data
      (dissect data (trivial)
        tail))))


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
(define-for-syntax (unmatched-brackets->holes opening-degree hn-expr)
  (expect (hypernest-degree hn-expr) 1
    (error "Expected hn-expr to be a hypernest of degree 1")
  #/w- first-d-not-to-process opening-degree
  #/w-loop next
    hn-expr hn-expr
    target-d opening-degree
    first-d-to-process 1
    
    (w- dropped (hypernest-drop1 hn-expr)
    #/mat dropped (hypernest-coil-hole d data tails)
      (hypernest-plus1 #/hypernest-coil-hole target-d data
      #/hypertee-dv-map-all-degrees tails #/fn d tail
        (next tail target-d (onum-max first-d-to-process d)))
    #/dissect dropped
      (hypernest-coil-bump overall-degree data bracket-degree-plus-two
        interior-and-bracket-and-tails)
    #/w- ignore
      (fn
        (hypernest-plus1 #/hypernest-coil-bump
          target-d
          data
          bracket-degree-plus-two
        #/next
          (hypernest-dv-map-all-degrees interior-and-bracket-and-tails
          #/fn d tail
            (if
              (and
                (onum<=? bracket-degree-plus-two d)
                (onum<? d first-d-to-process))
              tail
            #/next tail
              (onum-max target-d d)
              (onum-max first-d-to-process d)))
          (onum-max target-d bracket-degree-plus-two)
          (onum-max first-d-to-process bracket-degree-plus-two)))
    #/expect data (hn-tag-unmatched-closing-bracket) (ignore)
    #/expect
      (and
        (onum<=?
          (onum-plus first-d-to-process 2)
          bracket-degree-plus-two)
        (onum<?
          bracket-degree-plus-two
          (onum-plus first-d-not-to-process 2)))
      #t
      (ignore)
    #/expect (onum-pred-maybe bracket-degree-plus-two)
      (just bracket-degree-plus-one)
      (error "Encountered a matching hn-tag-unmatched-closing-bracket bump of degree 0")
      ; TODO: Use this error message instead if we ever add support
      ; for hypertees and hypernests of dimension greater than omega.
;      (error "Encountered an hn-tag-unmatched-closing-bracket bump of degree N where N was a limit ordinal, rather than a degree-(N + 2) bump for any N")
    #/expect (onum-pred-maybe bracket-degree-plus-one)
      (just bracket-degree)
      (error "Encountered a matching hn-tag-unmatched-closing-bracket bump of degree 1")
      ; TODO: Use this error message instead if we ever add support
      ; for hypertees and hypernests of dimension greater than omega.
;      (error "Encountered an hn-tag-unmatched-closing-bracket bump of degree 1 or a degree-(N + 1) bump where N was a limit ordinal, rather than a degree-(N + 2) bump for any N")
    #/expect
      (hypernest->maybe-hypertee interior-and-bracket-and-tails)
      (just bracket-and-tails)
      (error "Encountered an hn-tag-unmatched-closing-bracket bump with a bump in it")
    #/expect (hypertee-uncontour bracket-and-tails)
      (just #/list bracket-syntax bracket-interior-and-tails)
      (error "Encountered an hn-tag-unmatched-closing-bracket bump which wasn't a contour")
    #/expect (hypertee-uncontour bracket-interior-and-tails)
      (just #/list bracket-interior tails)
      (error "Encountered an hn-tag-unmatched-closing-bracket bump which wasn't a contour of a contour")
    #/hypernest-plus1 #/hypernest-coil-hole target-d
      (list bracket-syntax bracket-interior)
    #/hypertee-dv-map-all-degrees tails #/fn d tail
      (next tail target-d (onum-max first-d-to-process d)))))



(define-for-syntax (helper-for-^<-and-^> stx bump-value)
  (syntax-parse stx
    [op:id
      ; If this syntax transformer is used in an identifier position,
      ; we just expand as though the identifier isn't bound to a
      ; syntax transformer at all.
      ;
      ; TODO: See if we'll ever need to rely on this functionality.
      ;
      (n-hn 1 (list 'open 0 #/hn-tag-0-s-expr-stx stx)
      #/list 0 #/trivial)]
  #/ (op:id degree-stx:exact-positive-integer interpolation ...)
  #/w- degree (syntax-e #'degree-stx)
  #/w- degree-plus-one (onum-plus degree 1)
  #/w- degree-plus-two (onum-plus degree 2)
  #/w- interior-and-closing-brackets
    (unmatched-brackets->holes degree #/n-hn-append0 1
    #/list-map (syntax->list #'(interpolation ...)) #/fn interpolation
      (s-expr-stx->hn-expr interpolation))
  #/w- closing-brackets
    (hypernest-truncate-to-hypertee interior-and-closing-brackets)
  #/hypernest-plus1 #/hypernest-coil-bump 1 bump-value degree-plus-two
  #/hypernest-contour
    ; This is the syntax for the bracket itself.
    (hypernest-join-one-degree 1
    #/n-hn degree-plus-one
      (list 'open 1 #/hn-tag-1-list #/datum->syntax stx #/list)
      
      (list 'open 0 #/hn-tag-0-s-expr-stx #'op)
      (list 'open 0 #/hn-tag-0-s-expr-stx #'degree-stx)
      
      (list 1
      #/hypernest-join-all-degrees
      #/hypernest-contour
        (hypernest-contour (trivial)
        #/hypertee-dv-map-all-degrees closing-brackets #/fn d data
          (trivial))
      #/hypertee-dv-map-all-degrees closing-brackets #/fn d data
        (mat d 0
          (dissect data (trivial)
          #/degree-and-brackets->hypernest degree-plus-one #/list
          #/list 0 #/trivial)
        #/dissect data (list bracket-syntax tail)
        ; TODO: See if we need this `hypernest-promote` call.
        #/hypernest-promote degree-plus-one
          bracket-syntax))
      0
      
      0
    #/list 0 #/trivial)
  #/hypertee-contour
    ; This is everything inside of the bracket.
    (hypernest-dv-map-all-degrees interior-and-closing-brackets
    #/fn d data
      (trivial))
  ; This is everything after the bracket's closing brackets. These
  ; things are outside of the bracket.
  #/hypertee-dv-map-all-degrees closing-brackets #/fn d data
    (mat d 0
      (dissect data (trivial)
      #/n-hn 1 #/list 0 #/trivial)
    #/dissect data (list bracket-syntax tail)
      tail)))

(define-syntax ^< #/simple-hn-builder-syntax #/fn stx
  (helper-for-^<-and-^> stx #/hn-tag-nest))

(define-syntax ^> #/simple-hn-builder-syntax #/fn stx
  (helper-for-^<-and-^> stx #/hn-tag-unmatched-closing-bracket))
