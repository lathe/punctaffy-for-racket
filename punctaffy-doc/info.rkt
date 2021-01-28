#lang info

(define collection "punctaffy")

(define deps (list "base"))
(define build-deps
  (list
    "lathe-comforts-doc"
    "lathe-comforts-lib"
    "lathe-morphisms-doc"
    "lathe-morphisms-lib"
    "parendown-doc"
    "parendown-lib"
    "punctaffy-lib"
    "racket-doc"
    "scribble-lib"))

(define scribblings
  (list (list "scribblings/punctaffy.scrbl" (list 'multi-page))))
