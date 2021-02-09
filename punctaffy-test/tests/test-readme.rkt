#lang parendown racket/base

; punctaffy/tests/test-readme
;
; Unit tests corresponding to examples in the Punctaffy readme.

;   Copyright 2021 The Lathe Authors
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
(require #/only-in net/url
  combine-url/relative string->url url->string)
(require #/only-in syntax/datum datum with-datum)

(require #/only-in punctaffy ^< ^>)
(require #/only-in punctaffy/let list-taffy-map)
(require #/only-in punctaffy/quote taffy-quote)

; (We provide nothing from this module.)


; These are examples used in the readme.

(check-equal?
  (let ()

    (define site-base-url "https://docs.racket-lang.org/")

    (define (make-sxml-site-link relative-url content)
      `(a
         (@
           (href
             ,(url->string
                (combine-url/relative (string->url site-base-url)
                  relative-url))))
         ,@content))

    (make-sxml-site-link "punctaffy/index.html" '("Punctaffy docs")))
  
  '(a (@ (href "https://docs.racket-lang.org/punctaffy/index.html"))
     "Punctaffy docs"))

(define-syntax-rule (check-make-sxml-unordered-list items body)
  (check-equal?
    (let ()
      (define (make-sxml-unordered-list items)
        body)
      (make-sxml-unordered-list (list "Red" "Yellow" "Green")))
    '(ul (li "Red") (li "Yellow") (li "Green"))))

(check-make-sxml-unordered-list items
  `(ul
    ,@(for/list ([item (in-list items)])
        `(li ,item))))

(check-make-sxml-unordered-list items
  (taffy-quote
    (^<
      (ul
        (^>
          (list-taffy-map
            (^< (taffy-quote (^< (li (^> (list (^> items)))))))))))))

(check-make-sxml-unordered-list items
  (taffy-quote #/^< #/ul #/^>
    (list-taffy-map
      (^<
        (taffy-quote #/^< #/li #/^> #/list
          (^> items))))))

(check-make-sxml-unordered-list items
  (with-datum ([(item ...) items])
    (datum (ul (li item) ...))))
