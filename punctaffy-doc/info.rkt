#lang info

(define collection "punctaffy")

(define deps (list "base"))
(define build-deps (list "parendown-lib" "racket-doc" "scribble-lib"))

(define scribblings
  (list (list "scribblings/punctaffy.scrbl" (list 'multi-page))))
