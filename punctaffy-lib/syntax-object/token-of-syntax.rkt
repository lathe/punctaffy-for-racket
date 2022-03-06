#lang parendown/slash racket/base

; punctaffy/syntax-object/token-of-syntax
;
; A data structure to represent degree-2 hypersnippets of syntax
; objects, with `equal?`-based names identifying the holes and
; indications of which holes are splicing and which are non-splicing.

;   Copyright 2022 The Lathe Authors
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


(require /for-syntax racket/base)
(require /for-syntax /only-in racket/syntax
  format-id generate-temporary)
(require /for-syntax /only-in syntax/contract wrap-expr/c)
(require /for-syntax /only-in syntax/parse
  expr expr/c id syntax-parse this-syntax)

(require /for-syntax /only-in lathe-comforts fn)
(require /for-syntax /only-in lathe-comforts/struct
  define-imitation-simple-struct)

(require /only-in racket/contract/base
  -> and/c any any/c cons/c contract? flat-contract? hash/c list/c
  listof non-empty-listof not/c or/c)
(require /only-in racket/contract/combinator make-flat-contract)
(require /only-in racket/hash hash-union)
(require /only-in racket/list append*)
(require /only-in racket/match prop:match-expander)
(require /only-in racket/set set-equal? set-member?)
(require /only-in racket/struct make-constructor-style-printer)
(require /only-in syntax/parse/define define-syntax-parse-rule)

(require /only-in lathe-comforts dissect dissectfn expect fn mat w-)
(require /only-in lathe-comforts/list list-foldl)
(require /only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct immutable-prefab-struct?)
(require /only-in lathe-comforts/trivial trivial)

(require punctaffy/private/shim)
(init-shim)

(require /only-in punctaffy/private/util
  datum->syntax-with-everything prefab-struct-fill)

(require /for-template racket/base)
(require /for-template /only-in racket/list append*)


(provide /own-contract-out
  token-of-syntax?
  ; TODO: Figure out if we should export this one.
;  token-of-syntax-get-free-vars
  token-of-syntax-with-free-vars<=/c
  singular-token-of-syntax?
  
  token-of-syntax-beginning-with-splice?
  token-of-syntax-beginning-with-splice-elements)
(provide
  token-of-syntax-beginning-with-splice)
(provide /own-contract-out
  token-of-syntax-beginning-with-assert-singular?
  token-of-syntax-beginning-with-assert-singular-body)
(provide
  token-of-syntax-beginning-with-assert-singular)
(provide /own-contract-out
  token-of-syntax-beginning-with-splicing-free-var?
  token-of-syntax-beginning-with-splicing-free-var-var)
(provide
  token-of-syntax-beginning-with-splicing-free-var)
(provide /own-contract-out
  token-of-syntax-beginning-with-syntax?
  token-of-syntax-beginning-with-syntax-stx-example
  token-of-syntax-beginning-with-syntax-e)
(provide
  token-of-syntax-beginning-with-syntax)
(provide /own-contract-out
  token-of-syntax-beginning-with-box?
  token-of-syntax-beginning-with-box-element)
(provide
  token-of-syntax-beginning-with-box)
(provide /own-contract-out
  token-of-syntax-beginning-with-vector?
  token-of-syntax-beginning-with-vector-elements)
(provide
  token-of-syntax-beginning-with-vector)
(provide /own-contract-out
  token-of-syntax-beginning-with-prefab-struct?
  token-of-syntax-beginning-with-prefab-struct-prefab-struct-example
  token-of-syntax-beginning-with-prefab-struct-elements)
(provide
  token-of-syntax-beginning-with-prefab-struct)
(provide /own-contract-out
  token-of-syntax-beginning-with-list*?
  token-of-syntax-beginning-with-list*-elements
  token-of-syntax-beginning-with-list*-tail)
(provide
  token-of-syntax-beginning-with-list*)
(provide /own-contract-out
  token-of-syntax-beginning-with-other-value?
  token-of-syntax-beginning-with-other-value-value)
(provide
  token-of-syntax-beginning-with-other-value)
(provide /own-contract-out
  ; TODO: Figure out if we should export this one.
;  token-of-syntax->list
  list->token-of-syntax
  token-of-syntax-substitute
  token-of-syntax->syntax-list
  syntax->token-of-syntax
  token-of-syntax-autoquote)


(define (improper-list-rev-onto lst b)
  (mat lst (cons element lst)
    (improper-list-rev-onto lst (cons element b))
  /values lst b))

; TODO: Consider exporting this from Lathe Comforts.
(define (improper-list-split-at-end lst)
  (define-values (tail rev-elements)
    (improper-list-rev-onto lst (list)))
  (values (reverse rev-elements) tail))


(define-imitation-simple-struct
  (binary-tree-empty?)
  binary-tree-empty
  'binary-tree-empty (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct
  (binary-tree-singleton? binary-tree-singleton-value)
  binary-tree-singleton
  'binary-tree-singleton (current-inspector)
  (auto-write)
  (auto-equal))
(define-imitation-simple-struct
  (binary-tree-fork? binary-tree-fork-first binary-tree-fork-second)
  binary-tree-fork
  'binary-tree-fork (current-inspector) (auto-write) (auto-equal))

(define (binary-tree-cheap-append-preferably-nonempty a b)
  (mat a (binary-tree-empty) b
  /mat b (binary-tree-empty) a
  /binary-tree-fork a b))

(define (binary-trees-rev-onto-list trees rev-result)
  (expect trees (cons tree trees) rev-result
  /mat tree (binary-tree-empty)
    (binary-trees-rev-onto-list trees rev-result)
  /mat tree (binary-tree-singleton elem)
    (binary-trees-rev-onto-list trees (cons elem rev-result))
  /dissect tree (binary-tree-fork a b)
    (binary-trees-rev-onto-list (list* a b trees) rev-result)))

(define (binary-tree->list tree)
  (reverse /binary-trees-rev-onto-list (list tree) (list)))


(define-imitation-simple-struct
  (token-of-tree-free-vars-collection?
    token-of-tree-free-vars-collection-hash
    token-of-tree-free-vars-collection-binary-tree)
  token-of-tree-free-vars-collection
  'token-of-tree-free-vars-collection (current-inspector)
  (#:prop prop:custom-write
    (make-constructor-style-printer
      ; TODO: See if we should implement
      ; `token-of-tree-free-vars-collection-from-entries`.
      (fn token 'token-of-tree-free-vars-collection-from-entries)
      (dissectfn (token-of-tree-free-vars-collection hash binary-tree)
        (for/list ([var (in-list /binary-tree->list binary-tree)])
          (list var (hash-ref hash var)))))))
; NOTE: There's only one type of free variable, `'splicing`.
(ascribe-own-contract token-of-tree-free-vars-collection-hash
  (-> token-of-tree-free-vars-collection? (hash/c any/c 'splicing)))

(define (token-of-tree-free-vars-collection-append-zero)
  (token-of-tree-free-vars-collection (hash) (binary-tree-empty)))
(define (token-of-tree-free-vars-collection-append-two a b)
  (dissect a (token-of-tree-free-vars-collection a-hash a-binary-tree)
  /dissect b
    (token-of-tree-free-vars-collection b-hash b-binary-tree)
  /token-of-tree-free-vars-collection
    (hash-union a-hash b-hash #:combine/key /fn var a-type b-type
      (raise-arguments-error
        'token-of-tree-free-vars-collection-append
        "duplicate free vars"
        "a" a
        "b" b
        "var" var
        "type of var in a" a-type
        "type of var in b" b-type))
    (binary-tree-cheap-append-preferably-nonempty
      a-binary-tree b-binary-tree)))
(define (token-of-tree-free-vars-collection-append-list collections)
  (list-foldl
    (token-of-tree-free-vars-collection-append-zero)
    collections
    (fn a b /token-of-tree-free-vars-collection-append-two a b)))
(define (token-of-tree-free-vars-collection-append . collections)
  (token-of-tree-free-vars-collection-append-list collections))


(define-imitation-simple-generics
  token-of-syntax?
  token-of-syntax-impl?
  (#:method token-of-syntax-get-free-vars-from-one (#:this))
  prop:token-of-syntax make-token-of-syntax-impl
  'token-of-syntax 'token-of-syntax-impl (list))
(ascribe-own-contract token-of-syntax? (-> any/c boolean?))

(define (token-of-syntax-get-free-vars-from-list tokens)
  (token-of-tree-free-vars-collection-append-list
    (for/list ([token (in-list tokens)])
      (token-of-syntax-get-free-vars-from-one token))))
(define (token-of-syntax-get-free-vars . tokens)
  (token-of-syntax-get-free-vars-from-list tokens))

(define/own-contract
  (token-of-syntax-with-free-vars<=/c free-vars-set)
  (-> set-equal? flat-contract?)
  (w- name `(token-of-syntax-with-free-vars<=/c ,free-vars-set)
  /make-flat-contract #:name name
    #:first-order
    (fn v
      (and (token-of-syntax? v)
      /dissect (token-of-syntax-get-free-vars-from-one v)
        (token-of-tree-free-vars-collection hash binary-tree)
      /for/and ([var (in-hash-keys hash)])
        (set-member? free-vars-set var)))))


(define-syntax-parse-rule
  (define-token-of-syntax
    (token?:id
      (#:field field:id token-field:id field-description field/sig-c)
      ...)
    token
    token-name
    token/syntax-name
    calculate-free-vars)
  
  #:declare field-description
  (expr/c #'string? #:phase (add1 /syntax-local-phase-level)
    #:name "a field description")
  
  #:declare field/sig-c (expr/c #'contract? #:name "a field contract")
  
  #:declare token-name (expr/c #'symbol? #:name "the token name")
  
  #:declare token/syntax-name
  (expr/c #'symbol? #:phase (add1 /syntax-local-phase-level)
    #:name "the token syntax name")
  
  ; TODO: See if we should make this more specific than `any/c`.
  #:declare calculate-free-vars
  (expr/c #'any/c #:name "the free variables")
  
  #:with (local-field ...) (generate-temporaries #'(field ...))
  
  #:with (local-field.c ...)
  (for/list
    ([local-field (in-list /syntax->list #'(local-field ...))])
    (format-id local-field "~a.c" (syntax-e local-field)))
  
  #:with (field-description-result ...)
  (generate-temporaries #'(field ...))
  
  #:with (field/sig-c-result ...) (generate-temporaries #'(field ...))
  
  #:with token-name-result (generate-temporary #'token-name)
  
  #:with token/syntax-name-result
  (generate-temporary #'token/syntax-name)
  
  (begin
    
    (define-for-syntax field-description-result field-description.c)
    ...
    (define token-name-result token-name.c)
    (define-for-syntax token/syntax-name-result token/syntax-name.c)
    
    (define-imitation-simple-struct
      (token? token-free-vars token-field ...)
      unguarded-token
      token-name-result (current-inspector)
      (#:prop prop:custom-write
        (make-constructor-style-printer
          (fn token token-name-result)
          (dissectfn (unguarded-token free-vars field ...)
            (list field ...))))
      (#:prop prop:token-of-syntax
        (make-token-of-syntax-impl /fn token
          (token-free-vars token))))
    (define field/sig-c-result field/sig-c.c)
    ...
    (ascribe-own-contract token? (-> any/c boolean?))
    (ascribe-own-contract token-field (-> token? field/sig-c-result))
    ...
    
    (define (auto-token field ...)
      (unguarded-token calculate-free-vars.c field ...))
    (begin-for-syntax
      (define-imitation-simple-struct (token-impl?) token-impl
        token/syntax-name-result (current-inspector)
        (#:prop prop:procedure /fn this stx
          (syntax-protect
          /syntax-parse stx
            [ _:id
              #`(procedure-rename
                  #,(wrap-expr/c
                      #'(-> field/sig-c-result ... any)
                      (syntax/loc stx auto-token)
                      #:arg? #f
                      #:context stx
                      #:name "a first-class use")
                  token-name-result)]
            [ (_ local-field ...)
              
              {~@ #:declare local-field
                (expr/c #'field/sig-c-result
                  #:name field-description-result)}
              ...
              
              #'(auto-token local-field.c ...)]))
        (#:prop prop:match-expander /fn this stx
          (syntax-protect
          ; TODO: We should really use a syntax class for match
          ; patterns rather than `expr` here, but it doesn't look like
          ; one exists yet.
          /syntax-parse stx / (_ field ...)
            {~@ #:declare field expr}
            ...
            #'(unguarded-token _ field ...)))))
    (define-syntax token (token-impl))))

(define/own-contract (singular-token-of-syntax? v)
  (-> any/c boolean?)
  (and (token-of-syntax? v)
  /mat v (token-of-syntax-beginning-with-splice _) #f
    #t))

(define-token-of-syntax
  (token-of-syntax-beginning-with-splice?
    (#:field elements token-of-syntax-beginning-with-splice-elements
      "the elements"
      (or/c (list/c)
        (cons/c singular-token-of-syntax?
          (non-empty-listof singular-token-of-syntax?)))))
  token-of-syntax-beginning-with-splice
  'token-of-syntax-beginning-with-splice
  'token-of-syntax-beginning-with-splice/syntax
  (token-of-syntax-get-free-vars-from-list elements))
(define-token-of-syntax
  (token-of-syntax-beginning-with-assert-singular?
    (#:field body token-of-syntax-beginning-with-assert-singular-body
      "the body"
      token-of-syntax?))
  token-of-syntax-beginning-with-assert-singular
  'token-of-syntax-beginning-with-assert-singular
  'token-of-syntax-beginning-with-assert-singular/syntax
  (token-of-syntax-get-free-vars body))
(define-token-of-syntax
  (token-of-syntax-beginning-with-splicing-free-var?
    (#:field var
      token-of-syntax-beginning-with-splicing-free-var-var
      "the free variable"
      any/c))
  token-of-syntax-beginning-with-splicing-free-var
  'token-of-syntax-beginning-with-splicing-free-var
  'token-of-syntax-beginning-with-splicing-free-var/syntax
  (token-of-tree-free-vars-collection
    (hash var 'splicing)
    (binary-tree-singleton var)))
(define-token-of-syntax
  (token-of-syntax-beginning-with-syntax?
    (#:field stx-example
      token-of-syntax-beginning-with-syntax-stx-example
      "the example syntax"
      syntax?)
    (#:field e token-of-syntax-beginning-with-syntax-e
      "the token of syntax to be wrapped"
      token-of-syntax?))
  token-of-syntax-beginning-with-syntax
  'token-of-syntax-beginning-with-syntax
  'token-of-syntax-beginning-with-syntax/syntax
  (token-of-syntax-get-free-vars e))
(define-token-of-syntax
  (token-of-syntax-beginning-with-box?
    (#:field element token-of-syntax-beginning-with-box-element
      "the element"
      token-of-syntax?))
  token-of-syntax-beginning-with-box
  'token-of-syntax-beginning-with-box
  'token-of-syntax-beginning-with-box/syntax
  (token-of-syntax-get-free-vars element))
(define-token-of-syntax
  (token-of-syntax-beginning-with-vector?
    (#:field elements token-of-syntax-beginning-with-vector-elements
      "the elements"
      token-of-syntax?))
  token-of-syntax-beginning-with-vector
  'token-of-syntax-beginning-with-vector
  'token-of-syntax-beginning-with-vector/syntax
  (token-of-syntax-get-free-vars elements))
(define-token-of-syntax
  (token-of-syntax-beginning-with-prefab-struct?
    (#:field key
      token-of-syntax-beginning-with-prefab-struct-prefab-struct-example
      "the prefab struct example"
      immutable-prefab-struct?)
    (#:field elements
      token-of-syntax-beginning-with-prefab-struct-elements
      "the elements"
      token-of-syntax?))
  token-of-syntax-beginning-with-prefab-struct
  'token-of-syntax-beginning-with-prefab-struct
  'token-of-syntax-beginning-with-prefab-struct/syntax
  (token-of-syntax-get-free-vars elements))
(define-token-of-syntax
  (token-of-syntax-beginning-with-list*?
    (#:field elements token-of-syntax-beginning-with-list*-elements
      "the elements"
      token-of-syntax?)
    (#:field tail token-of-syntax-beginning-with-list*-tail
      "the tail"
      token-of-syntax?))
  token-of-syntax-beginning-with-list*
  'token-of-syntax-beginning-with-list*
  'token-of-syntax-beginning-with-list*/syntax
  (token-of-syntax-get-free-vars elements tail))
(define-token-of-syntax
  (token-of-syntax-beginning-with-other-value?
    (#:field value token-of-syntax-beginning-with-other-value-value
      "the value"
      (not/c /or/c
        syntax?
        (and/c box? immutable?)
        (and/c vector? immutable?)
        immutable-prefab-struct?
        pair?)))
  token-of-syntax-beginning-with-other-value
  'token-of-syntax-beginning-with-other-value
  'token-of-syntax-beginning-with-other-value/syntax
  (token-of-syntax-get-free-vars))


(define/own-contract (token-of-syntax->list token)
  (-> token-of-syntax? (listof singular-token-of-syntax?))
  (mat token (token-of-syntax-beginning-with-splice elements) elements
  /list token))

(define/own-contract (list-of-singular->token-of-syntax tokens)
  (-> (listof singular-token-of-syntax?) token-of-syntax?)
  (mat tokens (list token) token
  /token-of-syntax-beginning-with-splice tokens))

(define/own-contract (list->token-of-syntax tokens)
  (-> (listof token-of-syntax?) token-of-syntax?)
  (list-of-singular->token-of-syntax /append*
    (for/list ([token (in-list tokens)])
      (token-of-syntax->list token))))

(define/own-contract (token-of-syntax-substitute prefix suffixes)
  (->
    token-of-syntax?
    (and/c hash? hash-equal? /hash/c any/c token-of-syntax?)
    token-of-syntax?)
  (mat prefix (token-of-syntax-beginning-with-splice elements)
    (list->token-of-syntax
      (for/list ([element (in-list elements)])
        (token-of-syntax-substitute element suffixes)))
  /mat prefix (token-of-syntax-beginning-with-assert-singular body)
    (token-of-syntax-beginning-with-assert-singular
      (token-of-syntax-substitute body suffixes))
  /mat prefix (token-of-syntax-beginning-with-splicing-free-var var)
    (hash-ref suffixes var /fn prefix)
  /mat prefix (token-of-syntax-beginning-with-syntax stx-example e)
    (token-of-syntax-beginning-with-syntax stx-example
      (token-of-syntax-substitute e suffixes))
  /mat prefix (token-of-syntax-beginning-with-box element)
    (token-of-syntax-beginning-with-box
      (token-of-syntax-substitute element suffixes))
  /mat prefix (token-of-syntax-beginning-with-vector elements)
    (token-of-syntax-beginning-with-vector
      (token-of-syntax-substitute elements suffixes))
  /mat prefix
    (token-of-syntax-beginning-with-prefab-struct key elements)
    (token-of-syntax-beginning-with-prefab-struct key
      (token-of-syntax-substitute elements suffixes))
  /mat prefix (token-of-syntax-beginning-with-list* elements tail)
    (token-of-syntax-beginning-with-list*
      (token-of-syntax-substitute elements suffixes)
      (token-of-syntax-substitute tail suffixes))
  /dissect prefix (token-of-syntax-beginning-with-other-value value)
    prefix))

(define/own-contract (token-of-syntax->syntax-list prefix suffixes)
  (-> token-of-syntax? (and/c hash? hash-equal? /hash/c any/c list?)
    list?)
  (mat prefix (token-of-syntax-beginning-with-splice elements)
    (append* /for/list ([element (in-list elements)])
      (token-of-syntax->syntax-list element suffixes))
  /mat prefix (token-of-syntax-beginning-with-assert-singular body)
    (w- body-values (token-of-syntax->syntax-list body suffixes)
    /expect body-values (list body)
      (raise-arguments-error 'token-of-syntax->syntax-list
        "assertion expected just one s-expression"
        "body-values" body-values
        "the token of syntax that had that result" body
        "suffixes" suffixes)
    /list body)
  /mat prefix (token-of-syntax-beginning-with-splicing-free-var var)
    (hash-ref suffixes var /fn
      (raise-arguments-error 'token-of-syntax->syntax-list
        "unbound variable"
        "var" var
        "suffixes" suffixes))
  /mat prefix (token-of-syntax-beginning-with-syntax stx-example e)
    (w- e-values (token-of-syntax->syntax-list e suffixes)
    /expect e-values (list e)
      (raise-arguments-error 'token-of-syntax->syntax-list
        "expected just one s-expression to wrap as syntax"
        "e-values" e-values
        "the token of syntax that had that result" e
        "suffixes" suffixes)
    /list /datum->syntax-with-everything stx-example e)
  /mat prefix (token-of-syntax-beginning-with-box element)
    (w- element-values (token-of-syntax->syntax-list element suffixes)
    /expect element-values (list element)
      (raise-arguments-error 'token-of-syntax->syntax-list
        "expected just one s-expression for the element of a box"
        "element-values" element-values
        "the token of syntax that had that result" element
        "suffixes" suffixes)
    /list /box-immutable element)
  /mat prefix (token-of-syntax-beginning-with-vector elements)
    (list /apply vector-immutable
      (token-of-syntax->syntax-list elements suffixes))
  /mat prefix
    (token-of-syntax-beginning-with-prefab-struct key elements)
    (list /apply make-prefab-struct key
      (token-of-syntax->syntax-list elements suffixes))
  /mat prefix (token-of-syntax-beginning-with-list* elements tail)
    (w- elements (token-of-syntax->syntax-list elements suffixes)
    /w- tail-values (token-of-syntax->syntax-list tail suffixes)
    /expect tail-values (list tail)
      (raise-arguments-error 'token-of-syntax->syntax-list
        "expected just one s-expression for the tail of a list"
        "tail-values" tail-values
        "the token of syntax that had that result" tail
        "suffixes" suffixes)
    /list /append elements tail)
  /dissect prefix (token-of-syntax-beginning-with-other-value value)
    (list value)))

(define/own-contract (syntax->token-of-syntax stx)
  (-> any/c singular-token-of-syntax?)
  (if (syntax? stx)
    (token-of-syntax-beginning-with-syntax
      (datum->syntax-with-everything stx '())
      (syntax->token-of-syntax /syntax-e stx))
  /if (and (box? stx) (immutable? stx))
    (token-of-syntax-beginning-with-box
      (syntax->token-of-syntax /unbox stx))
  /if (and (vector? stx) (immutable? stx))
    (token-of-syntax-beginning-with-vector
      (list-of-singular->token-of-syntax
        (for/list ([element (in-vector stx)])
          (syntax->token-of-syntax element))))
  /if (immutable-prefab-struct? stx)
    (token-of-syntax-beginning-with-prefab-struct
      (prefab-struct-fill stx /trivial)
      (list-of-singular->token-of-syntax
        (for/list
          ([element (in-list /cdr /vector->list /struct->vector stx)])
          (syntax->token-of-syntax element))))
  /if (pair? stx)
    (let-values ([(elements tail) (improper-list-split-at-end stx)])
      (token-of-syntax-beginning-with-list*
        (list-of-singular->token-of-syntax
          (for/list ([element (in-list elements)])
            (syntax->token-of-syntax element)))
        (syntax->token-of-syntax tail)))
    (token-of-syntax-beginning-with-other-value stx)))

(module private racket/base
  (require /only-in racket/contract/base -> any/c)
  
  (require /only-in lathe-comforts expect)
  
  (require punctaffy/private/shim)
  (init-shim)
  
  (provide
    assert-singular
    unwrap-singular)
  
  (define/own-contract (assert-singular lst)
    (-> list? list?)
    (expect lst (list elem)
      ; TODO: See if we can improve this error message. This may mean
      ; adding more arguments to `token-of-syntax-autoquote`.
      (raise-arguments-error 'token-of-syntax-autoquote
        "encountered more than one value spliced where only one was expected"
        "lst" lst)
      lst))
  
  (define/own-contract (unwrap-singular lst)
    (-> list? any/c)
    (assert-singular lst)
    (car lst))
  
  )
(require /for-template 'private)

(define/own-contract
  (token-of-syntax-autoquote quote-expr datum->result--id token)
  (-> (-> any/c any/c) identifier? token-of-syntax? token-of-syntax?)
  (w- recur
    (fn token
      (token-of-syntax-autoquote quote-expr datum->result--id token))
  /w- call
    (lambda arg-tokens
      (token-of-syntax-beginning-with-syntax #'()
        (token-of-syntax-beginning-with-list*
          (list->token-of-syntax arg-tokens)
          (syntax->token-of-syntax /list))))
  /mat token (token-of-syntax-beginning-with-splice elements)
    (call (syntax->token-of-syntax #'append)
      (list->token-of-syntax
        (for/list ([element (in-list elements)])
          (recur element))))
  /mat token (token-of-syntax-beginning-with-assert-singular body)
    (call (syntax->token-of-syntax #'assert-singular) /recur body)
  /mat token (token-of-syntax-beginning-with-splicing-free-var var)
    token
  /mat token (token-of-syntax-beginning-with-syntax stx-example e)
    (call (syntax->token-of-syntax #'list)
      (call (syntax->token-of-syntax datum->result--id)
        (syntax->token-of-syntax stx-example)
        (call (syntax->token-of-syntax #'unwrap-singular) /recur e)))
  /mat token (token-of-syntax-beginning-with-box element)
    (call (syntax->token-of-syntax #'list)
      (call (syntax->token-of-syntax #'apply)
        (syntax->token-of-syntax #'box-immutable)
        (call (syntax->token-of-syntax #'assert-singular)
          (recur element))))
  /mat token (token-of-syntax-beginning-with-vector elements)
    (call (syntax->token-of-syntax #'list)
      (call (syntax->token-of-syntax #'apply)
        (syntax->token-of-syntax #'vector-immutable)
        (recur elements)))
  /mat token
    (token-of-syntax-beginning-with-prefab-struct key elements)
    (call (syntax->token-of-syntax #'list)
      (call (syntax->token-of-syntax #'apply)
        (syntax->token-of-syntax #'make-prefab-struct)
        (syntax->token-of-syntax #`'#,key)
        (recur elements)))
  /mat token (token-of-syntax-beginning-with-list* elements tail)
    (call (syntax->token-of-syntax #'list)
      (call (syntax->token-of-syntax #'append*)
        (call (syntax->token-of-syntax #'append) /recur elements)
        (call (syntax->token-of-syntax #'assert-singular)
          (recur tail))))
  /dissect token (token-of-syntax-beginning-with-other-value value)
    (syntax->token-of-syntax #`(list #,/quote-expr value))))
