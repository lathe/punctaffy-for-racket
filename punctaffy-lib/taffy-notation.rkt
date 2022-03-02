#lang parendown/slash racket/base

; punctaffy/taffy-notation
;
; Interfaces to represent syntactic keywords that other Racket macros
; can parse as hyperbrackets, escape sequences, or other kinds of
; Punctaffy notation.

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


(require /only-in racket/contract struct-type-property/c)
(require /only-in racket/contract/base
  -> and/c any/c hash/dc listof none/c or/c)
(require /only-in racket/match match)
(require /only-in racket/set set)

(require /only-in lathe-comforts dissect fn)
(require /only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct)

(require punctaffy/private/shim)
(init-shim)

(require /only-in punctaffy/syntax-object/token-of-syntax
  token-of-syntax-with-free-vars<=/c)


(provide /own-contract-out
  
  taffy-notation?
  taffy-notation-impl?
  prop:taffy-notation
  make-taffy-notation-impl
  
  taffy-notation-akin-to-^<>d?
  taffy-notation-akin-to-^<>d-impl?
  taffy-notation-akin-to-^<>d-parse
  prop:taffy-notation-akin-to-^<>d
  make-taffy-notation-akin-to-^<>d-impl
  makeshift-taffy-notation-akin-to-^<>d)


(define-imitation-simple-generics
  taffy-notation?
  taffy-notation-impl?
  prop:taffy-notation make-taffy-notation-impl
  'taffy-notation 'taffy-notation-impl (list))
(ascribe-own-contract taffy-notation? (-> any/c boolean?))
(ascribe-own-contract taffy-notation-impl? (-> any/c boolean?))
(ascribe-own-contract prop:taffy-notation
  (struct-type-property/c taffy-notation-impl?))
(ascribe-own-contract make-taffy-notation-impl
  (-> taffy-notation-impl?))

(define (raise-taffy-notation-as-expression-error stx)
  (raise-syntax-error #f "taffy notation keyword not allowed as an expression"
    stx))

(define-imitation-simple-generics
  taffy-notation-akin-to-^<>d?
  taffy-notation-akin-to-^<>d-impl?
  (#:method taffy-notation-akin-to-^<>d-parse (#:this) ())
  prop:taffy-notation-akin-to-^<>d
  make-taffy-notation-akin-to-^<>d-impl
  'taffy-notation-akin-to-^<>d
  'taffy-notation-akin-to-^<>d-impl
  (list))
(ascribe-own-contract taffy-notation-akin-to-^<>d?
  (-> any/c boolean?))
(ascribe-own-contract taffy-notation-akin-to-^<>d-impl?
  (-> any/c boolean?))
(ascribe-own-contract taffy-notation-akin-to-^<>d-parse
  (-> taffy-notation-akin-to-^<>d? syntax?
    (and/c hash? immutable? hash-equal?
      (hash/dc
        [ k
          (or/c
            'context
            'direction
            'degree
            'contents
            'token-of-syntax)]
        [ _ (k)
          (match k
            ['context syntax?]
            ['direction (or/c '< '>)]
            ['degree syntax?]
            ['contents (listof syntax?)]
            ['token-of-syntax
              (token-of-syntax-with-free-vars<=/c /set
                'context 'degree 'contents)])]))))
(ascribe-own-contract prop:taffy-notation-akin-to-^<>d
  (struct-type-property/c taffy-notation-akin-to-^<>d-impl?))
(ascribe-own-contract make-taffy-notation-akin-to-^<>d-impl
  (->
    (-> syntax?
      (and/c hash? immutable? hash-equal?
        (hash/dc
          [ k
            (or/c
              'context
              'direction
              'degree
              'contents
              'token-of-syntax)]
          [ _ (k)
            (match k
              ['context syntax?]
              ['direction (or/c '< '>)]
              ['degree syntax?]
              ['contents (listof syntax?)]
              [ 'token-of-syntax
                (token-of-syntax-with-free-vars<=/c /set
                  'context 'degree 'contents)])])))
    taffy-notation-akin-to-^<>d-impl?))

(define-imitation-simple-struct
  (makeshift-taffy-notation-akin-to-^<>d?
    makeshift-taffy-notation-akin-to-^<>d-parse)
  unguarded-makeshift-taffy-notation-akin-to-^<>d
  'makeshift-taffy-notation-akin-to-^<>d (current-inspector)
  (auto-write)
  (#:prop prop:procedure /fn op stx
    (raise-taffy-notation-as-expression-error stx))
  (#:prop prop:taffy-notation (make-taffy-notation-impl))
  (#:prop prop:taffy-notation-akin-to-^<>d
    (make-taffy-notation-akin-to-^<>d-impl
      (fn op stx
        (dissect op
          (unguarded-makeshift-taffy-notation-akin-to-^<>d parse)
        /parse stx)))))

(define/own-contract (makeshift-taffy-notation-akin-to-^<>d parse)
  (->
    (-> syntax?
      (and/c hash? immutable? hash-equal?
        (hash/dc
          [ k
            (or/c
              'context
              'direction
              'degree
              'contents
              'token-of-syntax)]
          [ _ (k)
            (match k
              ['context syntax?]
              ['direction (or/c '< '>)]
              ['degree syntax?]
              ['contents (listof syntax?)]
              ['token-of-syntax
                (token-of-syntax-with-free-vars<=/c /set
                  'context 'degree 'contents)])])))
    (and/c
      procedure?
      taffy-notation?
      taffy-notation-akin-to-^<>d?))
  (unguarded-makeshift-taffy-notation-akin-to-^<>d parse))
