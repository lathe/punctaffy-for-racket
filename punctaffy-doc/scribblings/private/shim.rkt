#lang parendown at-exp racket/base

; punctaffy/scribblings/private/shim
;
; Import lists, debugging constants, and other utilities that are
; useful primarily for this codebase.

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


(require #/for-syntax racket/base)

(require #/for-syntax #/only-in syntax/parse syntax-parse)

(require #/for-syntax #/only-in lathe-comforts fn w-)

(require scribble/base)


(provide
  shim-require-various-for-label
  code-block)


(define-syntax (shim-require-various-for-label stx)
  (syntax-protect
  #/syntax-parse stx #/ (_)
  #/w- break (fn id #/datum->syntax stx id)
    #`(require #/for-label
        
        #,(break 'racket/base)
        
        (only-in #,(break 'net/url)
          combine-url/relative string->url url->string)
        (only-in #,(break 'racket/contract) struct-type-property/c)
        (only-in #,(break 'racket/contract/base)
          -> </c and/c any/c cons/c contract? flat-contract? hash/c
          hash/dc ->i list/c listof non-empty-listof not/c or/c
          syntax/c)
        (only-in #,(break 'racket/extflonum) extflonum?)
        (only-in #,(break 'racket/flonum) flvector?)
        (only-in #,(break 'racket/fixnum) fxvector?)
        (only-in #,(break 'racket/list) append-map)
        (only-in #,(break 'racket/match)
          match-define match match/derived match-let)
        (only-in #,(break 'racket/math) natural?)
        (only-in #,(break 'racket/set) set set-equal?)
        (only-in #,(break 'syntax/datum) datum with-datum)
        (only-in #,(break 'syntax/parse)
          ~optional prop:pattern-expander ~seq syntax-parse)
        (only-in #,(break 'syntax/parse/define)
          define-syntax-parse-rule)
        (only-in #,(break 'syntax/parse/experimental/template)
          define-template-metafunction)
        
        (only-in #,(break 'lathe-comforts) fn)
        (only-in #,(break 'lathe-comforts/contract)
          flat-obstinacy obstinacy? obstinacy-contract/c)
        (only-in #,(break 'lathe-comforts/list) list-bind)
        (only-in #,(break 'lathe-comforts/maybe)
          just? maybe? maybe/c nothing)
        (only-in #,(break 'lathe-comforts/struct)
          immutable-prefab-struct?)
        (only-in #,(break 'lathe-comforts/trivial) trivial?)
        (only-in #,(break 'lathe-morphisms/in-fp/category)
          category-sys? category-sys-morphism/c functor-sys?
          functor-sys-apply-to-morphism functor-sys-apply-to-object
          functor-sys/c functor-sys-impl? functor-sys-target
          make-functor-sys-impl-from-apply
          make-natural-transformation-sys-impl-from-apply
          natural-transformation-sys-apply-to-morphism
          natural-transformation-sys/c
          natural-transformation-sys-endpoint-target
          natural-transformation-sys-replace-source
          natural-transformation-sys-replace-target
          natural-transformation-sys-source
          natural-transformation-sys-target prop:functor-sys)
        (only-in #,(break 'lathe-morphisms/in-fp/mediary/set) ok/c)
        (only-in #,(break 'parendown) pd)
        
        #,(break 'punctaffy)
        #,(break 'punctaffy/hypersnippet/dim)
        #,(break 'punctaffy/hypersnippet/hyperstack)
        #,(break 'punctaffy/hypersnippet/hypernest)
        #,(break 'punctaffy/hypersnippet/hypertee)
        #,(break 'punctaffy/hypersnippet/snippet)
        #,(break 'punctaffy/syntax-object/token-of-syntax)
        #,(break 'punctaffy/taffy-notation)
        #,(break 'punctaffy/quote)
        #,(break 'punctaffy/let)
        
        )))


(define-syntax-rule @code-block[args ...]
  @nested[#:style 'code-inset]{@verbatim[args ...]})
