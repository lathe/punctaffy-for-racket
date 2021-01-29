#lang parendown racket/base

; shim.rkt
;
; Import lists, debugging constants, and other utilities that are
; useful primarily for this codebase.

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

(require #/for-syntax #/only-in racket/syntax syntax-local-eval)
(require #/for-syntax #/only-in syntax/parse expr id syntax-parse)


(provide
  shim-contract-out
  shim-recontract-out)


; NOTE DEBUGGABILITY: These are here for debugging.
(define-for-syntax debugging-with-contracts-suppressed #f)

(define-syntax (ifc stx)
  (syntax-protect
  #/syntax-parse stx #/ (_ condition:expr then:expr else:expr)
  #/if (syntax-local-eval #'condition)
    #'then
    #'else))

; TODO: Figure out what to do with this section. Should we provide
; `.../with-contracts-suppressed/...` modules? For now, we have this
; here for testing.

(ifc debugging-with-contracts-suppressed
  (begin
    (require #/for-syntax #/only-in racket/provide-transform
      expand-export make-provide-transformer)
    
    (require #/for-syntax #/only-in lathe-comforts fn)
    
    (define-syntax shim-contract-out
      (make-provide-transformer #/fn stx modes
        (syntax-parse stx #/ (_ [var:id contract:expr] ...)
        #/expand-export #'(combine-out var ...) modes)))
    
    (define-syntax shim-recontract-out
      (make-provide-transformer #/fn stx modes
        (syntax-parse stx #/ (_ var:id ...)
        #/expand-export #'(combine-out var ...) modes))))
  (begin
    (require #/only-in racket/contract/base
      [contract-out shim-contract-out]
      [recontract-out shim-recontract-out])))
