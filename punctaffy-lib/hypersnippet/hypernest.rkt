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


(require #/only-in racket/contract/base recontract-out)
; TODO WITH-PLACEBO-CONTRACTS: Figure out what to do with this
; section. Should we provide `.../with-placebo-contracts/...` modules?
; For now, we have this here for testing. Note that if we enable this
; code, we also need to comment out the `recontract-out` import above.
#;
(begin
  (require #/for-syntax
    racket/base racket/provide-transform syntax/parse lathe-comforts)
  (define-syntax recontract-out
    (make-provide-transformer #/fn stx modes
      (syntax-parse stx #/ (_ var:id ...)
      #/expand-export #'(combine-out var ...) modes))))

(require #/submod punctaffy/hypersnippet/snippet private/hypernest)


(provide #/recontract-out
  hypernest?
  hypernest/c
  hypernestof
  hypernest-get-dim-sys)
(provide
  hypernest-snippet-sys)
(provide #/recontract-out
  hypernest-snippet-sys?
  hypernest-snippet-sys-snippet-format-sys
  hypernest-snippet-sys-dim-sys)
(provide
  hypernest-snippet-format-sys)
(provide #/recontract-out
  hypernest-snippet-format-sys?
  hypernest-snippet-format-sys-original
  hypernest-shape
  hypernest-get-hole-zero-maybe
  hypernest-join-list-and-tail-along-0)

(provide
  hypernest-coil-zero)
(provide #/recontract-out
  hypernest-coil-zero?)
(provide
  hypernest-coil-hole)
(provide #/recontract-out
  hypernest-coil-hole?
  hypernest-coil-hole-overall-degree
  hypernest-coil-hole-hole
  hypernest-coil-hole-data
  hypernest-coil-hole-tails-hypertee)
(provide
  hypernest-coil-bump)
(provide #/recontract-out
  hypernest-coil-bump?
  hypernest-coil-bump-overall-degree
  hypernest-coil-bump-data
  hypernest-coil-bump-bump-degree
  hypernest-coil-bump-tails-hypernest)
(provide #/recontract-out
  hypernest-coil/c)
(provide
  hypernest-furl)
(provide #/recontract-out
  hypernest-get-coil)

(provide
  hnb-open)
(provide #/recontract-out
  hnb-open?
  hnb-open-degree
  hnb-open-data)
(provide
  hnb-labeled)
(provide #/recontract-out
  hnb-labeled?
  hnb-labeled-degree
  hnb-labeled-data)
(provide
  hnb-unlabeled)
(provide #/recontract-out
  hnb-unlabeled?
  hnb-unlabeled-degree)
(provide #/recontract-out
  hypernest-bracket?
  hypernest-bracket/c
  ; TODO: Uncomment this export if we ever need it.
;  hypernest-bracket-degree
  hypertee-bracket->hypernest-bracket
  compatible-hypernest-bracket->hypertee-bracket
  hypernest-from-brackets
  hn-bracs
  hypernest-get-brackets)
