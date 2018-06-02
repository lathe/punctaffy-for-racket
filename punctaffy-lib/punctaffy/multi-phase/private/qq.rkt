#lang parendown racket/base


(require #/for-syntax racket/base)
(require #/for-syntax #/only-in syntax/parse id syntax-parse)

(provide my-quasiquote)



(module part1-private racket/base
  (require #/only-in racket/contract/base -> any/c list/c)
  (require #/only-in racket/contract/region define/contract)
  (require #/only-in syntax/parse expr syntax-parse)
  
  (require #/only-in lathe-comforts dissect expect fn mat w-)
  (require #/only-in lathe-comforts/maybe just maybe/c nothing)
  (require #/only-in lathe-comforts/struct struct-easy)
  (require #/only-in lathe-ordinals onum-omega)
  
  (require #/only-in punctaffy/multi-phase/private/hypertee-macros
    ht-tag-atom ht-tag-list ht-tag-list* ht-tag-vector
    s-expr-stx->ht-expr simple-ht-builder-syntax)
  (require #/only-in punctaffy/multi-phase/private/trees2
    degree-and-closing-brackets->hypertee hypertee? hypertee-degree
    hypertee-map-all-degrees)
  
  (provide #/all-defined-out)
  
  
  (define (omega-ht . closing-brackets)
    (degree-and-closing-brackets->hypertee (onum-omega)
      closing-brackets))
  
  ; TODO: Implement this.
  (define/contract (ht-drop1 ht)
    (-> hypertee? #/maybe/c #/list/c any/c hypertee?)
    'TODO)
  
  ; TODO: Put something like this in the
  ; `punctaffy/multi-phase/private/trees2` module.
  (define/contract (ht-fold ht func)
    (-> hypertee? (-> any/c hypertee? any/c) any/c)
    (mat (hypertee-degree ht) 0
      ; TODO: Make this part of the contract instead.
      (error "Expected ht to be a hypertee of degree greater than 0")
    #/dissect (ht-drop1 ht) (just #/list data tails)
    #/func data #/hypertee-map-all-degrees tails #/fn hole tail
      (ht-fold tail func)))
  
  
  (struct-easy (my-quasiquote-tag-unquote stx) #:equal)
  
  (define my-quasiquote-uq
    (simple-ht-builder-syntax #/fn stx
      (syntax-parse stx #/ (_ interpolation:expr)
      #/omega-ht
        (list 1 #/my-quasiquote-tag-unquote #'interpolation)
        0
      #/list 0 #/list)))
  
  ; TODO: Give this support for nested quasiquotation.
  (define (my-quasiquote-qq stx)
    (syntax-parse stx #/ (_ quotation:expr)
    #/w- quotation (s-expr-stx->ht-expr #'quotation)
    #/ht-fold quotation #/fn data tails
      (w- d (hypertee-degree tails)
      #/mat d 0
        (expect tails (list)
          (error "Encountered an unrecognized degree-0 hole in quasiquoted syntax")
        #/list)
      #/mat d 1
        (dissect (ht-drop1 tails) (just #/list data tails)
        #/dissect (ht-drop1 tails) (nothing)
        #/mat data (ht-tag-atom stx) #`'#,stx
        #/mat data (my-quasiquote-tag-unquote stx) stx
        #/error "Encountered an unrecognized degree-1 hole in quasiquoted syntax")
      #/mat d 2
        #`(
          #,
            (mat data (ht-tag-list stx-example) #'list
            #/mat data (ht-tag-list* stx-example) #'list*
            #/mat data (ht-tag-vector stx-example) #'vector
            #/error "Encountered an unrecognized degree-2 hole in quasiquoted syntax")
          #,@
            (ht-fold tails #/fn data tails
              (w- d (hypertee-degree tails)
              #/mat d 0
                (dissect tails (list)
                #/list)
              #/dissect d 1
              #/dissect (ht-drop1 tails) (just #/list rest tails)
              #/dissect (ht-drop1 tails) (nothing)
              #/cons data rest)))
      #/error "Encountered unexpectedly high-dimensional structure in quasiquoted syntax")))
  
)
(require #/for-syntax 'part1-private)


(define-syntax (my-quasiquote stx)
  (syntax-parse stx #/ (_ uq:id body)
    #'(let-syntax ([uq my-quasiquote-uq] [qq my-quasiquote-qq])
      #/qq body)))
