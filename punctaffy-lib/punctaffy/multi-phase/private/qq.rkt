#lang parendown racket/base


(require #/for-syntax racket/base)
(require #/for-syntax #/only-in syntax/parse id syntax-parse)

(provide my-quasiquote)



(module part1-private racket/base
  
  (require #/for-template racket/base)
  
  (require #/only-in racket/contract/base -> any/c list/c)
  (require #/only-in racket/contract/region define/contract)
  (require #/only-in syntax/parse expr syntax-parse)
  
  (require #/only-in lathe-comforts dissect expect fn mat w-)
  (require #/only-in lathe-comforts/maybe just maybe/c nothing)
  (require #/only-in lathe-comforts/struct struct-easy)
  (require #/only-in lathe-ordinals onum-omega)
  
  (require #/only-in punctaffy/multi-phase/private/hypertee-macros
    ht-tag-1-other ht-tag-1-s-expr-stx ht-tag-2-list ht-tag-2-list*
    ht-tag-2-prefab ht-tag-2-vector s-expr-stx->ht-expr
    simple-ht-builder-syntax)
  (require #/only-in punctaffy/multi-phase/private/trees2
    degree-and-closing-brackets->hypertee hypertee? hypertee-degree
    hypertee-drop1 hypertee-fold)
  
  (provide #/all-defined-out)
  
  
  (define (omega-ht . closing-brackets)
    (degree-and-closing-brackets->hypertee (onum-omega)
      closing-brackets))
  
  
  (struct-easy (my-quasiquote-tag-unquote stx) #:equal)
  
  (define my-quasiquote-uq
    (simple-ht-builder-syntax #/fn stx
      (syntax-parse stx #/ (_ interpolation:expr)
      #/omega-ht
        (list 1
        #/ht-tag-1-other #/my-quasiquote-tag-unquote #'interpolation)
        0
      #/list 0 #/list)))
  
  ; TODO: Give this support for nested quasiquotation.
  (define (my-quasiquote-qq stx)
    (syntax-parse stx #/ (_ quotation:expr)
    #/w- quotation (s-expr-stx->ht-expr #'quotation)
    #/expect
      (hypertee-fold quotation #/fn data tails
        (w- d (hypertee-degree tails)
        #/mat d 0
          (expect data (list)
            (error "Encountered an unrecognized degree-0 hole in quasiquoted syntax")
          #/list)
        #/mat d 1
          (dissect (hypertee-drop1 tails) (just #/list rest tails)
          #/dissect (hypertee-drop1 tails) (nothing)
          #/mat data (ht-tag-1-s-expr-stx stx) (cons #`'#,stx rest)
          #/mat data (ht-tag-1-other #/my-quasiquote-tag-unquote stx)
            (cons stx rest)
          #/error "Encountered an unrecognized degree-1 hole in quasiquoted syntax")
        #/mat d 2
          (dissect
            (hypertee-fold tails #/fn data tails
              (w- d (hypertee-degree tails)
              #/mat d 0 (list (list) data)
              #/dissect d 1
              #/dissect (hypertee-drop1 tails)
                (just #/list (list elems rest) tails)
              #/dissect (hypertee-drop1 tails) (nothing)
              #/list (append data elems) rest))
            (list elems rest)
          #/cons
            (mat data (ht-tag-2-list stx-example) #`(list #,@elems)
            #/mat data (ht-tag-2-list* stx-example) #`(list* #,@elems)
            #/mat data (ht-tag-2-vector stx-example)
              #`(vector #,@elems)
            #/mat data (ht-tag-2-prefab key stx-example)
              ; NOTE: The expression this generates can raise an error
              ; if the struct has more fields than prefab structs
              ; allow.
              #`(make-prefab-struct '#,key #,@elems)
            #/error "Encountered an unrecognized degree-2 hole in quasiquoted syntax")
            rest)
        #/error "Encountered unexpectedly high-dimensional structure in quasiquoted syntax"))
      (list stx)
      (error "Internal error: Somehow reconstructed more than one syntax object out of quasiquoted syntax")
      stx))
  
)
(require #/for-syntax 'part1-private)


(define-syntax (my-quasiquote stx)
  (syntax-parse stx #/ (_ uq:id body)
    #'(let-syntax ([uq my-quasiquote-uq] [qq my-quasiquote-qq])
      #/qq body)))
