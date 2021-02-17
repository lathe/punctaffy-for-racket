#lang info

(define collection "punctaffy")

(define deps (list "base"))
(define build-deps
  (list
    "at-exp-lib"
    "brag"
    "lathe-comforts-doc"
    "lathe-comforts-lib"
    "lathe-morphisms-doc"
    "lathe-morphisms-lib"
    "net-doc"
    "parendown-doc"
    "parendown-lib"
    "punctaffy-lib"
    "racket-doc"
    "ragg"
    "scribble-lib"))

(define scribblings
  (list (list "scribblings/punctaffy.scrbl" (list 'multi-page))))
