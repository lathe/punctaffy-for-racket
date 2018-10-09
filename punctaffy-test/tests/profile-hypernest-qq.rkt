#lang parendown racket/base

; punctaffy/tests/profile-hypernest-qq
;
; Provides a way to run the unit tests of the hypersnippet macro
; system under a profiler.

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


(require #/only-in profile profile-thunk)

(require #/only-in lathe-comforts fn)


(provide run-profiler)


(define (run-profiler)
  (profile-thunk #/fn
    (dynamic-require 'punctaffy/tests/test-hypernest-qq #f)))
