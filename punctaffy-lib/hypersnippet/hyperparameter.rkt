#lang parendown racket/base

; punctaffy/hypersnippet/hyperparameter
;
; Utilities for Racket parameters that allow the dynamic extents to be
; hypersnippet-shaped sections of the execution timeline.

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


(require #/only-in racket/contract/base
  -> any any/c contract? recursive-contract)
(require #/only-in racket/contract/region define/contract)

(require #/only-in lathe-comforts expect fn w-)
(require #/only-in lathe-comforts/maybe just nothing)

; TODO: Document all of these exports.
(provide
  hyperbody/c
  call-hyperbody-while-updating-parameterization
  call-hyperbody-while-parameterizing)


; If hypersnippets divide up code into high-dimensional structured
; code-with-holes-in-it pieces, higher-dimensional parameters do the
; same thing for dynamic extents.
;
; Racket already has support for getting and replacing the whole
; current parameterization, which already means Racket's
; parameterization frames can be uninstalled for dynamic extents of
; arbitrary dimension and come back good as new. All there is for us
; to do is to provide an implementation of this kind of structured
; uninstallation and reinstallation.


(define/contract hyperbody/c
  contract?
  ; NOTE: While this is equivalent to having only one `(-> ... any)`
  ; layer instead of two, we keep them both around because they
  ; represent different things: The inner `->` is a procedure meant
  ; for opening a hole in the hyperbody, and this hole can have any
  ; dimension less than the hyperbody's own dimension. This means if
  ; we were actually keeping track of dimensions and enforcing this,
  ; that function would receive the dimension as a second parameter,
  ; while the outer `->` would not; it would come paired with a
  ; dimension instead of taking it as a parameter.
  (-> (-> (recursive-contract hyperbody/c) any) any))

(define/contract
  (call-hyperbody-while-updating-parameterization func body)
  (-> (-> parameterization? parameterization?) hyperbody/c any)
  (w- current-p (current-parameterization)
  ; NOTE: We could refrain from storing `current-p` in the parameter
  ; here, and instead use a boolean here and use `current-p` in place
  ; of `old-p` below, but this way, `current-p` can be
  ; garbage-collected even if that function remains reachable.
  #/call-with-parameterization (func current-p) #/fn
    (w- in-progress (make-parameter #/nothing)
    #/parameterize ([in-progress (just current-p)])
      (body #/fn body
        (expect (in-progress) (just old-p)
          (error "Used a hyperbody hole for a dynamic extent that wasn't currently in progress")
        #/call-hyperbody-while-updating-parameterization (fn _ old-p)
          body)))))

(define/contract
  (call-hyperbody-while-parameterizing pr value body)
  (-> parameter? any/c hyperbody/c any)
  (call-hyperbody-while-updating-parameterization (fn pn pn) #/fn esc
    (parameterize ([pr value])
      (body esc))))
