#lang parendown racket/base

; punctaffy/tests/test-hypertee-2
;
; Unit tests of the hypertee data structure for hypersnippet-shaped
; data.

;   Copyright 2017-2020 The Lathe Authors
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


(require rackunit)

(require #/only-in lathe-comforts fn)
(require #/only-in lathe-comforts/maybe just)
(require #/only-in lathe-comforts/trivial trivial)

(require #/only-in punctaffy/hypersnippet/dim nat-dim-sys)
(require #/only-in punctaffy/hypersnippet/hypertee-2
  ht-bracs htb-labeled hypertee-coil hypertee-coil-hole hypertee-furl
  hypertee-snippet-sys)
(require #/only-in punctaffy/hypersnippet/snippet
  selected snippet-sys-snippet-done snippet-sys-snippet-join
  snippet-sys-snippet-join-selective snippet-sys-snippet-map
  snippet-sys-snippet-undone unselected)

; (We provide nothing from this module.)


(define ds (nat-dim-sys))
(define ss (hypertee-snippet-sys ds))


(define sample-0 (ht-bracs ds 0))
(define sample-closing-1 (ht-bracs ds 1 #/htb-labeled 0 'a))
(define sample-closing-2
  (ht-bracs ds 2 (htb-labeled 1 'a) 0 #/htb-labeled 0 'a))
(define sample-closing-3a
  (ht-bracs ds 3
    (htb-labeled 2 'a)
      1 (htb-labeled 1 'a) 0 0
    0
  #/htb-labeled 0 'a))
(define sample-closing-4
  (ht-bracs ds 4
    (htb-labeled 3 'a)
      2 (htb-labeled 2 'a) 1 1 1 (htb-labeled 1 'a) 0 0 0 0 0 0
    0
  #/htb-labeled 0 'a))
(define sample-closing-5
  (ht-bracs ds 5
    (htb-labeled 4 'a)
      3 (htb-labeled 3 'a) 2 2 2 (htb-labeled 2 'a)
        1 1 1 1 1 1 1 (htb-labeled 1 'a)
        0 0 0 0 0 0 0 0
      0 0 0 0 0 0
    0
  #/htb-labeled 0 'a))

; There was at one point (although not in any code that's been
; committed) a bug in `hypertee-fold` which involved using a mix of
; mutation and pure code, and it made the `c1` and `c2` holes
; disappear.
;
; NOTE: This example has a wandering revision control history since it
; survived a few file reorganization passes as a comment before we
; finally made a test out of it. When it was introduced as a comment,
; it was in file punctaffy-test/punctaffy/tests/multi-phase-qq.rkt.
;
(define sample-closing-3b
  (ht-bracs ds 3
    (htb-labeled 2 'a)
      1
        (htb-labeled 2 'b)
          
          ; NOTE: This bracket and its matching `0` below were not
          ; present when this test case was originally written, but
          ; they are necessary in order to make the
          ; (htb-labeled 1 'c1) and (htb-labeled 1 'c2) make sense
          ; here. Otherwise, in this context, a degree-1 closing
          ; bracket should not be labeled.
          ;
          ; Since this test case was originally written as a
          ; simplification of an intermediate state of one of the
          ; quasiquotation test cases, where the `(htb-labeled 2 ...)`
          ; holes were likely supposed to represent lists in an
          ; s-expression and the `(htb-labeled 1 ...)` holes were
          ; likely supposed to represent symbols, the omission of
          ; these `1` and `0` brackets was probably a mistake while
          ; writing the test case.
          ;
          1
          
            (htb-labeled 1 'c1)
            0
            (htb-labeled 1 'c2)
            0
          
          0
          
        0
        (htb-labeled 1 'c3)
        0
      0
    0
  #/htb-labeled 0 'end))


(define (check-furl-round-trip sample)
  (check-equal? (hypertee-furl ds #/hypertee-coil sample) sample))

(check-furl-round-trip sample-0)
(check-furl-round-trip sample-closing-1)
(check-furl-round-trip sample-closing-2)

(check-equal?
  (hypertee-coil sample-closing-3a)
  (hypertee-coil-hole
    3
    (ht-bracs ds 2
      (htb-labeled 1 #/trivial)
      0
    #/htb-labeled 0 #/trivial)
    'a
    ; TODO: We basically just transcribed this from the result of
    ; `(hypernest-unfurl sample-closing-3a)` in test-hypernest.rkt.
    ; Make sure it's correct.
    (ht-bracs ds 2
      (htb-labeled 1 #/ht-bracs ds 3
        (htb-labeled 1 'a)
        0
      #/htb-labeled 0 #/trivial)
      0
    #/htb-labeled 0 #/ht-bracs ds 3 #/htb-labeled 0 'a)))

(check-furl-round-trip sample-closing-3a)
(check-furl-round-trip sample-closing-4)
(check-furl-round-trip sample-closing-5)
(check-furl-round-trip sample-closing-3b)


(define (check-identity-map sample)
  (check-equal?
    (snippet-sys-snippet-map ss sample #/fn hole data data)
    sample))

(check-identity-map sample-0)
(check-identity-map sample-closing-1)
(check-identity-map sample-closing-2)
(check-identity-map sample-closing-3a)
(check-identity-map sample-closing-4)
(check-identity-map sample-closing-5)
(check-identity-map sample-closing-3b)


(define (check-done-round-trip d sample)
  (check-equal?
    (snippet-sys-snippet-undone ss
      (snippet-sys-snippet-done ss d 'b sample))
    (just #/list d 'b sample)))

(check-done-round-trip 10 sample-0)
(check-done-round-trip 10 sample-closing-1)
(check-done-round-trip 10 sample-closing-2)
(check-done-round-trip 10 sample-closing-3a)
(check-done-round-trip 10 sample-closing-4)
(check-done-round-trip 10 sample-closing-5)
(check-done-round-trip 10 sample-closing-3b)


(check-equal?
  (snippet-sys-snippet-join ss #/ht-bracs ds 2
    (htb-labeled 1 #/ht-bracs ds 2
      (htb-labeled 0 #/trivial))
    0
    (htb-labeled 1 #/ht-bracs ds 2
      (htb-labeled 0 #/trivial))
    0
    (htb-labeled 0
      (snippet-sys-snippet-done ss 2 'a #/ht-bracs ds 0)))
  (ht-bracs ds 2
    (htb-labeled 0 'a))
  "Joining hypertees to cancel out simple degree-1 holes")

; TODO: Put a similar test in test-hypernest.rkt.
(check-equal?
  (snippet-sys-snippet-join ss #/ht-bracs ds 2
    (htb-labeled 1 #/ht-bracs ds 2
      (htb-labeled 1 'a)
      0
      (htb-labeled 1 'a)
      0
      (htb-labeled 0 #/trivial))
    0
    (htb-labeled 1 #/ht-bracs ds 2
      (htb-labeled 1 'a)
      0
      (htb-labeled 1 'a)
      0
      (htb-labeled 0 #/trivial))
    0
    (htb-labeled 0
      (snippet-sys-snippet-done ss 2 'a #/ht-bracs ds 0)))
  (ht-bracs ds 2
    (htb-labeled 1 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 0 'a))
  "Joining hypertees to make a hypertee with more holes than any of the parts on its own")

; TODO: Put a similar test in test-hypernest.rkt.
(check-equal?
  (snippet-sys-snippet-join ss #/ht-bracs ds 2
    (htb-labeled 1 #/snippet-sys-snippet-done ss 2 'a #/ht-bracs ds 1
      (htb-labeled 0 #/trivial))
    0
    (htb-labeled 1 #/ht-bracs ds 2
      (htb-labeled 1 'a)
      0
      (htb-labeled 0 #/trivial))
    0
    (htb-labeled 1 #/ht-bracs ds 2
      (htb-labeled 1 'a)
      0
      (htb-labeled 0 #/trivial))
    0
    (htb-labeled 0
      (snippet-sys-snippet-done ss 2 'a #/ht-bracs ds 0)))
  (ht-bracs ds 2
    (htb-labeled 1 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 0 'a))
  "Joining hypertees where one of the nonzero-degree holes in the root is just a hole rather than an interpolation")

; TODO: Put a similar test in test-hypernest.rkt.
(check-equal?
  (snippet-sys-snippet-join ss #/ht-bracs ds 3
    
    ; This is propagated to the result.
    (htb-labeled 1 #/snippet-sys-snippet-done ss 3 'a #/ht-bracs ds 1
      (htb-labeled 0 #/trivial))
    0
    
    (htb-labeled 2 #/ht-bracs ds 3
      
      ; This is propagated to the result.
      (htb-labeled 2 'a)
      0
      
      ; This is matched up with one of the root's degree-1 sections
      ; and cancelled out.
      (htb-labeled 1 #/trivial)
      0
      
      ; This is propagated to the result.
      (htb-labeled 2 'a)
      0
      
      (htb-labeled 0 #/trivial))
    
    ; This is matched up with the interpolation's corresponding
    ; degree-1 section and cancelled out.
    1
    0
    
    0
    
    ; This is propagated to the result.
    (htb-labeled 1 #/snippet-sys-snippet-done ss 3 'a #/ht-bracs ds 1
      (htb-labeled 0 #/trivial))
    0
    
    (htb-labeled 0
      (snippet-sys-snippet-done ss 3 'a #/ht-bracs ds 0)))
  (ht-bracs ds 3
    (htb-labeled 1 'a)
    0
    (htb-labeled 2 'a)
    0
    (htb-labeled 2 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 0 'a))
  "Joining hypertees where one of the interpolations is degree 2 with its own degree-1 hole")


(check-equal?
  (snippet-sys-snippet-join-selective ss #/ht-bracs ds 2
    (htb-labeled 1 #/selected #/ht-bracs ds 2
      (htb-labeled 1 #/unselected 'a)
      0
      (htb-labeled 1 #/unselected 'a)
      0
      (htb-labeled 0 #/selected #/trivial))
    0
    (htb-labeled 1 #/selected #/ht-bracs ds 2
      (htb-labeled 1 #/unselected 'a)
      0
      (htb-labeled 1 #/unselected 'a)
      0
      (htb-labeled 0 #/selected #/trivial))
    0
    (htb-labeled 0
      (selected
        (snippet-sys-snippet-done ss 2 (unselected 'a)
          (ht-bracs ds 0)))))
  (ht-bracs ds 2
    (htb-labeled 1 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 0 'a))
  "Joining hypertees selectively when there isn't any selectiveness being exercised")

(check-equal?
  (snippet-sys-snippet-join-selective ss #/ht-bracs ds 2
    (htb-labeled 1 #/selected #/ht-bracs ds 2
      (htb-labeled 1 #/unselected 'a)
      0
      (htb-labeled 1 #/unselected 'a)
      0
      (htb-labeled 0 #/selected #/trivial))
    0
    (htb-labeled 1 #/unselected 'a)
    0
    (htb-labeled 0
      (selected
        (snippet-sys-snippet-done ss 2 (unselected 'a)
          (ht-bracs ds 0)))))
  (ht-bracs ds 2
    (htb-labeled 1 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 0 'a))
  "Joining hypertees selectively when there's a degree-1 non-interpolation in the root")

(check-equal?
  (snippet-sys-snippet-join-selective ss #/ht-bracs ds 2
    (htb-labeled 1 #/selected #/ht-bracs ds 2
      (htb-labeled 1 #/unselected 'a)
      0
      (htb-labeled 1 #/unselected 'a)
      0
      (htb-labeled 0 #/selected #/trivial))
    0
    (htb-labeled 1 #/unselected 'a)
    0
    (htb-labeled 0 #/unselected 'a))
  (ht-bracs ds 2
    (htb-labeled 1 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 1 'a)
    0
    (htb-labeled 0 'a))
  "Joining hypertees selectively when there's a degree-0 non-interpolation in the root")
