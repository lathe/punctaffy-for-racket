#lang parendown racket/base

; punctaffy/hypersnippet/hypertee-2
;
; A data structure for encoding the kind of higher-order structure
; that occurs in higher quasiquotation.

;   Copyright 2017-2020 The Lathe Authors
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


(require #/only-in racket/contract/base recontract-out)

(require #/submod punctaffy/hypersnippet/snippet private/hypertee)


(provide
  hypertee-coil-zero)
(provide #/recontract-out
  hypertee-coil-zero?)
(provide
  hypertee-coil-hole)
(provide #/recontract-out
  hypertee-coil-hole?
  hypertee-coil-hole-overall-degree
  hypertee-coil-hole-hole
  hypertee-coil-hole-data
  hypertee-coil-hole-tails)
(provide #/recontract-out
  hypertee-coil/c)
(provide
  hypertee-furl)
(provide #/recontract-out
  hypertee?
  hypertee-get-dim-sys
  hypertee-get-coil
  hypertee/c)
(provide
  hypertee-snippet-sys)
(provide #/recontract-out
  hypertee-snippet-sys?
  hypertee-snippet-sys-dim-sys)
(provide
  hypertee-snippet-format-sys)
(provide #/recontract-out
  hypertee-snippet-format-sys?)

(provide
  htb-labeled)
(provide #/recontract-out
  htb-labeled?
  htb-labeled-degree
  htb-labeled-data)
(provide
  htb-unlabeled)
(provide #/recontract-out
  htb-unlabeled?
  htb-unlabeled-degree)
(provide #/recontract-out
  hypertee-bracket?
  hypertee-bracket/c
  hypertee-bracket-degree
  hypertee-from-brackets
  ht-bracs
  hypertee-get-brackets)
