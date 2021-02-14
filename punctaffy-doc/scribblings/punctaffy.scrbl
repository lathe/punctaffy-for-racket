#lang parendown scribble/manual

@; punctaffy/scribblings/punctaffy.scrbl
@;
@; A library implementing and exploring hypersnippets, a
@; higher-dimensional generalization of syntax with holes.

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


@title{Punctaffy}

Punctaffy is an experimental library for working with a higher-dimensional notion of lexical syntactic structure. We call these generalized lexical regions @tech{hypersnippets}, we delimit them using @tech{hyperbrackets}, and we call our generalized s-expressions "hyperbracketed code."

For a gradual introduction to 2-dimensional hypersnippets, see @secref["intro"]. Basically, Punctaffy embraces the analogy sometimes drawn between parentheses @tt{( )} and the notation of quasiquotation @tt{@literal{`}( ,( ) )} and generalizes these as the 1-dimensional and 2-dimensional instances of a concept that can be instantiated at any dimension and used for various purposes aside from quotation.

The geometric shapes of hypersnippets don't appear to be new; they seem to coincide with the opetopes of opetopic higher category theory.

For practical use, Punctaffy's main drawback is the amount of time it takes to compile hyperbracketed programs---even the simplest ones. This is something that can be improved over time. For now, Punctaffy serves mainly as a proof of concept.

@; TODO: If Punctaffy ever overcomes its performance issues, stop discussing them here.



@table-of-contents[]



@include-section["punctaffy/intro.scrbl"]
@include-section["punctaffy/hypersnippet.scrbl"]
@include-section["punctaffy/hyperbracket.scrbl"]
@include-section["punctaffy/hyperbracketed-util.scrbl"]
