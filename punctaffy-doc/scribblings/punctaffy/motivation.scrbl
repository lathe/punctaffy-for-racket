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



@local-table-of-contents[]



@section[#:tag "existing-use-cases"]{Hyperbracketed Notations Predating Punctaffy}

@itemlist[
  
  @item{Trivially, hyperbrackets of low degree are hyperbrackets too: If we find ourselves in a context where a program is usually just a "sequence of instructions," then a structured @tt{while} loop is a degree-1-hyperbracketed operation. (An instruction by itself is a degree-0-hyperbracketed operation.) If we learn lessons about hygienic macro system design at higher degrees, there's a good chance they can be extrapolated downward to tell us something about s-expression macros (degree 1) and reader macros (degree 0).}
  
  @item{The @racket[quasiquote] or @tt{backquote} operation is probably the most widespread example. Moreover, string interpolation is even more widespread, and it's basically quasiquotation for text-based code.}
  
  @item{The "apply-to-all" notation @tt{α(f •xs)} from Connection Machine Lisp (CM-Lisp) applies the same operation @tt{(f _)} to every element of a xapping @tt{xs} (where a xapping is a certain type of multiple-element collection). Pages 280-281 of @hyperlink["https://web.archive.org/web/20060219230046/http://fresh.homeunix.net/~luke/misc/ConnectionMachineLisp.pdf"]{"Connection Machine Lisp" by Guy Steele} go into detail on the functionality and motivation of this operation.}
  
  @item{Shadow DOM is an HTML feature which allows templates to be defined and instantiated. A template can have slots in it, which can have default content specified inside (in case the slot isn't filled at the instantiation site). The template looks like @tt{<template>...<slot name="x">...</slot>...</template>}, where the @tt{...} inside the @tt{<slot>} element is the degree-1 hypersnippet of default content for the slot, the slot's @tt{name} attribute identifies the slot when overriding it at the instantiation site, and the rest of the template is the degree-2 hypersnippet of content that doesn't vary.}
  
  @item{In a @hyperlink["https://www.youtube.com/watch?v=dCuZkaaou0Q"]{2017 invited talk at Clojure/Conj}, Guy Steele talks about the inconsistency of computer science notation. At 53m03s, he goes into detail about a combination underline/overline notation he proposes as a way to bring more rigor to schematic formulas which iterate over vectors. He compares it to quasiquotation and the CM-Lisp @tt{α} notation.}
  
]

None of these existing examples involves a hypersnippet of degree 3 or greater. So, aside from the trivial degree-0 and degree-1 examples, all the examples above have degree 2.



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



@subsection[#:tag "potential-use-case-call-stacks"]{Potential Application: Abstraction-Respecting Call Stacks}

When using higher-order functional programming techniques, the call stack can sometimes be cluttered with the implementation details of higher-order functions.

For instance, if @racket[filter] were implemented in terms of @racket[append-map], then call stacks observed during the execution of the @racket[filter] predicate might look like:

@code-block{
  ...
  <filter-callback>
  <append-map-callback>
  append-map
  filter
  ...
}

But this may be too much information if someone's not trying to debug the @racket[filter] function itself. If @racket[filter] were implemented in a more direct way, the call stack would only show:

@code-block{
  ...
  <filter-callback>
  filter
  ...
}

If call stacks were @tech{hyperstacks}, then the @racket[filter] and @racket[append-map] calls could be degree-2 hyperstack frames, essentially giving the call stack a nested structure:

@code-block{
  ...
  {
    {
    } append-map
  } filter
  ...
}

With tools built on this infrastructure, the user could view the stack in as much or as little detail as they'd like, using UI toggles or a verbosity-controlling stylesheet to collapse and expand sections of interest.



@subsection[#:tag "potential-use-case-ellipsis-unsyntax"]{Potential Application: Interactions Between @racket[unsyntax] and Ellipses}

In @secref["intro"], we talk about the relationship between hypersnippets and Racket's @racket[syntax] DSL for syntax templates (or, more specifically, its @racket[datum] DSL for s-expression templates).

The @racket[quasisyntax] form (abbreviated @tt{#@literal{`}}) introduces the quasiquotation-like ability to use @racket[unsyntax] and @racket[unsyntax-splicing] (abbreviated @tt{#,} and @tt{#,@"@"}) to interpolate arbitrary expression results into a template.

There's a noticeable missed opportunity in the current design of the DSL, and it has to do with how these interpolated expressions interact with ellipses (@racket[...]). Usually, ellipses iterate the template they apply to, and template variables have an associated ellipsis depth that specifies how many dimensions of nested iteration they should undergo (usually because they were created by matching a @racket[syntax-parse] or @racket[syntax-case] template with the same number of nested ellipses).

However, expressions interpolated with @racket[unsyntax] don't have any ellipsis depth information. Even if they contain another @racket[syntax] or @racket[quasisyntax] call inside, the variables in that second call can't interact with the ellipses in the first call. For insatnce, the following doesn't work, because @racket[_pat] and @racket[_val] only occur in the template @racket[#'(_pat _val)], not in the template that has the ellipsis:

@RACKETBLOCK[
  (define-syntax (match-let/derived _stx)
    (syntax-parse _stx
      [(_ _orig-stx ([_pat _val] ...) _body ...)
       (syntax-protect
         #`(let ()
             #,(datum->syntax
                 #f
                 `(,#'match-define ,@#'(_pat _val))
                 #'_orig-stx)
             ...
             (let ()
               _body
               ...)))]))
]

(TODO: See if we can make this a better example. The idea here is that the macro defines something like a cross between @racket[match/derived] and @racket[match-let], and it manipulates the call to @racket[match-define] to insert the source location of the given term to help with accurate error-reporting. However, we haven't tested that this manipulation would actually improve the error-reporting this way, and using the actual @racket[match/derived] would likely be a better idea than trying to make @racket[match-define] work just right.)

Incidentally, the @racket[syntax] DSL already has an experimental feature that caters to this situation: template metafunctions. A template metafunction can run arbitrary code during the iteration of a template:

@racketblock[
  (define-syntax (match-let/derived _stx)
    (syntax-parse _stx
      [(_ _orig-stx ([_pat _val] ...) _body ...)
       
       (define-template-metafunction (_reattributed-match-define _stx)
         (syntax-parse _stx
           [(_ _pat _val)
            (datum->syntax
              #f
              `(,#'match-define ,@#'(_pat _val))
              #'_orig-stx)]))
       
       (syntax-protect
         #'(let ()
             (_reattributed-match-define _pat _val)
             ...
             (let ()
               _body
               ...)))]))
]

However, using @racket[define-template-metafunction] substantially rearranges the code. That can be good in cases like this one, where the concept can be associated with a simple name and interface. On the other hand, @racket[unsyntax] comes in handy in situations where the code's navigability benefits from having some structural resemblance to the results it produces, or in situations where multiple DSLs have synergy together but haven't yet been fused into a single monolithic DSL.

If for some reason we have a strong preference to arrange this code in the @racket[unsyntax] style, then what we really need here is for @racket[#'(_pat _val)] not to be a @emph{new} template but a @emph{resumption} of the original syntax. We need some kind of @tt{un-unsyntax}, perhaps abbreviated @tt{#,!}. Then we could replace @racket[#'(_pat _val)] with @tt{#,!}@racket[(_pat _val)] and be on our way.

The concept of @tt{un-unsyntax} fits neatly into the hypersnippet concept we explore in Punctaffy. We can consider @racket[quasisyntax] to be opening a degree-3 hypersnippet, @racket[unsyntax] to be opening a degree-2 hole in that hypersnippet, and @tt{un-unsyntax} to be opening a degree-1 hole in that degree-2 hole.

Punctaffy currently defines a @racket[taffy-quote-syntax] operation, but it corresponds to @racket[quote-syntax] rather than the @racket[syntax] template DSL. Suppose Punctaffy were to define a @tt{taffy-syntax} operation in that combined spirit, which used @seclink["baseline-notations"]{Punctaffy's baseline hyperbrackets} and had support for @racket[syntax] DSL features like ellipses. Using that operation, the above code could look like this:

@racketblock[
  (define-syntax (match-let/derived _stx)
    (syntax-parse _stx
      [(_ _orig-stx ([_pat _val] ...) _body ...)
       (syntax-protect
         (taffy-syntax
           (^<d 3
             (let ()
               (^>d 2
                 (list
                   (datum->syntax
                     #f
                     `(,#'match-define ,@(^> (_pat _val)))
                     #'_orig-stx)))
               ...
               (let ()
                 _body
                 ...)))))]))
]

This may be the one example we have where a degree-3 hypersnippet would come in handy for a purpose that specifically calls for it. Most of the things we say about hypersnippets of degree 3 would make just as much sense at degree 4, 5, etc., so this may be a rare example.

On the other hand, the basic principle of this example is that we want two different invocations of an embedded DSL to be part of the same "whole program" to allow some nonlocal interaction between them. The nonlocal interactions here aren't too exotic; they're basically lexically scoped variables (with ellipses acting as the binding sites). Other embedded DSLs with lexically scoped interactions may similarly benefit from degree-3 hyperbrackets.



@; TODO: Consider writing a "Potential Application" section about one of the original (and ongoing) motivating goals of Punctaffy: The ability to have custom escape sequences in a quotation DSL that are suppressed if the quotation DSL appears inside itself. The "suppressed" behavior of a custom escape sequence conveys nothing but what part of the input is consumed, which is the same part that's consumed when it's not suppressed. When it's not suppressed, it additionally specifies what quoted content that input transforms into.

@; TODO: Consider writing another "Potential Application" section related to the @racket[syntax] DSL, with the focus being this: If we change the reader to read hyperbracketed code instead of s-expressions (and change @racket[syntax-protect], the sets-of-scopes hygiene model, and the syntax property @racket[cons]-collecting logic, and the quotation operators to go along with this change), then we won't have to worry about reporting errors for unbound hyperbracket notations. Currently with Punctaffy's baseline notations, if the programmer neglects to import a certain notation or shadows its binding, then it'll silently be treated as an identifier in the code rather than as a hyperbracket. This problem exists for Racket's @racket[quasiquote] and @racket[unquote] and @racket[quasisyntax] and @racket[unsyntax], too.



@subsection[#:tag "potential-use-case-opetopes"]{Potential Application: Representing Opetopes}

The slide deck @hyperlink["https://ncatlab.org/nlab/files/FinsterTypesAndOpetopes2012.pdf"]{"Type Theory and the Opetopes" by Eric Finster} gives a nice graphical overview of opetopes as they're used in opetopic higher category theory and opetopic type theory. One slide mentions an inductive type @tt{MTree} of labeled opetopes, which more or less corresponds to Punctaffy's hypertee type. To our knowledge, hyperbracketed notations have not been used in this context before, but they should be a good fit.



@subsection[#:tag "potential-use-case-transpension"]{Potential Application: Type Theories with Transpension}

The paper @hyperlink["https://arxiv.org/pdf/2008.08533.pdf"]{"Transpension: The Right Adjoint to the Pi-type" by Andreas Nuyts and Dominique Devriese} discusses several type theories that have operations that we might hope to connect with what Punctaffy is doing. Transpension appears to be making use of degree-2 hypersnippets in its syntax.

Essentially (and if we understand correctly), a transpension operation declares a variable that represents some unknown coordinate along a new dimension. At some point in the scope of that dimension variable, another operation takes ownership of it, taking the original dimension variable and all the variables that depended on it since then out of scope, but replacing the latter with reusable functions that can be applied repeatedly to different coordinate values of the user's choice.

From a Punctaffy perspective, the dimension variable's original scope is a degree-2 hypersnippet, and the operation that takes it out of scope (and converts other variables to functions) is located at one of the degree-1 closing hyperbrackets of that hypersnippet.

Curiously, the degree-2 hypersnippet also gets closed by degree-1 closing hyperbrackets at the @emph{type} level; we might say these type theories assign types to terms that have unmatched closing hyperbrackets. They also have lambdas that @emph{abstract over} terms that have unmatched closing hyperbrackets, so the journey of a closing hyperbracket through the codebase to find its match can potentially be rather circuitous.

At any rate, these dimension variables have affine (use-at-most-once) types, which can sometimes seem odd in the context of a type theory where the rest of the variables are Cartesian (use-any-number-of-times). By relating transpension operators to hyperbrackets, we may give the affine typing situation some more clarity: A "closing bracket" can't match up with an "opening bracket" that's already been closed.

And conversely, by relating the two, we may find techniques for understanding Punctaffy's hyperbrackets in terms of affine variables in a type theory rather than the other way around. This kind of insight may come in handy for studying the categorical semantics of a calculus that has hyperbracketed operations, or even for implementing hyperbracket libraries like Punctaffy for typed languages.
