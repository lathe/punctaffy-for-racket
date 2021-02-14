#lang parendown scribble/manual

@; punctaffy/scribblings/punctaffy/defining-hyperbracket.scrbl
@;
@; Infrastructure for defining hyperbracket notations, for denoting
@; hypersnippet-shaped lexical regions.

@;   Copyright 2021 The Lathe Authors
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


@title[#:tag "hyperbracket-notation"]{Defining Hyperbracket Notations for Racket}

@defmodule[punctaffy/hyperbracket]

In order to use higher-dimensional @tech{hypernests} for syntax in Racket, we supply some new notations that augment Racket's low-dimensional lexical structure. We do this not by replacing Racket's existing reader and macro system, but by letting each Racket macro that cares about higher-dimensional structure do its own parsing of that structure when it needs to. Before this parsing occurs, we represent the structure in Racket syntax in the form of what we call @deftech{hyperbrackets}.

Punctaffy hasn't been put to the test yet, and there may still be some uncertainty about what the best notation for hypernest-structured programs will be. We may augment Punctaffy with new ideas in the future, and not all possible paths will necessarily lead to the same feature set.

With this in mind, we define our most basic hyperbracket notation keywords in such a way that they have no innate functionality but can instead be assigned meanings (hopefully consistent enough ones) by multiple external DSL implementations.

This is a pretty typical scenario in Racket. Racket has identifiers like @racket[_], @racket[...], @racket[else], and @racket[unquote] that are only assigned meaning by some external DSL.

Typically these DSLs recognize these special identifiers using @racket[free-identifier=?]. This approach allows new keywords to be added over time by exporting them from new (module path, symbol) pairs.

We take a different approach: We treat the identity as part of the functionality of the macro itself, not of the identifier. For each new piece of hyperbracket notation that should be identifiable, we provide some innate way to identify it, essentially treating it as a small macro DSL of its very own. As various experimental DSL implementations based on Punctaffy's hyperbracket notation mature and stabilize their macro calling conventions, we expect hyperbrackets to be a patchwork of multiple DSLs anyway, so we embrace that from the start.

Note that the term "hyperbracket" could be generalized beyond our Racket-specific use here. Punctaffy's own @racket[hypernest-bracket?] values are an abstract syntax representation of 0-dimensional hyperbrackets with labels in certain places. The ones we're talking about here are instead a concrete (indeed, @emph{unparsed}) representation of 1-dimensional hyperbrackets with no labels. We're using the generic term "hyperbracket" for the latter because it's the one that's most likely to be relevant most often in the context of Punctaffy's use as a Racket library, since Racket already has 1-dimensional hypernest @tech{bumps} (namely, paren matchings) to attach hyperbrackets to.


@deftogether[(
  @defproc[(hyperbracket-notation? [v any/c]) boolean?]
  @defproc[(hyperbracket-notation-impl? [v any/c]) boolean?]
  @defthing[
    prop:hyperbracket-notation
    (struct-type-property/c hyperbracket-notation-impl?)
  ]
)]{
  Structure type property operations for @tech{hyperbracket} notation keywords. Every macro that needs to be recognized as part of the hyperbracket notation by a hyperbracket parser should implement this property. That way, non-hyperbracket identifiers can be recognized as such, thus allowing hyperbrackets to coexist with existing Racket notations without the risk of making the user's intent ambiguous.
  
  A structure type that implements this property should generally also implement @racket[prop:procedure] to display an informative error message when the notation is used in a position where a Racket expression is expected.
}

@defproc[
  (make-hyperbracket-notation-impl)
  hyperbracket-notation-impl?
]{
  Returns something a struct can use to implement the @racket[prop:hyperbracket-notation] interface.
}

@deftogether[(
  @defproc[(hyperbracket-notation-prefix-expander? [v any/c]) boolean?]
  @defproc[
    (hyperbracket-notation-prefix-expander-impl? [v any/c])
    boolean?
  ]
  @defthing[
    prop:hyperbracket-notation-prefix-expander
    (struct-type-property/c
      hyperbracket-notation-prefix-expander-impl?)
  ]
)]{
  Structure type property operations for @tech{hyperbracket} keywords that can desugar to more basic hyperbracket notation when invoked in prefix position.
  
  A structure type that implements this property should generally also implement @racket[prop:hyperbracket-notation] to signify the fact that it's a hyperbracket notation,
  
  A structure type that implements this property should generally also implement @racket[prop:procedure] to display an informative error message when the notation is used in a position where a Racket expression is expected.
}

@defproc[
  (hyperbracket-notation-prefix-expander-expand
    [expander hyperbracket-notation-prefix-expander?]
    [stx syntax?])
  syntax?
]{
  Uses the given @racket[hyperbracket-notation-prefix-expander?] to expand the given syntax term. The term should be a syntax list which begins with an identifier that's bound to the given expander.
}

@defproc[
  (make-hyperbracket-notation-prefix-expander-impl
    [expand
      (-> hyperbracket-notation-prefix-expander-impl? syntax?
        syntax?)])
  hyperbracket-notation-prefix-expander-impl?
]{
  Given an implementation for @racket[hyperbracket-notation-prefix-expander-expand], returns something a struct can use to implement the @racket[prop:hyperbracket-notation-prefix-expander] interface.
}

@defproc[
  (makeshift-hyperbracket-notation-prefix-expander
    [expand (-> syntax? syntax?)])
  (and/c
    procedure?
    hyperbracket-notation?
    hyperbracket-notation-prefix-expander?)
]{
  Given an implementation for @racket[hyperbracket-notation-prefix-expander-expand], returns a macro implementation value that can be used with @racket[define-syntax] to define a prefix @tech{hyperbracket} notation. DSLs that parse hyperbrackets will typically parse this notation by first transforming it according to the given expander procedure and then attempting to parse the result.
}

@deftogether[(
  @defidform[hyperbracket-open-with-degree]
  @defform[#:link-target? #f (hyperbracket-open-with-degree)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hyperbracket-open-with-degree)
  ]
  @defproc[(hyperbracket-open-with-degree? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct the @racket[hyperbracket-notation?] syntax implementation corresponding to @racket[^<d]. This notation represents an opening @tech{hyperbracket} with a specified nonzero @tech{degree}.
  
  This structure type implements @racket[prop:procedure] for one argument so that it can behave like a syntax transformer, but invoking that behavior results in a syntax error. In the future, this error may be replaced with a more @racket[#%app]-like behavior.
  
  Every two @tt{hyperbracket-open-with-degree} values are @racket[equal?]. One such value is always an @racket[ok/c] match for another.
}

@deftogether[(
  @defidform[hyperbracket-close-with-degree]
  @defform[#:link-target? #f (hyperbracket-close-with-degree)]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (hyperbracket-close-with-degree)
  ]
  @defproc[(hyperbracket-close-with-degree? [v any/c]) boolean?]
)]{
  Struct-like operations which construct and deconstruct the @racket[hyperbracket-notation?] syntax implementation corresponding to @racket[^>d]. This notation represents a closing @tech{hyperbracket} with a specified nonzero @tech{degree}.
  
  This structure type implements @racket[prop:procedure] for one argument so that it can behave like a syntax transformer, but invoking that behavior results in a syntax error.
  
  Every two @tt{hyperbracket-close-with-degree} values are @racket[equal?]. One such value is always an @racket[ok/c] match for another.
}
