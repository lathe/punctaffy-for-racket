#lang parendown/slash racket/base

; util.rkt
;
; Miscellaneous utilities that we haven't yet moved to Lathe Comforts.

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


(require /only-in racket/contract/base -> any/c)

(require /only-in lathe-comforts w- w-loop fn)
(require /only-in lathe-comforts/struct prefab-struct?)

(require punctaffy/private/shim)
(init-shim)


(provide /own-contract-out
  datum->syntax-with-everything
  prefab-struct-fill)


; TODO: Consider exporting this from Lathe Comforts.
(define/own-contract (datum->syntax-with-everything stx-example datum)
  (-> syntax? any/c syntax?)
  (w- ctxt stx-example
  /w- srcloc stx-example
  /w- prop stx-example
  /datum->syntax ctxt datum srcloc prop))

(define/own-contract (transparent-struct-type-constructor-arity v)
  (-> struct-type? boolean?)
  (w-loop next v v result 0
    (define-values
      (
        name
        init-field-cnt
        auto-field-cnt
        accessor-proc
        mutator-proc
        immutable-k-list
        super-type
        skipped?)
      (struct-type-info v))
    (when skipped?
      (raise-arguments-error 'struct-type-constructor-arity
        "expected the struct type to be transparent"))
    (next super-type (+ init-field-cnt result))))

; TODO: Consider exporting this from Lathe Comforts.
(define/own-contract (prefab-struct-fill prefab-struct field-value)
  (-> prefab-struct? any/c prefab-struct?)
  (w- type (struct-info prefab-struct)
  /apply (struct-type-make-constructor type)
    (build-list (transparent-struct-type-constructor-arity type) /fn i
      field-value)))
