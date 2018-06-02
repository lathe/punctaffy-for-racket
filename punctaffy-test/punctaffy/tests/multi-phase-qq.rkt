#lang parendown racket/base

; multi-phase-qq.rkt
;
; Unit tests of a quasiquotation operator defined in the multi-phase
; higher quasiquotation macro system.

(require rackunit)

(require punctaffy/multi-phase/private/qq)

; (We provide nothing from this module.)



; TODO: Uncomment this once we have `ht-drop1` implemented.
#;(check-equal?
  (my-quasiquote my-unquote
    (a b
      (c d
        (my-unquote (+ 4 5)))))
  `
    (a b
      (c d
        ,(+ 4 5)))
  "The new quasiquote works a lot like the original")
