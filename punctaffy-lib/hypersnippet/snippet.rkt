#lang parendown racket/base

; punctaffy/hypersnippet/snippet
;
; An interface for data structures that are hypersnippet-shaped.

;   Copyright 2019 The Lathe Authors
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


; NOTE: The Racket documentation says `get/build-late-neg-projection`
; is in `racket/contract/combinator`, but it isn't. It's in
; `racket/contract/base`. Since it's also in `racket/contract` and the
; documentation correctly says it is, we require it from there.
(require #/only-in racket/contract
  get/build-late-neg-projection struct-type-property/c)
(require #/only-in racket/contract/base
  -> ->i and/c any/c contract? contract-name contract-out list/c
  none/c or/c rename-contract)
(require #/only-in racket/contract/combinator
  blame-add-context coerce-contract contract-first-order-passes?
  make-contract raise-blame-error)

(require #/only-in lathe-comforts
  dissect dissectfn expect expectfn fn mat w- w-loop)
(require #/only-in lathe-comforts/match match/c)
(require #/only-in lathe-comforts/maybe
  just just? just-value maybe? maybe-bind maybe/c maybe-map nothing)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct)
(require #/only-in lathe-comforts/trivial trivial trivial?)

(require #/only-in punctaffy/hypersnippet/dim
  dim-sys? dim-sys-accepts? dim-sys-dim<? dim-sys-dim=? dim-sys-dim=0?
  dim-sys-dim/c dim-sys-dim-max dim-sys-dim-zero)

; TODO: Document all of these exports.
(provide
  unselected)
(provide #/contract-out
  [unselected? (-> any/c boolean?)]
  [unselected-value (-> unselected? any/c)])
(provide
  selected)
(provide #/contract-out
  [selected? (-> any/c boolean?)]
  [selected-value (-> selected? any/c)])
(provide #/contract-out
  [selectable? (-> any/c boolean?)]
  [selectable/c (-> contract? contract? contract?)]
  [snippet-sys? (-> any/c boolean?)]
  [snippet-sys-impl? (-> any/c boolean?)]
  [snippet-sys-dim-sys (-> snippet-sys? dim-sys?)]
  [snippet-sys-shape-snippet-sys (-> snippet-sys? snippet-sys?)]
  [snippet-sys-snippet/c (-> snippet-sys? contract?)]
  [snippet-sys-snippet-degree
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)])]
  [snippet-sys-snippetof
    (->i
      (
        [ss snippet-sys?]
        [h-to-value/c (ss)
          (->
            ; TODO: See if the fact we're using
            ; `snippet-sys-snippetof` inside its own contract will
            ; cause any problems.
            (snippet-sys-snippetof
              (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            contract?)])
      [_ contract?])]
  [snippet-sys-snippet-zip-selective/c
    (->i
      (
        [ss snippet-sys?]
        [shape (ss)
          (snippet-sys-snippetof
            (snippet-sys-shape-snippet-sys ss)
            (fn hole trivial?))]
        [check-subject-hv? (ss)
          (->
            (snippet-sys-snippetof
              (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            any/c
            boolean?)]
        [hvv-to-subject-v/c (ss)
          (->
            (snippet-sys-snippetof
              (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            any/c
            any/c
            contract?)])
      [_ contract?])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting snippet should always be of the same degree and shape as
  ; the input shape.
  [snippet-sys-shape->snippet
    (->i
      (
        [ss snippet-sys?]
        [shape (ss)
          (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)])
      [_ (ss) (snippet-sys-snippet/c ss)])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting shape should always be of the same degree and shape as
  ; the input snippet.
  [snippet-sys-snippet->maybe-shape
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss)
        (maybe/c
          (snippet-sys-snippet/c
            (snippet-sys-shape-snippet-sys ss)))])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting snippet should always be of the given degree, the result
  ; should always exist if the given degree is equal to the degree
  ; returned by `snippet-sys-snippet-undone`, and it should always
  ; exist if the given degree is greater than that degree and that
  ; degree is nonzero.
  [snippet-sys-snippet-set-degree-maybe
    (->i
      (
        [ss snippet-sys?]
        [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
        [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss) (maybe/c #/snippet-sys-snippet/c ss)])]
  ; TODO: See if the contract should be more specific. The given shape
  ; should always be of a degree strictly less than the given degree,
  ; and the resulting snippet should always be of the same shape as
  ; the given shape in its low-degree holes.
  [snippet-sys-snippet-done
    (->i
      (
        [ss snippet-sys?]
        [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
        [shape (ss)
          (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)]
        [data any/c])
      [_ (ss) (snippet-sys-snippet/c ss)])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting shape should always be of the same shape as the given
  ; snippet's low-degree holes.
  [snippet-sys-snippet-undone
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss)
        (maybe/c #/list/c
          (dim-sys-dim/c #/snippet-sys-dim-sys ss)
          (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)
          any/c)])]
  ; TODO: See if the result contract should be more specific. The
  ; resulting snippet should always be of the same degree and shape as
  ; the given one.
  [snippet-sys-snippet-select-everything
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss) (snippet-sys-snippetof ss #/fn hole selected?)])]
  ; TODO: See if this contract should be more specific about the
  ; degrees of the snippets.
  [snippet-sys-snippet-splice
    (->i
      (
        [ss snippet-sys?]
        [snippet (ss) (snippet-sys-snippet/c ss)]
        [hv-to-splice (ss)
          (->i
            (
              [hole
                (snippet-sys-snippetof
                  (snippet-sys-shape-snippet-sys ss)
                  (fn hole trivial?))]
              [data any/c])
            [_ (hole)
              (maybe/c #/selectable/c any/c
                ; What this means is that this should be a snippet
                ; which contains a `selected` or `unselected` entry in
                ; each hole, and its `selected` holes should
                ; correspond to the holes of `hole` and contain
                ; `trivial?` values.
                (and/c
                  (snippet-sys-snippetof ss #/fn hole
                    (selectable/c any/c trivial?))
                  (snippet-sys-snippet-zip-selective/c ss hole
                    (fn hole subject-data #/selected? subject-data)
                    (fn hole shape-data subject-data any/c))))])])
      [_ (ss) (maybe/c #/snippet-sys-snippet/c ss)])]
  [snippet-sys-snippet-zip-map-selective
    (->i
      (
        [ss snippet-sys?]
        [shape (ss)
          (snippet-sys-snippetof
            (snippet-sys-shape-snippet-sys ss)
            (fn hole trivial?))]
        [snippet (ss)
          (snippet-sys-snippetof ss #/fn hole selectable?)]
        [hvv-to-maybe-v (ss)
          (->
            (snippet-sys-snippetof
              (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))
            any/c
            any/c
            maybe?)])
      [_ (ss) (maybe/c #/snippet-sys-snippet/c ss)])]
  [prop:snippet-sys (struct-type-property/c snippet-sys-impl?)]
  ; TODO: See if we can come up with a better name or interface for
  ; this.
  [make-snippet-sys-impl-from-various-1
    (->
      ; snippet-sys-dim-sys
      (-> snippet-sys? dim-sys?)
      ; snippet-sys-shape-snippet-sys
      (-> snippet-sys? snippet-sys?)
      ; snippet-sys-snippet/c
      (-> snippet-sys? contract?)
      ; snippet-sys-snippet-degree
      (->i
        ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
        [_ (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)])
      ; snippet-sys-shape->snippet
      (->i
        (
          [ss snippet-sys?]
          [shape (ss)
            (snippet-sys-snippet/c
              (snippet-sys-shape-snippet-sys ss))])
        [_ (ss) (snippet-sys-snippet/c ss)])
      ; snippet-sys-snippet->maybe-shape
      (->i
        (
          [ss snippet-sys?]
          [snippet (ss) (snippet-sys-snippet/c ss)])
        [_ (ss)
          (maybe/c
            (snippet-sys-snippet/c
              (snippet-sys-shape-snippet-sys ss)))])
      ; snippet-sys-snippet-set-degree-maybe
      (->i
        (
          [ss snippet-sys?]
          [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
          [snippet (ss) (snippet-sys-snippet/c ss)])
        [_ (ss) (maybe/c #/snippet-sys-snippet/c ss)])
      ; snippet-sys-snippet-done
      (->i
        (
          [ss snippet-sys?]
          [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
          [shape (ss)
            (snippet-sys-snippet/c
              (snippet-sys-shape-snippet-sys ss))]
          [data any/c])
        [_ (ss) (snippet-sys-snippet/c ss)])
      ; snippet-sys-snippet-undone
      (->i
        ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
        [_ (ss)
          (maybe/c #/list/c
            (dim-sys-dim/c #/snippet-sys-dim-sys ss)
            (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)
            any/c)])
      ; snippet-sys-snippet-splice
      (->i
        (
          [ss snippet-sys?]
          [snippet (ss) (snippet-sys-snippet/c ss)]
          [hv-to-splice (ss)
            (->i
              (
                [hole
                  (snippet-sys-snippetof
                    (snippet-sys-shape-snippet-sys ss)
                    (fn hole trivial?))]
                [data any/c])
              [_ (hole)
                (maybe/c #/selectable/c any/c
                  ; What this means is that this should be a snippet
                  ; which contains a `selected` or `unselected` entry
                  ; in each hole, and its `selected` holes should
                  ; correspond to the holes of `hole` and contain
                  ; `trivial?` values.
                  (and/c
                    (snippet-sys-snippetof ss #/fn hole
                      (selectable/c any/c trivial?))
                    (snippet-sys-snippet-zip-selective/c ss hole
                      (fn hole subject-data #/selected? subject-data)
                      (fn hole shape-data subject-data any/c))))])])
        [_ (ss) (maybe/c #/snippet-sys-snippet/c ss)])
      ; snippet-sys-snippet-zip-map-selective
      (->i
        (
          [ss snippet-sys?]
          [shape (ss)
            (snippet-sys-snippetof
              (snippet-sys-shape-snippet-sys ss)
              (fn hole trivial?))]
          [snippet (ss)
            (snippet-sys-snippetof ss #/fn hole selectable?)]
          [hvv-to-maybe-v (ss)
            (->
              (snippet-sys-snippetof
                (snippet-sys-shape-snippet-sys ss)
                (fn hole trivial?))
              any/c
              any/c
              maybe?)])
        [_ (ss) (maybe/c #/snippet-sys-snippet/c ss)])
      snippet-sys-impl?)])


(define-imitation-simple-struct
  (unselected? unselected-value)
  unselected
  'unselected (current-inspector) (auto-write) (auto-equal))

(define-imitation-simple-struct
  (selected? selected-value)
  selected
  'selected (current-inspector) (auto-write) (auto-equal))

(define (selectable? v)
  (or (unselected? v) (selected? v)))

(define (selectable/c unselected/c selected/c)
  (w- unselected/c (coerce-contract 'selectable/c unselected/c)
  #/w- selected/c (coerce-contract 'selectable/c selected/c)
  #/rename-contract
    (or/c
      (match/c unselected unselected/c)
      (match/c selected selected/c))
    `(selectable/c
       ,(contract-name unselected/c)
       ,(contract-name selected/c))))


(define-imitation-simple-generics snippet-sys? snippet-sys-impl?
  (#:method snippet-sys-dim-sys (#:this))
  (#:method snippet-sys-shape-snippet-sys (#:this))
  (#:method snippet-sys-snippet/c (#:this))
  (#:method snippet-sys-snippet-degree (#:this) ())
  (#:method snippet-sys-shape->snippet (#:this) ())
  (#:method snippet-sys-snippet->maybe-shape (#:this) ())
  (#:method snippet-sys-snippet-set-degree-maybe (#:this) () ())
  (#:method snippet-sys-snippet-done (#:this) () () ())
  (#:method snippet-sys-snippet-undone (#:this) ())
  (#:method snippet-sys-snippet-splice (#:this) () ())
  (#:method snippet-sys-snippet-zip-map-selective (#:this) () () ())
  prop:snippet-sys make-snippet-sys-impl-from-various-1
  'snippet-sys 'snippet-sys-impl (list))

; TODO: See if this should have the question mark in its name.
; TODO: See if we should have a way to implement this that doesn't
; involve constructing another snippet along the way, since we just
; end up ignoring it.
; TODO: Export this.
(define (snippet-sys-snippet-all? ss snippet check-hv?)
  (just? #/snippet-sys-snippet-splice ss snippet #/fn hole data
    (if (check-hv? hole data)
      (just #/unselected data)
      (nothing))))

; TODO: Export this.
(define (snippet-sys-snippet-map-maybe ss snippet hv-to-maybe-v)
  (snippet-sys-snippet-splice ss snippet #/fn hole data
    (maybe-map (hv-to-maybe-v hole data) #/fn data
      (unselected data))))

; TODO: Export this.
(define (snippet-sys-snippet-map ss snippet hv-to-v)
  (just-value
  #/snippet-sys-snippet-map-maybe ss snippet #/fn hole data
    (just #/hv-to-v hole data)))

; TODO: Export this.
(define (snippet-sys-snippet-select ss snippet check-hv?)
  (snippet-sys-snippet-map ss snippet #/fn hole data
    (if (check-hv? hole data)
      (selected data)
      (unselected data))))

(define (snippet-sys-snippet-select-everything ss snippet)
  (snippet-sys-snippet-select ss snippet #/fn hole data #t))

; TODO: See if this should have the question mark in its name.
; TODO: Export this.
(define
  (snippet-sys-snippet-zip-all-selective? ss shape snippet check-hvv?)
  (expect
    (snippet-sys-snippet-zip-map-selective ss shape snippet
    #/fn hole shape-data snippet-data
      (just #/list shape-data snippet-data))
    (just zipped)
    #f
  #/snippet-sys-snippet-all? ss zipped #/fn hole data
    (dissect data (list shape-data snippet-data)
    #/check-hvv? shape-data snippet-data)))

(define (snippet-sys-snippetof ss h-to-value/c)
  (w- name `(snippet-sys-snippetof ,ss ,h-to-value/c)
  #/w- snippet-contract (snippet-sys-snippet/c ss)
  #/w- first-order
    (fn v
      (and (contract-first-order-passes? snippet-contract v)
      #/snippet-sys-snippet-all? ss v #/fn hole data
        (contract-first-order-passes? (h-to-value/c hole) data)))
  #/make-contract #:name name #:first-order first-order
    
    #:late-neg-projection
    (fn blame
      (w- snippet-contract-projection
        (
          (get/build-late-neg-projection snippet-contract)
          (blame-add-context blame "initial snippet check of"))
      #/fn v missing-party
        (w- v (snippet-contract-projection v missing-party)
        #/snippet-sys-snippet-map ss v #/fn hole data
          (
            (
              (get/build-late-neg-projection #/h-to-value/c hole)
              (blame-add-context blame "hole value of"))
            data
            missing-party))))))

(define
  (snippet-sys-snippet-zip-selective/c
    ss shape check-subject-hv? hvv-to-subject-v/c)
  (w- name
    `(snippet-sys-snippet-zip-selective/c
      ,ss ,shape ,check-subject-hv? ,hvv-to-subject-v/c)
  #/w- snippet-contract (snippet-sys-snippet/c ss)
  #/w- first-order
    (fn v
      (and (contract-first-order-passes? snippet-contract v)
      #/snippet-sys-snippet-zip-all-selective? ss shape
        (snippet-sys-snippet-select ss v #/fn hole data
          (check-subject-hv? hole data))
      #/fn hole shape-data subject-data
        (contract-first-order-passes?
          (hvv-to-subject-v/c hole shape-data subject-data)
          subject-data)))
  #/make-contract #:name name #:first-order first-order
    
    #:late-neg-projection
    (fn blame
      (w- snippet-contract-projection
        (
          (get/build-late-neg-projection snippet-contract)
          (blame-add-context blame "initial snippet check of"))
      #/fn v missing-party
        (w- v (snippet-contract-projection v missing-party)
        #/expect
          (snippet-sys-snippet-zip-map-selective ss shape
            (snippet-sys-snippet-select ss v #/fn hole data
              (check-subject-hv? hole data))
          #/fn hole shape-data subject-data
            (just #/
              (
                (get/build-late-neg-projection
                  (hvv-to-subject-v/c hole shape-data subject-data))
                (blame-add-context blame "hole value of"))
              subject-data
              missing-party))
          (just result)
          (raise-blame-error blame #:missing-party missing-party v
            '(expected: "~e" given: "~e")
            name v)
          result)))))


; TODO: Export this.
; TODO: Use the things that use this.
(define
  (snippet-sys-snippet-select-if-degree ss snippet check-degree?)
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/snippet-sys-snippet-select ss snippet #/fn hole data
    (check-degree? #/snippet-sys-snippet-degree shape-ss hole)))

; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-select-if-degree< ss degree snippet)
  (w- ds (snippet-sys-dim-sys ss)
  #/snippet-sys-snippet-select-if-degree ss snippet #/fn actual-degree
    (dim-sys-dim<? ds actual-degree degree)))

; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-bind ss prefix hv-to-suffix)
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/just-value #/snippet-sys-snippet-splice ss prefix #/fn hole data
    (just #/selected #/snippet-sys-snippet-select-if-degree< ss
      (snippet-sys-snippet-degree shape-ss hole)
      (hv-to-suffix hole data))))

; TODO: Export this.
; TODO: Use this.
(define (snippet-sys-snippet-join ss snippet)
  (snippet-sys-snippet-bind ss snippet #/fn hole data data))

; TODO: See if this should have the question mark in its name.
; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-any? ss snippet check-hv?)
  (not #/snippet-sys-snippet-all? ss snippet #/fn hole data
    (not #/check-hv? hole data)))


; TODO: Export these.
; TODO: Use the things that use these.
(define-imitation-simple-struct
  (selective-snippet? selective-snippet-value)
  selective-snippet
  'selective-snippet (current-inspector) (auto-write) (auto-equal))

; TODO: Export this.
; TODO: Use the things that use this.
(define (selective-snippet/c ss h-to-unselected/c)
  (rename-contract
    (match/c selective-snippet
      (snippet-sys-snippetof ss #/fn hole
        (selectable/c (h-to-unselected/c hole) any/c)))
    `(selective-snippet/c ,ss ,h-to-unselected/c)))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (selective-snippet-sys?
    selective-snippet-sys-snippet-sys
    selective-snippet-sys-h-to-unselected/c)
  selective-snippet-sys
  'selective-snippet-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:snippet-sys #/make-snippet-sys-impl-from-various-1
    ; snippet-sys-dim-sys
    (dissectfn (selective-snippet-sys ss _)
      (snippet-sys-dim-sys ss))
    ; snippet-sys-shape-snippet-sys
    (dissectfn (selective-snippet-sys ss _)
      (snippet-sys-shape-snippet-sys ss))
    ; snippet-sys-snippet/c
    (dissectfn (selective-snippet-sys ss h-to-unselected/c)
      (selective-snippet/c ss h-to-unselected/c))
    ; snippet-sys-snippet-degree
    (fn ss snippet
      (dissect ss (selective-snippet-sys ss _)
      #/dissect snippet (selective-snippet snippet)
      #/snippet-sys-snippet-degree ss snippet))
    ; snippet-sys-shape->snippet
    (fn ss shape
      (dissect ss (selective-snippet-sys ss _)
      #/selective-snippet #/snippet-sys-shape->snippet ss shape))
    ; snippet-sys-snippet->maybe-shape
    (fn ss snippet
      (dissect ss (selective-snippet-sys ss _)
      #/dissect snippet (selective-snippet snippet)
      #/w- shape-ss (snippet-sys-shape-snippet-sys ss)
      #/maybe-bind (snippet-sys-snippet->maybe-shape snippet)
      #/fn shape
      #/snippet-sys-snippet-map-maybe shape-ss shape #/fn hole data
        (expect data (selected data) (nothing)
        #/just data)))
    ; snippet-sys-snippet-set-degree-maybe
    (fn ss degree snippet
      (dissect ss (selective-snippet-sys ss _)
      #/dissect snippet (selective-snippet snippet)
      #/maybe-map
        (snippet-sys-snippet-set-degree-maybe ss degree snippet)
      #/fn snippet
        (selective-snippet snippet)))
    ; snippet-sys-snippet-done
    (fn ss degree shape data
      (dissect ss (selective-snippet-sys ss _)
      #/selective-snippet #/snippet-sys-snippet-select-everything
        (snippet-sys-snippet-done ss degree shape data)))
    ; snippet-sys-snippet-undone
    (fn ss snippet
      (dissect ss (selective-snippet-sys ss _)
      #/dissect snippet (selective-snippet snippet)
      #/maybe-bind
        (snippet-sys-snippet-map-maybe ss snippet #/fn hole data
          (expect data (selected data) (nothing)
          #/just data))
      #/fn snippet
      #/snippet-sys-snippet-undone ss snippet))
    ; snippet-sys-snippet-splice
    (fn ss snippet hv-to-splice
      (dissect ss (selective-snippet-sys ss _)
      #/dissect snippet (selective-snippet snippet)
      #/maybe-map
        (snippet-sys-snippet-splice ss snippet #/fn hole data
          (mat data (unselected data)
            (just #/unselected #/unselected data)
          #/dissect data (selected data)
          #/maybe-map (hv-to-splice hole data) #/fn splice
            (mat splice (unselected data)
              (just #/unselected #/selected data)
            #/dissect splice (selected #/selective-snippet suffix)
            #/just #/selected
              (snippet-sys-snippet-map ss suffix #/fn hole data
                (mat data (unselected data)
                  (unselected #/unselected data)
                #/dissect data (selected data)
                #/mat data (unselected data)
                  (unselected #/selected data)
                #/dissect data (selected #/trivial)
                #/selected #/trivial)))))
      #/fn snippet
        (selective-snippet snippet)))
    ; snippet-sys-snippet-zip-map-selective
    (fn ss shape snippet hvv-to-maybe-v
      (dissect ss (selective-snippet-sys ss _)
      #/dissect snippet (selective-snippet snippet)
      #/maybe-map
        (snippet-sys-snippet-zip-map-selective ss shape
          (snippet-sys-snippet-map ss snippet #/fn hole data
            (mat data (unselected data) (unselected #/unselected data)
            #/dissect data (selected data)
            #/mat data (unselected data) (unselected #/selected data)
            #/dissect data (selected data) (selected data)))
        #/fn hole shape-data subject-data
          (maybe-map (hvv-to-maybe-v hole shape-data subject-data)
          #/fn result-data
            (selected result-data)))
      #/fn snippet
        (selective-snippet snippet)))))


; TODO: Consider rearranging everything in this file, but especially
; the things below. Currently the file is in three parts: The things
; needed for `selective-snippet-sys?`, the things needed for
; `hypertee-snippet-sys?`, and the things needed for
; `hypernest-snippet-sys?`. Each time, some generic `snippet-sys?`
; utilities are added, but as we have more code that uses
; `snippet-sys?` values, we'll probably want to maintain all the
; generic `snippet-sys?` utilities in one place.


; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-zip-map ss shape snippet hvv-to-maybe-v)
  (w- snippet (snippet-sys-snippet-select-everything ss snippet)
  #/snippet-sys-snippet-zip-map-selective
    ss shape snippet hvv-to-maybe-v))

; TODO: See if this should have the question mark in its name.
; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-zip-all? ss shape snippet check-hvv?)
  (w- snippet (snippet-sys-snippet-select-everything ss snippet)
  #/snippet-sys-snippet-zip-all-selective?
    ss shape snippet check-hvv?))

; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-shape=? ss a b hvv=?)
  (w- shape-ss (snippet-sys-shape-snippet-sys ss)
  #/snippet-sys-snippet-zip-all? shape-ss a b #/fn hole a-data b-data
    (hvv=? hole a-data b-data)))

; TODO: Find a better name for this.
; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-filter-maybe ss snippet)
  (w- ds (snippet-sys-dim-sys ss)
  #/w- d (snippet-sys-snippet-degree ss snippet)
  #/snippet-sys-snippet-splice ss snippet #/fn hole data
    (mat data (selected data) (just #/unselected data)
    #/dissect data (unselected data)
    #/maybe-map
      (snippet-sys-snippet-set-degree-maybe ss
        (snippet-sys-snippet-degree ss snippet)
        (snippet-sys-shape->snippet ss hole))
    #/fn patch
      (selected #/snippet-sys-snippet-select-if-degree< ss
        (snippet-sys-snippet-degree ss hole)
        patch))))

; TODO: Export this.
; TODO: Use the things that use this.
(define (snippet-sys-snippet-map-selective ss snippet hv-to-v)
  (snippet-sys-snippet-map ss snippet #/fn hole data
    (mat data (unselected data) data
    #/dissect data (selected data) (hv-to-v hole data))))


; TODO: Export these.
; TODO: Use the things that use these.
(define-imitation-simple-struct
  (hypertee-coil-zero?)
  hypertee-coil-zero
  'hypertee-coil-zero (current-inspector) (auto-write) (auto-equal))
(define-imitation-simple-struct
  (hypertee-coil-hole?
    hypertee-coil-hole-overall-degree
    hypertee-coil-hole-hole
    hypertee-coil-hole-data
    hypertee-coil-hole-tails)
  hypertee-coil-hole
  'hypertee-coil-hole (current-inspector) (auto-write) (auto-equal))
; TODO: Define `hypertee-furl` in terms of `hypertee-furl-unchecked`.
; TODO: Change the way a `hypertee?` is written using
; `gen:custom-write`.
(define-imitation-simple-struct
  (hypertee? hypertee-dim-sys hypertee-unfurl)
  hypertee-furl-unchecked
  'hypertee (current-inspector) (auto-write) (auto-equal))

; TODO: Export this.
; TODO: Use the things that use this.
(define (hypertee/c ds)
  (rename-contract
    (expectfn (hypertee-furl-unchecked actual-ds _) #f
      (dim-sys-accepts? ds actual-ds))
    `(hypertee/c ,ds)))

; TODO: See if we should export this.
; TODO: Use the things that use this.
(define (hypertee-map-cps ds state ht on-hole then)
  (w- ss (hypertee-snippet-sys ds)
  #/dissect ht (hypertee-furl-unchecked _ coil)
  #/mat coil (hypertee-coil-zero)
    (then state #/hypertee-furl-unchecked ds #/hypertee-coil-zero)
  #/dissect coil (hypertee-coil-hole d hole data tails)
  #/on-hole state hole data #/fn state data
  #/hypertee-map-cps ds state tails
    (fn state hole tail then
      (w- d (snippet-sys-snippet-degree ss hole)
      #/hypertee-map-cps ds state tail
        (fn state hole data then
          (if
            (dim-sys-dim<? ds
              (snippet-sys-snippet-degree ss hole)
              d)
            (dissect data (trivial)
              (then state #/trivial))
            (on-hole state hole data then)))
        then))
  #/fn state tails
  #/then state #/hypertee-furl-unchecked ds
    (hypertee-coil-hole d hole data tails)))

; TODO: See if we should export this.
; TODO: Use the things that use this.
(define (hypertee-each-cps ds state ht on-hole then)
  
  ; TODO: Pick just one of these implementations.
  
  #;
  (hypertee-map-cps ds state ht
    (fn state hole data then
      (on-hole state hole data #/fn state
      #/then state data))
  #/fn state mapped
  #/then state)
  
  (w- ss (hypertee-snippet-sys ds)
  #/dissect ht (hypertee-furl-unchecked _ coil)
  #/mat coil (hypertee-coil-zero) (then state)
  #/dissect coil (hypertee-coil-hole d hole data tails)
  #/on-hole state hole data #/fn state
  #/hypertee-each-cps ds state tails
    (fn state hole tail then
      (w- d (snippet-sys-snippet-degree ss hole)
      #/hypertee-each-cps ds state tail
        (fn state hole data then
          (if
            (dim-sys-dim<? ds
              (snippet-sys-snippet-degree ss hole)
              d)
            (dissect data (trivial)
              (then state))
            (on-hole state hole data then)))
        then))
      then))

; TODO: See if we should export this.
; TODO: Use the things that use this.
(define (hypertee-each-ltr ds state ht on-hole)
  (hypertee-each-cps ds state ht
    (fn state hole data then #/then #/on-hole state hole data)
  #/fn state
    state))

(define (hypertee-zip-map ds shape snippet hvv-to-maybe-v)
  (w- ss (hypertee-snippet-sys ds)
  #/dissect shape (hypertee-furl-unchecked _ shape-coil)
  #/dissect snippet (hypertee-furl-unchecked _ snippet-coil)
  #/mat shape-coil (hypertee-coil-zero)
    (expect snippet-coil (hypertee-coil-zero) (nothing)
    #/just #/hypertee-furl-unchecked ds #/hypertee-coil-zero)
  #/dissect shape-coil
    (hypertee-coil-hole shape-d shape-hole shape-data shape-tails)
  #/expect snippet-coil
    (hypertee-coil-hole
      snippet-d snippet-hole snippet-data snippet-tails)
    (nothing)
  #/expect (dim-sys-dim=? ds shape-d snippet-d) #t (nothing)
  #/expect
    (snippet-sys-shape=? ss shape-hole snippet-hole
    #/fn hole shape-data snippet-data
      (dissect shape-data (trivial)
      #/dissect snippet-data (trivial)
        #t))
    #t
    (nothing)
  #/maybe-bind (hvv-to-maybe-v shape-hole shape-data snippet-data)
  #/fn result-data
  #/maybe-bind
    (snippet-sys-snippet-zip-map ss shape-tails snippet-tails
    #/fn hole shape-tail snippet-tail
      (w- d (snippet-sys-snippet-degree ss hole)
      #/snippet-sys-snippet-zip-map-selective ss
        shape-tail
        (snippet-sys-snippet-map ss snippet-tail #/fn hole data
          (if
            (dim-sys-dim<? ds (snippet-sys-snippet-degree ss hole) d)
            (dissect data (trivial)
              (selected #/trivial))
            data))
      #/fn hole shape-data snippet-data
        (if (dim-sys-dim<? ds (snippet-sys-snippet-degree ss hole) d)
          (dissect shape-data (trivial)
          #/dissect snippet-data (trivial)
            (just #/trivial))
          (hvv-to-maybe-v hole shape-data snippet-data))))
  #/fn result-tails
  #/just #/hypertee-furl-unchecked ds
    (hypertee-coil-hole shape-d shape-hole result-data result-tails)))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (hypertee-snippet-sys? hypertee-snippet-sys-dim-sys)
  hypertee-snippet-sys
  'hypertee-snippet-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:snippet-sys #/make-snippet-sys-impl-from-various-1
    ; snippet-sys-dim-sys
    (dissectfn (hypertee-snippet-sys ds)
      ds)
    ; snippet-sys-shape-snippet-sys
    (fn ss
      ss)
    ; snippet-sys-snippet/c
    (dissectfn (hypertee-snippet-sys ds)
      (hypertee/c ds))
    ; snippet-sys-snippet-degree
    (fn ss snippet
      (dissect ss (hypertee-snippet-sys ds)
      #/dissect snippet (hypertee-furl-unchecked _ coil)
      #/mat coil (hypertee-coil-zero) (dim-sys-dim-zero ds)
      #/dissect coil (hypertee-coil-hole d hole data tails) d))
    ; snippet-sys-shape->snippet
    (fn ss shape
      shape)
    ; snippet-sys-snippet->maybe-shape
    (fn ss snippet
      (just snippet))
    ; snippet-sys-snippet-set-degree-maybe
    (fn ss degree snippet
      (dissect ss (hypertee-snippet-sys ds)
      #/dissect snippet (hypertee-furl-unchecked _ coil)
      #/mat coil (hypertee-coil-zero)
        (expect (dim-sys-dim=0? ds degree) #t (nothing)
        #/just #/hypertee-furl-unchecked ds #/hypertee-coil-zero)
      #/dissect coil (hypertee-coil-hole d hole data tails)
        (expect
          (and
            (not #/dim-sys-dim=0? ds degree)
            (dim-sys-dim<? ds
              (snippet-sys-snippet-degree ss hole)
              degree))
          #t
          (nothing)
        #/maybe-map
          (snippet-sys-snippet-map-maybe ss tails #/fn hole tail
            (snippet-sys-snippet-set-degree-maybe ss degree tail))
        #/fn tails
          (hypertee-furl-unchecked ds
            (hypertee-coil-hole d hole data tails)))))
    ; snippet-sys-snippet-done
    (fn ss degree shape data
      (dissect ss (hypertee-snippet-sys ds)
      #/hypertee-furl-unchecked ds #/hypertee-coil-hole
        degree
        (snippet-sys-snippet-map ss shape #/fn hole data #/trivial)
        data
        (snippet-sys-snippet-map ss shape #/fn hole data
          (snippet-sys-snippet-done ss degree hole data))))
    ; snippet-sys-snippet-undone
    (fn ss snippet
      (dissect ss (hypertee-snippet-sys ds)
      #/dissect snippet (hypertee-furl-unchecked _ coil)
      #/expect coil (hypertee-coil-hole d hole data tails) (nothing)
      #/maybe-map
        (snippet-sys-snippet-map-maybe ss tails #/fn hole tail
          (maybe-bind (snippet-sys-snippet-undone ss tail)
          #/dissectfn (list tail-d tail-shape data)
          #/expect
            (and
              (dim-sys-dim=? ds d tail-d)
              (snippet-sys-shape=? ss hole tail-shape
              #/fn hole hole-data tail-shape-data
                (dissect hole-data (trivial)
                #/dissect tail-shape-data (trivial)
                  #t)))
            #t
            (nothing)
          #/just data))
      #/fn shape
        (list d shape data)))
    ; snippet-sys-snippet-splice
    (fn ss snippet hv-to-splice
      (dissect ss (hypertee-snippet-sys ds)
      #/w-loop next
        snippet snippet
        first-nontrivial-d (dim-sys-dim-zero ds)
        
        (dissect snippet (hypertee-furl-unchecked _ coil)
        #/mat coil (hypertee-coil-zero)
          (just #/hypertee-furl-unchecked ds #/hypertee-coil-zero)
        #/dissect coil (hypertee-coil-hole d hole data tails)
        #/maybe-bind
          (if
            (dim-sys-dim<? ds
              (snippet-sys-snippet-degree ss hole)
              first-nontrivial-d)
            (dissect data (trivial)
              (unselected #/trivial))
            (hv-to-splice hole data))
        #/fn splice
        #/mat splice (unselected data)
          (maybe-bind
            (snippet-sys-snippet-map ss tails #/fn hole tail
              (next tail
                (dim-sys-dim-max ds
                  first-nontrivial-d
                  (snippet-sys-snippet-degree ss hole))))
          #/fn tails
          #/just #/hypertee-furl-unchecked ds
            (hypertee-coil-hole d hole data tails))
        #/dissect splice (selected suffix)
        #/w- suffix
          (snippet-sys-snippet-map ss suffix #/fn hole data
            (expect data (unselected data) data
            #/unselected #/unselected data))
        #/maybe-bind
          (snippet-sys-snippet-zip-map-selective ss tails suffix
          #/fn hole tail data
            (w- d (snippet-sys-snippet-degree ss hole)
            #/dissect data (trivial)
            #/selected
              (snippet-sys-snippet-select-if-degree< ss d tail)))
        #/fn suffix
        #/snippet-sys-snippet-splice ss suffix #/fn hole data data)))
    ; snippet-sys-snippet-zip-map-selective
    (fn ss shape snippet hvv-to-maybe-v
      
      ; TODO: See if we can implement this in a more direct style like
      ; `hypertee-zip-map` rather than using `hypertee-map-cps`.
      ;
      ; When the first hole was `selected`, the implementation would
      ; be just like `hypertee-zip-map`.
      ;
      ; When the first hole was `unselected`, we would have to do
      ; something like this: Join the `tails` as a `selective-snippet`
      ; with some unselected holes in between, zip it again that way,
      ; and then parse those unselected holes to turn the result back
      ; into a replacement for `tails`.
      
      (dissect ss (hypertee-snippet-sys ds)
      #/w- numbered-snippet
        (hypertee-map-cps ds 0 snippet
          (fn state hole data then
            (mat data (unselected data)
              (then state #/unselected data)
            #/dissect data (selected data)
              (then (add1 state) #/selected #/list state data)))
        #/fn state numbered-snippet
          numbered-snippet)
      #/maybe-bind
        (snippet-sys-snippet-filter-maybe ss numbered-snippet)
      #/fn filtered-numbered-snippet
      #/maybe-bind
        (hypertee-zip-map ds shape filtered-numbered-snippet
        #/fn hole shape-data snippet-data
          (dissect snippet-data (list i snippet-data)
          #/maybe-map (hvv-to-maybe-v shape-data snippet-data)
          #/fn result-data
            (list i result-data)))
      #/fn filtered-numbered-result
      #/w- env
        (hypertee-each-ltr ds (make-immutable-hasheq)
          filtered-numbered-result
        #/fn env hole data
          (dissect data (list i data)
          #/hash-set env i data))
      #/snippet-sys-snippet-map-selective ss numbered-snippet
      #/fn hole data
        (dissect data (list i data)
        #/hash-ref env i)))))


; TODO: Find a better name for this.
; TODO: Export this.
; TODO: Use the things that use this.
(define
  (make-snippet-sys-impl-from-conversions
    snippet-sys-snippet/c ss-> snippet-> ->snippet)
  (make-snippet-sys-impl-from-various-1
    ; snippet-sys-dim-sys
    (fn ss
      (snippet-sys-dim-sys #/ss-> ss))
    ; snippet-sys-shape-snippet-sys
    (fn ss
      (snippet-sys-shape-snippet-sys #/ss-> ss))
    ; snippet-sys-snippet/c
    snippet-sys-snippet/c
    ; snippet-sys-snippet-degree
    (fn ss snippet
      (snippet-sys-snippet-degree (ss-> ss) (snippet-> snippet)))
    ; snippet-sys-shape->snippet
    (fn ss shape
      (->snippet #/snippet-sys-shape->snippet (ss-> ss) shape))
    ; snippet-sys-snippet->maybe-shape
    (fn ss snippet
      (snippet-sys-snippet->maybe-shape (ss-> ss)
        (snippet-> snippet)))
    ; snippet-sys-snippet-set-degree-maybe
    (fn ss degree snippet
      (maybe-map
        (snippet-sys-snippet-set-degree-maybe (ss-> ss) degree
          (snippet-> snippet))
      #/fn selective
        (->snippet selective)))
    ; snippet-sys-snippet-done
    (fn ss degree shape data
      (->snippet #/snippet-sys-snippet-done (ss-> ss)
        degree shape data))
    ; snippet-sys-snippet-undone
    (fn ss snippet
      (snippet-sys-snippet-undone (ss-> ss) (snippet-> snippet)))
    ; snippet-sys-snippet-splice
    (fn ss snippet hv-to-splice
      (maybe-map
        (snippet-sys-snippet-splice (ss-> ss) (snippet-> snippet)
        #/fn hole data
          (maybe-map (hv-to-splice hole data) #/fn data
            (mat data (unselected data) (unselected data)
            #/dissect data (selected suffix)
            #/selected #/snippet-> suffix)))
      #/fn snippet
        (snippet-> snippet)))
    ; snippet-sys-snippet-zip-map-selective
    (fn ss shape snippet hvv-to-maybe-v
      (maybe-map
        (snippet-sys-snippet-zip-map-selective (ss-> ss)
          shape (snippet-> snippet) hvv-to-maybe-v)
      #/fn selective
        (snippet-> selective)))))


; TODO: Export this.
; TODO: Use the things that use this.
(define (hypernest-selective-snippet-sys shape-ss)
  (selective-snippet-sys shape-ss #/fn hole
    (if (just? #/snippet-sys-snippet-undone shape-ss hole)
      any/c
      none/c)))

; TODO: Export these.
; TODO: Use these.
; TODO: Define `hypernest` in terms of `hypernest-unchecked`.
; TODO: Change the way a `hypernest?` is written using
; `gen:custom-write`.
(define-imitation-simple-struct
  (hypernest? hypernest-selective-snippet)
  hypernest-unchecked
  'hypernest (current-inspector) (auto-write) (auto-equal))

; TODO: Export this.
; TODO: Use the things that use this.
(define (hypernest/c shape-ss)
  (rename-contract
    (match/c hypernest-unchecked #/snippet-sys-snippet/c
      (hypernest-selective-snippet-sys shape-ss))
    `(hypernest/c ,shape-ss)))

; TODO: Export these.
; TODO: Use these.
(define-imitation-simple-struct
  (hypernest-snippet-sys? hypernest-snippet-sys-shape-snippet-sys)
  hypernest-snippet-sys
  'hypernest-snippet-sys (current-inspector) (auto-write) (auto-equal)
  (#:prop prop:snippet-sys #/make-snippet-sys-impl-from-conversions
    ; snippet-sys-snippet/c
    (dissectfn (hypernest-snippet-sys shape-ss)
      (hypernest/c shape-ss))
    ; ss->
    (dissectfn (hypernest-snippet-sys shape-ss)
      (hypernest-selective-snippet-sys shape-ss))
    ; snippet->
    (dissectfn (hypernest-unchecked selective)
      selective)
    ; ->snippet
    (fn selective
      (hypernest-unchecked selective))))
