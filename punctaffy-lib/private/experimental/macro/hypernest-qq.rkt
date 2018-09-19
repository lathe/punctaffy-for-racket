#lang parendown racket/base

; hypernest-qq.rkt
;
; A quasiquotation operator which allows for user-defined escape
; sequences which can generalize unquotation and nested
; quasiquotation.

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


; TODO:
;
; Salvage anything from qq.rkt that makes sense to salvage for this
; file.
;
; Compared to qq.rkt, this whole file's design needs to be rethought
; now that we're using hypernests instead of hypertees. The syntax we
; use for quasiquotation should no longer be this:
;
;   (my-quasiquote uq #/qq
;     (a b
;       (my-quasiquote uq #/qq
;         (c d
;           (uq
;             (e f
;               (uq
;                 (+ 4 5))))))))
;
; Instead, it should be something like this, with new
; operators ^< and ^> that signify opening brackets and closing
; brackets of explicit degrees:
;
;   (my-quasiquote #/^< 2
;     (a b
;       (my-quasiquote #/^< 2
;         (c d
;           (^> 1 #/my-unquote
;             (e f
;               (^> 1 #/my-unquote
;                 (+ 4 5))))))))
;
; The ^< and ^> syntaxes should be defined in and provided from some
; module that makes them look as much like language builtins as
; reasonably possible. (In particular, `(require punctaffy)` should
; get them.) Most programmers will be able to treat them as
; parentheses; like parentheses, they're a notation that most programs
; don't need to extend or parse in custom ways.
;
; The `my-quasiquote` and `my-unquote` syntaxes should be defined only
; in terms of `s-expr-stx->ht-expr`, the structs of the hn-expression
; format, and the hypernest and hypertee utilities. Even these won't
; need to extend or parse the higher-order paren notation in custom
; ways.
;
; Users of `my-quasiquote` and `my-unquote` will only need to import
; those two operations and ^< and ^> but will not usually need to
; understand them any more deeply than the traditional `quasiquote`
; and `unquote`. Even if they define another quasiquotation syntax, it
; will interoperate seamlessly with `my-quasiquote` and `my-unquote`
; if it makes similar use of `s-expr-stx->ht-expr`.
;
; If people define custom parentheses very often, quotation operators
; will typically fail to preserve their meaning since code generated
; for different lexical contexts could have different sets of custom
; parentheses available. That's why we should decide on a minimalistic
; set of operators like ^< and ^> that can express the full range of
; hn-expressions and provide these as the baseline that other syntaxes
; are typically built around.
