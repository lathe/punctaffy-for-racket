#lang parendown scribble/manual

@; punctaffy/scribblings/punctaffy/motivation.scrbl
@;
@; Discussion of Punctaffy's high-level motivations.

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


@title[#:tag "motivation"]{Motivation for Punctaffy}



@section[#:tag "existing-use-cases"]{Hyperbracketed Notations Predating Punctaffy}

@itemlist[
  
  @item{Trivially, hyperbrackets of low degree are hyperbrackets too: If we find ourselves in a context where a program is usually just a "sequence of instructions," then a structured @tt{while} loop is a degree-1-hyperbracketed operation. (An instruction by itself is a degree-0-hyperbracketed operation.) If we learn lessons about hygienic macro system design at higher degrees, there's a good chance they can be extrapolated downward to tell us something about s-expression macros (degree 1) and reader macros (degree 0).}
  
  @item{The @racket[quasiquote] or @tt{backquote} operation is probably the most widespread example. Moreover, string interpolation is even more widespread, and it's basically quasiquotation for text-based code.}
  
  @item{The "apply-to-all" notation @tt{α(f •xs)} from Connection Machine Lisp (CM-Lisp) applies the same operation @tt{(f _)} to every element of a xapping @tt{xs} (where a xapping is a certain type of multiple-element collection). Pages 280-281 of @hyperlink["https://web.archive.org/web/20060219230046/http://fresh.homeunix.net/~luke/misc/ConnectionMachineLisp.pdf"]{"Connection Machine Lisp" by Guy Steele} go into detail on the functionality and motivation of this operation.}
  
  @item{In a @hyperlink["https://www.youtube.com/watch?v=dCuZkaaou0Q"]{2017 invited talk at Clojure/Conj}, Guy Steele talks about the inconsistency of computer science notation. At 53m03s, he goes into detail about a combination underline/overline notation he proposes as a way to bring more rigor to schematic formulas which iterate over vectors. He compares it to quasiquotation and the CM-Lisp @tt{α} notation.}
  
]



@section[#:tag "potential-use-cases"]{Potential Application Areas}



@subsection[#:tag "potential-use-case-hygiene"]{Potential Application: Hygiene}

Hygienic macroexpansion usually generates code where certain variables are only in scope across some degree-2 hypersnippet of the code.

For instance, Racket first colors all the input subforms of a macro call using a new scope tag, and then it inverts that color in the result so that the color winds up only occurring on the code the macro generates itself, not the code it merely passes through.

Racket's strategy works, but it relies on the generation of unique tags and the creation of invisible annotations throughout the generated code.

If we were to approach hygiene by using explicit hypersnippets instead, it might lead to more straightforward or less error-prone implementations of macro hygiene. If enough people find it convenient enough to do structural recursion over nested hypersnippets, then they may find this skill lets them easily keep a lid on the local details of each hypersnippet, just as traditional forms of structural recursion make it easy to keep the details of one branch of a tree data structure from interfering with unrelated branches.

@; TODO: Consider using the following explanation somewhere. We once had it in the Punctaffy documentation's opening blurb.

@;{

So how does this make any sense? We can think of the macro bodies as being @emph{more deeply nested}, despite the fact that the code they interpolate still appears in a nested position as far as the tree structure of the code is concerned. In this sense, the tree structure is not the full story of the nesting of the code.

This is a matter of @emph{dimension}, and we can find an analogous situation one dimension down: The content between two parentheses is typically regarded as further into the traversal of the tree structure of the code, despite the fact that the content following the closing parenthesis is still further into the traversal of the code's text stream structure. The text stream is not the full story of how the code is meant to be traversed.

}


@subsection[#:tag "potential-use-case-incremental-compilation"]{Potential Application: Incremental Compilation}

In a language like Racket where programmers can write arbitrarily complex custom syntaxes, compilation can be expensive. This can drag down the experience of editing code the DrRacket IDE, where features like jump-to-definition can depend on performing background expansion to process the user's custom syntaxes.

If macros weren't tree-to-tree transformations, but instead consumed only some small part of the tree and generated a degree-2 hypersnippet, then a modification of one local part of a file could lead to a pinpoint re-expansion of the specific macro call that processed that part of the file, rather than a costly re-expansion of every macro call in the whole file.

Incidentally, this would bring s-expression macro calls into a closer analogy with reader macro calls, which themselves consume some bounded part of the source text stream and generate an s-expression.



@subsection[#:tag "potential-use-case-opetopes"]{Potential Application: Representing Opetopes}

The slide deck @hyperlink["https://ncatlab.org/nlab/files/FinsterTypesAndOpetopes2012.pdf"]{"Type Theory and the Opetopes" by Eric Finster} gives a nice graphical overview of opetopes as they're used in opetopic higher category theory and opetopic type theory. One slide mentions an inductive type @tt{MTree} of labeled opetopes, which more or less corresponds to Punctaffy's hypertee type. To our knowledge, hyperbracketed notations have not been used in this context before, but they should be a good fit.



@subsection[#:tag "potential-use-case-transpension"]{Potential Application: Type Theories with Transpension}

The paper @hyperlink["https://arxiv.org/pdf/2008.08533.pdf"]{"Transpension: The Right Adjoint to the Pi-type" by Andreas Nuyts and Dominique Devriese} discusses several type theories that have operations that we might hope to connect with what Punctaffy is doing. Transpension appears to be making use of degree-2 hypersnippets in its syntax.

Essentially (and if we understand correctly), a transpension operation declares a variable that represents some unknown coordinate along a new dimension. At some point in the scope of that dimension variable, another operation takes ownership of it, taking the original dimension variable and all the variables that depended on it since then out of scope, but replacing the latter with reusable functions that can be applied repeatedly to different coordinate values of the user's choice.

From a Punctaffy perspective, the dimension variable's original scope is a degree-2 hypersnippet, and the operation that takes it out of scope (and converts other variables to functions) is one of the degree-1 closing hyperbrackets of that hypersnippet.

Curiously, the degree-2 hypersnippet also gets closed by degree-1 closing hyperbrackets at the @emph{type} level; we might say these type theories assign types to terms that have unmatched closing hyperbrackets. They also have lambdas that @emph{abstract over} terms that have unmatched closing hyperbrackets, so the journey of a closing hyperbracket through the codebase to find its match can potentially be rather circuitous.

At any rate, these dimension variables have affine (use-at-most-once) types, which can sometimes seem odd in the context of a type theory where the rest of the variables are Cartesian (use-any-number-of-times). By relating transpension operators to hyperbrackets, we may give the affine typing situation some more clarity: A "closing bracket" can't match up with an "opening bracket" that's already been closed.
