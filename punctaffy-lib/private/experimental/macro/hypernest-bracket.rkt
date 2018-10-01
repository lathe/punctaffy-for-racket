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
  hypernest-plus1 hypernest-promote hypernest-truncate-to-hypertee)
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


(define-for-syntax (unmatched-brackets->holes opening-degree hn-expr)
  
  (define (blah-fn args body)
    (w- tagline
      (apply string-append " blah"
        (list-map args #/fn arg
          (format " ~a" arg)))
    #/begin (displayln #/format "/~a" tagline)
    #/begin0 (body)
    #/begin (displayln #/format "\\~a" tagline)))
  
  (define-syntax-rule (blah arg ... body)
    (blah-fn (list arg ...) (lambda () body)))
  
  (blah "f1" opening-degree hn-expr
  #/expect (hypernest-degree hn-expr) 1
    (error "Expected hn-expr to be a hypernest of degree 1")
  #/w-loop next first-nontrivial-d 1 hn-expr hn-expr
    (blah "f2"
    #/w- dropped (hypernest-drop1 hn-expr)
    #/mat dropped (hypernest-drop1-result-hole data tails)
      (blah "f3"
      #/hypernest-plus1 #/hypernest-drop1-result-hole data
      #/hypertee-map-all-degrees tails #/fn hole tail
        (next (onum-max first-nontrivial-d #/hypertee-degree hole)
          tail))
    #/blah "f4"
    #/dissect dropped
      (hypernest-drop1-result-bump
        data interior-and-bracket-and-tails)
    #/w- ignore
      (fn
        (w- mapped
          (hypernest-map-all-degrees interior-and-bracket-and-tails
          #/fn hole tail
            (next (onum-max first-nontrivial-d #/hypertee-degree hole)
              tail))
        #/blah "f5" opening-degree interior-and-bracket-and-tails
          mapped
        #/hypernest-plus1 #/hypernest-drop1-result-bump data mapped))
    #/expect data (hn-tag-unmatched-closing-bracket) (ignore)
    #/blah "f6"
    #/w- bump-degree-plus-two
      (hypernest-degree interior-and-bracket-and-tails)
    #/expect
      (onum<? bump-degree-plus-two #/onum-plus opening-degree 2)
      #t
      (ignore)
    #/blah "f7"
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
    #/begin (displayln "blah f8") (writeln opening-degree) (writeln tails)
    #/hypernest-plus1 #/hypernest-drop1-result-hole
      (list bracket-syntax bracket-interior)
    #/hypertee-map-all-degrees tails #/fn hole tail
      (next (onum-max first-nontrivial-d #/hypertee-degree hole)
        tail))))



(define-for-syntax (helper-for-^<-and-^> stx bump-value)
  
  (define (blah-fn args body)
    (w- tagline
      (apply string-append " blah"
        (list-map args #/fn arg
          (format " ~a" arg)))
    #/begin (displayln #/format "/~a" tagline)
    #/begin0 (body)
    #/begin (displayln #/format "\\~a" tagline)))
  
  (define-syntax-rule (blah arg ... body)
    (blah-fn (list arg ...) (lambda () body)))
  
  (blah 0
  #/syntax-parse stx
    [op:id
      ; If this syntax transformer is used in an identifier position,
      ; we just expand as though the identifier isn't bound to a
      ; syntax transformer at all.
      (blah 1
      #/n-hn 1 (list 1 #/hn-tag-1-s-expr-stx stx) 0
      #/list 0 #/trivial)]
  #/ (op:id degree-stx:exact-positive-integer interpolation ...)
  #/w- degree (syntax-e #'degree-stx)
  #/w- degree-plus-one (onum-plus degree 1)
  #/w- interior-and-closing-brackets
    (blah 2
    #/unmatched-brackets->holes degree #/blah "2.0.1" #/n-hn-append0 1
    #/list-map (syntax->list #'(interpolation ...)) #/fn interpolation
      (blah 2.1 #/s-expr-stx->hn-expr interpolation))
  #/blah 3
  #/w- closing-brackets
    (hypernest-truncate-to-hypertee interior-and-closing-brackets)
  #/hypernest-plus1 #/hypernest-drop1-result-bump bump-value
  #/hypernest-contour
    ; This is the syntax for the bracket itself.
    (hypernest-join-one-degree 1
    #/blah 4
    #/n-hn degree-plus-one
      (list 'open 2 #/hn-tag-2-list #/datum->syntax stx #/list)
      1
      
      (list 'open 1 #/hn-tag-1-s-expr-stx #'op)
      0
      (list 'open 1 #/hn-tag-1-s-expr-stx #'degree-stx)
      0
      
      (list 1
      #/blah 5
      #/hypernest-join-all-degrees
      #/blah 6
      #/hypernest-contour
        (hypernest-contour (trivial)
        #/blah 7
        #/hypertee-map-all-degrees closing-brackets #/fn hole data
          (trivial))
      #/blah 8
      #/hypertee-map-all-degrees closing-brackets #/fn hole data
        (mat (hypertee-degree hole) 0
          (dissect data (trivial)
          #/blah 9
          #/degree-and-brackets->hypernest degree-plus-one #/list
          #/list 0 #/trivial)
        #/dissect data (list bracket-syntax tail)
        ; TODO: See if we need this `hypernest-promote` call.
;        #/hypernest-promote degree-plus-one
          bracket-syntax))
      0
      
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
    (mat (hypertee-degree hole) 0
      (dissect data (trivial)
      #/degree-and-brackets->hypernest degree #/list
      #/list 0 #/trivial)
    #/dissect data (list bracket-syntax tail)
      tail)))

(define-syntax ^< #/simple-hn-builder-syntax #/fn stx
  (helper-for-^<-and-^> stx #/hn-tag-nest))

(define-syntax ^> #/simple-hn-builder-syntax #/fn stx
  (helper-for-^<-and-^> stx #/hn-tag-unmatched-closing-bracket))
