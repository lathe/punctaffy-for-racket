#lang parendown/slash racket/base

; punctaffy
;
; Bindings that every program that uses Punctaffy-based DSLs should
; have at hand. Namely, the notations for the hyperbrackets
; themselves.

;   Copyright 2021, 2022 The Lathe Authors
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


(require /for-syntax racket/base)
(require /for-syntax /only-in syntax/parse attribute syntax-parse)

(require /for-syntax /only-in lathe-comforts fn)

(require /for-syntax /only-in punctaffy/private/util
  datum->syntax-with-everything)
(require /for-syntax /only-in punctaffy/syntax-object/token-of-syntax
  list->token-of-syntax syntax->token-of-syntax
  token-of-syntax-beginning-with-assert-singular
  token-of-syntax-beginning-with-list*
  token-of-syntax-beginning-with-splicing-free-var
  token-of-syntax-beginning-with-syntax)
(require /for-syntax /only-in punctaffy/taffy-notation
  makeshift-taffy-notation-akin-to-^<>d)


(provide
  ^<d
  ^>d
  ^<
  ^>)


(define-for-syntax (replace-body stx new-body)
  (syntax-parse stx / (macro-name . _)
  /datum->syntax stx `(,#'macro-name ,@new-body) stx stx))

(define-for-syntax (parse-^<>d direction stx)
  (syntax-parse stx / (op degree contents ...)
  /hash
    'context (datum->syntax stx '#%context)
    'direction direction
    'degree #'degree
    'contents (attribute contents)
    
    'token-of-syntax
    (token-of-syntax-beginning-with-syntax
      (datum->syntax-with-everything stx '())
      (token-of-syntax-beginning-with-list*
        (list->token-of-syntax /list
          (syntax->token-of-syntax #'op)
          (token-of-syntax-beginning-with-assert-singular
            (token-of-syntax-beginning-with-splicing-free-var
              'degree))
          (token-of-syntax-beginning-with-splicing-free-var
            'contents))
        (syntax->token-of-syntax /list)))))
(define-syntax ^<d /makeshift-taffy-notation-akin-to-^<>d /fn stx
  (parse-^<>d '< stx))
(define-syntax ^>d /makeshift-taffy-notation-akin-to-^<>d /fn stx
  (parse-^<>d '> stx))

(define-for-syntax (parse-^<> direction degree stx)
  (syntax-parse stx / (op contents ...)
  /hash
    'context (datum->syntax stx '#%context)
    'direction direction
    'degree degree
    'contents (attribute contents)
    
    'token-of-syntax
    (token-of-syntax-beginning-with-syntax
      (datum->syntax-with-everything stx '())
      (token-of-syntax-beginning-with-list*
        (list->token-of-syntax /list
          (syntax->token-of-syntax #'op)
          (token-of-syntax-beginning-with-splicing-free-var
            'contents))
        (syntax->token-of-syntax /list)))))
(define-syntax ^< /makeshift-taffy-notation-akin-to-^<>d /fn stx
  (parse-^<> '< #'2 stx))
(define-syntax ^> /makeshift-taffy-notation-akin-to-^<>d /fn stx
  (parse-^<> '> #'1 stx))
