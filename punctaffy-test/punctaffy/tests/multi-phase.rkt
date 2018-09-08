#lang parendown racket/base

; multi-phase.rkt
;
; Unit tests of the multi-phase higher quasiquotation macro system.

(require rackunit)

(require #/only-in lathe-comforts fn)
(require #/only-in lathe-comforts/trivial trivial)

(require punctaffy/multi-phase/private/trees2)

; (We provide nothing from this module.)


(define make-ht degree-and-closing-brackets->hypertee)


(degree-and-closing-brackets->hypertee 0 #/list)
(degree-and-closing-brackets->hypertee 1 #/list (list 0 'a))
(degree-and-closing-brackets->hypertee 2 #/list
  (list 1 'a)
  0 (list 0 'a))
(degree-and-closing-brackets->hypertee 3 #/list
  (list 2 'a)
  1 (list 1 'a) 0 0 0 (list 0 'a))
(degree-and-closing-brackets->hypertee 4 #/list
  (list 3 'a)
  2 (list 2 'a) 1 1 1 (list 1 'a) 0 0 0 0 0 0 0 (list 0 'a))
(degree-and-closing-brackets->hypertee 5 #/list
  (list 4 'a)
  3 (list 3 'a) 2 2 2 (list 2 'a) 1 1 1 1 1 1 1 (list 1 'a)
  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 (list 0 'a))


(check-equal?
  (hypertee-join-all-degrees #/make-ht 2 #/list
    (list 1 #/make-ht 2 #/list
      (list 0 #/trivial))
    0
    (list 1 #/make-ht 2 #/list
      (list 0 #/trivial))
    0
    (list 0 #/hypertee-pure 2 'a #/make-ht 0 #/list))
  (make-ht 2 #/list
    (list 0 'a))
  "Joining hypertees to cancel out simple degree-1 holes")

(check-equal?
  (hypertee-join-all-degrees #/make-ht 2 #/list
    (list 1 #/make-ht 2 #/list
      (list 1 'a)
      0
      (list 1 'a)
      0
      (list 0 #/trivial))
    0
    (list 1 #/make-ht 2 #/list
      (list 1 'a)
      0
      (list 1 'a)
      0
      (list 0 #/trivial))
    0
    (list 0 #/hypertee-pure 2 'a #/make-ht 0 #/list))
  (make-ht 2 #/list
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 0 'a))
  "Joining hypertees to make a hypertee with more holes than any of the parts on its own")

(check-equal?
  (hypertee-join-all-degrees #/make-ht 2 #/list
    (list 1 #/hypertee-pure 2 'a #/make-ht 1 #/list
      (list 0 #/trivial))
    0
    (list 1 #/make-ht 2 #/list
      (list 1 'a)
      0
      (list 0 #/trivial))
    0
    (list 1 #/make-ht 2 #/list
      (list 1 'a)
      0
      (list 0 #/trivial))
    0
    (list 0 #/hypertee-pure 2 'a #/make-ht 0 #/list))
  (make-ht 2 #/list
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 0 'a))
  "Joining hypertees where one of the nonzero-degree holes in the root is just a hole rather than an interpolation")

(check-equal?
  (hypertee-join-all-degrees #/make-ht 3 #/list
    
    ; This is propagated to the result.
    (list 1 #/hypertee-pure 3 'a #/make-ht 1 #/list
      (list 0 #/trivial))
    0
    
    (list 2 #/make-ht 3 #/list
      
      ; This is propagated to the result.
      (list 2 'a)
      0
      
      ; This is matched up with one of the root's degree-1 sections
      ; and cancelled out.
      (list 1 #/trivial)
      0
      
      ; This is propagated to the result.
      (list 2 'a)
      0
      
      (list 0 #/trivial))
    
    ; This is matched up with the interpolation's corresponding
    ; degree-1 section and cancelled out.
    1
    0
    
    0
    
    ; This is propagated to the result.
    (list 1 #/hypertee-pure 3 'a #/make-ht 1 #/list
      (list 0 #/trivial))
    0
    
    (list 0 #/hypertee-pure 3 'a #/make-ht 0 #/list))
  (make-ht 3 #/list
    (list 1 'a)
    0
    (list 2 'a)
    0
    (list 2 'a)
    0
    (list 1 'a)
    0
    (list 0 'a))
  "Joining hypertees where one of the interpolations is degree 2 with its own degree-1 hole")


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
