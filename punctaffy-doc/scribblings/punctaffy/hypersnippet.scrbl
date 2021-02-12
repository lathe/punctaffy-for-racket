#lang parendown scribble/manual

@; punctaffy/scribblings/punctaffy/hypersnippet.scrbl
@;
@; Hypersnippet data structures and interfaces.

@;   Copyright 2020, 2021 The Lathe Authors
@;
@;   Licensed under the Apache License, Version 2.0 (the "License");
@;   you may not use this file except in compliance with the License.
@;   You may obtain a copy of the License at
@;
@;       http://www.apache.org/licenses/LICENSE-2.0
@;
@;   Unless required by applicable law or agreed to in writing,
@;   software distributed under the License is distributed on an
@;   "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
@;   either express or implied. See the License for the specific
@;   language governing permissions and limitations under the License.


@(require punctaffy/scribblings/private/shim)

@(shim-require-various-for-label)

@(define lathe-comforts-doc
  '(lib "lathe-comforts/scribblings/lathe-comforts.scrbl"))


@title[#:tag "hypersnippet-data" #:style 'toc]{
  Representation of Hypersnippet Data
}



@local-table-of-contents[]



@section[#:tag "dim-sys"]{Dimension Systems}

@defmodule[punctaffy/hypersnippet/dim]


@subsection[#:tag "dim-sys-in-general"]{Dimension Systems in General}

@deftogether[(
  @defproc[(dim-sys? [v any/c]) boolean?]
  @defproc[(dim-sys-impl? [v any/c]) boolean?]
  @defthing[prop:dim-sys (struct-type-property/c dim-sys-impl?)]
)]{
  Structure type property operations for @tech{dimension systems}. These are systems of operations over a space of @tech{dimension numbers} which can be used to describe the @tech{degree} of a @tech{hypersnippet}.
}

@defproc[(dim-sys-dim/c [ds dim-sys?]) flat-contract?]{
  Returns a flat contract which recognizes any @tech{dimension number} of the given @tech{dimension system}.
}

@defproc[
  (dim-sys-dim-max [ds dim-sys?] [arg (dim-sys-dim/c ds)] ...)
  (dim-sys-dim/c ds)
]{
  Returns the maximum of zero or more @tech{dimension numbers}.
  
  The maximum of zero dimension numbers is well-defined; it's the least dimension number of the @tech{dimension system}. Typically this is 0, representing the dimension of 0-dimensional shapes. We recommend to use @racket[dim-sys-dim-zero] in that case for better clarity of intent.
}

@defproc[(dim-sys-dim-zero [ds dim-sys?]) (dim-sys-dim/c ds)]{
  Returns the least @tech{dimension numbers} of the @tech{dimension system}. Typically this is 0, representing the dimension of 0-dimensional shapes.
  
  This is equivalent to calling @racket[dim-sys-dim-max] without passing in any dimension numbers. We provide this alternative for better clarity of intent.
}

@defproc[
  (dim-sys-dim-max-of-two
    [ds dim-sys?]
    [a (dim-sys-dim/c ds)]
    [b (dim-sys-dim/c ds)])
  (dim-sys-dim/c ds)
]{
  Returns the maximum of two given @tech{dimension numbers}.
  
  This is equivalent to calling @racket[dim-sys-dim-max] without exactly two dimension numbers. We provide this alternative to clarify how @racket[make-dim-sys-impl-from-max-of-two] works. It may also be good for catching errors.
}

@deftogether[(
  @defproc[
    (dim-sys-dim<?
      [ds dim-sys?]
      [a (dim-sys-dim/c ds)]
      [b (dim-sys-dim/c ds)])
    boolean?
  ]
  @defproc[
    (dim-sys-dim<=?
      [ds dim-sys?]
      [a (dim-sys-dim/c ds)]
      [b (dim-sys-dim/c ds)])
    boolean?
  ]
  @defproc[
    (dim-sys-dim=?
      [ds dim-sys?]
      [a (dim-sys-dim/c ds)]
      [b (dim-sys-dim/c ds)])
    boolean?
  ]
)]{
  Compares the two given @tech{dimension numbers}, returning whether they're in strictly ascending order (less than), weakly ascending order (less than or equal), or equal.
}

@defproc[
  (dim-sys-dim=0? [ds dim-sys?] [d (dim-sys-dim/c ds)])
  boolean?
]{
  Returns whether the given dimension number is equal to 0 (in the sense of @racket[dim-sys-dim-zero]).
}

@deftogether[(
  @defproc[
    (dim-sys-dim</c [ds dim-sys?] [bound (dim-sys-dim/c ds)])
    flat-contract?
  ]
  @defproc[
    (dim-sys-dim=/c [ds dim-sys?] [bound (dim-sys-dim/c ds)])
    flat-contract?
  ]
)]{
  Returns a flat contract which recognizes @tech{dimension numbers} which are strictly less than the given one, or which are equal to the given one.
}

@defproc[(dim-sys-0<dim/c [ds dim-sys?]) flat-contract?]{
  Returns a flat contract which recognizes @tech{dimension numbers} which are nonzero, in the sense of @racket[dim-sys-dim-zero].
}

@defproc[
  (make-dim-sys-impl-from-max-of-two
    [dim/c (-> dim-sys? flat-contract?)]
    [dim=?
      (->i
        (
          [_ds dim-sys?]
          [_a (_ds) (dim-sys-dim/c _ds)]
          [_b (_ds) (dim-sys-dim/c _ds)])
        [_ boolean?])]
    [dim-zero (->i ([_ds dim-sys?]) [_ (_ds) (dim-sys-dim/c _ds)])]
    [dim-max-of-two
      (->i
        (
          [_ds dim-sys?]
          [_a (_ds) (dim-sys-dim/c _ds)]
          [_b (_ds) (dim-sys-dim/c _ds)])
        [_ (_ds) (dim-sys-dim/c _ds)])])
  dim-sys-impl?
]{
  Given implementations for @racket[dim-sys-dim/c], @racket[dim-sys-dim=?], @racket[dim-sys-dim-zero], and @racket[dim-sys-dim-max-of-two], returns something a struct can use to implement the @racket[prop:dim-sys] interface.
  
  The given method implementations should observe some algebraic laws. Namely, the @racket[dim=?] operation should be a decision procedure for equality of @tech{dimension numbers}, and the @racket[dim-max-of-two] operation should be associative, commutative, and idempotent with @racket[dim-zero] as its identity element.
}


@subsection[#:tag "dim-sys-category-theory"]{Category-Theoretic Dimension System Manipulations}

@deftogether[(
  @defproc[(dim-sys-morphism-sys? [v any/c]) boolean?]
  @defproc[(dim-sys-morphism-sys-impl? [v any/c]) boolean?]
  @defthing[
    prop:dim-sys-morphism-sys
    (struct-type-property/c dim-sys-morphism-sys-impl?)
  ]
)]{
  @; TODO: Figure out if we should put the 's inside the @deftech{...} brackets (even if that means we need to write out the link target explicitly).
  
  Structure type property operations for structure-preserving transformations from one @tech{dimension system}'s @tech{dimension numbers} to another's. In particular, these preserve relatedness of dimension numbers under the @racket[dim-sys-dim=?] and @racket[dim-sys-dim-max] operations.
}

@defproc[
  (dim-sys-morphism-sys-source [dsms dim-sys-morphism-sys?])
  dim-sys?
]{
  Returns a @racket[dim-sys-morphism-sys?] value's source @tech{dimension system}.
}

@defproc[
  (dim-sys-morphism-sys-replace-source
    [dsms dim-sys-morphism-sys?]
    [new-s dim-sys?])
  dim-sys-morphism-sys?
]{
  Returns a @racket[dim-sys-morphism-sys?] value like the given one, but with its source @tech{dimension system} replaced with the given one. This may raise an error if the given value isn't similar enough to the one being replaced. This is intended only for use by @racket[dim-sys-morphism-sys/c] and similar error-detection systems as a way to replace a value with one that reports better errors.
}

@defproc[
  (dim-sys-morphism-sys-target [dsms dim-sys-morphism-sys?])
  dim-sys?
]{
  Returns a @racket[dim-sys-morphism-sys?] value's target @tech{dimension system}.
}

@defproc[
  (dim-sys-morphism-sys-replace-target
    [dsms dim-sys-morphism-sys?]
    [new-s dim-sys?])
  dim-sys-morphism-sys?
]{
  Returns a @racket[dim-sys-morphism-sys?] value like the given one, but with its target @tech{dimension system} replaced with the given one. This may raise an error if the given value isn't similar enough to the one being replaced. This is intended only for use by @racket[dim-sys-morphism-sys/c] and similar error-detection systems as a way to replace a value with one that reports better errors.
}

@defproc[
  (dim-sys-morphism-sys-morph-dim
    [ms dim-sys-morphism-sys?]
    [d (dim-sys-dim/c (dim-sys-morphism-sys-source ms))])
  (dim-sys-dim/c (dim-sys-morphism-sys-target ms))
]{
  Transforms a @tech{dimension number} according to the given @racket[dim-sys-morphism-sys?] value.
}

@defproc[
  (make-dim-sys-morphism-sys-impl-from-morph
    [source
      (-> dim-sys-morphism-sys? dim-sys?)]
    [replace-source
      (-> dim-sys-morphism-sys? dim-sys? dim-sys-morphism-sys?)]
    [target
      (-> dim-sys-morphism-sys? dim-sys?)]
    [replace-target
      (-> dim-sys-morphism-sys? dim-sys? dim-sys-morphism-sys?)]
    [morph-dim
      (->i
        (
          [_ms dim-sys-morphism-sys?]
          [_object (_ms)
            (dim-sys-dim/c (dim-sys-morphism-sys-source _ms))])
        [_ (_ms) (dim-sys-dim/c (dim-sys-morphism-sys-target _ms))])])
  dim-sys-morphism-sys-impl?
]{
  Given implementations for the following methods, returns something a struct can use to implement the @racket[prop:dim-sys-morphism-sys] interface.
  
  @itemlist[
    @item{@racket[dim-sys-morphism-sys-source]}
    @item{@racket[dim-sys-morphism-sys-replace-source]}
    @item{@racket[dim-sys-morphism-sys-target]}
    @item{@racket[dim-sys-morphism-sys-replace-target]}
    @item{@racket[dim-sys-morphism-sys-morph-dim]}
  ]
  
  When the @tt{replace} methods don't raise errors, they should observe the lens laws: The result of getting a value after it's been replaced should be the same as just using the value that was passed to the replacer. The result of replacing a value with itself should be the same as not using the replacer at all. The result of replacing a value and replacing it a second time should be the same as just skipping to the second replacement.
  
  Moreover, the @tt{replace} methods should not raise an error when a value is replaced with itself. They're intended only for use by @racket[dim-sys-morphism-sys/c] and similar error-detection systems, which will tend to replace a replace a value with one that reports better errors.
  
  The other given method implementation (@racket[dim-sys-morphism-sys-morph-dim]) should observe some algebraic laws. Namely, it should preserve the relatedness of @tech{dimension numbers} by the @racket[dim-sys-dim=?] and @racket[dim-sys-dim-max] operations (not to mention operations like @racket[dim-sys-dim-zero], which are derived from those). In more symbolic terms (using a pseudocode DSL):
  
  @racketblock[
    (#:for-all
      _ms dim-sys-morphism-sys?
      #:let _s (dim-sys-morphism-sys-source _ms)
      #:let _t (dim-sys-morphism-sys-target _ms)
      
      (#:should-be-equal
        (morph-dim _ms (dim-sys-dim-zero _s))
        (dim-sys-dim-zero _t)))
    
    (#:for-all
      _ms dim-sys-morphism-sys?
      #:let _s (dim-sys-morphism-sys-source _ms)
      #:let _t (dim-sys-morphism-sys-target _ms)
      _a (dim-sys-dim/c _s)
      _b (dim-sys-dim/c _s)
      
      (#:should-be-equal
        (morph-dim _ms (dim-sys-dim-max _s _a _b))
        (dim-sys-dim-max _t
          (morph-dim _ms _a)
          (morph-dim _ms _b))))
    
    (#:for-all
      _ms dim-sys-morphism-sys?
      #:let _s (dim-sys-morphism-sys-source _ms)
      #:let _t (dim-sys-morphism-sys-target _ms)
      _a (dim-sys-dim/c _s)
      _b (dim-sys-dim/c _s)
      
      (#:should-be-equal
        (dim-sys-dim=? _s  _a _b)
        (dim-sys-dim=? _t (morph-dim _ms _a) (morph-dim _ms _b))))
  ]
}

@defproc[
  (dim-sys-morphism-sys/c [source/c contract?] [target/c contract?])
  contract?
]{
  Returns a contract that recognizes any @racket[dim-sys-morphism-sys?] value whose source and target @tech{dimension systems} are recognized by the given contracts.
  
  The result is a flat contract as long as the given contracts are flat.
  
  @; TODO: Support chaperone contracts as well.
}

@; TODO: Consider having a `makeshift-dim-sys-morphism-sys`, similar to `makeshift-functor-sys`.

@defproc[
  (dim-sys-morphism-sys-identity [endpoint dim-sys?])
  (dim-sys-morphism-sys/c (ok/c endpoint) (ok/c endpoint))
]{
  Returns the identity @racket[dim-sys-morphism-sys?] value on the given @tech{dimension system}. This is a transformation that goes from the given dimension system to itself, taking every @tech{dimension number} to itself.
}

@defproc[
  (dim-sys-morphism-sys-chain-two
    [ab dim-sys-morphism-sys?]
    [bc
      (dim-sys-morphism-sys/c
        (ok/c (dim-sys-morphism-sys-target ab))
        any/c)])
  (dim-sys-morphism-sys/c
    (ok/c (dim-sys-morphism-sys-source ab))
    (ok/c (dim-sys-morphism-sys-target bc)))
]{
  Returns the composition of the two given @racket[dim-sys-morphism-sys?] values. This is a transformation that goes from the first transformation's source @tech{dimension system} to the second transformation's target dimension system, transforming every @tech{dimension number} by applying the first transformation and then the second. The target of the first transformation should match the source of the second.
  
  This composition operation is written in @emph{diagrammatic order}, where in the process of reading off the arguments from left to right, we proceed from the source to the target of each transformation. Composition is often written with its arguments the other way around (e.g. in Racket's @racket[compose] operation).
}

@deftogether[(
  @defidform[dim-sys-category-sys]
  @defform[#:link-target? #f (dim-sys-category-sys)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (dim-sys-category-sys)
  ]
  @defproc[(dim-sys-category-sys? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct a @racketmodname[lathe-morphisms/in-fp/category] category (@racket[category-sys?]) where the objects are @tech{dimension systems} and the morphisms are structure-preserving transformations between them (namely, @racket[dim-sys-morphism-sys?] values).
  
  Every two @tt{dim-sys-category-sys} values are @racket[equal?]. One such value is always an @racket[ok/c] match for another.
}

@defproc[
  (functor-from-dim-sys-sys-apply-to-morphism
    [fs (functor-sys/c dim-sys-category-sys? any/c)]
    [dsms dim-sys-morphism-sys?])
  (category-sys-morphism/c (functor-sys-target fs)
    (functor-sys-apply-to-object fs
      (dim-sys-morphism-sys-source dsms))
    (functor-sys-apply-to-object fs
      (dim-sys-morphism-sys-target dsms)))
]{
  Uses the given @racketmodname[lathe-morphisms/in-fp/category] functor to transform a @racket[dim-sys-morphism-sys?] value.
  
  This is equivalent to @racket[(functor-sys-apply-to-morphism fs (dim-sys-morphism-sys-source dsms) (dim-sys-morphism-sys-target dsms) dsms)].
}

@defproc[
  (natural-transformation-from-from-dim-sys-sys-apply-to-morphism
    [nts
      (natural-transformation-sys/c
        dim-sys-category-sys? any/c any/c any/c)]
    [dsms dim-sys-morphism-sys?])
  (category-sys-morphism/c
    (natural-transformation-sys-endpoint-target nts)
    (functor-sys-apply-to-object
      (natural-transformation-sys-source nts)
      (dim-sys-morphism-sys-source dsms))
    (functor-sys-apply-to-object
      (natural-transformation-sys-target nts)
      (dim-sys-morphism-sys-target dsms)))
]{
  Uses the given @racketmodname[lathe-morphisms/in-fp/category] natural transformation to transform a @racket[dim-sys-morphism-sys?] value.
  
  This is equivalent to @racket[(natural-transformation-sys-apply-to-morphism fs (dim-sys-morphism-sys-source dsms) (dim-sys-morphism-sys-target dsms) dsms)].
}

@defproc[(dim-sys-endofunctor-sys? [v any/c]) boolean?]{
  Returns whether the given value is a @racketmodname[lathe-morphisms/in-fp/category] functor from the category @racket[(dim-sys-category-sys)] to itself.
}

@defproc[
  (make-dim-sys-endofunctor-sys-impl-from-apply
    [apply-to-dim-sys (-> dim-sys-endofunctor-sys? dim-sys? dim-sys?)]
    [apply-to-dim-sys-morphism-sys
      (->i
        (
          [_es dim-sys-endofunctor-sys?]
          [_ms dim-sys-morphism-sys?])
        [_ (_es _ms)
          (dim-sys-morphism-sys/c
            (ok/c
              (functor-sys-apply-to-object _es
                (dim-sys-morphism-sys-source _ms)))
            (ok/c
              (functor-sys-apply-to-object _es
                (dim-sys-morphism-sys-target _ms))))])])
  functor-sys-impl?
]{
  Given implementations for the following methods, returns something a struct can use to implement the @racket[prop:functor-sys] interface in a way that makes it satisfy @racket[dim-sys-endofunctor-sys?].
  
  @itemlist[
    @item{@racket[functor-sys-apply-to-object]}
    @item{@racket[functor-sys-apply-to-morphism]}
  ]
  
  These method implementations should observe the same algebraic laws as those required by @racket[make-functor-sys-impl-from-apply].
  
  This is essentially a shorthand for calling @racket[make-functor-sys-impl-from-apply] and supplying the appropriate source- and target-determining method implementations.
}

@; TODO: Consider having `dim-sys-endofunctor-sys-morphism-sys?`, similar to `functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?`.

@; TODO: Consider having `make-dim-sys-endofunctor-sys-morphism-sys-impl-from-apply`, similar to `make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-apply`.


@subsection[#:tag "dim-sys-examples"]{Commonly Used Dimension Systems}

@deftogether[(
  @defidform[nat-dim-sys]
  @defform[#:link-target? #f (nat-dim-sys)]
  @defform[#:kind "match expander" #:link-target? #f (nat-dim-sys)]
  @defproc[(nat-dim-sys? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct a @tech{dimension system} (@racket[dim-sys?]) where the @tech{dimension numbers} are the @racket[natural?] numbers and the @racket[dim-sys-dim-max] operation is @racket[max].
  
  The @racket[dim-sys-dim/c] of a @racket[nat-dim-sys] is a flat contract.
  
  Every two @tt{nat-dim-sys} values are @racket[equal?]. One such value is always an @racket[ok/c] match for another.
}

@deftogether[(
  @defidform[extended-with-top-dim-finite]
  @defform[#:link-target? #f (extended-with-top-dim-finite original)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (extended-with-top-dim-finite original)
  ]
  @defproc[(extended-with-top-dim-finite? [v any/c]) boolean?]
  @defproc[
    (extended-with-top-dim-finite-original
      [d extended-with-top-dim-finite?])
    any/c
  ]
)]{
  Struct-like operations which construct and deconstruct an @racket[extended-with-top-dim?] value that represents one of the original @tech{dimension numbers} of a @tech{dimension system} that was extended with an infinite dimension number.
  
  Two @tt{extended-with-top-dim-finite} values are @racket[equal?] if they contain @racket[equal?] elements.
}

@deftogether[(
  @defidform[extended-with-top-dim-infinite]
  @defform[#:link-target? #f (extended-with-top-dim-infinite)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (extended-with-top-dim-infinite)
  ]
  @defproc[(extended-with-top-dim-infinite? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct an @racket[extended-with-top-dim?] value that represents the infinite @tech{dimension number} of a @tech{dimension system} that was extended with one.
  
  Every two @tt{extended-with-top-dim-infinite} values are @racket[equal?].
}

@defproc[(extended-with-top-dim? [v any/c]) boolean?]{
  Returns whether the given value is a @tech{dimension number} of a @tech{dimension system} that was extended with an infinite dimension number. That is, it checks that the value is either an @racket[extended-with-top-dim-finite?] value or an @racket[extended-with-top-dim-infinite?] value.
}

@defproc[
  (extended-with-top-dim/c [original-dim/c contract?])
  contract?
]{
  Returns a contract that recognizes an @racket[extended-with-top-dim?] value where the unextended @tech{dimension system}'s corresponding @tech{dimension number}, if any, abides by the given contract.
  
  The resulting contract has the same @tech[#:doc lathe-comforts-doc]{contract obstinacy} as the given one.
}

@defproc[
  (extended-with-top-dim=?
    [original-dim=? (-> any/c any/c boolean?)]
    [a extended-with-top-dim?]
    [b extended-with-top-dim?])
  boolean?
]{
  Returns whether the two given @racket[extended-with-top-dim?] values are equal, given a function for checking whether two @tech{dimension numbers} of the unextended @tech{dimension system} are equal.
  
  If the given function is not the decision procedure of a decidable equivalence relation, then neither is this one. In that case, this one merely relates two finite dimension numbers if they would be related by @racket[original-dim=?] in the unextended dimension system.
}

@deftogether[(
  @defidform[extended-with-top-dim-sys]
  @defform[
    #:link-target? #f
    (extended-with-top-dim-sys original)
    #:contracts ([original dim-sys?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (extended-with-top-dim-sys original)
  ]
  @defproc[(extended-with-top-dim-sys? [v any/c]) boolean?]
  @defproc[
    (extended-with-top-dim-sys-original
      [ds extended-with-top-dim-sys?])
    dim-sys?
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{dimension system} (@racket[dim-sys?]) where the @tech{dimension numbers} are @racket[(extended-with-top-dim/c (dim-sys-dim/c original))] values. That is to say, the dimension numbers are all the dimension numbers of the @racket[original] dimension system (wrapped in @racket[extended-with-top-dim-finite]) and one more dimension number greater than the rest (@racket[extended-with-top-dim-infinite]).
  
  The resulting dimension system's @racket[dim-sys-dim-max] operation corresponds with the original operation on the @racket[extended-with-top-dim-finite?] dimension numbers, and it treats the @racket[extended-with-top-dim-infinite?] dimension number as being greater than the rest.
  
  Two @tt{extended-with-top-dim-sys} values are @racket[equal?] if they contain @racket[equal?] elements. One such value is an @racket[ok/c] match for another if the first's element is @racket[ok/c] for the second's.
}

@deftogether[(
  @defidform[extended-with-top-dim-sys-morphism-sys]
  @defform[
    #:link-target? #f
    (extended-with-top-dim-sys-morphism-sys original)
    #:contracts ([original dim-sys-morphism-sys?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (extended-with-top-dim-sys-morphism-sys original)
  ]
  @defproc[
    (extended-with-top-dim-sys-morphism-sys? [v any/c])
    boolean?
  ]
  @defproc[
    (extended-with-top-dim-sys-morphism-sys-original
      [dsms extended-with-top-dim-sys-morphism-sys?])
    dim-sys-morphism-sys?
  ]
)]{
  Struct-like operations which construct and deconstruct a @racket[dim-sys-morphism-sys?] value where the source and target are @racket[extended-with-top-dim-sys?] values and the action on finite @tech{dimension numbers} is the given @racket[dim-sys-morphism-sys?]. In other words, this transforms @racket[extended-with-top-dim?] values by transforming their @racket[extended-with-top-dim-finite-original] values, if any.
  
  Two @tt{extended-with-top-dim-sys-morphism-sys} values are @racket[equal?] if they contain @racket[equal?] elements. One such value is an @racket[ok/c] match for another if the first's element is @racket[ok/c] for the second's.
}

@deftogether[(
  @defidform[extended-with-top-dim-sys-endofunctor-sys]
  @defform[
    #:link-target? #f
    (extended-with-top-dim-sys-endofunctor-sys)
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (extended-with-top-dim-sys-endofunctor-sys)
  ]
  @defproc[
    (extended-with-top-dim-sys-endofunctor-sys? [v any/c])
    boolean?
  ]
)]{
  @; TODO: See if we can link the terms "category" and "functor" to the Lathe Morphisms docs.
  
  Struct-like operations which construct and deconstruct a @racketmodname[lathe-morphisms/in-fp/category] @racket[functor-sys?] value where the source and target categories are both @racket[(dim-sys-category-sys)] and the action on morphisms is @racket[extended-with-top-dim-sys-morphism-sys]. In other words, this value represents the transformation-transforming functionality of @racket[extended-with-top-dim-sys-morphism-sys] together with the assurance that its meta-transformation respects the compositional laws of the object-transformations the way a functor does.
  
  Every two @tt{extended-with-top-dim-sys-morphism-sys} values are @racket[equal?]. One such value is always an @racket[ok/c] match for another.
}

@deftogether[(
  @defidform[extend-with-top-dim-sys-morphism-sys]
  @defform[
    #:link-target? #f
    (extend-with-top-dim-sys-morphism-sys source)
    #:contracts ([source dim-sys?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (extend-with-top-dim-sys-morphism-sys source)
  ]
  @defproc[(extend-with-top-dim-sys-morphism-sys? [v any/c]) boolean?]
  @defproc[
    (extend-with-top-dim-sys-morphism-sys-source
      [dsms extend-with-top-dim-sys-morphism-sys?])
    dim-sys?
  ]
)]{
  Struct-like operations which construct and deconstruct a @racket[dim-sys-morphism-sys?] value where the source is any @racket[dim-sys?] value and the target is a corresponding @racket[dim-sys?] made by @racket[extended-with-top-dim-sys]. The action on @tech{dimension numbers} is @racket[extended-with-top-dim-finite]. In other words, this transforms dimension numbers by transporting them to their corresponding elements in a @tech{dimension system} that has been extended with an additional number greater than all the others. (No dimension number from the source is transported to the additional number in the target.)
  
  Two @tt{extend-with-top-dim-sys-morphism-sys} values are @racket[equal?] if they contain @racket[equal?] elements. One such value is an @racket[ok/c] match for another if the first's element is @racket[ok/c] for the second's.
}

@; TODO: See if we should implement and export a natural
@; transformation corresponding to
@; `extend-with-top-dim-sys-morphism-sys`, likely named
@; `extend-with-top-dim-sys-natural-transformation-sys`.

@deftogether[(
  @defidform[extended-with-top-finite-dim-sys]
  @defform[
    #:link-target? #f
    (extended-with-top-finite-dim-sys original)
    #:contracts ([original dim-sys?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (extended-with-top-finite-dim-sys original)
  ]
  @defproc[(extended-with-top-finite-dim-sys? [v any/c]) boolean?]
  @defproc[
    (extended-with-top-finite-dim-sys-original
      [ds extended-with-top-dim-sys?])
    dim-sys?
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{dimension system} (@racket[dim-sys?]) where the @tech{dimension numbers} are all the dimension numbers of the @racket[original] dimension system wrapped in @racket[extended-with-top-dim-finite], and where the action on those dimension numbers is the same as the original action. That is to say, this is a dimension system that @emph{represents} its dimension numbers the same way @racket[extended-with-top-dim-sys] does, but which doesn't actually include the additional @racket[extended-with-top-dim-infinite] dimension number.
  
  This is primarily used as the source of @racket[unextend-with-top-dim-sys], which otherwise would have to have an error-handling case if it encountered the @racket[extended-with-top-dim-infinite] value. (TODO: Consider passing an error handler to @racket[unextend-with-top-dim-sys-morphism-sys]. Perhaps that would be a better approach than this, since we would be encouraged to write errors where the error messages make the most sense, not rely indirectly on the error messages of the contracts of the behaviors we invoke. On the other hand, perhaps that error-handling should take place in a morphism (or natural transformation) from @racket[extended-with-top-dim-sys] to @racket[extended-with-top-finite-dim-sys].)
  
  Two @tt{extended-with-top-finite-dim-sys} values are @racket[equal?] if they contain @racket[equal?] elements. One such value is an @racket[ok/c] match for another if the first's element is @racket[ok/c] for the second's.
}

@; TODO: See if we should implement and export a functor corresponding
@; to `extend-with-top-finite-dim-sys`, likely named
@; `extend-with-top-finite-dim-sys-endofunctor-sys`.

@deftogether[(
  @defidform[unextend-with-top-dim-sys-morphism-sys]
  @defform[
    #:link-target? #f
    (unextend-with-top-dim-sys-morphism-sys target)
    #:contracts ([target dim-sys?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (unextend-with-top-dim-sys-morphism-sys target)
  ]
  @defproc[
    (unextend-with-top-dim-sys-morphism-sys? [v any/c])
    boolean?
  ]
  @defproc[
    (unextend-with-top-dim-sys-morphism-sys-target
      [dsms extend-with-top-dim-sys-morphism-sys?])
    dim-sys?
  ]
)]{
  Struct-like operations which construct and deconstruct a @racket[dim-sys-morphism-sys?] value where the source is an @racket[extended-with-top-finite-dim-sys?] @tech{dimension system} and the target is the dimension system it's based on. The action on @tech{dimension numbers} is to unwrap their @racket[extended-with-top-dim-finite] wrappers.
  
  Note that the source is an @racket[extended-with-top-finite-dim-sys?] value, not an @racket[extended-with-top-dim-sys?] value, so this operation can't encounter a @racket[extended-with-top-dim-infinite] value and get stuck.
  
  Two @tt{extend-with-top-dim-sys-morphism-sys} values are @racket[equal?] if they contain @racket[equal?] elements. One such value is an @racket[ok/c] match for another if the first's element is @racket[ok/c] for the second's.
}

@; TODO: See if we should implement and export a natural
@; transformation corresponding to
@; `unextend-with-top-dim-sys-morphism-sys`, likely named
@; `unextend-with-top-dim-sys-natural-transformation-sys`.



@section[#:tag "hyperstack"]{Hyperstacks}

@defmodule[punctaffy/hypersnippet/hyperstack]

A @deftech{hyperstack} is a stack-like abstraction that makes it easier to maintain the state of a computation that converts between structured @tech{hypersnippet} data and sequential representations of it (like parsing from text or pretty-printing). Hyperstacks generalize the way a more traditional parser might push onto a stack when it encounters an opening paren and pop from the stack when it finds a closing paren.

In particular, hyperstack pops correspond to inititiating @tech{holes} in a hypersnippet being parsed. When a hole has @tech{degree} 0, this is simply a closing paren, but when it has some higher degree N, the hole itself is a degree-N hypersnippet that will have some closing brackets of its own later in the stream. In order to interact properly with all those brackets later on, a hyperstack pop at dimension N basically pushes at every dimension less than N at the same time. (See the description of @racket[hyperstack-pop] for more details.)

Hyperstack pushes correspond to initiating @tech{bumps} in a @tech{hypernest}, generalizing the way the way opening parens tend to correspond to the nodes of a syntax tree.


@defproc[(hyperstack? [v any/c]) boolean?]{
  Returns whether the given value is a @tech{hyperstack}. A hyperstack is a stack-like data structure that helps to keep track of nested @tech{hypersnippet} structure while traversing a stream of text and brackets. It helps in the same way that a stack helps to keep track of s-expression-like nesting while traversing a stream of text and parentheses.
}

@defproc[(hyperstack/c [ds dim-sys?]) contract?]{
  Returns a contract which recognizes @tech{hyperstacks} whose @tech{dimension system} is an @racket[ok/c] match for the given one.
}

@defproc[(hyperstack-dim-sys [stack hyperstack?]) dim-sys?]{
  Returns the @tech{dimension system} of the given @tech{hyperstack}.
}

@defproc[
  (hyperstack-dimension [stack hyperstack?])
  (dim-sys-dim/c (hyperstack-dim-sys stack))
]{
  Returns the @deftech{hyperstack dimension} of the given @tech{hyperstack}. This is a @tech{dimension number} describing which dimensions of popping the hyperstack currently offers. A hyperstack of dimension N can be popped at any dimension M as long as (M < N).
  
  Over the course of executing a hyperstack-based stream traversal, the dimension of the hyperstack may change as it's updated by pushes and pops. It's important to check up on the dimension sometimes as a way to detect errors in the stream. In particular, if the dimension isn't large enough before performing a @racket[hyperstack-pop] operation, that indicates an unmatched closing bracket in the stream, and if the dimension isn't 0 at the end of the stream, that indicates an unmatched opening bracket.
}

@defproc[
  (make-hyperstack [ds dim-sys?] [dimension (dim-sys-dim/c ds)] [elem any/c])
  (hyperstack/c ds)
]{
  Returns an @tech{hyperstack} (in some sense, an @emph{empty} hyperstack) which has the given @tech{hyperstack dimension}. When it's popped at some dimension N, it reveals the data @racket[elem] and an updated hyperstack that's no more detailed than the caller specifies.
  
  If the dimension is 0 (in the sense of @racket[dim-sys-dim-zero]), then it can't be popped since no dimension is less than that one, so the value of @racket[elem] makes no difference.
  
  Traditional empty stacks are always created with dimension 0. (Traditional nonempty stacks are created by pushing onto an empty one.)
}

@defproc[
  (hyperstack-pop
    [i
      (let ([_ds (hyperstack-dim-sys stack)])
        (dim-sys-dim</c _ds (hyperstack-dimension stack)))]
    [stack hyperstack?]
    [elem any/c])
  (list/c any/c (hyperstack/c (hyperstack-dim-sys stack)))
]{
  Pops the given @tech{hyperstack} at dimension @racket[i], which must be less than the hyperstack's own @tech{hyperstack dimension}. Returns a two-element list consisting of the data value that was revealed by popping the hyperstack and an updated hyperstack.
  
  The updated hyperstack has dimension at least @racket[i], and popping it at dimensions less than @racket[i] will reveal data equal to the given @racket[elem] value and extra hyperstack detail based on @racket[stack].
  
  The updated hyperstack may have dimension greater than @racket[i]. The behavior when popping it at dimensions greater than @racket[i] corresponds to the extra hyperstack detail, if any, that was obtained when @racket[stack] was popped.
  
  Traditional stacks are always popped at dimension 0, so the entire resulting stack is comprised of this "extra information," and we can think of the extra information as representing the next stack frame that was uncovered. When we pop at a dimension greater than 0, we merely initiate a session of higher-dimensional popping. This session is higher-dimensional in the very sense that it may be bounded by several individual popping actions. A 1-dimensional session of popping has a beginning and an end. A 0-dimensional session is just a traditional, instantaneous pop.
  
  When a hyperstack is being used to parse a sequence of @tech{hypersnippet} brackets (such as @tech{hypertee} or @tech{hypernest} brackets), a popping session corresponds to a @tech{hole}, and each @tt{hyperstack-pop} call corresponds to one of the collection of higher-dimensional closing brackets that delimits that hole.
}

@defproc[
  (hyperstack-push
    [bump-degree (dim-sys-dim/c (hyperstack-dim-sys stack))]
    [stack hyperstack?]
    [elem any/c])
  (hyperstack/c (hyperstack-dim-sys stack))
]{
  Returns a @tech{hyperstack} which has @tech{hyperstack dimension} equal to either the given hyperstack's dimension or @racket[bump-degree], whichever is greater. When it's popped at a dimension less than @racket[bump-degree], it reveals the given @racket[elem] as its data and reveals an updated hyperstack that's based on @racket[stack]. When it's popped at any other dimension, it reveals the same data and extra hyperstack detail that the given hyperstack would reveal.
  
  Traditional stacks are always pushed with a @racket[bump-degree] greater than 0, so that the effects of this push can be reversed later with a pop at dimension 0. If the @racket[bump-degree] is a @tech{dimension number} with more than one lesser dimension available to pop at, then this push essentially initiates an extended pushing session that can take more than one pop action to entirely reverse.
  
  For instance, if we push with a @racket[bump-degree] of 2 and then pop at dimension 1, then we need to pop at dimension 0 two more times before the traces of @racket[elem] are gone from the hyperstack. The first pop of dimension 0 finishes the popping session that was initiated by the pop of dimension 1, and the second pop of dimension 0 finishes the pushing session.
  
  When a hyperstack is being used to parse a sequence of @tech{hypernest} brackets, a pushing session corresponds to a @tech{bump}.
}



@section[#:tag "snippet-sys"]{Snippet Systems}

@defmodule[punctaffy/hypersnippet/snippet]


@subsection[#:tag "snippet-sys-in-general"]{Snippet Systems in General}

@deftogether[(
  @defidform[unselected]
  @defform[#:link-target? #f (unselected value)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (unselected value)
  ]
  @defproc[(unselected? [v any/c]) boolean?]
  @defproc[(unselected-value [u unselected?]) any/c]
)]{
  Struct-like operations which construct and deconstruct a @racket[selectable?] value that represents a value that has not been selected to be processed as part of a collection traveral.
  
  Two @tt{unselected} values are @racket[equal?] if they contain @racket[equal?] elements.
}

@deftogether[(
  @defidform[selected]
  @defform[#:link-target? #f (selected value)]
  @defform[#:kind "match expander" #:link-target? #f (selected value)]
  @defproc[(selected? [v any/c]) boolean?]
  @defproc[(selected-value [s selected?]) any/c]
)]{
  Struct-like operations which construct and deconstruct a @racket[selectable?] value that represents a value that has indeed been selected to be processed as part of a collection traveral.
  
  Two @tt{selected} values are @racket[equal?] if they contain @racket[equal?] elements.
}

@defproc[(selectable? [v any/c]) boolean?]{
  Returns whether the given value is a possibly-selected value, which is an arbitrary value that may or may not have been selected to be processed as part of a collection traversal. A possibly-selected value is represented by either an @racket[unselected?] value or a @racket[selected?] value.
  
  (TODO: Consider renaming @tt{selectable?} to @tt{possibly-selected?}.)
}

@defproc[
  (selectable/c [unselected/c contract?] [selected/c contract?])
  contract?
]{
  Returns a contract that recognizes a @racket[selectable?] value where the value abides by @racket[unselected/c] if it's unselected or by @racket[selected/c] if it's selected.
  
  The resulting contract has the same @tech[#:doc lathe-comforts-doc]{contract obstinacy} as the most @tech[#:doc lathe-comforts-doc]{obstinate} of the given contracts.
}

@defproc[
  (selectable-map [s selectable?] [v-to-v (-> any/c any/c)])
  selectable?
]{
  Returns a @racket[selectable?] value similar to the given one, but with its selected element (if any) transformed by the given function.
}

@deftogether[(
  @defproc[(snippet-sys? [v any/c]) boolean?]
  @defproc[(snippet-sys-impl? [v any/c]) boolean?]
  @defthing[
    prop:snippet-sys
    (struct-type-property/c snippet-sys-impl?)
  ]
)]{
  Structure type property operations for @tech{hypersnippet systems} (aka @tech{snippet systems}). These are systems of traversal and concatenation operations over some form of @tech{hypersnippet} data, where the @tech{degrees} of the hypersnippets range over some decided-upon @tech{dimension system}.
  
  @; TODO: Once the link works, add "See @racket[snippet-format-sys?] for a similar bundle of operations which allows the dimension system to be decided upon by the caller."
}

@defproc[(snippet-sys-snippet/c [ss snippet-sys?]) flat-contract?]{
  Returns a flat contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system}.
}

@defproc[(snippet-sys-dim-sys [ss snippet-sys?]) dim-sys?]{
  Returns the @tech{dimension system} that operates on the @tech{degree} numbers of the given @tech{snippet system}'s @tech{hypersnippets}.
}

@defproc[
  (snippet-sys-shape-snippet-sys [ss snippet-sys?])
  snippet-sys?
]{
  Returns the @tech{snippet system} that operates on the @deftech{shapes} of the given @tech{snippet system}'s @tech{hypersnippets}. These shapes are hypersnippets of their own, and they have the same arrangement of @tech{holes} as the hypersnippets they're the shapes of, but they don't contain any content. They're good for representing content-free areas where a hypersnippet's content can be inserted, such as the holes of a fellow hypersnippet.
  
  @; TODO: See if this is really the best place to do @deftech{shapes}. Perhaps we should describe shapes in more detail in the introduction.
}

@defproc[
  (snippet-sys-snippet-degree
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)])
  (dim-sys-dim/c (snippet-sys-dim-sys ss))
]{
  Returns the @tech{degree} (or dimension) of the given @tech{hypersnippet}.
}

@defproc[
  (snippet-sys-snippet-with-degree/c
    [ss snippet-sys?]
    [degree/c flat-contract?])
  flat-contract?
]{
  Returns a flat contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system} if its @tech{degree} satisfies the given flat contract.
}

@deftogether[(
  @defproc[
    (snippet-sys-snippet-with-degree</c
      [ss snippet-sys?]
      [degree (dim-sys-dim/c (snippet-sys-dim-sys ss))])
    flat-contract?
  ]
  @defproc[
    (snippet-sys-snippet-with-degree=/c
      [ss snippet-sys?]
      [degree (dim-sys-dim/c (snippet-sys-dim-sys ss))])
    flat-contract?
  ]
)]{
  Returns a flat contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system} if its @tech{degree} is strictly less than the given one, or if its degree is equal to the given one.
}

@defproc[
  (snippet-sys-snippet-with-0<degree/c [ss snippet-sys?])
  flat-contract?
]{
  Returns a flat contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system} if its @tech{degree} is strictly greater than 0 (in the sense of @racket[dim-sys-dim-zero]).
}

@defproc[
  (snippet-sys-snippetof/ob-c
    [ss snippet-sys?]
    [ob obstinacy?]
    [h-to-value/c
      (-> (snippet-sys-unlabeled-shape/c ss)
        (obstinacy-contract/c ob))])
  (obstinacy-contract/c ob)
]{
  Returns a contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system} if the values in its @tech{holes} abide by the given contracts. The contracts are given by a function @racket[h-to-value/c] that takes the hypersnippet @tech{shape} of a hole and returns a contract for values residing in that hole.
  
  This design allows us to require the values in the holes to somehow @emph{fit} the shapes of the holes they're carried in. It's rather common for the value contracts to depend on at least the @tech{degree} of the hole, if not on its complete shape.
  
  The resulting contract is at least as @tech[#:doc lathe-comforts-doc]{reticent} as the given @tech[#:doc lathe-comforts-doc]{contract obstinacy}. The given contracts must also be at least that reticent.
}

@defproc[
  (snippet-sys-unlabeled-snippet/c [ss snippet-sys?])
  flat-contract?
]{
  Returns a flat contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system} if it has only @racket[trivial?] values in its @tech{holes}.
}

@defproc[
  (snippet-sys-unlabeled-shape/c [ss snippet-sys?])
  flat-contract?
]{
  Returns a flat contract which recognizes any hypersnippet @tech{shape} of the given @tech{snippet system} if it has only @racket[trivial?] values in its @tech{holes}.
}

@defproc[
  (snippet-sys-snippet-zip-selective/ob-c
    [ss snippet-sys?]
    [ob obstinacy?]
    [shape (snippet-sys-snippet/c (snippet-sys-shape-snippet-sys ss))]
    [check-subject-hv?
      (-> (snippet-sys-unlabeled-shape/c ss) any/c boolean?)]
    [hvv-to-subject-v/c
      (-> (snippet-sys-unlabeled-shape/c ss) any/c any/c
        (obstinacy-contract/c ob))])
  (obstinacy-contract/c ob)
]{
  Returns a contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system} if some of its @tech{holes} correspond with the holes of the given @tech{shape} hypersnippet @racket[shape] and if the values in those holes are somehow compatible with the values held in @racket[shape]'s holes.
  
  To determine which holes from the subject will be compared to those in @racket[shape], the given @racket[check-subject-hv?] is called for each of the subject's holes, passing it the hole's shape and the data value it carries. It's expected to return a boolean indicating whether this hole should correspond to some hole in @racket[shape].
  
  To determine if a value in the subject's holes is compatible with a corresponding (same-shaped) hole in @racket[shape], the @racket[hvv-to-subject-v/c] function is called, passing it the hole's shape, the value carried in @racket[shape]'s hole, and the value carried in the subject's hole. It's expected to return a contract, and the value in the subject's hole is expected to abide by that contract.
  
  The resulting contract is at least as @tech[#:doc lathe-comforts-doc]{reticent} as the given @tech[#:doc lathe-comforts-doc]{contract obstinacy}. The given contracts must also be at least that reticent.
}

@defproc[
  (snippet-sys-snippet-fitting-shape/c
    [ss snippet-sys?]
    [shape (snippet-sys-unlabeled-shape/c ss)])
  flat-contract?
]{
  Returns a flat contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system} if its @tech{holes} of low enough @tech{degree} correspond with the holes of the given @tech{shape} hypersnippet @racket[shape] and if there are only @racket[trivial?] values in those holes. Only holes of degree less than the degree of @racket[shape] are constrained this way; other holes don't have to coincide with holes of @racket[shape], and they can have any contents.
  
  This contract is fairly common because it's the kind of compatibility that's needed to concatenate hypersnippets (e.g. using @racket[snippet-sys-snippet-bind]). It's similar to joining two 3D polyhedra along a 2D face they share (and the 1D edges and 0D vertices of that face, which they also share).
}

@defproc[
  (snippet-sys-shape->snippet
    [ss snippet-sys?]
    [shape
      (snippet-sys-snippet/c (snippet-sys-shape-snippet-sys ss))])
  (snippet-sys-snippet-with-degree=/c ss
    (snippet-sys-snippet-degree (snippet-sys-shape-snippet-sys ss)
      shape))
]{
  Given a @tech{hypersnippet} @tech{shape}, returns an content-free hypersnippet which has that shape. The result has carries all the same values in its @tech{holes}.
  
  This operation can be inverted using @racket[snippet-sys-snippet->maybe-shape].
  
  @; TODO: See if the result contract should be more specific. The resulting snippet should always be of the same shape as the input shape.
}

@defproc[
  (snippet-sys-snippet->maybe-shape
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)])
  (maybe/c (snippet-sys-snippet/c (snippet-sys-shape-snippet-sys ss)))
]{
  Checks whether a @tech{hypersnippet} is content-free, and if it is, computes the hypersnippet's @tech{shape}.
  
  The resulting shape, if any, carries all the same values in its @tech{holes}.
  
  This operation is invertible when it succeeds. The resulting shape, if any, can be converted back into a content-free hypersnippet by using @racket[snippet-sys-shape->snippet].
}

@defproc[
  (snippet-sys-snippet-set-degree-maybe
    [ss snippet-sys?]
    [degree (dim-sys-dim/c (snippet-sys-dim-sys ss))]
    [snippet (snippet-sys-snippet/c ss)])
  (maybe/c (snippet-sys-snippet-with-degree=/c ss degree))
]{
  If possible, returns a @tech{hypersnippet} just like the given one but modified to have the given @tech{degree}.
  
  The resulting hypersnippet, if any, has all the same content as the original and carries all the same values in its @tech{holes}.
  
  If the given degree is already the same as the given snippet's degree, this operation succeeds (and returns a snippet equivalent to the original).
  
  If the original snippet has nonzero degree, and if the given degree is greater than the snippet's existing degree, this operation succeeds.
  
  This operation is invertible when it succeeds. The resulting snippet, if any, can be converted back by calling @tt{snippet-sys-snippet-set-degree-maybe} again with the snippet's original degree.
  
  @; TODO: See if the result contract should be more specific. The result should always exist if the snippet already has the given degree, and it should always exist if the given degree is greater than that degree and that degree is nonzero. Moreover, the result should always have the same shape as the input.
}

@defproc[
  (snippet-sys-snippet-done
    [ss snippet-sys?]
    [degree (dim-sys-dim/c (snippet-sys-dim-sys ss))]
    [shape
      (snippet-sys-snippet-with-degree</c
        (snippet-sys-shape-snippet-sys ss)
        degree)]
    [data any/c])
  (snippet-sys-snippet-with-degree=/c ss degree)
]{
  Given a @tech{hypersnippet} @tech{shape}, returns a content-free hypersnippet that fits into a @tech{hole} of that shape and has its own hole of the same shape. The resulting snippet has the given @tech{degree}, which must be high enough that a hole of shape @racket[shape] is allowed. The resulting snippet's @racket[shape]-shaped hole carries the given data value, and its lower-degree holes carry the same data values carried by @racket[shape]'s holes.
  
  The results of this operation are the identity elements of hypersnippet concatenation. It's the identity on both sides: Filling a hypersnippet's hole with one of these hypersnippets and concatenating has no effect, and filling this one's @racket[shape]-shaped hole with another hypersnippet and concatenating has no effect either.
  
  @; TODO: Once the link works, add a mention of @racket[ypersnippet-join] to the above paragraph.
  
  This operation can be inverted using @racket[snippet-sys-snippet-undone].
  
  The results of this operation are always content-free, so they can be successfully converted to shapes by @racket[snippet-sys-snippet->maybe-shape].
  
  @; TODO: See if the result contract should be more specific. The resulting snippet should always be of the same shape as the given shape in its low-degree holes.
}

@defproc[
  (snippet-sys-snippet-undone
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)])
  (maybe/c
    (list/c
      (dim-sys-dim/c (snippet-sys-dim-sys ss))
      (snippet-sys-snippet/c (snippet-sys-shape-snippet-sys ss))
      any/c))
]{
  Checks whether a @tech{hypersnippet} is an identity element of hypersnippet concatenation, and if it is, obtains three values: Its @tech{degree}, the @tech{shape} of @tech{hole} it interacts with in its role as an identity element, and the data value contained in its own hole of that shape.
  
  The resulting hole shape, if any, carries all the same values in its holes that @racket[snippet] carries in its low-degree holes.
  
  This operation is invertible when it succeeds. The resulting shape, if any, can be converted back into a content-free hypersnippet by using @racket[snippet-sys-snippet-done].
  
  (TODO: Consider renaming this to have "maybe" in the name, bringing it closer to @racket[snippet-sys-snippet->maybe-shape] and @racket[snippet-sys-snippet-set-degree-maybe].)
  
  @; TODO: See if the result contract should be more specific. The resulting shape should always be of the same shape as the given snippet's low-degree holes.
}

@; TODO: Reconsider where to arrange this relative to the other operations here.
@defproc[
  (snippet-sys-snippet-select-everything
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)])
  (and/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss snippet))
    (snippet-sys-snippetof/ob-c ss (flat-obstinacy)
      (fn _hole selected?)))
]{
  Returns a @tech{hypersnippet} like the given one, but where the data value carried in each @tech{hole} has been selected for traversal in the sense of @racket[selectable?].
  
  @; TODO: See if the result contract should be more specific. The resulting snippet should always be of the same shape as the given one.
}

@defproc[
  (snippet-sys-snippet-splice
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)]
    [hv-to-splice
      (->i
        (
          [_prefix-hole (snippet-sys-unlabeled-shape/c ss)]
          [_data any/c])
        [_ (_prefix-hole)
          (maybe/c
            (selectable/c any/c
              (and/c
                (snippet-sys-snippet-with-degree=/c ss
                  (snippet-sys-snippet-degree ss snippet))
                (snippet-sys-snippet-fitting-shape/c ss
                  _prefix-hole))))])])
  (maybe/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss snippet)))
]{
  Attempts to concatenate the given "prefix" @tech{hypersnippet} @racket[snippet] to any selected "suffix" hypersnippets computed from the @tech{hole} data by the given selection-attempting data-transforming function @racket[hv-to-splice].
  
  The @racket[hv-to-splice] function is invoked with the @tech{shape} and data value of each hole of the prefix, possibly stopping partway through if at least one of the invocations returns @racket[(nothing)]. If any invocation returns @racket[(nothing)], the overall result is @racket[(nothing)]. Otherwise, the concatenation proceeds successfully.
  
  When an invocation of @racket[hv-to-splice] is successful for some hole of degree N, the result is expected to be a @racket[selectable?] value. If it's @racket[unselected?], a corresponding hole with the @racket[unselected-value] appears verbatim in the concatenation result (without the value being concatenated to the prefix hypersnippet). If it's @racket[selected?], its @racket[selected-value] is expected to be a "suffix" hypersnippet, and it's concatenated into the prefix hypersnippet along the hole it's carried by in the prefix. For this concatenation to work, the suffix hypersnippet is expected to have the same degree as the prefix, and its holes of degree less than N are expected to contain @racket[trivial?] values and to correspond to the holes of the prefix's hole. Any holes of degree not less than N become holes in the concatenated result.
  
  This operation obeys higher-dimensional algebraic laws. We haven't really figured out how to express these laws yet, but they seem to correspond to the category-theoretic notion that this operation performs whiskering of higher-dimensional cells along various dimensions at once. (TODO: Do at least a little better. This could be an ongoing effort, but ideally we would have something to show in the @racket[#:should-be-equal] DSL that we use for other documentation of algebraic laws.)
  
  Some of the lawfulness is a kind of associativity: If we first concatenate along some selected holes and then concatenate along some other holes that weren't selected the first time, that's the same as concatenating along all those holes at once. If a hole's suffix is itself a concatenation of some suffix-prefix to some suffix-suffix, then it doesn't matter whether we concatenate those two parts to form the suffix first or if we concatenate the prefix to the suffix-prefix and then concatenate the suffix-suffix last.
  
  Some of the lawfulness is a kind of unitality: If the concatenation is being performed along a hole where either the prefix or the suffix is an identity element produced by @racket[snippet-sys-snippet-done] for that hole shape, then the result resembles the other snippet. (When the prefix is the identity, the result is equal to the suffix. When the suffix is the identity, the result is the prefix, but with its data value in that hole replaced with the data value that would have been passed to @racket[snippet-sys-snippet-done] when creating the suffix.)
  
  Some of the lawfulness is associativity in a bird's-eye-view form: If all the @racket[hv-to-splice] results are selected suffixes, and if the prefix is content-free (in the sense that it can be converted to a shape by @racket[snippet-sys-snippet->maybe-shape]), then the result is the same as performing multiple concatenations to concatenate the suffixes with each other. In this sense, content-free hypersnippets are like concatenation operations in their own right, possibly like the composition cells of an opetopic higher-dimensional weak category in category theory.
}

@defproc[
  (snippet-sys-snippet-zip-map-selective
    [ss snippet-sys?]
    [shape (snippet-sys-snippet/c (snippet-sys-shape-snippet-sys ss))]
    [snippet
      (snippet-sys-snippetof/ob-c ss (flat-obstinacy)
        (fn _hole selectable?))]
    [hvv-to-maybe-v
      (-> (snippet-sys-unlabeled-shape/c ss) any/c any/c maybe?)])
  (maybe/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss snippet)))
]{
  Attempts to use the data carried in the given @tech{hypersnippet} @tech{shape} to create a snippet like @racket[snippet], but with all its @racket[unselected?] @tech{hole} data values unwrapped and all its @racket[selected?] values replaced by using @racket[hvv-to-maybe-v] to combine @racket[shape]'s data and @racket[snippet]'s data.
  
  The @racket[hvv-to-maybe-v] function is invoked with the shape of each hole to be combined, the data value from that hole in @racket[shape], and the data value from that hole in @racket[snippet].
  
  The traversal may stop partway through with a result of @racket[(nothing)] if it proves to be impossible to align all the holes in @racket[shape] with all the @racket[selected?] holes in @racket[snippet], or if at least one of the @racket[hvv-to-maybe-v] invocations returns @racket[(nothing)].
  
  This operation serves as a way to compare the shape of a snippet with a known shape. For example, when this operation is used with content-free snippets (those which correspond to shapes via @racket[snippet-sys-shape->snippet] and by @racket[snippet-sys-snippet->maybe-shape]), and when those snippets have all their data values selected, it effectively serves as a way to compare two shapes for equality. It can also serve as a way to compute whether a given snippet is a compatible fit for a given hole (even if the snippet has some high-@tech{degree} holes beyond those accounted for in the hole's shape).
  
  When the "comparison" is successful, that means the shape and snippet have sufficiently similar layouts to combine their data values. That allows this comparison to double as a sort of zipping operation.
  
  @; TODO: See if the result contract should be more specific. The resulting snippet should always be of the same shape as the given one.
}

@defproc[
  (snippet-sys-snippet-zip-map
    [ss snippet-sys?]
    [shape (snippet-sys-snippet/c (snippet-sys-shape-snippet-sys ss))]
    [snippet (snippet-sys-snippet/c ss)]
    [hvv-to-maybe-v
      (-> (snippet-sys-unlabeled-shape/c ss) any/c any/c maybe?)])
  (maybe/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss snippet)))
]{
  Attempts to use the data carried in the given @tech{hypersnippet} @tech{shape} to create a snippet like @racket[snippet], but with all its @tech{hole} data values replaced by using @racket[hvv-to-maybe-v] to combine @racket[shape]'s data and @racket[snippet]'s data.
  
  The @racket[hvv-to-maybe-v] function is invoked with the shape of each hole to be combined, the data value from that hole in @racket[shape], and the data value from that hole in @racket[snippet].
  
  The traversal may stop partway through with a result of @racket[(nothing)] if it proves to be impossible to align all the holes in @racket[shape] with all the holes in @racket[snippet], or if at least one of the @racket[hvv-to-maybe-v] invocations returns @racket[(nothing)].
  
  This operation serves as a way to compare the shape of a snippet with a known shape. For example, when this operation is used with content-free snippets (those which correspond to shapes via @racket[snippet-sys-shape->snippet] and by @racket[snippet-sys-snippet->maybe-shape]), it effectively serves as a way to compare two shapes for equality.
  
  When the "comparison" is successful, that means the shape and snippet have sufficiently similar layouts to combine their data values. That allows this comparison to double as a sort of zipping operation.
  
  @; TODO: See if the result contract should be more specific. The resulting snippet should always be of the same shape as the given one.
}

@defproc[
  (snippet-sys-snippet-any?
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)]
    [check-hv?
      (-> (snippet-sys-unlabeled-shape/c ss) any/c boolean?)])
  boolean?
]{
  Iterates over the given @tech{hypersnippet}'s @tech{hole} data values in some order and calls the given function on each one, possibly stopping early if at least one invocation of the function returns @racket[#t]. If any of these invocations of the function returns @racket[#t], the result is @racket[#t]. Otherwise, the result is @racket[#f].
  
  This essentially does for hypersnippets what Racket's @racket[ormap] does for lists.
}

@defproc[
  (snippet-sys-snippet-all?
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)]
    [check-hv?
      (-> (snippet-sys-unlabeled-shape/c ss) any/c boolean?)])
  boolean?
]{
  Iterates over the given @tech{hypersnippet}'s @tech{hole} data values in some order and calls the given function on each one, possibly stopping early if at least one invocation of the function returns @racket[#f]. If any of these invocations of the function returns @racket[#f], the result is @racket[#f]. Otherwise, the result is @racket[#t].
  
  This essentially does for hypersnippets what Racket's @racket[andmap] does for lists.
}

@defproc[
  (snippet-sys-snippet-each
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)]
    [visit-hv (-> (snippet-sys-unlabeled-shape/c ss) any/c any)])
  void?
]{
  Iterates over the given @tech{hypersnippet}'s @tech{hole} data values in some order and calls the given procedure on each one. The procedure is called only for its side effects. The overall result of this call is @racket[(void)].
  
  This essentially does for hypersnippets what Racket's @racket[for-each] does for lists.
}

@defproc[
  (snippet-sys-snippet-map-maybe
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)]
    [hv-to-maybe-v
      (-> (snippet-sys-unlabeled-shape/c ss) any/c maybe?)])
  (maybe/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss snippet)))
]{
  Iterates over the given @tech{hypersnippet}'s @tech{hole} data values in some order and calls the given function on each one, possibly stopping early if at least one invocation of the function returns @racket[(nothing)]. If any of these invocations of the function returns @racket[(nothing)], the result is @racket[(nothing)]. Otherwise, the result is a @racket[just?] of a hypersnippet where the values have been replaced with the corresponding @racket[hv-to-maybe-v] function results.
  
  @; TODO: See if the result contract should be more specific. The resulting snippet should always be of the same shape as the given one.
}

@defproc[
  (snippet-sys-snippet-map
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)]
    [hv-to-v (-> (snippet-sys-unlabeled-shape/c ss) any/c any/c)])
  (snippet-sys-snippet-with-degree=/c ss
    (snippet-sys-snippet-degree ss snippet))
]{
  Transforms the given @tech{hypersnippet}'s @tech{hole} data values by calling the given function on each one.
  
  @; TODO: See if the result contract should be more specific. The resulting snippet should always be of the same shape as the given one.
}

@defproc[
  (snippet-sys-snippet-map-selective
    [ss snippet-sys?]
    [snippet
      (snippet-sys-snippetof/ob-c ss (flat-obstinacy)
        (fn _hole selectable?))]
    [hv-to-v (-> (snippet-sys-unlabeled-shape/c ss) any/c any/c)])
  (snippet-sys-snippet-with-degree=/c ss
    (snippet-sys-snippet-degree ss snippet))
]{
  Transforms the given @tech{hypersnippet}'s @tech{hole} data values by calling the given function on each @racket[selected?] one.
  
  @; TODO: See if the result contract should be more specific. The resulting snippet should always be of the same shape as the given one.
}

@defproc[
  (snippet-sys-snippet-select
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)]
    [check-hv?
      (-> (snippet-sys-unlabeled-shape/c ss) any/c boolean?)])
  (and/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss snippet))
    (snippet-sys-snippetof/ob-c ss (flat-obstinacy)
      (fn _hole selectable?)))
]{
  Turns the given @tech{hypersnippet}'s @tech{hole} data values into @racket[selectable?] values by calling the given function to decide whether each one should be @racket[selected?].
  
  @; TODO: See if the result contract should be more specific. The resulting snippet should always be of the same shape as the given one, and it should have `selectable?` values in its holes.
}

@defproc[
  (snippet-sys-snippet-select-if-degree
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)]
    [check-degree?
      (-> (dim-sys-dim/c (snippet-sys-dim-sys ss)) boolean?)])
  (and/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss snippet))
    (snippet-sys-snippetof/ob-c ss (flat-obstinacy)
      (fn _hole selectable?)))
]{
  Turns the given @tech{hypersnippet}'s @tech{hole} data values into @racket[selectable?] values by calling the given function on each hole's @tech{degree} decide whether the value should be @racket[selected?].
  
  @; TODO: See if the result contract should be more specific. The resulting snippet should always be of the same shape as the given one, and it should have `selectable?` values in its holes.
}

@defproc[
  (snippet-sys-snippet-select-if-degree<
    [ss snippet-sys?]
    [degreee (dim-sys-dim/c (snippet-sys-dim-sys ss))]
    [snippet (snippet-sys-snippet/c ss)])
  (and/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss snippet))
    (snippet-sys-snippetof/ob-c ss (flat-obstinacy)
      (fn _hole selectable?)))
]{
  Turns the given @tech{hypersnippet}'s @tech{hole} data values into @racket[selectable?] values by selecting the values whose holes' @tech{degrees} are strictly less than the given one.
  
  @; TODO: See if the result contract should be more specific. The resulting snippet should always be of the same shape as the given one, and it should have `selectable?` values in its holes.
}

@defproc[
  (snippet-sys-snippet-bind-selective
    [ss snippet-sys?]
    [prefix (snippet-sys-snippet/c ss)]
    [hv-to-suffix
      (->i
        (
          [_prefix-hole (snippet-sys-unlabeled-shape/c ss)]
          [_data any/c])
        [_ (_prefix-hole)
          (selectable/c any/c
            (and/c
              (snippet-sys-snippet-with-degree=/c ss
                (snippet-sys-snippet-degree ss prefix))
              (snippet-sys-snippet-fitting-shape/c ss
                _prefix-hole)))])])
  (maybe/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss prefix)))
]{
  Concatenates the given "prefix" @tech{hypersnippet} @racket[prefix] to any selected "suffix" hypersnippets computed from the @tech{hole} data by the given selection function @racket[hv-to-suffix].
  
  When @racket[hv-to-suffix] is invoked for some hole of degree N, the result is expected to be a @racket[selectable?] value. If it's @racket[unselected?], a corresponding hole with the @racket[unselected-value] appears verbatim in the concatenation result (without the value being concatenated to the prefix hypersnippet). If it's @racket[selected?], its @racket[selected-value] is expected to be a "suffix" hypersnippet, and it's concatenated into the prefix hypersnippet along the hole it's carried by in the prefix. For this concatenation to work, the suffix hypersnippet is expected to have the same degree as the prefix, and its holes of degree less than N are expected to contain @racket[trivial?] values and to correspond to the holes of the prefix's hole. Any holes of degree not less than N become holes in the concatenated result.
  
  This operation is a specialization of @racket[snippet-sys-snippet-splice] to the case where the concatenation is always successful. It obeys similar higher-dimensional algebraic laws.
}

@defproc[
  (snippet-sys-snippet-join-selective
    [ss snippet-sys?]
    [snippet
      (and/c (snippet-sys-snippet/c ss)
        (snippet-sys-snippetof/ob-c ss (flat-obstinacy)
          (fn _prefix-hole
            (selectable/c any/c
              (and/c
                (snippet-sys-snippet-with-degree=/c ss
                  (snippet-sys-snippet-degree ss snippet))
                (snippet-sys-snippet-fitting-shape/c ss
                  _prefix-hole))))))])
  (maybe/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss snippet)))
]{
  Concatenates the given "prefix" @tech{hypersnippet} @racket[snippet] to any selected "suffix" hypersnippets in its @tech{hole} data values.
  
  Each hole data value is expected to be a @racket[selectable?] value. If it's @racket[unselected?], a corresponding hole with the @racket[unselected-value] appears verbatim in the concatenation result (without the value being concatenated to the prefix hypersnippet). If it's @racket[selected?], its @racket[selected-value] is expected to be a "suffix" hypersnippet, and it's concatenated into the prefix hypersnippet along the hole it's carried by in the prefix. For this concatenation to work, the suffix hypersnippet is expected to have the same degree as the prefix, and its holes of degree less than N are expected to contain @racket[trivial?] values and to correspond to the holes of the prefix's hole. Any holes of degree not less than N become holes in the concatenated result.
  
  This operation is a specialization of @racket[snippet-sys-snippet-splice] to the case where the concatenation is always successful and the transformation function is always the identity. It obeys higher-dimensional algebraic laws similar to those @racket[snippet-sys-snippet-splice] obeys.
}

@defproc[
  (snippet-sys-snippet-bind
    [ss snippet-sys?]
    [prefix (snippet-sys-snippet/c ss)]
    [hv-to-suffix
      (->i
        (
          [_prefix-hole (snippet-sys-unlabeled-shape/c ss)]
          [_data any/c])
        [_ (_prefix-hole)
          (and/c
            (snippet-sys-snippet-with-degree=/c ss
              (snippet-sys-snippet-degree ss prefix))
            (snippet-sys-snippet-fitting-shape/c ss _prefix-hole))])])
  (maybe/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss prefix)))
]{
  Concatenates the given "prefix" @tech{hypersnippet} @racket[prefix] to the "suffix" hypersnippets computed from the @tech{hole} data by the given selection function @racket[hv-to-suffix].
  
  Each suffix hypersnippet is concatenated into the prefix hypersnippet along the hole it's carried by in the prefix. For this concatenation to work, the suffix hypersnippet is expected to have the same degree as the prefix, and its holes of degree less than N are expected to contain @racket[trivial?] values and to correspond to the holes of the prefix's hole. Any holes of degree not less than N become holes in the concatenated result.
  
  This operation is a specialization of @racket[snippet-sys-snippet-bind-selective] to the case where every hole is selected. That, in turn, is a specialization of @racket[snippet-sys-snippet-splice]. Each of these operations obeys similar higher-dimensional algebraic laws.
}

@defproc[
  (snippet-sys-snippet-join
    [ss snippet-sys?]
    [snippet
      (and/c (snippet-sys-snippet/c ss)
        (snippet-sys-snippetof/ob-c ss (flat-obstinacy)
          (fn _prefix-hole
            (and/c
              (snippet-sys-snippet-with-degree=/c ss
                (snippet-sys-snippet-degree ss snippet))
              (snippet-sys-snippet-fitting-shape/c ss
                _prefix-hole)))))])
  (maybe/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss snippet)))
]{
  Concatenates the given "prefix" @tech{hypersnippet} @racket[snippet] to the "suffix" hypersnippets in its @tech{hole} data values.
  
  Each suffix is concatenated into the prefix hypersnippet along the hole it's carried by in the prefix. For this concatenation to work, the suffix hypersnippet is expected to have the same degree as the prefix, and its holes of degree less than N are expected to contain @racket[trivial?] values and to correspond to the holes of the prefix's hole. Any holes of degree not less than N become holes in the concatenated result.
  
  This operation is a specialization of @racket[snippet-sys-snippet-join-selective] to the case where every hole is selected. That, in turn, is a specialization of @racket[snippet-sys-snippet-splice]. Each of these operations obeys similar higher-dimensional algebraic laws.
}

@defproc[
  (make-snippet-sys-impl-from-various-1
    [snippet/c (-> snippet-sys? flat-contract?)]
    [dim-sys (-> snippet-sys? dim-sys?)]
    [shape-snippet-sys (-> snippet-sys? snippet-sys?)]
    [snippet-degree
      (->i
        (
          [_ss snippet-sys?]
          [_snippet (_ss) (snippet-sys-snippet/c _ss)])
        [_ (_ss) (dim-sys-dim/c (snippet-sys-dim-sys _ss))])]
    [shape->snippet
      (->i
        (
          [_ss snippet-sys?]
          [_shape (_ss)
            (snippet-sys-snippet/c
              (snippet-sys-shape-snippet-sys _ss))])
        [_ (_ss _shape)
          (snippet-sys-snippet-with-degree=/c _ss
            (snippet-sys-snippet-degree
              (snippet-sys-shape-snippet-sys _ss)
              _shape))])]
    [snippet->maybe-shape
      (->i
        (
          [_ss snippet-sys?]
          [_snippet (_ss) (snippet-sys-snippet/c _ss)])
        [_ (_ss _snippet)
          (maybe/c
            (snippet-sys-snippet/c
              (snippet-sys-shape-snippet-sys _ss)))])]
    [snippet-set-degree-maybe
      (->i
        (
          [_ss snippet-sys?]
          [_degree (_ss) (dim-sys-dim/c (snippet-sys-dim-sys _ss))]
          [_snippet (_ss) (snippet-sys-snippet/c _ss)])
        [_ (_ss _degree)
          (maybe/c
            (snippet-sys-snippet-with-degree=/c _ss _degree))])]
    [snippet-done
      (->i
        (
          [_ss snippet-sys?]
          [_degree (_ss) (dim-sys-dim/c (snippet-sys-dim-sys _ss))]
          [_shape (_ss _degree)
            (snippet-sys-snippet-with-degree</c
              (snippet-sys-shape-snippet-sys _ss)
              _degree)]
          [_data any/c])
        [_ (_ss _degree)
          (snippet-sys-snippet-with-degree=/c _ss _degree)])]
    [snippet-undone
      (->i
        (
          [_ss snippet-sys?]
          [_snippet (_ss) (snippet-sys-snippet/c _ss)])
        [_ (_ss _snippet)
          (maybe/c
            (list/c
              (dim-sys-dim/c (snippet-sys-dim-sys _ss))
              (snippet-sys-snippet/c
                (snippet-sys-shape-snippet-sys _ss))
              any/c))])]
    [snippet-splice
      (->i
        (
          [_ss snippet-sys?]
          [_snippet (_ss) (snippet-sys-snippet/c _ss)]
          [_hv-to-splice (_ss _snippet)
            (->i
              (
                [_prefix-hole (snippet-sys-unlabeled-shape/c _ss)]
                [_data any/c])
              [_ (_prefix-hole)
                (maybe/c
                  (selectable/c any/c
                    (and/c
                      (snippet-sys-snippet-with-degree=/c _ss
                        (snippet-sys-snippet-degree _ss _snippet))
                      (snippet-sys-snippet-fitting-shape/c ss
                        _prefix-hole))))])])
        [_ (_ss _snippet)
          (maybe/c
            (snippet-sys-snippet-with-degree=/c _ss
              (snippet-sys-snippet-degree _ss _snippet)))])]
    [snippet-zip-map-selective
      (->i
        (
          [_ss snippet-sys?]
          [_shape (_ss)
            (snippet-sys-snippet/c
              (snippet-sys-shape-snippet-sys _ss))]
          [_snippet (_ss)
            (snippet-sys-snippetof/ob-c _ss (flat-obstinacy)
              (fn _hole selectable?))]
          [_hvv-to-maybe-v (_ss)
            (-> (snippet-sys-unlabeled-shape/c _ss) any/c any/c
              maybe?)])
        [_ (_ss _snippet)
          (maybe/c
            (snippet-sys-snippet-with-degree=/c _ss
              (snippet-sys-snippet-degree _ss _snippet)))])])
  snippet-sys-impl?
]{
  Given implementations for the following methods, returns something a struct can use to implement the @racket[prop:snippet-sys] interface.
  
  @itemlist[
    @item{@racket[snippet-sys-snippet/c]}
    @item{@racket[snippet-sys-dim-sys]}
    @item{@racket[snippet-sys-shape-snippet-sys]}
    @item{@racket[snippet-sys-snippet-degree]}
    @item{@racket[snippet-sys-shape->snippet]}
    @item{@racket[snippet-sys-snippet->maybe-shape]}
    @item{@racket[snippet-sys-snippet-set-degree-maybe]}
    @item{@racket[snippet-sys-snippet-done]}
    @item{@racket[snippet-sys-snippet-undone]}
    @item{@racket[snippet-sys-snippet-splice]}
    @item{@racket[snippet-sys-snippet-zip-map-selective]}
  ]
  
  The given method implementations should observe quite a few algebraic laws. At this point, we're not entirely sure what the full extent of these laws should be yet. (TODO: Do at least a little better. This could be an ongoing effort, but ideally we would have something to show in the @racket[#:should-be-equal] DSL that we use for other documentation of algebraic laws.) Even though this isn't going to be comprehensive, here's a rundown of quite a number of the assumptions we make about hypersnippet operations:
  
  @itemlist[
    
    @item{The @racket[shape->snippet] and @racket[snippet->maybe-shape] functions should be two-way partial inverses.}
    
    @item{When any of these various methods is invoked upon only content-free @tech{hypersnippets} (i.e. hypersnippets that can be converted to @tech{shapes} by @racket[snippet->maybe-shape]), its result should be consistent with the corresponding method of the @racket[shape-snippet-sys]. Among other things, this means the @racket[dim-sys] and the @racket[shape-snippet-sys] provided here should be the same as those belonging to the @racket[shape-snippet-sys], and the @racket[shape-snippet-sys] should recognize all its hypersnippets as being content-free.}
    
    @item{The @racket[snippet-set-degree-maybe] function should succeed when setting a snippet's @tech{degree} to the degree it already has.}
    
    @item{The @racket[snippet-set-degree-maybe] function should succeed when setting a snippet's degree to a greater degree, as long as the original degree is nonzero.}
    
    @item{If a call to @racket[snippet-set-degree-maybe] succeeds, calling it again to set the hypersnippet's degree back to its original value should also succeed.}
    
    @item{The @racket[snippet-done] and @racket[snippet-undone] functions should be two-way partial inverses.}
    
    @item{The @racket[snippet-done] function should return content-free hypersnippets (i.e. hypersnippets that can be converted to shapes by @racket[snippet->maybe-shape]).}
    
    @item{If @racket[snippet-set-degree-maybe] succeeds in setting the degree of a result of @racket[snippet-done], the updated hypersnippet should be equal to that which would have been created by @racket[snippet-done] if the updated degree had been specified in the first place. Conversely, if @racket[snippet-done] succeeds for two different degrees, then @racket[snippet-set-degree-maybe] should be able to convert either result into the other.}
    
    @item{The result of @racket[snippet-splice] should be @racket[(nothing)] if and only if the result of invoking the callback on at least one @tech{hole} is @racket[(nothing)].}
    
    @item{If @racket[snippet-splice] sees an @racket[unselected?] hole, its result should be equal to the result it would have if that hole were @racket[selected?] with a suffix obtained by calling @racket[snippet-done] with the hole's shape and @racket[unselected-value].}
    
    @item{If @racket[snippet-splice] gets a content-free prefix snippet and its concatenation succeeds, the result should be the same as concatenating the suffix snippets in a particular arrangement.}
    
    @item{Using @racket[snippet-splice] to concatenate a prefix snippet with a suffix that results from concatenating other snippets should give the same result as using it to concatenate the prefix snippet to the suffixes' prefixes and then concatenating that combined prefix with the suffixes' suffixes.}
    
    @item{The result of @racket[snippet-zip-map-selective] should be @racket[(nothing)] if and only if either the holes of the shape don't correspond to the selected holes of the snippet or the result of invoking the callback on at least one pair of corresponding holes is @racket[(nothing)].}
    
    @item{The @racket[snippet-sys-snippet-zip-map-selective] of the @racket[shape-snippet-sys] should work as a decision procedure for equality of hypersnippet shapes (as long as we select all the holes and supply a correct decision procedure for equality of the holes' data values).}
    
    @item{Given a particular (and not necessarily content-free) hypersnippet with particular @racket[selectable?] values in its holes, if two hypersnippet shapes can successfully @racket[snippet-zip-map-selective] with that hypersnippet, then those two shapes should also be able to zip with each other.}
    
    @item{Given a particular (and not necessarily content-free) hypersnippet with particular @racket[selectable?] values in its holes and a particular hypersnippet shape that  can successfully @racket[snippet-zip-map-selective] with it, another shape should only be able to zip with one of them if it can also zip with the other.}
    
    @item{If we can @racket[snippet-zip-map-selective] a hypersnippet shape with a hypersnippet, we should be able to zip the same shape with the result (as long as we select the same holes of the result).}
    
  ]
}


@subsection[#:tag "snippet-sys-category-theory"]{Category-Theoretic Snippet System Manipulations}

@deftogether[(
  @defproc[(snippet-sys-morphism-sys? [v any/c]) boolean?]
  @defproc[(snippet-sys-morphism-sys-impl? [v any/c]) boolean?]
  @defthing[
    prop:snippet-sys-morphism-sys
    (struct-type-property/c snippet-sys-morphism-sys-impl?)
  ]
)]{
  @; TODO: Figure out if we should put the 's inside the @deftech{...} brackets (even if that means we need to write out the link target explicitly).
  
  Structure type property operations for structure-preserving transformations from one @tech{snippet system}'s @tech{dimension numbers}, hypersnippet @tech{shapes}, and @tech{hypersnippets} to another's. In particular, these preserve relatedness of these values under the various operations a snippet system supplies.
}

@defproc[
  (snippet-sys-morphism-sys-source [ssms snippet-sys-morphism-sys?])
  snippet-sys?
]{
  Returns a @racket[snippet-sys-morphism-sys?] value's source @tech{snippet system}.
}

@defproc[
  (snippet-sys-morphism-sys-replace-source
    [ssms snippet-sys-morphism-sys?]
    [new-s snippet-sys?])
  snippet-sys-morphism-sys?
]{
  Returns a @racket[snippet-sys-morphism-sys?] value like the given one, but with its source @tech{snippet system} replaced with the given one. This may raise an error if the given value isn't similar enough to the one being replaced. This is intended only for use by @racket[snippet-sys-morphism-sys/c] and similar error-detection systems as a way to replace a value with one that reports better errors.
}

@defproc[
  (snippet-sys-morphism-sys-target [ssms snippet-sys-morphism-sys?])
  snippet-sys?
]{
  Returns a @racket[snippet-sys-morphism-sys?] value's target @tech{snippet system}.
}

@defproc[
  (snippet-sys-morphism-sys-replace-target
    [ssms snippet-sys-morphism-sys?]
    [new-s snippet-sys?])
  snippet-sys-morphism-sys?
]{
  Returns a @racket[snippet-sys-morphism-sys?] value like the given one, but with its target @tech{snippet system} replaced with the given one. This may raise an error if the given value isn't similar enough to the one being replaced. This is intended only for use by @racket[snippet-sys-morphism-sys/c] and similar error-detection systems as a way to replace a value with one that reports better errors.
}

@defproc[
  (snippet-sys-morphism-sys-dim-sys-morphism-sys
    [ms snippet-sys-morphism-sys?])
  dim-sys-morphism-sys?
]{
  Given a @tech{snippet system}, obtains the @tech{dimension system} that governs the @tech{degrees} of its @tech{hypersnippets}.
}

@defproc[
  (snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys
    [ms snippet-sys-morphism-sys?])
  snippet-sys-morphism-sys?
]{
  Given a @tech{snippet system}, obtains the @tech{snippet system} that governs how its hypersnippet @tech{shapes} interact with each other as @tech{hypersnippets} in their own right.
}

@; TODO: Consider having a `snippet-sys-morphism-sys-morph-dim` operation.

@; TODO: Consider having a `snippet-sys-morphism-sys-morph-shape` operation.

@defproc[
  (snippet-sys-morphism-sys-morph-snippet
    [ms snippet-sys-morphism-sys?]
    [d (snippet-sys-snippet/c (snippet-sys-morphism-sys-source ms))])
  (snippet-sys-snippet/c (snippet-sys-morphism-sys-target ms))
]{
  Transforms a @tech{hypersnippet} according to the given @racket[snippet-sys-morphism-sys?] value.
}

@defproc[
  (make-snippet-sys-morphism-sys-impl-from-morph
    [source
      (-> snippet-sys-morphism-sys? snippet-sys?)]
    [replace-source
      (-> snippet-sys-morphism-sys? snippet-sys?
        snippet-sys-morphism-sys?)]
    [target
      (-> snippet-sys-morphism-sys? snippet-sys?)]
    [replace-target
      (-> snippet-sys-morphism-sys? snippet-sys?
        snippet-sys-morphism-sys?)]
    [dim-sys-morphism-sys
      (-> snippet-sys-morphism-sys? dim-sys-morphism-sys?)]
    [shape-snippet-sys-morphism-sys
      (-> snippet-sys-morphism-sys? snippet-sys-morphism-sys?)]
    [morph-snippet
      (->i
        (
          [_ms snippet-sys-morphism-sys?]
          [_object (_ms)
            (snippet-sys-snippet/c
              (snippet-sys-morphism-sys-source _ms))])
        [_ (_ms)
          (snippet-sys-snippet/c
            (snippet-sys-morphism-sys-target _ms))])])
  snippet-sys-morphism-sys-impl?
]{
  Given implementations for the following methods, returns something a struct can use to implement the @racket[prop:snippet-sys-morphism-sys] interface.
  
  @itemlist[
    @item{@racket[snippet-sys-morphism-sys-source]}
    @item{@racket[snippet-sys-morphism-sys-replace-source]}
    @item{@racket[snippet-sys-morphism-sys-target]}
    @item{@racket[snippet-sys-morphism-sys-replace-target]}
    @item{@racket[snippet-sys-morphism-sys-dim-sys-morphism-sys]}
    @item{@racket[snippet-sys-morphism-sys-shape-snippet-sys-morphism-sys]}
    @item{@racket[snippet-sys-morphism-sys-morph-snippet]}
  ]
  
  When the @tt{replace} methods don't raise errors, they should observe the lens laws: The result of getting a value after it's been replaced should be the same as just using the value that was passed to the replacer. The result of replacing a value with itself should be the same as not using the replacer at all. The result of replacing a value and replacing it a second time should be the same as just skipping to the second replacement.
  
  Moreover, the @tt{replace} methods should not raise an error when a value is replaced with itself. They're intended only for use by @racket[snippet-sys-morphism-sys/c] and similar error-detection systems, which will tend to replace a replace a value with one that reports better errors.
  
  The other given method implementations should observe some algebraic laws. As with the laws described in @racket[make-snippet-sys-impl-from-various-1], we're not quite sure what these laws should be yet (TODO), but here's an inexhaustive description:
  
  @itemlist[
    
    @item{The @racket[dim-sys-morphism-sys] and the @racket[shape-snippet-sys-morphism-sys] provided here should be the same as those belonging to the @racket[shape-snippet-sys-morphism-sys].}
    
    @item{The @racket[morph-snippet] implementation should preserve the relatedness of @tech{hypersnippets} under by the various operations of the @tech{snippet systems} involved. For instance, if the source snippet system's @racket[snippet-sys-snippet-splice] implementation takes certain input snippets to a certain output snippet, then if we transform each of those using @racket[morph-snippet], the target snippet system's @racket[snippet-sys-snippet-splice] implementation should take values that are equal to the transformed input snippets to values that are equal to the transformed output snippets.}
    
  ]
}

@defproc[
  (snippet-sys-morphism-sys/c
    [source/c contract?]
    [target/c contract?])
  contract?
]{
  Returns a contract that recognizes any @racket[snippet-sys-morphism-sys?] value whose source and target @tech{snippet systems} are recognized by the given contracts.
  
  The result is a flat contract as long as the given contracts are flat.
  
  @; TODO: Support chaperone contracts as well.
}

@; TODO: Consider having a `makeshift-snippet-sys-morphism-sys`, similar to `makeshift-functor-sys`.

@defproc[
  (snippet-sys-morphism-sys-identity [endpoint snippet-sys?])
  (snippet-sys-morphism-sys/c (ok/c endpoint) (ok/c endpoint))
]{
  Returns the identity @racket[snippet-sys-morphism-sys?] value on the given @tech{snippet system}. This is a transformation that goes from the given snippet system to itself, taking every @tech{dimension number}, hypersnippet @tech{shape}, and @tech{hypersnippet} to itself.
}

@defproc[
  (snippet-sys-morphism-sys-chain-two
    [ab snippet-sys-morphism-sys?]
    [bc
      (snippet-sys-morphism-sys/c
        (ok/c (snippet-sys-morphism-sys-target ab))
        any/c)])
  (snippet-sys-morphism-sys/c
    (ok/c (snippet-sys-morphism-sys-source ab))
    (ok/c (snippet-sys-morphism-sys-target bc)))
]{
  Returns the composition of the two given @racket[snippet-sys-morphism-sys?] values. This is a transformation that goes from the first transformation's source @tech{snippet system} to the second transformation's target snippet system, transforming every @tech{dimension number}, hypersnippet @tech{shape}, and @tech{hypersnippet} by applying the first transformation and then the second. The target of the first transformation should match the source of the second.
  
  This composition operation is written in @emph{diagrammatic order}, where in the process of reading off the arguments from left to right, we proceed from the source to the target of each transformation. Composition is often written with its arguments the other way around (e.g. in Racket's @racket[compose] operation).
}

@deftogether[(
  @defidform[snippet-sys-category-sys]
  @defform[#:link-target? #f (snippet-sys-category-sys)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (snippet-sys-category-sys)
  ]
  @defproc[(snippet-sys-category-sys? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct a @racketmodname[lathe-morphisms/in-fp/category] category (@racket[category-sys?]) where the objects are @tech{snippet systems} and the morphisms are structure-preserving transformations between them (namely, @racket[snippet-sys-morphism-sys?] values).
  
  Every two @tt{snippet-sys-category-sys} values are @racket[equal?]. One such value is always an @racket[ok/c] match for another.
}

@defproc[
  (functor-from-snippet-sys-sys-apply-to-morphism
    [fs (functor-sys/c snippet-sys-category-sys? any/c)]
    [ssms snippet-sys-morphism-sys?])
  (category-sys-morphism/c (functor-sys-target fs)
    (functor-sys-apply-to-object fs
      (snippet-sys-morphism-sys-source ssms))
    (functor-sys-apply-to-object fs
      (snippet-sys-morphism-sys-target ssms)))
]{
  Uses the given @racketmodname[lathe-morphisms/in-fp/category] functor to transform a @racket[snippet-sys-morphism-sys?] value.
  
  This is equivalent to @racket[(functor-sys-apply-to-morphism fs (snippet-sys-morphism-sys-source ssms) (snippet-sys-morphism-sys-target ssms) ssms)].
}

@defproc[
  (natural-transformation-from-from-snippet-sys-sys-apply-to-morphism
    [nts
      (natural-transformation-sys/c
        snippet-sys-category-sys? any/c any/c any/c)]
    [ssms snippet-sys-morphism-sys?])
  (category-sys-morphism/c
    (natural-transformation-sys-endpoint-target nts)
    (functor-sys-apply-to-object
      (natural-transformation-sys-source nts)
      (snippet-sys-morphism-sys-source ssms))
    (functor-sys-apply-to-object
      (natural-transformation-sys-target nts)
      (snippet-sys-morphism-sys-target ssms)))
]{
  Uses the given @racketmodname[lathe-morphisms/in-fp/category] natural transformation to transform a @racket[snippet-sys-morphism-sys?] value.
  
  This is equivalent to @racket[(natural-transformation-sys-apply-to-morphism fs (snippet-sys-morphism-sys-source ssms) (snippet-sys-morphism-sys-target ssms) ssms)].
}

@; TODO: Consider having `snippet-sys-endofunctor-sys?`, similar to `dim-sys-endofunctor-sys?`.

@; TODO: Consider having `make-snippet-sys-endofunctor-sys-impl-from-apply`, similar to `make-dim-sys-endofunctor-sys-impl-from-apply`.

@; TODO: Consider having `snippet-sys-endofunctor-sys-morphism-sys?`, similar to `functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?`.

@; TODO: Consider having `make-snippet-sys-endofunctor-sys-morphism-sys-impl-from-apply`, similar to `make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-apply`.

@defproc[(functor-from-dim-sys-to-snippet-sys-sys? [v any/c]) boolean?]{
  Returns whether the given value is a @racketmodname[lathe-morphisms/in-fp/category] functor from the category @racket[(dim-sys-category-sys)] to the category @racket[(snippet-sys-category-sys)].
}

@defproc[
  (make-functor-from-dim-sys-to-snippet-sys-sys-impl-from-apply
    [apply-to-dim-sys
      (-> functor-from-dim-sys-to-snippet-sys-sys? dim-sys?
        snippet-sys?)]
    [apply-to-dim-sys-morphism-sys
      (->i
        (
          [_es functor-from-dim-sys-to-snippet-sys-sys?]
          [_ms dim-sys-morphism-sys?])
        [_ (_es _ms)
          (snippet-sys-morphism-sys/c
            (ok/c
              (functor-sys-apply-to-object _es
                (dim-sys-morphism-sys-source _ms)))
            (ok/c
              (functor-sys-apply-to-object _es
                (dim-sys-morphism-sys-target _ms))))])])
  functor-sys-impl?
]{
  Given implementations for the following methods, returns something a struct can use to implement the @racket[prop:functor-sys] interface in a way that makes it satisfy @racket[functor-from-dim-sys-to-snippet-sys-sys?].
  
  @itemlist[
    @item{@racket[functor-sys-apply-to-object]}
    @item{@racket[functor-sys-apply-to-morphism]}
  ]
  
  These method implementations should observe the same algebraic laws as those required by @racket[make-functor-sys-impl-from-apply].
  
  This is essentially a shorthand for calling @racket[make-functor-sys-impl-from-apply] and supplying the appropriate source- and target-determining method implementations.
}

@defproc[
  (functor-from-dim-sys-to-snippet-sys-sys-morphism-sys? [v any/c])
  boolean?
]{
  Returns whether the given value is a @racketmodname[lathe-morphisms/in-fp/category] natural transformation between two functors which each go from the category @racket[(dim-sys-category-sys)] to the category @racket[(snippet-sys-category-sys)].
  
  This could be called `natural-transformation-from-from-dim-sys-to-to-snippet-sys-sys?`, but that would be even more verbose.
}

@defproc[
  (make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-apply
    [source
      (-> functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        functor-from-dim-sys-to-snippet-sys-sys?)]
    [replace-source
      (->
        functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        functor-from-dim-sys-to-snippet-sys-sys?
        functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?)]
    [target
      (-> functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        functor-from-dim-sys-to-snippet-sys-sys?)]
    [replace-target
      (->
        functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
        functor-from-dim-sys-to-snippet-sys-sys?
        functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?)]
    [apply-to-morphism
      (->i
        (
          [_ms functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?]
          [_dsms dim-sys-morphism-sys?])
        [_ (_ms _dsms)
          (snippet-sys-morphism-sys/c
            (functor-sys-apply-to-object
              (natural-transformation-sys-source _ms)
              (dim-sys-morphism-sys-source _dsms))
            (functor-sys-apply-to-object
              (natural-transformation-sys-target _ms)
              (dim-sys-morphism-sys-target _dsms)))])])
  natural-transformation-sys-impl?
]{
  Given implementations for the following methods, returns something a struct can use to implement the @racket[prop:natural-transformation-sys] interface in a way that makes it satisfy @racket[functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?].
  
  @itemlist[
    @item{@racket[natural-transformation-sys-source]}
    @item{@racket[natural-transformation-sys-replace-source]}
    @item{@racket[natural-transformation-sys-target]}
    @item{@racket[natural-transformation-sys-replace-target]}
    @item{@racket[natural-transformation-sys-apply-to-morphism]}
  ]
  
  These method implementations should observe the same algebraic laws as those required by @racket[make-natural-transformation-sys-impl-from-apply].
  
  This is essentially a shorthand for calling @racket[make-natural-transformation-sys-impl-from-apply] and supplying the appropriate endpoint-source- and endpoint-target-determining method implementations.
}


@subsection[#:tag "snippet-format-sys-in-general"]{Snippet Format Systems in General}

@deftogether[(
  @defproc[(snippet-format-sys? [v any/c]) boolean?]
  @defproc[(snippet-format-sys-impl? [v any/c]) boolean?]
  @defthing[
    prop:snippet-format-sys
    (struct-type-property/c snippet-format-sys-impl?)
  ]
)]{
  Structure type property operations for @deftech{snippet format systems}. These are like @tech{snippet systems} in that they determine operations over hypersnippet @tech{shapes} and @tech{hypersnippets}, but the @tech{dimension system} is left undetermined until the caller chooses it.
}

@defproc[
  (snippet-format-sys-functor [sfs snippet-format-sys?])
  functor-from-dim-sys-to-snippet-sys-sys?
]{
  Returns the @racketmodname[lathe-morphisms/in-fp/category] functor associated with the given @tech{snippet format system}.
  
  This functor takes @tech{dimension systems} to @tech{snippet systems} that use them. It also takes @racket[dim-sys-morphism-sys?] values to @racket[snippet-sys-morphism-sys?] values, which facilitates the conversion of @tech{hypersnippets} between two snippet systems that differ only in their choice of dimension system.
}

@defproc[
  (make-snippet-format-sys-impl-from-functor
    [functor
      (-> snippet-format-sys?
        functor-from-dim-sys-to-snippet-sys-sys?)])
  snippet-format-sys-impl?
]{
  Given an implementation for @racket[snippet-format-sys-functor], returns something a struct can use to implement the @racket[prop:snippet-format-sys] interface.
  
  The given method implementations should observe some algebraic laws. Namely, the result of applying the functor to a @tech{dimension system} should be a @tech{snippet system} that uses it as its @racket[snippet-sys-dim-sys]. Likewise, the result of applying the functor to a @racket[dim-sys-morphism-sys?] should be a @racket[snippet-sys-morphism-sys?] that uses it as its @racket[snippet-sys-morphism-sys-dim-sys-morphism-sys]. In more symbolic terms (using a pseudocode DSL):
  
  @racketblock[
    (#:for-all
      _sfs snippet-format-sys?
      #:let _ffdstsss (snippet-format-sys-functor _sfs)
      _dms dim-sys-morphism-sys?
      
      (#:should-be-equal
        (snippet-sys-morphism-sys-dim-sys-morphism-sys
          (functor-from-dim-sys-sys-apply-to-morphism _ffdstsss _dms))
        _dms))
  ]
}


@subsection[#:tag "snippet-format-sys-category-theory"]{Category-Theoretic Snippet Format System Manipulations}

@deftogether[(
  @defproc[(snippet-format-sys-morphism-sys? [v any/c]) boolean?]
  @defproc[(snippet-format-sys-morphism-sys-impl? [v any/c]) boolean?]
  @defthing[
    prop:snippet-format-sys-morphism-sys
    (struct-type-property/c snippet-format-sys-morphism-sys-impl?)
  ]
)]{
  Structure type property operations for structure-preserving transformations from one @tech{snippet format system} to another. In practical terms, these are ways to transform one kind of @tech{hypersnippet} to another kind of hypersnippet without caring about what @tech{dimension system} is in use.
  
  In terms of category theory, these are based on natural transformations which go beteween the respective @racket[snippet-format-sys-functor] values, which means they're transformations of @racket[dim-sys-morphism-sys?] values to @racket[snippet-sys-morphism-sys?] values which don't necessarily take each identity morphism to an identity morphism. Unlike just any natural transformations, these also respect the fact that a snippet format system always produces a @tech{snippet system} that uses the given dimension system. To respect this, this natural transformation takes a @racket[dim-sys-morphism-sys?] value to a @racket[snippet-sys-morphism-sys?] value which has it as its @racket[snippet-sys-morphism-sys-dim-sys-morphism-sys].
}

@defproc[
  (snippet-format-sys-morphism-sys-source
    [sfsms snippet-format-sys-morphism-sys?])
  snippet-format-sys?
]{
  Returns a @racket[snippet-format-sys-morphism-sys?] value's source @tech{snippet format system}.
}

@defproc[
  (snippet-format-sys-morphism-sys-replace-source
    [sfsms snippet-format-sys-morphism-sys?]
    [new-s snippet-format-sys?])
  snippet-format-sys-morphism-sys?
]{
  Returns a @racket[snippet-format-sys-morphism-sys?] value like the given one, but with its source @tech{snippet format system} replaced with the given one. This may raise an error if the given value isn't similar enough to the one being replaced. This is intended only for use by @racket[snippet-format-sys-morphism-sys/c] and similar error-detection systems as a way to replace a value with one that reports better errors.
}

@defproc[
  (snippet-format-sys-morphism-sys-target
    [sfsms snippet-format-sys-morphism-sys?])
  snippet-format-sys?
]{
  Returns a @racket[snippet-format-sys-morphism-sys?] value's target @tech{snippet format system}.
}

@defproc[
  (snippet-format-sys-morphism-sys-replace-target
    [sfsms snippet-format-sys-morphism-sys?]
    [new-s snippet-format-sys?])
  snippet-format-sys-morphism-sys?
]{
  Returns a @racket[snippet-format-sys-morphism-sys?] value like the given one, but with its target @tech{snippet format system} replaced with the given one. This may raise an error if the given value isn't similar enough to the one being replaced. This is intended only for use by @racket[snippet-format-sys-morphism-sys/c] and similar error-detection systems as a way to replace a value with one that reports better errors.
}

@defproc[
  (snippet-format-sys-morphism-sys-functor-morphism
    [sfsms snippet-format-sys-morphism-sys?])
  functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?
]{
  Returns the @racketmodname[lathe-morphisms/in-fp/category] natural transformation associated with the given @tech{snippet format system} morphism.
  
  This natural transformation takes @racket[dim-sys-morphism-sys?] values to @racket[snippet-sys-morphism-sys?] values that use them as their @racket[snippet-sys-morphism-sys-dim-sys-morphism-sys] values.
}

@defproc[
  (make-snippet-format-sys-morphism-sys-impl-from-morph
    [source
      (-> snippet-format-sys-morphism-sys? snippet-format-sys?)]
    [replace-source
      (-> snippet-format-sys-morphism-sys? snippet-format-sys?
        snippet-format-sys-morphism-sys?)]
    [target
      (-> snippet-format-sys-morphism-sys? snippet-format-sys?)]
    [replace-target
      (-> snippet-format-sys-morphism-sys? snippet-format-sys?
        snippet-format-sys-morphism-sys?)]
    [functor-morphism
      (-> snippet-format-sys-morphism-sys?
        functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?)])
  snippet-format-sys-morphism-sys-impl?
]{
  Given implementations for the following methods, returns something a struct can use to implement the @racket[prop:snippet-format-sys-morphism-sys] interface.
  
  @itemlist[
    @item{@racket[snippet-format-sys-morphism-sys-source]}
    @item{@racket[snippet-format-sys-morphism-sys-replace-source]}
    @item{@racket[snippet-format-sys-morphism-sys-target]}
    @item{@racket[snippet-format-sys-morphism-sys-replace-target]}
    @item{@racket[snippet-format-sys-morphism-sys-functor-morphism]}
  ]
  
  When the @tt{replace} methods don't raise errors, they should observe the lens laws: The result of getting a value after it's been replaced should be the same as just using the value that was passed to the replacer. The result of replacing a value with itself should be the same as not using the replacer at all. The result of replacing a value and replacing it a second time should be the same as just skipping to the second replacement.
  
  Moreover, the @tt{replace} methods should not raise an error when a value is replaced with itself. They're intended only for use by @racket[snippet-format-sys-morphism-sys/c] and similar error-detection systems, which will tend to replace a replace a value with one that reports better errors.
  
  The other given method implementation (@racket[snippet-format-sys-morphism-sys-functor-morphism]) should observe some algebraic laws. Namely, when its resulting natural transformation is applied to a @racket[dim-sys-morphism-sys?] value, it should result in a @racket[snippet-sys-morphism-sys?] value that uses that value as its @racket[snippet-sys-morphism-sys-dim-sys-morphism-sys]. In more symbolic terms (using a pseudocode DSL):
  
  @racketblock[
    (#:for-all
      _sfsms snippet-format-sys-morphism-sys?
      
      #:let _ffdstsssms
      (snippet-format-sys-morphism-sys-functor-morphism _sfsms)
      
      _dms dim-sys-morphism-sys?
      
      (#:should-be-equal
        (snippet-sys-morphism-sys-dim-sys-morphism-sys
          (natural-transformation-from-from-dim-sys-sys-apply-to-morphism
            _ffdstsssms _dms))
        _dms))
  ]
}

@defproc[
  (snippet-format-sys-morphism-sys/c
    [source/c contract?]
    [target/c contract?])
  contract?
]{
  Returns a contract that recognizes any @racket[snippet-format-sys-morphism-sys?] value whose source and target @tech{snippet format systems} are recognized by the given contracts.
  
  The result is a flat contract as long as the given contracts are flat.
  
  @; TODO: Support chaperone contracts as well.
}

@; TODO: Consider having a `makeshift-snippet-format-sys-morphism-sys`, similar to `makeshift-functor-sys`.

@defproc[
  (snippet-format-sys-morphism-sys-identity
    [endpoint snippet-format-sys?])
  (snippet-format-sys-morphism-sys/c (ok/c endpoint) (ok/c endpoint))
]{
  Returns the identity @racket[snippet-format-sys-morphism-sys?] value on the given @tech{snippet format system}. This is a transformation that goes from the given snippet format system to itself, taking every @racket[dim-sys-morphism-sys?] value to whatever @racket[snippet-sys-morphism-sys?] value the snippet format system's @racket[snippet-format-sys-functor] takes it to.
}

@defproc[
  (snippet-format-sys-morphism-sys-chain-two
    [ab snippet-format-sys-morphism-sys?]
    [bc
      (snippet-format-sys-morphism-sys/c
        (ok/c (snippet-format-sys-morphism-sys-target ab))
        any/c)])
  (snippet-format-sys-morphism-sys/c
    (ok/c (snippet-format-sys-morphism-sys-source ab))
    (ok/c (snippet-format-sys-morphism-sys-target bc)))
]{
  Returns the composition of the two given @racket[snippet-format-sys-morphism-sys?] values. This is a transformation that goes from the first transformation's source @tech{snippet format system} to the second transformation's target snippet format system, transforming a @racket[dim-sys-morphism-sys?] value by applying one of the @racket[snippet-format-sys-morphism-sys?] values to it, applying the other to an identity @racket[dim-sys-morphism-sys?] value, and composing the two results. The target of the first transformation should match the source of the second.
  
  This composition operation is written in @emph{diagrammatic order}, where in the process of reading off the arguments from left to right, we proceed from the source to the target of each transformation. Composition is often written with its arguments the other way around (e.g. in Racket's @racket[compose] operation).
}

@deftogether[(
  @defidform[snippet-format-sys-category-sys]
  @defform[#:link-target? #f (snippet-format-sys-category-sys)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (snippet-format-sys-category-sys)
  ]
  @defproc[(snippet-format-sys-category-sys? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct a @racketmodname[lathe-morphisms/in-fp/category] category (@racket[category-sys?]) where the objects are @tech{snippet format systems} and the morphisms are structure-preserving transformations between them (namely, @racket[snippet-format-sys-morphism-sys?] values).
  
  Every two @tt{snippet-format-sys-category-sys} values are @racket[equal?]. One such value is always an @racket[ok/c] match for another.
}

@; TODO: Consider having `functor-from-snippet-format-sys-sys-apply-to-morphism`, similar to `functor-from-dim-sys-sys-apply-to-morphism`.

@; TODO: Consider having `natural-transformation-from-from-snippet-format-sys-sys-apply-to-morphism`, similar to `natural-transformation-from-from-dim-sys-sys-apply-to-morphism`.

@defproc[(snippet-format-sys-endofunctor-sys? [v any/c]) boolean?]{
  Returns whether the given value is a @racketmodname[lathe-morphisms/in-fp/category] functor from the category @racket[(snippet-format-sys-category-sys)] to itself.
}

@defproc[
  (make-snippet-format-sys-endofunctor-sys-impl-from-apply
    [apply-to-snippet-format-sys
      (-> snippet-format-sys-endofunctor-sys? snippet-format-sys?
        snippet-format-sys?)]
    [apply-to-snippet-format-sys-morphism-sys
      (->i
        (
          [_es snippet-format-sys-endofunctor-sys?]
          [_ms snippet-format-sys-morphism-sys?])
        [_ (_es _ms)
          (snippet-format-sys-morphism-sys/c
            (ok/c
              (functor-sys-apply-to-object _es
                (snippet-format-sys-morphism-sys-source _ms)))
            (ok/c
              (functor-sys-apply-to-object _es
                (snippet-format-sys-morphism-sys-target _ms))))])])
  functor-sys-impl?
]{
  Given implementations for the following methods, returns something a struct can use to implement the @racket[prop:functor-sys] interface in a way that makes it satisfy @racket[snippet-format-sys-endofunctor-sys?].
  
  @itemlist[
    @item{@racket[functor-sys-apply-to-object]}
    @item{@racket[functor-sys-apply-to-morphism]}
  ]
  
  These method implementations should observe the same algebraic laws as those required by @racket[make-functor-sys-impl-from-apply].
  
  This is essentially a shorthand for calling @racket[make-functor-sys-impl-from-apply] and supplying the appropriate source- and target-determining method implementations.
}

@; TODO: Consider having `snippet-format-sys-endofunctor-sys-morphism-sys?`, similar to `functor-from-dim-sys-to-snippet-sys-sys-morphism-sys?`.

@; TODO: Consider having `make-snippet-format-sys-endofunctor-sys-morphism-sys-impl-from-apply`, similar to `make-functor-from-dim-sys-to-snippet-sys-sys-morphism-sys-impl-from-apply`.



@section[#:tag "hypertee"]{Hypertees}

@defmodule[punctaffy/hypersnippet/hypertee]


@subsection[#:tag "hypertee-coil"]{Hypertee Coils}

@deftogether[(
  @defidform[hypertee-coil-zero]
  @defform[#:link-target? #f (hypertee-coil-zero)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hypertee-coil-zero)
  ]
  @defproc[(hypertee-coil-zero? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct a @racket[hypertee-coil/c] value that represents one layer of recursion in a @tech{hypertee} of @tech{degree} 0 (in the sense of @racket[dim-sys-dim-zero]).
  
  Every two @tt{hypertee-coil-zero} values are @racket[equal?].
}

@deftogether[(
  @defidform[hypertee-coil-hole]
  @defform[
    #:link-target? #f
    (hypertee-coil-hole overall-degree hole data tails)
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hypertee-coil-hole overall-degree hole data tails)
  ]
  @defproc[(hypertee-coil-hole? [v any/c]) boolean?]
  @defproc[
    (hypertee-coil-hole-overall-degree [coil hypertee-coil-hole?])
    any/c
  ]
  @defproc[(hypertee-coil-hole-hole [coil hypertee-coil-hole?]) any/c]
  @defproc[(hypertee-coil-hole-data [coil hypertee-coil-hole?]) any/c]
  @defproc[
    (hypertee-coil-hole-tails [coil hypertee-coil-hole?])
    any/c
  ]
)]{
  Struct-like operations which construct and deconstruct a @racket[hypertee-coil/c] value that represents one layer of recursion in a @tech{hypertee} that would start with a @tech{hole} in its bracket representation. Every hypertee of nonzero @tech{degree} (in the sense of @racket[dim-sys-dim-zero]) has at least one hole, and there's nothing it can begin with other than a hole, so this is the most common case.
  
  This has four parts: The @racket[overall-degree] is the degree of the hypertee, the @racket[hole] is the @tech{shape} of the hole (carrying @racket[trivial?] data in its own holes), the @racket[data] is the data value carried in the hole, and the @racket[tails] is a hypertee of the same shape as @racket[hole], but where the data values are hypertees representing the rest of the structure. The tail hypertee carried in a hole of degree N is expected to have @racket[trivial?] data in its holes of degree less than N. Its holes of degree not less than N can carry any data; they represent additional holes in the overall hypertee.
  
  Note that the @racket[hole] is basically redundant here; it's just the same as @racket[tails] but with the data values trivialized. Most of our traversal operations make use of values of this form, and some of the places we would construct a typertee already have values of this form readily available, so we save ourselves some redundant computation by keeping it separate. (TODO: Offer an alternative way to create a @tt{hypertee-coil-hole} without specifying its @racket[hole] shape.)
  
  On the other hand, we save ourselves some verbosity and some repetitive contract-checking by leaving out the @tech{dimension system}. If we stored a dimension system alongside the rest of the fields in a @tt{hypertee-coil-hole}, we could enforce far more precise contracts on the field values, but instead we allow any value to be stored in any of the fields and rely on @racket[hypertee-coil/c] in the contract of any operation that needs to enforce the structure. (TODO: Reconsider this choice. In most places, we pass a coil to something that associates it with a dimension system as soon as we create it, so we're effectively passing in the dimension system at the same time anyway. But for the sake of people doing a lot of computation at the coil level, perhaps enforcing contracts is too costly. We'll probably need more practical experience before we understand the tradeoffs.)
  
  A hypertee based on this kind of coil is essentially created from a @racket[snippet-sys-snippet-done] in the shape of the hole, concatenated with the tail hypertees using @racket[snippet-sys-snippet-join]. Considering this, it might be tempting to work with hypertees using only the generic @tech{snippet system} operations, but even though that interface supplies a way to put together this kind of hypertee, it doesn't supply a way to take it apart again to work with its details. Pattern-matching on the coils allows the details to be traversed.
  
  Two @tt{hypertee-coil-hole} values are @racket[equal?] if they contain @racket[equal?] elements.
}

@; TODO: Consider having a `hypertee-coil?`.

@defproc[(hypertee-coil/c [ds dim-sys?]) flat-contract?]{
  Returns a flat contract that recognizes a well-formed @tech{hypertee} coil for the given @tech{dimension system}. For a value to be suitable, it must either be a @racket[hypertee-coil-zero?] value or be a @racket[hypertee-coil-hole?] value which abides by stricter expectations.
  
  Namely: The overall @tech{degree} (@racket[hypertee-coil-hole-overall-degree]) must be a nonzero @tech{dimension number} in the given dimension system. The @tech{hole} @tech{shape} must be a hypertee (of any degree) with the given dimension system and with @racket[trivial?] values in its holes. The tails hypertee must be a hypertee similar to the hole shape, but with hypertees (the tails) in its holes. If a tail appears in a hole of degree N, each of its own holes of degree lower than N must have a @racket[trivial?] value in it, and those holes must be in the same arrangement as the hole's holes.
}


@subsection[#:tag "hypertee-bracket"]{Hypertee Brackets}

@deftogether[(
  @defidform[htb-labeled]
  @defform[#:link-target? #f (htb-labeled degree data)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (htb-labeled degree data)
  ]
  @defproc[(htb-labeled? [v any/c]) boolean?]
  @defproc[(htb-labeled-degree [b htb-labeled?]) any/c]
  @defproc[(htb-labeled-data [b htb-labeled?]) any/c]
)]{
  Struct-like operations which construct and deconstruct a @racket[hypertee-bracket?] value that represents one of the brackets of a @tech{hole} in a @tech{hypertee}, and in particular the bracket that appears first in the hypertee's bracket representation.
  
  The given @racket[degree] is the @tech{degree} of the hole, and the given @racket[data] is the data value to be carried in the hole.
  
  The data has to be placed somewhere among the hole's brackets, and we place it at the first bracket as a stylistic choice for readability: This way, the placement of data values is comparable to the placement of @emph{section headings} in a document or @emph{prefix operators} in a Racket program.
  
  Two @tt{htb-labeled} values are @racket[equal?] if they contain @racket[equal?] elements.
}

@deftogether[(
  @defidform[htb-unlabeled]
  @defform[#:link-target? #f (htb-unlabeled degree)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (htb-unlabeled degree)
  ]
  @defproc[(htb-unlabeled? [v any/c]) boolean?]
  @defproc[(htb-unlabeled-degree [b htb-unlabeled?]) any/c]
)]{
  Struct-like operations which construct and deconstruct a @racket[hypertee-bracket?] value that represents any non-first bracket of a @tech{hole} in a @tech{hypertee}, as it appears in the hypertee's bracket representation.
  
  The given @racket[degree] is the @tech{degree} of the hole that's being initiated by this bracket. Even though this bracket isn't the first bracket of a hole of the hypertee, it's still the first bracket of @emph{some} hole. It could be the first bracket of a hole of a hole of the hypertee; the first bracket of a hole of a hole of a hole of the hypertee; etc.
  
  Two @tt{htb-unlabeled} values are @racket[equal?] if they contain @racket[equal?] elements.
}

@defproc[(hypertee-bracket? [v any/c]) boolean?]{
  Returns whether the given value is a @tech{hypertee} bracket. That is, it checks that the value is either an @racket[htb-labeled?] value or an @racket[htb-unlabeled?] value.
}

@defproc[(hypertee-bracket/c [dim/c contract?]) contract?]{
  Returns a contract that recognizes a @racket[hypertee-bracket?] value where the @tech{degree} abides by the given contract.
  
  The resulting contract has the same @tech[#:doc lathe-comforts-doc]{contract obstinacy} as the given one.
}


@subsection[#:tag "hypertee-operations"]{Hypertee Constructors and Operations}

@defproc[(hypertee? [v any/c]) boolean?]{
  Returns whether the given value is a @tech{hypertee}. A hypertee is a specific data structure representing @tech{hypersnippets} of a content-free stream. While a hypertee does not have content, it does still have a multidimensional boundary. Hypertees tend to arise as the description of the @tech{shape} of another kind of hypersnippet.
}

@defproc[(hypertee-get-dim-sys [ht hypertee?]) dim-sys?]{
  Returns the @tech{dimension system} the given @tech{hypertee}'s @tech{degrees} abide by.
}

@deftogether[(
  @defidform[hypertee-furl]
  @defform[
    #:link-target? #f
    (hypertee-furl dim-sys coil)
    #:contracts ([dim-sys dim-sys?] [coil (hypertee-coil/c dim-sys)])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hypertee-furl dim-sys coil)
  ]
)]{
  Constructs or deconstructs a @tech{hypertee} value, regarding it as being made up of a @tech{dimension system} and a @racket[hypertee-coil/c] value.
  
  Two @tech{hypertees} are @racket[equal?] if they contain @racket[equal?] elements when seen this way. Note that this isn't the only way to understand their representation; they can also be seen as being constructed by @racket[hypertee-from-brackets].
}

@defproc[
  (hypertee-get-coil [ht hypertee?])
  (hypertee-coil/c (hypertee-get-dim-sys ht))
]{
  Given a @tech{hypertee}, computes the @racket[hypertee-coil/c] value that would need to be passed to @racket[hypertee-furl] to construct it.
}

@defproc[
  (hypertee-from-brackets
    [ds dim-sys?]
    [degree (dim-sys-dim/c ds)]
    [brackets (listof (hypertee-bracket/c (dim-sys-dim/c ds)))])
  (hypertee/c ds)
]{
  Constructs a @tech{hypertee} value, regarding it as being made up of a @tech{dimension system}, a @tech{degree}, and a properly nested sequence of @racket[hypertee-bracket?] values.
  
  If the brackets aren't properly nested, the @racket[exn:fail:contract] exception is raised.
  
  Proper nesting of hypertee brackets is a rather intricate matter which is probably easiest to approach by thinking of it as a series of @tech{hyperstack} pop operations. The hyperstack starts out with a dimension of @racket[degree] and data of @racket[#t] at every dimension, and each bracket in the list performs a @racket[hyperstack-pop] with data of @racket[#f]. (A @racket[hyperstack-pop] in some sense simultaneously "pushes" that data value onto every lower dimension. See the hyperstack documentation for more information.) If the pop reveals the data @racket[#t], the bracket should have been @racket[htb-labeled?]; otherwise, it should have been @racket[htb-unlabeled?]. Once we reach the end of the list, the hyperstack should have a dimension of 0 (in the sense of @racket[dim-sys-dim-zero]).
  
  Two @tech{hypertees} are @racket[equal?] if they're constructed with @racket[equal?] elements this way. Note that this isn't the only way to understand their representation; they can also be seen as being constructed by @racket[hypertee-furl].
  
  (TODO: Write some examples.)
}

@defproc[
  (ht-bracs
    [ds dim-sys?]
    [degree (dim-sys-dim/c ds)]
    [bracket
      (let ([_dim/c (dim-sys-dim/c ds)])
        (or/c (hypertee-bracket/c _dim/c) _dim/c))]
    ...)
  (hypertee/c ds)
]{
  Constructs a @tech{hypertee} value, regarding it as being made up of a @tech{dimension system}, a @tech{degree}, and a properly nested sequence of @racket[hypertee-bracket?] values (some of which may be expressed as raw @tech{dimension numbers}, which are understood as being implicitly wrapped in @racket[htb-unlabeled]).
  
  If the brackets aren't properly nested, the @racket[exn:fail:contract] exception is raised.
  
  Rarely, some @tech{dimension system} might represent its dimension numbers as @racket[hypertee-bracket?] values. If that's the case, then those values must be explicitly wrapped in @racket[htb-unlabeled]. Otherwise, this will understand them as brackets instead of as dimension numbers.
  
  This is simply a more concise alternative to @racket[hypertee-from-brackets]. See that documentation for more information about what it takes for hypertee brackets to be "properly nested."
  
  (TODO: Write some examples.)
}

@defproc[
  (hypertee-get-brackets [ht hypertee?])
  (listof (hypertee-bracket/c (dim-sys-dim/c ds)))
]{
  Given a @tech{hypertee}, computes the list of @racket[hypertee-bracket?] values that would need to be passed to @racket[hypertee-from-brackets] to construct it.
}

@defproc[(hypertee/c [ds dim-sys?]) flat-contract?]{
  Returns a contract that recognizes a @racket[hypertee?] value where the @tech{dimension system} is an @racket[ok/c] match for the given one.
}

@deftogether[(
  @defidform[hypertee-snippet-sys]
  @defform[
    #:link-target? #f
    (hypertee-snippet-sys dim-sys)
    #:contracts ([dim-sys dim-sys?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hypertee-snippet-sys dim-sys)
  ]
  @defproc[(hypertee-snippet-sys? [v any/c]) boolean?]
  @defproc[
    (hypertee-snippet-sys-dim-sys [ss hypertee-snippet-sys?])
    dim-sys?
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{snippet system} (@racket[snippet-sys?]) where the @tech{dimension numbers} are those of the given @tech{dimension system} and the hypersnippet @tech{shapes} and @tech{hypersnippets} are @tech{hypertees} which use that dimension system.
  
  The resulting snippet system's operations have behavior which corresponds to the sense in which we've described hypertees as being higher-dimensional snippets snipped out of content-free streams. Consider the @racket[snippet-sys-snippet-splice] and @racket[snippet-sys-snippet-zip-map-selective] operations, which iterate over all the @tech{holes} of a hypersnippet. In the case of a hypertee, they iterate over each of the @racket[hypertee-coil-hole]/@racket[htb-labeled] nodes exactly once (notwithstanding early exits and the skipping of @racket[unselected?] data values), so indeed each of these nodes legitimately represents one of the hypertee's holes. We've chosen to directly describe operations like @racket[hypertee-coil-hole] in terms of hypersnippet holes, largely because the very purpose of hypertees is tied to the functionality they have as hypersnippets. Because of this, "@racket[hypertee-coil-hole] nodes really do correspond to holes" may sound tautological, but in fact the behavior of this snippet system is the reason we've been able to describe those nodes in terms of holes in the first place.
  
  (TODO: This isn't really a complete specification of the behavior. A complete specification might get very exhaustive or technical, but let's see if we can at least improve this description over time. Perhaps we should go through and hedge some of the ways we describe hypertees so that they specifically appeal to @tt{hypertee-snippet-sys} as the basis for their use of terms like "hypersnippet," "@tech{degree}," and "hole.")
  
  Two @tt{hypertee-snippet-sys} values are @racket[equal?] if they contain @racket[equal?] elements. One such value is an @racket[ok/c] match for another if the first's element is @racket[ok/c] for the second's.
}

@deftogether[(
  @defidform[hypertee-snippet-format-sys]
  @defform[#:link-target? #f (hypertee-snippet-format-sys)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hypertee-snippet-format-sys)
  ]
  @defproc[(hypertee-snippet-format-sys? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct a @tech{snippet format system} (@racket[snippet-format-sys?]) where, given any particular @tech{dimension system},  the hypersnippet @tech{shapes} and @tech{hypersnippets} are @tech{hypertees} which use that dimension system.
  
  The shapes and snippets are related according to the same behavior as @racket[hypertee-snippet-sys]. In some sense, this is a generalization of @racket[hypertee-snippet-sys] which puts the choice of dimension system in the user's hands. Instead of merely generalizing by being more late-bound, this also generalizes by having slightly more functionality: The combination of @racket[functor-from-dim-sys-sys-apply-to-morphism] with @racket[snippet-format-sys-functor] allows for transforming just the @tech{degrees} of a hypertee while leaving the rest of the structure alone.
  
  Every two @tt{hypertee-snippet-format-sys} values are @racket[equal?]. One such value is always an @racket[ok/c] match for another.
}

@defproc[
  (hypertee-get-hole-zero-maybe
    [ht (and/c hypertee? (hypertee/c (hypertee-get-dim-sys ht)))])
  maybe?
]{
  Given a @tech{hypertee}, returns a @racket[maybe?] value containing the value associated with its hole of degree 0, if such a hole exists.
  
  (TODO: Not all @tech{snippet systems} necessarily support an operation like this, but all the ones we've defined so far do. It may turn out that we'll want to add this to the snippet system interface.)
}



@section[#:tag "hypernest"]{Hypernests}

@defmodule[punctaffy/hypersnippet/hypernest]


@subsection[#:tag "hypernest-coil"]{Hypernest Coils}

@deftogether[(
  @defidform[hypernest-coil-zero]
  @defform[#:link-target? #f (hypernest-coil-zero)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hypernest-coil-zero)
  ]
  @defproc[(hypernest-coil-zero? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct a @racket[hypernest-coil/c] value that represents one layer of recursion in a @tech{hypernest} of @tech{degree} 0 (in the sense of @racket[dim-sys-dim-zero]).
  
  Every two @tt{hypernest-coil-zero} values are @racket[equal?].
}

@deftogether[(
  @defidform[hypernest-coil-hole]
  @defform[
    #:link-target? #f
    (hypernest-coil-hole overall-degree hole data tails-hypertee)
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hypernest-coil-hole overall-degree hole data tails-hypertee)
  ]
  @defproc[(hypernest-coil-hole? [v any/c]) boolean?]
  @defproc[
    (hypernest-coil-hole-overall-degree [coil hypernest-coil-hole?])
    any/c
  ]
  @defproc[
    (hypernest-coil-hole-hole [coil hypernest-coil-hole?])
    any/c
  ]
  @defproc[
    (hypernest-coil-hole-data [coil hypernest-coil-hole?])
    any/c
  ]
  @defproc[
    (hypernest-coil-hole-tails-hypertee [coil hypernest-coil-hole?])
    any/c
  ]
)]{
  Struct-like operations which construct and deconstruct a @racket[hypernest-coil/c] value that represents one layer of recursion in a @tech{hypernest} that would start with a @tech{hole} in its bracket representation. Every hypernest of nonzero @tech{degree} (in the sense of @racket[dim-sys-dim-zero]) has at least one hole, and there's nothing it can begin with other than a hole, so this is the most common case.
  
  This has four parts: The @racket[overall-degree] is the degree of the hypernest, the @racket[hole] is the @tech{shape} of the hole (carrying @racket[trivial?] data in its own holes), the @racket[data] is the data value carried in the hole, and the @racket[tails-hypertee] is a @tech{hypertee} of the same shape as @racket[hole], but where the data values are hypernests representing the rest of the structure. The tail hypernest carried in a hole of degree N is expected to have @racket[trivial?] data in its holes of degree less than N. Its holes of degree not less than N can carry any data; they represent additional holes in the overall hypernest.
  
  Note that the @racket[hole] is basically redundant here; it's just the same as @racket[tails-hypertee] but with the data values trivialized. Most of our traversal operations make use of values of this form, and some of the places we would construct a typernest already have values of this form readily available, so we save ourselves some redundant computation by keeping it separate. (TODO: Offer an alternative way to create a @tt{hypernest-coil-hole} without specifying its @racket[hole] shape.)
  
  On the other hand, we save ourselves some verbosity and some repetitive contract-checking by leaving out the @tech{dimension system}. If we stored a dimension system alongside the rest of the fields in a @tt{hypernest-coil-hole}, we could enforce far more precise contracts on the field values, but instead we allow any value to be stored in any of the fields and rely on @racket[hypernest-coil/c] in the contract of any operation that needs to enforce the structure. (TODO: Reconsider this choice. In most places, we pass a coil to something that associates it with a dimension system as soon as we create it, so we're effectively passing in the dimension system at the same time anyway. But for the sake of people doing a lot of computation at the coil level, perhaps enforcing contracts is too costly. We'll probably need more practical experience before we understand the tradeoffs.)
  
  A hypernest based on this kind of coil is essentially created from a @racket[snippet-sys-snippet-done] in the shape of the hole, concatenated with the tail hypernests using @racket[snippet-sys-snippet-join].
  
  Two @tt{hypernest-coil-hole} values are @racket[equal?] if they contain @racket[equal?] elements.
}

@deftogether[(
  @defidform[hypernest-coil-bump]
  @defform[
    #:link-target? #f
    (hypernest-coil-bump
      overall-degree data bump-degree tails-hypernest)
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hypernest-coil-bump
      overall-degree data bump-degree tails-hypernest)
  ]
  @defproc[(hypernest-coil-bump? [v any/c]) boolean?]
  @defproc[
    (hypernest-coil-bump-overall-degree [coil hypernest-coil-bump?])
    any/c
  ]
  @defproc[
    (hypernest-coil-bump-data [coil hypernest-coil-bump?])
    any/c
  ]
  @defproc[
    (hypernest-coil-bump-bump-degree [coil hypernest-coil-bump?])
    any/c
  ]
  @defproc[
    (hypernest-coil-bump-tails-hypernest [coil hypernest-coil-bump?])
    any/c
  ]
)]{
  Struct-like operations which construct and deconstruct a @racket[hypernest-coil/c] value that represents one layer of recursion in a @tech{hypernest} that would start with a @tech{bump} in its bracket representation.
  
  This has four parts: The @racket[overall-degree] is the degree of the hypernest, the @racket[data] is the data value carried on the bump, the @racket[bump-degree] is the degree of the bump, and the @racket[tails-hypernest] is a @tech{hypernest} of degree equal to the max of @racket[overall-degree] and @racket[bump-degree], where the data values of holes of degree lower than @racket[bump-degree] are hypernests representing the rest of the structure. The tail hypernest carried in a hole of degree N is expected to have @racket[trivial?] data in its holes of degree less than N. Its holes of degree not less than N can carry any data; they represent additional holes in the overall hypernest.
  
  Note that the @racket[bump-degree] may be higher than the @racket[overall-degree].
  
  We save ourselves some verbosity and some repetitive contract-checking by leaving out the @tech{dimension system}. If we stored a dimension system alongside the rest of the fields in a @tt{hypernest-coil-bump}, we could enforce far more precise contracts on the field values, but instead we allow any value to be stored in any of the fields and rely on @racket[hypernest-coil/c] in the contract of any operation that needs to enforce the structure. (TODO: Reconsider this choice. In most places, we pass a coil to something that associates it with a dimension system as soon as we create it, so we're effectively passing in the dimension system at the same time anyway. But for the sake of people doing a lot of computation at the coil level, perhaps enforcing contracts is too costly. We'll probably need more practical experience before we understand the tradeoffs.)
  
  Two @tt{hypernest-coil-bump} values are @racket[equal?] if they contain @racket[equal?] elements.
}

@; TODO: Consider having a `hypernest-coil?`.

@defproc[(hypernest-coil/c [ds dim-sys?]) flat-contract?]{
  Returns a flat contract that recognizes a well-formed @tech{hypernest} coil for the given @tech{dimension system}. For a value to be suitable, it must fall into one of the following cases:
  
  @itemlist[
    
    @item{A @racket[hypernest-coil-zero?] value.}
    
    @item{A @racket[hypernest-coil-hole?] value which abides by stricter expectations. Namely: The overall @tech{degree} (@racket[hypernest-coil-hole-overall-degree]) must be a nonzero @tech{dimension number} in the given dimension system. The @tech{hole} @tech{shape} must be a hypernest (of any degree) with the given dimension system and with @racket[trivial?] values in its holes. The tails @tech{hypertee} must be a hypertee similar to the hole shape, but with hypernests (the tails) in its holes. If a tail appears in a hole of degree N, each of its own holes of degree lower than N must have a @racket[trivial?] value in it, and those holes must be in the same arrangement as the hole's holes.}
    
    @item{A @racket[hypernest-coil-bump?] value which abides by stricter expectations. Namely: The overall degree (@racket[hypernest-coil-bump-overall-degree]) and the bump degree (@racket[hypernest-coil-bump-bump-degree]) must be @tech{dimension numbers} in the given dimension system, and the overall degree must be nonzero. The tails hypernest must be a hypernest of degree equal to the max of the overall degree and the bump degree, and it must have hypernests (the tails) in its holes of degree lower than the bump degree. If a tail appears in a hole of degree N, each of its own holes of degree lower than N must have a @racket[trivial?] value in it, and those holes must be in the same arrangement as the hole's holes.}
    
  ]
}

@; TODO: Consider having a `hypertee-coil->hypernest-coil`, similar to `hypertee-bracket->hypernest-bracket`. This would probably need to take a callback that could recursively convert the tails.

@; TODO: Consider having a `compatiable-hypernext-coil->hypertee-coil`, similar to `compatible-hypernest-bracket->hypertee-bracket`. This would probably need to take a callback that could recursively convert the tails.


@subsection[#:tag "hypernest-bracket"]{Hypernest Brackets}

@deftogether[(
  @defidform[hnb-open]
  @defform[#:link-target? #f (hnb-open degree data)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hnb-open degree data)
  ]
  @defproc[(hnb-open? [v any/c]) boolean?]
  @defproc[(hnb-open-degree [b hnb-open?]) any/c]
  @defproc[(hnb-open-data [b hnb-open?]) any/c]
)]{
  Struct-like operations which construct and deconstruct a @racket[hypernest-bracket?] value that represents one of the brackets of a @tech{bump} in a @tech{hypernest}, and in particular the bracket that appears first in the hypernest's bracket representation.
  
  The given @racket[degree] is the @tech{degree} of the bump, and the given @racket[data] is the data value to be carried on the bump.
  
  The data has to be placed somewhere among the bump's brackets, and we place it at the first bracket as a stylistic choice for readability: This way, the placement of data values is comparable to the placement of @emph{section headings} in a document or @emph{prefix operators} in a Racket program.
  
  Two @tt{hnb-open} values are @racket[equal?] if they contain @racket[equal?] elements.
}

@deftogether[(
  @defidform[hnb-labeled]
  @defform[#:link-target? #f (hnb-labeled degree data)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hnb-labeled degree data)
  ]
  @defproc[(hnb-labeled? [v any/c]) boolean?]
  @defproc[(hnb-labeled-degree [b hnb-labeled?]) any/c]
  @defproc[(hnb-labeled-data [b hnb-labeled?]) any/c]
)]{
  Struct-like operations which construct and deconstruct a @racket[hypernest-bracket?] value that represents one of the brackets of a @tech{hole} in a @tech{hypernest}, and in particular the bracket that appears first in the hypernest's bracket representation.
  
  The given @racket[degree] is the @tech{degree} of the hole, and the given @racket[data] is the data value to be carried in the hole.
  
  The data has to be placed somewhere among the hole's brackets, and we place it at the first bracket as a stylistic choice for readability: This way, the placement of data values is comparable to the placement of @emph{section headings} in a document or @emph{prefix operators} in a Racket program.
  
  Two @tt{hnb-labeled} values are @racket[equal?] if they contain @racket[equal?] elements.
}

@deftogether[(
  @defidform[hnb-unlabeled]
  @defform[#:link-target? #f (hnb-unlabeled degree)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hnb-unlabeled degree)
  ]
  @defproc[(hnb-unlabeled? [v any/c]) boolean?]
  @defproc[(hnb-unlabeled-degree [b hnb-unlabeled?]) any/c]
)]{
  Struct-like operations which construct and deconstruct a @racket[hypernest-bracket?] value that represents any non-first bracket of a @tech{bump} or @tech{hole} in a @tech{hypernest}, as it appears in the hypernest's bracket representation.
  
  The given @racket[degree] is the @tech{degree} of the hole that's being initiated by this bracket. Even though this bracket isn't the first bracket of a hole of the hypernest, it's still the first bracket of @emph{some} hole. It could be
  
  @itemlist[
    @item{The first bracket of a hole of a bump of the hypernest;}
    @item{The first bracket of a hole of a hole of the hypernest;}
    @item{The first bracket of a hole of a hole of a bump of the hypernest;}
    @item{The first bracket of a hole of a hole of a hole of the hypernest; and}
    @item{Generally, the first bracket of @tt{(}a hole of@tt{)+} a @tt{(}hole@tt{|}bump@tt{)} of the hypernest.}
  ]
  
  Two @tt{hnb-unlabeled} values are @racket[equal?] if they contain @racket[equal?] elements.
}

@defproc[(hypernest-bracket? [v any/c]) boolean?]{
  Returns whether the given value is a @tech{hypernest} bracket. That is, it checks that the value is either an @racket[hnb-open?] value, an @racket[hnb-labeled?] value, or an @racket[hnb-unlabeled?] value.
}

@defproc[(hypernest-bracket/c [dim/c contract?]) contract?]{
  Returns a contract that recognizes a @racket[hypernest-bracket?] value where the @tech{degree} abides by the given contract.
  
  The resulting contract has the same @tech[#:doc lathe-comforts-doc]{contract obstinacy} as the given one.
}

@defproc[
  (hypertee-bracket->hypernest-bracket [bracket hypertee-bracket?])
  (or/c hnb-labeled? hnb-unlabeled?)
]{
  Given a @tech{hypertee} bracket, returns a similar @tech{hypernest} bracket.
}

@defproc[
  (compatible-hypernest-bracket->hypertee-bracket
    [bracket (or/c hnb-labeled? hnb-unlabeled?)])
  hypertee-bracket?
]{
  Given a suitable @tech{hypernest} bracket, returns a similar @tech{hypertee} bracket. This only works for hypernest brackets that are @racket[hnb-labeled?] or @racket[hnb-unlabeled?], not those that are @racket[hnb-open?].
}


@subsection[#:tag "hypernest-operations"]{Hypernest Constructors and Operations}

@defproc[(hypernest? [v any/c]) boolean?]{
  Returns whether the given value is a @deftech{generalized hypernest}, such as a (non-generalized) @tech{hypernest}.
  
  A (non-generalized) hypernest is a specific data structure representing @tech{hypersnippets} of a stream that contain fully matched-up arrangements (@tech{bumps}) of brackets.
  
  This is sufficient to represent, for instance, hypersnippets of character or token streams; each miscellaneous token in the stream can be treated as a bump-opening bracket (@racket[hnb-open?]) of @tech{degree} 0, which matches up with itself.
  
  A generalized hypernest is a less specific data structure, one which might be based on an arbitrary @tech{snippet format system} rather than just the kind that represents higher-dimensional snippets of streams (namely, @racket[(hypertee-snippet-format-sys)]). For instance, if a certain snippet format system represents polygon-bounded snippets of a 2D Euclidean plane, the appropriate notion of "hypernest" would be a similar kind of snippet that could additionally contain some number of unbroken arrangements of matched-up polygon boundaries.
  
  A generalized hypernest can be represented by a snippet in the underlying snippet format system. In this approach, each @tech{hole} is represented with a hole that has the same shape, and each bump is represented with an infinite-degree hole that has a @racket[snippet-sys-snippet-done] shape.
  
  We don't currently offer tools to construct or pull apart generalized hypersnippets (TODO), so (non-generalized) hypernests are the only particularly useful ones for now. Whenever we do supply better support for them, or whenever we decide the support we already have isn't worth enough to keep around, we might make substantial changes to the hypernest utilities described here.
  
  If a hypernest utility described here doesn't mention the phrase "generalized hypersnippet," then the hypersnippets it refers to are the ones based on @racket[(hypertee-snippet-format-sys)]. For instance, all the @racket[hypernest-coil/c] and @racket[hypernest-bracket?] values are specialized to hypertee-based hypernests.
  
  @; TODO: See if this really is the right place to go into this long explanation of an issue that pervades the Punctaffy docs.
}

@defproc[(hypernest-get-dim-sys [hn hypernest?]) dim-sys?]{
  Returns the @tech{dimension system} the given @tech{hypernest}'s @tech{degrees} abide by. The hypernest can be a @tech{generalized hypernest}.
}

@deftogether[(
  @defidform[hypernest-furl]
  @defform[
    #:link-target? #f
    (hypernest-furl dim-sys coil)
    #:contracts ([dim-sys dim-sys?] [coil (hypernest-coil/c dim-sys)])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hypernest-furl dim-sys coil)
  ]
)]{
  Constructs or deconstructs a @tech{hypernest} value, regarding it as being made up of a @tech{dimension system} and a @racket[hypernest-coil/c] value.
  
  Two @tech{hypernests} are @racket[equal?] if they contain @racket[equal?] elements when seen this way. Note that this isn't the only way to understand their representation; they can also be seen as being constructed by @racket[hypernest-from-brackets].
}

@defproc[
  (hypernest-get-coil [hn hypernest?])
  (hypernest-coil/c (hypernest-get-dim-sys hn))
]{
  Given a @tech{hypernest}, computes the @racket[hypernest-coil/c] value that would need to be passed to @racket[hypernest-furl] to construct it.
}

@defproc[
  (hypernest-from-brackets
    [ds dim-sys?]
    [degree (dim-sys-dim/c ds)]
    [brackets (listof (hypernest-bracket/c (dim-sys-dim/c ds)))])
  (hypernest/c (hypertee-snippet-format-sys) ds)
]{
  Constructs a @tech{hypernest} value, regarding it as being made up of a @tech{dimension system}, a @tech{degree}, and a properly nested sequence of @racket[hypernest-bracket?] values.
  
  If the brackets aren't properly nested, the @racket[exn:fail:contract] exception is raised.
  
  Proper nesting of hypernest brackets is a rather intricate matter which is probably easiest to approach by thinking of it as a series of @tech{hyperstack} push and pop operations, along with tracking some state about whether bumps are allowed. (The @racket[hypertee-from-brackets] situation is similar, but in that case it's just a series of pop operations, and bumps are never allowed.)
  
  Thinking about it this way, the hyperstack starts out with a dimension of @racket[degree] and data of @racket[(hash 'should-be-labeled #t 'bumps-allowed #f)] at every dimension. Bumps start out as being allowed, and this status updates each time we update the hyperstack by becoming whatever @racket['bumps-allowed] entry was revealed (not whichever entry was pushed or popped). We iterate through the list of brackets. An @racket[hnb-open?] bracket may only be encountered while bumps are allowed, and it performs a @racket[hyperstack-push] with data of @racket[(hash 'should-be-labeled #f 'bumps-allowed #t)]. Each @racket[hnb-labeled?] or @racket[hnb-unlabeled?] bracket performs a @racket[hyperstack-pop] with data of @racket[(hash 'should-be-labeled #f 'bumps-allowed  _ba)], where @racket[_ba] is the existing bumps-allowed state. (A @racket[hyperstack-pop] in some sense simultaneously "pushes" that data value onto every lower dimension. See the hyperstack documentation for more information.) If the pop reveals a @racket['should-be-labeled] entry of @racket[#t], the bracket should have been @racket[hnb-labeled?]; otherwise, it should have been @racket[hnb-unlabeled?]. Once we reach the end of the list, the hyperstack should have a dimension of 0 (in the sense of @racket[dim-sys-dim-zero]).
  
  Two @tech{hypernests} are @racket[equal?] if they're constructed with @racket[equal?] elements this way. Note that this isn't the only way to understand their representation; they can also be seen as being constructed by @racket[hypernest-furl].
  
  (TODO: Write some examples.)
}

@defproc[
  (hn-bracs
    [ds dim-sys?]
    [degree (dim-sys-dim/c ds)]
    [bracket
      (let ([_dim/c (dim-sys-dim/c ds)])
        (or/c (hypernest-bracket/c _dim/c) _dim/c))]
    ...)
  (hypernest/c (hypertee-snippet-format-sys) ds)
]{
  Constructs a @tech{hypernest} value, regarding it as being made up of a @tech{dimension system}, a @tech{degree}, and a properly nested sequence of @racket[hypernest-bracket?] values (some of which may be expressed as raw @tech{dimension numbers}, which are understood as being implicitly wrapped in @racket[hnb-unlabeled]).
  
  If the brackets aren't properly nested, the @racket[exn:fail:contract] exception is raised.
  
  Rarely, some @tech{dimension system} might represent its dimension numbers as @racket[hypernest-bracket?] values. If that's the case, then those values must be explicitly wrapped in @racket[hnb-unlabeled]. Otherwise, this will understand them as brackets instead of as dimension numbers.
  
  This is simply a more concise alternative to @racket[hypernest-from-brackets]. See that documentation for more information about what it takes for hypernest brackets to be "properly nested."
  
  (TODO: Write some examples.)
}

@defproc[
  (hypernest-get-brackets [hn hypernest?])
  (listof (hypernest-bracket/c (dim-sys-dim/c ds)))
]{
  Given a @tech{hypernest}, computes the list of @racket[hypernest-bracket?] values that would need to be passed to @racket[hypernest-from-brackets] to construct it.
}

@defproc[
  (hypernest/c [sfs snippet-format-sys?] [ds dim-sys?])
  flat-contract?
]{
  Returns a flat contract that recognizes a @tech{generalized hypernest} (@racket[hypernest?]) value where the @tech{snippet format system} and the @tech{dimension system} are @racket[ok/c] matches for the given ones.
  
  In particular, this can be used to recognize a (non-generalized) @tech{hypernest} if the given snippet format system is @racket[(hypertee-snippet-format-sys)].
}

@defproc[
  (hypernestof/ob-c
    [sfs snippet-format-sys?]
    [ds dim-sys?]
    [ob obstinacy?]
    [b-to-value/c
      (let*
        (
          [_ffdstsss (snippet-format-sys-functor sfs)]
          [_ss (functor-sys-apply-to-object _ffdstsss ds)])
        (-> (snippet-sys-unlabeled-shape/c _ss)
          (obstinacy-contract/c ob)))]
    [h-to-value/c
      (let*
        (
          [_ffdstsss (snippet-format-sys-functor sfs)]
          [_ss (functor-sys-apply-to-object _ffdstsss ds)])
        (-> (snippet-sys-unlabeled-shape/c _ss)
          (obstinacy-contract/c ob)))])
  (obstinacy-contract/c ob)
]{
  Returns a contract that recognizes any @tech{generalized hypernest} (@racket[hypernest?]) value if its @tech{snippet format system} and its @tech{dimension system} are @racket[ok/c] matches for the given ones and if the values carried by its @tech{bumps} and @tech{holes} abide by the given contracts. The contracts for the bumps are given by a function @racket[b-to-value/c] that takes the hypersnippet @tech{shape} of a bump's @tech{interior} and returns a contract for values residing on that bump. The contracts for the holes are given by a function @racket[h-to-value/c] that takes the shape of a hole and returns a contract for values residing in that hole.
  
  As a special case, this can be used to recognize a (non-generalized) @tech{hypernest} if the given snippet format system is @racket[(hypertee-snippet-format-sys)].
  
  The ability for the contracts to depend on the shapes of the bumps and holes they apply to allows us to require the values to somehow @emph{fit} those shapes. It's rather common for the value contracts to depend on at least the @tech{degree} of the hole, if not on its complete shape.
  
  The resulting contract is at least as @tech[#:doc lathe-comforts-doc]{reticent} as the given @tech[#:doc lathe-comforts-doc]{contract obstinacy}. The given contracts must also be at least that reticent.
}

@defproc[
  (hypernest-shape
    [ss hypernest-snippet-sys?]
    [hn (snippet-sys-snippet/c ss)])
  (snippet-sys-snippet/c (snippet-sys-shape-snippet-sys ss))
]{
  Given a @tech{generalized hypernest} (such as a (non-generalized) @tech{hypernest}), returns a hypersnippet @tech{shape} that has the same @tech{degree} and all the same @tech{holes} carrying the same data values.
  
  (TODO: Not all @tech{snippet systems} necessarily support an operation like this, but all the ones we've defined so far do. It may turn out that we'll want to add this to the snippet system interface.)
}

@defproc[
  (hypernest-get-hole-zero-maybe
    [hn
      (and/c hypernest?
        (hypernest/c (hypertee-snippet-format-sys)
          (hypernest-get-dim-sys hn)))])
  maybe?
]{
  Given a non-generalized @tech{hypernest}, returns a @racket[maybe?] value containing the value associated with its hole of degree 0, if such a hole exists.
  
  (TODO: Not all @tech{snippet systems} necessarily support an operation like this, but all the ones we've defined so far do. It may turn out that we'll want to add this to the snippet system interface.)
  
  (TODO: We may want to change the design of this to support @tech{generalized hypernests}.)
}

@defproc[
  (hypernest-join-list-and-tail-along-0
    [ds dim-sys?]
    [past-snippets
      (let*
        (
          [_ss
            (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)]
          [_shape-ss (snippet-sys-shape-snippet-sys _ss)])
        (listof
          (and/c
            (snippet-sys-snippet-with-degree=/c _ss
              (snippet-sys-snippet-degree _ss last-snippet))
            (snippet-sys-snippetof/ob-c _ss (flat-obstinacy)
              (fn _hole
                (if
                  (dim-sys-dim=0? ds
                    (snippet-sys-snippet-degree _shape-ss _hole))
                  trivial?
                  any/c))))))]
    [last-snippet
      (let
        (
          [_ss
            (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)])
        (snippet-sys-snippet-with-0<degree/c _ss))])
  (let
    ([_ss (hypernest-snippet-sys (hypertee-snippet-format-sys) ds)])
    (snippet-sys-snippet-with-degree=/c _ss
      (snippet-sys-snippet-degree _ss last-snippet)))
]{
  Given a list of non-generalized @tech{hypernests} and a final hypernest of the same @tech{degree}, returns a concatenation of them all along their degree-0 holes. Every snippet but the last must have a @racket[trivial?] value in its degree-0 hole, reflecting the fact that that hole will be filled in in the result. The degree of the hypernests must be greater than 0 so as to accommodate these degree-0 holes.
  
  In general, @tech{snippet} concatenations like @racket[snippet-sys-snippet-join] aren't list-shaped. However, list-shaped concatenations do make sense when each operand has exactly one designated hole and the shapes of the operands are compatible with each other's holes. Since each hypernest of degree greater than 0 has exactly one degree-0 hole, and since every hypernest fits into every degree-0 hole, it's particularly simple to designate concatenations of this form, and we supply this specialized function for it.
}

@deftogether[(
  @defidform[hypernest-snippet-sys]
  @defform[
    #:link-target? #f
    (hypernest-snippet-sys snippet-format-sys dim-sys)
    #:contracts
    ([snippet-format-sys snippet-format-sys?] [dim-sys dim-sys?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hypernest-snippet-sys snippet-format-sys dim-sys)
  ]
  @defproc[(hypernest-snippet-sys? [v any/c]) boolean?]
  @defproc[
    (hypernest-snippet-sys-snippet-format-sys
      [ss hypernest-snippet-sys?])
    snippet-format-sys?
  ]
  @defproc[
    (hypernest-snippet-sys-dim-sys [ss hypernest-snippet-sys?])
    dim-sys?
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{snippet system} (@racket[snippet-sys?]) where the @tech{dimension numbers} are those of the given @tech{dimension system}, the hypersnippet @tech{shapes} are the same as those of the given @tech{snippet format system} instantiated at that dimension system, and the @tech{hypersnippets} are @tech{generalized hypernests} which are based on that snippet format system and that dimension system. (In particular, when the snippet format system is @racket[(hypertee-snippet-format-sys)], the generalized hypernests are just (non-generalized) @tech{hypernests}.)
  
  The resulting snippet system's operations have behavior which corresponds to the sense in which we've described hypernests as hypersnippets throughout the documentation. Consider the @racket[snippet-sys-snippet-splice] and @racket[snippet-sys-snippet-zip-map-selective] operations, which iterate over all the @tech{holes} of a hypersnippet. In the case of a hypernest, they iterate over each of the @racket[hypernest-coil-hole]/@racket[hnb-labeled] nodes exactly once (notwithstanding early exits and the skipping of @racket[unselected?] data values), so indeed each of these nodes legitimately represents one of the hypernest's holes. We've chosen to directly describe operations like @racket[hypernest-coil-hole] in terms of hypersnippet holes, largely because the very purpose of hypernests is tied to the functionality they have as hypersnippets. Because of this, "@racket[hypernest-coil-hole] nodes really do correspond to holes" may sound tautological, but in fact the behavior of this snippet system is the reason we've been able to describe those nodes in terms of holes in the first place.
  
  (TODO: This isn't really a complete specification of the behavior. A complete specification might get very exhaustive or technical, but let's see if we can at least improve this description over time. Perhaps we should go through and hedge some of the ways we describe hypernests so that they specifically appeal to @tt{hypernest-snippet-sys} as the basis for their use of terms like "hypersnippet," "@tech{degree}," and "hole.")
  
  Two @tt{hypernest-snippet-sys} values are @racket[equal?] if they contain @racket[equal?] elements. One such value is an @racket[ok/c] match for another if the first's elements are @racket[ok/c] for the second's.
}

@deftogether[(
  @defidform[hypernest-snippet-format-sys]
  @defform[
    #:link-target? #f
    (hypernest-snippet-format-sys original)
    #:contracts ([original snippet-format-sys?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hypernest-snippet-format-sys original)
  ]
  @defproc[(hypernest-snippet-format-sys? [v any/c]) boolean?]
  @defproc[
    (hypernest-snippet-format-sys-original
      [sfs hypernest-snippet-format-sys?])
    snippet-format-sys?
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{snippet format system} (@racket[snippet-format-sys?]) where, given any particular @tech{dimension system}, the hypersnippet @tech{shapes} are the same as those of the given @tech{snippet format system} (@racket[original]) instantiated at that dimension system, and the @tech{hypersnippets} are @tech{generalized hypernests} which are based on that snippet format system and that dimension system. (In particular, when @racket[original] is @racket[(hypertee-snippet-format-sys)], the generalized hypernests are just (non-generalized) @tech{hypernests}, and the shapes are @tech{hypertees}.)
  
  The shapes and snippets are related according to the same behavior as @racket[hypernest-snippet-sys]. In some sense, this is a generalization of @racket[hypernest-snippet-sys] which puts the choice of dimension system in the user's hands. Instead of merely generalizing by being more late-bound, this also generalizes by having slightly more functionality: The combination of @racket[functor-from-dim-sys-sys-apply-to-morphism] with @racket[snippet-format-sys-functor] allows for transforming just the @tech{degrees} of a hypernest while leaving the rest of the structure alone.
  
  Two @tt{hypernest-snippet-format-sys} values are @racket[equal?] if they contain @racket[equal?] elements. One such value is an @racket[ok/c] match for another if the first's elements are @racket[ok/c] for the second's.
}
