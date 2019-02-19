#lang parendown racket/base

; punctaffy/tests/test-hypernest
;
; Unit tests of the hypernest data structure for hypersnippet-shaped
; data.

;   Copyright 2018-2019 The Lathe Authors
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

(require #/only-in lathe-comforts dissect fn mat w-)
(require #/only-in lathe-comforts/list list-map)
(require #/only-in lathe-comforts/trivial trivial)

(require punctaffy/hypersnippet/dim)
(require punctaffy/hypersnippet/hypernest)
(require punctaffy/hypersnippet/hypertee)

; (We provide nothing from this module.)


(define ds (nat-dim-sys))

(define (hnz)
  (hypernest-furl ds #/hypernest-coil-zero))

(define (hnh overall-degree data tails-hypertee)
  (hypernest-furl ds
  #/hypernest-coil-hole overall-degree data tails-hypertee))

(define (hno overall-degree data bump-degree tails-hypertee)
  (hypernest-furl ds
  #/hypernest-coil-bump
    overall-degree data bump-degree tails-hypertee))



; ====================================================================
; Testing `hypernest-from-brackets` (`hn-bracs`) and `hypernest-furl`
; ====================================================================

(define (make-sample degree . brackets)
  (list degree
    (list-map brackets #/fn bracket
      (mat bracket (hnb-open d data) bracket
      #/mat bracket (hnb-labeled d data) bracket
      #/mat bracket (hnb-unlabeled d) bracket
      #/hnb-unlabeled bracket))))

; NOTE: These are the same as some of the hypertee tests in
; test-hypertee.rkt.
(define sample-0 (make-sample 0))
(define sample-closing-1 (make-sample 1 #/hnb-labeled 0 'a))
(define sample-closing-2
  (make-sample 2 (hnb-labeled 1 'a) 0 #/hnb-labeled 0 'a))
(define sample-closing-3a
  (make-sample 3
    (hnb-labeled 2 'a)
      1 (hnb-labeled 1 'a) 0 0
    0
  #/hnb-labeled 0 'a))
(define sample-closing-4
  (make-sample 4
    (hnb-labeled 3 'a)
      2 (hnb-labeled 2 'a) 1 1 1 (hnb-labeled 1 'a) 0 0 0 0 0 0
    0
  #/hnb-labeled 0 'a))
(define sample-closing-5
  (make-sample 5
    (hnb-labeled 4 'a)
      3 (hnb-labeled 3 'a) 2 2 2 (hnb-labeled 2 'a)
        1 1 1 1 1 1 1 (hnb-labeled 1 'a)
        0 0 0 0 0 0 0 0
      0 0 0 0 0 0
    0
  #/hnb-labeled 0 'a))
(define sample-closing-3b
  (make-sample 3
    (hnb-labeled 2 'a)
      1
        (hnb-labeled 2 'b)
          1
            (hnb-labeled 1 'c1)
            0
            (hnb-labeled 1 'c2)
            0
          0
        0
        (hnb-labeled 1 'c3)
        0
      0
    0
  #/hnb-labeled 0 'end))


(define sample-opening-1a
  (make-sample 1
    (hnb-open 1 'a)
    0
    (hnb-open 2 'a)
    1
    (hnb-open 1 'a)
    0
    0
    0
    (hnb-labeled 0 'a)))

(define sample-opening-1b
  (make-sample 1 (hnb-open 0 'a) (hnb-labeled 0 'a)))

(define sample-opening-2
  (make-sample 2
    (hnb-open 0 'a)
    (hnb-labeled 1 'a)
    0
    (hnb-labeled 0 'a)))



(define (db->hn degree-and-brackets)
  (dissect degree-and-brackets (list degree brackets)
  #/hypernest-from-brackets ds degree brackets))

(define (check-brackets-round-trip sample)
  (w- hn (db->hn sample)
  #/check-equal?
    (list (hypernest-degree hn) (hypernest-get-brackets hn))
    sample))

(check-brackets-round-trip sample-0)
(check-brackets-round-trip sample-closing-1)
(check-brackets-round-trip sample-closing-2)
(check-brackets-round-trip sample-closing-3a)
(check-brackets-round-trip sample-closing-4)
(check-brackets-round-trip sample-closing-5)
(check-brackets-round-trip sample-closing-3b)
(check-brackets-round-trip sample-opening-1a)
(check-brackets-round-trip sample-opening-1b)
(check-brackets-round-trip sample-opening-2)

(define (check-furl-round-trip sample)
  (w- sample (db->hn sample)
  #/check-equal? (hypernest-furl ds #/hypernest-unfurl sample)
    sample))

(check-furl-round-trip sample-0)
(check-furl-round-trip sample-closing-1)
(check-furl-round-trip sample-closing-2)

(check-equal?
  (hypernest-unfurl #/db->hn sample-closing-3a)
  (hypernest-coil-hole 3 'a
    ; TODO: We basically just transcribed this from the result of
    ; `(hypernest-unfurl #/db->hn sample-closing-3a)`. Make sure it's
    ; correct.
    (ht-bracs ds 2
      (htb-labeled 1 #/hn-bracs ds 3
        (hnb-labeled 1 'a)
        0
      #/hnb-labeled 0 #/trivial)
      0
    #/htb-labeled 0 #/hn-bracs ds 3 #/hnb-labeled 0 'a)))

(check-furl-round-trip sample-closing-3a)
(check-furl-round-trip sample-closing-4)
(check-furl-round-trip sample-closing-5)
(check-furl-round-trip sample-closing-3b)
(check-furl-round-trip sample-opening-1a)
(check-furl-round-trip sample-opening-1b)
(check-furl-round-trip sample-opening-2)



; ===== Testing `hypernest-join-all-degrees` without bumps ===========

; TODO: Put a similar test in test-hypertee.rkt.
(check-equal?
  (hypernest-join-all-degrees #/hn-bracs ds 2
    (hnb-labeled 0 #/hypernest-done 2 'a #/ht-bracs ds 0))
  (hn-bracs ds 2
    (hnb-labeled 0 'a))
  "Joining hypernests to cancel out a simple degree-0 hole")

; TODO: Put a similar test in test-hypertee.rkt.
(check-equal?
  (hypernest-join-all-degrees #/hn-bracs ds 2
    (hnb-labeled 1 #/hn-bracs ds 2
      (hnb-labeled 0 #/trivial))
    0
    (hnb-labeled 0 #/hypernest-done 2 'a #/ht-bracs ds 0))
  (hn-bracs ds 2
    (hnb-labeled 0 'a))
  "Joining hypernests to cancel out a single simple degree-1 hole")

(check-equal?
  (hypernest-join-all-degrees #/hn-bracs ds 2
    (hnb-labeled 1 #/hn-bracs ds 2
      (hnb-labeled 0 #/trivial))
    0
    (hnb-labeled 1 #/hn-bracs ds 2
      (hnb-labeled 0 #/trivial))
    0
    (hnb-labeled 0 #/hypernest-done 2 'a #/ht-bracs ds 0))
  (hn-bracs ds 2
    (hnb-labeled 0 'a))
  "Joining hypernests to cancel out simple degree-1 holes")

(check-equal?
  (hypernest-join-all-degrees #/hn-bracs ds 2
    (hnb-labeled 1 #/hn-bracs ds 2
      (hnb-labeled 0 #/trivial))
    0
    (hnb-open 1 'a)
    0
    (hnb-labeled 1 #/hn-bracs ds 2
      (hnb-labeled 0 #/trivial))
    0
    (hnb-labeled 0 #/hypernest-done 2 'a #/ht-bracs ds 0))
  (hn-bracs ds 2
    (hnb-open 1 'a)
    0
    (hnb-labeled 0 'a))
  "Joining hypernests to cancel out simple degree-1 holes with a degree-1 bump in between")

(check-equal?
  (hypernest-join-all-degrees #/hn-bracs ds 2
    (hnb-labeled 1 #/hn-bracs ds 2
      (hnb-labeled 0 #/trivial))
    0
    (hnb-open 2 'a)
    1
    (hnb-labeled 1 #/hn-bracs ds 2
      (hnb-labeled 0 #/trivial))
    0
    0
    0
    (hnb-labeled 0 #/hypernest-done 2 'a #/ht-bracs ds 0))
  (hn-bracs ds 2
    (hnb-open 2 'a)
    1
    0
    0
    (hnb-labeled 0 'a))
  "Joining hypernests to cancel out simple degree-1 holes with a degree-2 bump in between")

(check-equal?
  (hypernest-join-all-degrees #/hn-bracs ds 2
    (hnb-labeled 1 #/hn-bracs ds 2
      (hnb-labeled 0 #/trivial))
    0
    (hnb-open 2 'a)
    (hnb-open 1 'a)
    0
    1
    (hnb-labeled 1 #/hn-bracs ds 2
      (hnb-labeled 0 #/trivial))
    0
    0
    0
    (hnb-labeled 0 #/hypernest-done 2 'a #/ht-bracs ds 0))
  (hn-bracs ds 2
    (hnb-open 2 'a)
    (hnb-open 1 'a)
    0
    1
    0
    0
    (hnb-labeled 0 'a))
  "Joining hypernests to cancel out simple degree-1 holes with a degree-2 bump in between that has a degree-1 bump inside it")



; ====================================================================
; Testing `hypernest-join-all-degrees` on a more realistic case
; ====================================================================

; A `hypernest-join-all-degrees` call on a value of this shape came up
; while debugging a test in test-hypernest-qq.rkt.
(define sample-hn-expr-shape-as-ast
  (hno 1 'a 3
    (hnh 3
      (hno 2 'a 4
        (hnh 4
          (hno 2 'a 3
            (hnh 3
              (hno 2 'a 3
                (hnh 3
                  (hnh 2 (trivial)
                    (ht-bracs ds 1
                      (htb-labeled 0
                        (hnh 2 (trivial) (ht-bracs ds 0)))))
                  (ht-bracs ds 0)))
              (ht-bracs ds 0)))
          (ht-bracs ds 1
            (htb-labeled 0
              (hnh 4
                (hnh 2 (trivial) (ht-bracs ds 0))
                (ht-bracs ds 0))))))
      (ht-bracs ds 2
        (htb-labeled 1
          (hnh 3
            (hno 1 'a 4
              (hnh 4
                (hno 1 'a 3
                  (hnh 3
                    (hno 1 'a 3
                      (hnh 3
                        (hno 1 'a 3
                          (hnh 3
                            (hnh 1 (trivial) (ht-bracs ds 0))
                            (ht-bracs ds 0)))
                        (ht-bracs ds 0)))
                    (ht-bracs ds 0)))
                (ht-bracs ds 1
                  (htb-labeled 0
                    (hnh 4
                      (hnh 1 (trivial) (ht-bracs ds 0))
                      (ht-bracs ds 0))))))
            (ht-bracs ds 1
              (htb-labeled 0 (hnh 3 (trivial) (ht-bracs ds 0))))))
        0
        (htb-labeled 0
          (hnh 3
            (hnh 1 (hnh 1 (trivial) (ht-bracs ds 0)) (ht-bracs ds 0))
            (ht-bracs ds 0)))))))

; We check that the above implementation of
; `sample-hn-expr-shape-as-ast`, which was adapted from log output, is
; equivalent to this implementation that I find to be more readable.
(check-equal?
  (hno 1 'a 3
    (hn-bracs ds 3
      (hnb-labeled 2
        (hn-bracs ds 2
          (hnb-open 4 'a)
          1
          (hnb-open 3 'a)
          0
          (hnb-open 3 'a)
          0
          (hnb-labeled 1 (trivial))
          0
          0
          0
          (hnb-labeled 0 (trivial))))
      1
      (hnb-labeled 1
        (hn-bracs ds 1
          (hnb-open 4 'a)
          1
          (hnb-open 3 'a)
          0
          (hnb-open 3 'a)
          0
          (hnb-open 3 'a)
          0
          0
          0
          (hnb-labeled 0 (trivial))))
      0
      0
      0
      (hnb-labeled 0
        (hn-bracs ds 1
          (hnb-labeled 0
            (hn-bracs ds 1 (hnb-labeled 0 (trivial))))))))
  sample-hn-expr-shape-as-ast
  "Making sure a certain hn-expression shape we're testing is equivalent to one constructed by mostly bracket representations")

; We check that `sample-hn-expr-shape-as-ast` is equivalent to this
; implementation that I find to be much more readable. It becomes
; really clear that passing this value into
; `hypernest-join-all-degrees` *should* work because the only hole it
; has to deal with is a degree-0 hole with contents that properly fit.
(check-equal?
  (hn-bracs ds 1
    (hnb-open 3 'a)
    2
    (hnb-open 4 'a)
    1
    (hnb-open 3 'a)
    0
    (hnb-open 3 'a)
    0
    1
    1
    (hnb-open 4 'a)
    1
    (hnb-open 3 'a)
    0
    (hnb-open 3 'a)
    0
    (hnb-open 3 'a)
    0
    0
    0
    0
    0
    0
    0
    0
    0
    (hnb-labeled 0 (hn-bracs ds 1 (hnb-labeled 0 (trivial)))))
  sample-hn-expr-shape-as-ast
  "A certain hn-expression shape we're testing is equivalent to one constructed by a bracket representation")

; Now that we have a better understanding of the situation that we've
; had trouble with, here's a simplified test that still fails in the
; same way.
(check-equal?
  (hypernest-join-all-degrees #/hn-bracs ds 1
    (hnb-open 3 'a)
    2
    1
    0
    0
    0
    (hnb-labeled 0 (hn-bracs ds 1 (hnb-labeled 0 (trivial)))))
  (hn-bracs ds 1
    (hnb-open 3 'a)
    2
    1
    0
    0
    0
    (hnb-labeled 0 (trivial)))
  "Joining with a complex degree-3 bump in the way")

(check-equal?
  (hypernest-join-all-degrees #/hn-bracs ds 1
    (hnb-open 3 'a)
    2
    (hnb-open 4 'a)
    1
    (hnb-open 3 'a)
    0
    (hnb-open 3 'a)
    0
    1
    1
    (hnb-open 4 'a)
    1
    (hnb-open 3 'a)
    0
    (hnb-open 3 'a)
    0
    (hnb-open 3 'a)
    0
    0
    0
    0
    0
    0
    0
    0
    0
    (hnb-labeled 0 (hn-bracs ds 1 (hnb-labeled 0 (trivial)))))
  (hn-bracs ds 1
    (hnb-open 3 'a)
    2
    (hnb-open 4 'a)
    1
    (hnb-open 3 'a)
    0
    (hnb-open 3 'a)
    0
    1
    1
    (hnb-open 4 'a)
    1
    (hnb-open 3 'a)
    0
    (hnb-open 3 'a)
    0
    (hnb-open 3 'a)
    0
    0
    0
    0
    0
    0
    0
    0
    0
    (hnb-labeled 0 (trivial)))
  "Joining with a bump in the way that's based on real data we encounter in test-hypernest-qq.rkt")



; ====================================================================
; Testing `hypernest-join-all-degrees` on bumps of degree 0
; ====================================================================

(check-equal?
  (hypernest-join-all-degrees #/hn-bracs ds 1
    (hnb-open 0 'a)
    (hnb-labeled 0 (hn-bracs ds 1 (hnb-labeled 0 (trivial)))))
  (hn-bracs ds 1
    (hnb-open 0 'a)
    (hnb-labeled 0 (trivial)))
  "Joining with a bump of degree 0 in the way")



; ===== Testing `hypernest-join-all-degrees-selective` ===============

(define (hnterp val)
  (hypernest-join-selective-interpolation val))

(define (hnnonterp val)
  (hypernest-join-selective-non-interpolation val))

(check-equal?
  (hypernest-join-all-degrees-selective #/hn-bracs ds 2
    (hnb-labeled 1 #/hnterp #/hn-bracs ds 2
      (hnb-labeled 1 #/hnnonterp 'a)
      0
      (hnb-labeled 1 #/hnnonterp 'a)
      0
      (hnb-labeled 0 #/hnterp #/trivial))
    0
    (hnb-labeled 1 #/hnterp #/hn-bracs ds 2
      (hnb-labeled 1 #/hnnonterp 'a)
      0
      (hnb-labeled 1 #/hnnonterp 'a)
      0
      (hnb-labeled 0 #/hnterp #/trivial))
    0
    (hnb-labeled 0
      (hnterp #/hypernest-done 2 (hnnonterp 'a) #/ht-bracs ds 0)))
  (hn-bracs ds 2
    (hnb-labeled 1 'a)
    0
    (hnb-labeled 1 'a)
    0
    (hnb-labeled 1 'a)
    0
    (hnb-labeled 1 'a)
    0
    (hnb-labeled 0 'a))
  "Joining hypernests selectively when there isn't any selectiveness being exercised")

(check-equal?
  (hypernest-join-all-degrees-selective #/hn-bracs ds 2
    (hnb-labeled 1 #/hnterp #/hn-bracs ds 2
      (hnb-labeled 1 #/hnnonterp 'a)
      0
      (hnb-labeled 1 #/hnnonterp 'a)
      0
      (hnb-labeled 0 #/hnterp #/trivial))
    0
    (hnb-labeled 1 #/hnnonterp 'a)
    0
    (hnb-labeled 0
      (hnterp #/hypernest-done 2 (hnnonterp 'a) #/ht-bracs ds 0)))
  (hn-bracs ds 2
    (hnb-labeled 1 'a)
    0
    (hnb-labeled 1 'a)
    0
    (hnb-labeled 1 'a)
    0
    (hnb-labeled 0 'a))
  "Joining hypernests selectively when there's a degree-1 non-interpolation in the root")

(check-equal?
  (hypernest-join-all-degrees-selective #/hn-bracs ds 2
    (hnb-labeled 1 #/hnterp #/hn-bracs ds 2
      (hnb-labeled 1 #/hnnonterp 'a)
      0
      (hnb-labeled 1 #/hnnonterp 'a)
      0
      (hnb-labeled 0 #/hnterp #/trivial))
    0
    (hnb-labeled 1 #/hnnonterp 'a)
    0
    (hnb-labeled 0 #/hnnonterp 'a))
  (hn-bracs ds 2
    (hnb-labeled 1 'a)
    0
    (hnb-labeled 1 'a)
    0
    (hnb-labeled 1 'a)
    0
    (hnb-labeled 0 'a))
  "Joining hypernests selectively when there's a degree-0 non-interpolation in the root")



; ===== Testing `hypernest-truncate-to-hypertee` =====================

(check-equal?
  (hypernest-truncate-to-hypertee #/hn-bracs ds 1
    (hnb-open 1 'a)
    0
    (hnb-labeled 0 'a))
  (ht-bracs ds 1
    (htb-labeled 0 'a))
  "Truncating a degree-1 hypernest to a hypertee")

(check-equal?
  (hypernest-truncate-to-hypertee #/hn-bracs ds 1
    (hnb-open 1 'a)
    0
    (hnb-open 1 'a)
    0
    (hnb-open 1 'a)
    0
    (hnb-labeled 0 'a))
  (ht-bracs ds 1
    (htb-labeled 0 'a))
  "Truncating a degree-1 hypernest with multiple bumps to a hypertee")

(check-equal?
  (hypernest-truncate-to-hypertee #/hn-bracs ds 1
    (hnb-open 2 'a)
    1
    (hnb-open 1 'a)
    0
    0
    0
    (hnb-open 1 'a)
    0
    (hnb-labeled 0 'a))
  (ht-bracs ds 1
    (htb-labeled 0 'a))
  "Truncating a degree-1 hypernest with a degree-2 bump to a hypertee")

(check-equal?
  (hypernest-truncate-to-hypertee #/hn-bracs ds 2
    (hnb-open 1 'a)
    0
    (hnb-labeled 1 'a)
    0
    (hnb-open 1 'a)
    0
    (hnb-labeled 0 'a))
  (ht-bracs ds 2
    (htb-labeled 1 'a)
    0
    (htb-labeled 0 'a))
  "Truncating a degree-2 hypernest to a hypertee")

(check-equal?
  (hypernest-truncate-to-hypertee #/hn-bracs ds 2
    (hnb-open 2 'a)
    1
    (hnb-labeled 1 'a)
    0
    0
    0
    (hnb-labeled 0 'a))
  (ht-bracs ds 2
    (htb-labeled 1 'a)
    0
    (htb-labeled 0 'a))
  "Truncating a degree-2 hypernest with a degree-2 bump to a hypertee")
