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


(require /only-in racket/contract/base -> any/c or/c)
(require /only-in syntax/datum datum)
(require /only-in syntax/parse ~and ~optional id nat syntax-parse)

(require /only-in lathe-comforts w-)

(require punctaffy/private/shim)
(init-shim)


(provide /own-contract-out
  datum->syntax-with-everything
  prefab-key-mutability
  known-to-be-immutable-prefab-key?
  known-to-be-immutable-prefab-struct?
  mutability-unconfirmed-prefab-key?
  mutability-unconfirmed-prefab-struct?)


; TODO: Consider exporting this from Lathe Comforts.
(define/own-contract (datum->syntax-with-everything stx-example datum)
  (-> syntax? any/c syntax?)
  (w- ctxt stx-example
  /w- srcloc stx-example
  /w- prop stx-example
  /datum->syntax ctxt datum srcloc prop))

; TODO: Consider exporting this from Lathe Comforts.
(define/own-contract (prefab-key-mutability k)
  (-> prefab-key?
    (or/c 'not-known 'known-to-be-immutable 'known-to-be-mutable))
  (syntax-parse k
    [_:id 'known-to-be-immutable]
    [
      (
        _:id
        (~optional _:nat)
        (~optional (_:nat _))
        (~optional (~and v #(_:nat ...)) #:defaults ([(v 0) #()]))
        . parent-key)
      (if (= 0 (vector-length (datum v)))
        (syntax-parse (datum parent-key)
          [() 'known-to-be-immutable]
          [_ (prefab-key-mutability (datum parent-key))])
        'known-to-be-mutable)]
    [_ 'not-known]))

; TODO: Consider exporting this from Lathe Comforts.
(define/own-contract (known-to-be-immutable-prefab-key? v)
  (-> any/c boolean?)
  (and
    (prefab-key? v)
    (eq? 'known-to-be-immutable (prefab-key-mutability v))))

; TODO: Consider exporting this from Lathe Comforts.
(define/own-contract (mutability-unconfirmed-prefab-key? v)
  (-> any/c boolean?)
  (and
    (prefab-key? v)
    (not /eq? 'known-to-be-mutable (prefab-key-mutability v))))

; TODO: Consider exporting this from Lathe Comforts.
(define/own-contract (known-to-be-immutable-prefab-struct? v)
  (-> any/c boolean?)
  (w- key (prefab-struct-key v)
  /and key (known-to-be-immutable-prefab-key? key)))

; TODO: Consider exporting this from Lathe Comforts.
(define/own-contract (mutability-unconfirmed-prefab-struct? v)
  (-> any/c boolean?)
  (w- key (prefab-struct-key v)
  /and key (mutability-unconfirmed-prefab-key? key)))
