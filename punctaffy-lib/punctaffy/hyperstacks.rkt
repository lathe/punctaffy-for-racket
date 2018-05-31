#lang parendown racket/base


(require #/only-in racket/contract/base -> ->i any/c list/c)
(require #/only-in racket/contract/region define/contract)

(require #/only-in lathe-comforts dissect fn w-)
(require #/only-in lathe-comforts/maybe just)
(require #/only-in lathe-comforts/struct struct-easy)
(require #/only-in lathe-ordinals onum<? onum</c onum<e0? onum<=e0?)
(require #/only-in lathe-ordinals/olist
  olist-drop olist<=e0? olist<e0? olist-length olist-map olist-tails
  olist-plus olist-ref-and-call olist-zip-map olist-zero)

;(provide #/all-defined-out)


(struct-easy (poppable-hyperstack nested-olist))

(define/contract (poppable-hyperstack-dimension h)
  (-> poppable-hyperstack? onum<=e0?)
  (dissect h (poppable-hyperstack olist)
  #/olist-length olist))

(define/contract (poppable-hyperstack-peek-elem h i)
  (->i
    (
      [h poppable-hyperstack?]
      [i (h) (onum</c #/poppable-hyperstack-dimension h)])
    [_ any/c])
  (dissect h (poppable-hyperstack olist)
  #/dissect (olist-ref-and-call olist i) (list elem olist-suffix)
    elem))

(define/contract (make-poppable-hyperstack elems)
  (-> olist<=e0? poppable-hyperstack?)
  (poppable-hyperstack #/olist-map elems #/fn elem
    (list elem #/olist-zero)))

(define/contract (poppable-hyperstack-pop h elems-to-push)
  (->i ([h poppable-hyperstack?] [elems-to-push olist<e0?])
    
    #:pre (h elems-to-push)
    (onum<?
      (olist-length elems-to-push)
      (poppable-hyperstack-dimension h))
    
    [_ (list/c any/c poppable-hyperstack?)])
  (dissect h (poppable-hyperstack olist)
  #/w- i (olist-length elems-to-push)
  #/dissect (olist-ref-and-call olist i) (list elem olist-suffix)
  #/dissect (olist-drop i #/olist-tails olist) (just #/list tails _)
  #/list elem #/poppable-hyperstack #/olist-plus
    (olist-zip-map elems-to-push tails #/fn elem tail
      (list elem tail))
    olist-suffix))
