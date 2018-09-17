#lang parendown racket/base

; tests.rkt
;
; Unit tests of the single-phase higher quasiquotation macro system,
; particularly the `-quasiquote` macro.

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


(require #/for-meta 1 racket/base)

(require rackunit)

(require "qq.rkt")

; (We provide nothing from this module.)


; This takes something that might or might not be syntax, and it
; "de-syntaxes" it recursively.
(define (destx x)
  (syntax->datum #/datum->syntax #'foo x))


(begin-for-syntax #/print-syntax-width 10000)


(check-equal? (destx #/-quasiquote 1) 1
  "Quasiquoting a self-quoting literal")
(check-equal? (destx #/-quasiquote a) 'a "Quasiquoting a symbol")
(check-equal? (destx #/-quasiquote (a b c)) '(a b c)
  "Quasiquoting a list")
(check-equal? (destx #/-quasiquote (a (b c) z)) '(a (b c) z)
  "Quasiquoting a nested list")
(check-equal?
  (destx #/-quasiquote (a (b (-unquote 1)) z))
  '(a (b 1) z)
  "Unquoting a self-quoting literal")
(check-equal?
  (destx #/-quasiquote (a (b (-unquote 'c)) z))
  '(a (b c) z)
  "Unquoting a quoted symbol")
(check-equal?
  (destx #/-quasiquote (a (b (-unquote list)) z))
  `(a (b ,list) z)
  "Unquoting a variable")
(check-equal?
  (destx #/-quasiquote (a (b (-unquote (+ 1 2 3))) z))
  '(a (b 6) z)
  "Unquoting an expression")
(check-equal?
  (destx
  #/-quasiquote
    (a (b (-unquote #/-quasiquote #/1 2 #/-unquote #/+ 1 2 3)) z))
  '(a (b (1 2 6)) z)
  "Unquoting another quasiquotation")
(check-equal?
  (destx
  #/-quasiquote
    (a (b (-quasiquote #/1 #/-unquote #/+ 2 #/-unquote #/+ 1 2 3)) z))
  '(a (b (-quasiquote #/1 #/-unquote #/+ 2 6)) z)
  "Nesting quasiquotations")


; This is a set of unit tests we used in a previous incarnation of
; this code.
(check-equal?
  (destx #/-quasiquote #/foo (bar baz) () qux)
  '(foo (bar baz) () qux)
  "Quasiquoting a nested list again")
(check-equal?
  (destx #/-quasiquote #/foo (bar baz) (-quasiquote ()) qux)
  '(foo (bar baz) (-quasiquote ()) qux)
  "Quasiquoting a nested list containing a quasiquoted empty list")
(check-equal?
  (destx #/-quasiquote #/foo (bar baz) (-unquote (* 1 123456)) qux)
  '(foo (bar baz) 123456 qux)
  "Unquoting an expression again")
(check-equal?
  (destx
  #/-quasiquote #/foo
  #/-quasiquote #/bar #/-unquote #/baz #/-unquote #/* 1 123456)
  '(foo #/-quasiquote #/bar #/-unquote #/baz 123456)
  "Nesting quasiquotations again")
