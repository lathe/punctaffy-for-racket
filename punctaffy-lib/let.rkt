#lang parendown racket/base

; punctaffy/let
;
; Binding and iteration operators which use Punctaffy's hyperbrackets
; to manage their nesting and interoperation.

;   Copyright 2018-2019, 2021 The Lathe Authors
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


(require #/for-syntax racket/base)

(require #/for-syntax #/only-in racket/syntax generate-temporary)
(require #/for-syntax #/only-in syntax/parse
  ...+ expr expr/c id syntax-parse)

(require #/for-syntax #/only-in lathe-comforts
  dissect expect fn mat w-)
(require #/for-syntax #/only-in lathe-comforts/list
  list-bind list-map)
(require #/for-syntax #/only-in lathe-comforts/maybe just nothing)
(require #/for-syntax #/only-in lathe-comforts/trivial trivial)

(require #/for-syntax #/only-in punctaffy/hypersnippet/dim
  dim-sys-dim=? dim-sys-dim=0? dim-sys-morphism-sys-morph-dim
  extended-with-top-dim-infinite extended-with-top-dim-sys
  extend-with-top-dim-sys-morphism-sys nat-dim-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypernest
  hnb-labeled hnb-open hnb-unlabeled hypernest-coil-bump
  hypernest-coil-hole hypernest-from-brackets hypernest-furl
  hypernest-shape hypernest-snippet-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypertee
  htb-labeled htb-unlabeled hypertee-coil-zero hypertee-furl
  hypertee-get-brackets hypertee-snippet-format-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/snippet
  snippet-sys-shape-snippet-sys snippet-sys-snippet-degree
  snippet-sys-snippet-join snippet-sys-snippet-map
  snippet-sys-snippet-set-degree-maybe snippet-sys-snippet-undone
  snippet-sys-snippet-zip-map)
(require #/for-syntax #/only-in
  punctaffy/private/experimental/macro/hypernest-macro
  hn-expr->s-expr-stx-list hn-tag-0-s-expr-stx hn-tag-nest
  s-expr-stx->hn-expr)

(require #/only-in racket/list append-map)
(require #/only-in syntax/parse/define define-simple-macro)

(require #/only-in lathe-comforts fn w-)


(provide
  taffy-let
  list-taffy-map
  list-taffy-bind)


(define-for-syntax (hn-bracs-n-d ds n-d degree . brackets)
  (w- n-d (fn d #/dim-sys-morphism-sys-morph-dim n-d d)
  #/hypernest-from-brackets ds (n-d degree)
    (list-map brackets #/fn bracket
      (mat bracket (hnb-open d data) (hnb-open (n-d d) data)
      #/mat bracket (hnb-labeled d data) (hnb-labeled (n-d d) data)
      #/mat bracket (hnb-unlabeled d) (hnb-unlabeled (n-d d))
      #/hnb-unlabeled (n-d bracket)))))


(define-for-syntax en-ds (extended-with-top-dim-sys #/nat-dim-sys))
(define-for-syntax en-n-d
  (extend-with-top-dim-sys-morphism-sys #/nat-dim-sys))

(define-for-syntax
  (helper-for-let
    err-dsl-stx
    err-phrase-expression
    err-phrase-invocation
    err-name
    body-and-splices)
  (w- ds en-ds
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/w- n-d en-n-d
  #/w- body-and-splices
    (s-expr-stx->hn-expr err-dsl-stx body-and-splices)
  #/expect body-and-splices
    (hypernest-furl _ #/hypernest-coil-bump
      overall-degree
      (hn-tag-nest)
      (extended-with-top-dim-infinite)
      bracket-and-body-and-tails)
    ; TODO: We should let `err-name` be more than one symbol.
    (error #/format "Expected ~a to be of the form (~s #/^< ...)"
      err-phrase-invocation
      err-name)
  #/dissect
    (snippet-sys-snippet-undone shape-ss
      (hypernest-shape ss bracket-and-body-and-tails))
    (just #/list (extended-with-top-dim-infinite) tails body)
  #/w- represented-bump-degree
    (snippet-sys-snippet-degree shape-ss tails)
  #/expect
    (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 2)
      represented-bump-degree)
    #t
    ; TODO: We should let `err-name` be more than one symbol.
    (error #/format "Expected ~a to be of the form (~s #/^< 2 ...)"
      err-phrase-invocation
      err-name)
  #/w- tails-via-temporaries
    (snippet-sys-snippet-map shape-ss tails #/fn hole tail
      (w- d (snippet-sys-snippet-degree shape-ss hole)
      #/if (dim-sys-dim=0? ds d)
        ; We verify that the tail in the hole of degree-0 is a snippet
        ; with just one hole, a degree-0 hole containing a trivial
        ; value.
        (dissect tail
          (hypernest-furl _ #/hypernest-coil-hole _ _ (trivial)
            (hypertee-furl _ #/hypertee-coil-zero))
        #/list (nothing)
          (hn-bracs-n-d ds n-d 2 #/hnb-labeled 0 #/trivial))
      #/dissect
        (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 1) d)
        #t
        (expect (hn-expr->s-expr-stx-list tail) (list splice)
          (error #/format "Encountered more than one ~a in a splice of ~a"
            err-phrase-expression
            err-phrase-invocation)
        #/w- temp (generate-temporary splice)
        #/list (just #/list temp splice)
          (hn-bracs-n-d ds n-d 2
            (hnb-open 0 #/hn-tag-0-s-expr-stx
              ; TODO: Consider protecting it even more than this.
              ; Currently, it can appear under a `quote`, but we can
              ; quash some attempts to exploit that by inserting a
              ; non-marshalable value into the expression.
              (syntax-protect #`(#,temp)))
            (hnb-labeled 0 #/trivial)))))
  #/dissect
    (snippet-sys-snippet-zip-map ss tails-via-temporaries body
    #/fn hole tail-via-temporary body-data
      (dissect tail-via-temporary (list binding tail)
      #/dissect body-data (trivial)
      #/just tail))
    (just zipped)
  #/w- joined (snippet-sys-snippet-join ss zipped)
  #/expect
    (hn-expr->s-expr-stx-list
      (dissect
        (snippet-sys-snippet-set-degree-maybe ss
          (dim-sys-morphism-sys-morph-dim n-d 1)
          joined)
        (just joined)
        joined))
    (list body)
    (error #/format "Encountered more than one ~a in ~a"
      err-phrase-expression
      err-phrase-invocation)
  #/w- bindings
    (list-bind (hypertee-get-brackets tails-via-temporaries) #/fn b
      (mat b (htb-labeled d tail-via-temporary)
        (dissect tail-via-temporary (list maybe-binding tail)
        #/expect maybe-binding (just binding) (list)
        #/list binding)
      #/dissect b (htb-unlabeled d) (list)))
  #/list bindings body))


; TODO: See which of these we should export. Document `taffy-let`.

; TODO: Instead of using this, use something with better error
; messages (i.e. something that passes custom arguments to
; `helper-for-let`).
(define-syntax (taffy-letlike stx)
  (syntax-protect
  #/syntax-parse stx #/ (_ letlike-call ... body-and-splices)
    
    #:with (([var val] ...) body)
    (helper-for-let
      stx
      "s-expression"
      "a taffy-letlike invocation"
      'taffy-letlike
      #'body-and-splices)
    
    #'(letlike-call ... ([var val] ...) body)))

; TODO: See if we'll use this. It would be good for a binding time
; annotation.
(define-simple-macro
  (letlike-eager letlike-call ... ([var:id val:expr] ...) body)
  (letlike-call ... ([var (w- result val #/fn result)] ...)
    body))

(define-simple-macro
  (letlike-lazy letlike-call ... ([var:id val:expr] ...) body)
  (letlike-call ... ([var (fn val)] ...)
    body))

(define-simple-macro
  (letlike-merge letlike-call ...
    ([var-1:id val-1:expr] ...)
    ([var-2:id val-2:expr] ...)
    body)
  (letlike-call ... ([var-1 val-1] ... [var-2 val-2] ...)
    body))

(define-simple-macro
  (taffy-let ([var:id val:expr] ...) body-and-splices)
  (taffy-letlike letlike-lazy letlike-merge let ([var val] ...)
    body-and-splices))

(define-simple-macro (list-taffy-map-impl ([var:id val] ...+) body)
  #:declare val (expr/c #'list? #:name "an iteration subject")
  #:declare body (expr/c #'any/c #:name "a transformed list element")
  #:with (elem ...+) (generate-temporaries #'(var ...))
  (map
    (lambda (elem ...)
      (let ([var (fn elem)] ...)
        body))
    val.c
    ...))

(define-simple-macro (list-taffy-map body-and-splices)
  (taffy-letlike list-taffy-map-impl body-and-splices))

(define-simple-macro (list-taffy-bind-impl ([var:id val] ...+) body)
  #:declare val (expr/c #'list? #:name "an iteration subject")
  #:declare body (expr/c #'list? #:name "a transformed list segment")
  #:with (elem ...+) (generate-temporaries #'(var ...))
  (append-map
    (lambda (elem ...)
      (let ([var (fn elem)] ...)
        body))
    val.c
    ...))

(define-simple-macro (list-taffy-bind body-and-splices)
  (taffy-letlike list-taffy-bind-impl body-and-splices))

(define-simple-macro
  (taffy-forlike-impl forlike-call ... ([var:id seq:expr] ...) body)
  #:with (eager-var ...) (generate-temporaries #'(var ...))
  (forlike-call ... ([eager-var seq] ...)
    (let ([var (fn eager-var)] ...)
      body)))

(define-simple-macro (taffy-forlike forlike-call ... body-and-splices)
  (taffy-letlike taffy-forlike-impl forlike-call ...
    body-and-splices))
