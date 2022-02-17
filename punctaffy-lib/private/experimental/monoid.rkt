#lang parendown racket/base

; monoid.rkt
;
; A dictionary-passing implementation of the monoid type class for
; Racket, using Racket's generic methods so that it's more
; straightforward to define dictiaonries that are comparable by
; `equal?`.

;   Copyright 2017-2018, 2022 The Lathe Authors
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


(require #/only-in racket/contract/base -> any any/c)
(require #/only-in racket/generic define-generics)

(require #/only-in lathe-comforts expect)
(require #/only-in lathe-comforts/struct struct-easy)

(require punctaffy/private/shim)
(init-shim)


(provide gen:monoid monoid? monoid/c monoid-empty monoid-append)

(provide #/rename-out [make-monoid-trivial monoid-trivial])


(define-generics monoid
  (monoid-empty monoid)
  (monoid-append monoid prefix suffix))


; This monoid has only one segment, namely the empty list.
(struct-easy (monoid-trivial)
  #:equal
  #:other
  
  #:constructor-name make-monoid-trivial
  
  #:methods gen:monoid
  [
    
    (define (monoid-empty this)
      (expect this (monoid-trivial)
        (error "Expected this to be a monoid-trivial")
        null))
    
    (define/own-contract (monoid-append this prefix suffix)
      (-> any/c null? null? any)
      (expect this (monoid-trivial)
        (error "Expected this to be a monoid-trivial")
        null))
  ])
