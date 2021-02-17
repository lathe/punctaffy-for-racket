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
  
  @item{Trivially, @tech{hyperbrackets} of low @tech{degree} are hyperbrackets too: If we find ourselves in a context where a program is usually just a "sequence of instructions," then a structured @tt{while} loop is a degree-1-@tech{hyperbracketed} operation. (An instruction by itself is a degree-0-hyperbracketed operation.) If we learn lessons about hygienic macro system design at higher degrees, there's a good chance they can be extrapolated downward to tell us something about s-expression macros (degree 1) and reader macros (degree 0).}
  
  @item{The @racket[quasiquote] or @tt{backquote} operation is probably the most widespread example. Moreover, string interpolation is even more widespread, and it's basically quasiquotation for text-based code.}
  
  @item{The "apply-to-all" notation @tt{α(f •xs)} from Connection Machine Lisp (CM-Lisp) applies the same operation @tt{(f _)} to every element of a xapping @tt{xs} (where a xapping is a certain type of multiple-element collection). Pages 280-281 of @hyperlink["https://web.archive.org/web/20060219230046/http://fresh.homeunix.net/~luke/misc/ConnectionMachineLisp.pdf"]{"Connection Machine Lisp" by Guy Steele} go into detail on the functionality and motivation of this operation.}
  
  @item{Shadow DOM is an HTML feature which allows templates to be defined and instantiated. A template can have slots in it, which can have default content specified inside (in case the slot isn't filled at the instantiation site). The template looks like @tt{<template>...<slot name="x">...</slot>...</template>}, where the @tt{...} inside the @tt{<slot>} element is the @tech{degree}-1 @tech{hypersnippet} of default content for the slot, the slot's @tt{name} attribute identifies the slot when overriding it at the instantiation site, and the rest of the template is the degree-2 hypersnippet of content that doesn't vary.}
  
  @item{In a @hyperlink["https://www.youtube.com/watch?v=dCuZkaaou0Q"]{2017 invited talk at Clojure/Conj}, Guy Steele talks about the inconsistency of computer science notation. At 53m03s, he goes into detail about a combination underline/overline notation he proposes as a way to bring more rigor to schematic formulas which iterate over vectors. He compares it to quasiquotation and the CM-Lisp @tt{α} notation.}
  
]

None of these existing examples involves a @tech{hypersnippet} of @tech{degree} 3 or greater. So, aside from the trivial degree-0 and degree-1 examples, all the examples above have degree 2.



@section[#:tag "potential-use-cases"]{Potential Application Areas}



@subsection[#:tag "potential-use-case-hygiene"]{Potential Application: Hygiene}

Hygienic macroexpansion usually generates code where certain variables are only in scope across some @tech{degree}-2 @tech{hypersnippet} of the code.

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

If macros weren't tree-to-tree transformations, but instead consumed only some small part of the tree and generated a @tech{degree}-2 @tech{hypersnippet}, then a modification of one local part of a file could lead to a pinpoint re-expansion of the specific macro call that processed that part of the file, rather than a costly re-expansion of every macro call in the whole file.

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

If call stacks were @tech{hyperstacks}, then the @racket[filter] and @racket[append-map] calls could be @tech{degree}-2 hyperstack frames, essentially giving the call stack a nested structure:

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

In @secref["intro"], we talk about the relationship between @tech{hypersnippets} and Racket's @racket[syntax] DSL for syntax templates (or, more specifically, its @racket[datum] DSL for s-expression templates).

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

The concept of @tt{un-unsyntax} fits neatly into the hypersnippet concept we explore in Punctaffy. We can consider @racket[quasisyntax] to be opening a @tech{degree}-3 hypersnippet, @racket[unsyntax] to be opening a degree-2 @tech{hole} in that hypersnippet, and @tt{un-unsyntax} to be opening a degree-1 hole in that degree-2 hole.

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

This seems to be a rare example of where a degree-3 hypersnippet specifically would come in handy. Most of the things we say about hypersnippets of degree 3 aren't so specific; they would make just as much sense at degree 4, 5, etc.

This example seems like an instance of a pattern, though: The basic principle of this example is that we want two different invocations of an embedded DSL to be part of the same "whole program" to allow some nonlocal interaction between them. The nonlocal interactions here aren't too exotic; they're basically lexically scoped variables, with ellipses acting as the binding sites.

Other embedded DSLs with lexically scoped interactions, such as type inference and type-directed elaboration, may similarly benefit from degree-3 lexical structure.



@; TODO: Consider writing another "Potential Application" section related to the @racket[syntax] DSL, with the focus being this: If we change the reader to read hyperbracketed code instead of s-expressions (and change @racket[syntax-protect], the sets-of-scopes hygiene model, and the syntax property @racket[cons]-collecting logic, and the quotation operators to go along with this change), then we won't have to worry about reporting errors for unbound hyperbracket notations. Currently with Punctaffy's baseline notations, if the programmer neglects to import a certain notation or shadows its binding, then it'll silently be treated as an identifier in the code rather than as a hyperbracket. This problem exists for Racket's @racket[quasiquote] and @racket[unquote] and @racket[quasisyntax] and @racket[unsyntax], too.



@subsection[#:tag "potential-use-case-opetopes"]{Potential Application: Representing Opetopes}

The slide deck @hyperlink["https://ncatlab.org/nlab/files/FinsterTypesAndOpetopes2012.pdf"]{"Type Theory and the Opetopes" by Eric Finster} gives a nice graphical overview of opetopes as they're used in opetopic higher category theory and opetopic type theory. One slide mentions an inductive type @tt{MTree} of labeled opetopes, which more or less corresponds to Punctaffy's @tech{hypertee} data structure. To our knowledge, @tech{hyperbracketed} notations have not been used in this context before, but they should be a good fit.



@subsection[#:tag "potential-use-case-transpension"]{Potential Application: Type Theories with Transpension}

The paper @hyperlink["https://arxiv.org/pdf/2008.08533.pdf"]{"Transpension: The Right Adjoint to the Pi-type" by Andreas Nuyts and Dominique Devriese} discusses several type theories that have operations that we might hope to connect with what Punctaffy is doing. Transpension appears to be making use of @tech{degree}-2 @tech{hypersnippets} in its syntax.

Essentially (and if we understand correctly), a transpension operation declares a variable that represents some unknown coordinate along a new dimension. At some point in the scope of that dimension variable, another operation takes ownership of it, taking the original dimension variable and all the variables that depended on it since then out of scope, but replacing the latter with reusable functions that can be applied repeatedly to different coordinate values of the user's choice.

From a Punctaffy perspective, the dimension variable's original scope is a degree-2 hypersnippet, and the operation that takes it out of scope (and converts other variables to functions) is located at one of the degree-1 closing @tech{hyperbrackets} of that hypersnippet.

Curiously, the degree-2 hypersnippet also gets closed by degree-1 closing hyperbrackets at the @emph{type} level; we might say these type theories assign types to terms that have unmatched closing hyperbrackets. They also have lambdas that @emph{abstract over} terms that have unmatched closing hyperbrackets, so the journey of a closing hyperbracket through the codebase to find its match can potentially be rather circuitous.

At any rate, these dimension variables have affine (use-at-most-once) types, which can sometimes seem odd in the context of a type theory where the rest of the variables are Cartesian (use-any-number-of-times). By relating transpension operators to hyperbrackets, we may give the affine typing situation some more clarity: A "closing bracket" can't match up with an "opening bracket" that's already been closed.

And conversely, by relating the two, we may find techniques for understanding Punctaffy's hyperbrackets in terms of affine variables in a type theory rather than the other way around. This kind of insight may come in handy for studying the categorical semantics of a calculus that has @tech{hyperbracketed} operations, or even for implementing hyperbracket libraries like Punctaffy for typed languages.



@subsection[#:tag "potential-use-case-custom-escape"]{Potential Application: User-Defined Escapes from Nestable Quotation}

Pairs of @racket[quasiquote] and @racket[unquote] can be seamlessly nested within each other as long as they match up. The situation is less convenient for string literal syntaxes, which typically require nested occurrences to be escaped:

@racketblock[
  (displayln "(displayln \"(displayln \\\"Hello, world!\\\")\")")
]

A rethought design for string syntaxes, using more distinctive string delimiters like @tt{"@"{"} and @tt{@"}""}, can give strings the ability to recognize nested occurrences of @tt{"@"{"} the way @racket[quasiquote] does:

@code-block{
  (displayln "{(displayln "{(displayln "{Hello, world!}")}")}")
}

However, string syntaxes also complicate matters in a way that doesn't come up as often with @racket[quasiquote]: String syntaxes have a wide variety of escape sequences.

In fact, if we take a look at s-expression quotation DSLs other than @racket[quasiquote], this @emph{does} come up: For instance, @racket[syntax] templates have the @racket[...], @racket[~@], and @racket[~?] directives, and @racket[syntax-parse] patterns have a wide variety of directives like @racket[~seq] and @racket[~optional]. Users can even define their own operations like @racket[~seq] and @racket[~optional] by using @racket[prop:pattern-expander]. (And from a certain point of view, most languages are trivial "quotation DSLs" where nothing at all is quoted and every single term is an escape sequence.)

When an escape sequence appears inside multiple layers of quotation, there's an ambiguity issue: Which layer of quotation does it escape from? Should a string escape sequence be processed right away as part of the first string literal, or should it become part of the generated code to be processed as part of the next one (or the one after that)?

While this suggests some ambiguity in the user's intent, there's no corresponding wiggle room in the design. When we consider the point of recognizing nested occurrences in the first place, one design stands out: If we associate escape sequences specifically with the innermost quotation, we can successfully write a string literal the same way whether we're inside or outside another string literal.

That ambiguity in the user's intent does exist, though. Sometimes the user may @emph{intend} to escape from an outer quotation. In that case, they can use a more elaborate notation to specify what layer they have in mind, such as writing @tt{\[LABEL]x20} instead of @tt{\x20}:


@code-block{
  (displayln "[OUTER]{(displayln "{Hello,\[OUTER]x20world!}")}")
}

One implication of this design is that when we process an escape sequence like @tt{\x20}, we might treat it in two different ways depending on context: If it's associated with the outermost stage of quotation, we fully process it, turning @tt{\x20} into a space character. If it's associated with some inner stage of quotation, we suppress it, treating @tt{\x20} as the four characters @tt{\ x 2 0}.

Note that even when we suppress an escape sequence, we still need to @emph{recognize} it to know where it ends. That means in the implementation of even our simplest escape sequences, we'll need a couple of behaviors:

@itemlist[
  
  @item{Process an unbounded input to determine what prefix of it is the escape sequence's bounded input.}
  
  @item{Once we know the bounded input to determine what the interpretation of this escape sequence is (often just some escaped content, but sometimes a more sophisticated behavior like @racket[~optional]).}
  
]

For string escape sequences, expressing the boundary is simple, and the bounded input is some substring of the string literal's code. For instance, in @racket["Hello,\x20world..."], the @tt{x} escape sequence might process the unbounded input @tt{20world...} and determine that its bounded input is @tt{20}. If the escape sequence is being suppressed, then we stop there and treat that bounded input as literal text. Otherwise, we invoke the @tt{x} escape sequence's second step to detemine what it represents (a space character). Either way, we then turn our attention to the rest of the input (@tt{world...}) and process the escape sequences we find there.

Punctaffy's infrastructure starts to come in handy when we apply this design to s-expression escape sequences. There, the bounded input is a @tech{degree}-2 @tech{hypersnippet} of code.

This quotation DSL design---specifically this particular way it leads to degree-2 hypersnippets---is actually the original motivating force behind Punctaffy.

For a couple of other reasons, the infrastructure we need to complete a DSL like this is still not straightorward to build, even with Punctaffy's hypersnippets in our toolkit:

@itemlist[
  
  @item{If we just have @tech{hyperbracketed code}, how do we know which @tech{hyperbrackets} delimit @emph{quoted} sections of code that should suppress our escape sequences? After all, in the examples above, we wouldn't expect the parentheses around the @racket[(displayln _...)] call to be delimiting a quoted section of code, and the same is true of degree-2 hyperbrackets when they're used in the @racket[list-taffy-map] or @racket[taffy-let] operations. We might want to create a slightly more complex analogue of hyperbracketed code where instead of just having an interoperable notation for hyperbracketed lexical structure, we also have interoperable notations for quotation boundaries and escape sequences.}
  
  @item{
    One of the techniques we mention above is to use @tt{\[LABEL]x20} as a way to specify which quotation stage the escape sequence @tt{\x20} should be processed in. What happens if we want to apply that kind of label to an @racket[unquote]?
    
    @RACKETBLOCK[
      (let ([_place "world"])
        (writeln
          (quasiquote #:label _OUTER
            (writeln
              ((UNSYNTAX @racket[quasiquote])
                ("hello" (unquote #:to-label _OUTER _place)))))))
    ]
    
    If we do that, we might expect our labeled @racket[unquote] to skip over one @racket[quasiquote] to match a labeled @racket[quasiquote] beyond it, but isn't obvious how to denote that interaction in terms of hyperbrackets or how to manipulate that kind of structure in terms of hypersnippet-shaped data.
    
    One approach we might take to this is to use hypersnippets of almost impredicatively infinite degree, where we don't quite get to say we have a degree that's "less than itself," but every time we use an unnamed degree, it's something that's less than the unnamed degree we used before. We can likely simulate this if we use a custom @tech{dimension system} where instead of counting degrees up from zero using natural numbers, we count down from infinity using chains of symbolic names.
    
    We might say the outer @racket[quasiquote] is a quote-depth-increasing opening hyperbracket of degree @tt{/OUTER}, the inner @racket[quasiquote] is a quote-depth-increasing opening hyperbracket of degree @tt{/OUTER/GENSYM_ONE}, and the @racket[unquote] is a closing hyperbracket of degree @tt{/OUTER/GENSYM_TWO} --- not @tt{/OUTER/GENSYM_ONE/GENSYM_TWO}, because its explicit label specifies another parent to use. To see if one degree is less than another, we check that it's @emph{under the other's directory}. Since @tt{/OUTER/GENSYM_TWO} is under the @tt{/OUTER} directory, but not under the @tt{/OUTER/GENSYM_ONE} directory, the hyperbrackets match up just the way we want.
    
    Of course, we haven't put this plan into motion yet, so there may be lurking obstacles that we haven't uncovered.
  }
]

Nestable quasiquotation with depth-labeled escape sequences seems to be a complex problem. While Punctaffy's notion of hyperbracketed code doesn't straightforwardly apply in all the ways we might hope for it to, the slightly more complex variations we've described seem viable, and Punctaffy's hyperbrackets are a milestone in those directions. Hypersnippet-shaped data does seem come in handy at least for representing the bounded input of an escape sequence.

@; TODO: The above is very long-winded. The original plan to write this section had a much pithier description, which we might be able to pilfer from for an intro or summary paragraph:
@;
@; Consider writing a "Potential Application" section about one of the original (and ongoing) motivating goals of Punctaffy: The ability to have custom escape sequences in a quotation DSL that are suppressed if the quotation DSL appears inside itself. The "suppressed" behavior of a custom escape sequence conveys nothing but what part of the input is consumed, which is the same part that's consumed when it's not suppressed. When it's not suppressed, it additionally specifies what quoted content that input transforms into.
