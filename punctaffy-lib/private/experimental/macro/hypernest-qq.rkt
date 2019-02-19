#lang parendown racket/base

; hypernest-qq.rkt
;
; A quasiquotation operator which allows for user-defined escape
; sequences which can generalize unquotation and nested
; quasiquotation.

;   Copyright 2018-2019 The Lathe Authors
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

(require #/for-syntax #/only-in syntax/parse syntax-parse)

(require #/for-syntax #/only-in lathe-comforts
  dissect expect fn mat w-)
(require #/for-syntax #/only-in lathe-comforts/list list-map)
(require #/for-syntax #/only-in lathe-comforts/maybe just just-value)
(require #/for-syntax #/only-in lathe-comforts/trivial trivial)

(require #/for-syntax #/only-in punctaffy/hypersnippet/dim
  dim-successors-sys-dim-from-int dim-successors-sys-dim-sys
  dim-sys-dim=? dim-sys-dim=0? nat-dim-successors-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypernest
  hnb-labeled hnb-open hn-bracs-dss hypernest-append-zero
  hypernest-coil-bump hypernest-coil-hole hypernest-degree
  hypernest-furl hypernest-get-hole-zero hypernest-join-all-degrees
  hypernest->maybe-hypertee hypernest-set-degree-and-join-all-degrees
  hypernest-unfurl hypernest-v-map-one-degree
  hypernest-zip hypertee->hypernest)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypertee
  hypertee-degree hypertee-dv-map-all-degrees hypertee-uncontour
  hypertee-v-each-one-degree)
(require #/for-syntax #/only-in
  punctaffy/private/experimental/macro/hypernest-macro
  hn-tag-0-s-expr-stx hn-tag-1-list hn-tag-1-list* hn-tag-1-prefab
  hn-tag-1-vector hn-tag-nest s-expr-stx->hn-expr)

(require #/only-in lathe-comforts expect w-)


(provide my-quasiquote)


; (TODO: Update this comment. We now define ^< and ^> in
; hypernest-bracket.rkt.)
;
; TODO:
;
; Salvage anything from qq.rkt that makes sense to salvage for this
; file.
;
; Compared to qq.rkt, this whole file's design needs to be rethought
; now that we're using hypernests instead of hypertees. The syntax we
; use for quasiquotation should no longer be this:
;
;   (my-quasiquote uq #/qq
;     (a b
;       (my-quasiquote uq #/qq
;         (c d
;           (uq
;             (e f
;               (uq
;                 (+ 4 5))))))))
;
; Instead, it should be something like this, with new
; operators ^< and ^> that signify opening brackets and closing
; brackets of explicit degrees:
;
;   (my-quasiquote #/^< 2
;     (a b
;       (my-quasiquote #/^< 2
;         (c d
;           (^> 1 #/my-unquote
;             (e f
;               (^> 1 #/my-unquote
;                 (+ 4 5))))))))
;
; The ^< and ^> syntaxes should be defined in and provided from some
; module that makes them look as much like language builtins as
; reasonably possible. (In particular, `(require punctaffy)` should
; get them.) Most programmers will be able to treat them as
; parentheses; like parentheses, they're a notation that most programs
; don't need to extend or parse in custom ways.
;
; The `my-quasiquote` and `my-unquote` syntaxes should be defined only
; in terms of `s-expr-stx->hn-expr`, the structs of the hn-expression
; format, and the hypernest and hypertee utilities. Even these won't
; need to extend or parse the higher-order paren notation in custom
; ways.
;
; Users of `my-quasiquote` and `my-unquote` will only need to import
; those two operations and ^< and ^> but will not usually need to
; understand them any more deeply than the traditional `quasiquote`
; and `unquote`. Even if they define another quasiquotation syntax, it
; will interoperate seamlessly with `my-quasiquote` and `my-unquote`
; if it makes similar use of `s-expr-stx->hn-expr`.
;
; If people define custom parentheses very often, quotation operators
; will typically fail to preserve their meaning since code generated
; for different lexical contexts could have different sets of custom
; parentheses available. That's why we should decide on a minimalistic
; set of operators like ^< and ^> that can express the full range of
; hn-expressions and provide these as the baseline that other syntaxes
; are typically built around.


(define-for-syntax (hn-expr->s-expr-stx-list dss hn)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/expect (dim-successors-sys-dim-from-int dss 1) (just _)
    (error "Expected at least 1 successor to exist for the zero dimension")
  #/w- n-d (fn n #/just-value #/dim-successors-sys-dim-from-int dss n)
  #/expect (dim-sys-dim=? ds (hypernest-degree hn) (n-d 1)) #t
    (raise-arguments-error 'hn-expr->s-expr-stx-list
      "expected an hn-expr of degree 1"
      "hn" hn)
  #/w- dropped (hypernest-unfurl hn)
  #/mat dropped (hypernest-coil-hole _ data tails)
    (expect data (trivial)
      (error "Expected an hn-expr with a trivial value in its degree-0 hole")
    #/list)
  #/dissect dropped (hypernest-coil-bump _ data bump-degree tails)
  #/mat data (hn-tag-0-s-expr-stx stx)
    (expect (dim-sys-dim=0? ds bump-degree) #t
      (error "Encountered an hn-tag-0-s-expr-stx bump with a degree other than 0")
    #/cons stx #/hn-expr->s-expr-stx-list dss tails)
  #/w- process-listlike
    (fn stx-example list->whatever
      (expect (dim-sys-dim=? ds bump-degree (n-d 1)) #t
        (error "Encountered a list-like hn-tag-1-... bump with a degree other than 1")
      #/w- elems
        (hypernest-v-map-one-degree (n-d 0) tails #/fn tail
          (trivial))
      #/dissect (hypernest-get-hole-zero tails) (just tail)
      #/cons
        (datum->syntax stx-example
          (list->whatever #/hn-expr->s-expr-stx-list dss elems))
        (hn-expr->s-expr-stx-list dss tail)))
  #/mat data (hn-tag-1-list stx-example)
    (process-listlike stx-example #/fn lst lst)
  #/mat data (hn-tag-1-list* stx-example)
    (process-listlike stx-example #/fn lst #/apply list* lst)
  #/mat data (hn-tag-1-vector stx-example)
    (process-listlike stx-example #/fn lst #/list->vector lst)
  #/mat data (hn-tag-1-prefab key stx-example)
    (process-listlike stx-example #/fn lst
      (apply make-prefab-struct key lst))
  #/mat data (hn-tag-nest)
    (expect (hypernest->maybe-hypertee tails) (just tails)
      (error "Encountered an hn-tag-nest bump with bumps in it")
    #/expect (hypertee-uncontour dss tails)
      (just #/list bracket-syntax tails-tails)
      (error "Encountered an hn-tag-nest bump which wasn't a contour")
    #/expect (hypertee-uncontour dss tails-tails) (just _)
      (error "Encountered an hn-tag-nest bump which wasn't a contour of a contour")
    #/error "Encountered an hn-tag-nest bump value when converting an hn-expression to a list of Racket syntax objects")
  #/error "Encountered an unsupported bump value when converting an hn-expression to a list of Racket syntax objects"))

(define-for-syntax (hn-expr-2->s-expr-generator dss hn)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/expect (dim-successors-sys-dim-from-int dss 2) (just _)
    (error "Expected at least 2 successors to exist for the zero dimension")
  #/w- n-d (fn n #/just-value #/dim-successors-sys-dim-from-int dss n)
  #/expect (dim-sys-dim=? ds (hypernest-degree hn) (n-d 2)) #t
    (error "Expected an hn-expr of degree 2")
  #/w- dropped (hypernest-unfurl hn)
  #/w- process-tails
    (fn tails
      (hypertee-dv-map-all-degrees tails #/fn d tail
        (hn-expr-2->s-expr-generator dss tail)))
  #/mat dropped (hypernest-coil-hole _ data tails)
    (hypernest-furl ds #/hypernest-coil-hole (n-d 2) data
    #/process-tails tails)
  #/dissect dropped (hypernest-coil-bump _ data bump-degree tails)
  #/mat data (hn-tag-0-s-expr-stx stx)
    (expect (dim-sys-dim=0? ds bump-degree) #t
      (error "Encountered an hn-tag-0-s-expr-stx bump with a degree other than 0")
    #/hypernest-furl ds #/hypernest-coil-bump (n-d 2)
      (hn-tag-0-s-expr-stx #`(list '#,stx))
      (n-d 0)
    #/hn-expr-2->s-expr-generator dss tails)
  #/w- process-listlike
    (fn stx-example list-beginnings
      (expect (dim-sys-dim=? ds bump-degree (n-d 1)) #t
        (error "Encountered a list-like hn-tag-1-... bump with a degree other than 1")
      #/w- elems
        (hypernest-v-map-one-degree (n-d 0) tails #/fn tail #/trivial)
      #/dissect (hypernest-get-hole-zero tails) (just tail)
      #/hypernest-join-all-degrees
      #/hn-bracs-dss dss 2
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'list)
        
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'apply)
        
        (hnb-labeled 1 #/hypernest-append-zero ds (n-d 2)
        #/list-map list-beginnings #/fn list-beginning
          (hn-bracs-dss dss 2
            (hnb-open 0 #/hn-tag-0-s-expr-stx list-beginning)
          #/hnb-labeled 0 #/trivial))
        0
        
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'append)
        
        (hnb-labeled 1 #/hn-expr-2->s-expr-generator dss elems)
        0
        
        0
        
        0
        
        0
      #/hnb-labeled 0 #/hn-expr-2->s-expr-generator dss tail))
  #/mat data (hn-tag-1-list stx-example)
    (process-listlike stx-example #/list #'list)
  #/mat data (hn-tag-1-list* stx-example)
    (process-listlike stx-example #/list #'list*)
  #/mat data (hn-tag-1-vector stx-example)
    (process-listlike stx-example #/list #'vector)
  #/mat data (hn-tag-1-prefab key stx-example)
    (process-listlike stx-example
    #/list #'make-prefab-struct #`'#,key)
  #/mat data (hn-tag-nest)
    (expect (hypernest->maybe-hypertee tails) (just tails)
      (error "Encountered an hn-tag-nest bump with bumps in it")
    #/expect (hypertee-uncontour dss tails)
      (just #/list bracket-syntax tails-tails)
      (error "Encountered an hn-tag-nest bump which wasn't a contour")
    #/expect (hypertee-uncontour dss tails-tails) (just _)
      (error "Encountered an hn-tag-nest bump which wasn't a contour of a contour")
    #/hn-expr-2->s-expr-generator dss
    ; We concatenate everything inside this `hn-tag-nest`, *including*
    ; the bracket syntax, so that the bracket syntax is included in
    ; the quoted part of the result.
    #/hypernest-set-degree-and-join-all-degrees (n-d 2)
      (hypertee->hypernest tails))
  #/error "Encountered an unsupported bump value when making an hn-expression into code that generates it as an s-expression"))

(define-for-syntax (hn-expr-2->s-expr-stx-generator dss hn)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/expect (dim-successors-sys-dim-from-int dss 2) (just _)
    (error "Expected at least 2 successors to exist for the zero dimension")
  #/w- n-d (fn n #/just-value #/dim-successors-sys-dim-from-int dss n)
  #/expect (dim-sys-dim=? ds (hypernest-degree hn) (n-d 2)) #t
    (error "Expected an hn-expr of degree 2")
  #/w- dropped (hypernest-unfurl hn)
  #/w- process-tails
    (fn tails
      (hypertee-dv-map-all-degrees tails #/fn d tail
        (hn-expr-2->s-expr-stx-generator dss tail)))
  #/mat dropped (hypernest-coil-hole _ data tails)
    (hypernest-furl ds #/hypernest-coil-hole (n-d 2) data
    #/process-tails tails)
  #/dissect dropped (hypernest-coil-bump _ data bump-degree tails)
  #/mat data (hn-tag-0-s-expr-stx stx)
    (expect (dim-sys-dim=0? ds bump-degree) #t
      (error "Encountered an hn-tag-0-s-expr-stx bump with a degree other than 0")
    #/hypernest-furl ds #/hypernest-coil-bump (n-d 2)
      (hn-tag-0-s-expr-stx #`(list #'#,stx))
      (n-d 0)
    #/hn-expr-2->s-expr-stx-generator dss tails)
  #/w- process-listlike
    (fn stx-example list-beginnings
      (expect (dim-sys-dim=? ds bump-degree (n-d 1)) #t
        (error "Encountered a list-like hn-tag-1-... bump with a degree other than 1")
      #/w- elems
        (hypernest-v-map-one-degree (n-d 0) tails #/fn tail #/trivial)
      #/dissect (hypernest-get-hole-zero tails) (just tail)
      #/hypernest-join-all-degrees
      #/hn-bracs-dss dss 2
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'list)
        
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'datum->syntax)
        (hnb-open 0 #/hn-tag-0-s-expr-stx #`#'#,stx-example)
        
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'apply)
        
        (hnb-labeled 1 #/hypernest-append-zero ds (n-d 2)
        #/list-map list-beginnings #/fn list-beginning
          (hn-bracs-dss dss 2
            (hnb-open 0 #/hn-tag-0-s-expr-stx list-beginning)
          #/hnb-labeled 0 #/trivial))
        0
        
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'append)
        
        (hnb-labeled 1 #/hn-expr-2->s-expr-stx-generator dss elems)
        0
        
        0
        
        0
        
        0
        
        0
        
      #/hnb-labeled 0 #/hn-expr-2->s-expr-stx-generator dss tail))
  #/mat data (hn-tag-1-list stx-example)
    (process-listlike stx-example #/list #'list)
  #/mat data (hn-tag-1-list* stx-example)
    (process-listlike stx-example #/list #'list*)
  #/mat data (hn-tag-1-vector stx-example)
    (process-listlike stx-example #/list #'vector)
  #/mat data (hn-tag-1-prefab key stx-example)
    (process-listlike stx-example
    #/list #'make-prefab-struct #`'#,key)
  #/mat data (hn-tag-nest)
    (expect (hypernest->maybe-hypertee tails) (just tails)
      (error "Encountered an hn-tag-nest bump with bumps in it")
    #/expect (hypertee-uncontour dss tails)
      (just #/list bracket-syntax tails-tails)
      (error "Encountered an hn-tag-nest bump which wasn't a contour")
    #/expect (hypertee-uncontour dss tails-tails) (just _)
      (error "Encountered an hn-tag-nest bump which wasn't a contour of a contour")
    #/hn-expr-2->s-expr-stx-generator dss
    ; We concatenate everything inside this `hn-tag-nest`, *including*
    ; the bracket syntax, so that the bracket syntax is included in
    ; the quoted part of the result.
    #/hypernest-set-degree-and-join-all-degrees (n-d 2)
      (hypertee->hypernest tails))
  #/error "Encountered an unsupported bump value when making an hn-expression into code that generates it as a Racket syntax object"))

(define-syntax (my-quasiquote stx)
  (syntax-parse stx #/ (_ quotation)
  #/w- dss (nat-dim-successors-sys)
  #/w- ds (dim-successors-sys-dim-sys dss)
  #/expect (dim-successors-sys-dim-from-int dss 4) (just _)
    (error "Expected at least 4 successors to exist for the zero dimension")
  #/w- n-d (fn n #/just-value #/dim-successors-sys-dim-from-int dss n)
  #/w- quotation (s-expr-stx->hn-expr dss #'quotation)
  #/expect (hypernest-unfurl quotation)
    (hypernest-coil-bump overall-degree (hn-tag-nest) bump-degree
      bracket-and-quotation-and-tails)
    (error "Expected a quasiquotation to be of the form (my-quasiquote #/^< ...)")
  #/expect (dim-sys-dim=? ds bump-degree (n-d 4)) #t
    (error "Expected a quasiquotation to be of the form (my-quasiquote #/^< 2 ...)")
  #/expect (hypernest->maybe-hypertee bracket-and-quotation-and-tails)
    (just bracket-and-quotation-and-tails)
    (error "Encountered an hn-tag-nest bump with bumps in it")
  #/expect (hypertee-uncontour dss bracket-and-quotation-and-tails)
    (just #/list bracket quotation-and-tails)
    (error "Encountered an hn-tag-nest bump which wasn't a contour")
  #/expect (hypertee-uncontour dss quotation-and-tails)
    (just #/list quotation tails)
    (error "Encountered an hn-tag-nest bump which wasn't a contour of a contour")
  #/begin
    (hypertee-v-each-one-degree (n-d 0) tails #/fn tail
      ; TODO: See if there's a good way to differentiate these error
      ; messages.
      (expect (hypernest-unfurl tail)
        (hypernest-coil-hole d data tail-tails)
        (error "Encountered more than one degree-0-adjacent piece of data in the root of a quasiquotation")
      #/expect (dim-sys-dim=0? ds #/hypertee-degree tail-tails) #t
        (error "Encountered more than one degree-0-adjacent piece of data in the root of a quasiquotation")
      #/dissect data (trivial)
      #/void))
  #/dissect
    (hypernest-zip tails (hn-expr-2->s-expr-generator dss quotation)
    #/fn hole tail quotation-data
      (dissect quotation-data (trivial)
      #/dissect (dim-sys-dim=? ds (hypernest-degree tail) (n-d 1))
        #t
        tail))
    (just zipped)
  #/expect
    (hn-expr->s-expr-stx-list dss
      (hypernest-set-degree-and-join-all-degrees (n-d 1) zipped))
    (list result)
    (error "Encountered more than one s-expression in a quasiquotation")
  #/syntax-protect
    ; TODO: See if we should use `quasisyntax/loc` here so the error
    ; message refers to the place `my-quasiquote` is used.
    #`(w- spliced-root #,result
      #/expect spliced-root (list root)
        (raise-arguments-error 'my-quasiquote
          "spliced a value other than a singleton list into the root of a my-quasiquote"
          "spliced-root" spliced-root)
        root)))

; TODO: Define a corresponding `my-quasisyntax` based on
; `hn-expr-2->s-expr-stx-generator`.
