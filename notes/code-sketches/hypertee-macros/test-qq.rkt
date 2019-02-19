#lang parendown racket/base

; test-qq.rkt
;
; Unit tests of a quasiquotation operator defined in terms of
; hypersnippet-shaped data structures.

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
