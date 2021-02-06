# Punctaffy

[![Travis build](https://travis-ci.org/lathe/punctaffy-for-racket.svg?branch=master)](https://travis-ci.org/lathe/punctaffy-for-racket)

Punctaffy is an experimental library for processing program syntax that has higher-dimensional nested structure.

Most programming languages are designed for programs to be structured in the form of trees, with some (or all) nodes of the tree being delimited using opening and closing brackets. However, occasionallysometimes templating languages take this a dimension higher, opening with one tree node and closing with some number of tree nodes toward the leaves.

(TODO: Illustrate this graphically.)

For instance, a quasiquotation operation has a quoted body that begins with the initial `` `___`` tree node and ends with number of `,___` and `,@___` tree nodes. The quasiquotation operation also takes a number of expressions to compute what values should be inserted into those holes in the quoted body, and those expressions are positioned at their respective holes.

```racket
(define site-base-url "https://docs.racket-lang.org/")

(define (make-sxml-site-link relative-url content)
  `(a (@ (href ,(combine-url/relative site-base-url relative-url)))
     ,@content))

> (make-sxml-site-link "punctaffy/index.html" '("Punctaffy docs"))
(a (@ (href "https://docs.racket-lang.org/punctaffy/index.html")) "Punctaffy docs")
```

Quasiquotation isn't the only example. Connection Machine Lisp (CM-Lisp) is a language that was once used for programming Connection Machine supercomputers, and it has a concept of "xappings," key-value data structures where each element resides on a different processor. It has ways to distribute the same behavior to each processor to transform these values, and it has a dedicated notation to assist with this:

```lisp
(defun celsius-to-fahrenheit (c)
  α(+ (* •c 9/5) 32))
 
(celsius-to-fahrenheit '{low→0 mid→50 high→100})
 ⇒ {low→32 mid→122 high→212}
```

That notation has a body that begins with `α...` node and ends with some number of `•...` nodes. The behavior in between is repeated for each xapping entry.

To make it a bit more mundane for the sake of example, let's suppose the `α` notation works on lists instead of xappings, making it a fancy notation for what a Racket programmer would usually write using `map` or `for/list`.

In some programs, the two of them might be used together. Here's some code we can write in Racket today:

```
(define (make-sxml-unordered-list items)
  `(ul
     ,@(for/list ([item (in-list items)])
         `(li ,item))))

> (make-sxml-unordered-list "Strawberry" "Chocolate" "Vanilla")
(ul (li "Strawberry") (li "Chocolate") (li "Vanilla"))
```

Here's the same code, using the `α` operator to do the list mapping operation:

```
(define (make-sxml-unordered-list items)
  `(ul ,@α`(li ,•items))
```

In the expression ``α`(li ,•items)``, we see the `` `...`` and `,...` tree nodes are nested in between the `α...` and `•...` tree nodes.

In Punctaffy's terms, this is the nesting of one degree-2 hypersnippet inside another. It's just like the nesting of one parenthesized region of code inside another, but one dimension higher than usual.

In fact, the geometric shape of a hypersnippet is already studied under a different name: An opetope. Opeteopes are usually studied in higher-dimensional category theory and type theory as one way to work with algebraic structures where two things can be "equal" in more than one distinct way. For instance, in homotopy theory, in the place of equality there's a notion of path-connectedness, and the different "ways" things are path-connected are the various different paths between them.

Our motivation for using these shapes in Punctaffy is different, but it's not a complete coincidence. In a way, the body of a quasiquotation is like the space swept out by the path from the `` `...`` tree node to the `,...` tree nodes, and if we think in terms of fully parenthesized s-expressions, each tree node corresponds to a line drawn from its opening parenthesis to its closing parenthesis.

But Punctaffy is driven by syntax. Let's recall the above example of synthesizing quasiquotaton and apply-to-all notation in a single program:

```
(define (make-sxml-unordered-list items)
  `(ul ,@α`(li ,•items))
```

Here we have `` `...`` nested inside `α...`. We could also imagine the reverse of this; if we quote a piece of code which uses `α...`, then the `α...` appears nested inside the `` `...``.

What does this program do?

```racket
α`(li •,items)
```

This is analogous to writing the program `(while #t (println "Hello, world))"`. The delimiters are simply mismatched. We can try to come up with creative interpretations, but there's little reason to use the notations this way in the first place.

So, where do we report the error? Racket's reader doesn't match occurrences of `` `...`` to occurrences of `,...` at read time; instead, these always read successfully as `(quasiquote ...)` and `(unquote ...)`, and it's up to the implementation of the `quasiquote` macro to search its tree-shaped input, looking for occurrences of `unquote`. So now do we extend that search so that it keeps track of the proper nesting of `α...` and `•...` hyperbrackets? Does every one of these higher-dimensional operations need to hardcode the grammar of every other?

Currently, in Racket:

* `quasiquote` only knows to skip nested `quasiquote`..`unquote` pairs
* `quasisyntax` only knows to skip nested `quasisyntax`..`unsyntax` pairs
* `quasisyntax/loc` only knows to skip nested `quasisyntax`..`unsyntax` pairs (but not `quasisyntax/loc`..`unsyntax`)

This isn't a problem that usually arises with traditional parentheses. The Racket reader only supports a small set of parentheses, `( ) [ ] { }`, which makes it feasible to hardcode them all. Extending this set is rare; new operations usually just follow the Lispy convention of using the same parentheses as everything else.

What if we did that for higher-dimensional brackets as well, picking a single bracket notation and having most of our operations just use that one? In Punctaffy, we've implemented this approach like so:

Before:

```racket
(define (make-sxml-unordered-list items)
  `(ul ,@α`(li ,•items))
```

After:

```
(define (make-sxml-unordered-list items)
  (taffy-quote
    (^<
      (ul
        (^>
          (list-taffy-map
            (^< (taffy-quote (^< (li (^> (list (^> items)))))))))))))
```

Welcome to 2-dimensional parenthesis soup. Like s-expression notation, this notation isn't the easiest to follow if we're only concerned with a small number of familiar operations, but it does have the arguable advantage of giving programmers a smoother on-ramp to extending their language: Programmers can add new operations that build on the same infrastructure as the existing ones and blend right in.

We refer to delimiters like `(^<` and `(^>` as hyperbrackets. There are hyperbrackets of any degree (dimension), and traditional brackets `(` and `)` are a special case of hyperbrackets.

In many cases, we might be able to draw attention to matching hyperbrackets a little bit better by making some judicious use of [Parendown](https://github.com/lathe/parendown-for-racket):

```
(define (make-sxml-unordered-list items)
  (taffy-quote #/^< #/ul #/^>
    (list-taffy-map
      (^<
        (taffy-quote #/^< #/li #/^> #/list
          (^> items))))))
```

S-expressions are far from the only option for syntax. Many programming languages have a more elaborate syntax involving infix/prefix/suffix operators, separators, various distinct-looking brackets, and so on.

Likewise, the `(^<` and `(^>` hyperbracket notation isn't the only conceivable option for working with this kind of higher-dimensional structure.

We expect the same techniques we use in Punctaffy to be useful for parsing other notations that have similar higher-dimensional structure. As an easy example, we could develop a parser for the `` `...`` and `α...` notations we originally used above.

A more curious example is a template DSL that already exists in Racket, which is almost tailor-made for the exact situation:

```
(define (make-sxml-unordered-list items)
  (with-datum ([(item ...) items])
    (datum (ul (li item) ...))))
```

In Racket's `datum` template DSL, occurrences of `...` cause an item to be repeated some number of times, just like using `α`. A template variable like `item` is statically associated with an ellipsis depth that governs how many ellipses must be applied to it. In this case, `item` has an ellipsis depth of 1, so wherever it appears in a template, it implicitly behaves like `•items`. (If the iteration depth were 4, it would behave like `••••items`.) Meanwhile, unbound identifiers like `ul` and `li` are implicitly quoted, and miscellaneous syntactic landmarks are implicitly quoted as well. For instance, the lists which surround `ul` and `li` are quoted as though they were surrounded with `` ` `` and `,@`.

In the process of explaining how Racket's template DSL works, we've described a *translation* of (a subset of) that DSL into other Racket code. Maybe `α...` and `•...` aren't actually implemented in Racket, but Punctaffy does implement `(list-taffy-map (^< ...))` and `(^> ...)` to serve their purpose here.

A common technique for DSLs in Racket is first to use a parser to preprocess a DSL into a similarly shaped Racket s-expression, then to expand it using a suite of Racket macros. In this case, what we've described isn't a translation into a mere s-expression so much as a translation into hyperbracketed code. In this way, regardless of the experience of using hyperbrackets directly, hyperbrackets provide infrastructure that can be helpful in the implementation of other DSLs.


## Known shortcomings

Unfortunately, translation layers like the one we just described won't yet be as easy as Racket programmers may have come to expect. While most DSLs in Racket can use frameworks like `match`, `syntax-parse`, `ragg`, and `brag` to parse and translate tree structure, Punctaffy doesn't currently provide any simple framework to parse and translate nested hypersnippet structure.

For now, Punctaffy's hyperbracketed operations are implemented longhand as recursive descent parsers which use various special-purpose utility functions and algebraic translations to pull hypersnippets apart and put them back together. The situation is not dissimilar to writing low-tech macros full of calls to `caddadr` and `append` and `list*`, but instead of these operations, we have various detours into category theory. Hmm... `caddadr`gory theory...

Punctaffy's hyperbracketed operations are also prohibitively slow at parsing even small examples. The compiled code is fine, but even a small example can take several minutes to compile.

About 70% of the compile-time rigamarole seems attributable to defensive higher-order contract checking. We don't want all our `caddadr`gory theory to have bugs in it. Since we can simply disable the contracts once we're confident in them, this isn't so concerning... but we might need to spend some time making it easier to disable these contracts, especially the more redundant ones.

Secondarily, we likely have a few too many traversals over hypersnippets. Each traversal over a hypersnippet involves doing several traversals over constituent hypersnippets of lower degree, so they can add up fast. There's likely to be some low-hanging fruit here; we might change the hypersnippet representations to avoid converting things back and forth and to give low-degree snippets some simpler internal representations that don't recur into hypersnippet after hypersnippet. In the long run, if we introduce parsing and template DSLs and use them everywhere, the optimization of the DSL implementation might take us a long way. Essentially, parsers and templates could together serve as higher-dimensional stream transducers, and they might be statically analyzable enough that we can perform stream fusion optimizations within the DSL.

In short, Punctaffy has essentially spent its entire performance budget on the core functionality of parsing hypersnippet structure, and this functionality isn't even that easy to use yet. Low-hanging-fruit optimizations are Punctaffy's clearest path to improvement, followed by more convenient hypersnippet-matching utilities.


## Examples of existing hyperbracketed notations

* Hyperbrackets of low degree are hyperbrackets too: If we find ourselves in a context where a program is usually just a "sequence of instructions," then a structured `while` loop is a degree-1-hyperbracketed operation. (An instruction by itself is a degree-0-hyperbracketed operation.) If we learn lessons about hygienic macro system design at higher degrees, there's a good chance they can be extrapolated downward to tell us something about s-expression macros (degree 1) and reader macros (degree 0).

* The `quasiquote` or `backquote` operation is probably the most widespread example. Moreover, string interpolation is even more widespread, and it's basically quasiquotation for text-based code.

* Above, we mention the "apply-to-all" notation `α` from CM-Lisp. Pages 280-281 of ["Connection Machine Lisp" by Guy Steele](https://web.archive.org/web/20060219230046/http://fresh.homeunix.net/~luke/misc/ConnectionMachineLisp.pdf) go into detail on the functionality and motivation of this operation.

* In a [2017 invited talk at Clojure/Conj](https://www.youtube.com/watch?v=dCuZkaaou0Q), Guy Steele talks about the inconsistency of computer science notation. At 53m03s, he goes into detail about a combination underline/overline notation he proposes as a way to bring more rigor to schematic formulas which iterate over vectors. He compares it to quasiquotation and the CM-Lisp `α` notation.

* The slide deck ["Type Theory and the Opetopes" by Eric Finster](https://ncatlab.org/nlab/files/FinsterTypesAndOpetopes2012.pdf) gives a nice graphical overview of opetopes as they're used in opetopic higher category theory and opetopic type theory. One slide mentions an inductive type `MTree` of labeled opetopes, which more or less corresponds to Punctaffy's hypertee type. To our knowledge, hyperbracketed notations have not been used in this context before, but they should be a good fit.

* The paper ["Transpension: The Right Adjoint to the Pi-type" by Andreas Nuyts and Dominique Devriese](https://arxiv.org/pdf/2008.08533.pdf) discusses several type theories that have operations that we might hope to connect with what Punctaffy is doing. Transpension appears to be making use of degree-2 hypersnippets in its syntax. More on this below.

### Notes on transpension

Essentially (and if we understand correctly), a transpension operation declares a variable that represents some unknown coordinate along a new dimension. At some point in the scope of that variable, another operation takes ownership of that dimension variable, taking the original dimension variable out of scope but gaining access a reusable function that abstracts all the code in between that had depended on it. The reusable function can then be applied to a coordinate value of the user's choice.

From a Punctaffy perspective, the dimension variable's original scope is a degree-2 hypersnippet, and the operation that replaces it with a function is one of the degree-1 closing hyperbrackets of that hypersnippet.

Curiously, the degree-2 hypersnippet also gets closed by degree-1 closing hyperbrackets at the *type* level; we might say these type theories assign types to terms that have unmatched closing hyperbrackets. They also have lambdas that *abstract over* terms that have unmatched closing hyperbrackets, so the journey of a closing hyperbracket through the codebase to find its match can potentially be rather circuitous.

At any rate, the affinely typed nature of these dimension variables sometimes gives the impression of an unfortunate quirk of these type theories, especially when the rest of their variables are Cartesian. By relating transpension operators to hyperbrackets, we may manage to express the affine typing in terms of a more intuitive metaphor: A "closing bracket" can't match up with an "opening bracket" that's already been closed.


## Installation and use

This is a library for Racket. To install it from the Racket package index, run `raco pkg install punctaffy`. Then you can put an import like `(require punctaffy)` in your Racket program.

To install it from source, run `raco pkg install --deps search-auto` from the `punctaffy-lib/` directory.

[Documentation for Punctaffy for Racket](http://docs.racket-lang.org/lathe-comforts/index.html) is available at the Racket documentation website, and it's maintained in the `punctaffy-doc/` directory.
