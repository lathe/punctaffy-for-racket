#lang parendown racket/base

; punctaffy/quote
;
; Quasiuotation operators similar to those in the Racket base package,
; but which use Punctaffy's hyperbrackets to manage their nesting and
; interoperation.

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


; TODO NOW: Unquote all this.
#|
(require #/for-syntax racket/base)

(require #/for-syntax #/only-in racket/extflonum extflonum?)
(require #/for-syntax #/only-in syntax/datum datum)
(require #/for-syntax #/only-in syntax/parse
  ~and id nat ~optional syntax-parse)

(require #/for-syntax #/only-in lathe-comforts
  dissect expect fn mat w-)
(require #/for-syntax #/only-in lathe-comforts/list
  list-each list-map)
(require #/for-syntax #/only-in lathe-comforts/maybe just)
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
  hypertee-coil-hole hypertee-coil-zero hypertee-furl
  hypertee-snippet-format-sys)
(require #/for-syntax #/only-in punctaffy/hypersnippet/snippet
  selected snippet-sys-shape-snippet-sys
  snippet-sys-snippet-bind snippet-sys-snippet-degree
  snippet-sys-snippet-each snippet-sys-snippet-join
  snippet-sys-snippet-join-selective snippet-sys-snippet-map
  snippet-sys-snippet-map-selective
  snippet-sys-snippet-select-if-degree
  snippet-sys-snippet-set-degree-maybe snippet-sys-snippet-undone
  snippet-sys-snippet-zip-map unselected)
(require #/for-syntax #/only-in
  punctaffy/private/experimental/macro/hypernest-macro
  hn-expr-forget-nests hn-expr->s-expr-stx-list hn-tag-0-s-expr-stx
  hn-tag-1-box hn-tag-1-list hn-tag-1-prefab hn-tag-1-vector
  hn-tag-2-list* hn-tag-nest parse-list*-tag s-expr-stx->hn-expr)

(require #/only-in racket/list append*)

(require #/only-in lathe-comforts expect fn w-)
(require #/only-in lathe-comforts/list list-each)

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


(provide
  taffy-quote
  taffy-quote-syntax)


; In this file, the syntax we define for quasiquotation looks
; something like this, using operators ^< and ^> that signify
; higher-dimensional opening brackets and closing brackets:
;
;   (taffy-quote #/^< 2
;     (a b
;       (taffy-quote #/^< 2
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
; The `taffy-quote` syntax is defined without directly using all the
; infrastructure underlying ^< and ^>. It's defined only in terms of
; `s-expr-stx->hn-expr`, the structs of the hn-expression format, and
; the hypernest and hypertee utilities.
;
; Users of `taffy-quote` will only need to import that operation and
; ^< and ^> but will not usually need to understand them any more
; deeply than the traditional `quasiquote` and `unquote`. Even if they
; define another quasiquotation syntax, it will interoperate
; seamlessly with `taffy-quote` if it makes similar use of
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


(define-for-syntax (datum->syntax-with-everything stx-example datum)
  (w- ctxt stx-example
  #/w- srcloc stx-example
  #/w- prop stx-example
  #/datum->syntax ctxt datum srcloc prop))

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

(define-for-syntax (adjust-atom err-dsl-stx atom-stx)
  (w- a (syntax-e atom-stx)
  #/if
    ; NOTE: See the `taffy-quote` documentation for commentary on why
    ; each of these types is supported and why certain other types are
    ; not.
    (or
      (boolean? a)
      (char? a)
      (keyword? a)
      (number? a)
      (extflonum? a)
      
      ; NOTE: We process mutable strings below.
      (and (string? a) (immutable? a))
      
      ; NOTE: We check elsewhere that the atom isn't an identifier
      ; with a `hyperbracket-notation?` transformer binding.
      (symbol? a))
    atom-stx
  #/if (string? a)
    (datum->syntax-with-everything atom-stx
      (string->immutable-string a))
    (raise-syntax-error #f "value not of a recognized quasiquotable type"
      err-dsl-stx atom-stx)))

(define-for-syntax (prefab-key-mutability k)
  (syntax-parse k
    [_:id 'known-to-be-immutable]
    [
      (
        _:id
        (~optional _:nat)
        (~optional (_:nat _))
        (~optional (~and v #(_:nat ...)) #:defaults ([(v 0) #()]))
        . parent-key)
      (if (= 0 (vector-length (datum v)))
        (syntax-parse (datum parent-key)
          [() 'known-to-be-immutable]
          [_ (prefab-key-mutability (datum parent-key))])
        'known-to-be-mutable)]
    [_ 'not-known]))

(define (splice-gen-helper-run-time . args)
  (begin
    (list-each args #/fn arg
      (unless (list? arg)
        ; TODO: Improve this error.
        (error "spliced a non-list value")))
  #/append* args))

(define-syntax (splice-gen-helper stx)
  (syntax-protect
  #/syntax-parse stx #/ (_ arg ...)
  #/begin
    (list-each (syntax->list #'(arg ...)) #/fn arg
      (when (keyword? (syntax-e arg))
        (raise-syntax-error #f "keyword not allowed in splice"
          ; TODO: See if we can somehow procure the `err-dsl-stx` here
          ; so that this can report the location of the quasiquotation
          ; operation that the splice belongs to.
          arg)))
    #'(splice-gen-helper-run-time arg ...)))

(define (singleton-gen-helper lst)
  (expect lst (list elem)
    ; TODO: Improve this error.
    (error "expected to splice exactly one element")
    elem))

(define (box-immutable-gen-helper . args)
  (box-immutable #/singleton-gen-helper #/append* args))

(define-for-syntax
  (hn-expr-2->generator
    err-dsl-stx err-phrase quote-expr datum->result-id hn)
  (dlog 'hqq-h1
  #/w- ds en-ds
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/w- n-d en-n-d
  #/w- recur
    (fn hn
      (hn-expr-2->generator
        err-dsl-stx err-phrase quote-expr datum->result-id hn))
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
    (dlog 'hqq-h3.1
    #/dissect data (trivial)
    #/dlog 'hqq-h3.2
    #/mat tails (hypertee-furl _ #/hypertee-coil-zero)
      ; We do nothing with the degree-0 hole.
      (hypernest-furl ds #/hypernest-coil-hole
        (dim-sys-morphism-sys-morph-dim n-d 2)
        tails-shape
        data
        tails)
    #/dlog 'hqq-h3.3
    #/dissect tails
      (hypertee-furl _ #/hypertee-coil-hole _ _ tail
        (hypertee-furl _ #/hypertee-coil-zero))
      
      ; We transform each degree-1 hole by wrapping its spliced
      ; expressions in `splice-gen-helper`.
      ;
      ; TODO: See if there's a better `stx-example` to use here.
      ;
      (dlog 'hqq-h3.4
      #/w- stx-example err-dsl-stx
      #/snippet-sys-snippet-join-selective ss
        (hn-bracs-n-d ds n-d 2
          
          #||# (hnb-open 1 #/hn-tag-1-list stx-example)
            (hnb-open 0 #/hn-tag-0-s-expr-stx #'splice-gen-helper)
            
            (hnb-labeled 1 #/unselected #/trivial)
            0
          0
          
          (hnb-labeled 0 #/selected #/recur tail))))
  
  #/dlog 'hqq-h4
  #/dissect dropped (hypernest-coil-bump _ data bump-degree tails)
  #/dlog 'hqq-h5
  #/mat data (hn-tag-0-s-expr-stx stx)
    (expect (dim-sys-dim=0? ds bump-degree) #t
      (error "Encountered an hn-tag-0-s-expr-stx bump with a degree other than 0")
    #/hypernest-furl ds #/hypernest-coil-bump
      (dim-sys-morphism-sys-morph-dim n-d 2)
      (hn-tag-0-s-expr-stx
        #`(list #,(quote-expr #/adjust-atom err-dsl-stx stx)))
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
        
        #||# (hnb-open 1 #/hn-tag-1-list stx-example)
          (hnb-open 0 #/hn-tag-0-s-expr-stx #'list)
          
          #||# (hnb-open 1 #/hn-tag-1-list stx-example)
            (hnb-open 0 #/hn-tag-0-s-expr-stx datum->result-id)
            (hnb-open 0 #/hn-tag-0-s-expr-stx stx-example)
            
            #||# (hnb-open 1 #/hn-tag-1-list stx-example)
              (hnb-open 0 #/hn-tag-0-s-expr-stx #'apply)
              
              (hnb-labeled 1 #/hypernest-join-0 ds n-d 2
              #/list-map list-beginnings #/fn list-beginning
                (hn-bracs-n-d ds n-d 2
                  (hnb-open 0 #/hn-tag-0-s-expr-stx list-beginning)
                #/hnb-labeled 0 #/trivial))
              0
              
              #||# (hnb-open 1 #/hn-tag-1-list stx-example)
                (hnb-open 0 #/hn-tag-0-s-expr-stx #'append)
                
                (hnb-labeled 1 #/recur elems)
                0
              0
            0
          0
        0
        
        (hnb-labeled 0 #/recur tail)))
  #/mat data (hn-tag-1-box stx-example)
    (process-listlike stx-example #/list #'box-immutable-gen-helper)
  #/mat data (hn-tag-1-list stx-example)
    (process-listlike stx-example #/list #'list)
  #/mat data (hn-tag-1-vector stx-example)
    (process-listlike stx-example #/list #'vector-immutable)
  #/mat data (hn-tag-1-prefab key stx-example)
    (w- mutability (prefab-key-mutability key)
    ; TODO: See if we can procure something here that isn't an empty
    ; list like `stx-example` is. This should have the right source
    ; location, at least. We might want to change our policy so
    ; `stx-example` is the original syntax object rather than
    ; normalizing it to an empty list.
    #/w- struct-stx stx-example
    #/mat mutability 'known-to-be-mutable
      (raise-syntax-error #f "cannot quote a mutable prefab struct"
        err-dsl-stx struct-stx)
    #/mat mutability 'not-known
      (raise-syntax-error #f "cannot quote a prefab struct unless it's immutable"
        err-dsl-stx struct-stx)
    #/dissect mutability 'known-to-be-immutable
    #/process-listlike stx-example
      (list #'make-prefab-struct #`'#,key))
  
  #/mat (parse-list*-tag bump-degree data tails)
    (just #/list stx-example list*-elems list*-tail tail)
    (snippet-sys-snippet-join ss
      (hn-bracs-n-d ds n-d 2
        
        #||# (hnb-open 1 #/hn-tag-1-list stx-example)
          (hnb-open 0 #/hn-tag-0-s-expr-stx #'list)
          
          #||# (hnb-open 1 #/hn-tag-1-list stx-example)
            (hnb-open 0 #/hn-tag-0-s-expr-stx datum->result-id)
            (hnb-open 0 #/hn-tag-0-s-expr-stx stx-example)
            
            #||# (hnb-open 1 #/hn-tag-1-list stx-example)
              ; NOTE: Ironically, we don't actually use `list*` here.
              (hnb-open 0 #/hn-tag-0-s-expr-stx #'append)
              
              (hnb-labeled 1 #/recur list*-elems)
              0
              
              #||# (hnb-open 1 #/hn-tag-1-list stx-example)
                (hnb-open 0
                  (hn-tag-0-s-expr-stx #'singleton-gen-helper))
                
                #||# (hnb-open 1 #/hn-tag-1-list stx-example)
                  (hnb-open 0 #/hn-tag-0-s-expr-stx #'append)
                  
                  (hnb-labeled 1 #/recur list*-tail)
                  0
                0
              0
            0
          0
        0
        
        (hnb-labeled 0 #/recur tail)))
  
  #/mat data (hn-tag-nest)
    (error #/format "Encountered an hn-tag-nest bump when making an hn-expression into code that generates it as ~a"
      err-phrase)
  #/error #/format "Encountered an unsupported bump value when making an hn-expression into code that generates it as ~a"
    err-phrase))

(define-for-syntax
  (helper-for-quasiquote
    hn-expr-2->result-generator
    err-dsl-stx
    err-phrase-s-expression
    err-phrase-invocation
    err-name
    quotation)
  (dlog 'hqq-a1
  #/w- ds en-ds
  #/w- ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)
  #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/w- n-d en-n-d
  #/dlog 'hqq-a1.1
  #/w- quotation (s-expr-stx->hn-expr err-dsl-stx quotation)
  #/dlog 'hqq-a1.2
  #/expect quotation
    (hypernest-furl _ #/hypernest-coil-bump
      overall-degree
      (hn-tag-nest)
      (extended-with-top-dim-infinite)
      bracket-and-quotation-and-tails)
    (error #/format "Expected ~a to be of the form (~s #/^< ...)"
      err-phrase-invocation
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
      err-phrase-invocation
      err-name)
  #/dlog 'hqq-a3
  #/begin
    ; We verify that the tail in the hole of degree-0 is a snippet
    ; with just one hole, a degree-0 hole containing a trivial value.
    (snippet-sys-snippet-each shape-ss tails #/fn hole tail
      (w- d (snippet-sys-snippet-degree shape-ss hole)
      #/expect (dim-sys-dim=0? ds d) #t
        (void)
      #/dissect tail
        (hypernest-furl _ #/hypernest-coil-hole _ _ (trivial)
          (hypertee-furl _ #/hypertee-coil-zero))
      #/void))
  #/dlog 'hqq-a4
  #/dissect
    (dlog 'hqq-a4.1
    #/snippet-sys-snippet-zip-map ss tails
      (dlog 'hqq-a4.1.1
      #/hn-expr-2->result-generator #/hn-expr-forget-nests quotation)
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
    #/hn-expr->s-expr-stx-list #/hn-expr-forget-nests
      (dissect
        (dlog 'hqq-a4.4
        #/snippet-sys-snippet-set-degree-maybe ss
          (dim-sys-morphism-sys-morph-dim n-d 1)
          joined)
        (just joined)
      #/dlog 'hqq-a4.5
        joined))
    (list result)
    (error #/format "Expected exactly one ~a in ~a"
      err-phrase-s-expression
      err-phrase-invocation)
  #/dlog 'hqq-a5
  #/syntax-protect
    ; TODO: See if we should use `quasisyntax/loc` here so the error
    ; message refers to the place `taffy-quote` is used.
    #`(w- spliced-root #,result
      #/expect spliced-root (list root)
        (raise-arguments-error '#,err-name
          #,(format "spliced a value other than a singleton list into the root of a ~s"
              err-name)
          "spliced-root" spliced-root)
        root)))


(define-syntax-rule (datum->datum stx-example datum)
  datum)

(define-syntax (taffy-quote stx)
  (syntax-parse stx #/ (_ quotation)
  #/helper-for-quasiquote
    (fn hn
      (hn-expr-2->generator
        stx
        "an s-expression"
        (fn expr #`'#,expr)
        #'datum->datum
        hn))
    stx
    "s-expression"
    "a quasiquotation"
    'taffy-quote
    #'quotation))


(define-syntax-rule (datum->quoted-syntax stx-example datum)
  (datum->syntax-with-everything (quote-syntax stx-example) datum))

(define-syntax-rule (datum->quoted-syntax-local stx-example datum)
  (datum->syntax-with-everything (quote-syntax stx-example #:local)
    datum))

; TODO: Test this.
(define-syntax (taffy-quote-syntax stx)
  (define (helper quote-expr datum->syntax-id quotation)
    (helper-for-quasiquote
      (fn hn
        (hn-expr-2->generator
          stx
          "a Racket syntax object"
          quote-expr
          datum->syntax-id
          hn))
      stx
      "syntax object"
      "a syntax quasiquotation"
      'taffy-quote-syntax
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
|#

; TODO: Define `taffy-datum` corresponding to `datum`/`quasidatum`,
; `taffy-syntax` corresponding to `syntax`/`quasisyntax`, and
; `taffy-syntax/loc` corresponding to `syntax/loc`/`quasisyntax/loc`.
