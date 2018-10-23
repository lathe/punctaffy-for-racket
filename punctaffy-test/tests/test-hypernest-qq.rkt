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
; To illustrate in more detail, the problem we avoid that way is that
; if we have one `hn-tag-nest` representing a degree-2 snippet of the
; code (encoded as a degree-4 bump) and inside its degree-2 region we
; have a degree-1 snippet of code represented as a degree-1 bump, then
; the first hypertee in the representation of this hypernest will have
; a degree-1 hole (the inner bump) inside a degree-2 region, which is
; treated (whether we like it or not) as a hole in that region rather
; than as a bump. Bumping all the degree-1 snippets up to degree 3
; lets us avoid this.
;
; We shouldn't really have to think about that when we're using
; hypernests, so there's probably a representation format that fits
; the hypernest format better. Here's an approach that could work:
; Instead of representing `hn-tag-nest` as contour-of-contour-shaped
; bumps with empty interiors, we could represent them with bumps whose
; interiors correspond to the interiors of the brackets they represent
; and whose data annotations contain are appropriately shaped
; hypernest values which encode the brackets' original syntax.
;
; On the other hand, since we have been able to get this working with
; that degree-3 approach, do we really need hypernests at all?


; TODO NOW: Some of these tests haven't succeeded ever since we
; changed the implementation of hypernests to an AST-style approach
; (which was necessary so we could have bumps of low degree in the
; areas beyond the low-degree holes of bumps and holes of high
; degree). Fix these tests. Then go back and change `hn-tag-3-...` and
; `hn-tag-4-...` to `hn-tag-1-...` and `hn-tag-2...` since those
; lower-degree encodings will have become correct.
;
; Note that technically `hn-tag-3-...` and `hn-tag-4-...` were always
; of too low degree -- they're only of degree high enough to get
; quasiquote to work -- which is why we needed to start fixing the way
; we were representing hypernests.


; Altogether, these commented-out tests seem to take about (TODO: Time
; these once they're all working.) to run (on my machine). They take
; about (TODO: Time this too.) if `assert-valid-hypertee-brackets` and
; `assert-valid-hypernest-coil` are no-ops.
;
; Each one is labeled with the amount of time it takes to run
; individually (with and without those `assert-...` passes).
;
; TODO: See if there's some way to optimize them. Let's uncomment them
; if we can get them down to 3 minutes or less.


; Time with assertions:       2m45s
; Time without assertions:      11.4s
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

; Time with assertions:     >16m
; Time without assertions:      20.2s
;
; TODO NOW: See if there's an infinite loop when the assertions are
; active.
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

; TODO NOW: Time this.
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

; TODO NOW: Time this.
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
