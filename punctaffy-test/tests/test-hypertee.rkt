#lang parendown racket/base

; punctaffy/tests/test-hypertee
;
; Unit tests of the hypertee data structure for hypersnippet-shaped
; data.

;   Copyright 2017-2018 The Lathe Authors
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

(require punctaffy/hypersnippet/hypertee)

; (We provide nothing from this module.)


(define (n-ht degree . brackets)
  (degree-and-closing-brackets->hypertee degree brackets))


(define sample-0 (n-ht 0))
(define sample-closing-1 (n-ht 1 (list 0 'a)))
(define sample-closing-2
  (n-ht 2
    (list 1 'a)
    0 (list 0 'a)))
(define sample-closing-3
  (n-ht 3
    (list 2 'a)
    1 (list 1 'a) 0 0 0 (list 0 'a)))
(define sample-closing-4
  (n-ht 4
    (list 3 'a)
    2 (list 2 'a) 1 1 1 (list 1 'a) 0 0 0 0 0 0 0 (list 0 'a)))
(define sample-closing-5
  (n-ht 5
    (list 4 'a)
    3 (list 3 'a) 2 2 2 (list 2 'a) 1 1 1 1 1 1 1 (list 1 'a)
    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 (list 0 'a)))


(define (check-drop1-round-trip sample)
  (check-equal? (hypertee-plus1 #/hypertee-drop1 sample) sample))

(check-drop1-round-trip sample-0)
(check-drop1-round-trip sample-closing-1)
(check-drop1-round-trip sample-closing-2)

(check-equal?
  (hypertee-drop1 sample-closing-3)
  (just #/list 'a
    ; TODO: We basically just transcribed this from the result of
    ; `(hypernest-drop1 sample-closing-3)` in test-hypernest.rkt. Make
    ; sure it's correct.
    (n-ht 2
      (list 1 #/n-ht 3
        (list 1 'a)
        0
      #/list 0 #/trivial)
      0
    #/list 0 #/n-ht 3 #/list 0 'a)))

(check-drop1-round-trip sample-closing-3)
(check-drop1-round-trip sample-closing-4)
(check-drop1-round-trip sample-closing-5)


(check-equal?
  (hypertee-join-all-degrees #/n-ht 2
    (list 1 #/n-ht 2
      (list 0 #/trivial))
    0
    (list 1 #/n-ht 2
      (list 0 #/trivial))
    0
    (list 0 #/hypertee-pure 2 'a #/n-ht 0))
  (n-ht 2
    (list 0 'a))
  "Joining hypertees to cancel out simple degree-1 holes")

(check-equal?
  (hypertee-join-all-degrees #/n-ht 2
    (list 1 #/n-ht 2
      (list 1 'a)
      0
      (list 1 'a)
      0
      (list 0 #/trivial))
    0
    (list 1 #/n-ht 2
      (list 1 'a)
      0
      (list 1 'a)
      0
      (list 0 #/trivial))
    0
    (list 0 #/hypertee-pure 2 'a #/n-ht 0))
  (n-ht 2
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 0 'a))
  "Joining hypertees to make a hypertee with more holes than any of the parts on its own")

(check-equal?
  (hypertee-join-all-degrees #/n-ht 2
    (list 1 #/hypertee-pure 2 'a #/n-ht 1
      (list 0 #/trivial))
    0
    (list 1 #/n-ht 2
      (list 1 'a)
      0
      (list 0 #/trivial))
    0
    (list 1 #/n-ht 2
      (list 1 'a)
      0
      (list 0 #/trivial))
    0
    (list 0 #/hypertee-pure 2 'a #/n-ht 0))
  (n-ht 2
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 0 'a))
  "Joining hypertees where one of the nonzero-degree holes in the root is just a hole rather than an interpolation")

(check-equal?
  (hypertee-join-all-degrees #/n-ht 3
    
    ; This is propagated to the result.
    (list 1 #/hypertee-pure 3 'a #/n-ht 1
      (list 0 #/trivial))
    0
    
    (list 2 #/n-ht 3
      
      ; This is propagated to the result.
      (list 2 'a)
      0
      
      ; This is matched up with one of the root's degree-1 sections
      ; and cancelled out.
      (list 1 #/trivial)
      0
      
      ; This is propagated to the result.
      (list 2 'a)
      0
      
      (list 0 #/trivial))
    
    ; This is matched up with the interpolation's corresponding
    ; degree-1 section and cancelled out.
    1
    0
    
    0
    
    ; This is propagated to the result.
    (list 1 #/hypertee-pure 3 'a #/n-ht 1
      (list 0 #/trivial))
    0
    
    (list 0 #/hypertee-pure 3 'a #/n-ht 0))
  (n-ht 3
    (list 1 'a)
    0
    (list 2 'a)
    0
    (list 2 'a)
    0
    (list 1 'a)
    0
    (list 0 'a))
  "Joining hypertees where one of the interpolations is degree 2 with its own degree-1 hole")
