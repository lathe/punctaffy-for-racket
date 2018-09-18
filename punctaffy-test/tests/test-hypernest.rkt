#lang parendown racket/base

; punctaffy/tests/test-hypernest
;
; Unit tests of the hypernest data structure for hypersnippet-shaped
; data.

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


(require rackunit)

(require #/only-in lathe-comforts fn)
(require #/only-in lathe-comforts/trivial trivial)

(require punctaffy/hypersnippet/hypernest)

; (We provide nothing from this module.)


(define make-hn degree-and-brackets->hypernest)


; NOTE: These are the same as some of the hypertee tests in
; test-hypertee.rkt.
(make-hn 0 #/list)
(make-hn 1 #/list (list 0 'a))
(make-hn 2 #/list
  (list 1 'a)
  0 (list 0 'a))
(make-hn 3 #/list
  (list 2 'a)
  1 (list 1 'a) 0 0 0 (list 0 'a))
(make-hn 4 #/list
  (list 3 'a)
  2 (list 2 'a) 1 1 1 (list 1 'a) 0 0 0 0 0 0 0 (list 0 'a))
(make-hn 5 #/list
  (list 4 'a)
  3 (list 3 'a) 2 2 2 (list 2 'a) 1 1 1 1 1 1 1 (list 1 'a)
  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 (list 0 'a))


(make-hn 1 #/list
  (list 'open 1 'a)
  0
  (list 'open 2 'a)
  1
  (list 'open 1 'a)
  0
  0
  0
  (list 0 'a))

#|
#hasheq(
  (0 . ((0 #<hypernest-hole: #<trivial:>>)))
  (4 . ((0 #<hypernest-hole: #<trivial:>>)))
  (2 . (
    (0 #<hypernest-hole: #<trivial:>>)
    0
    (1 #<hypernest-hole: #<trivial:>>)
  ))
  (root . (
    (0 #<hypernest-hole: a>)
    0
    (0 #<hypernest-hole: #<trivial:>>)
    0
    (1 #<hypernest-bump: a 4>)
    1
    (2 #<hypernest-bump: a 2>)
    0
    (1 #<hypernest-bump: a 0>)
  ))
)
|#
