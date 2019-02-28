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
  -> ->i and/c any/c contract? contract-name contract-out list/c or/c
  rename-contract)
(require #/only-in racket/contract/combinator
  blame-add-context coerce-contract contract-first-order-passes?
  make-contract raise-blame-error)

(require #/only-in lathe-comforts dissect expect fn w-)
(require #/only-in lathe-comforts/match match/c)
(require #/only-in lathe-comforts/maybe
  just just? just-value maybe? maybe/c nothing)
(require #/only-in lathe-comforts/struct
  auto-equal auto-write define-imitation-simple-generics
  define-imitation-simple-struct)
(require #/only-in lathe-comforts/trivial trivial?)

(require #/only-in punctaffy/hypersnippet/dim dim-sys? dim-sys-dim/c)

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
  [snippet-sys-shape->snippet
    (->i
      (
        [ss snippet-sys?]
        [shape (ss)
          (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)])
      [_ (ss) (snippet-sys-snippet/c ss)])]
  [snippet-sys-snippet->maybe-shape
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss)
        (maybe/c
          (snippet-sys-snippet/c
            (snippet-sys-shape-snippet-sys ss)))])]
  [snippet-sys-snippet-set-degree-maybe
    (->i
      (
        [ss snippet-sys?]
        [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
        [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss) (maybe/c #/snippet-sys-snippet/c ss)])]
  [snippet-sys-snippet-done
    (->i
      (
        [ss snippet-sys?]
        [degree (ss) (dim-sys-dim/c #/snippet-sys-dim-sys ss)]
        [shape (ss)
          (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)]
        [data any/c])
      [_ (ss) (snippet-sys-snippet/c ss)])]
  [snippet-sys-snippet-undone
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss)
        (maybe/c #/list/c
          (dim-sys-dim/c #/snippet-sys-dim-sys ss)
          (snippet-sys-snippet/c #/snippet-sys-shape-snippet-sys ss)
          any/c)])]
  [snippet-sys-snippet-select-everything
    (->i ([ss snippet-sys?] [snippet (ss) (snippet-sys-snippet/c ss)])
      [_ (ss) (snippet-sys-snippetof ss #/fn hole selected?)])]
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
                  (snippet-sys-snippet-zip-selective/c ss
                    (snippet-sys-snippet-select-everything
                      (snippet-sys-shape-snippet-sys ss)
                      hole)
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
            (fn hole selectable?))]
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
                    (snippet-sys-snippet-zip-selective/c ss
                      (snippet-sys-snippet-select-everything
                        (snippet-sys-shape-snippet-sys ss)
                        hole)
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
              (fn hole selectable?))]
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
(define (snippet-sys-snippet-map ss snippet hv-to-v)
  (just-value #/snippet-sys-snippet-splice ss snippet #/fn hole data
    (just #/unselected #/hv-to-v hole data)))

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
