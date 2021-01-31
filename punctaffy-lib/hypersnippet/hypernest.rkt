#lang parendown racket/base

; punctaffy/hypersnippet/hypernest
;
; A data structure for encoding hypersnippet notations that can nest
; with themselves.

;   Copyright 2018-2021 The Lathe Authors
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


(require lathe-morphisms/private/shim)

(require #/submod punctaffy/hypersnippet/snippet private/hypernest)


(provide #/shim-recontract-out
  hypernest?
  hypernest/c
  hypernestof/ob-c
  hypernest-get-dim-sys)
(provide
  hypernest-snippet-sys)
(provide #/shim-recontract-out
  hypernest-snippet-sys?
  hypernest-snippet-sys-snippet-format-sys
  hypernest-snippet-sys-dim-sys)
(provide
  hypernest-snippet-format-sys)
(provide #/shim-recontract-out
  hypernest-snippet-format-sys?
  hypernest-snippet-format-sys-original
  hypernest-shape
  hypernest-get-hole-zero-maybe
  hypernest-join-list-and-tail-along-0)

(provide
  hypernest-coil-zero)
(provide #/shim-recontract-out
  hypernest-coil-zero?)
(provide
  hypernest-coil-hole)
(provide #/shim-recontract-out
  hypernest-coil-hole?
  hypernest-coil-hole-overall-degree
  hypernest-coil-hole-hole
  hypernest-coil-hole-data
  hypernest-coil-hole-tails-hypertee)
(provide
  hypernest-coil-bump)
(provide #/shim-recontract-out
  hypernest-coil-bump?
  hypernest-coil-bump-overall-degree
  hypernest-coil-bump-data
  hypernest-coil-bump-bump-degree
  hypernest-coil-bump-tails-hypernest)
(provide #/shim-recontract-out
  hypernest-coil/c)
(provide
  hypernest-furl)
(provide #/shim-recontract-out
  hypernest-get-coil)

(provide
  hnb-open)
(provide #/shim-recontract-out
  hnb-open?
  hnb-open-degree
  hnb-open-data)
(provide
  hnb-labeled)
(provide #/shim-recontract-out
  hnb-labeled?
  hnb-labeled-degree
  hnb-labeled-data)
(provide
  hnb-unlabeled)
(provide #/shim-recontract-out
  hnb-unlabeled?
  hnb-unlabeled-degree)
(provide #/shim-recontract-out
  hypernest-bracket?
  hypernest-bracket/c
  ; TODO: Uncomment this export if we ever need it.
;  hypernest-bracket-degree
  hypertee-bracket->hypernest-bracket
  compatible-hypernest-bracket->hypertee-bracket
  hypernest-from-brackets
  hn-bracs
  hypernest-get-brackets)
