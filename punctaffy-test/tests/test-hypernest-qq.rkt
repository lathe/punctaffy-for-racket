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

(require punctaffy/private/experimental/macro/hypernest-bracket)
(require punctaffy/private/experimental/macro/hypernest-qq)

; (We provide nothing from this module.)



; TODO:
;
; These tests used to cause an error error due to a mistake in the
; design of hn-expressions themselves (so a fix needed to correct the
; `punctaffy/private/experimental/macro/hypernest-bracket` and
; `punctaffy/private/experimental/macro/hypernest-qq` modules).
;
; Right now we're taking an approach where we represent expressions
; using degree-3 regions and list-like operations using degree-4
; regions. This makes it possible for them to reside inside a
; `hn-tag-nest` region without being confused with closing brackets
; bounding the region.
;
; The problem we avoided that way has to do with a previous
; representation of hypernests we were using. That representation
; treated all the hypernest's immediate holes and bumps as being holes
; of a hypertee, and it treated the interior of each bump as another
; hypertee. This representation was incorrect because it wasn't able
; to represent a low-degree bump that occurred inside of a high-degree
; hole of a higher-degree hole or bump. Those low-degree bumps would
; have needed to be represented by low-degree holes, but the
; low-degree holes occurring there were inside high-degree holes in
; the hypertee representation, so they could only represent holes in
; the high-degree hole, not bumps in it.
;
; To work around this problem at first, we represented expressions
; using degree-3 regions and list-like operations using degree-4
; regions. This put them at just high enough a degree that we could
; get these quasiquotation tests to work. I believe an operator of
; higher degree than quasiquotation would have required us to raise
; the degrees of our regions accordingly, so this was not an approach
; that allowed us to express operators of arbitrary degree.
;
; Now, we have changed the representation of hypernests so that it
; *is* possible to represent a low-degree bump beyond a higher-degree
; hole in a high-degree hole or bump. This means we should be able to
; switch the expressions and list-like operators back to using
; degree-1 and degree-2 regions. If we can, I don't believe we will
; have trouble implementing operations of higher degree than
; quasiquotation.


; Altogether, these commented-out tests seem to take about 54m52s to
; run (on my machine). They take about 28.7s if
; `assert-valid-hypertee-brackets` and `assert-valid-hypernest-coil`
; are no-ops.
;
; Each one is labeled with the amount of time it takes to run
; individually (with and without those `assert-...` passes).
;
; TODO: See if there's some way to optimize them. Let's uncomment them
; if we can get them down to 3 minutes or less.


; Time with assertions:       3m07s
; Time without assertions:       9.67s
;
#;
(check-equal?
  (my-quasiquote #/^< 2
    (a b
      (c d
        (^> 1 (+ 4 5)))))
  `
    (a b
      (c d
        ,(+ 4 5)))
  "The new quasiquote works a lot like the original")

; Time with assertions:      20m54s
; Time without assertions:      13.3s
;
#;
(check-equal?
  (my-quasiquote #/^< 2
    (a b
      (my-quasiquote #/_^< 2
        (c d
          (_^> 1
            (e f
              (^> 1 (+ 4 5))))))))
  `
    (a b
      (my-quasiquote #/_^< 2
        (c d
          (_^> 1
            (e f
              ,(+ 4 5))))))
  "The new quasiquote works on data that looks roughly similar to nesting")

; Time with assertions:      14m01s
; Time without assertions:      20.1s
;
#;
(check-equal?
  (my-quasiquote #/^< 2
    (a b
      (my-quasiquote #/^< 2
        (c d
          (^> 1
            (e f
              (^> 1 (+ 4 5))))))))
  `
    (a b
      (my-quasiquote #/^< 2
        (c d
          (^> 1
            (e f
              ,(+ 4 5))))))
  "The new quasiquote supports nesting")

; Time with assertions:      15m10s
; Time without assertions:      16.6s
;
#;
(check-equal?
  (my-quasiquote #/^< 2
    (a b
      (my-quasiquote #/^< 2
        (c d
          (^> 1
            (e f
              (^> 1 (+ 4 5))
              g h))
          i j))
      k l))
  `
    (a b
      (my-quasiquote #/^< 2
        (c d
          (^> 1
            (e f
              ,(+ 4 5)
              g h))
          i j))
      k l)
  "The new quasiquote supports nesting even when it's not at the end of a list")


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
