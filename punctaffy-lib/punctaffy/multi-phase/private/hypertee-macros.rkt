#lang parendown racket/base

(require #/only-in racket/contract/base -> any/c list/c)
(require #/only-in racket/contract/region define/contract)
(require #/only-in syntax/parse id syntax-parse)

(require #/only-in lathe-comforts dissect expect fn mat w- w-loop)
(require #/only-in lathe-comforts/list list-map)
(require #/only-in lathe-comforts/maybe
  just maybe? maybe-bind nothing)
(require #/only-in lathe-comforts/struct struct-easy)

(require #/only-in punctaffy/multi-phase/private/trees2 hypertee?)


; TODO: We're going to take this approach:
;
;
; Conceptually, we'll treat the program's syntax as an
; unbounded-degree hypertee built up from a sequential encoding. That
; is, the program's syntax is an arrangement of
; "holes with holes with holes..." of various degrees, and the
; particular holes we're using can always be flattened into a sequence
; of degree-annotated parentheses.
;
; Since we're in Racket, our syntax transformers will take
; s-expression-shaped syntax objects as input like usual. When we
; write a syntax transformer where we care to process
; higher-dimensional syntax, we will explicitly convert these syntax
; objects to unbounded-degree hypertees using a special macroexpansion
; procedure called `s-expr-stx->ht-expr`. We call the unbounded-degree
; hypertees "ht-expressions" when we use them for syntax this way.
;
; This conversion is a kind of macroexpansion only because we don't
; hardcode particular symbols for the higher-dimensional brackets that
; this conversion process handles. Instead of hardcoding those
; symbols, we allow users to define their own
; syntax-object-to-ht-expression transformers. These are a lot like
; reader extensions, since they create higher-dimensional syntax out
; of a lower-dimensional encoding.
;
;
; Of all the Racket syntax transformers that will invoke
; `s-expr-stx->ht-expr`, the most familiar will be ones that imitate
; `quasiquote` or `quasisyntax`. Unfortunately, these operations are
; somewhat deceptive examples because they distract us with another
; idiosyncratic behavior: They use the higher-dimensional structure of
; their syntax to construct a *lower-dimensional* data structure, and
; in the process they have to re-encode some of that
; higher-dimensional structure in terms of bracket symbols. The
; output's bracket symbols can't always correspond exactly to the ones
; the user entered in the first place (that is, if we want the output
; to be capable of containing any arrangement of symbols the user
; needs), but in general it's very preferable for them to be as close
; an approximation to the input's brackets as possible. That way the
; user can maintain quoted code using the same syntax they use to
; maintain other code, without constantly escaping every bracket they
; write.
;
; This means for the sake of `quasiquote` and `quasisyntax` operations
; in particular,  when we parse low-dimensional syntax into
; high-dimensional syntax, we also need to *preserve* enough details
; to reconstruct the original; we need some amount of round-tripping
; support.
;
; So, should we just set aside `quasiquote` and `quasisyntax` until we
; talk about other examples? Not necessarily, because even our
; simplest examples will tend to encounter *some* of the same
; idiosyncrasies: We eventually have to compile every operation to
; Racket code, which is a low-dimensional data structure again. The
; input format of many of our operations will consist of snippets of
; Racket code, and if these inputs are used like patchwork to generate
; some Racket code (as traditional Racket syntax transformers often
; do), then those parts of the output should be a perfectly faithful
; recreation of the input; any imperfection will be visible to Racket
; syntax transformer calls occurring in that snippet.
;
; So now we can state it in a way that isn't so particular: We need
; round-tripping of the brackets we use. Not every operation will use
; all the round-tripping data, and that data will rarely be a core
; motivation in the design of a high-dimensional syntax transformer,
; but it is data almost all of those designs will have minor uses for.



(define/contract (improper-list->list-and-tail lst)
  (-> any/c #/list/c list? any/c)
  (w-loop next rev-elems (list) tail lst
    (expect tail (cons elem tail) (list (reverse rev-elems) tail)
    #/next (cons elem rev-elems) tail)))

(define/contract (syntax-local-maybe identifier)
  (-> any/c maybe?)
  (if (identifier? identifier)
    (w- dummy (list #/list)
    #/w- local (syntax-local-value identifier #/fn dummy)
    #/if (eq? local dummy)
      (nothing)
      (just local))
    (nothing)))


; TODO: Generalize hypertees to allow "unbounded-degree hypertees" so
; that we can use them as syntax.



; This struct property indicates a syntax's behavior as the kind of
; macro expected by `s-expr-stx->ht-expr`.
(define-values
  (prop:ht-builder-syntax ht-builder-syntax? ht-builder-syntax-ref)
  (make-struct-type-property 'ht-builder-syntax))

(define/contract (ht-builder-syntax-maybe x)
  (-> any/c maybe?)
  (if (ht-builder-syntax? x)
    (just #/ht-builder-syntax-ref x)
    (nothing)))

; This recursively converts the given Racket syntax object into an
; unbounded-degree hypertee. It performs a kind of macroexpansion on
; lists that begin with an identifier with an appropriate
; `syntax-local-value` binding. For everything else, it uses
; particular data structures in the holes of the result hypertee to
; represent the other atoms, proper lists, improper lists, vectors,
; and prefabricated structs it encounters.
(define/contract (s-expr-stx->ht-expr stx)
  (-> syntax? hypertee?)
  (mat
    (syntax-parse stx
      [ (op:id arg ...)
        (maybe-bind (syntax-local-maybe #'op) #/fn op
        #/ht-builder-syntax-maybe op)]
      [op:id
        (maybe-bind (syntax-local-maybe #'op) #/fn op
        #/ht-builder-syntax-maybe op)]
      [_ (nothing)])
    (just op)
    
    ; If `stx` is shaped like `op` or `(op arg ...)` where `op` is
    ; bound to an `ht-builder-syntax?` syntax transformer according to
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
    ;     is an ht-expression that may "contain" several encoded
    ;     Racket syntax objects (their trees encoded as concentric
    ;     degree-2 holes and their leaves as degree-1 holes) that are
    ;     peers of each other, as well as several holes that have
    ;     nothing to do with this encoding of Racket syntax objects.
    ;
    ; TODO: Use a contract to enforce that `op` returns a single
    ; value matching `hypertee?`. Currently, if it doesn't, then
    ; `s-expr-stx->ht-expr` reports that it has broken its own
    ; contract.
    ;
    (op stx)
  #/w- process-list
    (fn elems
      (list-map (syntax->list elems) #/fn elem
        (s-expr-stx->ht-expr elem)))
  ; NOTE: We go to some trouble to detect improper lists here. This is
  ; so we can preserve the metadata of syntax objects occurring in
  ; tail positions partway through the list, which we would lose track
  ; of if we simply used `syntax->list` or `syntax-parse` with a
  ; pattern of `(elem ...)` or `(elem ... . tail)`.
  #/w- s (syntax-e stx)
  #/if (pair? s)
    (dissect (improper-list->list-and-tail s) (list elems tail)
    #/w- elems (process-list elems)
    #/mat tail (list)
      ; TODO: At this point, the elements of `elems` should be
      ; unbounded-degree hypertees, and their degree-0 holes should
      ; have trivial contents. Degree-0-concatenate them, and then
      ; degree-1-concatenate a degree-2 hole around that. Return the
      ; unbouded-degree hypertee that results.
      ;
      ; That degree-2 hole represents the `list` operation, so its
      ; data should contain the metadata of `stx` so that clients
      ; processing this hypertee-based encoding of this Racket syntax
      ; can recover this layer of information about it.
      ;
      'TODO
    ; NOTE: Even though we call the full `s-expr-stx->ht-expr`
    ; operation here, we already know `#'tail` can't be cons-shaped,
    ; so we know it's either going to be expanded as a symbol macro or
    ; wrapped up as an atom.
    #/w- tail (s-expr-stx->ht-expr tail)
      ; TODO: At this point, the elements of `elems` as well as `tail`
      ; should be unbounded-degree hypertees. Concatenate and wrap
      ; them the same way as for the proper list case, but this time
      ; the degree-2 hole represents an improper list operation
      ; (`list*`) rather than a proper list operation (`list`).
      'TODO)
  #/syntax-parse stx
    [ #(elem ...)
      (w- elems (process-list #'(elem ...))
        ; TODO: At this point, the elements of `elems` should be
        ; unbounded-degree hypertees. Concatenate and wrap them the
        ; same way as for the proper list case, but this time the
        ; degree-2 hole represents a vector operation (`vector`)
        ; rather than a proper list operation (`list`).
        'TODO)]
    ; TODO: We support lists and vectors, but let's also support
    ; prefabricated structs like Racket's `quasiquote` and
    ; `quasisyntax` do.
    
    [_
      ; TODO: Return an unbounded-degree hypertee with trivial
      ; contents in its degree-0 hole, and with a single degree-1 hole
      ; that contains `stx` itself (perhaps put in some kind of
      ; container so that it can be distinguished from degree-1 holes
      ; that a user-defined syntax introduces for a different reason).
      'TODO]))

; This recursively converts the given Racket syntax object into an
; unbounded-degree hypertee just like `s-expr-stx->ht-expr`, but it
; expects the outermost layer of the syntax object to be a proper
; list, and it does not represent that list in the result, so the
; result will "splice" all the list's elements in whatever place it's
; inserted.
;
; TODO: See if we'll ever use this. Right now it's just here as a
; reminder that ht-expressions aren't quite "expressions" so much as
; snippets of expression-like data.
;
(define/contract (splicing-s-expr-stx->ht-expr stx)
  (-> syntax? hypertee?)
  (w- elems
    (list-map (syntax->list stx) #/fn elem
      (s-expr-stx->ht-expr elem))
    ; TODO: At this point, the elements of `elems` should be
    ; unbounded-degree hypertees, and their degree-0 holes should
    ; have trivial contents. Return their degree-0 concatenation.
    'TODO))


(struct-easy (simple-ht-builder-syntax impl)
  #:other
  #:property prop:ht-builder-syntax
  (lambda (this stx)
    (expect this (simple-ht-builder-syntax impl)
      (error "Expected this to be a simple-ht-builder-syntax")
    #/impl stx)))

(struct-easy
  (syntax-and-ht-builder-syntax syntax-impl ht-builder-syntax-impl)
  #:other
  
  #:property prop:procedure
  (lambda (this stx)
    (expect this
      (syntax-and-ht-builder-syntax
        syntax-impl ht-builder-syntax-impl)
      (error "Expected this to be a syntax-and-ht-builder-syntax")
    #/syntax-impl stx))
  
  #:property prop:ht-builder-syntax
  (lambda (this stx)
    (expect this
      (syntax-and-ht-builder-syntax
        syntax-impl ht-builder-syntax-impl)
      (error "Expected this to be a syntax-and-ht-builder-syntax")
    #/ht-builder-syntax-impl stx))
)
