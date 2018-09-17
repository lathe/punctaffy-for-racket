#lang parendown racket/base

; punctaffy/tests/test-hyprid
;
; Unit tests of the hyprid data structure for hypersnippet-shaped
; data.

(require rackunit)

(require #/only-in lathe-comforts fn)
(require #/only-in lathe-comforts/trivial trivial)

(require punctaffy/hypersnippet/hypertee)
(require punctaffy/private/experimental/hyprid)

; (We provide nothing from this module.)


(define make-ht degree-and-closing-brackets->hypertee)


(check-equal?
  (hyprid-destripe-once
    (hyprid 1 1
    #/island-cane "Hello." #/hyprid 1 0 #/make-ht 1 #/list #/list 0
    #/non-lake-cane #/trivial))
  (hyprid 2 0 #/make-ht 2 #/list
    (list 0 #/trivial))
  "Destriping a hyprid-encoded interpolated string with no interpolations gives a degree-2 hyprid with no nonzero-degree holes")

(check-equal?
  (hyprid-fully-destripe
    (hyprid 1 1
    #/island-cane "Hello, " #/hyprid 1 0 #/make-ht 1 #/list #/list 0
    #/lake-cane 'name #/make-ht 1 #/list #/list 0
    #/island-cane "! It's " #/hyprid 1 0 #/make-ht 1 #/list #/list 0
    #/lake-cane 'weather #/make-ht 1 #/list #/list 0
    #/island-cane " today." #/hyprid 1 0 #/make-ht 1 #/list #/list 0
    #/non-lake-cane #/trivial))
  (make-ht 2 #/list
    (list 1 'name)
    0
    (list 1 'weather)
    0
    (list 0 #/trivial))
  "Fully destriping a hyprid-encoded interpolated string with two interpolations gives a degree-2 hypertee with two degree-1 holes containing the interpolated values")

(check-equal?
  (hyprid-stripe-once
  #/hyprid 3 0 #/make-ht 3 #/list
    (list 2 'a)
    1
    (list 1 'a)
    0
    0
    0
    (list 0 'a))
  (hyprid 2 1 #/island-cane (trivial) #/hyprid 2 0 #/make-ht 2 #/list
    (list 1 #/lake-cane 'a #/make-ht 2 #/list
      (list 1 #/island-cane (trivial) #/hyprid 2 0 #/make-ht 2 #/list
        (list 1 #/non-lake-cane 'a)
        0
        (list 0 #/trivial))
      0
      (list 0 #/trivial))
    0
    (list 0 'a))
  "Striping a hyprid")

(check-equal?
  
  (hyprid-stripe-once
  #/hyprid-stripe-once
  #/hyprid 3 0 #/make-ht 3 #/list
    (list 2 'a)
    1
    (list 1 'a)
    0
    0
    0
    (list 0 'a))
  
  ; NOTE: The only reason I was able to write this out was because I
  ; printed the result first and transcribed it.
  (hyprid 1 2
  #/island-cane (trivial) #/hyprid 1 1
  #/island-cane (trivial) #/hyprid 1 0
  #/make-ht 1 #/list #/list 0 #/lake-cane
    (lake-cane 'a #/make-ht 2 #/list
      (list 1
      #/island-cane (trivial) #/hyprid 1 1
      #/island-cane (trivial) #/hyprid 1 0
      #/make-ht 1 #/list #/list 0 #/lake-cane
        (non-lake-cane 'a)
      #/make-ht 1 #/list #/list 0
      #/island-cane (trivial) #/hyprid 1 0
      #/make-ht 1 #/list #/list 0 #/non-lake-cane #/trivial)
      0
      (list 0 #/trivial))
  #/make-ht 1 #/list #/list 0
  #/island-cane (trivial) #/hyprid 1 0
  #/make-ht 1 #/list #/list 0 #/non-lake-cane 'a)
  
  "Striping a hyprid twice")

(check-exn exn:fail?
  (fn
  #/hyprid-stripe-once
  #/hyprid-stripe-once
  #/hyprid-stripe-once
  #/hyprid 3 0 #/make-ht 3 #/list
    (list 2 'a)
    1
    (list 1 'a)
    0
    0
    0
    (list 0 'a))
  "Trying to stripe a hybrid more than it can be striped")
