#lang parendown racket/base

; hyprid.rkt
;
; A data structure which encodes higher-dimensional
; hypersnippet-shaped data using "stripes" of low-dimensional
; hypertees.

;   Copyright 2017-2019, 2021-2022 The Lathe Authors
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


(require #/only-in racket/contract/base -> ->i any any/c)
(require #/only-in racket/contract/combinator
  contract-first-order-passes?)
(require #/only-in racket/math natural?)

(require #/only-in lathe-comforts
  dissect dissectfn expect fn mat w- w-loop)
(require #/only-in lathe-comforts/list
  list-each list-foldl list-kv-map list-map nat->maybe)
(require #/only-in lathe-comforts/maybe just nothing)
(require #/only-in lathe-comforts/struct struct-easy)
(require #/only-in lathe-comforts/trivial trivial)
(require #/only-in lathe-morphisms/in-fp/mediary/set ok/c)

(require punctaffy/private/shim)
(init-shim)

(require #/only-in punctaffy/hypersnippet/dim
  dim-successors-sys? dim-successors-sys-dim-sys
  dim-successors-sys-dim-plus-int dim-successors-sys-dim=plus-int?
  dim-sys-dim<? dim-sys-dim=? dim-sys-dim=0? dim-sys-dim/c)
(require #/only-in punctaffy/hypersnippet/hyperstack
  hyperstack-dimension hyperstack-pop-trivial hyperstack-pop
  make-hyperstack-trivial make-hyperstack)
(require #/only-in punctaffy/private/hypertee-as-brackets
  htb-labeled htb-unlabeled hypertee? hypertee-bind-pred-degree
  hypertee-bracket-degree hypertee-contour hypertee-degree
  hypertee-done hypertee-dv-each-all-degrees hypertee-from-brackets
  hypertee-get-brackets hypertee-increase-degree-to
  hypertee-map-highest-degree hypertee-v-map-highest-degree)


(provide
  ; TODO: See if there's anything more abstract we can export in place
  ; of these structure types.
  (struct-out hyprid)
  (struct-out island-cane)
  (struct-out lake-cane)
  (struct-out non-lake-cane))
(provide #/own-contract-out
  hyprid-destripe-once
  hyprid-fully-destripe
  hyprid-stripe-once)


; ===== Hyprids ======================================================

; A hyprid is a hypertee that *also* contains hypersnippet data.
;
; TODO: Come up with a better name than "hyprid."
;
(struct-easy
  (hyprid
    dim-successors-sys
    unstriped-degrees striped-degrees striped-hypertee)
  #:equal
  (#:guard-easy
    (define dss dim-successors-sys)
    (unless (dim-successors-sys? dss)
      (error "Expected dss to be a dimension successors system"))
    (define ds (dim-successors-sys-dim-sys dss))
    ; TODO: Stop calling `contract-first-order-passes?` like this, and
    ; enforce this part of the contract with `contract-out` instead.
    (unless
      (contract-first-order-passes? (dim-sys-dim/c ds)
        unstriped-degrees)
      (error "Expected unstriped-degrees to be a dimension number"))
    ; TODO: See if this is really necessary.
    (expect (dim-successors-sys-dim-plus-int dss unstriped-degrees -1)
      (just pred-unstriped-degrees)
      (error "Expected unstriped-degrees to have a predecessor")
    #/void)
    (unless (natural? striped-degrees)
      (error "Expected striped-degrees to be a natural number"))
    (expect
      (dim-successors-sys-dim-plus-int dss
        unstriped-degrees striped-degrees)
      (just total-degrees)
      (error "Expected unstriped-degrees to have at least as many as striped-degrees successors")
    #/void)
    (expect (nat->maybe striped-degrees) (just pred-striped-degrees)
      (expect (hypertee? striped-hypertee) #t
        (error "Expected striped-hypertee to be a hypertee since striped-degrees was zero")
      #/w- degree (hypertee-degree striped-hypertee)
      #/w- closing-brackets (hypertee-get-brackets striped-hypertee)
      #/unless (dim-sys-dim=? ds unstriped-degrees degree)
        (error "Expected striped-hypertee to be a hypertee of degree unstriped-degrees"))
      (expect striped-hypertee
        (island-cane data
        #/hyprid dss
          unstriped-degrees-2 striped-degrees-2 striped-hypertee-2)
        (error "Expected striped-hypertee to be an island-cane since striped-degrees was nonzero")
      #/expect
        (dim-sys-dim=? ds unstriped-degrees unstriped-degrees-2)
        #t
        (error "Expected striped-hypertee to be an island-cane of the same unstriped-degrees")
      #/unless (= pred-striped-degrees striped-degrees-2)
        (error "Expected striped-hypertee to be an island-cane of striped-degrees one less")))))

(define/own-contract (hyprid-degree h)
  (->i ([h hyprid?])
    [_ (h)
      (dim-sys-dim/c #/dim-successors-sys-dim-sys
      #/hyprid-dim-successors-sys h)])
  (dissect h
    (hyprid dss unstriped-degrees striped-degrees striped-hypertee)
  #/dissect
    (dim-successors-sys-dim-plus-int dss
      unstriped-degrees striped-degrees)
    (just degree)
    degree))

(struct-easy (island-cane data rest)
  #:equal
  (#:guard-easy
    (unless (hyprid? rest)
      (error "Expected rest to be a hyprid"))
    (w- dss (hyprid-dim-successors-sys rest)
    #/w- ds (dim-successors-sys-dim-sys dss)
    #/w- d (hyprid-degree rest)
    #/hyprid-dv-each-lake-all-degrees rest #/fn hole-degree data
      (when (dim-successors-sys-dim=plus-int? dss d hole-degree 1)
        (mat data (lake-cane lake-dss data rest)
          (begin
            (unless (contract-first-order-passes? (ok/c dss) lake-dss)
              (error "Expected lake-dss to be accepted by dss"))
            (unless (dim-sys-dim=? ds d #/hypertee-degree rest)
              (error "Expected data to be of the same degree as the island-cane if it was a lake-cane")))
        #/mat data (non-lake-cane data)
          (void)
        #/error "Expected data to be a lake-cane or a non-lake-cane")))))

(struct-easy (lake-cane dss data rest)
  #:equal
  (#:guard-easy
    (unless (dim-successors-sys? dss)
      (error "Expected dss to be a dimension successors system"))
    (unless (hypertee? rest)
      (error "Expected rest to be a hypertee"))
    (w- ds (dim-successors-sys-dim-sys dss)
    #/w- d (hypertee-degree rest)
    #/hypertee-dv-each-all-degrees rest #/fn hole-degree data
      (if (dim-successors-sys-dim=plus-int? dss d hole-degree 1)
        (expect data (island-cane data rest)
          (error "Expected data to be an island-cane")
        #/unless (dim-sys-dim=? ds d #/hyprid-degree rest)
          (error "Expected data to be an island-cane of the same degree")
        #/hyprid-dv-each-lake-all-degrees rest #/fn hole-degree data
          (unless
            (dim-successors-sys-dim=plus-int? dss d hole-degree 1)
          
          ; A root island is allowed to contain arbitrary values in
          ; its low-degree holes, but the low-degree holes of an
          ; island beyond a lake just represent boundaries that
          ; transition back to the lake, so we require them to be
          ; `trivial` values.
          ;
          ; Note that this does not prohibit nontrivial data in holes
          ; of the highest degree an island can have (which are the
          ; same as the holes we wrap in `non-lake-cane`), since those
          ; holes don't represent transitions back to the lake.
          
          #/expect data (trivial)
            (error "Expected data to be an island-cane where the low-degree holes contained trivial values")
          #/void))
        (expect data (trivial)
          (error "Expected data to be a trivial value")
        #/void)))))

(struct-easy (non-lake-cane data) #:equal)

(define/own-contract (hyprid-map-lakes-highest-degree h func)
  (-> hyprid? (-> hypertee? any/c any/c) hyprid?)
  (dissect h
    (hyprid dss unstriped-degrees striped-degrees striped-hypertee)
  #/hyprid dss unstriped-degrees striped-degrees
  #/expect (nat->maybe striped-degrees) (just pred-striped-degrees)
    (hypertee-map-highest-degree dss striped-hypertee func)
  #/dissect striped-hypertee (island-cane data rest)
  #/island-cane data
  #/hyprid-map-lakes-highest-degree rest #/fn hole-hypertee rest
    (mat rest (lake-cane _ data rest)
      (lake-cane dss
        (func
          (hypertee-v-map-highest-degree dss rest #/fn rest
            (trivial))
          data)
      #/hypertee-v-map-highest-degree dss rest #/fn rest
        (dissect
          (hyprid-map-lakes-highest-degree
            (hyprid dss unstriped-degrees striped-degrees rest)
            func)
          (hyprid _ unstriped-degrees-2 striped-degrees-2 rest)
          rest))
    #/mat rest (non-lake-cane data) (non-lake-cane data)
    #/error "Internal error")))

(define/own-contract (hyprid-destripe-once h)
  (-> hyprid? hyprid?)
  (dissect h
    (hyprid dss unstriped-degrees striped-degrees striped-hypertee)
  #/expect (nat->maybe striped-degrees) (just pred-striped-degrees)
    (error "Expected h to be a hyprid with at least one degree of striping")
  #/dissect (dim-successors-sys-dim-plus-int dss unstriped-degrees 1)
    (just succ-unstriped-degrees)
  #/hyprid dss succ-unstriped-degrees pred-striped-degrees
  #/dissect striped-hypertee
    (island-cane data
    #/hyprid dss unstriped-degrees-2 pred-striped-degrees-2 rest)
  #/expect (nat->maybe pred-striped-degrees)
    (just pred-pred-striped-degrees)
    (hypertee-bind-pred-degree dss unstriped-degrees
      (hypertee-increase-degree-to succ-unstriped-degrees rest)
    #/fn hole rest
      (mat rest (lake-cane _ data rest)
        (hypertee-bind-pred-degree dss unstriped-degrees
          (hypertee-contour dss data rest)
        #/fn hole rest
          (dissect
            (hyprid-destripe-once
              (hyprid dss unstriped-degrees striped-degrees rest))
            (hyprid _ succ-unstriped-degrees pred-striped-degrees
              destriped-rest)
            destriped-rest))
      #/mat rest (non-lake-cane data)
        (hypertee-done succ-unstriped-degrees data hole)
      #/error "Internal error"))
  #/island-cane data
  #/w- destriped-rest (hyprid-destripe-once rest)
  #/hyprid-map-lakes-highest-degree destriped-rest
  #/fn hole-hypertee rest
    (mat rest (lake-cane _ data rest)
      (lake-cane dss data
      #/hypertee-v-map-highest-degree dss rest #/fn rest
        (dissect
          (hyprid-destripe-once
            (hyprid dss unstriped-degrees striped-degrees rest))
          (hyprid _ succ-unstriped-degrees pred-striped-degrees
            destriped-rest)
          destriped-rest))
    #/mat rest (non-lake-cane data) (non-lake-cane data)
    #/error "Internal error")))

(define/own-contract (hyprid-fully-destripe h)
  (-> hyprid? hypertee?)
  (dissect h
    (hyprid dss unstriped-degrees striped-degrees striped-hypertee)
  #/mat striped-degrees 0 striped-hypertee
  #/hyprid-fully-destripe #/hyprid-destripe-once h))

(define/own-contract (hyprid-dv-each-lake-all-degrees h body)
  (->i
    (
      [h hyprid?]
      [body (h)
        (w- ds
          (dim-successors-sys-dim-sys #/hyprid-dim-successors-sys h)
        #/-> (dim-sys-dim/c ds) any/c any)])
    [_ void?])
  (hypertee-dv-each-all-degrees (hyprid-fully-destripe h) body))

; This is the inverse of `hyprid-destripe-once`, taking a hyprid and
; returning a hyprid with one more striped degree and one fewer
; unstriped degree. The new stripe's data values are trivial values,
; as implemented at the comment labeled "TRIVIAL VALUE NOTE".
;
; The last degree can't be striped, so the number of unstriped degrees
; in the input must be greater than one.
;
; TODO: Test this.
;
(define/own-contract (hyprid-stripe-once h)
  (-> hyprid? hyprid?)
  
  (define (location-needs-state? location)
    (not #/memq location #/list 'non-lake 'hole))
  (define (location-is-island? location)
    (not #/not #/memq location #/list 'root-island 'inner-island))
  ; NOTE: The only reason we have a `location` slot here at all (and
  ; the makeshift enum that goes in it) is for sanity checks.
  (struct-easy (history-info location maybe-state)
    (#:guard-easy
      (unless
        (memq location
        #/list 'root-island 'non-lake 'lake 'inner-island 'hole)
        (error "Internal error"))
      (if (location-needs-state? location)
        (expect maybe-state (just state)
          (error "Internal error")
        #/void)
        (expect maybe-state (nothing)
          (error "Internal error")
        #/void))))
  (struct-easy (unfinished-lake-cane data rest-state))
  (struct-easy (stripe-state rev-brackets hist))
  
  (dissect h
    (hyprid dss unstriped-degrees striped-degrees striped-hypertee)
  #/w- ds (dim-successors-sys-dim-sys dss)
  #/expect (dim-successors-sys-dim-plus-int dss unstriped-degrees -1)
    (just pred-unstriped-degrees)
    (error "Expected h to be a hyprid with at least two unstriped degrees")
  #/expect
    (dim-successors-sys-dim-plus-int dss pred-unstriped-degrees -1)
    (just pred-pred-unstriped-degrees)
    (error "Expected h to be a hyprid with at least two unstriped degrees")
  #/w- succ-striped-degrees (add1 striped-degrees)
  #/hyprid dss pred-unstriped-degrees succ-striped-degrees
  #/expect striped-degrees 0
    (dissect striped-hypertee (island-cane data rest)
    #/w- striped-rest (hyprid-stripe-once rest)
    #/island-cane data
    #/hyprid-map-lakes-highest-degree striped-rest
    #/fn hole-hypertee rest
      (mat rest (lake-cane lake-dss data rest)
        (dissect (contract-first-order-passes? (ok/c dss) lake-dss) #t
        #/lake-cane dss data
        #/hypertee-v-map-highest-degree dss rest #/fn rest
          (dissect
            (hyprid-stripe-once
              (hyprid dss unstriped-degrees striped-degrees rest))
            (hyprid _ pred-unstriped-degrees succ-striped-degrees
              striped-rest)
            striped-rest))
      #/mat rest (non-lake-cane data) (non-lake-cane data)
      #/error "Internal error"))
  #/w- d (hypertee-degree striped-hypertee)
  #/w- closing-brackets (hypertee-get-brackets striped-hypertee)
  #/expect (dim-sys-dim=? ds d unstriped-degrees) #t
    (error "Internal error")
  ; We begin a `stripe-states` entry to place the root island's
  ; brackets in and a loop variable for the overall history.
  #/w- stripe-starting-state
    (w- rev-brackets (list)
    #/stripe-state rev-brackets
    #/make-hyperstack-trivial ds pred-unstriped-degrees)
  #/w- root-island-state 'root
  #/w-loop next
    
    closing-brackets
    (list-kv-map closing-brackets #/fn k v #/list k v)
    
    stripe-states
    (hash-set (make-immutable-hasheq) root-island-state
      stripe-starting-state)
    
    hist
    (list (history-info 'root-island #/just root-island-state)
      (make-hyperstack ds d #/history-info 'hole #/nothing))
    
    (expect closing-brackets (cons closing-bracket closing-brackets)
      ; In the end, we build the root island by accessing its state to
      ; get the brackets, arranging the brackets in the correct order,
      ; and recursively assembling lakes and islands using their
      ; states the same way.
      (w-loop assemble-island-from-state state root-island-state
        (dissect (hash-ref stripe-states state)
          (stripe-state rev-brackets hist)
        #/dissect (dim-sys-dim=0? ds #/hyperstack-dimension hist) #t
        
        ; TRIVIAL VALUE NOTE: This is where we put a trivial value
        ; into the new layer of stripe data.
        #/island-cane (trivial)
        
        #/hyprid dss pred-unstriped-degrees 0
        #/hypertee-from-brackets ds pred-unstriped-degrees
        #/list-map (reverse rev-brackets) #/fn closing-bracket
          (expect closing-bracket (htb-labeled d data) closing-bracket
          #/expect (dim-sys-dim=? ds d pred-pred-unstriped-degrees) #t
            closing-bracket
          #/mat data (non-lake-cane data) closing-bracket
          #/mat data (unfinished-lake-cane data rest-state)
            (dissect (hash-ref stripe-states rest-state)
              (stripe-state rev-brackets hist)
            #/dissect (dim-sys-dim=0? ds #/hyperstack-dimension hist)
              #t
            #/htb-labeled d #/lake-cane dss data
            #/hypertee-from-brackets ds pred-unstriped-degrees
            #/list-map (reverse rev-brackets) #/fn closing-bracket
              (expect closing-bracket (htb-labeled d data)
                closing-bracket
              #/expect
                (dim-sys-dim=? ds d pred-pred-unstriped-degrees)
                #t
                closing-bracket
              #/htb-labeled d #/assemble-island-from-state data))
          #/error "Internal error")))
    
    ; As we encounter lakes, we build `stripe-states` entries to keep
    ; their histories in, and so on for every island and lake at every
    ; depth.
    #/dissect closing-bracket (list new-i closing-bracket)
    #/dissect hist
      (list (history-info location-before maybe-state-before)
        histories-before)
    #/w- d (hypertee-bracket-degree closing-bracket)
    #/expect
      (dim-sys-dim<? ds d #/hyperstack-dimension histories-before)
      #t
      (error "Internal error")
    #/dissect
      (hyperstack-pop d histories-before
        (history-info location-before maybe-state-before))
      (list
        (history-info location-after maybe-state-after)
        histories-after)
    #/if (dim-sys-dim=? ds d pred-unstriped-degrees)
      
      ; If we've encountered a closing bracket of the highest degree
      ; the original hypertee can support, we're definitely starting a
      ; lake.
      (expect (location-is-island? location-before) #t
        (error "Internal error")
      #/expect (eq? 'hole location-after) #t
        (error "Internal error")
      #/expect closing-bracket (htb-labeled d data)
        (error "Internal error")
      #/w- rest-state new-i
      #/dissect maybe-state-before (just state)
      #/dissect (hash-ref stripe-states state)
        (stripe-state rev-brackets hist)
      #/w- stripe-states
        (hash-set stripe-states rest-state stripe-starting-state)
      #/w- stripe-states
        (hash-set stripe-states state
          (stripe-state
            (cons
              (htb-labeled pred-pred-unstriped-degrees
                (unfinished-lake-cane data rest-state))
              rev-brackets)
            (hyperstack-pop-trivial pred-pred-unstriped-degrees
              hist)))
      #/next closing-brackets stripe-states
        (list (history-info 'lake #/just rest-state) histories-after))
    
    #/if (dim-sys-dim=? ds d pred-pred-unstriped-degrees)
      
      ; If we've encountered a closing bracket of the highest degree
      ; that a stripe in the result can support, we may be starting an
      ; island or a non-lake.
      (mat closing-bracket (htb-labeled d data)
        
        ; This bracket is closing the original hypertee, so it must be
        ; closing an island, so we're starting a non-lake.
        (expect (location-is-island? location-before) #t
          (error "Internal error")
        #/expect (eq? 'hole location-after) #t
          (error "Internal error")
        #/dissect maybe-state-before (just state)
        #/dissect (hash-ref stripe-states state)
          (stripe-state rev-brackets hist)
        #/next closing-brackets
          (hash-set stripe-states state
            (stripe-state
              (cons (htb-labeled d #/non-lake-cane data) rev-brackets)
              (hyperstack-pop-trivial d hist)))
          (list (history-info 'non-lake #/nothing) histories-after))
        
        ; This bracket is closing an even higher-degree bracket, which
        ; must have started a lake, so we're starting an island.
        (expect (eq? 'lake location-before) #t
          (error "Internal error")
        #/expect (eq? 'root-island location-after) #t
          (error "Internal error")
        #/w- new-state new-i
        #/dissect maybe-state-before (just state)
        #/dissect (hash-ref stripe-states state)
          (stripe-state rev-brackets hist)
        #/w- stripe-states
          (hash-set stripe-states new-state stripe-starting-state)
        #/w- stripe-states
          (hash-set stripe-states state
            (stripe-state
              (cons (htb-labeled d new-state) rev-brackets)
              (hyperstack-pop-trivial d hist)))
        #/next closing-brackets stripe-states
          (list (history-info 'inner-island #/just new-state)
            histories-after)))
    
    ; If we've encountered a closing bracket of low degree, we pass it
    ; through to whatever island or lake we're departing from
    ; (including any associated data in the bracket) and whatever
    ; island or lake we're arriving at (excluding the data, since this
    ; bracket must be closing some hole which was started there
    ; earlier). In some circumstances, we need to associate a trivial
    ; value with the bracket we record to the departure island or
    ; lake, even if this bracket is not a hole-opener as far as the
    ; original hypertee is concerned.
    #/w- stripe-states
      (expect maybe-state-before (just state) stripe-states
      #/dissect (hash-ref stripe-states state)
        (stripe-state rev-brackets hist)
      #/w- hist (hyperstack-pop-trivial d hist)
      #/hash-set stripe-states state
        (stripe-state
          (cons
            (mat closing-bracket (htb-labeled d data) closing-bracket
            #/if (dim-sys-dim=? ds d #/hyperstack-dimension hist)
              (htb-labeled d #/trivial)
              (htb-unlabeled d))
            rev-brackets)
          hist))
    #/w- stripe-states
      (expect maybe-state-after (just state) stripe-states
      #/dissect (hash-ref stripe-states state)
        (stripe-state rev-brackets hist)
      #/hash-set stripe-states state
        (stripe-state
          (cons (htb-unlabeled d) rev-brackets)
          (hyperstack-pop-trivial d hist)))
    #/next closing-brackets stripe-states
      (list (history-info location-after maybe-state-after)
        histories-after))))
