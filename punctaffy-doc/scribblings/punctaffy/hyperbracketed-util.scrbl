#lang parendown scribble/manual

@; punctaffy/scribblings/punctaffy/hyperbracketed-util.scrbl
@;
@; Various hyperbracketed operations.

@;   Copyright 2021, 2022 The Lathe Authors
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
    'parendown
    'punctaffy
    'punctaffy/quote))


@title[#:tag "hyperbracketed-util"]{Hyperbracketed Operations}



@local-table-of-contents[]



@section[#:tag "quote"]{Hyperbracketed Quotation Operators}

@defmodule[punctaffy/quote]

Quasiquotation is perhaps the most widespread example of an operation with a subterm of the shape that's known in Punctaffy as a "@tech{degree}-2 @tech{hypersnippet}." It may not be the absolute best example of hypersnippet syntax, since quotation is a complex problem domain with additional concerns around escape sequences and round-tripping, but it is the example that motivates the Punctaffy library.

The @racketmodname[punctaffy/quote] module is for variations of Racket's own quotation forms that have been redesigned to use Punctaffy's @tech{hyperbrackets} for their syntax. This allows them to gracefully support nesting, as in the quotation of code that is itself performing quotation, without requiring that code to be modified with escape sequences. Furthermore, since each of these quotation operators will use the @emph{same} hyperbracket syntax to represent its nesting structure, they can each gracefully nest within each other.

This design leads to a more consistent experience than the current situation in Racket: At the time of writing, Racket's @racket[quasiquote] and @racket[quasisyntax] can accommodate nested occurrences of themselves but not of each other. Racket's @racket[quasisyntax/loc] can accommodate nested occurrences of @racket[quasisyntax] but not of itself.

For instance, @racket[list-taffy-map] can accommodate nested occurrences of @racket[taffy-quote], as demonstrated in @secref["intro"].


@defform[
  #:literals (^<d ^< ^>)
  (taffy-quote (^< content-and-splices))
  #:grammar
  [
    (content-and-splices
      atom
      ()
      (content-and-splices . content-and-splices)
      #&content-and-splices
      #(content-and-splices ...)
      #s(prefab-key-datum content-and-splices ...)
      (^<d degree deeper-content-and-splices ...)
      (^> spliced-list-expr ...))]
  #:contracts ([spliced-list-expr list?])
]{
  A variant of @racket[quote] or @racket[quasiquote] that uses @tech{hyperbrackets} to delimit a quoted @tech{degree}-2 @tech{hypersnippet} of datum values. Expressions can be supplied within the degree-1 @tech{holes} of this hypersnippet to cause their resulting lists to be spliced into the surrounding datum content.
  
  Specifically, the holes behave like @racket[unquote-splicing]. It's possible to achieve the behavior of @racket[unquote] by wrapping the expression in a call to @racket[list].
  
  The @racket[content-and-splices] is converted to a list of datum values as follows:
  
  @specsubform[atom]{
    Produces a single datum: Itself.
    
    The @racket[atom] value must be an instance of one of a specific list of types. Generally, we intend to support exactly those values which are @racket[equal?] to some immutable value that can appear in Racket code. Some of these values can accommodate internal s-expressions, including spliced expressions, and they're covered by the other cases of this grammar (@racket[list?], @racket[box?], @racket[pair?], @racket[vector?], and instances of immutable prefab structure types). The @racket[atom] case is a catch-all for those values which are unlikely to ever accommodate internal s-expressions.
    
    Values supported:
    
    @itemlist[
      @item{This operation supports quoting @racket[boolean?], @racket[char?], @racket[keyword?], @racket[number?], and @racket[extflonum?] values. These are immutable values with reader syntaxes, so they fit the description exactly.}
      
      @item{This operation supports quoting @racket[string?] values. If the value is a mutable string, it is converted to its immutable equivalent.}
      
      @; TODO DOCUMENT-TOKEN-OF-SYNTAX: Figure out if this supports quoting identifiers that have transformer bindings that implement `prop:taffy-notation-akin-to-^<>d`, and if so, consider documenting that fact.
      @item{This operation supports quoting @racket[symbol?] values as long as they aren't hyperbracket notation (i.e. identifiers which have transformer bindings that implement @racket[prop:taffy-notation]). Only interned symbols have a reader syntax, but this operation accepts uninterned and unreadable symbols anyway. (After all, symbols exist to be used in Racket code, so even the ones that can't be found in @emph{textual} Racket code can be found in some other kind.)}
    ]
    
    Notable exclusions:
    
    @itemlist[
      @item{Out of caution, this operation does not yet support quoting @racket[hash?] values. There are several places where the design of this support could go wrong: Hashes have unspecified iteration order (potentially affecting the order splices would be evaluated in), and their keys are unique (potentially unique both after and @emph{before} processing hyperbrackets and splices). There isn't much of a precedent, either; Racket's @racket[quasiquote] seems to support @racket[unquote] in a hash entry's value, but @racket[syntax] and @racket[quasisyntax] leave hash entries' values alone, processing neither template variables nor @racket[unsyntax] in that location. It's possible that treating hashes as unquotable values will be the design that raises the fewest questions.}
      
      @item{Out of caution, this operation does not yet support quoting @racket[compiled-expression?] or @racket[regexp?] values. These values' reader syntaxes are complex languages, and it's easy to conceive of the idea that they may someday be extended in in ways that support internal s-expressions.}
      
      @item{Out of caution, this operation does not yet support quoting @racket[flvector?], @racket[fxvector?], or @racket[bytes?] values. These are mutable values, and it's possible Racket will someday introduce immutable equivalents that are @racket[equal?] to them.}
    ]
  }
  
  @specsubform[()]{
    Produces a single datum: Itself, an empty list.
  }
  
  @specsubform[(content-and-splices . content-and-splices)]{
    Produces a single datum by combining some datum values using @racket[list*]. The first @racket[content-and-splices] produces any number of leading arguments for the @racket[list*] call. The second @racket[content-and-splices] must produce a single datum, and that datum serves as the final @racket[list*] argument, namely the tail.
  }
  
  @specsubform[#&content-and-splices]{
    Produces a single datum: An immutable box which contains the datum value produced by the given @racket[content-and-splices] term. The given @racket[content-and-splices] term must produce a single datum.
  }
  
  @specsubform[#(content-and-splices ...)]{
    Produces a single datum: An immutable vector which contains all the datum values produced by each of the given @racket[content-and-splices] terms.
  }
  
  @specsubform[#s(prefab-key-datum content-and-splices ...)]{
    Produces a single datum: A prefab struct which contains all the datum values produced by each of the given @racket[content-and-splices] terms. The prefab struct's key is given by @racket[_prefab-key-datum], which must be a @racket[prefab-key?] value which specifies no mutable fields.
  }
  
  @specsubform[
    #:literals (^<d)
    (^<d degree deeper-content-and-splices ...)
  ]{
    Parses as an opening hyperbracket, and produces datum values which denote a similar opening hyperbracket.
    
    Within the @racket[deeper-content-and-splices] of an opening hyperbracket like this of some degree N, the same grammar as @racket[content-and-splices] applies except that occurrences of @racket[(^>d degree _shallower-content-and-splices ...)] for degree less than N instead serve as hyperbrackets that close this opening hyperbracket.
    
    Within the @racket[_shallower-content-and-splices] of a closing hyperbracket of some degree N, the same grammar applies that did at the location of the corresponding opening bracket, except that occurrences of @racket[(^>d degree deeper-content-and-splices ...)] for degree less than N instead serve as hyperbrackets that close this closing hyperbracket (resuming the body of the opening hyperbracket again).
    
    (TODO: That's a mouthful. Can we reword this?)
  }
  
  @specsubform[#:literals (^>) (^> spliced-list-expr ...)]{
    Evaluates the expressions @racket[spliced-list-expr ...] and produces whatever datum values they return. Each expression must return a list; the elements of the lists, appended together, are the datum values to return. The elements can be any type of value, even types that this operation doesn't allow in the quoted content.
  }
  
  Each intermediate @racket[content-and-splices] may result in any number of datum values, but the overall @racket[content-and-splices] must result in exactly one datum. If it results in some other number of datum values, an error is raised.
  
  Graph structure in the input is not necessarily preserved. If the input contains a reference cycle, this operation will not necessarily finish expanding. This situation may be accommodated better in the future, either by making sure this graph structure is preserved or by producing a more informative error message.
  
  @; TODO DOCUMENT-TOKEN-OF-SYNTAX: Document `prop:taffy-notation-akin-to-^<>d`.
  This operation parses hyperbracket notation in its own way. It supports all the individual notations currently exported by Punctaffy (including the @racket[^<d], @racket[^>d], @racket[^<], and @racket[^>] notations mentioned here), and it also supports some user-defined operations if they're defined using @racket[prop:taffy-notation-akin-to-^<>d]. Other @racket[prop:taffy-notation] notations are not yet supported but may be supported in the future.
  
  For examples of using @tt{taffy-quote}, see @secref["intro"].
  
  @; TODO: Even though we can link to examples in the intro, consider putting some examples on this page as well.
}

@defform[
  #:literals (^<d ^< ^>)
  (taffy-quote-syntax maybe-local (^< content-and-splices))
  #:grammar
  [
    (maybe-local
      (code:line)
      #:local)
    (content-and-splices
      atom
      ()
      (content-and-splices . content-and-splices)
      #&content-and-splices
      #(content-and-splices ...)
      #s(prefab-key-datum content-and-splices ...)
      (^<d degree deeper-content-and-splices ...)
      (^> spliced-list-expr ...))]
  #:contracts ([spliced-list-expr list?])
]{
  Like @racket[taffy-quote], but instead of producing a datum, produces a syntax object.
  
  If the @racket[#:local] option is not supplied, the scope sets of the quoted content are pruned using the same method as @racket[quote-syntax] to omit the scope for local bindings that surround the @tt{taffy-quote-syntax} expression. The only syntax objects in the result that are pruned this way are the ones that correspond to the quoted content; syntax objects that are spliced into the result are left alone.
  
  Note that the result values of spliced expressions must still be non-syntax lists. The @racket[syntax->list] function may come in handy.
  
  Whereas @racket[taffy-quote] imitates @racket[quote] and @racket[quasiquote], @racket[taffy-quote-syntax] imitates @racket[quote-syntax].
  
  It may be tempting to compare the splicing support of @tt{taffy-quote-syntax} to the splicing support of @racket[quasisyntax]. However, @racket[quasisyntax] supports template variables and ellispes, and @tt{taffy-quote-syntax} does not. In the future, Punctaffy may offer a @tt{taffy-syntax} operation that works more like @racket[quasisyntax]. For a little more in-depth exploration of what @tt{taffy-syntax} would hypothetically look like, see @secref["potential-use-case-ellipsis-unsyntax"].
  
  @; TODO: Update that `taffy-syntax` remark if and when we implement `taffy-syntax`.
}




@section[#:tag "let"]{Hyperbracketed Binding Operators}

@defmodule[punctaffy/let]

This module uses the higher-dimensional lexical structure afforded by @tech{hyperbrackets} to define operations that use a kind of higher-dimensional lexical scope.


@defform[
  #:literals (^<d ^< ^>)
  (taffy-let ([id val-expr] ...) (^< body-expr-and-splices))
  #:grammar
  [
    (body-expr-and-splices
      atomic-form
      ()
      (body-expr-and-splices . body-expr-and-splices)
      #&body-expr-and-splices
      #(body-expr-and-splices ...)
      #s(prefab-key-datum body-expr-and-splices ...)
      (^<d degree deeper-body-expr-and-splices ...)
      (^> spliced-expr))]
]{
  A variant of @racket[let] that uses @tech{hyperbrackets} to delimit a lexical scope in the shape of a @tech{degree}-2 @tech{hypersnippet}. Expressions supplied in the degree-1 @tech{holes} of this hypersnippet behave just as they would normally but without the variable bindings in scope.
  
  The @racket[body-expr-and-splices] is converted to a syntax object as follows:
  
  @specsubform[atomic-form]{
    Produces itself.
    
    The @racket[atomic-form] expression must be represented by an instance of one of a specific list of types. Generally, we intend to support exactly those representations which can appear in Racket code. Some of these values can accommodate internal s-expressions, including spliced expressions, and they're covered by the other cases of this grammar (@racket[list?], @racket[box?], @racket[pair?], @racket[vector?], and instances of immutable prefab structure types). The @racket[atomic-form] case is a catch-all for those values which are unlikely to ever accommodate internal s-expressions.
    
    Values supported:
    
    @itemlist[
      @item{This operation accommodates subforms represented by @racket[string?], @racket[boolean?], @racket[flvector?], @racket[fxvector?], @racket[char?], @racket[bytes?], @racket[keyword?], @racket[number?], and @racket[extflonum?] values. These are representations with reader syntaxes, so they fit the description exactly.}
      
      @; TODO DOCUMENT-TOKEN-OF-SYNTAX: Figure out if this accommodates subforms represented by `symbol?` values that have transformer bindings that implement `prop:taffy-notation-akin-to-^<>d`, and if so, consider documenting that fact.
      @item{This operation accommodates subforms represented by @racket[symbol?] values as long as they aren't hyperbracket notation (i.e. identifiers which have transformer bindings that implement @racket[prop:taffy-notation]). Only interned symbols have a reader syntax, but this operation accepts uninterned and unreadable symbols anyway. (After all, symbols exist to be used in Racket code, so even the ones that can't be found in @emph{textual} Racket code can be found in some other kind.)}
    ]
    
    Notable exclusions:
    
    @itemlist[
      @item{Out of caution, this operation does not yet accommodate subforms represented by @racket[hash?] values. Hash keys must be unique, both after and @emph{before} processing hyperbrackets, and this may lead to an unnecessarily confusing design.}
      
      @item{Out of caution, this operation does not yet support quoting @racket[compiled-expression?] or @racket[regexp?] values. These values' reader syntaxes are complex languages, and it's easy to conceive of the idea that they may someday be extended in in ways that support internal s-expressions. (TODO: Reconsider this.)}
    ]
    
    (TODO: Currently, we actually let all kinds of representations through, including the ones we've listed as being excluded here. Let's fix this.)
  }
  
  @specsubform[()]{
    Produces itself, a syntax value represented by an empty list.
  }
  
  @specsubform[(body-expr-and-splices . body-expr-and-splices)]{
    Produces a syntax value similar to itself, but with the pair's head and tail processed recursively.
  }
  
  @specsubform[#&body-expr-and-splices]{
    Produces a syntax value similar to itself, but with the box's value processed recursively. The box must be immutable.
    
    (TODO: Actually, we don't enforce immutability yet.)
  }
  
  @specsubform[#(body-expr-and-splices ...)]{
    Produces a syntax value similar to itself, but with the vector's elements each processed recursively. The vector must be immutable.
    
    (TODO: Actually, we don't enforce immutability yet.)
  }
  
  @specsubform[#s(prefab-key-datum body-expr-and-splices ...)]{
    Produces a syntax value similar to itself, but with the prefab struct's field values each processed recursively. The prefab struct must not have any mutable fields.
    
    (TODO: Actually, we don't enforce immutability yet.)
  }
  
  @specsubform[
    #:literals (^<d)
    (^<d degree deeper-body-expr-and-splices ...)
  ]{
    Parses as an opening hyperbracket, and produces a syntax object which denotes a similar opening hyperbracket. The exact way the hyperbracket is re-encoded as syntax is unspecified.
    
    Within the @racket[deeper-body-expr-and-splices] of an opening hyperbracket like this of some degree N, the same grammar as @racket[body-expr-and-splices] applies except that occurrences of @racket[(^>d degree _shallower-body-expr-and-splices ...)] for degree less than N instead serve as hyperbrackets that close this opening hyperbracket.
    
    Within the @racket[_shallower-body-expr-and-splices] of a closing hyperbracket of some degree N, the same grammar applies that did at the location of the corresponding opening bracket, except that occurrences of @racket[(^>d degree deeper-body-expr-and-splices ...)] for degree less than N instead serve as hyperbrackets that close this closing hyperbracket (resuming the body of the opening hyperbracket again).
    
    (TODO: That's a mouthful. Can we reword this?)
  }
  
  @specsubform[#:literals (^>) (^> spliced-expr)]{
    Produces an expression which, when evaluated, is equivalent to @racket[spliced-expr].
    
    When this syntax object appears in a context where it's quoted, like as a subform of an expression that's a @racket[quote] form, a box, a vector, or a prefab struct, the result is unspecified.
  }
  
  As noted, all boxes, vectors, and prefab structs that are encountered in the body must be immutable. Racket's reader usually produces immutable boxes and immutable vectors as syntax anyway, and it usually refuses to produce mutable prefab structs as syntax, so the presence of mutability indicates a devoted effort is underway somewhere. If this operation cloned the object to process its elements, the fact that the result was a different mutable object than the original might interfere with whatever that devoted effort was meant to accomplish. Instead, out of caution, the presence of a mutable box, vector, or prefab struct is currently treated as an error.
  
  Graph structure in the input is not necessarily preserved. If the input contains a reference cycle, this operation will not necessarily finish expanding. This situation may be accommodated better in the future, either by making sure this graph structure is preserved or by producing a more informative error message.
  
  @; TODO DOCUMENT-TOKEN-OF-SYNTAX: Document `prop:taffy-notation-akin-to-^<>d`.
  This operation parses hyperbracket notation in its own way. It supports all the individual notations currently exported by Punctaffy (including the @racket[^<d], @racket[^>d], @racket[^<], and @racket[^>] notations mentioned here), and it also supports some user-defined operations if they're defined using @racket[prop:taffy-notation-akin-to-^<>d]. Other @racket[prop:taffy-notation] notations are not yet supported but may be supported in the future.
  
  @examples[
    #:eval (example-eval)
    (eval:alts
      (pd _/ let ([x 5])
        (taffy-let ([_x (+ 1 2)]) _/ ^<
          (+ (* 10 _x) _/ ^> _x)))
      35)
    (eval:alts
      (pd _/ taffy-let () _/ ^<
        (if #f
          (^> _/ error "whoops")
          "whew"))
      "whew")
  ]
}

@defform[
  #:literals (^<d ^< ^>)
  (list-taffy-map (^< body-expr-and-splices))
  #:grammar
  [
    (body-expr-and-splices
      atomic-form
      ()
      (body-expr-and-splices . body-expr-and-splices)
      #&body-expr-and-splices
      #(body-expr-and-splices ...)
      #s(prefab-key-datum body-expr-and-splices ...)
      (^<d degree deeper-body-expr-and-splices ...)
      (^> lst-expr))]
  #:contracts ([lst-expr list?])
]{
  A variant of @racket[map] that uses @tech{hyperbrackets} to delimit the transformation code in a @tech{degree}-2 @tech{hypersnippet}. Expressions supplied in the degree-1 @tech{holes} of this hypersnippet are evaluated first, and they supply the lists to iterate over. There must be at least one list given to iterate over, and all the lists must be of the same length.
  
  Per @racket[map], the result of the body on each iteration must be a single value. The overall result is a list of the body's results in the order they were generated.
  
  The body hypersnippet is parsed according to the same rules as @racket[taffy-let].
  
  @examples[
    #:eval (example-eval)
    (eval:alts
      (pd _/ list-taffy-map _/ ^<
        (format "~a, ~a!"
          (^> _/ list "Hello" "Goodnight")
          (^> _/ list "world" "everybody")))
      (list "Hello, world!" "Goodnight, everybody!"))
  ]
}

@defform[
  #:literals (^<d ^< ^>)
  (list-taffy-bind (^< body-expr-and-splices))
  #:grammar
  [
    (body-expr-and-splices
      atomic-form
      ()
      (body-expr-and-splices . body-expr-and-splices)
      #&body-expr-and-splices
      #(body-expr-and-splices ...)
      #s(prefab-key-datum body-expr-and-splices ...)
      (^<d degree deeper-body-expr-and-splices ...)
      (^> lst-expr))]
  #:contracts ([lst-expr list?])
]{
  A variant of @racket[append-map] (named like @racket[list-bind] from Lathe Comforts) that uses @tech{hyperbrackets} to delimit the transformation code in a @tech{degree}-2 @tech{hypersnippet}. Expressions supplied in the degree-1 @tech{holes} of this hypersnippet are evaluated first, and they supply the lists to iterate over. There must be at least one list given to iterate over, and all the lists must be of the same length.
  
  Per @racket[append-map], the result of the body on each iteration must be a list. The overall result is the concatenation of the body's list results in the order they were generated.
  
  The body hypersnippet is parsed according to the same rules as @racket[taffy-let].
  
  @examples[
    #:eval (example-eval)
    (eval:alts
      (pd _/ list-taffy-bind _/ ^<
        (list (^> _/ list 1 3 5) (^> _/ list 2 4 6)))
      (list 1 2 3 4 5 6))
  ]
}
