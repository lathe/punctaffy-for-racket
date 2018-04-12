#lang parendown racket/base

(require #/for-syntax racket/base)


(define-syntax (define-punctaffy-reader-macro stx)
  (syntax-case stx () #/ (_ degree impl)
    'TODO))

(define-syntax (define-punctaffy-backend-macro stx)
  (syntax-case stx () #/ (_ degree impl)
    'TODO))
