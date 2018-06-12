#lang parendown racket/base

; multi-phase-qq.rkt
;
; Unit tests of a quasiquotation operator defined in the multi-phase
; higher quasiquotation macro system.

(require rackunit)

(require punctaffy/multi-phase/private/qq)

; (We provide nothing from this module.)



(check-equal?
  (my-quasiquote uq #/qq
    (a b
      (c d
        (uq (+ 4 5)))))
  `
    (a b
      (c d
        ,(+ 4 5)))
  "The new quasiquote works a lot like the original")


; TODO: Turn this into a unit test. There was at one point (although
; not in any code that's been committed) a bug in `hypertee-fold`
; which made the `c1` and `c2` holes disappear, because we were trying
; to replace the `loc-interpolation` state's `rev-brackets` slot in a
; pure way, rather than using a mutable box (`rev-brackets-box`).
;
; We're still using a similar kind of pure code to change a
; `loc-interpolation-uninitialized` state into a `loc-interpolation`
; state, so there's a good chance there's a similar bug lurking in
; there, maybe for degree-3 holes. We should write tests like this
; with degree-3 holes to check it out.
;
#|
(require punctaffy/multi-phase/private/trees2)

(writeln #/hypertee-drop1
  (degree-and-closing-brackets->hypertee 3 #/list
    (list 2 'a)
      1
        (list 2 'b)
          (list 1 'c1)
          0
          (list 1 'c2)
          0
        0
        (list 1 'c3)
        0
      0
    0
  #/list 0 'end))
|#
