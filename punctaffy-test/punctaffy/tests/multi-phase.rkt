#lang parendown racket/base

; multi-phase.rkt
;
; Unit tests of the multi-phase higher quasiquotation macro system.

(require rackunit)

(require punctaffy/multi-phase/private/trees2)

; (We provide nothing from this module.)


(assert-valid-hypertee-brackets 0 #/list)
(assert-valid-hypertee-brackets 1 #/list (list 0 'a))
(assert-valid-hypertee-brackets 2 #/list (list 1 'a) 0 (list 0 'a))
(assert-valid-hypertee-brackets 3 #/list
  (list 2 'a)
  1 (list 1 'a) 0 0 0 (list 0 'a))
(assert-valid-hypertee-brackets 4 #/list
  (list 3 'a)
  2 (list 2 'a) 1 1 1 (list 1 'a) 0 0 0 0 0 0 0 (list 0 'a))
(assert-valid-hypertee-brackets 5 #/list
  (list 4 'a)
  3 (list 3 'a) 2 2 2 (list 2 'a) 1 1 1 1 1 1 1 (list 1 'a)
  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 (list 0 'a))


(check-equal?
  (hypertee-join-all-degrees #/hypertee 2 #/list
    (list 1 #/hypertee-join-interpolation #/hypertee 2 #/list
      (list 0 #/list))
    0
    (list 1 #/hypertee-join-interpolation #/hypertee 2 #/list
      (list 0 #/list))
    0
    (list 0 #/hypertee-join-hole 'a))
  (hypertee 2 #/list
    (list 0 'a))
  "Joining hypertees to cancel out simple degree-1 holes")

(check-equal?
  (hypertee-join-all-degrees #/hypertee 2 #/list
    (list 1 #/hypertee-join-interpolation #/hypertee 2 #/list
      (list 1 'a)
      0
      (list 1 'a)
      0
      (list 0 #/list))
    0
    (list 1 #/hypertee-join-interpolation #/hypertee 2 #/list
      (list 1 'a)
      0
      (list 1 'a)
      0
      (list 0 #/list))
    0
    (list 0 #/hypertee-join-hole 'a))
  (hypertee 2 #/list
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
  (hypertee-join-all-degrees #/hypertee 2 #/list
    (list 1 #/hypertee-join-hole 'a)
    0
    (list 1 #/hypertee-join-interpolation #/hypertee 2 #/list
      (list 1 'a)
      0
      (list 0 #/list))
    0
    (list 1 #/hypertee-join-interpolation #/hypertee 2 #/list
      (list 1 'a)
      0
      (list 0 #/list))
    0
    (list 0 #/hypertee-join-hole 'a))
  (hypertee 2 #/list
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 1 'a)
    0
    (list 0 'a))
  "Joining hypertees where one of the nonzero-degree holes in the root is just a hole rather than an interpolation")

(check-equal?
  (hypertee-join-all-degrees #/hypertee 3 #/list
    
    ; This is propagated to the result.
    (list 1 #/hypertee-join-hole 'a)
    0
    
    (list 2 #/hypertee-join-interpolation #/hypertee 3 #/list
      
      ; This is propagated to the result.
      (list 2 'a)
      0
      
      ; This is matched up with one of the root's degree-1 sections
      ; and cancelled out.
      (list 1 #/list)
      0
      
      ; This is propagated to the result.
      (list 2 'a)
      0
      
      (list 0 #/list))
    
    ; This is matched up with the interpolation's corresponding
    ; degree-1 section and cancelled out.
    1
    0
    
    0
    
    ; This is propagated to the result.
    (list 1 #/hypertee-join-hole 'a)
    0
    
    (list 0 #/hypertee-join-hole 'a))
  (hypertee 3 #/list
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


; TODO: Uncomment this test once we get it working, and put it in a
; `check-equal?` form. Now that we've implemented
; `hypertee-map-all-degrees`, this should be fully implemented, but
; there's an error here somewhere. We may want to write tests for
; `hypertee-map-all-degrees` to help find it.
#;(hyprid-fully-destripe
  (hyprid 1 1
  #/island-cane "Hello, " #/hyprid 0 1 #/hypertee 1 #/list #/list 0
  #/lake-cane 'name #/hypertee 1 #/list #/list 0
  #/island-cane "! It's " #/hyprid 0 1 #/hypertee 1 #/list #/list 0
  #/lake-cane 'weather #/hypertee 1 #/list #/list 0
  #/island-cane " today." #/hyprid 0 1 #/hypertee 1 #/list #/list 0
  #/non-lake-cane #/list))
