#lang parendown scribble/manual

@; punctaffy/scribblings/punctaffy/baseline-hyperbracket.scrbl
@;
@; Baseline hyperbracket notations.

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


@title[#:tag "baseline-notations"]{Baseline Punctaffy Hyperbracket Notations}

@defmodule[punctaffy]

Punctaffy is a framework for macros to have access to higher-dimensional structure in the code they operate on. Just as parentheses give more structure to 1-dimensional text streams to create s-expressions (or Racket syntax objects), @tech{hyperbrackets} can give more structure to Racket syntax objects to create infinite-dimensional higher-order nesting structure.

Most programs will use only a few of the lower dimensions. For instance, quasiquotation is an operation that works with a 2-dimensional snippet (what we call a @tech{hypersnippet}) of literal code and several 1-dimensional expressions that will be interpolated into it. All it takes is 3-dimensional syntactic medium to represent any number of nested and juxtaposed 2-dimensional quasiquotation operations, just as all it takes is a 2-dimensional syntactic medium (s-expressions) to represent any nesting or juxtaposition of 1-dimensional function calls.

Punctaffy's notation represents an infinite-dimensional syntactic medium. The goal of Punctaffy is to assist in defining higher-dimensional operations that play nicely with each other by building common tools and notations for them to build on. Punctaffy's notation generalizes far enough to be a common medium for notations of arbitrarily high dimension.

Punctaffy's main module, @racket[punctaffy], provides the hyperbracket notation itself, which just about every higher-dimensional macro built on Punctaffy will use.

Whether a certain notation uses Punctaffy's hyperbrackets or not, if it has a straightforward analogue as an operaton that uses hyperbrackets, we call it a @deftech{hyperbracketed} operation. We refer to code where hyperbrackets can appear as @deftech{hyperbracketed code}.


@defform[(^<d degree term ...)]{
  A @tech{hyperbracket} notation that represents an opening hyperbracket with a specified nonzero @tech{degree}. The degree must be a natural number literal.
  
  Using this notation as an expression is a syntax error. In the future, this error may be replaced with @racket[#%app]-like functionality.
  
  When writing a hyperbracket parser, this notation can be recognized using @racket[hyperbracket-open-with-degree?].
  
  For the common case where @racket[degree] is 2, see the shorthand @racket[^<], which has examples in @secref["intro"]. For a rare example of hypothetical code where @racket[degree] would be 3, see @secref["potential-use-case-ellipsis-unsyntax"].
}

@defform[(^>d degree term ...)]{
  A @tech{hyperbracket} notation that represents a closing hyperbracket with a specified nonzero @tech{degree}. The degree must be a natural number literal.
  
  This notation is not an expression. Using it as an expression is a syntax error.
  
  When writing a hyperbracket parser, this notation can be recognized using @racket[hyperbracket-close-with-degree?].
  
  For the common case where @racket[degree] is 1, see the shorthand @racket[^>], which has examples in @secref["intro"]. For a rare example of hypothetical code where @racket[degree] would be 2, see @secref["potential-use-case-ellipsis-unsyntax"].
}

@defform[(^< term ...)]{
  A @tech{hyperbracket} notation shorthand that specifically represents an opening hyperbracket of @tech{degree} 2. This is the lowest, and hence the most likely to be commonplace, degree of opening bracket that isn't already easy to represent in Racket's syntax.
  
  This represents the same thing as @racket[(^<d 2 term ...)].
  
  Note that while @tt{^<} involves a degree of 2, @racket[^>] involves a degree of 1. This may seem confusing out of context, but these two often match up with each other.
  
  Using this notation as an expression is a syntax error. In the future, this error may be replaced with @racket[#%app]-like functionality.
  
  For examples of how to use @racket[^<] and @racket[^>], see @secref["intro"].
}

@defform[(^> term ...)]{
  A @tech{hyperbracket} notation shorthand that specifically represents a closing hyperbracket of @tech{degree} 1. This is the lowest, and hence the most likely to be commonplace, degree of closing bracket that isn't already easy to represent in Racket's syntax.
  
  This represents the same thing as @racket[(^>d 1 term ...)].
  
  Note that while @tt{^>} involves a degree of 1, @racket[^<] involves a degree of 2. This may seem confusing out of context, but these two often match up with each other.
  
  This notation is not an expression. Using it as an expression is a syntax error.
  
  For examples of how to use @racket[^<] and @racket[^>], see @secref["intro"].
}
