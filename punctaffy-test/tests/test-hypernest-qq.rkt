#lang parendown racket/base

; punctaffy/tests/test-hypernest-qq
;
; Unit tests of a quasiquotation operator defined in terms of
; hypersnippet-shaped data structures.

;   Copyright 2018, 2019 The Lathe Authors
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


(require #/for-syntax racket/base)

(require #/for-syntax #/only-in
  punctaffy/private/suppress-internal-errors
  punctaffy-suppress-internal-errors)

(require rackunit)

(require #/only-in lathe-comforts w-)

(require punctaffy/private/experimental/macro/hypernest-bracket)
(require punctaffy/private/experimental/macro/hypernest-qq)

; (We provide nothing from this module.)


; NOTE: We edit this line to change this to `#f` when we want to
; measure the "with assertions" times.
(define-for-syntax should-suppress-assertions #f)

(define-syntax (possibly-suppress-assertions stx)
  (syntax-case stx () #/ (_ body)
  #/parameterize
    ([punctaffy-suppress-internal-errors should-suppress-assertions])
    (if (procedure-arity-includes? syntax-local-expand-expression 2)
      ; Racket 7.0+
      (let ()
        (define opaque-only #t)
        (define-values (false opaque-expanded-expr)
          (syntax-local-expand-expression #'body opaque-only))
        opaque-expanded-expr)
      
      ; Racket 6.12
      ;
      ; TODO: See if we should keep this around. Lathe Comforts hasn't
      ; stopped working on Racket 6.12, but it's no longer testing on
      ; it, and it might introduce new features that don't work on it.
      ;
      (let ()
        (define-values (expanded-expr opaque-expanded-expr)
          (syntax-local-expand-expression #'body))
        expanded-expr))))


; Altogether, these tests take about 3m01.038s to run (on my machine).
; [TODO UPDATE: They seem to take only 33s now!]
;
; They run faster if we use `punctaffy-suppress-internal-errors` to
; skip all internal calls to `assert-valid-hypertee-brackets` and
; `assert-valid-hypernest-coil`. When we do that (by changing
; `should-suppress-assertions` to `#t`), the tests take about 51.657s.
;
; Each test is labeled with the amount of time it takes to run
; individually, with and without those `assert-...` passes.
;
; We've been timing them by commenting out certain tests and running
; Bash commands like this:
;
;   # Print the date so it's easy to check how long the test has run.
;   # Run the test, and at the end, print how long it takes.
;   # Print the bell control character as a completion notification.
;   date; time racket test-hypernest-qq.rkt; printf '\a'
;
; TODO: If at any point these tests take around 4 minutes or more to
; run, change `should-suppress-assertions` to `#t`. If at any point
; they take around 3 minutes or less to run, change it back to `#f`.
;
; TODO: If at any point any of these timings are likely to be
; outdated, label them with "[TODO UPDATE]". If at any point they're
; labeled with that, update them.


; Time with assertions:           16.235s  [TODO UPDATE]
; Time without assertions:         9.988s  [TODO UPDATE]
;
;#;
(possibly-suppress-assertions
#/check-equal?
  (my-quasiquote #/^< 2
    (a b
      (c d
        (^> 1 #/list
          (+ 4 5)))))
  `
    (a b
      (c d
        ,(+ 4 5)))
  "The new quasiquote works a lot like the original")

; Time with assertions:         1m12.688s  [TODO UPDATE]
; Time without assertions:        17.133s  [TODO UPDATE]
;
;#;
(possibly-suppress-assertions
#/check-equal?
  (my-quasiquote #/^< 2
    (a b
      (my-quasiquote #/_^< 2
        (c d
          (_^> 1 #/list
            (e f
              (^> 1 #/list
                (+ 4 5))))))))
  `
    (a b
      (my-quasiquote #/_^< 2
        (c d
          (_^> 1 #/list
            (e f
              ,
                (+ 4 5))))))
  "The new quasiquote works on data that looks roughly similar to nesting")

; Time with assertions:           59.624s  [TODO UPDATE]
; Time without assertions:        18.623s  [TODO UPDATE]
;
;#;
(possibly-suppress-assertions
#/check-equal?
  (my-quasiquote #/^< 2
    (a b
      (my-quasiquote #/^< 2
        (c d
          (^> 1 #/list
            (e f
              (^> 1 #/list
                (+ 4 5))))))))
  `
    (a b
      (my-quasiquote #/^< 2
        (c d
          (^> 1 #/list
            (e f
              ,
                (+ 4 5))))))
  "The new quasiquote supports nesting")

; Time with assertions:         1m01.345s  [TODO UPDATE]
; Time without assertions:        19.327s  [TODO UPDATE]
;
;#;
(possibly-suppress-assertions
#/check-equal?
  (my-quasiquote #/^< 2
    (a b
      (my-quasiquote #/^< 2
        (c d
          (^> 1 #/list
            (e f
              (^> 1 #/list
                (+ 4 5))
              g h))
          i j))
      k l))
  `
    (a b
      (my-quasiquote #/^< 2
        (c d
          (^> 1 #/list
            (e f
              ,
                (+ 4 5)
              g h))
          i j))
      k l)
  "The new quasiquote supports nesting even when it's not at the end of a list")

; Time with assertions:           45.716s  [TODO UPDATE]
; Time without assertions:        14.983s  [TODO UPDATE]
;
;#;
(possibly-suppress-assertions
#/check-equal?
  (w- list-to-splice (list 4 5)
    (my-quasiquote #/^< 2
      (a b
        (my-quasiquote #/^< 2
          (c d
            (^> 1
              (e f
                (^> 1 list-to-splice)
                g h))
            i j))
        k l)))
  (w- list-to-splice (list 4 5)
    `
      (a b
        (my-quasiquote #/^< 2
          (c d
            (^> 1
              (e f
                ,@list-to-splice
                g h))
            i j))
        k l))
  "The new quasiquote supports nesting and splicing")


; TODO: Turn this into a unit test. There was at one point (although
; not in any code that's been committed) a bug in `hypertee-fold`
; which involved using a mix of mutation and pure code, and it made
; the `c1` and `c2` holes disappear.
;
; We're now using pure code throughout the hypertee implementation,
; but it's still a bit like using mutation in some places since we
; maintain hash tables that simulate mutable heaps. There may be a
; similar bug still lurking in there, maybe for degree-3 holes. We
; should write tests like this with degree-3 holes to check it out.
;
#|
(require punctaffy/hypersnippet/hypertee)

(writeln #/hypertee-drop1
  (n-ht (nat-dim-successors-sys) 3
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
