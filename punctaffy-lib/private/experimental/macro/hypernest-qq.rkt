#lang parendown racket/base

; hypernest-qq.rkt
;
; A quasiquotation operator which allows for user-defined escape
; sequences which can generalize unquotation and nested
; quasiquotation.

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

(require #/for-syntax #/only-in racket/math natural?)
(require #/for-syntax #/only-in syntax/parse syntax-parse)

(require #/for-syntax #/only-in lathe-comforts
  dissect dissectfn expect fn mat w-)
(require #/for-syntax #/only-in lathe-comforts/list list-map)
(require #/for-syntax #/only-in lathe-comforts/maybe
  just just-value maybe-bind maybe-if)
(require #/for-syntax #/only-in lathe-comforts/trivial trivial)

(require #/for-syntax #/only-in punctaffy/hypersnippet/dim
  dim-successors-sys-dim-from-int dim-successors-sys-dim=plus-int?
  dim-successors-sys-dim-sys dim-sys-dim=? dim-sys-dim=0?
  nat-dim-successors-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypernest-2
  hnb-labeled hn-bracs hnb-open hnb-unlabeled hypernest-coil-bump
  hypernest-coil-hole hypernest-from-brackets hypernest-furl
  hypernest-get-hole-zero-maybe hypernest-join-list-and-tail-along-0
  hypernest-snippet-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypertee-2
  hypertee-snippet-format-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/snippet
  snippet-sys-shape->snippet snippet-sys-shape-snippet-sys
  snippet-sys-snippet-bind snippet-sys-snippet-degree
  snippet-sys-snippet-each snippet-sys-snippet-join
  snippet-sys-snippet-map snippet-sys-snippet-map-selective
  snippet-sys-snippet->maybe-shape
  snippet-sys-snippet-select-if-degree
  snippet-sys-snippet-set-degree-maybe snippet-sys-snippet-undone
  snippet-sys-snippet-zip-map)
(require #/for-syntax #/only-in
  punctaffy/private/experimental/macro/hypernest-macro
  hn-tag-0-s-expr-stx hn-tag-1-list hn-tag-1-list* hn-tag-1-prefab
  hn-tag-1-vector hn-tag-nest s-expr-stx->hn-expr)

; NOTE DEBUGGABILITY: These are here for debugging.
(require #/for-syntax #/only-in racket/syntax syntax-local-eval)
(define-for-syntax debugging-with-prints #f)
(define-syntax (ifc stx)
  (syntax-protect
  #/syntax-case stx () #/ (_ condition then else)
  #/if (syntax-local-eval #'condition)
    #'then
    #'else))

; NOTE DEBUGGABILITY: These are here for debugging, as are all the
; `dlog` and `dlogr` calls throughout this file.
;
; NOTE DEBUGGABILITY: We could also do
; `(require lathe-debugging/placebo)` instead of defining this
; submodule, but that would introduce a package dependency on
; `lathe-debugging`, which at this point still isn't a published
; package.
;
(module private/lathe-debugging/placebo racket/base
  (provide #/all-defined-out)
  (define-syntax-rule (dlog value ... body) body)
  (define-syntax-rule (dlogr value ... body) body))
(ifc debugging-with-prints
  (require #/for-syntax lathe-debugging)
  (require #/for-syntax 'private/lathe-debugging/placebo))

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


(define-for-syntax (snippet-sys-snippet-uncontour dss ss snippet)
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/maybe-bind (snippet-sys-snippet-undone ss snippet)
  #/dissectfn (list original-degree hole data)
  #/w- d (snippet-sys-snippet-degree shape-ss hole)
  #/maybe-if
    (dim-successors-sys-dim=plus-int? dss original-degree d 1)
    (fn #/list hole data)))

(define-for-syntax (hypernest-join-0 ds n-d d elems)
  (hypernest-join-list-and-tail-along-0 ds elems
    (hn-bracs ds (n-d d) #/hnb-labeled (n-d 0) #/trivial)))

(define-for-syntax (hn-bracs-dss dss degree . brackets)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/w- n-d
    (fn n
      (expect (natural? n) #t n
      #/mat (dim-successors-sys-dim-from-int dss n) (just d) d
      #/raise-arguments-error 'hn-bracs-dss
        "expected the given number of successors to exist for the zero dimension"
        "n" n
        "dss" dss))
  #/hypernest-from-brackets ds (n-d degree)
    (list-map brackets #/fn bracket
      (mat bracket (hnb-open d data) (hnb-open (n-d d) data)
      #/mat bracket (hnb-labeled d data) (hnb-labeled (n-d d) data)
      #/mat bracket (hnb-unlabeled d) (hnb-unlabeled (n-d d))
      #/hnb-unlabeled (n-d bracket)))))


(define-for-syntax (hn-expr->s-expr-stx-list dss hn)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/expect (dim-successors-sys-dim-from-int dss 1) (just _)
    (error "Expected at least 1 successor to exist for the zero dimension")
  #/w- n-d (fn n #/just-value #/dim-successors-sys-dim-from-int dss n)
  #/expect
    (dim-sys-dim=? ds (snippet-sys-snippet-degree ss hn) (n-d 1))
    #t
    (raise-arguments-error 'hn-expr->s-expr-stx-list
      "expected an hn-expr of degree 1"
      "hn" hn)
  #/dissect hn (hypernest-furl _ dropped)
  #/mat dropped (hypernest-coil-hole _ _ data tails)
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
        (snippet-sys-snippet-map-selective ss
          (snippet-sys-snippet-select-if-degree ss tails #/fn d
            (dim-sys-dim=0? ds d))
        #/fn hole tail
          (trivial))
      #/dissect (hypernest-get-hole-zero-maybe tails) (just tail)
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
    (expect (snippet-sys-snippet->maybe-shape ss tails) (just tails)
      (error "Encountered an hn-tag-nest bump with bumps in it")
    #/expect (snippet-sys-snippet-uncontour dss shape-ss tails)
      (just #/list tails-tails bracket-syntax)
      (error "Encountered an hn-tag-nest bump which wasn't a contour")
    #/expect (snippet-sys-snippet-uncontour dss shape-ss tails-tails)
      (just _)
      (error "Encountered an hn-tag-nest bump which wasn't a contour of a contour")
    #/error "Encountered an hn-tag-nest bump value when converting an hn-expression to a list of Racket syntax objects")
  #/error "Encountered an unsupported bump value when converting an hn-expression to a list of Racket syntax objects"))

(define-for-syntax (hn-expr-2->s-expr-generator dss hn)
  (dlog 'hqq-h1
  #/w- ds (dim-successors-sys-dim-sys dss)
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/expect (dim-successors-sys-dim-from-int dss 2) (just _)
    (error "Expected at least 2 successors to exist for the zero dimension")
  #/w- n-d (fn n #/just-value #/dim-successors-sys-dim-from-int dss n)
  #/expect
    (dim-sys-dim=? ds (snippet-sys-snippet-degree ss hn) (n-d 2))
    #t
    (error "Expected an hn-expr of degree 2")
  #/dlog 'hqq-h2  ; (hypernest? hn) hn
  #/dissect hn (hypernest-furl _ dropped)
  #/dlog 'hqq-h3
  #/w- process-tails
    (fn tails
      (snippet-sys-snippet-map shape-ss tails #/fn d tail
        (hn-expr-2->s-expr-generator dss tail)))
  #/mat dropped (hypernest-coil-hole _ tails-shape data tails)
    (hypernest-furl ds #/hypernest-coil-hole (n-d 2) tails-shape data
    #/process-tails tails)
  #/dlog 'hqq-h4
  #/dissect dropped (hypernest-coil-bump _ data bump-degree tails)
  #/dlog 'hqq-h5
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
      #/dlog 'hqq-h5.1
      #/w- elems
        (snippet-sys-snippet-map-selective ss
          (snippet-sys-snippet-select-if-degree ss tails #/fn d
            (dim-sys-dim=0? ds d))
        #/fn hole tail
          (trivial))
      #/dlog 'hqq-h5.2 tails
      #/dissect (hypernest-get-hole-zero-maybe tails) (just tail)
      #/dlog 'hqq-h5.3
      #/snippet-sys-snippet-join ss
      #/dlog 'hqq-h5.4
      #/hn-bracs-dss dss 2
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'list)
        
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'apply)
        
        (hnb-labeled 1 #/hypernest-join-0 ds n-d 2
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
    (expect (snippet-sys-snippet->maybe-shape ss tails)
      (just tails-shape)
      (error "Encountered an hn-tag-nest bump with bumps in it")
    #/expect (snippet-sys-snippet-uncontour dss shape-ss tails-shape)
      (just #/list tails-tails bracket-syntax)
      (error "Encountered an hn-tag-nest bump which wasn't a contour")
    #/expect (snippet-sys-snippet-uncontour dss shape-ss tails-tails)
      (just _)
      (error "Encountered an hn-tag-nest bump which wasn't a contour of a contour")
    #/hn-expr-2->s-expr-generator dss
    ; We concatenate everything inside this `hn-tag-nest`, *including*
    ; the bracket syntax, so that the bracket syntax is included in
    ; the quoted part of the result.
    #/dlog 'hqq-h6
    #/w- joined
      (snippet-sys-snippet-bind ss tails #/fn hole tail
        (dissect
          (snippet-sys-snippet-set-degree-maybe ss (n-d 4) tail)
          (just tail)
          tail))
    #/dlog 'hqq-h7
    #/dissect (snippet-sys-snippet-set-degree-maybe ss (n-d 2) joined)
      (just tails)
      tails)
  #/error "Encountered an unsupported bump value when making an hn-expression into code that generates it as an s-expression"))

(define-for-syntax (hn-expr-2->s-expr-stx-generator dss hn)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/expect (dim-successors-sys-dim-from-int dss 2) (just _)
    (error "Expected at least 2 successors to exist for the zero dimension")
  #/w- n-d (fn n #/just-value #/dim-successors-sys-dim-from-int dss n)
  #/expect
    (dim-sys-dim=? ds (snippet-sys-snippet-degree ss hn) (n-d 2))
    #t
    (error "Expected an hn-expr of degree 2")
  #/dissect hn (hypernest-furl _ dropped)
  #/w- process-tails
    (fn tails
      (snippet-sys-snippet-map shape-ss tails #/fn d tail
        (hn-expr-2->s-expr-stx-generator dss tail)))
  #/mat dropped (hypernest-coil-hole _ tails-shape data tails)
    (hypernest-furl ds #/hypernest-coil-hole (n-d 2) tails-shape data
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
        (snippet-sys-snippet-map-selective ss
          (snippet-sys-snippet-select-if-degree ss tails #/fn d
            (dim-sys-dim=0? ds d))
        #/fn hole tail
          (trivial))
      #/dissect (hypernest-get-hole-zero-maybe tails) (just tail)
      #/snippet-sys-snippet-join ss
      #/hn-bracs-dss dss 2
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'list)
        
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'datum->syntax)
        (hnb-open 0 #/hn-tag-0-s-expr-stx #`#'#,stx-example)
        
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'apply)
        
        (hnb-labeled 1 #/hypernest-join-0 ds n-d 2
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
    (expect (snippet-sys-snippet->maybe-shape ss tails) (just tails)
      (error "Encountered an hn-tag-nest bump with bumps in it")
    #/expect (snippet-sys-snippet-uncontour dss shape-ss tails)
      (just #/list tails-tails bracket-syntax)
      (error "Encountered an hn-tag-nest bump which wasn't a contour")
    #/expect (snippet-sys-snippet-uncontour dss shape-ss tails-tails)
      (just _)
      (error "Encountered an hn-tag-nest bump which wasn't a contour of a contour")
    #/hn-expr-2->s-expr-stx-generator dss
    ; We concatenate everything inside this `hn-tag-nest`, *including*
    ; the bracket syntax, so that the bracket syntax is included in
    ; the quoted part of the result.
    #/dissect
      (snippet-sys-snippet-set-degree-maybe ss (n-d 2)
        (snippet-sys-shape->snippet ss tails))
      (just tails)
    #/snippet-sys-snippet-join ss tails)
  #/error "Encountered an unsupported bump value when making an hn-expression into code that generates it as a Racket syntax object"))

(define-syntax (my-quasiquote stx)
  (syntax-parse stx #/ (_ quotation)
  #/dlog 'hqq-a1
  #/w- dss (nat-dim-successors-sys)
  #/w- ds (dim-successors-sys-dim-sys dss)
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/expect (dim-successors-sys-dim-from-int dss 4) (just _)
    (error "Expected at least 4 successors to exist for the zero dimension")
  #/w- n-d (fn n #/just-value #/dim-successors-sys-dim-from-int dss n)
  #/dlog 'hqq-a1.1
  #/w- quotation (s-expr-stx->hn-expr ds n-d #'quotation)
  #/dlog 'hqq-a1.2
  #/expect quotation
    (hypernest-furl _
    #/hypernest-coil-bump overall-degree (hn-tag-nest) bump-degree
      bracket-and-quotation-and-tails)
    (error "Expected a quasiquotation to be of the form (my-quasiquote #/^< ...)")
  #/dlog 'hqq-a2
  #/expect (dim-sys-dim=? ds bump-degree (n-d 4)) #t
    (error "Expected a quasiquotation to be of the form (my-quasiquote #/^< 2 ...)")
  #/expect
    (snippet-sys-snippet->maybe-shape ss
      bracket-and-quotation-and-tails)
    (just bracket-and-quotation-and-tails)
    (error "Encountered an hn-tag-nest bump with bumps in it")
  #/expect
    (snippet-sys-snippet-uncontour dss shape-ss
      bracket-and-quotation-and-tails)
    (just #/list quotation-and-tails bracket)
    (error "Encountered an hn-tag-nest bump which wasn't a contour")
  #/dlog 'hqq-a3
  #/expect
    (snippet-sys-snippet-uncontour dss shape-ss quotation-and-tails)
    (just #/list tails quotation)
    (error "Encountered an hn-tag-nest bump which wasn't a contour of a contour")
  #/begin
    (snippet-sys-snippet-each shape-ss tails #/fn hole tail
      (w- d (snippet-sys-snippet-degree shape-ss hole)
      #/expect (dim-sys-dim=0? ds d) #t
        (void)
      ; TODO: See if there's a good way to differentiate these error
      ; messages.
      #/expect tail
        (hypernest-furl _ #/hypernest-coil-hole _ _ data tail-tails)
        (error "Encountered more than one degree-0-adjacent piece of data in the root of a quasiquotation")
      #/expect
        (dim-sys-dim=0? ds
          (snippet-sys-snippet-degree shape-ss tail-tails))
        #t
        (error "Encountered more than one degree-0-adjacent piece of data in the root of a quasiquotation")
      #/dissect data (trivial)
      #/void))
  #/dlog 'hqq-a4
  #/dissect
    (dlog 'hqq-a4.1
    #/snippet-sys-snippet-zip-map ss tails
      (dlog 'hqq-a4.1.1 #/hn-expr-2->s-expr-generator dss quotation)
    #/fn hole tail quotation-data
      (dissect quotation-data (trivial)
      #/dissect
        (dim-sys-dim=? ds (n-d 1)
          (snippet-sys-snippet-degree ss tail))
        #t
      #/dissect (snippet-sys-snippet-set-degree-maybe ss (n-d 2) tail)
        (just tail)
      #/just tail))
    (just zipped)
  #/dlog 'hqq-a4.2
  #/w- joined (snippet-sys-snippet-join ss zipped)
  #/expect
    (dlog 'hqq-a4.3
    #/hn-expr->s-expr-stx-list dss
      (dissect
        (dlog 'hqq-a4.4
        #/snippet-sys-snippet-set-degree-maybe ss (n-d 1) joined)
        (just joined)
      #/dlog 'hqq-a4.5
        joined))
    (list result)
    (error "Encountered more than one s-expression in a quasiquotation")
  #/dlog 'hqq-a5
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
