#lang parendown racket/base

; punctaffy/tests/test-hypernest
;
; Unit tests of the hypernest data structure for hypersnippet-shaped
; data.

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


(require rackunit)

(require #/only-in lathe-comforts fn)
(require #/only-in lathe-comforts/trivial trivial)

(require punctaffy/hypersnippet/hypernest)
(require punctaffy/hypersnippet/hypertee)

; (We provide nothing from this module.)


(define (n-ht degree . brackets)
  (degree-and-closing-brackets->hypertee degree brackets))

(define (n-hn degree . brackets)
  (degree-and-brackets->hypernest degree brackets))


; NOTE: These are the same as some of the hypertee tests in
; test-hypertee.rkt.
(define sample-0 (n-hn 0))
(define sample-closing-1 (n-hn 1 (list 0 'a)))
(define sample-closing-2
  (n-hn 2
    (list 1 'a)
    0 (list 0 'a)))
(define sample-closing-3
  (n-hn 3
    (list 2 'a)
    1 (list 1 'a) 0 0 0 (list 0 'a)))
(define sample-closing-4
  (n-hn 4
    (list 3 'a)
    2 (list 2 'a) 1 1 1 (list 1 'a) 0 0 0 0 0 0 0 (list 0 'a)))
(define sample-closing-5
  (n-hn 5
    (list 4 'a)
    3 (list 3 'a) 2 2 2 (list 2 'a) 1 1 1 1 1 1 1 (list 1 'a)
    0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 (list 0 'a)))


(define sample-opening-1
  (n-hn 1
    (list 'open 1 'a)
    0
    (list 'open 2 'a)
    1
    (list 'open 1 'a)
    0
    0
    0
    (list 0 'a)))


(define (check-drop1-round-trip sample)
  (check-equal? (hypernest-plus1 #/hypernest-drop1 sample) sample))

(check-drop1-round-trip sample-0)
(check-drop1-round-trip sample-closing-1)
(check-drop1-round-trip sample-closing-2)

(check-equal?
  (hypernest-drop1 sample-closing-3)
  (hypernest-coil-hole 2 'a
    ; TODO: We basically just transcribed this from the result of
    ; `(hypernest-drop1 sample-closing-3)`. Make sure it's correct.
    (n-ht 2
      (list 1 #/n-hn 3
        (list 1 'a)
        0
      #/list 0 #/trivial)
      0
    #/list 0 #/n-hn 3 #/list 0 'a)))

(check-drop1-round-trip sample-closing-3)
(check-drop1-round-trip sample-closing-4)
(check-drop1-round-trip sample-closing-5)
(check-drop1-round-trip sample-opening-1)
