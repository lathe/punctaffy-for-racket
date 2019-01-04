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

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/hash hash-kv-each hash-ref-maybe)
(require #/only-in lathe-comforts/list list-kv-map)
(require #/only-in lathe-comforts/maybe
  just maybe? maybe/c maybe-map nothing)
(require #/only-in lathe-comforts/struct istruct/c struct-easy)
(require #/only-in lathe-comforts/trivial trivial)
(require #/only-in lathe-ordinals
  onum<=? onum<? onum-max 0<onum<=omega? onum<=omega? onum<omega?)
(require #/only-in lathe-ordinals/olist olist-build)

(require #/only-in punctaffy/hypersnippet/hyperstack
  make-pushable-hyperstack pushable-hyperstack-dimension
  pushable-hyperstack-peek-elem pushable-hyperstack-pop
  pushable-hyperstack-push-uniform)
(require #/only-in punctaffy/hypersnippet/hypertee
  degree-and-closing-brackets->hypertee hypertee?
  hypertee-bind-all-degrees hypertee-contour hypertee-degree
  hypertee->degree-and-closing-brackets hypertee-drop1
  hypertee-dv-fold-map-any-all-degrees hypertee-dv-map-all-degrees
  hypertee-each-all-degrees hypertee-get-hole-zero hypertee<omega?
  hypertee-plus1 hypertee-promote hypertee-set-degree
  hypertee-zip-low-degrees hypertee-zip-selective)
(require #/only-in punctaffy/private/suppress-internal-errors
  punctaffy-suppress-internal-errors)

(provide
  (struct-out hypernest-coil-zero)
  (struct-out hypernest-coil-hole)
  (struct-out hypernest-coil-bump)
  hypernest-bracket-degree
  (rename-out [-hypernest? hypernest?])
  hypernest-degree
  degree-and-brackets->hypernest
  hypernest->degree-and-brackets
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
  hypernest-v-map-one-degree
  (struct-out hypernest-join-selective-interpolation)
  (struct-out hypernest-join-selective-non-interpolation)
  hypernest-join-all-degrees-selective
  hypernest-map-all-degrees
  hypernest-pure
  hypernest-get-hole-zero
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

(struct-easy (hypernest coil)
  #:equal
  
  ; We write hypernests using a sequence-of-brackets representation.
  #:write
  (fn this
    (dissect (hypernest->degree-and-brackets this)
      (list degree brackets)
    #/cons degree brackets)))

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
    onum<=omega?)
  (mat bracket (list 'open d data)
    d
  #/mat bracket (list d data)
    d
    bracket))

; NOTE: This is a procedure we call only from within this module. It
; may seem like a synonym of `hypernest`, but when we're debugging
; this module, we can change it to be a synonym of `hypernest-plus1`.
(define (hypernest-careful coil)
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
  
  (struct-easy (parent-same-part should-annotate-as-nontrivial))
  (struct-easy (parent-new-part))
  (struct-easy (parent-part i should-annotate-as-trivial))
  
  (struct-easy
    (part-state
      is-hypernest
      first-nontrivial-degree
      first-non-interpolation-degree
      overall-degree
      rev-brackets))
  
  (mat opening-degree 0
    (expect hypernest-brackets (list)
      (error "Expected hypernest-brackets to be empty since opening-degree was zero")
    #/hypernest-careful #/hypernest-coil-zero)
  #/expect hypernest-brackets (cons first-bracket hypernest-brackets)
    (error "Expected hypernest-brackets to be nonempty since opening-degree was nonzero")
  #/w- root-i 'root
  #/w- stack
    (make-pushable-hyperstack
    #/olist-build opening-degree #/dissectfn _
      (parent-same-part #t))
  #/dissect
    (mat first-bracket (list 'open bump-degree data)
      (list
        (fn root-part
          (hypernest-careful #/hypernest-coil-bump
            opening-degree data bump-degree root-part))
        (part-state #t 0 bump-degree
          (onum-max opening-degree bump-degree)
          (list))
        (pushable-hyperstack-push-uniform stack bump-degree
          (parent-new-part)))
    #/mat first-bracket (list hole-degree data)
      (expect (onum<? hole-degree opening-degree) #t
        (raise-arguments-error 'degree-and-brackets->hypernest
          "encountered a closing bracket of degree too high for where it occurred, and it was the first bracket"
          "opening-degree" opening-degree
          "first-bracket" first-bracket
          "hypernest-brackets" hypernest-brackets)
      #/dissect
        (pushable-hyperstack-pop stack
        #/olist-build hole-degree #/dissectfn _
          (parent-new-part))
        (list 'root (parent-same-part #t) stack)
      #/list
        (fn root-part
          (hypernest-careful #/hypernest-coil-hole
            opening-degree data root-part))
        (part-state #f 0 hole-degree hole-degree (list))
        stack)
    #/error "Expected the first bracket of a hypernest to be annotated")
    (list finish root-part stack)
  #/w-loop next
    hypernest-brackets-remaining hypernest-brackets
    parts (hash-set (make-immutable-hasheq) root-i root-part)
    stack stack
    current-i root-i
    new-i 0
    (dissect (hash-ref parts current-i)
      (part-state
        current-is-hypernest
        current-first-nontrivial-degree
        current-first-non-interpolation-degree
        current-overall-degree
        current-rev-brackets)
    #/w- current-d (pushable-hyperstack-dimension stack)
    #/expect hypernest-brackets-remaining
      (cons hypernest-bracket hypernest-brackets-remaining)
      (expect current-d 0
        (error "Expected more closing brackets")
      #/let ()
        (define (get-part i)
          (dissect (hash-ref parts i)
            (part-state
              is-hypernest
              first-nontrivial-degree
              first-non-interpolation-degree
              overall-degree
              rev-brackets)
          #/w- get-subpart
            (fn d data
              (if
                (and
                  (onum<=? first-nontrivial-degree d)
                  (onum<? d first-non-interpolation-degree))
                (get-part data)
                data))
          #/if is-hypernest
            (hypernest-dv-map-all-degrees
              (degree-and-brackets->hypernest overall-degree
                (reverse rev-brackets))
            #/fn d data
              (get-subpart d data))
            (hypertee-dv-map-all-degrees
              (degree-and-closing-brackets->hypertee overall-degree
                (reverse rev-brackets))
            #/fn d data
              (get-subpart d data))))
      #/finish #/get-part root-i)
    
    #/mat hypernest-bracket (list 'open bump-degree bump-value)
      (expect current-is-hypernest #t
        (error "Encountered a bump inside a hole")
      #/next
        hypernest-brackets-remaining
        (hash-set parts current-i
          (part-state
            current-is-hypernest
            current-first-nontrivial-degree
            current-first-non-interpolation-degree
            current-overall-degree
            (cons hypernest-bracket current-rev-brackets)))
        (pushable-hyperstack-push-uniform stack bump-degree
          (parent-same-part #f))
        current-i
        new-i)
    #/dissect
      (mat hypernest-bracket (list hole-degree hole-value)
        (list hole-degree hole-value)
        (list hypernest-bracket (trivial)))
      (list hole-degree hole-value)
    #/expect (onum<? hole-degree current-d) #t
      (raise-arguments-error 'degree-and-brackets->hypernest
        "encountered a closing bracket of degree too high for where it occurred"
        "current-d" current-d
        "hypernest-bracket" hypernest-bracket
        "hypernest-brackets-remaining"
        hypernest-brackets-remaining
        "hypernest-brackets" hypernest-brackets)
    #/w- parent (pushable-hyperstack-peek-elem stack hole-degree)
    #/begin
      (mat hypernest-bracket (list hole-degree hole-value)
        (expect parent (parent-same-part #t)
          (raise-arguments-error 'degree-and-brackets->hypernest
            "encountered an annotated closing bracket of degree too low for where it occurred"
            "current-d" current-d
            "hypernest-bracket" hypernest-bracket
            "hypernest-brackets-remaining"
            hypernest-brackets-remaining
            "hypernest-brackets" hypernest-brackets)
        #/void)
        (mat parent (parent-same-part #t)
          (raise-arguments-error 'degree-and-brackets->hypernest
            "encountered an unannotated closing bracket of degree too high for where it occurred"
            "current-d" current-d
            "hypernest-bracket" hypernest-bracket
            "hypernest-brackets-remaining"
            hypernest-brackets-remaining
            "hypernest-brackets" hypernest-brackets)
        #/void))
    #/mat parent (parent-same-part should-annotate-as-nontrivial)
      (dissect
        (pushable-hyperstack-pop stack
        #/olist-build hole-degree #/dissectfn _
          (parent-same-part #f))
        (list _ _ updated-stack)
      #/dissect
        (eq? should-annotate-as-nontrivial
          (mat hypernest-bracket (list hole-degree hole-value) #t #f))
        #t
      #/w- parts
        (hash-set parts current-i
          (part-state
            current-is-hypernest
            current-first-nontrivial-degree
            current-first-non-interpolation-degree
            current-overall-degree
            (cons hypernest-bracket current-rev-brackets)))
      #/next
        hypernest-brackets-remaining
        parts
        updated-stack
        current-i
        new-i)
    #/mat parent (parent-new-part)
      (dissect
        (pushable-hyperstack-pop stack
        #/olist-build hole-degree #/dissectfn _
          (parent-part current-i #t))
        (list _ _ updated-stack)
      #/mat hypernest-bracket (list hole-degree hole-value)
        ; TODO: Is this really an internal error, or is there some way
        ; to cause it with an incorrect sequence of input brackets?
        (error "Internal error: Expected the beginning of an interpolation to be unannotated")
      #/w- parent-i new-i
      #/w- new-i (add1 new-i)
      #/w- parts
        (hash-set parts current-i
          (part-state
            current-is-hypernest
            current-first-nontrivial-degree
            current-first-non-interpolation-degree
            current-overall-degree
            (cons (list hole-degree parent-i) current-rev-brackets)))
      #/w- parts
        (hash-set parts parent-i
          (part-state #t hole-degree hole-degree
            (onum-max opening-degree hole-degree)
            (list)))
      #/next
        hypernest-brackets-remaining
        parts
        updated-stack
        parent-i
        new-i)
    #/dissect parent (parent-part parent-i should-annotate-as-trivial)
      (dissect hole-value (trivial)
      #/dissect
        (pushable-hyperstack-pop stack
        #/olist-build hole-degree #/dissectfn _
          (parent-part current-i #f))
        (list _ _ updated-stack)
      #/dissect (hash-ref parts parent-i)
        (part-state
          parent-is-hypernest
          parent-first-nontrivial-degree
          parent-first-non-interpolation-degree
          parent-overall-degree
          parent-rev-brackets)
      #/w- parts
        (hash-set parts current-i
          (part-state
            current-is-hypernest
            current-first-nontrivial-degree
            current-first-non-interpolation-degree
            current-overall-degree
            (cons
              (if should-annotate-as-trivial
                (list hole-degree (trivial))
                hole-degree)
              current-rev-brackets)))
      #/w- parts
        (hash-set parts parent-i
          (part-state
            parent-is-hypernest
            parent-first-nontrivial-degree
            parent-first-non-interpolation-degree
            parent-overall-degree
            (cons hole-degree parent-rev-brackets)))
      #/next
        hypernest-brackets-remaining
        parts
        updated-stack
        parent-i
        new-i))))

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
            (raise-arguments-error 'hypernest-plus1
              "expected each tail of a hypernest-coil-hole to have trivial values in its low-degree holes"
              "tail-data" tail-data)
          #/trivial))
        (just zipped)
        (error "Expected each tail of a hypernest-coil-hole to match up with the hole it occurred in")
      #/void))
  #/dissect coil
    (hypernest-coil-bump
      overall-degree bump-value bump-degree tails-hypernest)
    ; NOTE: We don't validate `bump-value`.
    (expect
      (equal?
        (onum-max overall-degree bump-degree)
        (hypernest-degree tails-hypernest))
      #t
      (error "Expected the tails of a hypernest-coil-bump to be a hypernest of degree equal to the max of the overall degree and the bump degree")
    #/hypernest-each-all-degrees tails-hypernest #/fn hole data
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
              (raise-arguments-error 'hypernest-plus1
                "expected each tail of a hypernest-coil-bump to have trivial values in its low-degree holes"
                "tail-data" tail-data)
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
  ; thrown from inside `assert-valid-hypernest-coil`.
  (unless (punctaffy-suppress-internal-errors)
    ; NOTE: At this point we don't expect
    ; `assert-valid-hypernest-coil` itself to be very buggy. Since its
    ; implementation involves the construction of other hypertees and
    ; hypernests, we can save a *lot* of time by constructing those
    ; without verification. Otherwise the verification can end up
    ; doing some rather catastrophic recursion.
    (parameterize ([punctaffy-suppress-internal-errors #t])
      (assert-valid-hypernest-coil coil)))
  (hypernest coil))

(define/contract (hypernest-degree hn)
  (-> hypernest? onum<=omega?)
  (dissect hn (hypernest coil)
  #/mat coil (hypernest-coil-zero) 0
  #/mat coil (hypernest-coil-hole d data tails) d
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    overall-degree))

(define/contract (hypernest->degree-and-brackets hn)
  (-> hypernest?
    (list/c onum<=omega?
    #/listof #/or/c
      onum<omega?
      (list/c onum<omega? any/c)
      (list/c 'open onum<=omega? any/c)))
  (dissect hn (hypernest coil)
  #/w- interleave
    (fn overall-degree bump-degree tails #/let ()
      
      (struct-easy (state-in-root))
      (struct-easy (state-in-interpolation i))
      
      (w-loop next
        root-brackets (list-kv-map tails #/fn k v #/list k v)
        interpolations (make-immutable-hasheq)
        hist
          (list (state-in-root)
          #/make-pushable-hyperstack
          #/olist-build (onum-max overall-degree bump-degree)
          #/dissectfn _ #/state-in-root)
        rev-result (list)
        
        (define (finish root-brackets interpolations rev-result)
          (expect root-brackets (list)
            (error "Internal error: Encountered the end of a hypernest hole or bump tail in a region of degree 0 before getting to the end of the hole or bump itself")
          #/void)
          (hash-kv-each interpolations #/fn i interpolation-brackets
            (expect interpolation-brackets (list)
              (error "Internal error: Encountered the end of a hypernest hole or bump bracket system before getting to the end of its tails")
            #/void))
          (reverse rev-result))
        
        (define (pop-interpolation-bracket interpolations i)
          (expect (hash-ref interpolations i) (cons bracket rest)
            (list interpolations #/nothing)
            (list (hash-set interpolations i rest) #/just bracket)))
        
        (dissect hist (list state histories)
        #/mat state (state-in-interpolation interpolation-i)
          
          ; We read from the interpolation's bracket stream.
          (dissect
            (pop-interpolation-bracket interpolations interpolation-i)
            (list interpolations maybe-bracket)
          #/expect maybe-bracket (just bracket)
            ; TODO: We used to make this check here, back when this
            ; code was part of `hypertee-join-all-degrees`. However,
            ; since we can have a bump of degree 0, and a
            ; non-interpolation such as a bump causes us to push
            ; rather than pop the hyperstack, we can have a hyperstack
            ; of degree other than 0 at the end here. See if there's
            ; some other check we should make. This was an internal
            ; error anyway, so maybe not.
;            (expect (pushable-hyperstack-dimension histories) 0
;              (error "Internal error: A hypernest tail ran out of brackets before reaching a region of degree 0")
            (begin
            ; The interpolation has no more brackets, and we're in a
            ; region of degree 0, so we end the loop.
            #/finish root-brackets interpolations rev-result)
          #/w- d (hypernest-bracket-degree bracket)
          #/if
            (mat bracket (list 'open d data) #t
            #/onum<=? (pushable-hyperstack-dimension histories) d)
            ; We begin a non-interpolation in an interpolation.
            (w- histories
              (pushable-hyperstack-push-uniform histories d state)
            #/w- hist (list state histories)
            #/next root-brackets interpolations hist
              (cons bracket rev-result))
          #/dissect
            (pushable-hyperstack-pop histories
            #/olist-build d #/dissectfn _ state)
            (list popped-barrier state histories)
          #/w- hist (list state histories)
          #/mat state (state-in-root)
            
            ; We've moved out of the interpolation through a
            ; low-degree hole and arrived at the root. Now we proceed
            ; by processing the root's brackets instead of the
            ; interpolation's brackets.
            ;
            (dissect root-brackets
              (cons (list root-bracket-i root-bracket) root-brackets)
            #/begin
              (mat bracket (list d data)
                (expect data (trivial)
                  (error "Internal error: A hypernest hole or bump had a tail with a low-degree hole where the value wasn't a trivial value")
                #/void)
              #/void)
            #/next root-brackets interpolations hist
              (cons d rev-result))
          #/dissect state (state-in-interpolation i)
            
            ; We just moved out of a non-interpolation of the
            ; interpolation, so we're still in the interpolation, and
            ; we continue to proceed by processing the interpolation's
            ; brackets.
            ;
            (next root-brackets interpolations hist
              (cons bracket rev-result)))
        
        ; We read from the root's bracket stream.
        #/expect root-brackets (cons root-bracket root-brackets)
          ; TODO: We used to make this check here, back when this code
          ; was part of `hypertee-join-all-degrees`. However, since we
          ; can have a bump of degree 0, and a non-interpolation such
          ; as a bump causes us to push rather than pop the
          ; hyperstack, we can have a hyperstack of degree other than
          ; 0 at the end here. See if there's some other check we
          ; should make. This was an internal error anyway, so maybe
          ; not.
;          (expect (pushable-hyperstack-dimension histories) 0
;            (error "Internal error: A hypernest hole or bump ran out of brackets before reaching a region of degree 0")
          (begin
          ; The root has no more brackets, and we're in a region of
          ; degree 0, so we end the loop.
          #/finish root-brackets interpolations rev-result)
        #/dissect root-bracket (list root-bracket-i bracket)
        #/w- d (hypernest-bracket-degree bracket)
        #/mat bracket (list 'open _ _)
          ; We begin a non-interpolation in the root.
          (w- histories
            (pushable-hyperstack-push-uniform histories d state)
          #/w- hist (list state histories)
          #/next root-brackets interpolations hist
            (cons bracket rev-result))
        #/expect (onum<? d #/pushable-hyperstack-dimension histories)
          #t
          (error "Internal error: Expected each hole of a hypernest hole or bump to be of a degree less than the current region's degree")
        #/w- old-d (pushable-hyperstack-dimension histories)
        #/dissect
          (pushable-hyperstack-pop histories
          #/olist-build d #/dissectfn _ state)
          (list popped-barrier state histories)
        #/expect bracket (list d data)
          (w- hist (list state histories)
          #/mat state (state-in-root)
            ; We just moved out of a non-interpolation of the root, so
            ; we're still in the root.
            (next root-brackets interpolations hist
              (cons bracket rev-result))
          #/dissect state (state-in-interpolation i)
            ; We resume an interpolation in the root.
            (dissect (pop-interpolation-bracket interpolations i)
              (list interpolations #/just interpolation-bracket)
            #/next root-brackets interpolations hist
              (cons d rev-result)))
        ; We begin an interpolation in the root.
        #/expect data (list data-d data-brackets)
          (error "Internal error: Expected each hypernest bump or hole tail to be converted to brackets already")
        #/expect (equal? data-d #/onum-max overall-degree d) #t
          (error "Internal error: Expected each hypernest bump or hole tail to have the same degree as the root or the bump, whichever was greater")
        #/next root-brackets
          (hash-set interpolations root-bracket-i data-brackets)
          (list (state-in-interpolation root-bracket-i) histories)
          (cons d rev-result))))
  #/mat coil (hypernest-coil-zero) (list 0 #/list)
  #/mat coil (hypernest-coil-hole overall-degree data tails)
    (list overall-degree
    #/dissect
      (hypertee->degree-and-closing-brackets
      #/hypertee-dv-map-all-degrees tails #/fn d tail
        (hypernest->degree-and-brackets tail))
      (list hole-degree tails)
    #/cons (list hole-degree data)
    #/interleave overall-degree hole-degree tails)
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (list overall-degree
    #/dissect
      (hypernest->degree-and-brackets
      #/hypernest-dv-map-all-degrees tails #/fn d data
        (if (onum<? d bump-degree)
          (hypernest->degree-and-brackets data)
          data))
      (list _ tails)
    #/cons (list 'open bump-degree data)
    #/interleave overall-degree bump-degree tails)))

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
    #/hypernest-promote (onum-max new-degree bump-degree)
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
    #/hypernest-set-degree (onum-max new-degree bump-degree)
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
    (just #/hypertee-plus1 0 #/nothing)
  #/mat coil (hypernest-coil-hole d data tails)
    (dissect
      (hypertee-dv-fold-map-any-all-degrees (trivial) tails
      #/fn state d tail
        (list state #/hypernest->maybe-hypertee tail))
      (list (trivial) maybe-tails)
    #/maybe-map maybe-tails #/fn tails
    #/hypertee-plus1 d #/just #/list data tails)
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (nothing)))

(define/contract (hypernest-truncate-to-hypertee hn)
  (-> hypernest? hypertee?)
  (dissect hn (hypernest coil)
  #/mat coil (hypernest-coil-zero)
    (hypertee-plus1 0 #/nothing)
  #/mat coil (hypernest-coil-hole d data tails)
    (hypertee-plus1 d #/just #/list data
    #/hypertee-dv-map-all-degrees tails #/fn d tail
      (hypernest-truncate-to-hypertee tail))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (w- intermediate-degree (onum-max overall-degree bump-degree)
    #/hypertee-set-degree overall-degree
    #/hypertee-bind-all-degrees
      (hypertee-promote intermediate-degree
      #/hypernest-truncate-to-hypertee tails)
    #/fn hole data
      (hypertee-promote intermediate-degree
      #/if (onum<? (hypertee-degree hole) bump-degree)
        (hypernest-truncate-to-hypertee data)
        (hypertee-contour data hole)))))

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
  #/dissect
    (hypernest-dv-fold-map-any-all-degrees 0 bigger #/fn i d data
      (list (add1 i) #/just #/list i data))
    (list _ #/just bigger)
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
    (hypertee-dv-fold-map-any-all-degrees
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
      (hypernest-dgv-map-all-degrees tail
      #/fn tail-hole-d get-tail-hole data
        (if (onum<? tail-hole-d tails-hole-d)
          (dissect data (trivial)
          #/trivial)
        #/func tail-hole-d get-tail-hole data)))
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

(define/contract (hypernest-v-map-one-degree degree hn func)
  (-> onum<omega? hypernest? (-> any/c any/c) hypernest?)
  (hypernest-dv-map-all-degrees hn #/fn hole-degree data
    (if (equal? degree hole-degree)
      (func data)
      data)))

; TODO IMPLEMENT: Implement operations analogous to `hypertee-fold`.

(struct-easy (hypernest-join-selective-interpolation val) #:equal)
(struct-easy (hypernest-join-selective-non-interpolation val) #:equal)

; This takes a hypernest of degree N where each hole value of each
; degree M is either a `hypernest-join-selective-interpolation`
; containing another degree-N hypernest to be interpolated or a
; `hypernest-join-selective-non-interpolation`. In those interpolated
; hypernests, each value of a hole of degree L is either a
; `hypernest-join-selective-non-interpolation` or, if L is less than
; M, possibly a `hypernest-join-selective-interpolation` of a
; `trivial` value. This returns a single degree-N hypernest which has
; holes for all the non-interpolations of the interpolations and the
; non-interpolations of the root.
;
; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
(define/contract (hypernest-join-all-degrees-selective hn)
  (-> hypernest? hypernest?)
  (dissect hn (hypernest coil)
  #/mat coil (hypernest-coil-zero)
    (hypernest-careful #/hypernest-coil-zero)
  #/w- result-degree (hypernest-degree hn)
  #/w- verify-hole-value
    (fn root-hole-degree data
      (mat data (hypernest-join-selective-interpolation interpolation)
        (expect (hypernest? interpolation) #t
          (raise-arguments-error 'hypernest-join-all-degrees-selective
            "expected each interpolation to be a hypernest"
            "hn" hn
            "root-hole-degree" root-hole-degree
            "interpolation" interpolation)
        #/expect
          (equal? result-degree (hypernest-degree interpolation))
          #t
          (raise-arguments-error 'hypernest-join-all-degrees-selective
            "expected every interpolation to have the same degree as the root hypernest"
            "hn" hn
            "root-hole-degree" root-hole-degree
            "interpolation" interpolation)
        #/void)
      #/mat data (hypernest-join-selective-non-interpolation _) (void)
      #/raise-arguments-error 'hypernest-join-all-degrees-selective
        "expected each of the root's hole values to be a hypernest-join-selective-interpolation or a hypernest-join-selective-non-interpolation"
        "hn" hn
        ; TODO: See if we should display a full hole shape here.
        "root-hole-degree" root-hole-degree
        "data" data))
  #/w- double-non-interpolations
    (fn data
      (mat data (hypernest-join-selective-interpolation interpolation)
        ; TODO: See if there's some user input which makes
        ; `interpolation` a value other than a hypernest.
        (hypernest-join-selective-interpolation
        #/hypernest-dv-map-all-degrees interpolation #/fn d data
          (mat data (hypernest-join-selective-interpolation data)
            ; TODO: See if `data` is always a trivial value here.
            (hypernest-join-selective-interpolation data)
          ; TODO: See if there's some user input which makes this
          ; `dissect` fail.
          #/dissect data
            (hypernest-join-selective-non-interpolation data)
            (hypernest-join-selective-non-interpolation
            #/hypernest-join-selective-non-interpolation data)))
      ; TODO: See if there's some user input which makes this
      ; `dissect` fail.
      #/dissect data (hypernest-join-selective-non-interpolation data)
        (hypernest-join-selective-non-interpolation
        #/hypernest-join-selective-non-interpolation data)))
  #/mat coil (hypernest-coil-hole overall-degree data tails)
    (begin (verify-hole-value (hypertee-degree tails) data)
    #/mat data (hypernest-join-selective-interpolation interpolation)
      ; TODO: Make sure the recursive calls to
      ; `hypernest-join-all-degrees-selective` we make here always
      ; terminate. If they don't, we need to take a different
      ; approach.
      (expect
        (hypernest-zip-selective tails interpolation
          (fn hole data
            (mat data (hypernest-join-selective-interpolation _)
              #t
              #f))
        #/fn tails-hole tail interpolation-data
          (expect interpolation-data
            (hypernest-join-selective-interpolation #/trivial)
            (error "Expected each low-degree hole of each interpolation to contain an interpolation of a trivial value")
          #/hypernest-join-selective-interpolation
          #/hypernest-join-all-degrees-selective
          #/hypernest-dv-map-all-degrees tail
          #/fn tail-hole-degree tail-data
            (if (onum<? tail-hole-degree (hypertee-degree tails-hole))
              (dissect tail-data (trivial)
              #/hypernest-join-selective-non-interpolation
              #/hypernest-join-selective-interpolation #/trivial)
            #/double-non-interpolations tail-data)))
        (just interpolation)
        (raise-arguments-error 'hypernest-join-all-degrees-selective
          "expected each interpolation to have the right shape for the hole it occurred in"
          "hn" hn
          ; TODO: See if we should display `tails` transformed so its
          ; holes contain trivial values here.
          "root-hole-degree" (hypertee-degree tails)
          "interpolation" interpolation)
      #/hypernest-join-all-degrees-selective interpolation)
    #/dissect data (hypernest-join-selective-non-interpolation data)
      (hypernest-careful
      #/hypernest-coil-hole overall-degree data
      #/hypertee-dv-map-all-degrees tails #/fn tails-hole-degree tail
        (hypernest-join-all-degrees-selective
        #/hypernest-dv-map-all-degrees tail #/fn tail-hole-degree data
          (if (onum<? tail-hole-degree tails-hole-degree)
            (dissect data (trivial)
            #/hypernest-join-selective-non-interpolation #/trivial)
            data))))
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    ; TODO: Make sure the recursive calls to
    ; `hypernest-join-all-degrees-selective` we make here always
    ; terminate. If they don't, we need to take a different approach.
    (hypernest-careful
    #/hypernest-coil-bump overall-degree data bump-degree
    #/hypernest-join-all-degrees-selective
    #/hypernest-dv-map-all-degrees tails #/fn tails-hole-degree data
      (expect (onum<? tails-hole-degree bump-degree) #t
        (begin (verify-hole-value tails-hole-degree data)
        #/mat data
          (hypernest-join-selective-interpolation interpolation)
          (hypernest-join-selective-interpolation
          ; TODO: See if we really need this `hypernest-promote`
          ; call.
          #/hypernest-promote (onum-max bump-degree overall-degree)
            interpolation)
        #/dissect data
          (hypernest-join-selective-non-interpolation data)
          (hypernest-join-selective-non-interpolation data))
      #/hypernest-join-selective-non-interpolation
      #/hypernest-join-all-degrees-selective
      #/hypernest-dv-map-all-degrees data #/fn tail-hole-degree data
        (if (onum<? tail-hole-degree tails-hole-degree)
          (dissect data (trivial)
          #/hypernest-join-selective-non-interpolation #/trivial)
          data)))))

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
    (expect (hypertee-get-hole-zero tails) (just tail)
      (just data)
    #/hypernest-get-hole-zero tail)
  #/dissect coil
    (hypernest-coil-bump overall-degree data bump-degree tails)
    (dissect (hypernest-get-hole-zero tails) (just tail)
    #/mat bump-degree 0
      (just tail)
    #/hypernest-get-hole-zero tail)))

; TODO IMPLEMENT: Implement operations analogous to these:
;
;   hypertee-bind-pred-degree
;   hypertee-bind-highest-degree

; This takes a hypernest of degree N where each hole value of each
; degree M is another degree-N hypernest to be interpolated. In those
; interpolated hypertees, the values of holes of degree less than M
; must be `trivial` values. This returns a single degree-N hypernest
; which has holes for all the degree-M-or-greater holes of the
; interpolations of each degree M.
;
; TODO IMPLEMENT: Implement operations analogous to this, but for
; bumps instead of holes.
;
(define/contract (hypernest-join-all-degrees hn)
  (-> hypernest? hypernest?)
  (hypernest-join-all-degrees-selective
  #/hypernest-dv-map-all-degrees hn #/fn root-hole-degree data
    (expect (hypernest? data) #t
      (error "Expected each interpolation of a hypernest join to be a hypernest")
    #/hypernest-join-selective-interpolation
    #/hypernest-dv-map-all-degrees data
    #/fn interpolation-hole-degree data
      (expect (onum<? interpolation-hole-degree root-hole-degree) #t
        (hypernest-join-selective-non-interpolation data)
      #/hypernest-join-selective-interpolation data))))

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
  (hypernest-dv-each-all-degrees
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
