#lang parendown racket/base

; punctaffy/hypersnippet/hypernest
;
; A data structure for encoding hypersnippet notations that can nest
; with themselves.

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


(require #/only-in racket/contract/base
  -> any any/c contract? list/c listof or/c)
(require #/only-in racket/contract/region define/contract)

(require lathe-debugging)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/hash hash-ref-maybe)
(require #/only-in lathe-comforts/list list-kv-map)
(require #/only-in lathe-comforts/maybe
  just maybe? maybe-bind maybe/c maybe-map nothing)
(require #/only-in lathe-comforts/struct istruct/c struct-easy)
(require #/only-in lathe-comforts/trivial trivial)
(require #/only-in lathe-ordinals
  onum<=? onum<? onum-max 0<onum<=omega? onum<=omega? onum<omega?)
(require #/only-in lathe-ordinals/olist
  olist-build olist-drop olist-length olist-plus olist-ref-and-call
  olist-zero)

(require #/only-in punctaffy/hypersnippet/hypertee
  hypertee? hypertee-bind-all-degrees hypertee-contour hypertee-degree
  hypertee-drop1 hypertee-dv-each-all-degrees
  hypertee-dv-fold-map-any-all-degrees hypertee-dv-map-all-degrees
  hypertee-each-all-degrees hypertee-get-hole-zero hypertee<omega?
  hypertee-plus1 hypertee-zip-low-degrees hypertee-zip-selective)

(provide
  (struct-out hypernest-coil-zero)
  (struct-out hypernest-coil-hole)
  (struct-out hypernest-coil-bump)
  hypernest-bracket-degree
  (rename-out [-hypernest? hypernest?])
  hypernest-degree
  degree-and-brackets->hypernest
  hypernest-promote
  hypernest-set-degree
  hypernest<omega?
  hypertee->hypernest
  hypernest->maybe-hypertee
  hypernest-truncate-to-hypertee
  hypernest-contour
  hypernest-zip
  hypernest-drop1
  hypernest-dv-map-all-degrees
  hypernest-map-all-degrees
  hypernest-pure
  hypernest-join-all-degrees
  hypernest-dv-bind-all-degrees
  hypernest-bind-all-degrees
  hypernest-bind-one-degree
  hypernest-join-one-degree
  hypernest-plus1)


; ===== Hypernests ===================================================

(struct-easy (hypernest-coil-zero) #:equal)
(struct-easy (hypernest-coil-hole overall-degree data tails-hypertee)
  #:equal)
(struct-easy
  (hypernest-coil-bump
    overall-degree data bump-degree tails-hypernest)
  #:equal)

; TODO: Give this a custom writer that uses a sequence-of-brackets
; representation.
(struct-easy (hypernest coil) #:equal)

(define/contract (hypernest-coil/c)
  (-> contract?)
  (or/c
    (istruct/c hypernest-coil-zero)
    (istruct/c hypernest-coil-hole 0<onum<=omega? any/c hypertee?)
    (istruct/c hypernest-coil-bump
      0<onum<=omega? any/c onum<=omega? hypernest?)))

(define/contract (hypernest-bracket-degree bracket)
  (->
    (or/c
      onum<omega?
      (list/c onum<omega? any/c)
      (list/c 'open onum<=omega? any/c))
    onum<omega?)
  (mat bracket (list 'open d data)
    d
  #/mat bracket (list d data)
    d
    bracket))

(define (olist-replace-first-n n elem lst)
  (olist-plus
    (olist-build n #/dissectfn _ elem)
    (expect (olist-drop n lst) (just dropped-and-rest) (olist-zero)
    #/dissect dropped-and-rest (list dropped rest)
      rest)))

(define (hypernest-careful coil)
  (assert-valid-hypernest-coil coil)
  (hypernest coil))

(define/contract
  (degree-and-brackets->hypernest opening-degree hypernest-brackets)
  (->
    onum<=omega?
    (listof #/or/c
      onum<omega?
      (list/c onum<omega? any/c)
      (list/c 'open onum<=omega? any/c))
    hypernest?)
  
  (struct-easy (part-state-hypertee-zero))
  (struct-easy
    (part-state-hypertee-hole
      first-nontrivial-d parents data tails-hypertee-i))
  (struct-easy (part-state-hypernest-zero))
  (struct-easy
    (part-state-hypernest-hole
      first-nontrivial-d parents data tails-hypertee-i))
  (struct-easy
    (part-state-hypernest-bump
      first-nontrivial-d parents data bump-degree tails-hypernest-i))
  
  (w- root-i 'root
  #/w-loop next
    
    hypernest-brackets-remaining
    (list-kv-map hypernest-brackets #/fn k v #/list k v)
    
    parts (make-immutable-hasheq)
    in-hypernest #t
    current-i root-i
    first-nontrivial-d 0
    parents (olist-build opening-degree #/dissectfn _ #/nothing)
    
    (w- current-d (olist-length parents)
    #/expect hypernest-brackets-remaining
      (cons hypernest-bracket hypernest-brackets-remaining)
      (expect current-d 0
        (error "Expected more closing brackets")
      #/w- parts
        (hash-set parts current-i
          (if in-hypernest
            (part-state-hypernest-zero)
            (part-state-hypertee-zero)))
      #/let ()
        (define (get-part i)
          (w- part (hash-ref parts i)
          #/mat part (part-state-hypernest-zero)
            (hypernest-careful #/hypernest-coil-zero)
          #/mat part
            (part-state-hypernest-hole
              first-nontrivial-d parents data tails-hypertee-i)
            (hypernest-careful
            #/hypernest-coil-hole (olist-length parents) data
            #/get-part tails-hypertee-i)
          #/mat part
            (part-state-hypernest-bump
              first-nontrivial-d parents data bump-degree
              tails-hypernest-i)
            (hypernest-careful
            #/hypernest-coil-bump (olist-length parents) data
              bump-degree
            #/get-part tails-hypernest-i)
          #/mat part (part-state-hypertee-zero)
            (hypertee-plus1 #/nothing)
          #/mat part
            (part-state-hypernest-hole
              first-nontrivial-d parents data tails-hypertee-i)
            (hypertee-plus1
            #/just #/list data #/get-part tails-hypertee-i)
          #/error "Internal error: Encountered an unrecognized part state"))
      #/get-part root-i)
    #/dissect hypernest-bracket (list new-i bracket)
    #/mat bracket (list 'open bracket-d bump-value)
      (expect in-hypernest #t
        (error "Encountered a bump inside a hole")
      #/next
        hypernest-brackets-remaining
        (hash-set parts current-i
          (part-state-hypernest-bump
            first-nontrivial-d parents bump-value bracket-d new-i))
        #t
        new-i
        (onum-max first-nontrivial-d bracket-d)
        (olist-replace-first-n bracket-d current-i parents))
    #/dissect
      (mat bracket (list bracket-d hole-value)
        (expect (onum<? bracket-d current-d) #t
          (error "Encountered a closing bracket of degree too high for where it occurred")
        #/expect (onum<=? first-nontrivial-d bracket-d) #t
          (error "Encountered an annotated closing bracket of degree too low for where it occurred")
        #/list bracket-d hole-value)
        (expect (onum<? bracket first-nontrivial-d) #t
          (error "Encountered an unannotated closing bracket of degree too high for where it occurred")
        #/list bracket (trivial)))
      (list bracket-d hole-value)
    #/w- parent-i (olist-ref-and-call parents bracket-d)
    ; TODO NOW: Figure out what to do when `parent-i` is `(nothing)`.
    #/w- parent (dlog "blah a1" #/hash-ref parts parent-i)
    #/w- parts
      (hash-set parts current-i
        (if in-hypernest
          (part-state-hypernest-hole
            first-nontrivial-d parents hole-value new-i)
          (part-state-hypertee-hole
            first-nontrivial-d parents hole-value new-i)))
    #/mat parent
      (part-state-hypernest-hole
        restored-first-nontrivial-d restored-parents data
        tails-hypertee-i)
      (next hypernest-brackets-remaining parts #t new-i
        (onum-max restored-first-nontrivial-d bracket-d)
        (olist-replace-first-n bracket-d current-i
          restored-parents))
    #/mat parent
      (part-state-hypernest-bump
        restored-first-nontrivial-d restored-parents data
        bump-degree tails-hypernest-i)
      (next hypernest-brackets-remaining parts #t new-i
        (onum-max restored-first-nontrivial-d bracket-d)
        (olist-replace-first-n bracket-d current-i
          restored-parents))
    #/dissect parent
      (part-state-hypernest-hole
        restored-first-nontrivial-d restored-parents data
        tails-hypertee-i)
      (next hypernest-brackets-remaining parts #f new-i
        (onum-max restored-first-nontrivial-d bracket-d)
        (olist-replace-first-n bracket-d current-i
          restored-parents)))))

; TODO: Implement this.
#;
(define/contract (hypernest->brackets hn)
  (-> hypernest?
    (listof #/or/c
      onum<omega?
      (list/c onum<omega? any/c)
      (list/c 'open onum<=omega? any/c)))
  'TODO)

(define/contract (assert-valid-hypernest-coil coil)
  (-> (hypernest-coil/c) void?)
  (mat coil (hypernest-coil-zero) (void)
  #/mat coil
    (hypernest-coil-hole overall-degree hole-value tails-hypertee)
    ; NOTE: We don't validate `hole-value`.
    (expect
      (onum<? (hypertee-degree tails-hypertee) overall-degree)
      #t
      (error "Expected the tails of a hypernest-coil-hole to be a hypertee of degree strictly less than the overall degree")
    #/hypertee-each-all-degrees tails-hypertee #/fn hole tail
      (w- hole-degree (hypertee-degree hole)
      #/expect (hypernest? tail) #t
        (error "Expected each tail of a hypernest-coil-hole to be a hypernest")
      #/expect (equal? (hypernest-degree tail) overall-degree) #t
        (error "Expected each tail of a hypernest-coil-hole to be a hypernest of the same degree as the overall degree")
      #/expect
        (hypertee-zip-low-degrees hole
          (hypernest-truncate-to-hypertee tail)
        #/fn hole-hole hole-data tail-data
          (expect tail-data (trivial)
            (error "Expected each tail of a hypernest-coil-hole to have trivial values in its low-degree holes")
          #/trivial))
        (just zipped)
        (error "Expected each tail of a hypernest-coil-hole to match up with the hole it occurred in")
      #/void))
  #/dissect coil
    (hypernest-coil-bump
      overall-degree bump-value bump-degree tails-hypernest)
    ; NOTE: We don't validate `bump-value`.
    (hypernest-each-all-degrees tails-hypernest #/fn hole data
      (w- hole-degree (hypertee-degree hole)
      #/when (onum<? hole-degree bump-degree)
        (expect (hypernest? data) #t
          (error "Expected each tail of a hypernest-coil-bump to be a hypernest")
        #/expect
          (equal?
            (hypernest-degree data)
            (onum-max hole-degree overall-degree))
          #t
          (error "Expected each tail of a hypernest-coil-bump to be a hypernest of the same degree as the overall degree or of the same degree as the hole it occurred in, whichever was greater")
        #/expect
          (hypertee-zip-low-degrees hole
            (hypernest-truncate-to-hypertee data)
          #/fn hole-hole hole-data tail-data
            (expect tail-data (trivial)
              (error "Expected each tail of a hypernest-coil-bump to have trivial values in its low-degree holes")
            #/trivial))
          (just zipped)
          (error "Expected each tail of a hypernest-coil-bump to match up with the hole it occurred in")
        #/void)))))

; A version of `hypernest?` that does not satisfy
; `struct-predicate-procedure?`.
(define/contract (-hypernest? v)
  (-> any/c boolean?)
  (hypernest? v))

; A version of the `hypernest` constructor that does not satisfy
; `struct-constructor-procedure?`.
(define/contract (hypernest-plus1 coil)
  (-> (hypernest-coil/c) hypernest?)
  ; TODO: See if we can improve the error messages so that they're
  ; like part of the contract of this procedure instead of being
  ; thrown from inside `hypernest-careful`.
  (hypernest-careful coil))

(define/contract (hypernest-degree hn)
  (-> hypernest? onum<=omega?)
  (dissect hn (hypernest coil)
  #/mat coil (hypernest-coil-zero) 0
  #/mat coil (hypernest-coil-hole d data tails) d
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    overall-degree))

; TODO: Uncomment this once `hypernest->brackets` has been
; implemented.
#;
(define/contract (hypernest->degree-and-brackets hn)
  (-> hypertee?
    (list/c onum<=omega?
    #/listof #/or/c
      onum<omega?
      (list/c onum<omega? any/c)
      (list/c 'open onum<=omega? any/c)))
  (list (hypernest-degree hn) (hypernest->brackets hn)))

; Takes a hypernest of any nonzero degree N and upgrades it to any
; degree N or greater, while leaving its bumps and holes the way they
; are.
(define/contract (hypernest-promote new-degree hn)
  (-> onum<=omega? hypernest? hypernest?)
  (dissect hn (hypernest coil)
  #/mat coil (hypernest-coil-zero)
    (error "Expected hn to be a hypernest of nonzero degree")
  #/expect (onum<=? (hypernest-degree hn) new-degree) #t
    (raise-arguments-error 'hypernest-promote
      "expected hn to be a hypernest of degree no greater than new-degree"
      "new-degree" new-degree
      "hn" hn)
  #/mat coil (hypernest-coil-hole d data tails)
    (if (equal? d new-degree) hn
    #/hypernest-careful #/hypernest-coil-hole new-degree data
    #/hypertee-dv-map-all-degrees tails #/fn d tail
      (hypernest-promote new-degree tail))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (if (equal? overall-degree new-degree) hn
    #/hypernest-careful
    #/hypernest-coil-bump new-degree data bump-degree
    #/hypernest-dv-map-all-degrees tails #/fn d data
      (if (onum<? d bump-degree)
        (hypernest-set-degree (onum-max d new-degree) data)
        data))))

; Takes a nonzero-degree hypernest with no holes of degree N or
; greater and returns a degree-N hypernest with the same bumps and
; holes.
(define/contract (hypernest-set-degree new-degree hn)
  (-> onum<=omega? hypernest? hypernest?)
  (dissect hn (hypernest coil)
  #/mat coil (hypernest-coil-zero)
    (error "Expected hn to be a hypernest of nonzero degree")
  #/mat coil (hypernest-coil-hole d data tails)
    (if (equal? d new-degree) hn
    #/expect (onum<? (hypertee-degree tails) new-degree) #t
      (raise-arguments-error 'hypernest-set-degree
        "expected hn to have no holes of degree new-degree or greater"
        "hn" hn
        "new-degree" new-degree
        "hole-degree" (hypertee-degree tails)
        "data" data)
    #/hypernest-careful #/hypernest-coil-hole new-degree data
    #/hypertee-dv-map-all-degrees tails #/fn d tail
      (hypernest-set-degree new-degree tail))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (if (equal? overall-degree new-degree) hn
    #/hypernest-careful
    #/hypernest-coil-bump new-degree data bump-degree
    #/hypernest-dv-map-all-degrees tails #/fn d data
      (if (onum<? d bump-degree)
        (hypernest-set-degree (onum-max d new-degree) data)
        data))))

(define/contract (hypernest<omega? v)
  (-> any/c boolean?)
  (and (hypernest? v) (onum<omega? #/hypernest-degree v)))

(define/contract (hypertee->hypernest ht)
  (-> hypertee? hypernest?)
  (expect (hypertee-drop1 ht) (just data-and-tails)
    (hypernest-careful #/hypernest-coil-zero)
  #/dissect data-and-tails (list data tails)
  #/hypernest-careful #/hypernest-coil-hole (hypertee-degree ht) data
  #/hypertee-dv-map-all-degrees tails #/fn d tail
    (hypertee->hypernest tail)))

(define/contract (hypernest->maybe-hypertee hn)
  (-> hypernest? #/maybe/c hypertee?)
  (dissect hn (hypernest coil)
  #/mat coil (hypernest-coil-zero)
    (just #/hypertee-plus1 #/nothing)
  #/mat coil (hypernest-coil-hole d data tails)
    (dissect
      (hypertee-dv-fold-map-any-all-degrees (trivial) tails
      #/fn state d tail
        (list state #/hypernest->maybe-hypertee tail))
      (list (trivial) maybe-tails)
    #/maybe-map maybe-tails #/fn tails
    #/hypertee-plus1 #/just #/list d tails)
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (nothing)))

(define/contract (hypernest-truncate-to-hypertee hn)
  (-> hypernest? hypertee?)
  (dissect hn (hypernest coil)
  #/mat coil (hypernest-coil-zero)
    (hypertee-plus1 #/nothing)
  #/mat coil (hypernest-coil-hole d data tails)
    (hypertee-plus1 #/just #/list d
    #/hypertee-dv-map-all-degrees tails #/fn d tail
      (hypernest-truncate-to-hypertee tail))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (hypertee-bind-all-degrees
      (hypernest-truncate-to-hypertee tails)
    #/fn hole data
      (if (onum<? (hypertee-degree hole) bump-degree)
        (hypernest-truncate-to-hypertee data)
        (hypernest-pure overall-degree data hole)))))

; Takes a hypertee of any degree N and returns a hypernest of degree
; N+1 with all the same degree-less-than-N holes as well as a single
; degree-N hole in the shape of the original hypertee. This should
; be useful as something like a monadic return.
(define/contract (hypernest-contour hole-value ht)
  (-> any/c hypertee<omega? hypernest?)
  (hypertee->hypernest #/hypertee-contour hole-value ht))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/contract
  (hypernest-dv-fold-map-any-all-degrees state hn on-hole)
  (->
    any/c
    hypernest?
    (-> any/c onum<omega? any/c #/list/c any/c #/maybe/c any/c)
    (list/c any/c #/maybe/c hypernest?))
  (dissect hn (hypernest coil)
  #/mat coil (hypernest-coil-zero)
    (list state #/just #/hypernest-careful #/hypernest-coil-zero)
  #/mat coil (hypernest-coil-hole d data tails)
    (dissect (on-hole state (hypertee-degree tails) data)
      (list state maybe-data)
    #/expect maybe-data (just data) (list state #/nothing)
    #/dissect
      (hypertee-dv-fold-map-any-all-degrees state tails
      #/fn state tails-hole-d tail
        (hypernest-dv-fold-map-any-all-degrees state tail
        #/fn state tail-hole-d data
          (if (onum<? tail-hole-d tails-hole-d)
            (dissect data (trivial)
            #/list state #/just #/trivial)
          #/on-hole state tail-hole-d data)))
      (list state maybe-tails)
    #/expect maybe-tails (just tails) (list state #/nothing)
    #/list state
      (just #/hypernest-careful #/hypernest-coil-hole d data tails))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (dissect
      (hypernest-dv-fold-map-any-all-degrees state tails
      #/fn state tails-hole-d data
        (if (onum<? tails-hole-d bump-degree)
          (hypernest-dv-fold-map-any-all-degrees state data
          #/fn state tail-hole-d data
            (if (onum<? tail-hole-d tails-hole-d)
              (dissect data (trivial)
              #/list state #/just #/trivial)
            #/on-hole state tail-hole-d data))
          (on-hole state tails-hole-d data)))
      (list state maybe-tails)
    #/expect maybe-tails (just tails) (list state #/nothing)
    #/list state
      (just #/hypernest-careful
      #/hypernest-coil-bump overall-degree data bump-degree tails))))

; This zips a degree-N hypertee with a same-degree-or-higher hypernest
; if they have the same holes when certain holes of the hypernest are
; removed -- namely, the holes of degree N or greater and the holes
; that don't match the given predicate.
;
; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
(define/contract
  (hypernest-zip-selective smaller bigger should-zip? func)
  (->
    hypertee?
    hypernest?
    (-> hypertee? any/c boolean?)
    (-> hypertee? any/c any/c any/c)
    (maybe/c hypernest?))
  (expect (onum<=? (hypertee-degree smaller) (hypernest-degree bigger)) #t
    (error "Expected smaller to be a hypertee of degree no greater than bigger's degree")
  #/w- bigger
    (hypernest-dv-fold-map-any-all-degrees 0 bigger #/fn i d data
      (list (add1 i) #/just #/list i data))
  #/maybe-map
    (hypertee-zip-selective
      smaller
      (hypernest-truncate-to-hypertee bigger)
      (fn hole entry
        (dissect entry (list i data)
        #/should-zip? hole data))
      (fn hole smaller-data entry
        (dissect entry (list i bigger-data)
        #/list i #/func hole smaller-data bigger-data)))
  #/fn zipped
  #/dissect
    (hypernest-dv-fold-map-any-all-degrees
      (make-immutable-hasheq)
      zipped
    #/fn hash d entry
      (dissect entry (list i data)
      #/list (hash-set hash i data) #/just entry))
    (list hash #/just _)
  #/hypernest-dv-map-all-degrees bigger #/fn d entry
    (dissect entry (list i original-data)
    #/mat (hash-ref-maybe hash i) (just zipped-data) zipped-data
      original-data)))

; This zips a degree-N hypertee with a same-degree-or-higher hypernest
; if they have the same holes when truncated to degree N.
;
; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
(define/contract (hypernest-zip-low-degrees smaller bigger func)
  (-> hypertee? hypernest? (-> hypertee? any/c any/c any/c)
    (maybe/c hypernest?))
  (hypernest-zip-selective smaller bigger (fn hole data #t) func))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/contract (hypernest-zip ht hn func)
  (-> hypertee? hypernest? (-> hypertee? any/c any/c any/c)
    (maybe/c hypernest?))
  (expect (equal? (hypertee-degree ht) (hypernest-degree hn)) #t
    (error "Expected the hypertee and the hypernest to have the same degree")
  #/hypernest-zip-low-degrees ht hn func))

(define/contract (hypernest-drop1 hn)
  (-> hypernest? (hypernest-coil/c))
  (dissect hn (hypernest coil)
    coil))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/contract (hypernest-dgv-map-all-degrees hn func)
  (-> hypernest? (-> onum<omega? (-> hypertee<omega?) any/c any/c)
    hypernest?)
  (dissect hn (hypernest coil)
  #/mat coil (hypernest-coil-zero)
    (hypernest-careful #/hypernest-coil-zero)
  #/mat coil (hypernest-coil-hole d data tails)
    (hypernest-careful #/hypernest-coil-hole d
      (func
        (hypertee-degree tails)
        (fn #/hypertee-dv-map-all-degrees tails #/fn d tail #/trivial)
        data)
    #/hypertee-dv-map-all-degrees tails #/fn tails-hole-d tail
      (hypernest-dv-map-all-degrees tail #/fn tail-hole-d data
        (if (onum<? tail-hole-d tails-hole-d)
          (dissect data (trivial)
          #/trivial)
        #/func tail-hole-d data)))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (hypernest-careful
    #/hypernest-coil-bump overall-degree data bump-degree
    #/hypernest-dgv-map-all-degrees tails
    #/fn tails-hole-d get-tails-hole data
      (if (onum<? tails-hole-d bump-degree)
        (hypernest-dgv-map-all-degrees data
        #/fn tail-hole-d get-tail-hole data
          (if (onum<? tail-hole-d tails-hole-d)
            (dissect data (trivial)
            #/trivial)
          #/func tail-hole-d get-tail-hole data))
        (func tails-hole-d get-tails-hole data)))))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/contract (hypernest-dv-map-all-degrees hn func)
  (-> hypernest? (-> onum<omega? any/c any/c) hypernest?)
  (hypernest-dgv-map-all-degrees hn #/fn d get-hole data
    (func d data)))

; TODO IMPLEMENT: Implement operations analogous to these:
;
;   hypertee-v-map-one-degree
;   hypertee-fold
;   hypertee-dv-join-all-degrees-selective

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/contract (hypernest-map-all-degrees hn func)
  (-> hypernest? (-> hypertee<omega? any/c any/c) hypernest?)
  (hypernest-dgv-map-all-degrees hn #/fn d get-hole data
    (func (get-hole) data)))

; TODO IMPLEMENT: Implement operations analogous to these:
;
;   hypertee-map-one-degree
;   hypertee-map-pred-degree
;   hypertee-map-highest-degree

(define/contract (hypernest-pure degree data hole)
  (-> onum<=omega? any/c hypertee<omega? hypernest?)
  (hypernest-promote degree #/hypernest-contour data hole))

(define/contract (hypernest-get-hole-zero hn)
  (-> hypernest? maybe?)
  (dissect hn (hypernest coil)
  #/mat coil (hypernest-coil-zero)
    (nothing)
  #/mat coil (hypernest-coil-hole d data tails)
    (maybe-bind (hypertee-get-hole-zero tails) #/fn tail
    #/hypernest-get-hole-zero tail)
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (maybe-bind (hypernest-get-hole-zero tails) #/fn tail
    #/hypernest-get-hole-zero tail)))

; TODO IMPLEMENT: Implement operations analogous to these:
;
;   hypertee-bind-pred-degree
;   hypertee-bind-highest-degree

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/contract (hypernest-join-all-degrees hn)
  (-> hypernest? hypernest?)
  (dissect hn (hypernest coil)
  #/mat coil (hypernest-coil-zero)
    (hypernest-careful #/hypernest-coil-zero)
  #/dissect (hypertee-get-hole-zero hn) (just tail0)
  #/dissect (hypernest-get-hole-zero tail0) (just interpolation0)
  #/w- result-degree (hypernest-degree interpolation0)
  #/expect (hypernest? interpolation0) #t
    (raise-arguments-error 'hypernest-join-all-degrees
      "expected the degree-0 interpolation to be a hypernest"
      "hn" hn
      "interpolation0" interpolation0)
  #/mat coil (hypernest-coil-hole d interpolation tails)
    ; TODO: Make sure the recursive calls to
    ; `hypernest-join-all-degrees` we make here always terminate. If
    ; they don't, we need to take a different approach.
    (expect (hypernest? interpolation) #t
      (raise-arguments-error 'hypernest-join-all-degrees
        "expected each interpolation to be a hypernest"
        "hn" hn
        "root-hole-degree" (hypertee-degree tails)
        "interpolation" interpolation)
    #/expect
      (equal? result-degree (hypernest-degree interpolation))
      #t
      (raise-arguments-error 'hypernest-join-all-degrees
        "expected every interpolation to have the same degree as the degree-0 interpolation"
        "hn" hn
        "root-hole-degree" (hypertee-degree tails)
        "interpolation" interpolation
        "degree-zero-interpolation" interpolation0)
    #/expect
      (hypernest-zip tails interpolation
      #/fn tails-hole tail interpolation-data
        (expect interpolation-data (trivial)
          (error "Expected each low-degree hole of each interpolation to contain a trivial value")
        #/hypernest-join-all-degrees
        #/hypernest-map-all-degrees tail #/fn tail-hole tail-data
          (if
            (onum<?
              (hypertee-degree tail-hole)
              (hypertee-degree tails-hole))
            (hypernest-pure result-degree tail-data tail-hole)
            tail-data)))
      (just interpolation)
      (raise-arguments-error 'hypernest-join-all-degrees
        "expected each interpolation to have the right shape for the hole it occurred in"
        "hn" hn
        ; TODO: See if we should display `tails` transformed so its
        ; holes contain trivial values here.
        "root-hole-degree" (hypertee-degree tails)
        "interpolation" interpolation)
    #/hypernest-join-all-degrees interpolation)
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    ; TODO: Make sure the recursive calls to
    ; `hypernest-join-all-degrees` we make here always terminate. If
    ; they don't, we need to take a different approach.
    (hypernest-careful
    #/hypernest-coil-bump overall-degree data bump-degree
    #/hypernest-join-all-degrees
    #/hypernest-map-all-degrees tails #/fn tails-hole data
      (w- tails-hole-degree (hypertee-degree tails-hole)
      #/expect (onum<? tails-hole-degree bump-degree) #t data
      #/hypernest-pure result-degree
        (hypernest-join-all-degrees
        #/hypernest-map-all-degrees data #/fn tail-hole data
          (if (onum<? (hypertee-degree tail-hole) tails-hole-degree)
            (dissect data (trivial)
            #/hypernest-pure result-degree (trivial) tail-hole)
            data))
        tails-hole))))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
; TODO IMPLEMENT: See if we should implement a corresponding
; `hypertee-dv-bind-all-degrees`. Would it actually be more efficient
; at all?
;
(define/contract (hypernest-dv-bind-all-degrees hn dv-to-hn)
  (-> hypernest? (-> onum<omega? any/c hypernest?) hypernest?)
  (hypernest-join-all-degrees
  #/hypernest-dv-map-all-degrees hn dv-to-hn))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/contract (hypernest-bind-all-degrees hn hole-to-hn)
  (-> hypernest? (-> hypertee<omega? any/c hypernest?) hypernest?)
  (hypernest-join-all-degrees
  #/hypernest-map-all-degrees hn hole-to-hn))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/contract (hypernest-bind-one-degree degree hn func)
  (-> onum<omega? hypernest? (-> hypertee<omega? any/c hypernest?)
    hypernest?)
  (hypernest-bind-all-degrees hn #/fn hole data
    (if (equal? degree #/hypertee-degree hole)
      (func hole data)
      (hypernest-pure (hypernest-degree hn) data hole))))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/contract (hypernest-join-one-degree degree hn)
  (-> onum<omega? hypernest? hypernest?)
  (hypernest-bind-one-degree degree hn #/fn hole data
    data))

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/contract (hypernest-dv-any-all-degrees hn func)
  (-> hypernest? (-> onum<omega? any/c any/c) any/c)
  (dissect
    (hypernest-dv-fold-map-any-all-degrees (trivial) hn
    #/fn state d data
      (w- result (func d data)
      #/list result
        (if result
          (just data)
          (nothing))))
    (list result maybe-mapped)
  #/expect maybe-mapped (just mapped) #f
    result))

; TODO IMPLEMENT: Implement operations analogous to these:
;
;   hypertee-v-any-one-degree
;   hypertee-any-all-degrees
;   hypertee-dv-all-all-degrees
;   hypertee-all-all-degrees

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/contract (hypernest-dv-each-all-degrees hn body)
  (-> hypernest? (-> onum<omega? any/c any) void?)
  (hypernest-dv-any-all-degrees hn #/fn d data #/begin
    (body d data)
    #f)
  (void))

; TODO IMPLEMENT: Implement operations analogous to these:
;
;   hypertee-v-each-one-degree

; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
(define/contract (hypernest-each-all-degrees hn body)
  (-> hypernest? (-> hypertee<omega? any/c any) void?)
  (hypertee-dv-each-all-degrees
    (hypernest-map-all-degrees hn #/fn hole data
      (list hole data))
  #/fn d entry
    (dissect entry (list hole data)
    #/body hole data)))

; TODO IMPLEMENT: Implement operations analogous to these:
;
;   hypertee-contour?
;   hypertee-uncontour
;   hypertee-filter
;   hypertee-truncate
