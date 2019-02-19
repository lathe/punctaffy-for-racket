#lang parendown racket/base

; punctaffy/hypersnippet/hypernest
;
; A data structure for encoding hypersnippet notations that can nest
; with themselves.

;   Copyright 2018-2019 The Lathe Authors
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


(require punctaffy/private/hypernest-as-ast)

(provide #/all-from-out punctaffy/private/hypernest-as-ast)
