#lang parendown scribble/manual

@; punctaffy/scribblings/punctaffy/hypersnippet.scrbl
@;
@; Hypersnippet data structures and interfaces.

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


@(require #/only-in scribble/example examples make-eval-factory)

@(require punctaffy/scribblings/private/shim)

@(shim-require-various-for-label)

@(define example-eval
  (make-eval-factory #/list
    
    'racket/base
    'net/url
    'syntax/datum
    
    'parendown
    
    'punctaffy
    'punctaffy/let
    'punctaffy/quote))

@(define parendown-doc '(lib "parendown/scribblings/parendown.scrbl"))


@(define-syntax-rule @code-block[args ...]
   @nested[#:style 'code-inset]{@verbatim[args ...]})


@title[#:tag "concepts"]{Punctaffy Concepts}



@section[#:tag "intro"]{Introduction to Punctaffy}

Punctaffy is an experimental library for processing program syntax that has higher-dimensional nested structure.

Most programming languages are designed for programs to be structured in the form of trees, with some (or all) nodes of the tree being delimited using opening and closing brackets. However, occasionally some operations take that a dimension higher, opening with one tree node and closing with some number of tree nodes toward the leaves.

@; TODO: Illustrate this graphically.

This is common with templating languages. For instance, a quasiquotation operation has a quoted body that begins with the initial @racket[`_...] tree node and ends with number of @racket[,_...] and @racket[,@_...] tree nodes. The quasiquotation operation also takes a number of expressions to compute what values should be inserted into those holes in the quoted body, and those expressions are maintained in the same place as the holes their results will be inserted into.

@examples[
  #:label #f
  #:eval (example-eval)
  
  (eval:no-prompt
    (define _site-base-url "https://docs.racket-lang.org/"))
  
  (eval:no-prompt
    (define (_make-sxml-site-link _relative-url _content)
      `(a
         (|@|
           (href
             ,(url->string
                 (combine-url/relative (string->url _site-base-url)
                   _relative-url))))
         ,@_content)))
  
  (_make-sxml-site-link "punctaffy/index.html" '("Punctaffy docs"))
]

Quasiquotation isn't the only example. Connection Machine Lisp (CM-Lisp) is a language that was once used for programming Connection Machine supercomputers, and it has a concept of "xappings," key-value data structures where each element resides on a different processor. It has ways to distribute the same behavior to each processor to transform these values, and it has a dedicated notation to assist with this:

@code-block{
  (defun celsius-to-fahrenheit (c)
    α(+ (* •c 9/5) 32))
  
  (celsius-to-fahrenheit '{low→0 mid→50 high→100})
  ⇒ {low→32 mid→122 high→212}
}

That notation has a body that begins with @tt{α...} node and ends with some number of @tt{•...} nodes. The behavior in between is repeated for each xapping entry.

To make it a bit more mundane for the sake of example, let's suppose the @tt{α} notation works on lists instead of xappings, making it a fancy notation for what a Racket programmer would usually write using @racket[map] or @racket[for/list].

In some programs, the two of them might be used together. Here's some code we can write in Racket today:

@examples[
  #:label #f
  #:eval (example-eval)
  
  (eval:no-prompt
    (define (_make-sxml-unordered-list _items)
      `(ul
        ,@(for/list ([_item (in-list _items)])
            `(li ,_item)))))
  
  (_make-sxml-unordered-list (list "Red" "Yellow" "Green"))
]

Here's the same code, using the @tt{α} operator to do the list mapping operation:

@code-block|{
  (define (make-sxml-unordered-list items)
    `(ul ,@α`(li ,•items)))
}|

In the expression @tt{α@literal{`}(li ,•items)}, we see the @racket[`_...] and @racket[,_...] tree nodes are nested in between the @tt{α...} and @tt{•...} tree nodes.

In Punctaffy's terms, this is the nesting of one degree-2 hypersnippet inside another. It's just like the nesting of one parenthesized region of code inside another, but one dimension higher than usual.

In fact, the geometric shape of a hypersnippet is already studied under a different name: An opetope. Opeteopes are usually studied in higher-dimensional category theory and type theory as one way to work with algebraic structures where two things can be "equal" in more than one distinct way. For instance, in homotopy theory, in the place of equality there's a notion of path-connectedness, and the different "ways" things are path-connected are the various different paths between them.

Our motivation for using these shapes in Punctaffy is different, but it's not a complete coincidence. In a way, the body of a quasiquotation is like the space swept out by the path from the @racket[`_...] tree node to the @racket[,_...] tree nodes, and if we think in terms of fully parenthesized s-expressions, each tree node corresponds to a line drawn from its opening parenthesis to its closing parenthesis.

But Punctaffy is driven by syntax. Let's recall the above example of synthesizing quasiquotaton and apply-to-all notation in a single program:

@code-block|{
  (define (make-sxml-unordered-list items)
    `(ul ,@α`(li ,•items)))
}|

Here we have @racket[`_...] nested inside @tt{α...}. We could also imagine the reverse of this; if we quote a piece of code which uses @tt{α...}, then the @tt{α...} appears nested inside the @racket[`_...].

What does this program do?

@code-block{
  α`(li •,items)
}

This is analogous to writing the program @tt{(while #t (displayln "Hello, world))"}. The delimiters are simply mismatched. We can try to come up with creative interpretations, but there's little reason to use the notations this way in the first place.

So, where do we report the error? Racket's reader doesn't match occurrences of @racket[`_...] to occurrences of @racket[,_...] at read time; instead, these always read successfully as @racket[(quasiquote _...)] and @racket[(unquote _...)], and it's up to the implementation of the @racket[quasiquote] macro to search its tree-shaped input, looking for occurrences of @racket[unquote]. So now do we extend that search so that it keeps track of the proper nesting of @tt{α...} and @tt{•...} hyperbrackets? Does every one of these higher-dimensional operations need to hardcode the grammar of every other?

Currently, in Racket:

@itemlist[
  @item{@racket[quasiquote] only knows to skip nested @racket[quasiquote]..@racket[unquote] pairs}
  
  @item{@racket[quasisyntax] only knows to skip nested @racket[quasisyntax]..@racket[unsyntax] pairs}
  
  @item{@racket[quasisyntax/loc] only knows to skip nested @racket[quasisyntax]..@racket[unsyntax] pairs (but not @racket[quasisyntax/loc]..@racket[unsyntax])}
]

This isn't a problem that usually arises with traditional parentheses. The Racket reader only supports a small set of parentheses, @tt{( ) [ ] { }}, which makes it feasible to hardcode them all. Extending this set is rare; new operations usually just follow the Lispy convention of using the same parentheses as everything else.

What if we did that for higher-dimensional brackets as well, picking a single bracket notation and having most of our operations just use that one? In Punctaffy, we've implemented this approach like so:

Before:

@code-block|{
  (define (make-sxml-unordered-list items)
    `(ul ,@α`(li ,•items)))
}|

After:

@examples[
  #:label #f
  #:eval (example-eval)
  
  (eval:alts
    (eval:no-prompt
      (define (_make-sxml-unordered-list _items)
        (taffy-quote
          (^<
            (ul
              (^>
                (list-taffy-map
                  (^< (taffy-quote (^< (li (^> (list (^> _items))))))))))))))
    #;
    (define (_make-sxml-unordered-list _items)
      (taffy-quote
        (^<
          (ul
            (^>
              (list-taffy-map
                (^< (taffy-quote (^< (li (^> (list (^> _items)))))))))))))
    (define (_make-sxml-unordered-list _items)
      `(ul
        ,@(for/list ([_item (in-list _items)])
            `(li ,_item)))))
]

Welcome to 2-dimensional parenthesis soup. Like s-expression notation, this notation isn't the easiest to follow if we're only concerned with a small number of familiar operations, but it does have the arguable advantage of giving programmers a smoother on-ramp to extending their language: Programmers can add new operations that build on the same infrastructure as the existing ones and blend right in.

We refer to delimiters like @tt{(}@racket[^<] and @tt{(}@racket[^>] as hyperbrackets. There are hyperbrackets of any degree (dimension), and traditional brackets @tt{(} and @tt{)} are a special case of hyperbrackets.

In many cases, we might be able to draw attention to matching hyperbrackets a little bit better by making some judicious use of @other-doc[parendown-doc]:

@examples[
  #:label #f
  #:eval (example-eval)
  
  (eval:alts
    (eval:no-prompt
      (pd _/ define (_make-sxml-unordered-list _items)
        (taffy-quote _/ ^< _/ ul _/ ^>
          (list-taffy-map
            (^<
              (taffy-quote _/ ^< _/ li _/ ^> _/ list
                (^> _items)))))))
    #;
    (pd _/ define (_make-sxml-unordered-list _items)
      (taffy-quote _/ ^< _/ ul _/ ^>
        (list-taffy-map
          (^<
            (taffy-quote _/ ^< _/ li _/ ^> _/ list
              (^> _items))))))
    (define (_make-sxml-unordered-list _items)
      `(ul
        ,@(for/list ([_item (in-list _items)])
            `(li ,_item)))))
]

S-expressions are far from the only option for syntax. Many programming languages have a more elaborate syntax involving infix/prefix/suffix operators, separators, various distinct-looking brackets, and so on.

Likewise, the @tt{(}@racket[^<] and @tt{(}@racket[^>] hyperbracket notation isn't the only conceivable option for working with this kind of higher-dimensional structure.

We expect the same techniques we use in Punctaffy to be useful for parsing other notations that have similar higher-dimensional structure. As an easy example, we could develop a parser for the @racket[`_...] and @tt{α...} notations we originally used above.

A more curious example is a template DSL that already exists in Racket, which is almost tailor-made for the exact situation:

@examples[
  #:label #f
  #:eval (example-eval)
  
  (eval:no-prompt
    (define (_make-sxml-unordered-list _items)
      (with-datum ([(_item ...) _items])
        (datum (ul (li _item) ...)))))
]

In Racket's @racket[datum] template DSL, occurrences of @racket[...] cause an item to be repeated some number of times, just like using @tt{α}. A template variable like @racket[_item] is statically associated with an ellipsis depth that governs how many ellipses must be applied to it. In this case, @racket[_item] has an ellipsis depth of 1, so wherever it appears in a template, it implicitly behaves like @tt{•items}. (If the iteration depth were 4, it would behave like @tt{••••items}.) Meanwhile, unbound identifiers like @racket[_ul] and @racket[_li] are implicitly quoted, and miscellaneous syntactic landmarks are implicitly quoted as well. For instance, the lists which surround @racket[_ul] and @racket[_li] are quoted as though they were surrounded with @tt{@literal{`}} and @tt|{,@}|.

In the process of explaining how Racket's template DSL works, we've described a *translation* of (a subset of) that DSL into other Racket code. Maybe @tt{α...} and @tt{•...} aren't actually implemented in Racket, but Punctaffy does implement @racket[(list-taffy-map (^< _...))] and @racket[(^> _...)] to serve their purpose here.

A common technique for DSLs in Racket is first to use a parser to preprocess a DSL into a similarly shaped Racket s-expression, then to expand it using a suite of Racket macros. In this case, what we've described isn't a translation into a mere s-expression so much as a translation into hyperbracketed code. In this way, regardless of the experience of using hyperbrackets directly, hyperbrackets provide infrastructure that can be helpful in the implementation of other DSLs.



@section[#:tag "use-cases"]{Use Cases for Punctaffy}



@subsection[#:tag "existing-use-cases"]{Examples of Existing Hyperbracketed Notations}

@itemlist[
  
  @item{Hyperbrackets of low degree are hyperbrackets too: If we find ourselves in a context where a program is usually just a "sequence of instructions," then a structured @tt{while} loop is a degree-1-hyperbracketed operation. (An instruction by itself is a degree-0-hyperbracketed operation.) If we learn lessons about hygienic macro system design at higher degrees, there's a good chance they can be extrapolated downward to tell us something about s-expression macros (degree 1) and reader macros (degree 0).}
  
  @item{The @racket[quasiquote] or @tt{backquote} operation is probably the most widespread example. Moreover, string interpolation is even more widespread, and it's basically quasiquotation for text-based code.}

  @item{Above, we mention the "apply-to-all" notation @tt{α} from CM-Lisp. Pages 280-281 of @hyperlink["https://web.archive.org/web/20060219230046/http://fresh.homeunix.net/~luke/misc/ConnectionMachineLisp.pdf"]{"Connection Machine Lisp" by Guy Steele} go into detail on the functionality and motivation of this operation.}
  
  @item{In a @hyperlink["https://www.youtube.com/watch?v=dCuZkaaou0Q"]{2017 invited talk at Clojure/Conj}, Guy Steele talks about the inconsistency of computer science notation. At 53m03s, he goes into detail about a combination underline/overline notation he proposes as a way to bring more rigor to schematic formulas which iterate over vectors. He compares it to quasiquotation and the CM-Lisp @tt{α} notation.}
  
]



@subsection[#:tag "potential-use-cases"]{Potential Applications of Hypersnippets}



@subsubsection[#:tag "potential-use-case-hygiene"]{Potential Application: Hygiene}

Hygienic macroexpansion usually generates code where certain variables are only in scope across some degree-2 hypersnippet of the code.

For instance, Racket first colors all the input subforms of a macro call using a new scope tag, and then it inverts that color in the result so that the color winds up only occurring on the code the macro generates itself, not the code it merely passes through.

Racket's strategy works, but it relies on the generation of unique tags and the creation of invisible annotations throughout the generated code.

If we were to approach hygiene by using explicit hypersnippets instead, it might lead to more straightforward or less error-prone implementations of macro hygiene. If enough people find it convenient enough to do structural recursion over nested hypersnippets, then they may find this skill lets them easily keep a lid on the local details of each hypersnippet, just as traditional forms of structural recursion make it easy to keep the details of one branch of a tree data structure from interfering with unrelated branches.

@; TODO: Consider using the following explanation somewhere. We once had it in the Punctaffy documentation's opening blurb.

@;{

So how does this make any sense? We can think of the macro bodies as being @emph{more deeply nested}, despite the fact that the code they interpolate still appears in a nested position as far as the tree structure of the code is concerned. In this sense, the tree structure is not the full story of the nesting of the code.

This is a matter of @emph{dimension}, and we can find an analogous situation one dimension down: The content between two parentheses is typically regarded as further into the traversal of the tree structure of the code, despite the fact that the content following the closing parenthesis is still further into the traversal of the code's text stream structure. The text stream is not the full story of how the code is meant to be traversed.

}


@subsubsection[#:tag "potential-use-case-incremental-compilation"]{Potential Application: Incremental Compilation}

In a language like Racket where programmers can write arbitrarily complex custom syntaxes, compilation can be expensive. This can drag down the experience of editing code the DrRacket IDE, where features like jump-to-definition can depend on performing background expansion to process the user's custom syntaxes.

If macros weren't tree-to-tree transformations, but instead consumed only some small part of the tree and generated a degree-2 hypersnippet, then a modification of one local part of a file could lead to a pinpoint re-expansion of the specific macro call that processed that part of the file, rather than a costly re-expansion of every macro call in the whole file.

Incidentally, this would bring s-expression macro calls into a closer analogy with reader macro calls, which themselves consume some bounded part of the source text stream and generate an s-expression.



@subsubsection[#:tag "potential-use-case-opetopes"]{Potential Application: Representing Opetopes}

The slide deck @hyperlink["https://ncatlab.org/nlab/files/FinsterTypesAndOpetopes2012.pdf"]{"Type Theory and the Opetopes" by Eric Finster} gives a nice graphical overview of opetopes as they're used in opetopic higher category theory and opetopic type theory. One slide mentions an inductive type @tt{MTree} of labeled opetopes, which more or less corresponds to Punctaffy's hypertee type. To our knowledge, hyperbracketed notations have not been used in this context before, but they should be a good fit.



@subsubsection[#:tag "potential-use-case-transpension"]{Potential Application: Type Theories with Transpension}

The paper @hyperlink["https://arxiv.org/pdf/2008.08533.pdf"]{"Transpension: The Right Adjoint to the Pi-type" by Andreas Nuyts and Dominique Devriese} discusses several type theories that have operations that we might hope to connect with what Punctaffy is doing. Transpension appears to be making use of degree-2 hypersnippets in its syntax.

Essentially (and if we understand correctly), a transpension operation declares a variable that represents some unknown coordinate along a new dimension. At some point in the scope of that dimension variable, another operation takes ownership of it, taking the original dimension variable and all the variables that depended on it since then out of scope, but replacing the latter with reusable functions that can be applied repeatedly to different coordinate values of the user's choice.

From a Punctaffy perspective, the dimension variable's original scope is a degree-2 hypersnippet, and the operation that takes it out of scope (and converts other variables to functions) is one of the degree-1 closing hyperbrackets of that hypersnippet.

Curiously, the degree-2 hypersnippet also gets closed by degree-1 closing hyperbrackets at the @emph{type} level; we might say these type theories assign types to terms that have unmatched closing hyperbrackets. They also have lambdas that @emph{abstract over} terms that have unmatched closing hyperbrackets, so the journey of a closing hyperbracket through the codebase to find its match can potentially be rather circuitous.

At any rate, these dimension variables have affine (use-at-most-once) types, which can sometimes seem odd in the context of a type theory where the rest of the variables are Cartesian (use-any-number-of-times). By relating transpension operators to hyperbrackets, we may give the affine typing situation some more clarity: A "closing bracket" can't match up with an "opening bracket" that's already been closed.



@; TODO: Figure out what to do with the "known shortcomings" section of the readme. If we don't include that whole section on this page (or perhaps on a sibling page?), we should probably at least mention Punctaffy's slowness somewhere on this page. Some of the more specific ideas for optimizations probably make more sense to write down in code comments or in tickets on an issue tracker.

@; TODO: If Punctaffy ever overcomes its performance issues, stop discussing them here and in the readme.



@; TODO: Consider using the following explanation for something. I think it builds up to the point too slowly to be a useful introduction to hypersnippets, but it might turn out to be just the explanation someone needs.

@;{

At some level, program code is often represented with text streams. This is a one-dimensional representation of syntax; when we talk about a snippet of text, we designate a beginning point and an ending point and talk about the text that falls in between.

Instead of treating the program as a text stream directly, most languages conceive of it as taking on a tree structure, like an s-expression, a Racket syntax object, a concrete syntax tree, or a skeleton tree. Even later stages of program analysis tend to be modeled as trees (in this case, abstract syntax trees). The notion of a "program with holes" tends to refer to a tree where some of the branches are designated as blanks to be filled in later.

A "program with holes" in that sense is very much analogous to a snippet of text: It begins with a root node and ends with any number of hole nodes, and we talk about the nodes in between.

As s-expressions make explicit, a node in a concrete syntax tree tends to correspond to a pair of parentheses in the text stream. So each node is a snippet between points in the text, and a program with holes is the content that falls in between one root snippet and some number of hole snippets. It's a 2-dimensional snippet.

The dimensions of a higher-dimensional snippet are roughly analogous to those of a geometric shape. A location in a text stream is like a geometric point, a snippet of text is like a line segment bounded by two points, and a program-with-holes is like a polygon bounded by line segments.

As with geometric shapes, we can look toward higher dimensions: A 3-dimensional snippet is bounded by an outer program-with-holes and some arrangement of inner programs-with-holes. A 4-dimensional snippet is bounded by 3-dimensional snippets. We coin the term "hypersnippet" to suggest this tower of generalization.

Higher-dimensional geometric shapes often have quite a number of component vertices and line segments, and the jumble can be a bit awkward to visualize. The same is true to some extent with hypersnippets, but as full of detail as they can get, they're still ultimately bounded by some collection of locations in a text stream. Because of this, we can visualize their shapes using sequences of unambiguously labeled brackets positioned at those points.

}
