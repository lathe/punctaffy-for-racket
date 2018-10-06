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



; TODO NOW: Get these tests to pass, and uncomment the ones that are
; commented out with "#;". Currently, each of them causes the same
; kind of error.
;
; The error they cause right now seems to be due to a mistake in the
; design of hn-expressions themselves (so a fix would need to correct
; the `punctaffy/private/experimental/macro/hypernest-bracket` and
; `punctaffy/private/experimental/macro/hypernest-qq` modules).
; Instead of representing `hn-tag-nest` as contour-of-contour-shaped
; bumps with empty interiors, we need to represent them with... well,
; interiors of some sort. Probably as bumps with interiors according
; to the brackets they represent, and with data annotations that are
; appropriately shaped hypernest values that encode the bracket's
; original syntax.
;
; The problem we solve that way is that if we have one `hn-tag-nest`
; representing a degree-2 snippet of the code (hence encoded as a
; degree-4 bump right now) and inside its degree-2 region it has an
; `hn-tag-nest` that represents a degree-1 snippet of code (encoded as
; a degree-3 bump), that degree-3 bump is... Wait...
;
; There may be an easier way. Instead of using a degree-2 bump to
; represent a degree-2 `hn-tag-nest`, we could keep using a degree-4
; bump as long as we use a *degree-3* bump to represent an
; `hn-tag-1-s-expr-stx` occurrence and a *degree-4* bump to represent
; an `hn-tag-2-list` occurrence.
;
; Huh. If we do that, doesn't that mean we could encode the
; hn-expression as a hypertee after all?

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
