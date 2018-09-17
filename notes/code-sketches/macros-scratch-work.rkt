#lang parendown racket

;   Copyright 2017-2018 The Lathe Authors
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


(provide (all-defined-out))

(require (for-meta 1 (only-in racket/match match)))
(require (only-in racket/stxparam define-syntax-parameter syntax-parameter-value))





(define-values
  (prop:qq-transformer qq-transformer? qq-transformer-ref)
  (make-struct-type-property 'qq-transformer))

(struct simple-qq-transformer (val)
  #:property prop:qq-transformer
  (lambda (this stx)
    (match this
      [(simple-qq-transformer val) (val stx)]
      [_ (error "Expected this to be a simple-qq-transformer")])))

(define-syntax-parameter qq-unquote #/lambda (stx)
#/syntax-case stx ()
  [(_ exprs ...) (error "Encountered an unmatched qq-unquote")])

(define-syntax-parameter qq-quasiquote #/lambda (stx)
#/syntax-case stx ()
  [(_ expr) (error "Encountered an unmatched qq-unquote")])

(define-syntax-parameter blah 2)

(define-syntax notparam
  (lambda (stx)
    (syntax-case stx ()
      [ (_ stx)
        (let ([result (syntax-local-value #'stx)])
          #`(#,(lambda () result)))])))

(writeln (notparam blah))

(begin-for-syntax
  (struct mutable-syntax (storage)
    #:property prop:procedure
    (lambda (this stx)
      (match this
        [ (mutable-syntax storage)
          ((unbox storage) stx)]
        [_ (error "Expected this to be a mutable-syntax")]))))
;  (struct foo () #:property prop:set!-transformer (lambda args (displayln "expanding foo") 2)))

(define-syntax foo (mutable-syntax (box (lambda (stx) #''hello-from-foo))))

(define-syntax local
  (lambda (stx)
    (syntax-case stx ()
      [ (_ stx)
        (let ([result (mutable-syntax-storage (syntax-local-value #'stx))])
          #`(#,(lambda () result)))])))

(writeln (eval-syntax #'(foo 1)))

(writeln (foo 1.1))

(set-box! (eval-syntax #'(local foo)) (lambda (stx) #''hello-from-foo-2))

(writeln (eval-syntax #'(foo 2)))

(begin-for-syntax
  (set-box! (mutable-syntax-storage (syntax-local-value #'foo))
    (lambda (stx) #''hello-from-foo-number-3)))

(writeln (foo 2.1))

;(writeln ((unbox (local foo)) 1))

#;(define-syntax foo-stx
  (lambda (stx)
    `(,(foo))))

#;(define-syntax foo-stx2 2)

;(set! (foo-stx) 9)

#;(begin-for-syntax
  (writeln (syntax-local-value #'foo-stx2)))

#;(for-meta 0
  (writeln (namespace-variable-value 'foo-stx)))
