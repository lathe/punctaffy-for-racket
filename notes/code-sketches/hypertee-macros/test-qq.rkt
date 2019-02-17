#lang parendown racket/base

; test-qq.rkt
;
; Unit tests of a quasiquotation operator defined in terms of
; hypersnippet-shaped data structures.

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

(require "qq.rkt")

; (We provide nothing from this module.)



(check-equal?
  (my-quasiquote uq #/qq
    (a b
      (c d
        (uq (+ 4 5)))))
  `
    (a b
      (c d
        ,(+ 4 5)))
  "The new quasiquote works a lot like the original")

(check-equal?
  (my-quasiquote uq #/qq
    (a b
      (my-quasiquote uq #/_qq
        (c d
          (_uq
            (e f
              (uq (+ 4 5))))))))
  `
    (a b
      (my-quasiquote uq #/_qq
        (c d
          (_uq
            (e f
              ,(+ 4 5))))))
  "The new quasiquote works on data that looks roughly similar to nesting")

(check-equal?
  (my-quasiquote uq #/qq
    (a b
      (my-quasiquote uq #/qq
        (c d
          (uq
            (e f
              (uq (+ 4 5))))))))
  `
    (a b
      (my-quasiquote uq #/qq
        (c d
          (uq
            (e f
              ,(+ 4 5))))))
  "The new quasiquote supports nesting")

(check-equal?
  (my-quasiquote uq #/qq
    (a b
      (my-quasiquote uq #/qq
        (c d
          (uq
            (e f
              (uq (+ 4 5))
              g h))
          i j))
      k l))
  `
    (a b
      (my-quasiquote uq #/qq
        (c d
          (uq
            (e f
              ,(+ 4 5)
              g h))
          i j))
      k l)
  "The new quasiquote supports nesting even when it's not at the end of a list")


; TODO: Turn this into a unit test. There was at one point (although
; not in any code that's been committed) a bug in `hypertee-fold`
; which involved using a mix of mutation and pure code, and it made
; the `c1` and `c2` holes disappear.
;
; We're now using pure code throughout the hypertee implementation,
; but it's still a bit like using mutation in some places since we
; maintain hash tables that simulate mutable heaps. There may be a
; similar bug still lurking in there, maybe for degree-3 holes. We
; should write tests like this with degree-3 holes to check it out.
;
#|
(require punctaffy/hypersnippet/hypertee)

(writeln #/hypertee-unfurl
  (ht-bracs (nat-dim-sys) 3
    (htb-labeled 2 'a)
      1
        (htb-labeled 2 'b)
          (htb-labeled 1 'c1)
          0
          (htb-labeled 1 'c2)
          0
        0
        (htb-labeled 1 'c3)
        0
      0
    0
  #/htb-labeled 0 'end))
|#
