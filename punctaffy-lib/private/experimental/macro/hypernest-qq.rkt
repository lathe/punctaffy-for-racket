#lang parendown racket/base

; hypernest-qq.rkt
;
; A quasiquotation operator which allows for user-defined escape
; sequences which can generalize unquotation and nested
; quasiquotation.

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


(require #/for-syntax racket/base)

(require #/for-syntax #/only-in syntax/parse syntax-parse)

(require #/for-syntax #/only-in lathe-comforts
  dissect expect fn mat w-)
(require #/for-syntax #/only-in lathe-comforts/list
  list-foldr list-map)
(require #/for-syntax #/only-in lathe-comforts/maybe just)
(require #/for-syntax #/only-in lathe-comforts/trivial trivial)

(require #/for-syntax #/only-in punctaffy/hypersnippet/hypernest
  degree-and-brackets->hypernest hypernest-bind-one-degree
  hypernest-coil-bump hypernest-coil-hole hypernest-contour
  hypernest-degree hypernest-drop1 hypernest-dv-bind-all-degrees
  hypernest-get-hole-zero hypernest-join-all-degrees
  hypernest->maybe-hypertee hypernest-plus1 hypernest-promote
  hypernest-set-degree hypernest-v-map-one-degree hypernest-zip
  hypertee->hypernest)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hyperstack
  dim-successors-sys-dim-plus-int dim-successors-sys-dim-sys
  dim-sys-dim=? dim-sys-dim=0? dim-sys-dim-zero nat-dim-successors-sys
  successorless-dim-successors-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypertee
  hypertee-degree hypertee-dv-map-all-degrees hypertee-promote
  hypertee-set-degree-maybe hypertee-uncontour
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


(define-for-syntax (n-d-maybe dss dim-as-nat)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/dim-successors-sys-dim-plus-int dss (dim-sys-dim-zero ds)
    dim-as-nat))

(define-for-syntax (n-d dss dim-as-nat)
  (expect (n-d-maybe dss dim-as-nat) (just dim)
    (raise-arguments-error 'n-d
      "expected the given number of successors to exist for the zero dimension"
      "dss" dss
      "dim-as-nat" dim-as-nat)
    dim))

(define-for-syntax (n-hn dss degree . brackets)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/degree-and-brackets->hypernest ds (n-d dss degree)
  #/list-map brackets #/fn bracket
    (mat bracket (list 'open d data) (list 'open (n-d dss d) data)
    #/mat bracket (list d data) (list (n-d dss d) data)
      (n-d dss bracket))))

(define-for-syntax (n-hn-append0 dss degree hns)
  ; When we call this, the elements of `hns` are hypernests of degree
  ; `degree`, and their degree-0 holes have trivial values as
  ; contents. We return their degree-0 concatenation.
  (list-foldr hns (n-hn dss degree #/list 0 #/trivial) #/fn hn tail
    (hypernest-bind-one-degree (n-d dss 0) hn #/fn hole data
      (dissect data (trivial)
        tail))))


(define-for-syntax (hn-expr->s-expr-stx-list dss hn)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/expect (dim-sys-dim=? ds (hypernest-degree hn) (n-d dss 1)) #t
    (raise-arguments-error 'hn-expr->s-expr-stx-list
      "expected an hn-expr of degree 1"
      "hn" hn)
  #/w- dropped (hypernest-drop1 hn)
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
      (expect (dim-sys-dim=? ds bump-degree (n-d dss 1)) #t
        (error "Encountered a list-like hn-tag-1-... bump with a degree other than 1")
      #/w- elems
        (hypernest-v-map-one-degree (n-d dss 0) tails #/fn tail
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
  #/expect (dim-sys-dim=? ds (hypernest-degree hn) (n-d dss 2)) #t
    (error "Expected an hn-expr of degree 2")
  #/w- dropped (hypernest-drop1 hn)
  #/w- process-tails
    (fn tails
      (hypertee-dv-map-all-degrees tails #/fn d tail
        (hn-expr-2->s-expr-generator dss tail)))
  #/mat dropped (hypernest-coil-hole _ data tails)
    (hypernest-plus1 ds #/hypernest-coil-hole (n-d dss 2) data
    #/process-tails tails)
  #/dissect dropped (hypernest-coil-bump _ data bump-degree tails)
  #/mat data (hn-tag-0-s-expr-stx stx)
    (expect (dim-sys-dim=0? ds bump-degree) #t
      (error "Encountered an hn-tag-0-s-expr-stx bump with a degree other than 0")
    #/hypernest-plus1 ds #/hypernest-coil-bump (n-d dss 2)
      (hn-tag-0-s-expr-stx #`(list '#,stx))
      (n-d dss 0)
    #/hn-expr-2->s-expr-generator dss tails)
  #/w- process-listlike
    (fn stx-example list-beginnings
      (expect (dim-sys-dim=? ds bump-degree (n-d dss 1)) #t
        (error "Encountered a list-like hn-tag-1-... bump with a degree other than 1")
      #/w- elems
        (hypernest-v-map-one-degree (n-d dss 0) tails #/fn tail
          (trivial))
      #/dissect (hypernest-get-hole-zero tails) (just tail)
      #/hypernest-join-all-degrees
      #/n-hn dss 2
        (list 'open 1 #/hn-tag-1-list stx-example)
        
        (list 'open 0 #/hn-tag-0-s-expr-stx #'list)
        
        (list 'open 1 #/hn-tag-1-list stx-example)
        
        (list 'open 0 #/hn-tag-0-s-expr-stx #'apply)
        
        (list 1 #/n-hn-append0 dss 2
        #/list-map list-beginnings #/fn list-beginning
          (n-hn dss 2
            (list 'open 0 #/hn-tag-0-s-expr-stx list-beginning)
          #/list 0 #/trivial))
        0
        
        (list 'open 1 #/hn-tag-1-list stx-example)
        
        (list 'open 0 #/hn-tag-0-s-expr-stx #'append)
        
        (list 1 #/hn-expr-2->s-expr-generator dss elems)
        0
        
        0
        
        0
        
        0
      #/list 0 #/hn-expr-2->s-expr-generator dss tail))
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
    #/hypernest-set-degree (n-d dss 2)
    #/hypernest-dv-bind-all-degrees (hypertee->hypernest tails)
    #/fn d tail
      (hypernest-promote (n-d dss 4) tail))
  #/error "Encountered an unsupported bump value when making an hn-expression into code that generates it as an s-expression"))

(define-for-syntax (hn-expr-2->s-expr-stx-generator dss hn)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/expect (dim-sys-dim=? ds (hypernest-degree hn) (n-d dss 2)) #t
    (error "Expected an hn-expr of degree 2")
  #/w- dropped (hypernest-drop1 hn)
  #/w- process-tails
    (fn tails
      (hypertee-dv-map-all-degrees tails #/fn d tail
        (hn-expr-2->s-expr-stx-generator dss tail)))
  #/mat dropped (hypernest-coil-hole _ data tails)
    (hypernest-plus1 ds #/hypernest-coil-hole (n-d dss 2) data
    #/process-tails tails)
  #/dissect dropped (hypernest-coil-bump _ data bump-degree tails)
  #/mat data (hn-tag-0-s-expr-stx stx)
    (expect (dim-sys-dim=0? ds bump-degree) #t
      (error "Encountered an hn-tag-0-s-expr-stx bump with a degree other than 0")
    #/hypernest-plus1 ds #/hypernest-coil-bump (n-d dss 2)
      (hn-tag-0-s-expr-stx #`(list #'#,stx))
      (n-d dss 0)
    #/hn-expr-2->s-expr-stx-generator dss tails)
  #/w- process-listlike
    (fn stx-example list-beginnings
      (expect (dim-sys-dim=? ds bump-degree (n-d dss 1)) #t
        (error "Encountered a list-like hn-tag-1-... bump with a degree other than 1")
      #/w- elems
        (hypernest-v-map-one-degree (n-d dss 0) tails #/fn tail
          (trivial))
      #/dissect (hypernest-get-hole-zero tails) (just tail)
      #/hypernest-join-all-degrees
      #/n-hn dss 2
        (list 'open 1 #/hn-tag-1-list stx-example)
        
        (list 'open 0 #/hn-tag-0-s-expr-stx #'list)
        
        (list 'open 1 #/hn-tag-1-list stx-example)
        
        (list 'open 0 #/hn-tag-0-s-expr-stx #'datum->syntax)
        (list 'open 0 #/hn-tag-0-s-expr-stx #`#'#,stx-example)
        
        (list 'open 1 #/hn-tag-1-list stx-example)
        
        (list 'open 0 #/hn-tag-0-s-expr-stx #'apply)
        
        (list 1 #/n-hn-append0 dss 2
        #/list-map list-beginnings #/fn list-beginning
          (n-hn dss 2
            (list 'open 0 #/hn-tag-0-s-expr-stx list-beginning)
          #/list 0 #/trivial))
        0
        
        (list 'open 1 #/hn-tag-1-list stx-example)
        
        (list 'open 0 #/hn-tag-0-s-expr-stx #'append)
        
        (list 1 #/hn-expr-2->s-expr-stx-generator dss elems)
        0
        
        0
        
        0
        
        0
        
        0
        
      #/list 0 #/hn-expr-2->s-expr-stx-generator dss tail))
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
    #/hypernest-set-degree (n-d dss 2)
    #/hypernest-dv-bind-all-degrees (hypertee->hypernest tails)
    #/fn d tail
      (hypernest-promote (n-d dss 4) tail))
  #/error "Encountered an unsupported bump value when making an hn-expression into code that generates it as a Racket syntax object"))

(define-syntax (my-quasiquote stx)
  (syntax-parse stx #/ (_ quotation)
  #/w- dss (nat-dim-successors-sys)
  #/w- ds (dim-successors-sys-dim-sys dss)
  #/w- quotation (s-expr-stx->hn-expr dss #'quotation)
  #/expect (hypernest-drop1 quotation)
    (hypernest-coil-bump overall-degree (hn-tag-nest) bump-degree
      bracket-and-quotation-and-tails)
    (error "Expected a quasiquotation to be of the form (my-quasiquote #/^< ...)")
  #/expect (dim-sys-dim=? ds bump-degree (n-d dss 4)) #t
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
    (hypertee-v-each-one-degree (n-d dss 0) tails #/fn tail
      ; TODO: See if there's a good way to differentiate these error
      ; messages.
      (expect (hypernest-drop1 tail)
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
      #/dissect (dim-sys-dim=? ds (hypernest-degree tail) (n-d dss 1))
        #t
      #/hypernest-promote (n-d dss 2)
        tail))
    (just zipped)
  #/expect
    (hn-expr->s-expr-stx-list dss
      (hypernest-set-degree (n-d dss 1)
      #/hypernest-join-all-degrees zipped))
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
