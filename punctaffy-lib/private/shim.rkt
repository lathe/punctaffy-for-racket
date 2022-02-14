#lang parendown/slash racket/base

; shim.rkt
;
; Import lists, debugging constants, and other utilities that are
; useful primarily for this codebase.

;   Copyright 2022 The Lathe Authors
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


(require /only-in reprovide/require-transformer/combine-in-fallback
  combine-in/fallback)

(require /for-syntax /combine-in/fallback
  (combine-in
    (only-in racket/syntax format-id)
    (only-in syntax/parse ~optional ~seq this-syntax))
  racket/base)

(require /only-in syntax/parse/define define-syntax-parse-rule)

(require /only-in reprovide/reprovide reprovide)

(require /only-in lathe-comforts/own-contract
  define-own-contract-policies)

(reprovide punctaffy/private/codebasewide-requires)

(provide
  (for-syntax
    suppressing-external-contracts?
    activating-internal-contracts?)
  init-shim)


; Should be `#f` unless we're debugging to determine if contracts are
; a performance bottleneck.
;
(define-for-syntax suppressing-external-contracts? #f)

; Should be `#f` unless we're debugging this library's internal call
; graph.
;
(define-for-syntax activating-internal-contracts? #f)

(define-syntax-parse-rule
  (init-shim
    {~optional {~seq #:antecedent-land antecedent-land}
      #:defaults ([antecedent-land (datum->syntax this-syntax '())])})
  
  #:with result
  #`(define-own-contract-policies #:antecedent-land antecedent-land
      
      #:make-signature-contract-id
      (lambda (orig) /format-id orig "~a/sig-c" orig #:subs? #t)
      
      #:suppressing-external-contracts?
      #,(datum->syntax #'() suppressing-external-contracts?)
      
      #:activating-internal-contracts?
      #,(datum->syntax #'() activating-internal-contracts?))
  
  result)
