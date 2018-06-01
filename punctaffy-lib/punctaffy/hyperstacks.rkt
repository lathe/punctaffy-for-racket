#lang parendown racket/base


(require #/only-in racket/contract/base -> ->i any/c list/c)
(require #/only-in racket/contract/region define/contract)

(require #/only-in lathe-comforts dissect dissectfn expect fn w-)
(require #/only-in lathe-comforts/maybe just)
(require #/only-in lathe-comforts/struct struct-easy)
(require #/only-in lathe-ordinals
  onum<? onum</c onum-drop onum<e0? onum<=e0?)
(require #/only-in lathe-ordinals/olist
  olist-drop olist<=e0? olist<e0? olist-build olist-length olist-map
  olist-tails olist-plus olist-ref-and-call olist-zip-map olist-zero)

; TODO: Document all of these exports.
(provide
  make-poppable-hyperstack
  poppable-hyperstack-dimension
  poppable-hyperstack-pop
  poppable-hyperstack-promote
  
  make-poppable-hyperstack-n
  poppable-hyperstack-pop-n)


(struct-easy (poppable-hyperstack nested-olist))

(define/contract (make-poppable-hyperstack elems)
  (-> olist<=e0? poppable-hyperstack?)
  (poppable-hyperstack #/olist-map elems #/fn elem
    (list elem #/olist-zero)))

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

(define/contract (poppable-hyperstack-promote h dimension elem)
  (-> poppable-hyperstack? onum<=e0? any/c poppable-hyperstack?)
  (dissect h (poppable-hyperstack olist)
  #/expect (onum-drop (olist-length olist) dimension) (just excess) h
  #/poppable-hyperstack
  #/olist-plus olist #/olist-build excess #/dissectfn _
    (list elem #/olist-zero)))

(define/contract (make-poppable-hyperstack-n dimension)
  (-> onum<=e0? poppable-hyperstack?)
  (make-poppable-hyperstack
  #/olist-build dimension #/dissectfn _ #/list))

(define/contract (poppable-hyperstack-pop-n h i)
  (->i
    (
      [h poppable-hyperstack?]
      [i (h) (onum</c #/poppable-hyperstack-dimension h)])
    [_ poppable-hyperstack?])
  (dissect
    (poppable-hyperstack-pop h
    #/olist-build i #/dissectfn _ #/list)
    (list elem rest)
    rest))
