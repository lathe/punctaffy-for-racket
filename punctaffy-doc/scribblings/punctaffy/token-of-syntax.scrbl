#lang parendown scribble/manual

@; punctaffy/scribblings/punctaffy/token-of-syntax.scrbl
@;
@; Hypersnippet data structures and interfaces.

@;   Copyright 2022, 2025 The Lathe Authors
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


@title[#:tag "token-of-syntax"]{Tokens of Syntax Object Tree Content}

@defmodule[punctaffy/syntax-object/token-of-syntax]

Traditionally, a bracket appears as text in a text stream, and this token can be pulled out of the text stream and treated as a string. In Punctaffy, when we recognize @racket[taffy-notation?] @tech{hyperbracket} notations, we need to pull a token out of a program represented by a Racket syntax object. This results in a list of adjacent syntax objects, where each syntax object can have holes in it. Punctaffy supplies a data structure to represent this kind of data, which we call a token of syntax object tree content, or a @deftech{token of syntax} for short.

The holes in a token of syntax are given mutually unique labels, and the labels are part of the token's representation. We call these labels the token's free variables. They can be arbitrary values identified by @racket[equal-always?], but usually, they're interned symbols.

In our representation, a token of syntax can also have nodes in it that represent assertions that they have only one subform once the holes are filled in. At the moment, these assertions are checked only when the token is converted into a list of syntax objects.

(In Punctaffy's @tech{hypersnippet} terminology, a token of syntax is a @tech{degree}-2 hypersnippet of the textual code, as opposed to a string token, which is a degree-1 hypersnippet. We could represent tokens of syntax in a way that's generalizable to arbitrarily high degrees by using @tech{hypernests}, but instead we dedicate some unique attention to this data structure so we can manipulate it efficiently.)


@defproc[(token-of-syntax? [v any/c]) boolean?]{
  Returns whether the value is a @tech{token of syntax}.
}

@defproc[
  (token-of-syntax-with-free-vars<=/c
    [free-vars-set set-equal-always?])
  flat-contract?
]{
  Returns a flat contract which recognizes any @tech{token of syntax} whose set of free variables is the same as or a subset of the given set.
}

@defproc[(singular-token-of-syntax? [v any/c]) boolean?]{
  Returns whether the value is a @tech{token of syntax} that has a single syntax object or a single hole at its root.
  
  Note that if the token has a single hole at its root, that hole could be filled with more than one (or fewer than one) syntax object. What @tt{singular-token-of-syntax?} checks for has to do with representation details of the token of syntax itself, not what its shape is when it's embedded in a syntax object tree.
}

@deftogether[(
  @defidform[token-of-syntax-beginning-with-splice]
  @defform[
    #:link-target? #f
    
    (token-of-syntax-beginning-with-splice elements)
    
    #:contracts
    (
      [elements
        (or/c (list/c)
          (cons/c singular-token-of-syntax?
            (non-empty-listof singular-token-of-syntax?)))])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (token-of-syntax-beginning-with-splice elements)
  ]
  @defproc[
    (token-of-syntax-beginning-with-splice? [v any/c])
    boolean?
  ]
  @defproc[
    (token-of-syntax-beginning-with-splice-elements
      [token token-of-syntax-beginning-with-splice?])
    (or/c (list/c)
      (cons/c singular-token-of-syntax?
        (non-empty-listof singular-token-of-syntax?)))
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{token of syntax} consisting of a sequence of fewer than one or more than one syntax object or hole.
  
  The element list is a list of @racket[singular-token-of-syntax?] values. This just prevents @tt{token-of-syntax-beginning-with-splice?} values from being nested, which would otherwise be an unnecessary source of variation between token values.
  
  @constructor-enforces-autopticity[]
}

@deftogether[(
  @defidform[token-of-syntax-beginning-with-assert-singular]
  @defform[
    #:link-target? #f
    (token-of-syntax-beginning-with-assert-singular body)
    #:contracts ([body token-of-syntax?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (token-of-syntax-beginning-with-assert-singular body)
  ]
  @defproc[
    (token-of-syntax-beginning-with-assert-singular? [v any/c])
    boolean?
  ]
  @defproc[
    (token-of-syntax-beginning-with-assert-singular-body
      [token token-of-syntax-beginning-with-assert-singular?])
    token-of-syntax?
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{token of syntax} which carries an assertion that once it's used to build a list of syntax objects, that list will have a single element.
  
  This node type makes up for the fact that all compositions of tokens of syntax are splicing compositions in the sense of @racket[unquote-splicing] or @racket[unsyntax-splicing]. Using this, it's possible to assert that a certain use site actually only admits a single element, as would be the case with a non-splicing @racket[unquote] or @racket[unsyntax].
  
  @constructor-enforces-autopticity[]
}

@deftogether[(
  @defidform[token-of-syntax-beginning-with-splicing-free-var]
  @defform[
    #:link-target? #f
    (token-of-syntax-beginning-with-splicing-free-var var)
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (token-of-syntax-beginning-with-splicing-free-var var)
  ]
  @defproc[
    (token-of-syntax-beginning-with-splicing-free-var? [v any/c])
    boolean?
  ]
  @defproc[
    (token-of-syntax-beginning-with-splicing-free-var-var
      [token token-of-syntax-beginning-with-splicing-free-var?])
    any/c
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{token of syntax} which consists of nothing but a single hole.
  
  The hole is labeled with an arbitrary object to use as a free variable name, which will be identified using @racket[equal-always?].
  
  When this token is converted to a list of syntax objects, the caller performing that conversion will specify some list of syntax objects to substitute for the variable, and that list will be the result. In the name of the node type, we specifically refer to this a "splicing" free variable occurrence, since the way it deals with a list of trees makes it more analogous to @racket[unquote-splicing] or @racket[unsyntax-splicing] than to @racket[unquote] or @racket[unsyntax].
  
  @constructor-enforces-autopticity[]
}

@deftogether[(
  @defidform[token-of-syntax-beginning-with-syntax]
  @defform[
    #:link-target? #f
    (token-of-syntax-beginning-with-syntax stx-example e)
    #:contracts ([stx-example syntax?] [e token-of-syntax?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (token-of-syntax-beginning-with-syntax stx-example e)
  ]
  @defproc[
    (token-of-syntax-beginning-with-syntax? [v any/c])
    boolean?
  ]
  @defproc[
    (token-of-syntax-beginning-with-syntax-stx-example
      [token token-of-syntax-beginning-with-syntax?])
    syntax?
  ]
  @defproc[
    (token-of-syntax-beginning-with-syntax-e
      [token token-of-syntax-beginning-with-syntax?])
    token-of-syntax?
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{token of syntax} which has a syntax object wrapper at its root.
  
  When this token is converted to a list of trees, it asserts that the given @racket[e] token results in a single value, and then it invokes @racket[datum->syntax] to wrap that value as a syntax object. The the lexical information, source location, and syntax properties of the wrapper are copied from the given @racket[stx-example].
  
  @constructor-enforces-autopticity[]
}

@deftogether[(
  @defidform[token-of-syntax-beginning-with-box]
  @defform[
    #:link-target? #f
    (token-of-syntax-beginning-with-box element)
    #:contracts ([element token-of-syntax?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (token-of-syntax-beginning-with-box element)
  ]
  @defproc[(token-of-syntax-beginning-with-box? [v any/c]) boolean?]
  @defproc[
    (token-of-syntax-beginning-with-box-element
      [token token-of-syntax-beginning-with-box?])
    token-of-syntax?
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{token of syntax} which has an immutable box at its root.
  
  When this token is converted to a list of trees, it asserts that the given @racket[element] token results in a single value, and then it wraps that value in an immutable box.
  
  @constructor-enforces-autopticity[]
}

@deftogether[(
  @defidform[token-of-syntax-beginning-with-vector]
  @defform[
    #:link-target? #f
    (token-of-syntax-beginning-with-vector elements)
    #:contracts ([elements token-of-syntax?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (token-of-syntax-beginning-with-vector elements)
  ]
  @defproc[
    (token-of-syntax-beginning-with-vector? [v any/c])
    boolean?
  ]
  @defproc[
    (token-of-syntax-beginning-with-vector-elements
      [token token-of-syntax-beginning-with-vector?])
    token-of-syntax?
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{token of syntax} which has an immutable vector at its root.
  
  When this token is converted to a list of trees, it takes the list of trees that result from the given @racket[elements] token and wraps them as the elements of an immutable vector.
  
  @constructor-enforces-autopticity[]
}

@deftogether[(
  @defidform[token-of-syntax-beginning-with-prefab-struct]
  @defform[
    #:link-target? #f
    (token-of-syntax-beginning-with-prefab-struct key elements)
    #:contracts
    (
      [prefab-example immutable-prefab-struct?]
      [elements token-of-syntax?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (token-of-syntax-beginning-with-prefab-struct
      prefab-struct-example elements)
  ]
  @defproc[
    (token-of-syntax-beginning-with-prefab-struct? [v any/c])
    boolean?
  ]
  @defproc[
    (token-of-syntax-beginning-with-prefab-struct-prefab-struct-example
      [token token-of-syntax-beginning-with-prefab-struct?])
    immutable-prefab-struct?
  ]
  @defproc[
    (token-of-syntax-beginning-with-prefab-struct-elements
      [token token-of-syntax-beginning-with-prefab-struct?])
    token-of-syntax?
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{token of syntax} which has an immutable prefab struct at its root.
  
  When this token is converted to a list of trees, it takes the list of trees that result from the given @racket[elements] token and wraps them as the fields of an immutable prefab struct with the same @racket[prefab-struct-key] as @racket[prefab-struct-example]. If the prefab key isn't consistent with the computed number of fields, this raises an error. For now, this error is reported in terms of an internal call to @racket[make-prefab-struct].
  
  @constructor-enforces-autopticity[]
}

@deftogether[(
  @defidform[token-of-syntax-beginning-with-list*]
  @defform[
    #:link-target? #f
    (token-of-syntax-beginning-with-list* elements tail)
    #:contracts ([elements token-of-syntax?] [tail token-of-syntax?])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (token-of-syntax-beginning-with-list* key elements)
  ]
  @defproc[(token-of-syntax-beginning-with-list*? [v any/c]) boolean?]
  @defproc[
    (token-of-syntax-beginning-with-list*-elements
      [token token-of-syntax-beginning-with-list*?])
    token-of-syntax?
  ]
  @defproc[
    (token-of-syntax-beginning-with-list*-tail
      [token token-of-syntax-beginning-with-list*?])
    token-of-syntax?
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{token of syntax} which has a possibly improper list its root.
  
  When this token is converted to a list of trees, it asserts that the given @racket[tail] token results in a single value, and then it invokes @racket[list*] to wrap that as the tail of a possibly improper list beginning with the elements obtained from the result of @racket[elements].
  
  If @racket[tail] results in a single tree that's a proper list, the result will also be a single tree that's a proper list.
  
  If @racket[elements] results in a list of zero trees, the result will just be the result of @racket[tail], even if that's not a @racket[pair?].
  
  Unlike with @racket[token-of-syntax-beginning-with-splice?] nodes, we make no attempt to enforce that two @tt{token-of-syntax-beginning-with-list*?} nodes aren't nested in a way that could be combined into a single node. (TODO: Should we?)
  
  @constructor-enforces-autopticity[]
}

@deftogether[(
  @defidform[token-of-syntax-beginning-with-other-value]
  @defform[
    #:link-target? #f
    (token-of-syntax-beginning-with-other-value value)
    #:contracts
    (
      [value
        (not/c
          (or/c
            syntax?
            (and/c box? immutable?)
            (and/c vector? immutable?)
            immutable-prefab-struct?
            pair?))])
  ]
  @defform[
    #:kind "match expander"
    #:link-target? #f
    (token-of-syntax-beginning-with-other-value value)
  ]
  @defproc[
    (token-of-syntax-beginning-with-other-value? [v any/c])
    boolean?
  ]
  @defproc[
    (token-of-syntax-beginning-with-other-value-value
      [token token-of-syntax-beginning-with-other-value?])
    (not/c
      (or/c
        syntax?
        (and/c box? immutable?)
        (and/c vector? immutable?)
        immutable-prefab-struct?
        pair?))
  ]
)]{
  Struct-like operations which construct and deconstruct a @tech{token of syntax} which has a miscellaneous value at its root.
  
  When this token is converted to a list of trees, it results in just one tree, namely the given value.
  
  The value must not be a syntax object, an immutable box, an immutable vector, an immutable prefab struct, or a pair. This just prevents @tt{token-of-syntax-beginning-with-other-value?} values from being represented in alternative ways using the other token of syntax constructors, which would be an unnecessary source of variation between token values.
  
  (TODO: What if Racket's syntax supports more values in the future? In @racket[taffy-let] and our other hyperbracketed operations, we defensively disallow certain values that people might want hypersnippets to reach into someday, like @racket[hash?] and @racket[regexp?] values. Maybe we should disallow those here too. Alternatively, maybe we should just allow every type of value here, a policy which might be good for performance so that we don't traverse into certain data instances further than necessary.)
  
  @constructor-enforces-autopticity[]
}

@defproc[
  (list->token-of-syntax [tokens (listof token-of-syntax?)])
  token-of-syntax?
]{
  Given any number of @tech[#:key "token of syntax"]{tokens of syntax}, returns a single token of syntax that converts to the same list of syntaxes they all do when their resulting lists are concatenated together.
}

@defproc[
  (token-of-syntax-substitute
    [prefix token-of-syntax?]
    [ suffixes
      (and/c hash? hash-equal-always?
        (hash/c any/c token-of-syntax?))])
  token-of-syntax?
]{
  Transforms a @tech{token of syntax} by substituting other tokens of syntax for its free variables.
}

@defproc[
  (token-of-syntax->syntax-list
    [prefix token-of-syntax?]
    [suffixes (and/c hash? hash-equal-always? (hash/c any/c list?))])
  list?
]{
  Converts a @tech{token of syntax} into a list of syntax objects by substituting other lists of syntax objects for its free variables.
  
  This operation may fail if assertions in the token are unmet, such as the assertions of single-element intermediate results made by nodes like @racket[token-of-syntax-beginning-with-assert-singular?] and @racket[token-of-syntax-beginning-with-box?].
}

@defproc[
  (syntax->token-of-syntax [stx any/c])
  singular-token-of-syntax?
]{
  Constructs a @tech{token of syntax} which has the given syntax object at its root.
  
  This is like @racket[token-of-syntax-beginning-with-other-value], but it also traverses into syntax objects, immutable boxes, immutable vectors, immutable prefab structs, and pairs to construct the appropriate token nodes.
}

@defproc[
  (token-of-syntax-autoquote
    [quote-expr (-> any/c any/c)]
    [datum->result--id identifier?]
    [token token-of-syntax?])
  singular-token-of-syntax?
]{
  Constructs a @tech{token of syntax} which has the same free variables as @racket[token] and essentially serves as its quoted form.
  
  We'll call the resulting token @racket[_quotation-token].
  
  When @racket[token-of-syntax->syntax-list] converts @racket[_quotation-token] to a list of trees, the result is a list containing some number of Racket expressions which, when run, result in lists of trees. When these lists of trees are appended, they form the result of a simulated invocation of @racket[token-of-syntax->syntax-list] on @racket[token].
  
  The substitutions this simulated call supplies for @racket[token]'s free variables are obtained from the substitutions of @racket[_quotation-token]'s corresponding free variables. In particular, the substitution of each of @racket[_quotation-token]'s free variables should be a list of Racket expressions, each of which should return a list of trees when it's run. The concatenation of these lists of trees is the substitution for @racket[token]'s corresponding free variable.
  
  @; TODO: Figure out why
  The @racket[quote-expr] argument should be a function that takes a Racket syntax object and returns another Racket syntax object that represents an expression which quotes it. This is applied to @racket[token-of-syntax-beginning-with-other-value?] nodes of the token, and it effectively determines what kind of quoting is performed. For instance, @racket[quote-expr] could be @racket[(lambda (_expr) @#,elem{@racketmetafont{@literal{#`'#,}}@var{expr}})] to do the usual kind of quoting of values, which preserves many values but converts several types of mutable data structures into immutable ones. (TODO: Test with multiple choices of @racket[quote-expr] to be sure it works, and see if we can explain better.)
  
  The @racket[datum->result--id] argument should be an identifier bound to a syntax that can be used like @racket[(_datum->result _stx-example _datum-expr)] to transfer a syntax wrapper. For instance, the following syntax would create syntax wrappers that carry over the lexical information of the original syntax wrappers, but not their source locations or syntax properties:
  
  @racketblock[
    (define-syntax-parse-rule/autoptic
      (_datum->result _stx-example _datum)
      (syntax->datum (quote-syntax _stx-example #:local) _datum))
  ]
  
  (TODO: Test with multiple choices of @racket[datum->result--id] to be sure it works, and see if we can explain better.)
}
