#lang parendown racket/base

; punctaffy/tests/test-hypernest-qq
;
; Unit tests of a quasiquotation operator defined in terms of
; hypersnippet-shaped data structures.

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

(require #/only-in lathe-comforts w-)

(require punctaffy/private/experimental/macro/hypernest-bracket)
(require punctaffy/private/experimental/macro/hypernest-qq)

; (We provide nothing from this module.)



; Altogether, these commented-out tests seem to take about
; 54m52s[TODO UPDATE] to run (on my machine). They take about 1m1.236s
; if `assert-valid-hypertee-brackets` and
; `assert-valid-hypernest-coil` are no-ops.
;
; Each one is labeled with the amount of time it takes to run
; individually (with and without those `assert-...` passes).
;
; TODO: See if there's some way to optimize them. Let's uncomment them
; if we can get them down to 3 minutes or less.
;
; TODO: Update any timings labeled with "[TODO UPDATE]". We've added
; behavior to `assert-valid-hypernest-coil` and redesigned the
; unquotes to be of the form `(^> 1 #/list ...)` instead of
; `(^> 1 ...)`, so the timings are likely to be longer now. Longer
; than one hour each, if the time of the splicing test is any
; indication.


; Time with assertions:         4m15.992s
; Time without assertions:         8.910s
;
#;
(check-equal?
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

; Time with assertions:        20m54s[TODO UPDATE]
; Time without assertions:        17.853s
;
#;
(check-equal?
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

; Time with assertions:        14m01s[TODO UPDATE]
; Time without assertions:        19.709s
;
#;
(check-equal?
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

; Time with assertions:        15m10s[TODO UPDATE]
; Time without assertions:        20.582s
;
#;
(check-equal?
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

; Time with assertions:      1h13m42.123s
; Time without assertions:        14.975s
;
#;
(check-equal?
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
