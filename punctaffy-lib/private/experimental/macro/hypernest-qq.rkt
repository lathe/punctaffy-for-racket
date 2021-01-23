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

(require #/for-syntax #/only-in syntax/parse syntax-parse)

(require #/for-syntax #/only-in lathe-comforts
  dissect expect fn mat w-)
(require #/for-syntax #/only-in lathe-comforts/list list-map)
(require #/for-syntax #/only-in lathe-comforts/maybe just just-value)
(require #/for-syntax #/only-in lathe-comforts/trivial trivial)

(require #/for-syntax #/only-in punctaffy/hypersnippet/dim
  dim-sys-dim=? dim-sys-dim=0? dim-sys-morphism-sys-morph-dim
  extended-with-top-dim-infinite extended-with-top-dim-sys
  extend-with-top-dim-sys-morphism-sys nat-dim-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypernest
  hnb-labeled hnb-open hnb-unlabeled hypernest-coil-bump
  hypernest-coil-hole hypernest-from-brackets hypernest-furl
  hypernest-get-hole-zero-maybe hypernest-join-list-and-tail-along-0
  hypernest-shape hypernest-snippet-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/hypertee
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


; In this file, the syntax we define for quasiquotation looks
; something like this, using operators ^< and ^> that signify
; higher-dimensional opening brackets and closing brackets:
;
;   (my-quasiquote #/^< 2
;     (a b
;       (my-quasiquote #/^< 2
;         (c d
;           (^> 1 #/list
;             (e f
;               (^> 1 #/list
;                 (+ 4 5))))))))
;
; The ^< and ^> syntaxes are defined in and provided from
; hypernest-macro.rkt. (TODO: Ideally, we will make these look as
; much like language builtins as reasonably possible. In particular,
; `(require punctaffy)` should get them.) Like parentheses, this
; higher-dimensional bracket notation is something that most programs
; won't need to extend or parse in custom ways.
;
; The `my-quasiquote` syntax is defined without directly using all the
; infrastructure underlying ^< and ^>. It's defined only in terms of
; `s-expr-stx->hn-expr`, the structs of the hn-expression format, and
; the hypernest and hypertee utilities.
;
; Users of `my-quasiquote` will only need to import that operation and
; ^< and ^> but will not usually need to understand them any more
; deeply than the traditional `quasiquote` and `unquote`. Even if they
; define another quasiquotation syntax, it will interoperate
; seamlessly with `my-quasiquote` if it makes similar use of
; `s-expr-stx->hn-expr`.
;
; If people define custom parentheses very often, quotation operators
; will typically fail to preserve their meaning since code generated
; for different lexical contexts could have different sets of custom
; parentheses available. That's why we focus on on a minimalistic set
; of notations like ^< and ^> that can express the full range of
; hn-expressions. These provide the higher-dimensional structural
; encoding that other syntaxes can use as a common language rather
; than reinventing their structural notations every time.


(define (datum->syntax-with-everything stx-example datum)
  (w- ctxt stx-example
  #/w- srcloc stx-example
  #/w- prop stx-example
  #/datum->syntax ctxt datum srcloc prop))

(define-for-syntax (hn-bracs-n-d ds n-d degree . brackets)
  (w- n-d (fn d #/dim-sys-morphism-sys-morph-dim n-d d)
  #/hypernest-from-brackets ds (n-d degree)
    (list-map brackets #/fn bracket
      (mat bracket (hnb-open d data) (hnb-open (n-d d) data)
      #/mat bracket (hnb-labeled d data) (hnb-labeled (n-d d) data)
      #/mat bracket (hnb-unlabeled d) (hnb-unlabeled (n-d d))
      #/hnb-unlabeled (n-d bracket)))))

(define-for-syntax (hypernest-join-0 ds n-d d elems)
  (hypernest-join-list-and-tail-along-0 ds elems
    (hn-bracs-n-d ds n-d d #/hnb-labeled 0 #/trivial)))


(define-for-syntax en-ds (extended-with-top-dim-sys #/nat-dim-sys))
(define-for-syntax en-n-d
  (extend-with-top-dim-sys-morphism-sys #/nat-dim-sys))


(define-for-syntax (hn-expr->s-expr-stx-list hn)
  (w- ds en-ds
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/w- n-d en-n-d
  #/expect
    (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 1)
      (snippet-sys-snippet-degree ss hn))
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
    #/cons stx #/hn-expr->s-expr-stx-list tails)
  #/w- process-listlike
    (fn stx-example list->whatever
      (expect
        (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 1)
          bump-degree)
        #t
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
          (list->whatever #/hn-expr->s-expr-stx-list elems))
        (hn-expr->s-expr-stx-list tail)))
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
    (expect
      (snippet-sys-snippet-undone shape-ss #/hypernest-shape ss tails)
      (just undone)
      (error "Encountered an hn-tag-nest bump whose interior wasn't shaped like a snippet system identity element")
    #/error "Encountered an hn-tag-nest bump value when converting an hn-expression to a list of Racket syntax objects")
  #/error "Encountered an unsupported bump value when converting an hn-expression to a list of Racket syntax objects"))

(define-for-syntax
  (hn-expr-2->generator quote-expr datum->result-id err-phrase hn)
  (dlog 'hqq-h1
  #/w- ds en-ds
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/w- n-d en-n-d
  #/w- recur
    (fn hn
      (hn-expr-2->generator
        quote-expr datum->result-id err-phrase hn))
  #/expect
    (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 2)
      (snippet-sys-snippet-degree ss hn))
    #t
    (error "Expected an hn-expr of degree 2")
  #/dlog 'hqq-h2  ; (hypernest? hn) hn
  #/dissect hn (hypernest-furl _ dropped)
  #/dlog 'hqq-h3
  #/w- process-tails
    (fn tails
      (snippet-sys-snippet-map shape-ss tails #/fn d tail
        (recur tail)))
  #/mat dropped (hypernest-coil-hole _ tails-shape data tails)
    (hypernest-furl ds #/hypernest-coil-hole
      (dim-sys-morphism-sys-morph-dim n-d 2)
      tails-shape
      data
      (process-tails tails))
  #/dlog 'hqq-h4
  #/dissect dropped (hypernest-coil-bump _ data bump-degree tails)
  #/dlog 'hqq-h5
  #/mat data (hn-tag-0-s-expr-stx stx)
    (expect (dim-sys-dim=0? ds bump-degree) #t
      (error "Encountered an hn-tag-0-s-expr-stx bump with a degree other than 0")
    #/hypernest-furl ds #/hypernest-coil-bump
      (dim-sys-morphism-sys-morph-dim n-d 2)
      (hn-tag-0-s-expr-stx #`(list #,(quote-expr stx)))
      (dim-sys-morphism-sys-morph-dim n-d 0)
      (recur tails))
  #/w- process-listlike
    (fn stx-example list-beginnings
      (expect
        (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 1)
          bump-degree)
        #t
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
      #/hn-bracs-n-d ds n-d 2
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'list)
        
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx datum->result-id)
        (hnb-open 0 #/hn-tag-0-s-expr-stx stx-example)
        
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'apply)
        
        (hnb-labeled 1 #/hypernest-join-0 ds n-d 2
        #/list-map list-beginnings #/fn list-beginning
          (hn-bracs-n-d ds n-d 2
            (hnb-open 0 #/hn-tag-0-s-expr-stx list-beginning)
          #/hnb-labeled 0 #/trivial))
        0
        
        (hnb-open 1 #/hn-tag-1-list stx-example)
        
        (hnb-open 0 #/hn-tag-0-s-expr-stx #'append)
        
        (hnb-labeled 1 #/recur elems)
        0
        
        0
        
        0
        
        0
        
        0
        
        (hnb-labeled 0 #/recur tail)))
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
    (expect
      (snippet-sys-snippet-undone shape-ss #/hypernest-shape ss tails)
      (just undone)
      (error "Encountered an hn-tag-nest bump whose interior wasn't shaped like a snippet system identity element")
    #/recur
    ; We concatenate everything inside this `hn-tag-nest`, *including*
    ; the bracket syntax, so that the bracket syntax is included in
    ; the quoted part of the result.
    #/dlog 'hqq-h6
    #/w- joined
      (snippet-sys-snippet-bind ss tails #/fn hole tail
        (dissect
          (snippet-sys-snippet-set-degree-maybe ss
            (extended-with-top-dim-infinite)
            tail)
          (just tail)
          tail))
    #/dlog 'hqq-h7
    #/dissect
      (snippet-sys-snippet-set-degree-maybe ss
        (dim-sys-morphism-sys-morph-dim n-d 2)
        joined)
      (just tails)
      tails)
  #/error #/format "Encountered an unsupported bump value when making an hn-expression into code that generates it as ~a"
    err-phrase))

(define-for-syntax
  (helper-for-quasiquote
    hn-expr-2->result-generator
    err-phrase-s-expression
    err-phrase-quasiquotation
    err-name
    quotation)
  (dlog 'hqq-a1
  #/w- ds en-ds
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/w- n-d en-n-d
  #/dlog 'hqq-a1.1
  #/w- quotation (s-expr-stx->hn-expr quotation)
  #/dlog 'hqq-a1.2
  #/expect quotation
    (hypernest-furl _ #/hypernest-coil-bump
      overall-degree
      (hn-tag-nest)
      (extended-with-top-dim-infinite)
      bracket-and-quotation-and-tails)
    (error #/format "Expected ~a to be of the form (~s #/^< ...)"
      err-phrase-quasiquotation
      err-name)
  #/dlog 'hqq-a2
  #/dissect
    (snippet-sys-snippet-undone shape-ss
      (hypernest-shape ss bracket-and-quotation-and-tails))
    (just #/list (extended-with-top-dim-infinite) tails quotation)
  #/w- represented-bump-degree
    (snippet-sys-snippet-degree shape-ss tails)
  #/expect
    (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 2)
      represented-bump-degree)
    #t
    (error #/format "Expected ~a to be of the form (~s #/^< 2 ...)"
      err-phrase-quasiquotation
      err-name)
  #/dlog 'hqq-a3
  #/begin
    (snippet-sys-snippet-each shape-ss tails #/fn hole tail
      (w- d (snippet-sys-snippet-degree shape-ss hole)
      #/expect (dim-sys-dim=0? ds d) #t
        (void)
      ; TODO: See if there's a good way to differentiate these error
      ; messages.
      #/expect tail
        (hypernest-furl _ #/hypernest-coil-hole _ _ data tail-tails)
        (error #/format "Encountered more than one degree-0-adjacent piece of data in the root of ~a"
          err-phrase-quasiquotation)
      #/expect
        (dim-sys-dim=0? ds
          (snippet-sys-snippet-degree shape-ss tail-tails))
        #t
        (error #/format "Encountered more than one degree-0-adjacent piece of data in the root of ~a"
          err-phrase-quasiquotation)
      #/dissect data (trivial)
      #/void))
  #/dlog 'hqq-a4
  #/dissect
    (dlog 'hqq-a4.1
    #/snippet-sys-snippet-zip-map ss tails
      (dlog 'hqq-a4.1.1 #/hn-expr-2->result-generator quotation)
    #/fn hole tail quotation-data
      (dissect quotation-data (trivial)
      #/dissect
        (dim-sys-dim=? ds (dim-sys-morphism-sys-morph-dim n-d 1)
          (snippet-sys-snippet-degree ss tail))
        #t
      #/dissect
        (snippet-sys-snippet-set-degree-maybe ss
          (dim-sys-morphism-sys-morph-dim n-d 2)
          tail)
        (just tail)
      #/just tail))
    (just zipped)
  #/dlog 'hqq-a4.2
  #/w- joined (snippet-sys-snippet-join ss zipped)
  #/expect
    (dlog 'hqq-a4.3
    #/hn-expr->s-expr-stx-list
      (dissect
        (dlog 'hqq-a4.4
        #/snippet-sys-snippet-set-degree-maybe ss
          (dim-sys-morphism-sys-morph-dim n-d 1)
          joined)
        (just joined)
      #/dlog 'hqq-a4.5
        joined))
    (list result)
    (error #/format "Encountered more than one ~a in ~a"
      err-phrase-s-expression
      err-phrase-quasiquotation)
  #/dlog 'hqq-a5
  #/syntax-protect
    ; TODO: See if we should use `quasisyntax/loc` here so the error
    ; message refers to the place `my-quasiquote` is used.
    #`(w- spliced-root #,result
      #/expect spliced-root (list root)
        (raise-arguments-error '#,err-name
          #,(format "spliced a value other than a singleton list into the root of a ~s"
              err-name)
          "spliced-root" spliced-root)
        root)))


(define-syntax-rule (datum->datum stx-example datum)
  datum)

(define-syntax (my-quasiquote stx)
  (syntax-parse stx #/ (_ quotation)
  #/helper-for-quasiquote
    (fn hn
      (hn-expr-2->generator
        (fn expr #`'#,expr)
        #'datum->datum
        "an s-expression"
        hn))
    "s-expression"
    "a quasiquotation"
    'my-quasiquote
    #'quotation))


(define-syntax-rule (datum->quoted-syntax stx-example datum)
  (datum->syntax-with-everything (quote-syntax stx-example) datum))

(define-syntax-rule (datum->quoted-syntax-local stx-example datum)
  (datum->syntax-with-everything (quote-syntax stx-example #:local)
    datum))

; TODO: Test this.
(define-syntax (my-quasiquote-syntax stx)
  (define (helper quote-expr datum->syntax-id quotation)
    (helper-for-quasiquote
      (fn hn
        (hn-expr-2->generator
          quote-expr
          datum->syntax-id
          "a Racket syntax object"
          hn))
      "syntax object"
      "a syntax quasiquotation"
      'my-quasiquote-syntax
      quotation))
  (syntax-parse stx
    [
      (_ quotation)
      (helper
        (fn expr #`(quote-syntax #,expr))
        #'datum->quoted-syntax
        #'quotation)]
    [
      (_ #:local quotation)
      (helper
        (fn expr #`(quote-syntax #,expr #:local))
        #'datum->quoted-syntax-local
        #'quotation)]))

; TODO: Rename `my-quasiquote` to `taffyquote` and
; `my-quasiquote-syntax` to `taffyquote-syntax`.
;
; TODO: Define `taffydatum` corresponding to `datum`/`quasidatum`,
; `taffysyntax` corresponding to `syntax`/`quasisyntax`, and
; `taffysyntax/loc` corresponding to `syntax/loc`/`quasisyntax/loc`.
