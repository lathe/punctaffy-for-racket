#lang parendown/slash reprovide

; codebasewide-requires.rkt
;
; An import list that's useful primarily for this codebase.

;   Copyright 2022, 2025 The Lathe Authors
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


(for-syntax /only-in syntax/parse expr this-syntax)

(for-syntax /only-in lathe-comforts/own-contract
  ascribe-own-contract define/own-contract own-contract-out)
(for-syntax /only-in lathe-comforts/syntax ~autoptic ~autoptic-list)


(only-in racket/contract/base any/c)
(only-in racket/list append-map)
(only-in syntax/parse ~not)

(only-in lathe-comforts define-syntax-parse-rule/autoptic fn w-)
(only-in lathe-comforts/own-contract
  ascribe-own-contract define/own-contract own-contract-out)
