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
  -> </c and/c any/c contract? flat-contract? ->i list/c)
@(require #/for-label #/only-in racket/math natural?)

@(require #/for-label #/only-in lathe-comforts fn)
@(require #/for-label #/only-in lathe-comforts/maybe maybe/c nothing)
@(require #/for-label #/only-in lathe-comforts/trivial trivial?)
@(require #/for-label #/only-in lathe-morphisms/in-fp/category
  category-sys? category-sys-morphism/c functor-sys?
  functor-sys-apply-to-morphism functor-sys-apply-to-object
  functor-sys/c functor-sys-impl? functor-sys-target
  make-functor-sys-impl-from-apply
  natural-transformation-sys-apply-to-morphism
  natural-transformation-sys/c
  natural-transformation-sys-endpoint-target
  natural-transformation-sys-source natural-transformation-sys-target
  prop:functor-sys)
@(require #/for-label #/only-in lathe-morphisms/in-fp/mediary/set
  ok/c)

@(require #/for-label punctaffy/hypersnippet/dim)
@(require #/for-label punctaffy/hypersnippet/hyperstack)
@(require #/for-label punctaffy/hypersnippet/snippet)


@title{Punctaffy}

Punctaffy is a library implementing and exploring hypersnippets, a higher-dimensional generalization of lexical hierarchical structure. For instance, theoretically, Punctaffy can be good for manipulating data that contains expanded macro bodies whose internal details should be independent from both the surrounding code and the code they interpolate. Structural recursion using Punctaffy's data representations makes it easy to keep these local details local, just as traditional forms of structural recursion make it easy to keep branches of a tree data structure from interfering with unrelated branches.

So how does this make any sense? We can think of the macro bodies as being @emph{more deeply nested}, despite the fact that the code they interpolate still appears in a nested position as far as the tree structure of the code is concerned. In this sense, the tree structure is not the full story of the nesting of the code.

This is a matter of @emph{dimension}, and we can find an analogous situation one dimension down: The content between two parentheses is typically regarded as further into the traversal of the tree structure of the code, despite the fact that the content following the closing parenthesis is still further into the traversal of the code's text stream structure. The text stream is not the full story of how the code is meant to be traversed.

Punctaffy has a few particular data structures that it revolves around.

A @deftech{hypersnippet}, or a @deftech{snippet} for short, is a region of code that's bounded by lower-degree snippets. The @deftech{degree} of a snippet is typically a number representing its dimension in a geometric sense. For instance, a degree-3 snippet is bounded by degree-2 snippets, which are bounded by degree-1 snippets, which are bounded by degree-0 snippets, just as a 3D cube is bounded by 2D squares, which are bounded by 1D line segments, which are bounded by 0D points. One of the boundaries of a hypersnippet is the opening delimiter. The others are the closing delimiters, or the @deftech{holes} for short. This name comes from the idea that a degree-3 snippet is like an expression (degree-2 snippet) with expression-shaped holes.

While a degree-3 snippet primarily has degree-2 holes, it's also important to note that its degree-2 opening delimiter has degree-1 holes, and the degree-1 opening delimiter of that opening delimiter has a degree-0 hole. Most Punctaffy operations traverse the holes of every dimension at once, largely just because we've found that to be a useful approach.

The idea of a hypersnippet is specific enough to suggest quite a few operations, but the actual content of the code contained @emph{inside} the snippet is vague. We could say that the content of the code is some sequence of bytes or some Unicode text, but we have a lot of options there, and it's worth generalizing over them so that we don't have to implement a new library each time. So the basic operations of a hypersnippet are represented in Punctaffy as generic operations that multiple data structures might be able to implement.

Snippets don't identify their own snippet nature. Instead, each hypersnippet operation takes a @deftech{hypersnippet system} (aka a @deftech{snippet system}) argument, and it uses that to look up the appropriate hypersnippet functionality.

A @deftech{dimension system} is a collection of implementations of the arithmetic operations we need on dimension numbers. (A @deftech{dimension number} is the "3" in the phrase "degree-3 hypersnippet." It generally represents the set of smaller dimension numbers that are allowed for a snippet's @tech{holes}.) For what we're doing so far, it turns out we only need to compare dimension numbers and take their maximum. For some purposes, it may be useful to use dimension numbers that aren't quite numbers in the usual sense, such as dimensions that are infinite or symbolic.

@; TODO: See if we should mention hyperstacks right here. It seems like they can be skipped in this high-level overview since they're more of an implementation aid.

A hypersnippet system always has some specific dimension system it's specialized for. We tend to find that notions of hypersnippet make sense independently of a specific dimension system, so we sometimes represent these notions abstractly as a kind of functor from a dimesion system to a snippet system. In practical terms, a functor like this lets us convert between two snippet systems that vary only in their choice of dimension system, as long as we have some way to convert between the dimension systems in question.

A @deftech{hypertee} is a kind of hypersnippet data structure that represents a region of code that doesn't contain content of any sort at all. A hypertee may not have content, but it still has a boundary, and hypertees tend to arise as the description of the @tech{shape} of a hypersnippet. For instance, when we try to graft a snippet into the hole of another snippet, it needs to have a shape that's compatible with the shape of that hole.

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
  
  For some dimension systems, this may be relied upon to be a flat contract or a chaperone contract.
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
    [dim-max-of-list
      (->i ([_ds dim-sys?] [_dims (_ds) (listof (dim-sys-dim/c _ds))])
        [_ (_ds) (dim-sys-dim/c _ds)])])
  dim-sys-impl?
]{
  Given implementations for @racket[dim-sys-dim/c], @racket[dim-sys-dim=?], and a list-taking variation of @racket[dim-sys-dim-max], returns something a struct can use to implement the @racket[prop:dim-sys] interface.
  
  The given method implementations should observe some algebraic laws. Namely, the @racket[dim=?] operation should be a decision procedure for equality of @tech{dimension numbers}, the @racket[dim-max-of-list] operation should be associative, commutative, and idempotent. (As a particularly notable consequence of idempotence, the maximum of a list of one dimension number should be that number itself.)
  
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
  
  @; TODO: See if we should guarantee a flat contract or chaperone contract under certain circumstances.
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
  
  @; TODO: See if we should guarantee the @racket[dim-sys-dim/c] to be a flat contract or chaperone contract under certain circumstances.
  
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
  
  @; TODO: See if we should guarantee the @racket[dim-sys-dim/c] to be a flat contract or chaperone contract under certain circumstances.
  
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

(TODO: Document a lot more things.)


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
  
  @; TODO: See if we should guarantee a flat contract or chaperone contract under certain circumstances.
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

@defproc[(snippet-sys-snippet/c [ss snippet-sys?]) contract?]{
  Returns a contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system}.
  
  For some snippet systems, this may be relied upon to be a flat contract or a chaperone contract.
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
  contract?
]{
  Returns a contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system} if its @tech{degree} satisfies the given flat contract.
  
  @; TODO: See if we should guarantee a flat contract or chaperone contract under certain circumstances.
}

@deftogether[(
  @defproc[
    (snippet-sys-snippet-with-degree</c
      [ss snippet-sys?]
      [degree (dim-sys-dim/c (snippet-sys-dim-sys ss))])
    contract?
  ]
  @defproc[
    (snippet-sys-snippet-with-degree=/c
      [ss snippet-sys?]
      [degree (dim-sys-dim/c (snippet-sys-dim-sys ss))])
    contract?
  ]
)]{
  Returns a contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system} if its @tech{degree} is strictly less than the given one, or if its degree is equal to the given one.
  
  @; TODO: See if we should guarantee a flat contract or chaperone contract under certain circumstances.
}

@defproc[
  (snippet-sys-snippetof
    [ss snippet-sys?]
    [h-to-value/c
      (->
        (snippet-sys-snippetof (snippet-sys-shape-snippet-sys ss)
          (fn _hole trivial?))
        contract?)])
  contract?
]{
  Returns a contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system} if the values in its @tech{holes} abide by the given contracts. The contracts are given by a function @racket[h-to-value/c] that takes the hypersnippet @tech{shape} of the hole and returns a contract for values residing in that hole.
  
  This design allows us to require the values in the holes to somehow @emph{fit} the shapes of the holes they're carried in. It's rather common for the value contracts to depend on at least the @tech{degree} of the hole, if not on its complete shape.
  
  This operation appears in its own contract. This usage refers to the fact that the hole shape supplied to @racket[h-to-value/c] will have @racket[trivial?] values in its holes.
  
  @; TODO: See if we should have a `(snippet-sys-unlabeled-shape/c ss)` that abbreviates this common `(snippet-sys-snippetof ... trivial? ...)` combination. That might be especially helpful here, just in case `snippet-sys-snippetof` appearing in its own contract turns out to confuse someone.
  
  @; TODO: See if we should guarantee a flat contract or chaperone contract under certain circumstances.
}

@defproc[
  (snippet-sys-snippet-zip-selective/c
    [ss snippet-sys?]
    [shape (snippet-sys-snippet/c (snippet-sys-shape-snippet-sys ss))]
    [check-subject-hv?
      (->
        (snippet-sys-snippetof (snippet-sys-shape-snippet-sys ss)
          (fn _hole trivial?))
        any/c
        boolean?)]
    [hvv-to-subject-v/c
      (->
        (snippet-sys-snippetof (snippet-sys-shape-snippet-sys ss)
          (fn _hole trivial?))
        any/c
        any/c
        contract?)])
  contract?
]{
  Returns a contract which recognizes any @tech{hypersnippet} of the given @tech{snippet system} if some of its @tech{holes} correspond with the holes of the given @tech{shape} hypersnippet @racket[shape] and if the values in those holes are somehow compatible with the values held in @racket[shape]'s holes.
  
  To determine which holes from the subject will be compared to those in @racket[shape], the given @racket[check-subject-hv?] is called for each of the subject's holes, passing it the hole's shape and the data value it carries. It's expected to return a boolean indicating whether this hole should correspond to some hole in @racket[shape].
  
  To determine if a value in the subject's holes is compatible with a corresponding (same-shaped) hole in @racket[shape], the @racket[hvv-to-subject-v/c] procedure is called, passing it the hole's shape, the value carried in @racket[shape]'s hole, and the value carried in the subject's hole. It's expected to return a contract, and the value in the subject's hole is expected to abide by that contract.
  
  In our experience so far, it seems the @racket[check-subject-hv?] function always takes on a certain form: It always selects every hole that has @tech{degree} lower than @racket[shape]'s degree. (TODO: Consider updating the design of @tt{snippet-sys-snippet-zip-selective/c} to reflect that, or at least designing an alternative that's simpler for this common case.)
  
  @; TODO: See if we should guarantee a flat contract or chaperone contract under certain circumstances.
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
  (maybe/c
    (snippet-sys-snippet-with-degree=/c
      (snippet-sys-shape-snippet-sys ss)
      (snippet-sys-snippet-degree ss snippet)))
]{
  Checks whether a @tech{hypersnippet} is content-free, and if it is, computes the hypersnippet's @tech{shape}.
  
  The resulting shape, if any, carries all the same values in its @tech{holes}.
  
  This operation is invertible when it succeeds. The resulting shape, if any, can be converted back into a content-free hypersnippet by using @racket[snippet-sys-shape->snippet].
  
  @; TODO: See if the result contract should be more specific. The resulting shape should always be of the same shape as the input snippet.
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
      (dim-sys-dim=/c (snippet-sys-dim-sys ss)
        (snippet-sys-snippet-degree ss snippet))
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
    (snippet-sys-snippetof ss (fn _hole selected?)))
]{
  Returns a @tech{hypersnippet} like the given one, but where the data value carried in each @tech{hole} has been selected for traversal in the sense of @racket[selectable?].
  
  @; TODO: See if the result contract should be more specific. The resulting snippet should always be of the same shape as the given one.
}

@defproc[
  (snippet-sys-snippet-splice
    [ss snippet-sys?]
    [snippet (snippet-sys-snippet/c ss)]
    [hv-to-splice
      (let
        (
          [_ds (snippet-sys-dim-sys ss)]
          [_shape-ss (snippet-sys-shape-snippet-sys ss)]
          [_d (snippet-sys-snippet-degree ss snippet)])
        (->i
          (
            [_prefix-hole
              (snippet-sys-snippetof
                (snippet-sys-shape-snippet-sys ss)
                (fn _hole trivial?))]
            [_data any/c])
          [_ (_prefix-hole)
            (let
              (
                [_prefix-hole-d
                  (snippet-sys-snippet-degree
                    _shape-ss _prefix-hole)])
              (maybe/c
                (selectable/c any/c
                  (and/c
                    (snippet-sys-snippet-with-degree=/c ss _d)
                    (snippet-sys-snippet-zip-selective/c ss
                      _prefix-hole
                      (fn _suffix-hole _subject-data
                        (let
                          (
                            [_suffix-hole-d
                              (snippet-sys-snippet-degree
                                _shape-ss _suffix-hole)])
                          (dim-sys-dim<?
                            _ds _suffix-hole-d _prefix-hole-d)))
                      (fn _hole _shape-data _subject-data
                        trivial?))))))]))])
  (maybe/c
    (snippet-sys-snippet-with-degree=/c ss
      (snippet-sys-snippet-degree ss snippet)))
]{
  Attempts to concatenate the given "prefix" @tech{hypersnippet} @racket[snippet] to any selected "suffix" hypersnippets computed from the @tech{hole} data by the given selection-attempting data-transforming procedure @racket[hv-to-splice].
  
  The @racket[hv-to-splice] procedure is invoked with the @tech{shape} and data value of each hole of the prefix, possibly stopping partway through if at least one of the invocations returns @racket[(nothing)]. If any invocation returns @racket[(nothing)], the overall result is @racket[(nothing)]. Otherwise, the concatenation proceeds successfully.
  
  When an invocation of @racket[hv-to-splice] is successful for some hole of degree N, the result is expected to be a @racket[selectable?] value. If it's @racket[unselected?], a corresponding hole with the @racket[unselected-value] appears verbatim in the concatenation result (without the value being concatenated to the prefix hypersnippet). If it's @racket[selected?], its @racket[selected-value] is expected to be a "suffix" hypersnippet, and it's concatenated into the prefix hypersnippet along the hole it's carried by in the prefix. For this concatenation to work, the suffix hypersnippet is expected to have the same degree as the prefix, and its holes of degree less than N are expected to contain @racket[trivial?] values and correspond to the holes of the prefix's hole. Any holes of degree not less than N become holes in the concatenated result.
  
  This operation obeys higher-dimensional algebraic laws. We haven't really figured out how to express these laws yet, but they seem to correspond to the category-theoretic notion that this operation performs whiskering of higher-dimensional cells along various dimensions at once. (TODO: Do at least a little better. This could be an ongoing effort, but ideally we would have something to show in the @racket[#:should-be-equal] DSL that we use for other documentation of algebraic laws.)
  
  Some of the lawfulness is a kind of associativity: If we first concatenate along some selected holes and then concatenate along some other holes that weren't selected the first time, that's the same as concatenating along all those holes at once. If a hole's suffix is itself a concatenation of some suffix-prefix to some suffix-suffix, then it doesn't matter whether we concatenate those two parts to form the suffix first or if we concatenate the prefix to the suffix-prefix and then concatenate the suffix-suffix last.
  
  Some of the lawfulness is a kind of unitality: If the concatenation is being performed along a hole where either the prefix or the suffix is an identity element produced by @racket[snippet-sys-snippet-done] for that hole shape, then the result resembles the other snippet. (When the prefix is the identity, the result is equal to the suffix. When the suffix is the identity, the result is the prefix, but with its data value in that hole replaced with the data value that would have been passed to @racket[snippet-sys-snippet-done] when creating the suffix.)
}
