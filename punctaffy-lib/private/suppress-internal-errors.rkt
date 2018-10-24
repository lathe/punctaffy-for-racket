#lang parendown racket/base

; suppress-internal-errors.rkt
;
; A Racket parameter that controls whether certain Punctaffy
; operations perform exhaustive checks for errors or not. When
; debugging Punctaffy itself, it may be useful to edit the places this
; parameter is initialized and used so that the checks are always
; performed.

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


(provide punctaffy-suppress-internal-errors)


(define punctaffy-suppress-internal-errors (make-parameter #f))
