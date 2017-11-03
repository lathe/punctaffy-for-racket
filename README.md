# Punctaffy

Punctaffy is a library for dealing with structured data with a higher-degree concept of "nesting" than usual. Its main use is for programming languages' syntax, where we structure lexical regions according to the intervals that mark their beginnings and ends. Higher degrees correspond to making degree-N+1 intervals that begin at one degree-N interval and end at another degree-N interval inside it.

```
Statement terminators:       ;   ;
Parentheses:                 (   (   )   )
Quasiquotations (Scheme):   `(  `(  ,(  ,(  )  )  )  )
???:                       ^`( ^`( ~`( ~`( ,( ,( ,( ,( ) ) ) ) ) ) ) )
```

## Deep rationale

The lexical structure of our textual programming languages isn't something we've arrived at by mere creativity. Linear text is a compact format for abstract information that offers a guiding track for a human to receive it (and recapitulate information like it). As a document, linear text is accidentally chunked by the fact that not all text is in focus or even in view at the same time; there are fogs before and after any region of interest, and that creates an interval topology on the syntax before we even apply section headers to break it up manuallly. It breaks up almost on its own, on whatever boundaries are most faithfully understood when only a title or summary is known.

Logic, mathematics, and computer science give us textual languages where not only are the sections of a text extremely faithfully understandable by proxy, but those natural section boundaries are extremely densely packed with only a small lexicon of building blocks in between.

What do those building blocks look like? Typically, they're text sections with a few text sections carved out of the middle.

```
((_____) + (_____))
(if (_____) then (_____) else (_____))
(true)
```

There's a bit more to their shape than that. There's also the fact that we can recognize markers like "+" and "if" first as we determine where we should place those boundaries in the first place, and some operators are associative, allowing us to break up a section of syntax into overlapping sub-sections, not just nested ones.

But even in the simplest case, we already see that we have a new kind of interval. It's made out of the old one: The syntax `(if (_____) then (_____) else (_____))` has a lower bound in the form of the outer pair of parentheses, as well as three upper bounds in the form of the inner pairs.

This kind of interval has at least one more notable use: Quasiquotation.

```
`(foo (lambda () ,(bar 1 2))
```

The `(foo ...)` section is quoted, and the `(bar ...)` section is inside that section in one sense, but it's not quoted. So the section of code that's quoted has a hole carved out of it.

Quasiquotation is useful in the Lisp family for code generation. I suspect it could also be useful for switching into and out of DSLs and scripting languages, or even just for binding time annotations. Further, I think there are fruitful similarities between quasiquotations (with their unquotes) and lambdas (with their parameters' usage sites).

Few languages have quasiquotation at all, and none that I know of have facilities to help users develop their own quasiquotation-shaped syntaxes, except possibly for Racket's "macros that work together" features.

If a language *did* support this, how could we be confident the support was adequate? It's easy to see how parentheses nest with each other, but the support for nesting quasiquotations differs even between Common Lisp and Scheme.

We pursue this confidence in Punctaffy by extending the analogy further.

Where there's an ordering, there's an interval. Where there's an interval, we can order them by containment. By iterating this, we can find lexical regions of higher and higher degrees, which have higher and higher degrees of holes carved out of them. Quasiquotation-shaped regions with quasiquotation-shaped holes... and then whatever comes after that.

We can even extend the analogy one degree lower than parentheses. A quasiquotation has holes that are pairs of parentheses. When a Lisp-style reader processes a text stream, a pair of parentheses has a hole that starts at the closing bracket and continues for the rest of the stream. A tail of a stream... has no holes. So we call that degree 0. Pairs of parentheses are degree 1, and quasiquotations are degree 2.

Every degree of this is likely useful for *something*. For instance, expressions of degree N+1 may be useful for expressing code generation, binding time annotations, and DSL mode-switching over expressions of degree N.

But if you want my opinion, I think the most compelling application of this is to do quasiquotation syntaxes like `unquote` properly, and the most exciting side effect is to generalize reader macros and s-expression macros into a unified system.


## Macros over high-degree syntaxes

When we put high-degree syntax on the table, it may start to call into question the Lisp tradition of using s-expressions for the post-reader, pre-macroexpander syntax. What about using higher degrees in between? Or what about unifying the reader and the macroexpander into one stage?

This project, Punctaffy, has explored the second option first. (It's still been difficult to get to this point, because allowing users to define closing bracket operators like `unquote` takes special attention.) Punctaffy will also pursue the more phase-separated approach as well, so that users have the option of implementing either kind of macroexpander for their purposes.


## High-degree syntaxes in Racket

Racket has a lot invested in its representations of syntax. Between syntax properties, syntax taints, sets of scopes, and source locations, Racket syntax objects have a lot attached. Then Racket has various specific uses for its syntax properties, such as `'taint-mode`, `syntax-original?`, and so on, which might be tricky to work around -- not to mention all the ways other Racket code might be using syntax properties for its own purposes. Syntax taints really seem to be the trickiest part, since they mean we can't model higher degrees of Racket syntax by using Racket syntax objects with "holes" deep inside; if we pull apart the syntax to find the holes inside, we taint all our results.

Racket also has a particular implementation of readtables already. Readtable mappings have little in common with variable lookups and have very little hygiene or extensibility.

To work together with Racket's hygiene systems, Punctaffy will focus on taking Racket syntax objects as input and producing Racket syntax objects as output, trying to play nicely with source locations, taints, etc. along the way.

The readtable, on the other hand, almost seems better to rebuild from scratch, using custom implementations of every reader macro. This is a steep undertaking, and yet 100% parity with Racket's existing (unhygienic) reader syntaxes is probably undesirable, so it's not a priority of the Punctaffy project yet.


## Using Punctaffy

Punctaffy is still in a highly experimental phase. If there's even an API to speak of, it's more an accident of `(provide (all-defined-out))` rather than something that's actually well-defined, stable, or supported. Consider Punctaffy to be a proof of concept, and implement your own systems similar to it if you like what you see. Let me know if you do! :)



## Notes about macroexpansion of high-degree syntax

(TODO: Put these notes somewhere better.)


### Macroexpansion with a reader phase and a backend phase

A nice part about Lisp syntax is that programmers can usually forget their code has a text syntax at all. When they write macros, they can almost always manipulate an s-expression encoding of their programs, rather than manipulating text streams. Moreover, when they write their own languages, they can reuse the reader and just define their languages' syntax in terms of s-expressions.

We can't expect higher-degree syntax to have quite the same appeal, because tree-like structures seem to be pervasive in computation, like call trees, lexical scope inheritance trees, and so on. Higher-degree syntax has nontrivial shapes (a single root, multiple holes, and a specific elaborate juxtaposition of those holes and the data in between), and code that manages those shapes may be verbose even with our best effort. However, by allowing users to pretend that their syntax is higher-degree on the surface, we save them from having to write their own higher-degree bracket-matching algorithms for their custom quasiquotation-shaped operators and such, which can be even more verbose and error-prone for them to do themselves.

To support this, we should expand the text streams or s-expressions to high-degree structures first, and then in a separate phase expand the high-degree structures into the target code format (in our case Racket syntax objects).

This can be done with two families of macroexpanders:

  - For each degree N, we'll want to have a reader-like macroexpander that starts with syntax of degree N, matches up the degree-N bracket sets it contains, and finally returns a structure of those matched-up brackets and any unmatched closing brackets that remain.

  - For each degree N, we'll want to have a backend-like macroexpander that takes that structure of degree-N bracketed regions and closing brackets and turns it into either a Racket syntax object or a reader-like macro call of degree N+1. This would typically expect the input to consist of nothing but a single set of matched brackets. It would look up a macro based on the data attached to those brackets, and then it would pass the brackets' degree-N+1 contents to the macro.

Full macroexpansion from low-degree surface syntax to low-degree Racket syntax objects proceeds by running a reader-like macroexpander followed by a backend-like macroexpander in a loop until the backend-like macroexpander doesn't generate a reader-like macro call.

Users would typically choose a degree and write a backend-like macro that takes a macro body of that degree and generates Racket code.

When users need it, they also have the option of choosing a degree and writing a reader-like macro that takes a macro body of that degree and generates a structure of matched and unmatched brackets.


### Single-phase macroexpansion

If we don't require separate reader-like and backend-like macroexpansion steps, we can write reader-like macros only, letting them take care of the whole loop. Instead of returning a structure of matched brackets, they return a result that only contains the closing brackets and some code that will macroexpand the matched brackets itself.

This is what Punctaffy currently implements.

Unfortunately it doesn't let users reuse the reader phase of the macroexpander for their own custom languages, nor doe it let them ignore the reader phase when they write their macros, because the reader really isn't distinguishable from the backend. It may be possible for users to implement their own reader/backend phase-separated macro system, but probably not much more easily than the way we'll implement that kind of system here in Punctaffy.
