#lang parendown scribble/manual

@; punctaffy/scribblings/punctaffy/motivation.scrbl
@;
@; Discussion of Punctaffy's high-level motivations.

@;   Copyright 2021, 2025 The Lathe Authors
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
      [{~autoptic-list
         (_ _orig-stx
           {~autoptic-list ({~autoptic-list [_pat _val]} ...)}
           _body ...)}
       #`(let ()
            #,(datum->syntax
                #f
                `(,#'match-define ,@#'(_pat _val))
                #'_orig-stx)
            ...
            (let ()
              _body
              ...))]))
]

(TODO: See if we can make this a better example. The idea here is that the macro defines something like a cross between @racket[match/derived] and @racket[match-let], and it manipulates the call to @racket[match-define] to insert the source location of the given term to help with accurate error-reporting. However, we haven't tested that this manipulation would actually improve the error-reporting this way, and using the actual @racket[match/derived] would likely be a better idea than trying to make @racket[match-define] work just right.)

Incidentally, the @racket[syntax] DSL already has an experimental feature that caters to this situation: template metafunctions. A template metafunction can run arbitrary code during the iteration of a template:

@racketblock[
  (define-syntax (match-let/derived _stx)
    (syntax-parse _stx
      [{~autoptic-list
         (_ _orig-stx
           {~autoptic-list ({~autoptic-list [_pat _val]} ...)}
           _body ...)}
       
       (define-template-metafunction (_reattributed-match-define _stx)
         (syntax-parse _stx
           [(_ _pat _val)
            (datum->syntax
              #f
              `(,#'match-define ,@#'(_pat _val))
              #'_orig-stx)]))
       
       #'(let ()
           (_reattributed-match-define _pat _val)
           ...
           (let ()
             _body
             ...))]))
]

However, using @racket[define-template-metafunction] substantially rearranges the code. That can be good in cases like this one, where the concept can be associated with a simple name and interface. On the other hand, @racket[unsyntax] comes in handy in situations where the code's navigability benefits from having some structural resemblance to the results it produces, or in situations where multiple DSLs have synergy together but haven't yet been fused into a single monolithic DSL.

If for some reason we have a strong preference to arrange this code in the @racket[unsyntax] style, then what we really need here is for @racket[#'(_pat _val)] not to be a @emph{new} template but a @emph{resumption} of the original syntax. We need some kind of @tt{un-unsyntax}, perhaps abbreviated @tt{#,!}. Then we could replace @racket[#'(_pat _val)] with @tt{#,!}@racket[(_pat _val)] and be on our way.

The concept of @tt{un-unsyntax} fits neatly into the hypersnippet concept we explore in Punctaffy. We can consider @racket[quasisyntax] to be opening a @tech{degree}-3 hypersnippet, @racket[unsyntax] to be opening a degree-2 @tech{hole} in that hypersnippet, and @tt{un-unsyntax} to be opening a degree-1 hole in that degree-2 hole.

Punctaffy currently defines a @racket[taffy-quote-syntax] operation, but it corresponds to @racket[quote-syntax] rather than the @racket[syntax] template DSL. Suppose Punctaffy were to define a @tt{taffy-syntax} operation in that combined spirit, which used @seclink["baseline-notations"]{Punctaffy's baseline hyperbrackets} and had support for @racket[syntax] DSL features like ellipses. Using that operation, the above code could look like this:

@racketblock[
  (define-syntax (match-let/derived _stx)
    (syntax-parse _stx
      [{~autoptic-list
         (_ _orig-stx
           {~autoptic-list ({~autoptic-list [_pat _val]} ...)}
           _body ...)}
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
               ...))))]))
]

This seems to be a rare example of where a degree-3 hypersnippet specifically would come in handy. Most of the things we say about hypersnippets of degree 3 aren't so specific; they would make just as much sense at degree 4, 5, etc.

This example seems like an instance of a pattern, though: The basic principle of this example is that we want two different invocations of an embedded DSL to be part of the same "whole program" to allow some nonlocal interaction between them. The nonlocal interactions here aren't too exotic; they're basically lexically scoped variables, with ellipses acting as the binding sites.

Other embedded DSLs with lexically scoped interactions, such as type inference and type-directed elaboration, may similarly benefit from degree-3 lexical structure.



@; TODO: Consider writing another "Potential Application" section related to the @racket[syntax] DSL, with the focus being this: If we change the reader to read hyperbracketed code instead of s-expressions (and change @racket[syntax-protect], the sets-of-scopes hygiene model, and the syntax property @racket[cons]-collecting logic, and the quotation operators to go along with this change), then we won't have to worry about reporting errors for unbound hyperbracket notations. Currently with Punctaffy's baseline notations, if the programmer neglects to import a certain notation or shadows its binding, then it'll silently be treated as an identifier in the code rather than as a hyperbracket. This problem exists for Racket's @racket[quasiquote] and @racket[unquote] and @racket[quasisyntax] and @racket[unsyntax], too.



@subsection[#:tag "potential-use-case-opetopes"]{Potential Application: Opetopes and Higher Categories}

An opetope is a kind of geometric shape that arises in certain formulations of higher category theory.

A category is like the collection of paths in a directed graph: Two paths (called morphisms) can match up end-to-end, and if they do, together they make a single path. Path-joining like this is associative; if we join some number of paths together this way, it doesn't matter which ones we join first.

Higher category theory extends this to higher-dimensional shapes. If two paths share both their endpoints, we can think of a soap bubble where current flows across from one of them to the other, a path between paths (called a 2-cell). And given two of these, we can imagine a geometric solid where current flows from one of these faces to the other (called a 3-cell).

We can study more subtle category-like systems this way: Instead of simply knowing whether two paths are equal or not, we can point to a 2-cell and say they're equivalent according to this specific equivalence that translates between them. This is appealing to many category theorists, because a lot of interesting category-theoretic results don't depend at all on whether paths have @emph{particular endpoints} (called objects), only that when joining paths, there's some equivalence-like way to join up one endpoint to another. Once we're looking at 2-cells, a lot of interesting results have nothing to do with what specific 1-cells/paths/morphisms they begin and end at.

However, this kind of generalization also makes it quite a bit more difficult to formalize the meaning of a higher category. A number of different formalizations exist.

What we've described just now is a @emph{globular} approach, where each cell of dimension (N + 1) begins at a cell of dimension N and ends at another cell of dimension N with the same endpoints.

Perhaps we should instead take a @emph{cubical} approach, where the source and target don't necessarily have "the same" endpoints, just edges that are related by other cells. Then a 2-cell is shaped like a square, a 3-cell is a cube, and higher cells are hypercubes.

Or perhaps we could take a @emph{simplicial} approach, where the higher cells that mediate compositions of two paths are triangles, the ones that mediate compositions of three paths are tetrahedra, and the ones that mediate compositions of more paths are higher-dimensional simplex polytopes.

But one of the approaches is what we're here for, because it resembles Punctaffy's @tech{hypersnippets}: The @emph{opetopic} approach.

@deftech{Opetopes} are another set of higher-dimensional shapes like hypercubes or simplexes. An @deftech{opetopic} cell of dimension (N + 1) has a target cell of dimension N and any number of source cells of dimension N that are in a composable arrangement. For instance, an opetopic 2-cell ends at a path, and it begins with any number of paths aligned end-to-end. This makes opetopic 2-cells just the right shape for saying "this arrangement of paths composes to make something that's related to this other path in this particular way." Opetopic 3-cells are good for the same thing, but they relate a composable arrangement of 2-cells (i.e. a tree) to a single 2-cell. Since these are many-input, single-output relations, a composition of 2-cells tends to look like a tree, and higher cells are composed along "higher-dimensional trees."

The peculiar shape of opetopes lets us talk about composition at the same time as we talk about cells being related to each other. Instead of postulating ideas of composition and equivalence as separate ideas, we can define them both in terms of the existence of certain opetopic cells. If we're looking for a cell that acts as the composition of some composable arrangement of cells, all we need is for the arrangement to be the source of some equivalence-like cell; that way the target of that cell is the composition we're looking for (or equivalent to it, which is just as good). Once we have composition, we can also use cells like these to relate one arrangement to another, by first taking the composition of the target arrangement and making that the target cell of another opetope. In this fashion, we can build up a theory of weak higher categories by merely requiring that enough equivalence-like cells exist (and are actually equivalence-like in their relationships with each other).

Now we can finally relate opetopes to hypersnippets, specifically @tech{hypertees}. At low dimensions, there's a striking resemblance: @tech{Degree}-2 hypertees are shaped like @racket[(^< (^> __) (^> __) (^> __) ...)] with some number of degree-1 @tech{holes} in sequence, which looks just like the way an opetopic 2-cell represents a composition of any number of paths. There's only one degree-0 hypertee, and only one degree-1 hypertee, and the same is true for dimension-0 and dimension-1 opetopes. At degree 3, the degree-2 holes of a hypertee can be arranged like a tree, and the source cells of a dimension-3 opetope are also arranged like a tree.

However, there does seem to be a discrepancy. This is apparent when we look at algebraic data types that represent opetopes and hypersnippets.

The slide deck @hyperlink["https://ncatlab.org/nlab/files/FinsterTypesAndOpetopes2012.pdf"]{"Type Theory and the Opetopes"} by Eric Finster gives a richly illustrated overview of opetopes as they're used in opetopic higher category theory and opetopic type theory. One slide mentions a type @tt{MTree} representing "possible ill-typed A-labeled pasting diagrams":

@code-block{
  data MTree (A : Set) : N → Set where
    obj : MTree A 0
    drop : {n : N} → MTree ⊤ n → MTree A (n + 2)
    node : {n : N} → A → MTree (MTree A (n + 1)) n → MTree A (n + 1)
}

This corresponds to three mutually exclusive kinds of opetopes:

@itemlist[
  @item{An opetope can be the trivial dimension-0 opetope, which has no targets or sources.}
  
  @item{An dimension-(@emph{n} + 2) opetope's composable arrangement of dimension-(@emph{n} + 1) source cells can be a trivial arrangement of zero source cells. In that case, its dimension-(@emph{n} + 1) target cell is shaped like an identity element of dimension-(@emph{n} + 1) cell composition. That dimension-(@emph{n} + 1) target cell must have a single dimension-@emph{n} source cell of the same shape as its dimension-@emph{n} target cell. This kind of opetope is called a "drop" due to the teardrop-like way it can be illustrated: The zero source cells effectively pinch the two sides of the target cell together into a teardrop. There's one of these dimension-(@emph{n} + 2) opetopes for each of the dimension-@emph{n} opetopes (the endpoints that are pinched together).}
  
  @item{Finally, a dimension-(@emph{n} + 1) opetope's composable arrangement of source cells can consist of a nonzero number of cells. In this case, one of these dimension-@emph{n} source cells in the arrangement can be identified by its incidence with the the target cell's target cell (if dimension (@emph{n} + 1) is at least 2). The rest can be grouped into sub-arrangements of dimension (@emph{n} + 1), each of which targets one of the identified source cell's source cells. (If the dimension (@emph{n} + 1) is only 1, then there's precisely one dimension-@emph{n} source cell, which we can serendipitously talk about the same way since that source cell no source cells of its own for the sub-arrangements to target.)}
]

In short, an opetope falls into one of three cases: Either it's the trivial dimension-0 opetope where sources aren't allowed at all, it has no sources, or it has at least one source.

As for hypersnippets, an analogous data type definition for possible ill-typed A-labeled hypertees would look like this:

@code-block{
  data Hypertee (A : Set) : N → Set where
    zero : Hypertee A 0
    hole :
      {m, n : N} → {m < n} → A → Hypertee (Hypertee A n) m →
        Hypertee A n
}

These cases correspond to @racket[hypertee-coil-zero] and @racket[hypertee-coil-hole], and we can describe them like this:

@itemlist[
  @item{A hypertee can be the trivial degree-0 hypertee, which has no holes.}
  
  @item{A degree-@emph{n} hypertee can have at least one hole. In that case, the first hole has some dimension @emph{m} such that (@emph{m} < @emph{n}). The rest of the hypertee's arrangement of holes can be grouped into sub-arrangements which correspond to other degree-@emph{n} hypertees.}
]

Going from opetopes to hypertees, we notably lose the existence of "drop" opetopes, but the "at least one" case has become more lenient and admits more hypertees to take the place of what we lost. Specifically, the "at least one" case no longer limites us to incrementing the dimension by precisely 1.

This gives us all the shapes we had before. The degree-2 hypertee @racket[(^<)] has zero degree-1 holes @racket[(^> __)], and in this way it is exactly the same shape as the "drop" dimension-2 opetope which has zero degree-1 source cells. However, we don't represent it by a zero-hole "drop" case; we represent it as having at least one hole: Its @emph{degree-0} hole. The degree-0 hole corresponds not to one of the dimension-2 opetope's dimension-1 source cells, but to its dimension-1 target cell's dimension-0 source cell. We can similarly encode any other "drop" opetope as a hypertee by encoding its target cell (which is not itself a "drop" opetope since it has one source cell) and then adjusting that encoding to have a degree 1 greater.

In fact, we have some hypertees that don't correspond to any opetopes. For instance, the degree-2 hypertee @racket[(^< (^> __) (^> __))] corresponds to an opetope, but setting its degree to 3 gives us a degree-3 hypertee @racket[(^<d 3 (^> __) (^> __))] that has no such correspondence. This hypertee isn't a drop, because a drop's target must have exactly one source (of the same shape as its target, so that it can represent an identity element that unimposingly slots into compositions along that shape).

On the other hand, if we turn our attention to the role of these shapes as conceptual notations for higher category theory, then in some sense it makes sense for @racket[(^<d 3 (^> __) (^> __))] to be a "drop." That's because, while the degree-2 target @racket[(^< (^> __) (^> __))] isn't syntactically identity-shaped the way @racket[(^< (^> __))] is, it's still @emph{semantically} identity-shaped: A higher category has an equivalence-like cell of this shape---namely, one of the 2-cells that relates two composable paths to the combined path they become.

The story isn't as simple as saying that there are more hypertees than opetopes. The two approaches seem to have an affinity for different kinds of generalization:

@itemlist[
  
  @item{
    Opetopes are typically defined by iterating a @emph{slice construction} taking one symmetric operad or symmetric multicategory to another. The "symmetric" part means there sources of an opetopic cell are an orderless collection.
    
    The Punctaffy authors don't yet (TODO) understand the reason for this. It seems the cells can be assigned an ordering by, for instance, iterating over each tree of a zoom complex in depth-first order according to the branch ordering we established in the previous tree, and numbering the circles as we first arrive at them to establish the branch ordering of the next tree. But we suppose the slice construction could potentially be applied to an operad or multicategory that isn't trivial enough for this to work. As long as most of the work on opetopic theories works with this kind of slice construction, its results will likely be transportable to those less trivial base operads/multicategories. (The paper @hyperlink["https://mat.uab.cat/~kock/cat/0706.1033v2.pdf"]{"Polynomial functors and opetopes"} by Joachim Kock, André Joyal, Michael Batanin, and Jean-François Mascari goes into detail on zoom complexes and might even contain information as to why the symmetric approach is necessary.)
    
    This kind of generality doesn't seem like a focus of hypersnippets. Hypersnippets are primarily motivated by giving structure to a text file, a context where the syntax does have an innate order that we can work with. In particular, the design of @tech{hyperbracket} notation and the @tech{hyperstacks} to parse it likely relies intrinsically on syntax having an ordering so that the brackets can be associated with their closest matches.
  }
  
  @item{
    Since the definition of hypertees doesn't rely on adding 1 or 2 to a dimension number, hypertees can be generalized across any @tech{dimension system}. (Dimension systems seem to be semilattices.) We sometimes make use of this as an implementation technique, by constructing a modified dimension system that gives us the hypertees we need for our intermediate representations. Typically when we do this, we simply add a new greatest element to the dimension system, giving us "degree-infinity" hypersnippets to work with.
    
    With opetopes, by defining them via the iteration of a slice construction on a base operad/multicategory, it's generally possible to prove things about them by doing induction on the dimension of an opetope. (TODO: Is that right?)
    
    In Punctaffy, since hypersnippets are motivated by syntax, and since programs have syntax of finite size, we can count on each hypersnippet to have a finite number of holes. This already seems to be a way to keep our recursive constructions well-founded, so induction over the degree of a hypersnippet doesn't seem to be as necessary.
  }
  
]

Still, hypertees and opetopes are two systems that seem to have a lot in common. This finally brings us to the potential applications:

It's quite likely Punctaffy will be easier to explain if we borrow some of the graphical visualization techniques from the existing body of work on opetopes. Conversely, we suspect opetopic type theory in particular would benefit from hyperbrackets as a more intuitive notation for specifying opetopic shapes in textual code.

If hypertees aren't quite the same as opetopes, then perhaps hypertees constitute yet another geometry for higher category theory, alongside shapes like hypercubes and simplexes. Perhaps this approach to higher category theory would be more appealing than the others in some ways, at least thanks to the ease of representing its higher-dimensional shapes in textual code if nothing else.

If we pursue hypersnippet-shaped higher category theory, then Punctaffy's progress so far can give us some clues as to how that theory might be formulated. In particular, the @tech{snippet system} interface likely bears a strong resemblance to the interface of an internalized hypersnippet-based higher category, similar to the way the Haskell @tt{Category} type class can be seen as the interface of an internalized 1-category.



@subsection[#:tag "potential-use-case-transpension"]{Potential Application: Type Theories with Transpension}

The paper @hyperlink["https://arxiv.org/pdf/2008.08533.pdf"]{"Transpension: The Right Adjoint to the Pi-type"} by Andreas Nuyts and Dominique Devriese discusses several type theories that have operations that we might hope to connect with what Punctaffy is doing. Transpension appears to be making use of @tech{degree}-2 @tech{hypersnippets} in its syntax.

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
