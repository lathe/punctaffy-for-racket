#lang parendown racket/base

; hypernest-macro.rkt
;
; A framework for macros which take hypersnippet-shaped syntax.

;   Copyright 2018, 2019 The Lathe Authors
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


(require #/only-in racket/contract/base -> ->i any/c list/c)
(require #/only-in racket/contract/region define/contract)
(require #/only-in syntax/parse id syntax-parse)

(require #/only-in lathe-comforts dissect expect fn mat w- w-loop)
(require #/only-in lathe-comforts/list list-foldr list-map)
(require #/only-in lathe-comforts/maybe
  just maybe? maybe-bind maybe-map nothing)
(require #/only-in lathe-comforts/struct struct-easy)
(require #/only-in lathe-comforts/trivial trivial)

(require #/only-in punctaffy/hypersnippet/dim
  dim-successors-sys? dim-successors-sys-dim-plus-int
  dim-successors-sys-dim-sys dim-sys-dim-zero
  successorless-dim-successors-sys)
(require #/only-in punctaffy/hypersnippet/hypernest
  degree-and-brackets->hypernest hnb-labeled hnb-open hnb-unlabeled
  hypernest-bind-one-degree hypernest/c hypernest-promote
  hypernest-set-degree)

(provide
  (struct-out hn-tag-0-s-expr-stx)
  (struct-out hn-tag-1-list)
  (struct-out hn-tag-1-list*)
  (struct-out hn-tag-1-vector)
  (struct-out hn-tag-1-prefab)
  (struct-out hn-tag-unmatched-closing-bracket)
  (struct-out hn-tag-nest)
  (struct-out hn-tag-other)
  s-expr-stx->hn-expr
  simple-hn-builder-syntax)


; We're taking this approach:
;
;
; Conceptually, we treat the program's syntax as a degree-1 hypernest
; built up from a sequential encoding. That is, the program's syntax
; is an arrangement of bumps and holes, and each of the bumps can have
; its own bumps and holes, and each of the holes can have its own
; holes (but not bumps). Bumps can be of any nonzero degree, and holes
; can be of any degree less than the degree of their containing bump
; (or at the outermost level, less than the degree of the overall
; degree-1 hypernest, so only degree 0). These conditions ensure that
; the bumps and holes can always be flattened into a sequence of
; degree-annotated opening and closing brackets. Each bump will be
; associated with a data value, and the only overall hole in the
; hypernest -- the degree-0 one -- will essentially represent
; "end of file" and will only be associated with a trivial data value.
;
; Since we're in Racket, our syntax transformers will take
; s-expression-shaped syntax objects as input like usual. When we
; write a syntax transformer where we care to process
; higher-dimensional syntax, we will explicitly convert these syntax
; objects to degree-1 hypernests using a special macroexpansion
; procedure called `s-expr-stx->hn-expr`. We call the degree-1
; hypernests "hn-expressions" when we use them for syntax this way.
; (Note that s-expressions have a degree-1 hypersnippet shape already,
; so there is no need to explicitly represent the degree-0 hole with a
; bracket.)
;
; This conversion is a kind of macroexpansion only because we don't
; hardcode particular symbols for the higher-dimensional brackets that
; this conversion process handles. Instead of hardcoding those
; symbols, we allow users to define their own
; syntax-object-to-hn-expression transformers. These are a lot like
; reader extensions, since they create higher-dimensional syntax out
; of a lower-dimensional encoding.
;
;
; Of all the Racket syntax transformers that will invoke
; `s-expr-stx->hn-expr`, the most familiar will be ones that imitate
; `quasiquote` or `quasisyntax`. However, these aren't necessarily the
; easiest examples to deal with because they introduce two other
; problems: Problem one is, the `quasiquote` and `quasisyntax`
; operators have degree-2 hypersnippet syntax, but they still create
; s-expression-shaped data. Problem two is, since `quasiquote` and
; `quasisyntax` are operations that are useful in Racket code, and
; since they're operations that are meant for quoting Racket code,
; they should be able to quote themselves.
;
; Quoting themselves isn't a problem with hypernests, but hypernests
; aren't the kind of s-expression-shaped data these operations should
; return.
;
; So what we're going to use is a hypernest-based representation
; format that *preserves* the s-expressions we built it up out of;
; this way operators like `quasiquote` and `quasisyntax` can
; round-trip it back to s-expressions.
;
; It's not just `quasiquote` and `quasisyntax` that will benefit from
; this round-tripping. The Racket compiler and just about all existing
; Racket syntaxes are designed to take s-expressions as input, so
; programmers will still have many reasons to generate them.
;
;
; To incorporate that round-tripping data into our hypernest format,
; we will treat occurrences of opening brackets as bumps just like we
; would otherwise, but the data we associate with a degree-N bump will
; generally include a degree-(N+1) hypernest with a single degree-N
; hole shaped like the bump, and with each hole of that hole
; containing a single hole of the same shape. This is just the right
; shape to be degree-N-concatenated in between the bump's interior and
; the surrounding hypernest data in order to flatten the bumps back
; into s-expression-shaped data.
;
; When we interpret an s-expression as a hypernest, the data we can
; usually encode in an s-expression also remains. Our hypernest-based
; encoding has analogues for:
;
;   - Embedded datums. We represent these with another kind of
;     degree-1 bump.
;
;   - Brackets introducing lists, improper lists, vectors, and
;     prefabricated structs. We represent these with other kinds of
;     degree-2 bump.
;
; These bumps have interiors like any other bumps, but they're empty
; and can be safely ignored; they contan no bumps of their own.



(define/contract (improper-list->list-and-tail lst)
  (-> any/c #/list/c list? any/c)
  (w-loop next rev-elems (list) tail lst
    (expect tail (cons elem tail) (list (reverse rev-elems) tail)
    #/next (cons elem rev-elems) tail)))

(define/contract (syntax-local-maybe identifier)
  (-> any/c maybe?)
  (if (identifier? identifier)
    (w- dummy (box #/trivial)
    #/w- local (syntax-local-value identifier #/fn dummy)
    #/if (eq? local dummy)
      (nothing)
      (just local))
    (nothing)))



; This struct property indicates a syntax's behavior as the kind of
; macro expected by `s-expr-stx->hn-expr`.
(define-values
  (prop:hn-builder-syntax hn-builder-syntax? hn-builder-syntax-ref)
  (make-struct-type-property 'hn-builder-syntax))

(define/contract (hn-builder-syntax-maybe x)
  (-> any/c maybe?)
  (if (hn-builder-syntax? x)
    (just #/hn-builder-syntax-ref x)
    (nothing)))

(define (n-d-maybe dss dim-as-nat)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/dim-successors-sys-dim-plus-int dss (dim-sys-dim-zero ds)
    dim-as-nat))

(define (n-d dss dim-as-nat)
  (expect (n-d-maybe dss dim-as-nat) (just dim)
    (raise-arguments-error 'n-d
      "expected the given number of successors to exist for the zero dimension"
      "dss" dss
      "dim-as-nat" dim-as-nat)
    dim))

(define (n-hn dss degree . brackets)
  (w- ds (dim-successors-sys-dim-sys dss)
  #/degree-and-brackets->hypernest ds (n-d dss degree)
  #/list-map brackets #/fn bracket
    (mat bracket (hnb-open d data) (hnb-open (n-d dss d) data)
    #/mat bracket (hnb-labeled d data) (hnb-labeled (n-d dss d) data)
    #/mat bracket (hnb-unlabeled d) (hnb-unlabeled (n-d dss d))
    #/hnb-unlabeled (n-d dss bracket))))

(define (n-hn-append0 dss degree hns)
  ; When we call this, the elements of `hns` are hypernests of degree
  ; `degree`, and their degree-0 holes have trivial values as
  ; contents. We return their degree-0 concatenation.
  (list-foldr hns (n-hn dss degree #/hnb-labeled 0 #/trivial)
  #/fn hn tail
    (hypernest-bind-one-degree (n-d dss 0) hn #/fn hole data
      (dissect data (trivial)
        tail))))


; Each of these tags can occur as a bump of the indicated degree. They
; represent data that was carried over from the original
; s-expression-shaped Racket syntax objects when they were converted
; to hn-expressions. The `hn-tag-0-s-expr-stx` can potentially contain
; an entire subtree in Racket syntax object form, but usually the
; layers are broken up into separate `hn-tag-1-list` nodes. Instead,
; an `hn-tag-0-s-expr-syntax` is usually used just for miscellaneous
; atomic values occurring in the syntax, like symbols and datums.
;
(struct-easy (hn-tag-0-s-expr-stx stx) #:equal)
(struct-easy (hn-tag-1-list stx-example) #:equal)
(struct-easy (hn-tag-1-list* stx-example) #:equal)
(struct-easy (hn-tag-1-vector stx-example) #:equal)
(struct-easy (hn-tag-1-prefab key stx-example) #:equal)

; The `hn-tag-unmatched-closing-bracket` tag can occur as a bump of
; degree (N + 2) for any nonzero N. It represents a closing bracket of
; degree N. It should be an empty contour of a single degree-(N + 1)
; hole, which should contain the syntax that was parsed to create this
; closing bracket. If that hole is removed, it should be an empty
; contour of a single degree-N hole, which should contain the syntax
; that lies beyond this closing bracket.
;
; These tags usually signify there's an unmatched bracket error, but
; opening bracket syntaxes can specifically look for them and process
; them to build things like `hn-tag-nest` values.
;
; NOTE: See "NOTE COUNTOURS".
;
(struct-easy (hn-tag-unmatched-closing-bracket) #:equal)

; The `hn-tag-nest` tag can occur as a bump of degree (N + 2) for any
; nonzero N. It represents an unlabeled nested region of degree N. It
; should be an empty contour of a single degree-(N + 1) hole, which
; should contain the syntax that was parsed to create the brackets
; around this nested region. If that hole is removed, it should be an
; empty contour of a single degree-N hole, which should contain the
; syntax that lies in the interior of this region.
;
; These are essentially supposed to represent bumps in the hypernest,
; but they're represented in a slightly higher-dimensional format to
; let us round-trip the bracket syntax back to s-expressions when
; desired. If the preserved s-expression syntax (the degree-(N + 1)
; hole and everything inside it) is removed from all of these, they
; can be replaced with degree-N hypernest bumps. The value of these
; bumps is something trivial; if we actually represented them as
; bumps, we would probably use `(hn-tag-nest)` as the label for the
; bumps themselves so that they could coexist with user-defined bumps.
;
; NOTE: See "NOTE COUNTOURS".
;
(struct-easy (hn-tag-nest) #:equal)

; NOTE CONTOURS: Although we could represent
; `hn-tag-unmatched-closing-bracket` or `hn-tag-nest` bumps by using a
; bump where the interior of the bump contains the syntax of the
; bracket (and a hole in the bump still contains the interior of the
; bracket), or by using a bump where the interior of the bump contains
; the interior of the bracket (and the data annotation on the bump
; contains a hypernest containing the syntax of the bracket), neither
; of those seems like a particularly consistent choice. By
; representing this using a bump with a trivial interior, we represent
; both regions of data in the same way, as contoured holes in the
; bump. This may help clarify how the two regions are related.

; This is a value designated to let hn-expression users put custom
; kinds of data into an hn-expression. It can occur as a bump or a
; hole of any degree.
(struct-easy (hn-tag-other val) #:equal)


; This recursively converts the given Racket syntax object into a
; degree-1 hypernest. It performs a kind of macroexpansion on lists
; that begin with an identifier with an appropriate
; `syntax-local-value` binding. For everything else, it uses
; particular data structures in the bumps of the result hypernest to
; represent the other atoms, proper lists, improper lists, vectors,
; and prefab structs it encounters.
;
(define/contract (s-expr-stx->hn-expr dss stx)
  (->i
    (
      [dss dim-successors-sys?]
      [stx syntax?])
    [_ (dss) (hypernest/c #/dim-successors-sys-dim-sys dss)])
  (expect (n-d-maybe dss 2) (just _)
    (error "Expected at least 2 successors to exist for the zero dimension")
  #/mat
    (syntax-parse stx
      [ (op:id arg ...)
        (maybe-bind (syntax-local-maybe #'op) #/fn op
        #/maybe-map (hn-builder-syntax-maybe op) #/fn proc
        #/list op proc)]
      [op:id
        (maybe-bind (syntax-local-maybe #'op) #/fn op
        #/maybe-map (hn-builder-syntax-maybe op) #/fn proc
        #/list op proc)]
      [_ (nothing)])
    (just #/list op proc)
    
    ; If `stx` is shaped like `op` or `(op arg ...)` where `op` is
    ; bound to an `hn-builder-syntax?` syntax transformer according to
    ; `syntax-local-value`, then we invoke it on `stx`.
    ;
    ; TODO: See if we can call this more like a Racket syntax
    ; transformer. If we can, we'll want to approximate this process:
    ;
    ;   - Disarm `stx`.
    ;
    ;   - Remove any `'taint-mode` and `'certify-mode` syntax
    ;     properties from `stx`.
    ;
    ;   - Rearm the result, and apply syntax properties to the result
    ;     that correspond to the syntax properties of `stx`. It's not
    ;     really clear how this would be performed, since the result
    ;     is an hn-expression that may "contain" several encoded
    ;     Racket syntax objects (their trees encoded as concentric
    ;     degree-2 bumps and their leaves as degree-1 bumps) that are
    ;     peers of each other, as well as several bumps that have
    ;     nothing to do with this encoding of Racket syntax objects.
    ;
    ; TODO: Use a contract to enforce that `proc` returns a single
    ; value matching `(hypernest/c ds)`. Currently, if it doesn't,
    ; then `s-expr-stx->hn-expr` reports that it has broken its own
    ; contract.
    ;
    (proc op stx)
  #/w- process-list
    (fn elems
      (list-map elems #/fn elem #/s-expr-stx->hn-expr dss elem))
  ; NOTE: We go to some trouble to detect improper lists here. This is
  ; so we can preserve the metadata of syntax objects occurring in
  ; tail positions partway through the list, which we would lose track
  ; of if we simply used `syntax->list` or `syntax-parse` with a
  ; pattern of `(elem ...)` or `(elem ... . tail)`.
  #/w- s (syntax-e stx)
  #/w- stx-example (datum->syntax stx #/list)
  #/w- make-list-layer
    (fn metadata elems
      ; When we call this, `elems` is a list of degree-1 hypernests,
      ; and their degree-0 holes have trivial contents. We
      ; degree-0-concatenate them, and then we degree-1-concatenate a
      ; degree-1 bump around that, holding the given metadata. We
      ; return the degree-1 hypernest that results.
      (hypernest-set-degree (n-d dss 1)
      #/hypernest-bind-one-degree (n-d dss 1)
        (n-hn dss 2
          (hnb-open 1 metadata)
          (hnb-labeled 1 #/trivial)
          0
          0
        #/hnb-labeled 0 #/trivial)
      #/fn hole data
        (hypernest-promote (n-d dss 2)
        #/n-hn-append0 dss 1 elems)))
  
  ; We traverse into proper and improper lists.
  #/if (pair? s)
    (dissect (improper-list->list-and-tail s) (list elems tail)
    #/w- elems (process-list elems)
    #/mat tail (list)
      ; The metadata we pass in here represents the `list` operation,
      ; so its data contains the metadata of `stx` so that clients
      ; processing this hypernest-based encoding of this Racket syntax
      ; can recover this layer of information about it.
      (make-list-layer (hn-tag-1-list stx-example) elems)
    ; NOTE: Even though we call the full `s-expr-stx->hn-expr`
    ; operation here, we already know `#'tail` can't be cons-shaped.
    ; Usually it'll be wrapped up as an atom. However, it could still
    ; be expanded as a identifier syntax or processed as a vector or
    ; as a prefab struct.
    #/w- tail (s-expr-stx->hn-expr dss tail)
      ; This is like the proper list case, but this time the metadata
      ; represents an improper list operation (`list*`) rather than a
      ; proper list operation (`list`).
      (make-list-layer (hn-tag-1-list* stx-example)
      #/append elems #/list tail))
  
  ; We traverse into prefab structs.
  #/w- key (prefab-struct-key s)
  #/if key
    (make-list-layer (hn-tag-1-prefab key stx-example)
    #/process-list #/cdr #/vector->list #/struct->vector s)
  
  #/syntax-parse stx
    ; We traverse into vectors.
    [ #(elem ...)
      (w- elems (process-list #/syntax->list #'(elem ...))
        ; This is like the proper list case, but this time the
        ; metadata represents a vector operation (`vector`) rather
        ; than a proper list operation (`list`).
        (make-list-layer (hn-tag-1-vector stx-example) elems))]
    
    [_
      ; We return a degree-1 hypernest with trivial contents in its
      ; degree-0 hole and with a single degree-0 bump that contains
      ; `stx` itself (put in a container so that it can be
      ; distinguished from degree-0 bumps that a user-defined syntax
      ; introduces for a different reason).
      (n-hn dss 1 (hnb-open 0 #/hn-tag-0-s-expr-stx stx)
      #/hnb-labeled 0 #/trivial)]))

; This recursively converts the given Racket syntax object into an
; degree-1 hypernest just like `s-expr-stx->hn-expr`, but it expects
; the outermost layer of the syntax object to be a proper list, and it
; does not represent that list in the result, so the result will
; "splice" all the list's elements in whatever place it's inserted.
;
; TODO: See if we'll ever use this. Right now it's just here as a
; reminder that hn-expressions aren't quite "expressions" so much as
; snippets of expression-like data.
;
(define/contract (splicing-s-expr-stx->hn-expr dss stx)
  (->i
    (
      [dss dim-successors-sys?]
      [stx syntax?])
    [_ (dss) (hypernest/c #/dim-successors-sys-dim-sys dss)])
  (expect (n-d-maybe dss 2) (just _)
    (error "Expected 2 successors to exist for the zero dimension")
  #/n-hn-append0 dss 1
  #/list-map (syntax->list stx) #/fn elem
    (s-expr-stx->hn-expr dss elem)))


(struct-easy (simple-hn-builder-syntax impl)
  #:other
  #:property prop:hn-builder-syntax
  (fn this stx
    (expect this (simple-hn-builder-syntax impl)
      (error "Expected this to be a simple-hn-builder-syntax")
    #/impl stx)))

(struct-easy
  (syntax-and-hn-builder-syntax syntax-impl hn-builder-syntax-impl)
  #:other
  
  #:property prop:procedure
  (fn this stx
    (expect this
      (syntax-and-hn-builder-syntax
        syntax-impl hn-builder-syntax-impl)
      (error "Expected this to be a syntax-and-hn-builder-syntax")
    #/syntax-impl stx))
  
  #:property prop:hn-builder-syntax
  (fn this stx
    (expect this
      (syntax-and-hn-builder-syntax
        syntax-impl hn-builder-syntax-impl)
      (error "Expected this to be a syntax-and-hn-builder-syntax")
    #/hn-builder-syntax-impl stx))
)
