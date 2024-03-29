# Punctaffy

[![CI](https://github.com/lathe/punctaffy-for-racket/actions/workflows/ci.yml/badge.svg)](https://github.com/lathe/punctaffy-for-racket/actions/workflows/ci.yml)

Punctaffy is an experimental library for processing program syntax that has higher-dimensional nested structure.

Most programming languages are designed for programs to be structured in the form of trees, with some (or all) nodes of the tree being delimited using opening and closing brackets. However, occasionally some operations take that a dimension higher, opening with one tree node and closing with some number of tree nodes toward the leaves.

This is common with templating languages. For instance, a quasiquotation operation has a quoted body that begins with the initial `` `...`` tree node and ends with number of `,...` and `,@...` tree nodes. The quasiquotation operation also takes a number of expressions to compute what values should be inserted into those holes in the quoted body, and those expressions are maintained in the same place as the holes their results will be inserted into.

```racket
(define site-base-url "https://docs.racket-lang.org/")

(define (make-sxml-site-link relative-url content)
  `(a
     (@
       (href
         ,(url->string
            (combine-url/relative (string->url site-base-url)
              relative-url))))
     ,@content))

> (make-sxml-site-link "punctaffy/index.html" '("Punctaffy docs"))
'(a
  (@ (href "https://docs.racket-lang.org/punctaffy/index.html"))
  "Punctaffy docs")
```

Quasiquotation isn't the only example. Connection Machine Lisp is a language that was once used for programming Connection Machine supercomputers, and it has a concept of "xappings," key-value data structures where each element resides on a different processor. It has ways to distribute the same behavior to each processor to transform these values, and it has a dedicated notation to assist with this:

```lisp
(defun celsius-to-fahrenheit (c)
  α(+ (* •c 9/5) 32))
 
(celsius-to-fahrenheit '{low→0 mid→50 high→100})
 ⇒ {low→32 mid→122 high→212}
```

That notation has a body that begins with `α...` node and ends with some number of `•...` nodes. The behavior in between is repeated for each xapping entry.

To make it a bit more mundane for the sake of example, let's suppose the `α` notation works on lists instead of xappings, making it a fancy notation for what a Racket programmer would usually write using `map` or `for/list`.

In some programs, the two of them might be used together. Here's some code we can write in Racket today:

```racket
(define (make-sxml-unordered-list items)
  `(ul
     ,@(for/list ([item (in-list items)])
         `(li ,item))))

> (make-sxml-unordered-list (list "Red" "Yellow" "Green"))
'(ul (li "Red") (li "Yellow") (li "Green"))
```

Here's the same code, using the `α` operator to do the list mapping operation:

```racket
(define (make-sxml-unordered-list items)
  `(ul ,@α`(li ,•items)))
```

In the expression ``α`(li ,•items)``, we see the `` `...`` and `,...` tree nodes are nested in between the `α...` and `•...` tree nodes.

In Punctaffy's terms, this is the nesting of one degree-2 hypersnippet inside another. It's just like the nesting of one parenthesized region of code inside another, but one dimension higher than usual.

In fact, the geometric shape of a hypersnippet seems to be deeply related to another higher-dimensional shape called an opetope, where the idea of "dimension" is more rigorously studied. Opeteopes are usually brought up in higher algebra (e.g. higher category theory and higher-dimensional type theory), where it's possible to ask whether two equivalence proofs of dimension N are themselves equivalent via some equivalence proof of dimension (N + 1). When trying to model this precisely, opetopes are one of many possible higher-dimensional geometric shapes that an equivalence proof can take on. Hypersnippets seem to be mostly the same as opetopes; it seems that every opetope is a hypersnippet, but not quite every hypersnippet is an opetope. For a more in-depth look at this, see [Potential Application: Opetopes and Higher Categories](https://docs.racket-lang.org/punctaffy/motivation.html#%28part._potential-use-case-opetopes%29).

Our motivation for using hypersnippets in Punctaffy isn't because we're trying to talk about higher-dimensional algebraic relationships, but it's not unrelated either. In a program tree, a single tree node is like the 1-dimensional path that relates the place the node begins in the code to the place it ends, and the quoted body of a quasiquotation is like the 2-dimensional path swept out by taking the `,...` tree nodes' 1-dimensional paths and pulling them down the tree until they reach the matching `` `...`` tree node.

Regardless of that kind of algebraic interpretation, Punctaffy is driven by syntax. Where there's syntax, there are usability concerns like syntax errors and user-defined syntactic extensions. Let's recall the above example where we mix quasiquotaton and apply-to-all notation in a single program:

```racket
  (define (make-sxml-unordered-list items)
    `(ul ,@α`(li ,•items)))
```

Here we have `` `...`` nested inside `α...` to make ``α`...``. We could also imagine the reverse of this; to quote a piece of code which uses `α...`, we can write `` `α...``, letting the `α...` appear nested inside the `` `...``.

What happens when we nest improperly? For instance, what does this program do?

```racket
  α`(li •,items)
```

This is analogous to writing the program `(while #t (displayln "Hello, world))"`. While some language designers may try to force programs like these to work using creative interpretations, there's little reason to use these kinds of mismatched brackets in the first place. It's a good place to report an error.

So, where do we report the error? Racket's reader doesn't match occurrences of `` `...`` to occurrences of `,...` at read time; instead, these always read successfully as `(quasiquote ...)` and `(unquote ...)`, and it's up to the implementation of the `quasiquote` macro to search its tree-shaped input, looking for occurrences of `unquote`. So now do we extend that search so that it keeps track of the proper nesting of `α...` and `•...`? Does every one of these higher-dimensional operations need to hardcode the grammar of every other?

Currently, in Racket:

* `quasiquote` only knows to skip nested `quasiquote`..`unquote` pairs
* `quasisyntax` only knows to skip nested `quasisyntax`..`unsyntax` pairs
* `quasisyntax/loc` only knows to skip nested `quasisyntax`..`unsyntax` pairs (but not `quasisyntax/loc`..`unsyntax`)

This isn't a problem that usually arises with traditional parentheses. The Racket reader only supports a small set of parentheses, `( ) [ ] { }`, which makes it feasible to hardcode them all. Extending this set is rare; new operations usually just follow the Lispy convention of using the same parentheses as everything else.

What if we did that for higher-dimensional brackets as well, picking a single bracket notation and having most of our operations just use that one? In Punctaffy, we've implemented this approach like so:

Before:

```racket
(define (make-sxml-unordered-list items)
  `(ul ,@α`(li ,•items)))
```

After:

```racket
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

```racket
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

```racket
(define (make-sxml-unordered-list items)
  (with-datum ([(item ...) items])
    (datum (ul (li item) ...))))
```

In Racket's `datum` template DSL, occurrences of `...` cause an item to be repeated some number of times, just like using `α`. A template variable like `item` is statically associated with an ellipsis depth that governs how many ellipses must be applied to it. In this case, `item` has an ellipsis depth of 1, so wherever it appears in a template, it implicitly behaves like `•items`. (If the iteration depth were 4, it would behave like `••••items`.) Meanwhile, unbound identifiers like `ul` and `li` are implicitly quoted, and miscellaneous syntactic landmarks are implicitly quoted as well. For instance, the lists which surround `ul` and `li` are quoted as though they were surrounded with `` ` `` and `,@`.

In the process of explaining how Racket's template DSL works, we've described a *translation* of (a subset of) that DSL into other Racket code. Maybe `α...` and `•...` aren't actually implemented in Racket, but Punctaffy does implement `(list-taffy-map (^< ...))` and `(^> ...)` to serve their purpose here.

A common technique for DSLs in Racket is first to use a parser to preprocess a DSL into a similarly shaped Racket s-expression, then to expand it using a suite of Racket macros. In this case, what we've described isn't a translation into a mere s-expression so much as a translation into hyperbracketed code. In this way, regardless of the experience of using hyperbrackets directly, hyperbrackets provide infrastructure that can be helpful in the implementation of other DSLs.

Unfortunately, we've begun to digress into ideas that aren't fully realized in Punctaffy yet. Most DSLs in Racket can use frameworks like `match`, `syntax-parse`, `ragg`, and `brag` to parse and translate their tree-structured code, but Punctaffy doesn't yet have a parsing framework for hyperbracketed code. As such, implementing the `datum` template DSL in terms of Punctaffy may still be trickier than implementing it the way Racket has.

Punctaffy isn't short on unrealized ambitions; the ["Motivation for Punctaffy" section of the docs](https://docs.racket-lang.org/punctaffy/motivation.html) describes several application areas where we expect Punctaffy's hypersnippet and hyperbracket concepts to come in handy. For now, our explorations have culminated in operations like `taffy-quote` and `list-taffy-map`, which demonstrate a certain technique: the interoperation of multiple notations like these by means of a common hyperbracket notation. There's still much more exploration ahead.


## Installation and use

This is a library for Racket. To install it from the Racket package index, run `raco pkg install punctaffy`. Then you can put an import like `(require punctaffy)` in your Racket program.

To install it from source, run `raco pkg install --deps search-auto` from the `punctaffy-lib/` directory.

[Documentation for Punctaffy for Racket](https://docs.racket-lang.org/punctaffy/index.html) is available at the Racket documentation website, and it's maintained in the `punctaffy-doc/` directory.
