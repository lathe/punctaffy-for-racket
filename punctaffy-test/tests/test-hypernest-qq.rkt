#lang parendown racket/base

; punctaffy/tests/test-hypernest-qq
;
; Unit tests of quasiquotation operators defined in terms of
; hypersnippet-shaped data structures.

;   Copyright 2018-2019, 2021 The Lathe Authors
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


; TODO NOW: Uncomment these.
#|
(require #/for-syntax racket/base)

(require #/for-syntax #/only-in
  punctaffy/private/suppress-internal-errors
  punctaffy-suppress-internal-errors)

(require rackunit)

(require #/only-in lathe-comforts w-)
(require #/only-in parendown pd)

(require punctaffy)
(require punctaffy/quote)

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


; Altogether, these tests take about 39.458s to run (on my machine).
;
; They run faster if we use `punctaffy-suppress-internal-errors` to
; skip all internal calls to `assert-valid-hypertee-brackets` and
; `assert-valid-hypernest-coil`. When we do that (by changing
; `should-suppress-assertions` to `#t`), the tests take about 26.433s.
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


; Time with assertions:           19.899s
; Time without assertions:        11.987s
;
;#;
(possibly-suppress-assertions
#/check-equal?
  (taffy-quote #/^<d 2
    (a b
      (c d
        (^>d 1 #/list
          (+ 4 5)))))
  `
    (a b
      (c d
        ,(+ 4 5)))
  "`taffy-quote` works a lot like `quasiquote`")

; Time with assertions:           18.094s
; Time without assertions:        18.119s
;
;#;
(possibly-suppress-assertions
#/check-equal?
  (taffy-quote #/^<d 2
    (a b
      (taffy-quote #/_^<d 2
        (c d
          (_^>d 1 #/list
            (e f
              (^>d 1 #/list
                (+ 4 5))))))))
  `
    (a b
      (taffy-quote #/_^<d 2
        (c d
          (_^>d 1 #/list
            (e f
              ,
                (+ 4 5))))))
  "`taffy-quote` works on data that looks roughly similar to nesting")

; Time with assertions:           20.466s
; Time without assertions:        21.376s
;
;#;
(possibly-suppress-assertions
#/check-equal?
  (taffy-quote #/^<d 2
    (a b
      (taffy-quote #/^<d 2
        (c d
          (^>d 1 #/list
            (e f
              (^>d 1 #/list
                (+ 4 5))))))))
  `
    (a b
      (taffy-quote #/^<d 2
        (c d
          (^>d 1 #/list
            (e f
              ,
                (+ 4 5))))))
  "`taffy-quote` supports nesting")

; Time with assertions:           21.670s
; Time without assertions:        21.087s
;
;#;
(possibly-suppress-assertions
#/check-equal?
  (taffy-quote #/^<d 2
    (a b
      (taffy-quote #/^<d 2
        (c d
          (^>d 1 #/list
            (e f
              (^>d 1 #/list
                (+ 4 5))
              g h))
          i j))
      k l))
  `
    (a b
      (taffy-quote #/^<d 2
        (c d
          (^>d 1 #/list
            (e f
              ,
                (+ 4 5)
              g h))
          i j))
      k l)
  "`taffy-quote` supports nesting even when it's not at the end of a list")

; Time with assertions:           17.457s
; Time without assertions:        21.868s
;
;#;
(possibly-suppress-assertions
#/check-equal?
  (w- list-to-splice (list 4 5)
    (taffy-quote #/^<d 2
      (a b
        (taffy-quote #/^<d 2
          (c d
            (^>d 1
              (e f
                (^>d 1 list-to-splice)
                g h))
            i j))
        k l)))
  (w- list-to-splice (list 4 5)
    `
      (a b
        (taffy-quote #/^<d 2
          (c d
            (^>d 1
              (e f
                ,@list-to-splice
                g h))
            i j))
        k l))
  "`taffy-quote` supports nesting and splicing")

(check-equal?
  (pd / taffy-quote / ^<d 2 / println "hello")
  '(println "hello")
  "`taffy-quote` supports being used with `pd`")

(possibly-suppress-assertions
#/check-equal?
  (syntax->datum
  #/w- list-to-splice (list 4 5)
    (taffy-quote-syntax #/^<d 2
      (a b
        (taffy-quote-syntax #/^<d 2
          (c d
            (^>d 1
              (e f
                (^>d 1 list-to-splice)
                g h))
            i j))
        k l)))
  (w- list-to-splice (list 4 5)
    `
      (a b
        (taffy-quote-syntax #/^<d 2
          (c d
            (^>d 1
              (e f
                ,@list-to-splice
                g h))
            i j))
        k l))
  "`taffy-quote-syntax` supports nesting and splicing")

(possibly-suppress-assertions
#/check-equal?
  (syntax->datum
  #/w- list-to-splice (list 4 5)
    (taffy-quote-syntax #:local #/^<d 2
      (a b
        (taffy-quote-syntax #:local #/^<d 2
          (c d
            (^>d 1
              (e f
                (^>d 1 list-to-splice)
                g h))
            i j))
        k l)))
  (w- list-to-splice (list 4 5)
    `
      (a b
        (taffy-quote-syntax #:local #/^<d 2
          (c d
            (^>d 1
              (e f
                ,@list-to-splice
                g h))
            i j))
        k l))
  "`taffy-quote-syntax` with `#:local` supports nesting and splicing")

(check-equal?
  (bound-identifier=?
    (w- x 1 #/quote-syntax x)
    (w- x 1 #/quote-syntax x))
  #t
  "Racket's `quote-syntax` prunes local binding information")
(check-equal?
  (bound-identifier=?
    (w- x 1 #/taffy-quote-syntax #/^<d 2 x)
    (w- x 1 #/taffy-quote-syntax #/^<d 2 x))
  #t
  "`taffy-quote-syntax` prunes local binding information")
(check-equal?
  (bound-identifier=?
    (w- x 1 #/quote-syntax x #:local)
    (w- x 1 #/quote-syntax x #:local))
  #f
  "Racket's `quote-syntax` with `#:local` does not prune local binding information")
(check-equal?
  (bound-identifier=?
    (w- x 1 #/taffy-quote-syntax #:local #/^<d 2 x)
    (w- x 1 #/taffy-quote-syntax #:local #/^<d 2 x))
  #f
  "`taffy-quote-syntax` with `#:local` does not prune local binding information")

(check-equal?
  (syntax-property (quote-syntax {a b c}) 'paren-shape)
  #\{
  "Racket's `quote-syntax` preserves the `'paren-shape` syntax property")
(check-equal?
  (syntax-property
    (taffy-quote-syntax #/^<d 2 {a (^>d 1 #/list (quote-syntax b)) c})
    'paren-shape)
  #\{
  "`taffy-quote-syntax` preserves the `'paren-shape` syntax property, even when there's a splice beyond that node")

(check-equal?
  (syntax-property
    (taffy-quote-syntax #/^<d 2 #/^>d 1 #/list #/quote-syntax {a b c})
    'paren-shape)
  #\{
  "`taffy-quote-syntax` preserves the `'paren-shape` syntax property in the spliced subexpressions")
|#
