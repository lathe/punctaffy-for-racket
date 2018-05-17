#lang parendown racket/base


(require #/only-in racket/contract/base -> ->i any/c list/c)
(require #/only-in racket/contract/region define/contract)

(require #/only-in lathe-comforts dissect fn w-)
(require #/only-in lathe-comforts/maybe just)
(require #/only-in lathe-comforts/struct struct-easy)

; TODO: Stop relying on `.../private/...` modules like this.
(require #/only-in
  lathe-morphisms/private/ordinals/below-epsilon-zero/onum
  onum? onum<?)
(require #/only-in
  lathe-morphisms/private/ordinals/below-epsilon-zero/olist
  olist? olist-drop olist-length olist-map olist-tails olist-plus
  olist-ref-and-call olist-zip-map olist-zero)

; TODO: Once we implement this concretely in terms of the operations
; of `.../below-epsilon-zero/olist`, implement it instead in terms of
; algebras which those can be a special case of.

;(provide #/all-defined-out)


(struct-easy (poppable-hyperstack nested-olist))

(define/contract (poppable-hyperstack-dimension h)
  (-> poppable-hyperstack? onum?)
  (dissect h (poppable-hyperstack olist)
  ; TODO NOW: We've changed `olist-length` to return an `onumext?`.
  ; Update this call.
  #/olist-length olist))

(define/contract (poppable-hyperstack-peek-elem h i)
  (->i ([h poppable-hyperstack?] [i onum?])
    #:pre (h i) (onum<? i #/poppable-hyperstack-dimension h)
    [_ any/c])
  (dissect h (poppable-hyperstack olist)
  #/dissect (olist-ref-and-call olist i) (list elem olist-suffix)
    elem))

(define/contract (make-poppable-hyperstack elems)
  (-> olist? poppable-hyperstack?)
  (poppable-hyperstack #/olist-map elems #/fn elem
    (list elem olist-zero)))

(define/contract (poppable-hyperstack-pop h elems-to-push)
  (->i ([h poppable-hyperstack?] [elems-to-push olist?])
    
    #:pre (h elems-to-push)
    (onum<?
      ; TODO NOW: We've changed `olist-length` to return an `onumext?`.
      ; Update this call.
      (olist-length elems-to-push)
      (poppable-hyperstack-dimension h))
    
    [_ (list/c any/c poppable-hyperstack?)])
  (dissect h (poppable-hyperstack olist)
  ; TODO NOW: We've changed `olist-length` to return an `onumext?`.
  ; Update this call.
  #/w- i (olist-length elems-to-push)
  #/dissect (olist-ref-and-call olist i) (list elem olist-suffix)
  #/dissect (olist-drop i #/olist-tails olist) (just #/list tails _)
  #/list elem #/poppable-hyperstack #/olist-plus
    (olist-zip-map elems-to-push tails #/fn elem tail
      (list elem tail))
    olist-suffix))
