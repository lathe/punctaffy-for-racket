#lang parendown scribble/manual

@; punctaffy/scribblings/punctaffy/defining-hyperbracket.scrbl
@;
@; Infrastructure for defining hyperbracket notations, for denoting
@; hypersnippet-shaped lexical regions.

@;   Copyright 2021, 2022, 2025 The Lathe Authors
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


@title[#:tag "taffy-notation"]{Defining Hyperbracket Notations for Racket}

@defmodule[punctaffy/taffy-notation]

In order to use higher-dimensional @tech{hypernests} for syntax in Racket, we supply some new notations that augment Racket's low-dimensional lexical structure. We do this not by replacing Racket's existing reader and macro system, but by letting each Racket macro that cares about higher-dimensional structure do its own parsing of that structure when it needs to. Before this parsing occurs, we represent the structure in Racket syntax in the form of what we call @deftech{hyperbrackets}.

Punctaffy hasn't been put to the test yet, and there may still be some uncertainty about what the best notation for hypernest-structured programs will be. We may augment Punctaffy with new ideas in the future, and not all possible paths will necessarily lead to the same feature set.

With this in mind, we define our most basic hyperbracket notation keywords in such a way that they have no innate functionality but can instead be assigned meanings (hopefully consistent enough ones) by multiple external DSL implementations.

This is a pretty typical scenario in Racket. Racket has identifiers like @racket[_], @racket[...], @racket[else], and @racket[unquote] that are only assigned meaning by some external DSL.

Typically these DSLs recognize these special identifiers using @racket[free-identifier=?]. This approach allows new keywords to be added over time by exporting them from new (module path, symbol) pairs.

We take a different approach: We treat the identity as part of the functionality of the macro itself, not of the identifier. For each new piece of hyperbracket notation that should be identifiable, we provide some innate way to identify it, essentially treating it as a small macro DSL of its very own. As various experimental DSL implementations based on Punctaffy's hyperbracket notation mature and stabilize their macro calling conventions, we expect hyperbrackets to be a patchwork of multiple DSLs anyway, so we embrace that from the start.

Note that the term "hyperbracket" could be generalized beyond our Racket-specific use here. Punctaffy's own @racket[hypernest-bracket?] values are an abstract syntax representation of 0-dimensional hyperbrackets with labels in certain places. The ones we're talking about here are instead a concrete (indeed, @emph{unparsed}) representation of 1-dimensional hyperbrackets with no labels. We're using the generic term "hyperbracket" for the latter because it's the one that's most likely to be relevant most often in the context of Punctaffy's use as a Racket library, since Racket already has 1-dimensional hypernest @tech{bumps} (namely, paren matchings) to attach hyperbrackets to.


@deftogether[(
  @defproc[(taffy-notation? [v any/c]) boolean?]
  @defproc[(taffy-notation-impl? [v any/c]) boolean?]
  @defthing[
    prop:taffy-notation
    (struct-type-property/c taffy-notation-impl?)
  ]
)]{
  Structure type property operations for @tech{hyperbracket} notation keywords. Every macro that needs to be recognized as part of the hyperbracket notation by a hyperbracket parser should implement this property. That way, non-hyperbracket identifiers can be recognized as such, thus allowing hyperbrackets to coexist with existing Racket notations without the risk of making the user's intent ambiguous.
  
  A structure type that implements this property should generally also implement @racket[prop:procedure] to display an informative error message when the notation is used in a position where a Racket expression is expected.
}

@defproc[
  (make-taffy-notation-impl)
  taffy-notation-impl?
]{
  Returns something a struct can use to implement the @racket[prop:taffy-notation] interface.
}

@deftogether[(
  @defproc[(taffy-notation-akin-to-^<>d? [v any/c]) boolean?]
  @defproc[(taffy-notation-akin-to-^<>d-impl? [v any/c]) boolean?]
  @defthing[
    prop:taffy-notation-akin-to-^<>d
    (struct-type-property/c taffy-notation-akin-to-^<>d-impl?)
  ]
)]{
  Structure type property operations for @tech{hyperbracket} keywords that behave similarly to @racket[^<d], @racket[^>d], @racket[^<], or @racket[^>] when invoked in prefix position.
  
  A structure type that implements this property should generally also implement @racket[prop:taffy-notation] to signify the fact that it's a hyperbracket notation.
  
  A structure type that implements this property should generally also implement @racket[prop:procedure] to display an informative error message when the notation is used in a position where a Racket expression is expected.
}

@defproc[
  (taffy-notation-akin-to-^<>d-parse
    [op taffy-notation-akin-to-^<>d?]
    [stx syntax?])
  (and/c hash? immutable? hash-equal-always?
    (hash/dc
      [ _k
        (or/c
          'lexical-context
          'direction
          'degree
          'contents
          'token-of-syntax)]
      [ _ (_k)
        (match _k
          ['lexical-context identifier?]
          ['direction (or/c '< '>)]
          ['degree (syntax/c natural?)]
          ['contents (listof syntax?)]
          [ 'token-of-syntax
            (token-of-syntax-with-free-vars<=/c
              (setalw 'lexical-context 'degree 'contents))])]))
]{
  Uses the given @racket[taffy-notation-akin-to-^<>d?] instance to parse the given syntax term. The term should be a syntax list which begins with an identifier that's bound to the given notation.
  
  The result is an @racket[equal-always?]-based hash that represents several components parsed from the term:
  
  @specform['lexical-context]{
    An identifier that may refer to certain information Punctaffy needs to keep track of about the @tech{hyperbracket}-nesting depth that this @tech{hyperbracket} interacts with. Currently, this identifier is not actually used (TODO), but we intend to use this identifier's lexical information to prevent a macro call's macro-introduced uses of hyperstacks from interacting unintentionally with the macro caller's uses of hyperbrackets. A hyperbracket-nesting depth is more than a number and will likely be represented by a @tech{hyperstack}, possibly together with information about variables that are in scope at the various depths.
    
    Hyperbracket notations implementing this method may differ about how they determine the @racket['lexical-context] identifier, but when the user doesn't specify it explicitly in the hyperbracket's syntax, the usual default will be an identifier whose name is the symbol @racket['#%lexical-context] and whose lexical information matches that of @racket[stx].
  }
  
  @specform['direction]{
    A representation of whether this call site of this notation represents an opening hyperbracket or a closing hyperbracket. If it's an opening hyperbracket like @racket[^<d] or @racket[^<], this is the symbol @racket['<]. Otherwise, it's a closing hyperbracket like @racket[^>d] or @racket[^>], and this is the symbol @racket['>].
  }
  
  @specform['degree]{
    A syntax object containing a @racket[natural?] number, representing the @tech{degree} of the @tech{hyperbracket}. This corresponds to the degree the user would specify explicitly when using @racket[^<d] or @racket[^>d].
  }
  
  @specform['contents]{
    A list of syntax objects. This @tech{hyperbracket} usage site only takes up some outermost part of @racket[stx], and some unconsumed region of syntax remains beyond that, which is what this represents.
    
    If this use site is an opening hyperbracket, this remaining syntax begins inside it, but it may contain its own closing hyperbrackets that continue into syntax that's outside again. If this use site is a closing bracket, this remaining syntax begins outside it, but it may contain closing hyperbrackets that close this one and continue into syntax that's inside again. Calling it the "contents" is somewhat of a misnomer. (TODO: Rename @racket['contents] to use a term like "tail," "rest," "beyond," or "remainder" instead, ideally referring to its role as a piece of the given @racket[stx] rather than a piece of the hyperbracket we parsed out.)
  }
  
  @specform['token-of-syntax]{
    A @tech{token of syntax} value representing the concrete syntax of the @tech{hyperbracket} usage site itself, possibly separated from the specific values of @racket['lexical-context], @racket['degree], and @racket['contents] so that these can be replaced with new values.
    
    The token may have free variables named @racket['lexical-context], @racket['degree], and @racket['contents]. If the token is converted to a list of trees using @racket[token-of-syntax->syntax-list], it should result in a single tree that closely resembles @racket[stx], particularly if the free variables are substituted with the corresponding information that this method call parsed out.
    
    Specifically, since the substitution takes lists of syntax as input, the @racket['lexical-context] and @racket['degree] parts of the parsed hash need to be wrapped in singleton lists to perform the substitution that most faithfully reproduces @racket[stx]. The @racket['contents] part of the parsed hash is already a list and can be substituted in without wrapping it.
    
    The reason this @racket['token-of-syntax] entry exists in the parse result is to support usage scenarios that involve parsing a program, transforming parts of it, and reconstructing it with the new parts. For instance, @racket[taffy-quote] uses this so that it can process interpolated expressions without disrupting the syntax of hyperbrackets that appear in the quoted region of code.
  }
}

@defproc[
  (make-taffy-notation-akin-to-^<>d-impl
    [parse
      (-> syntax?
        (and/c hash? immutable? hash-equal-always?
          (hash/dc
            [ _k
              (or/c
                'lexical-context
                'direction
                'degree
                'contents
                'token-of-syntax)]
            [ _ (_k)
              (match _k
                ['lexical-context identifier?]
                ['direction (or/c '< '>)]
                ['degree (syntax/c natural?)]
                ['contents (listof syntax?)]
                [ 'token-of-syntax
                  (token-of-syntax-with-free-vars<=/c
                    (setalw
                      'lexical-context
                      'degree
                      'contents))])])))])
  taffy-notation-akin-to-^<>d-impl?
]{
  Given an implementation for @racket[taffy-notation-akin-to-^<>d-parse], returns something a struct can use to implement the @racket[prop:taffy-notation-akin-to-^<>d] interface.
}

@defproc[
  (makeshift-taffy-notation-akin-to-^<>d
    [parse
      (-> syntax?
        (and/c hash? immutable? hash-equal-always?
          (hash/dc
            [ _k
              (or/c
                'lexical-context
                'direction
                'degree
                'contents
                'token-of-syntax)]
            [ _ (_k)
              (match _k
                ['lexical-context identifier?]
                ['direction (or/c '< '>)]
                ['degree (syntax/c natural?)]
                ['contents (listof syntax?)]
                [ 'token-of-syntax
                  (token-of-syntax-with-free-vars<=/c
                    (setalw
                      'lexical-context
                      'degree
                      'contents))])])))])
  (and/c procedure? taffy-notation? taffy-notation-akin-to-^<>d?)
]{
  Given an implementation for @racket[taffy-notation-akin-to-^<>d-parse], returns a macro implementation value that can be used with @racket[define-syntax] to define a prefix @tech{hyperbracket} notation similar to @racket[^<d], @racket[^>d], @racket[^<], or @racket[^>].
}
