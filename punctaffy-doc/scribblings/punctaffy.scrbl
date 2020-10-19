#lang parendown scribble/manual

@; punctaffy/scribblings/punctaffy.scrbl
@;
@; A library implementing and exploring hypersnippets, a
@; higher-dimensional generalization of syntax with holes.

@;   Copyright 2020 The Lathe Authors
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


@(require #/for-label racket/base)
@(require #/for-label #/only-in racket/contract
  struct-type-property/c)
@(require #/for-label #/only-in racket/contract/base
  -> </c and/c any/c contract? flat-contract? ->i)
@(require #/for-label #/only-in racket/math natural?)

@; TODO: Use `only-in` for this import.
@(require #/for-label lathe-morphisms/in-fp/category)
@(require #/for-label #/only-in lathe-morphisms/in-fp/mediary/set ok/c)

@(require #/for-label punctaffy/hypersnippet/dim)
@(require #/for-label punctaffy/hypersnippet/snippet)


@title{Punctaffy}

Punctaffy is a library implementing and exploring hypersnippets, a higher-dimensional generalization of lexical hierarchical structure. For instance, theoretically, Punctaffy can be good for manipulating data that contains expanded macro bodies whose internal details should be independent from both the surrounding code and the code they interpolate. Structural recursion using Punctaffy's data representations makes it easy to keep these local details local, just as traditional forms of structural recursion make it easy to keep branches of a tree data structure from interfering with unrelated branches.

How does this make any sense? We can think of the macro bodies as being @emph{more deeply nested}, despite the fact that the code they interpolate still appears in a nested position as far as the tree structure of the code is concerned. In this sense, the tree structure is not the full story of the nesting of the code.

This is a matter of @emph{dimension}, and we can find a fully analogous situation one one dimension down: The content between two parentheses is typically be regarded as further into the traversal of the tree structure of the code, despite the fact that the content following the closing parenthesis is still further into the traversal of the code's text stream structure. The text stream is not the full story of how the code is meant to be traversed.

Punctaffy has a few particular data structures that it revolves around.

A @deftech{hypersnippet}, or a @deftech{snippet} for short, is a region of code that's bounded by lower-degree snippets. The @deftech{degree} of a snippet is typically a number representing its dimension in a geometric sense. For instance, a degree-3 snippet is bounded by degree-2 snippets, which are bounded by degree-1 snippets, which are bounded by degree-0 snippets, just as a 3D cube is bounded by 2D squares, which are bounded by 1D line segments, which are bounded by 0D points. One of the boundaries of a hypersnippet is the opening delimiter. The others are the closing delimiters, or the @deftech{holes} for short. This name comes from the idea that a degree-3 snippet is like an expression (degree-2 snippet) with expression-shaped holes.

While a degree-3 snippet primarily has degree-2 holes, it's also important to note that its degree-2 opening delimiter has degree-1 holes, and the degree-1 opening delimiter of that opening delimiter has a degree-0 hole. Most Punctaffy operations traverse the holes of every dimension at once, largely just because we've found that to be a useful approach.

The idea of a hypersnippet is specific enough to suggest quite a few operations, but the actual content of the code contained @emph{inside} the snippet is vague. We could say that the content of the code is some sequence of bytes or some Unicode text, but we have a lot of options there, and it's worth generalizing over them so that we don't have to implement a new library each time. So the basic operations of a hypersnippet are represented in Punctaffy as generic operations that multiple data structures might be able to implement.

Snippets don't identify their own snippet nature. Instead, each hypersnippet operation takes a @deftech{hypersnippet system} (aka a @deftech{snippet system}) argument, and it uses that to look up the appropriate hypersnippet functionality.

A @deftech{dimension system} is a collection of implementations of the arithmetic operations we need on dimension numbers. (A @deftech{dimension number} is the "3" in the phrase "degree-3 hypersnippet." It generally represents the set of smaller dimension numbers that are allowed for a snippet's @tech{holes}.) For what we're doing so far, it turns out we only need to compare dimension numbers and take their maximum. For some purposes, it may be useful to use dimension numbers that aren't quite numbers in the usual sense, such as dimensions that are infinite or symbolic.

A hypersnippet system always has some specific dimension system it's specialized for. We tend to find that notions of hypersnippet make sense independently of a specific dimension system, so we sometimes represent these notions abstractly as a kind of functor from a dimesion system to a snippet system. In practical terms, a functor like this lets us convert between two snippet systems that vary only in their choice of dimension system, as long as we have some way to convert between the dimension systems in question.

A @deftech{hypertee} is a kind of hypersnippet data structure that represents a region of code that doesn't contain content of any sort at all. A hypertee may not have content, but it still has a boundary, and hypertees tend to arise as the description of the @emph{shape} of a hypersnippet. For instance, when we try to graft a snippet into the hole of another snippet, it needs to have a shape that's compatible with the shape of that hole.

A @deftech{hypernest} is a kind of hypersnippet data structure that generalizes some other kind of hypersnippet (typically hypertees) by adding @deftech{bumps}. Bumps are like @tech{holes} that are already filled in, but with a seam showing. The filling, called the bump's @deftech{interior}, is considered to be nested deeper than the surrounding content. A bump can contain other bumps. A bump can also contain holes of degree equal to or greater than the bump's degree.

A hypernest is a generalization of an s-expression or other syntax tree. In an s-expression, the bumps are the pairs of parentheses and the atoms. In a syntax tree, the bumps are the nodes. Just as trees are rather effective representations of lots of different kinds of structured programs and structured data, so are hypernests, and that makes them Punctaffy's primary hypersnippet data structure.


@; TODO: Consider using the following explanation for something. I think it builds up to the point too slowly to be a useful introduction to hypersnippets, but it might turn out to be just the explanation someone needs. Maybe now that we've laid out the main themes of Punctaffy above, this can be part of a more gradual explanation. Let's also consider how the readme factors into all this.

@;{

At some level, program code is often represented with text streams. This is a one-dimensional representation of syntax; when we talk about a snippet of text, we designate a beginning point and an ending point and talk about the text that falls in between.

Instead of treating the program as a text stream directly, most languages conceive of it as taking on a tree structure, like an s-expression, a Racket syntax object, a concrete syntax tree, or a skeleton tree. Even later stages of program analysis tend to be modeled as trees (in this case, abstract syntax trees). The notion of a "program with holes" tends to refer to a tree where some of the branches are designated as blanks to be filled in later.

A "program with holes" in that sense is very much analogous to a snippet of text: It begins with a root node and ends with any number of hole nodes, and we talk about the nodes in between.

As s-expressions make explicit, a node in a concrete syntax tree tends to correspond to a pair of parentheses in the text stream. So each node is a snippet between points in the text, and a program with holes is the content that falls in between one root snippet and some number of hole snippets. It's a 2-dimensional snippet.

The dimensions of a higher-dimensional snippet are roughly analogous to those of a geometric shape. A location in a text stream is like a geometric point, a snippet of text is like a line segment bounded by two points, and a program-with-holes is like a polygon bounded by line segments.

As with geometric shapes, we can look toward higher dimensions: A 3-dimensional snippet is bounded by an outer program-with-holes and some arrangement of inner programs-with-holes. A 4-dimensional snippet is bounded by 3-dimensional snippets. We coin the term "hypersnippet" to suggest this tower of generalization.

Higher-dimensional geometric shapes often have quite a number of component vertices and line segments, and the jumble can be a bit awkward to visualize. The same is true to some extent with hypersnippets, but as full of detail as they can get, they're still ultimately bounded by some collection of locations in a text stream. Because of this, we can visualize their shapes using sequences of unambiguously labeled brackets positioned at those points.

}



@table-of-contents[]



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

@defproc[(dim-sys-dim/c [ds dim-sys?]) contract?]{
  Returns a contract which recognizes any @tech{dimension number} of the given @tech{dimension system}.
}

@defproc[
  (dim-sys-dim-max [ds dim-sys?] [arg (dim-sys-dim/c ds)] ...)
  (dim-sys-dim/c ds)
]{
  Returns the maximum of zero or more @tech{dimension numbers}.
  
  The maximum of zero dimension numbers is well-defined; it's the least dimension number of the @tech{dimension system}. Typically this is 0, representing the dimension of 0-dimensional shapes. We recommended to use @racket[dim-sys-dim-zero] in that case for better clarity of intent.
}

@defproc[(dim-sys-dim-zero [ds dim-sys?]) (dim-sys-dim/c ds)]{
  Returns the least @tech{dimension numbers} of the @tech{dimension system}. Typically this is 0, representing the dimension of 0-dimensional shapes.
  
  This is equivalent to calling @racket[dim-sys-dim-max] without passing in any dimension numbers. We provide this alternative for better clarity of intent.
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
    contract?
  ]
  @defproc[
    (dim-sys-dim=/c [ds dim-sys?] [bound (dim-sys-dim/c ds)])
    contract?
  ]
)]{
  Returns a contract which recognizes @tech{dimension numbers} which are strictly less than the given one, or which are equal to the given one.
  
  The result is a flat contract as long as the given @tech{dimension system}'s @racket[dim-sys-dim/c] contract is flat.
  
  @; TODO: See if we should make a similar guarantee about chaperone contracts.
}

@defproc[(dim-sys-0<dim/c [ds dim-sys?]) contract?]{
  Returns a contract which recognizes @tech{dimension numbers} which are nonzero, in the sense of @racket[dim-sys-dim-zero].
  
  The result is a flat contract as long as the given @tech{dimension system}'s @racket[dim-sys-dim/c] contract is flat.
  
  @; TODO: See if we should make a similar guarantee about chaperone contracts.
}

@defproc[
  (make-dim-sys-impl-from-max
    [dim/c (-> dim-sys? contract?)]
    [dim=?
      (->i
        (
          [_ds dim-sys?]
          [_a (_ds) (dim-sys-dim/c _ds)]
          [_b (_ds) (dim-sys-dim/c _ds)])
        [_ boolean?])]
    [max-of-list
      (->i ([_ds dim-sys?] [_lsts (_ds) (listof #/dim-sys-dim/c _ds)])
        [_ (_ds) (dim-sys-dim/c _ds)])])
  dim-sys-impl?
]{
  Given implementations for @racket[dim-sys-dim/c], @racket[dim-sys-dim=?], and a list-taking variation of @racket[dim-sys-dim-max], returns something a struct can use to implement the @racket[prop:dim-sys] interface.
  
  The given method implementations should observe some algebraic laws. Namely, the @racket[dim=?] operation should be the decision procedure of some decidable equivalence relation, and the @racket[max-of-list] operation should be associative and commutative.
  
  So far, we've only tried @racket[flat-contract?] values for @racket[dim/c]. It's possible that the implementation of some Punctaffy operations like @racket[dim-sys-dim</c] relies on the @racket[dim/c] contract being flat in order to avoid breaking contracts itself when it passes the value to another operation. (TODO: Investigate this further.)
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
  (make-dim-sys-morphism-sys-sys-impl-from-apply
    [source
      (-> dim-sys-morphism-sys? dim-sys?)]
    [replace-source
      (-> dim-sys-morphism-sys? dim-sys? functor-sys?)]
    [target
      (-> dim-sys-morphism-sys? dim-sys?)]
    [replace-target
      (-> dim-sys-morphism-sys? dim-sys? functor-sys?)]
    [morph-dim
      (->i
        (
          [_ms dim-sys-morphism-sys?]
          [object (_ms)
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
  
  Moreover, the @tt{replace} methods should not raise an error when a value is replaced with itself. They're intended only for use by @racket[functor-sys/c] and similar error-detection systems, which will tend to replace a replace a value with one that reports better errors.
  
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
}

@; TODO: Consider having a `makeshift-dim-sys-morphism-sys`, similar
@; to `makeshift-functor-sys`.

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
  Returns the composition of the two given @racket[dim-sys-morphism-sys?] values. This is a transformation that goes from the first transformation's source @tech{dimension system} to the second functor's target dimension system, transforming every @tech{dimension number} by applying the first transformation and then the second. The target of the first transformation should match the source of the second.
  
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
  
  These method implementations should observe the same algebraic laws as required by @racket[make-functor-sys-impl-from-apply].
  
  This is essentially a shorthand for calling @racket[make-functor-sys-impl-from-apply] and supplying the appropriate source- and target-determining method implementations.
}


@subsection[#:tag "dim-sys-examples"]{Commonly Used Dimension Systems}

@deftogether[(
  @defidform[nat-dim-sys]
  @defform[#:link-target? #f (nat-dim-sys)]
  @defform[#:kind "match expander" #:link-target? #f (nat-dim-sys)]
  @defproc[(nat-dim-sys? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct a @tech{dimension system} (@racket[dim-sys?]) where the @tech{dimension numbers} are the @racket[natural?] numbers and the @racket[dim-sys-dim-max] operation is @racket[max].
  
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
  
  @; TODO: See if we guarantee a flat contract or chaperone contract under certain circumstances.
}

@defproc[
  (extended-with-top-dim=?
    [original-dim=? (-> any/c any/c boolean?)]
    [a extended-with-top-dim?]
    [b extended-with-top-dim?])
  boolean?
]{
  Returns whether the two given @racket[extended-with-top-dim?] values are equal, given a procedure for checking whether two @tech{dimension numbers} of the unextended @tech{dimension system} are equal.
  
  If the given procedure is not the decision procedure of a decidable equivalence relation, then neither is this one. In that case, this one merely relates two finite dimension numbers if they would be related by @racket[original-dim=?] in the unextended dimension system.
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




@section[#:tag "snippet-sys"]{Snippet Systems}

@defmodule[punctaffy/hypersnippet/snippet]


@subsection[#:tag "snippet-sys-in-general"]{Snippet Systems in General}

(TODO: Document a lot more things.)


@defproc[(snippet-sys? [v any/c]) boolean?]{
  Returns whether the given value is a @tech{snippet system}.
}
