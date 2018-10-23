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

(define (hnz)
  (hypernest-plus1 #/hypernest-coil-zero))

(define (hnh overall-degree data tails-hypertee)
  (hypernest-plus1
  #/hypernest-coil-hole overall-degree data tails-hypertee))

(define (hnb overall-degree data bump-degree tails-hypertee)
  (hypernest-plus1
  #/hypernest-coil-bump
    overall-degree data bump-degree tails-hypertee))



; ====================================================================
; Testing `degree-and-brackets->hypernest` (`n-hn`) and
; `hypernest-plus1`
; ====================================================================

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



; ===== Testing `hypernest-join-all-degrees` without bumps ===========

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

(check-equal?
  (hypernest-join-all-degrees #/n-hn 2
    (list 1 #/n-hn 2
      (list 0 #/trivial))
    0
    (list 'open 1 'a)
    0
    (list 1 #/n-hn 2
      (list 0 #/trivial))
    0
    (list 0 #/hypernest-pure 2 'a #/n-ht 0))
  (n-hn 2
    (list 'open 1 'a)
    0
    (list 0 'a))
  "Joining hypernests to cancel out simple degree-1 holes with a degree-1 bump in between")

(check-equal?
  (hypernest-join-all-degrees #/n-hn 2
    (list 1 #/n-hn 2
      (list 0 #/trivial))
    0
    (list 'open 2 'a)
    1
    (list 1 #/n-hn 2
      (list 0 #/trivial))
    0
    0
    0
    (list 0 #/hypernest-pure 2 'a #/n-ht 0))
  (n-hn 2
    (list 'open 2 'a)
    1
    0
    0
    (list 0 'a))
  "Joining hypernests to cancel out simple degree-1 holes with a degree-2 bump in between")

(check-equal?
  (hypernest-join-all-degrees #/n-hn 2
    (list 1 #/n-hn 2
      (list 0 #/trivial))
    0
    (list 'open 2 'a)
    (list 'open 1 'a)
    0
    1
    (list 1 #/n-hn 2
      (list 0 #/trivial))
    0
    0
    0
    (list 0 #/hypernest-pure 2 'a #/n-ht 0))
  (n-hn 2
    (list 'open 2 'a)
    (list 'open 1 'a)
    0
    1
    0
    0
    (list 0 'a))
  "Joining hypernests to cancel out simple degree-1 holes with a degree-2 bump in between that has a degree-1 bump inside it")



; ====================================================================
; Testing `hypernest-join-all-degrees` on a more realistic case
; ====================================================================

; A `hypernest-join-all-degrees` call on a value of this shape came up
; while debugging a test in test-hypernest-qq.rkt.
(define sample-hn-expr-shape-as-ast
  (hnb 1 'a 3
    (hnh 3
      (hnb 2 'a 4
        (hnh 4
          (hnb 2 'a 3
            (hnh 3
              (hnb 2 'a 3
                (hnh 3
                  (hnh 2 (trivial)
                    (n-ht 1 (list 0 (hnh 2 (trivial) (n-ht 0)))))
                  (n-ht 0)))
              (n-ht 0)))
          (n-ht 1
            (list 0 (hnh 4 (hnh 2 (trivial) (n-ht 0)) (n-ht 0))))))
      (n-ht 2
        (list 1
          (hnh 3
            (hnb 1 'a 4
              (hnh 4
                (hnb 1 'a 3
                  (hnh 3
                    (hnb 1 'a 3
                      (hnh 3
                        (hnb 1 'a 3
                          (hnh 3 (hnh 1 (trivial) (n-ht 0)) (n-ht 0)))
                        (n-ht 0)))
                    (n-ht 0)))
                (n-ht 1
                  (list 0
                    (hnh 4 (hnh 1 (trivial) (n-ht 0)) (n-ht 0))))))
            (n-ht 1 (list 0 (hnh 3 (trivial) (n-ht 0))))))
        0
        (list 0
          (hnh 3
            (hnh 1 (hnh 1 (trivial) (n-ht 0)) (n-ht 0))
            (n-ht 0)))))))

; We check that the above implementation of
; `sample-hn-expr-shape-as-ast`, which was adapted from log output, is
; equivalent to this implementation that I find to be more readable.
(check-equal?
  (hnb 1 'a 3
    (n-hn 3
      (list 2
        (n-hn 2
          (list 'open 4 'a)
          1
          (list 'open 3 'a)
          0
          (list 'open 3 'a)
          0
          (list 1 (trivial))
          0
          0
          0
          (list 0 (trivial))))
      1
      (list 1
        (n-hn 1
          (list 'open 4 'a)
          1
          (list 'open 3 'a)
          0
          (list 'open 3 'a)
          0
          (list 'open 3 'a)
          0
          0
          0
          (list 0 (trivial))))
      0
      0
      0
      (list 0 (n-hn 1 (list 0 (n-hn 1 (list 0 (trivial))))))))
  sample-hn-expr-shape-as-ast
  "Making sure a certain hn-expression shape we're testing is equivalent to one constructed by mostly bracket representations")

; We check that `sample-hn-expr-shape-as-ast` is equivalent to this
; implementation that I find to be much more readable. It becomes
; really clear that passing this value into
; `hypernest-join-all-degrees` *should* work because the only hole it
; has to deal with is a degree-0 hole with contents that properly fit.
(check-equal?
  (n-hn 1
    (list 'open 3 'a)
    2
    (list 'open 4 'a)
    1
    (list 'open 3 'a)
    0
    (list 'open 3 'a)
    0
    1
    1
    (list 'open 4 'a)
    1
    (list 'open 3 'a)
    0
    (list 'open 3 'a)
    0
    (list 'open 3 'a)
    0
    0
    0
    0
    0
    0
    0
    0
    0
    (list 0 (n-hn 1 (list 0 (trivial)))))
  sample-hn-expr-shape-as-ast
  "A certain hn-expression shape we're testing is equivalent to one constructed by a bracket representation")

; Now that we have a better understanding of the situation that we've
; had trouble with, here's a simplified test that still fails in the
; same way.
(check-equal?
  (hypernest-join-all-degrees #/n-hn 1
    (list 'open 3 'a)
    2
    1
    0
    0
    0
    (list 0 (n-hn 1 (list 0 (trivial)))))
  (n-hn 1
    (list 'open 3 'a)
    2
    1
    0
    0
    0
    (list 0 (trivial)))
  "Joining with a complex degree-3 bump in the way")

(check-equal?
  (hypernest-join-all-degrees #/n-hn 1
    (list 'open 3 'a)
    2
    (list 'open 4 'a)
    1
    (list 'open 3 'a)
    0
    (list 'open 3 'a)
    0
    1
    1
    (list 'open 4 'a)
    1
    (list 'open 3 'a)
    0
    (list 'open 3 'a)
    0
    (list 'open 3 'a)
    0
    0
    0
    0
    0
    0
    0
    0
    0
    (list 0 (n-hn 1 (list 0 (trivial)))))
  (n-hn 1
    (list 'open 3 'a)
    2
    (list 'open 4 'a)
    1
    (list 'open 3 'a)
    0
    (list 'open 3 'a)
    0
    1
    1
    (list 'open 4 'a)
    1
    (list 'open 3 'a)
    0
    (list 'open 3 'a)
    0
    (list 'open 3 'a)
    0
    0
    0
    0
    0
    0
    0
    0
    0
    (list 0 (trivial)))
  "Joining with a bump in the way that's based on real data we encounter in test-hypernest-qq.rkt")



; ===== Testing `hypernest-join-all-degrees-selective` ===============

(define (hnterp val)
  (hypernest-join-selective-interpolation val))

(define (hnnonterp val)
  (hypernest-join-selective-non-interpolation val))

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
