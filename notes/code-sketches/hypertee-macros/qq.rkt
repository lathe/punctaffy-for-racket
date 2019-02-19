#lang parendown racket/base

; qq.rkt
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
(require #/for-syntax #/only-in syntax/parse id syntax-parse)

(provide my-quasiquote)



(module part1-private racket/base
  
  (require #/for-template racket/base)
  
  (require #/only-in syntax/parse expr id syntax-parse)
  
  (require #/only-in lathe-comforts dissect expect fn mat w-)
  (require #/only-in lathe-comforts/maybe just)
  (require #/only-in lathe-comforts/struct struct-easy)
  (require #/only-in lathe-comforts/trivial trivial)
  
  (require #/only-in "hypertee-macro.rkt"
    
    ht-tag-1-other ht-tag-1-s-expr-stx ht-tag-2-list ht-tag-2-list*
    ht-tag-2-other ht-tag-2-prefab ht-tag-2-vector
    s-expr-stx->ht-expr simple-ht-builder-syntax)
  (require #/only-in punctaffy/hypersnippet/dim
    dim-successors-sys-dim-sys dim-sys-dim<? extended-nat-dim-sys
    omega)
  (require #/only-in punctaffy/hypersnippet/hypertee
    htb-labeled ht-bracs hypertee-bind-one-degree hypertee-coil-hole
    hypertee-coil-zero hypertee-degree hypertee-unfurl hypertee-fold
    hypertee-increase-degree-to hypertee-join-one-degree hypertee-pure
    hypertee-truncate hypertee-v-map-one-degree
    hypertee-zip-selective)
  
  (provide #/all-defined-out)
  
  
  (define ds (extended-nat-dim-sys))
  
  
  (struct-easy (my-quasiquote-tag-1-expanded-expr stx) #:equal)
  (struct-easy
    (my-quasiquote-tag-1-unmatched-unquote
      closing-bracket interpolation)
    #:equal)
  (struct-easy
    (my-quasiquote-tag-2-matched-internal-quasiquotation
      opening-bracket body-with-closing-brackets)
    #:equal)
  (struct-easy (bracket-tag-1-end) #:equal)
  (struct-easy
    (internal-quasiquotation-tag-1-matched-unquote closing-bracket)
    #:equal)
  
  (define (make-op-bracket call-stx)
    (syntax-parse call-stx #/ (op body)
    #/ht-bracs ds (omega)
      (htb-labeled 2 #/ht-tag-2-list #/datum->syntax call-stx #/list)
      1
      (htb-labeled 1 #/ht-tag-1-s-expr-stx #'op)
      0
      (htb-labeled 1 #/ht-tag-1-other #/bracket-tag-1-end)
      0
      0
      0
    #/htb-labeled 0 #/trivial))
  
  (define my-quasiquote-uq
    (simple-ht-builder-syntax #/fn stx
      (syntax-parse stx
        [op:id
          ; If this syntax transformer is used in an identifier
          ; position, we just expand as though the identifier isn't
          ; bound to a syntax transformer at all. In this case, that
          ; makes it possible to nest `(my-quasiquote uq #/qq ...)`
          ; within itself, without the inner `uq` being treated as a
          ; closing bracket.
          (ht-bracs ds (omega)
            (htb-labeled 1 #/ht-tag-1-s-expr-stx stx)
            0
          #/htb-labeled 0 #/trivial)]
      #/ (op interpolation)
      #/ht-bracs ds (omega)
        (htb-labeled 1
        #/ht-tag-1-other #/my-quasiquote-tag-1-unmatched-unquote
          (make-op-bracket stx)
          #'interpolation)
        0
      #/htb-labeled 0 #/trivial)))
  
  (define my-quasiquote-qq
    (simple-ht-builder-syntax #/fn stx
      (syntax-parse stx
        [op:id
          ; If this syntax transformer is used in an identifier
          ; position, we just expand as though the identifier isn't
          ; bound to a syntax transformer at all.
          (ht-bracs ds (omega)
            (htb-labeled 1 #/ht-tag-1-s-expr-stx stx)
            0
          #/htb-labeled 0 #/trivial)]
      #/ (op body)
      #/w- body (s-expr-stx->ht-expr #'body)
      ; We make a hypertee with a single degree-2 hole (annotated with
      ; the body of the quasiquotation) and some degree-1 holes
      ; (annotated with the `s-expr-stx->ht-expr` expansions of the
      ; interpolations) in its degree-1 holes. Then we join on those
      ; degree-1 holes so that those expansions become part of this
      ; expansion directly.
      #/hypertee-join-one-degree 1
      #/hypertee-pure (omega)
        (ht-tag-2-other #/my-quasiquote-tag-2-matched-internal-quasiquotation
          (make-op-bracket stx)
          (hypertee-v-map-one-degree 1 body #/fn data
            (expect data
              (ht-tag-1-other #/my-quasiquote-tag-1-unmatched-unquote
                closing-bracket interpolation)
              data
            #/ht-tag-1-other #/internal-quasiquotation-tag-1-matched-unquote
              closing-bracket)))
        (hypertee-truncate 2
        #/hypertee-bind-one-degree 1 body #/fn hole data
          (expect data
            (ht-tag-1-other #/my-quasiquote-tag-1-unmatched-unquote
              closing-bracket interpolation)
            (hypertee-increase-degree-to (omega) hole)
          #/hypertee-pure (omega)
            (s-expr-stx->ht-expr interpolation)
            hole)))))
  
  (define (my-quasiquote-ht-expr->stx ht-expr)
    (expect
      (hypertee-fold 1 ht-expr
        (fn
          (error "Expected ht-expr to be of degree greater than zero"))
      #/fn first-nontrivial-d data tails
        (w- d (hypertee-degree tails)
        #/w- is-trivial (dim-sys-dim<? ds d first-nontrivial-d)
        #/begin
          (when is-trivial
            (dissect data (trivial)
            #/void))
        #/mat d 0
          (expect is-trivial #t
            (error "Encountered an unrecognized degree-0 hole in quasiquoted syntax")
          #/list)
        #/expect is-trivial #f
          ; Since `first-nontrivial-d` can only exceed 1 when we're in
          ; a degree-2-or-greater hole of a degree-3-or-greater hole,
          ; and since we expect no degree-3-or-greater holes, we raise
          ; an error.
          (error "Encountered unexpectedly high-dimensional structure in quasiquoted syntax")
        #/mat d 1
          (dissect (hypertee-unfurl tails)
            (hypertee-coil-hole overall-degree rest tails)
          #/dissect (hypertee-unfurl tails) (hypertee-coil-zero)
          #/(fn result #/cons result rest)
          #/mat data (ht-tag-1-s-expr-stx stx) #`'#,stx
          #/mat data
            (ht-tag-1-other #/my-quasiquote-tag-1-expanded-expr stx)
            stx
          #/mat data
            (ht-tag-1-other #/my-quasiquote-tag-1-unmatched-unquote
              bracket-ht-expr stx)
            (syntax-parse stx
              [interpolation:expr stx]
              [_  (error "Encountered an interpolation of a non-expression in quasiquoted syntax")])
          #/error "Encountered an unrecognized degree-1 hole in quasiquoted syntax")
        #/mat d 2
          (dissect
            (hypertee-fold 1 tails
              (fn
                (error "Internal error: Expected tails to be of degree 2 since we just observed that using hypertee-degree"))
            #/fn first-nontrivial-d data tails
              (w- d (hypertee-degree tails)
              #/mat d 0 (list (list) data)
              #/dissect d 1
              #/dissect (hypertee-unfurl tails)
                (hypertee-coil-hole
                  overall-degree (list elems rest) tails)
              #/dissect (hypertee-unfurl tails) (hypertee-coil-zero)
              #/list (append data elems) rest))
            (list elems rest)
          #/(fn result #/cons result rest)
          #/mat data (ht-tag-2-list stx-example) #`(list #,@elems)
          #/mat data (ht-tag-2-list* stx-example) #`(list* #,@elems)
          #/mat data (ht-tag-2-vector stx-example) #`(vector #,@elems)
          #/mat data (ht-tag-2-prefab key stx-example)
            ; NOTE: The expression this generates can raise an error
            ; if the struct has more fields than prefab structs allow.
            #`(make-prefab-struct '#,key #,@elems)
          
          ; This is the support for nested quasiquotation. We use the
          ; `opening-bracket` and `body-with-closing-brackets` to
          ; generate an expression that generates the same data that
          ; was parsed to make the opening bracket, body, and closing
          ; brackets in the first place.
          ;
          #/mat data
            (ht-tag-2-other #/my-quasiquote-tag-2-matched-internal-quasiquotation
              opening-bracket body-with-closing-brackets)
            (w- body-as-closing-bracket
              (hypertee-bind-one-degree 1 body-with-closing-brackets
              #/fn hole data
                (mat data
                  (ht-tag-1-other #/internal-quasiquotation-tag-1-matched-unquote
                    closing-bracket)
                  closing-bracket
                #/hypertee-pure (omega) data hole))
            #/w- zip-bracket-ends
              (fn smaller bigger func
                (hypertee-zip-selective smaller bigger
                  (fn hole data
                    (w- d (hypertee-degree hole)
                    #/mat d 0
                      (dissect data (trivial)
                        #t)
                    #/mat d 1
                      (mat data (ht-tag-1-other #/bracket-tag-1-end)
                        #t
                        #f)
                      #f))
                #/fn hole smaller-data bigger-data
                  (w- d (hypertee-degree hole)
                  #/mat d 0
                    (dissect smaller-data (trivial)
                    #/dissect bigger-data (trivial)
                    #/trivial)
                  #/mat d 1
                    (dissect bigger-data
                      (ht-tag-1-other #/bracket-tag-1-end)
                    #/func smaller-data)
                  #/error "Internal error: Encountered unexpectedly high-dimensional structure when zipping bracket ends")))
            #/expect
              (zip-bracket-ends
                (hypertee-v-map-one-degree 0 tails #/fn data
                  (trivial))
                body-as-closing-bracket
              #/fn tails-data
                (expect tails-data (list stx)
                  ; TODO: See if this is really an "internal" error or
                  ; if there's some input that can legitimately cause
                  ; this error.
                  (error "Internal error: Somehow reconstructed more than one syntax object out of a nested quasiquotation's unquoted syntax")
                #/ht-tag-1-other #/my-quasiquote-tag-1-expanded-expr
                  stx))
              (just body-and-tails)
              (error "Internal error: Expected tails to have the same shape as the nested quasiquotation's body and closing bracket data combined")
            #/w- body-and-tails
              (my-quasiquote-ht-expr->stx body-and-tails)
            #/expect
              (zip-bracket-ends
                (ht-bracs ds (omega) (htb-labeled 1 body-and-tails) 0
                #/htb-labeled 0 #/trivial)
                opening-bracket
              #/fn body-and-tails
                (ht-tag-1-other #/my-quasiquote-tag-1-expanded-expr
                  body-and-tails))
              (just body-and-tails)
              (error "Internal error: Expected opening-bracket to have exactly one end")
            #/my-quasiquote-ht-expr->stx body-and-tails)
          
          #/error "Encountered an unrecognized degree-2 hole in quasiquoted syntax")
        #/error "Encountered unexpectedly high-dimensional structure in quasiquoted syntax"))
      (list stx)
      (error "Internal error: Somehow reconstructed more than one syntax object out of quasiquoted syntax")
      stx))
  
  (define (my-quasiquote-begin-fn stx)
    (syntax-parse stx #/ (_ quotation:expr)
    #/my-quasiquote-ht-expr->stx #/s-expr-stx->ht-expr #'quotation))
  
)
(require #/for-syntax 'part1-private)


(define-syntax my-quasiquote-begin my-quasiquote-begin-fn)

(define-syntax (my-quasiquote stx)
  (syntax-parse stx #/ (_ uq:id (qq:id body))
    #'(let-syntax ([uq my-quasiquote-uq] [qq my-quasiquote-qq])
      #/my-quasiquote-begin body)))
