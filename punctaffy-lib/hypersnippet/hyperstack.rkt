#lang parendown racket/base

; punctaffy/hypersnippet/hyperstack
;
; Data structures to help with traversing a sequence of brackets of
; various degrees to manipulate hypersnippet-shaped data.

;   Copyright 2018 The Lathe Authors
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


(require #/only-in racket/contract/base -> ->i any/c list/c or/c)
(require #/only-in racket/contract/region define/contract)

(require lathe-debugging)

(require #/only-in lathe-comforts dissect dissectfn expect fn mat w-)
(require #/only-in lathe-comforts/maybe just)
(require #/only-in lathe-comforts/struct struct-easy)
(require #/only-in lathe-comforts/trivial trivial)
(require #/only-in lathe-ordinals
  onum<? onum</c onum-drop onum<e0? onum<=e0? onum-max)
(require #/only-in lathe-ordinals/olist
  olist-drop olist<=e0? olist<e0? olist-build olist-length olist-map
  olist-tails olist-plus olist-ref-and-call olist-zip-map olist-zero)

; TODO: Document all of these exports.
(provide
  make-poppable-hyperstack
  poppable-hyperstack-dimension
  poppable-hyperstack-pop
  
  make-poppable-hyperstack-n
  poppable-hyperstack-pop-n-with-barrier
  poppable-hyperstack-pop-n
  
  make-pushable-hyperstack
  pushable-hyperstack-dimension
  pushable-hyperstack-peek-elem
  pushable-hyperstack-push
  pushable-hyperstack-pop
  
  pushable-hyperstack-push-uniform)


(struct-easy (poppable-hyperstack nested-olist))

(define/contract (make-poppable-hyperstack elems)
  (-> olist<=e0? poppable-hyperstack?)
  (poppable-hyperstack #/olist-map elems #/fn elem
    (list 'root elem #/olist-zero)))

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
  #/dissect (olist-ref-and-call olist i)
    (list barrier elem olist-suffix)
    elem))

; TODO: See if we'll ever use the `popped-barrier` result of this
; procedure. We've added it just for consistency with
; `pushable-hyperstack-pop`, the only place we've used it so far is
; the place we use `poppable-hyperstack-pop-n-with-barrier`. It has
; also provided a little bit more information during debugging.
;
(define/contract (poppable-hyperstack-pop h elems-to-push)
  (->i ([h poppable-hyperstack?] [elems-to-push olist<e0?])
    
    #:pre (h elems-to-push)
    (onum<?
      (olist-length elems-to-push)
      (poppable-hyperstack-dimension h))
    
    [_ (list/c (or/c 'root 'pop) any/c poppable-hyperstack?)])
  (dissect h (poppable-hyperstack olist)
  #/w- i (olist-length elems-to-push)
  #/dissect (olist-ref-and-call olist i)
    (list popped-barrier elem olist-suffix)
  #/dissect (olist-drop i #/olist-tails olist) (just #/list tails _)
  #/list popped-barrier elem #/poppable-hyperstack #/olist-plus
    (olist-zip-map elems-to-push tails #/fn elem tail
      (list 'pop elem tail))
    olist-suffix))

(define/contract (make-poppable-hyperstack-n dimension)
  (-> onum<=e0? poppable-hyperstack?)
  (make-poppable-hyperstack
  #/olist-build dimension #/dissectfn _ #/trivial))

(define/contract (poppable-hyperstack-pop-n-with-barrier h i)
  (->i
    (
      [h poppable-hyperstack?]
      [i (h) (onum</c #/poppable-hyperstack-dimension h)])
    [_ (list/c (or/c 'root 'pop) poppable-hyperstack?)])
  (dissect
    (poppable-hyperstack-pop h
    #/olist-build i #/dissectfn _ #/trivial)
    (list popped-barrier elem rest)
  #/list popped-barrier rest))

(define/contract (poppable-hyperstack-pop-n h i)
  (->i
    (
      [h poppable-hyperstack?]
      [i (h) (onum</c #/poppable-hyperstack-dimension h)])
    [_ poppable-hyperstack?])
  (dissect (poppable-hyperstack-pop-n-with-barrier h i)
    (list popped-barrier rest)
    rest))


(struct-easy (pushable-hyperstack nested-olist))

(define/contract (make-pushable-hyperstack elems)
  (-> olist<=e0? pushable-hyperstack?)
  (pushable-hyperstack #/olist-map elems #/fn elem
    (list 'root elem #/olist-zero)))

(define/contract (pushable-hyperstack-dimension h)
  (-> pushable-hyperstack? onum<=e0?)
  (dissect h (pushable-hyperstack olist)
  #/olist-length olist))

(define/contract (pushable-hyperstack-peek-elem h i)
  (->i
    (
      [h pushable-hyperstack?]
      [i (h) (onum</c #/pushable-hyperstack-dimension h)])
    [_ any/c])
  (dissect h (pushable-hyperstack olist)
  #/dissect (olist-ref-and-call olist i)
    (list barrier elem olist-suffix)
    elem))

(define/contract (pushable-hyperstack-push h elems-to-push)
  (-> pushable-hyperstack? olist<=e0? pushable-hyperstack?)
  (dissect h (pushable-hyperstack olist)
  #/w- i (olist-length elems-to-push)
  #/w- tails (olist-tails olist)
  #/dissect
    (mat (olist-drop i olist) (just dropped-and-rest)
      (dissect dropped-and-rest (list _ rest)
      #/dissect (olist-drop i tails) (just #/list tails _)
      #/list tails rest)
    #/dissect (onum-drop (olist-length tails) i) (just excess)
    #/list
      (olist-plus tails #/olist-build excess #/dissectfn _
        (olist-zero))
      (olist-zero))
    (list tails rest)
  #/pushable-hyperstack #/olist-plus
    (olist-zip-map elems-to-push tails #/fn elem tail
      (list 'push elem tail))
    rest))

(define/contract (pushable-hyperstack-pop h elems-to-push)
  (->i ([h pushable-hyperstack?] [elems-to-push olist<e0?])
    
    #:pre (h elems-to-push)
    (onum<?
      (olist-length elems-to-push)
      (pushable-hyperstack-dimension h))
    
    [_ (list/c (or/c 'root 'push 'pop) any/c pushable-hyperstack?)])
  (dissect h (pushable-hyperstack olist)
  #/w- i (olist-length elems-to-push)
  #/dissect (olist-ref-and-call olist i)
    (list popped-barrier elem olist-suffix)
  #/dissect (olist-drop i #/olist-tails olist) (just #/list tails _)
  #/list popped-barrier elem #/pushable-hyperstack #/olist-plus
    (olist-zip-map elems-to-push tails #/fn elem tail
      (list 'pop elem tail))
    olist-suffix))

(define/contract (pushable-hyperstack-push-uniform h bump-degree elem)
  (-> pushable-hyperstack? onum<=e0? any/c pushable-hyperstack?)
  (pushable-hyperstack-push h #/olist-build bump-degree #/dissectfn _
    elem))
