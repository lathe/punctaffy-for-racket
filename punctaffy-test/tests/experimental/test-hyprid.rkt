#lang parendown racket/base

; punctaffy/tests/experimental/test-hyprid
;
; Unit tests of the hyprid data structure for hypersnippet-shaped
; data.

;   Copyright 2017-2019 The Lathe Authors
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

(require #/only-in lathe-comforts fn mat)
(require #/only-in lathe-comforts/list list-map)
(require #/only-in lathe-comforts/trivial trivial)

(require punctaffy/hypersnippet/dim)
(require punctaffy/hypersnippet/hypertee)
(require punctaffy/private/experimental/hyprid)

; (We provide nothing from this module.)


(define ds (nat-dim-sys))
(define dss (nat-dim-successors-sys))

(define (n-ht degree . brackets)
  (degree-and-closing-brackets->hypertee ds degree
  #/list-map brackets #/fn bracket
    (mat bracket (htb-labeled d data) bracket
    #/mat bracket (htb-unlabeled d) bracket
    #/htb-unlabeled bracket)))


(check-equal?
  (hyprid-destripe-once
    (hyprid dss 1 1
    #/island-cane "Hello."
    #/hyprid dss 1 0 #/n-ht 1 #/htb-labeled 0
    #/non-lake-cane #/trivial))
  (hyprid dss 2 0 #/n-ht 2
    (htb-labeled 0 #/trivial))
  "Destriping a hyprid-encoded interpolated string with no interpolations gives a degree-2 hyprid with no nonzero-degree holes")

(check-equal?
  (hyprid-fully-destripe
    (hyprid dss 1 1
    #/island-cane "Hello, "
    #/hyprid dss 1 0 #/n-ht 1 #/htb-labeled 0
    #/lake-cane dss 'name #/n-ht 1 #/htb-labeled 0
    #/island-cane "! It's "
    #/hyprid dss 1 0 #/n-ht 1 #/htb-labeled 0
    #/lake-cane dss 'weather #/n-ht 1 #/htb-labeled 0
    #/island-cane " today."
    #/hyprid dss 1 0 #/n-ht 1 #/htb-labeled 0
    #/non-lake-cane #/trivial))
  (n-ht 2
    (htb-labeled 1 'name)
    0
    (htb-labeled 1 'weather)
    0
    (htb-labeled 0 #/trivial))
  "Fully destriping a hyprid-encoded interpolated string with two interpolations gives a degree-2 hypertee with two degree-1 holes containing the interpolated values")

(check-equal?
  (hyprid-stripe-once
  #/hyprid dss 3 0 #/n-ht 3
    (htb-labeled 2 'a)
    1
    (htb-labeled 1 'a)
    0
    0
    0
    (htb-labeled 0 'a))
  (hyprid dss 2 1
  #/island-cane (trivial) #/hyprid dss 2 0 #/n-ht 2
    (htb-labeled 1 #/lake-cane dss 'a #/n-ht 2
      (htb-labeled 1
      #/island-cane (trivial) #/hyprid dss 2 0 #/n-ht 2
        (htb-labeled 1 #/non-lake-cane 'a)
        0
        (htb-labeled 0 #/trivial))
      0
      (htb-labeled 0 #/trivial))
    0
    (htb-labeled 0 'a))
  "Striping a hyprid")

(check-equal?
  
  (hyprid-stripe-once
  #/hyprid-stripe-once
  #/hyprid dss 3 0 #/n-ht 3
    (htb-labeled 2 'a)
    1
    (htb-labeled 1 'a)
    0
    0
    0
    (htb-labeled 0 'a))
  
  ; NOTE: The only reason I was able to write this out was because I
  ; printed the result first and transcribed it.
  (hyprid dss 1 2
  #/island-cane (trivial) #/hyprid dss 1 1
  #/island-cane (trivial) #/hyprid dss 1 0
  #/n-ht 1 #/htb-labeled 0 #/lake-cane dss
    (lake-cane dss 'a #/n-ht 2
      (htb-labeled 1
      #/island-cane (trivial) #/hyprid dss 1 1
      #/island-cane (trivial) #/hyprid dss 1 0
      #/n-ht 1 #/htb-labeled 0 #/lake-cane dss
        (non-lake-cane 'a)
      #/n-ht 1 #/htb-labeled 0
      #/island-cane (trivial) #/hyprid dss 1 0
      #/n-ht 1 #/htb-labeled 0 #/non-lake-cane #/trivial)
      0
      (htb-labeled 0 #/trivial))
  #/n-ht 1 #/htb-labeled 0
  #/island-cane (trivial) #/hyprid dss 1 0
  #/n-ht 1 #/htb-labeled 0 #/non-lake-cane 'a)
  
  "Striping a hyprid twice")

(check-exn exn:fail?
  (fn
  #/hyprid-stripe-once
  #/hyprid-stripe-once
  #/hyprid-stripe-once
  #/hyprid dss 3 0 #/n-ht 3
    (htb-labeled 2 'a)
    1
    (htb-labeled 1 'a)
    0
    0
    0
    (htb-labeled 0 'a))
  "Trying to stripe a hybrid more than it can be striped")
