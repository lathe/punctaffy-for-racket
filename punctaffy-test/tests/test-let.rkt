#lang parendown racket/base

; punctaffy/tests/test-let
;
; Unit tests of binding operators defined in terms of
; hypersnippet-shaped data structures.

;   Copyright 2021 The Lathe Authors
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

(require rackunit)

(require #/only-in lathe-comforts w-)
(require #/only-in parendown pd)

(require punctaffy)
(require punctaffy/let)

; (We provide nothing from this module.)


(check-equal?
  (w- x 5
    (taffy-let ([x (+ 1 2)]) #/^<d 2
      (+ (* 10 x) #/^>d 1 x)))
  (w- x 5
    (let ([x2 (+ 1 2)])
      (+ (* 10 x2) x)))
  "the variable bindings of `taffy-let` only apply within its hyperbracketed body")

(check-equal?
  (taffy-let () #/^<d 2
    (if #f
      (^>d 1 #/error "whoops")
      "whew"))
  (let ()
    (if #f
      (error "whoops")
      "whew"))
  "`taffy-let` only evaluates a spliced expression at the moment it occurs when evaluating the hyperbracketed body")

(check-equal?
  (list-taffy-map #/^<d 2
    (format "~a, ~a!"
      (^>d 1 #/list "Hello" "Goodnight")
      (^>d 1 #/list "world" "everybody")))
  (list "Hello, world!" "Goodnight, everybody!")
  "`list-taffy-map` works")

(check-equal?
  (list-taffy-bind #/^<d 2
    (list (^>d 1 #/list 1 3 5) (^>d 1 #/list 2 4 6)))
  (list 1 2 3 4 5 6)
  "`list-taffy-bind` works")


; These are examples used in the documentation.

(check-equal?
  (pd _/ let ([_x 5])
    (taffy-let ([_x (+ 1 2)]) _/ ^<d 2
      (+ (* 10 _x) _/ ^>d 1 _x)))
  35
  "the variable bindings of `taffy-let` only apply within its hyperbracketed body [documentation example variant]")

(check-equal?
  (pd _/ taffy-let () _/ ^<d 2
    (if #f
      (^>d 1 _/ error "whoops")
      "whew"))
  "whew"
  "`taffy-let` only evaluates a spliced expression at the moment it occurs when evaluating the hyperbracketed body [documentation example variant]")

(check-equal?
  (pd _/ list-taffy-map _/ ^<d 2
    (format "~a, ~a!"
      (^>d 1 _/ list "Hello" "Goodnight")
      (^>d 1 _/ list "world" "everybody")))
  (list "Hello, world!" "Goodnight, everybody!")
  "`list-taffy-map` works [documentation example variant]")

(check-equal?
  (pd _/ list-taffy-bind _/ ^<d 2
    (list (^>d 1 _/ list 1 3 5) (^>d 1 _/ list 2 4 6)))
  (list 1 2 3 4 5 6)
  "`list-taffy-bind` works [documentation example variant]")
