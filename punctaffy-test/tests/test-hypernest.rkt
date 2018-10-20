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
  (hypernest-coil-hole 3 'a
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


; TODO: Put a similar test in test-hypertee.rkt.
(check-equal?
  (hypernest-join-all-degrees #/n-hn 2
    (list 0 #/hypernest-pure 2 'a #/n-ht 0))
  (n-hn 2
    (list 0 'a))
  "Joining hypernests to cancel out a simple degree-0 hole")

; TODO: Put a similar test in test-hypertee.rkt.
(check-equal?
  (hypernest-join-all-degrees #/n-hn 2
    (list 1 #/n-hn 2
      (list 0 #/trivial))
    0
    (list 0 #/hypernest-pure 2 'a #/n-ht 0))
  (n-hn 2
    (list 0 'a))
  "Joining hypernests to cancel out a single simple degree-1 hole")

; TODO NOW: There are several commented-out tests after this. Get them
; all working.

#;
(check-equal?
  (hypernest-join-all-degrees #/n-hn 2
    (list 1 #/n-hn 2
      (list 0 #/trivial))
    0
    (list 1 #/n-hn 2
      (list 0 #/trivial))
    0
    (list 0 #/hypernest-pure 2 'a #/n-ht 0))
  (n-hn 2
    (list 0 'a))
  "Joining hypernests to cancel out simple degree-1 holes")


(define (hnterp val)
  (hypernest-join-selective-interpolation val))

(define (hnnonterp val)
  (hypernest-join-selective-non-interpolation val))

#;
(check-equal?
  (hypernest-join-all-degrees-selective #/n-hn 2
    (list 1 #/hnterp #/n-hn 2
      (list 1 #/hnnonterp 'a)
      0
      (list 1 #/hnnonterp 'a)
      0
      (list 0 #/hnterp #/trivial))
    0
    (list 1 #/hnterp #/n-hn 2
      (list 1 #/hnnonterp 'a)
      0
      (list 1 #/hnnonterp 'a)
      0
      (list 0 #/hnterp #/trivial))
    0
    (list 0 #/hnterp #/hypernest-pure 2 (hnnonterp 'a) #/n-ht 0))
  (n-hn 2
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 0 'a))
  "Joining hypernests selectively when there isn't any selectiveness being exercised")

#;
(check-equal?
  (hypernest-join-all-degrees-selective #/n-hn 2
    (list 1 #/hnterp #/n-hn 2
      (list 1 #/hnnonterp 'a)
      0
      (list 1 #/hnnonterp 'a)
      0
      (list 0 #/hnterp #/trivial))
    0
    (list 1 #/hnnonterp 'a)
    0
    (list 0 #/hnterp #/hypernest-pure 2 (hnnonterp 'a) #/n-ht 0))
  (n-hn 2
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 0 'a))
  "Joining hypernests selectively when there's a degree-1 non-interpolation in the root")

#;
(check-equal?
  (hypernest-join-all-degrees-selective #/n-hn 2
    (list 1 #/hnterp #/n-hn 2
      (list 1 #/hnnonterp 'a)
      0
      (list 1 #/hnnonterp 'a)
      0
      (list 0 #/hnterp #/trivial))
    0
    (list 1 #/hnnonterp 'a)
    0
    (list 0 #/hnnonterp 'a))
  (n-hn 2
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 0 'a))
  "Joining hypernests selectively when there's a degree-0 non-interpolation in the root")
