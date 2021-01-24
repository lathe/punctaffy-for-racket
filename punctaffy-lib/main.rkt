#lang parendown racket/base

; punctaffy
;
; Bindings that every program that uses Punctaffy-based DSLs should
; have at hand. Namely, the notations for the hyperbrackets
; themselves.

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
(require #/for-syntax #/only-in syntax/parse syntax-parse)

(require #/for-syntax #/only-in lathe-comforts fn)

(require #/for-syntax #/only-in punctaffy/hyperbracket
  hyperbracket-close-with-degree hyperbracket-open-with-degree
  makeshift-hyperbracket-notation-prefix-expander)


(provide
  ^<d
  ^>d
  ^<
  ^>)


(define-syntax ^<d (hyperbracket-open-with-degree))
(define-syntax ^>d (hyperbracket-close-with-degree))

(define-syntax ^<
  (makeshift-hyperbracket-notation-prefix-expander #/fn stx
    (syntax-parse stx #/ (_ term ...) #'(^<d 2 term ...))))

(define-syntax ^>
  (makeshift-hyperbracket-notation-prefix-expander #/fn stx
    (syntax-parse stx #/ (_ term ...) #'(^>d 1 term ...))))
