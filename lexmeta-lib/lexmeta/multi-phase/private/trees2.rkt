#lang parendown racket/base

; trees2.rkt
;
; Data structures for encoding the kind of higher-order structure that
; occurs in higher quasiquotation.

(require #/only-in racket/list make-list)

(require #/only-in lathe expect w-)

(require "../../private/util.rkt")

(provide #/all-defined-out)


#|

Here's an example of a degree-4 hypersnippet along with variations where its high-degree holes are removed so that it's easier to see its matching structure at a glance:

  ;
  (                                       )
^2(                      ,( )             )
^3(         ~2( ,(       ,( )     ) )     )
^4( ~3( ~2( ~2( ,( ,( ,( ,( ) ) ) ) ) ) ) )

And here's an example of running an algorithm from left to right across the sequence of brackets to verify that it's properly balanced:

   | 4
       | 3 (4, 4, 4)
           | 4 (3 (4, 4, *), 3 (4, 4, 4))
               | 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))
                  | 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))
                     | 3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))))
                        | 4 (3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))))
                           | 1 (4 (3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))))))
                             | 4 (3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))))
                               | 3 (4, 4, 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))))
                                 | 4 (3 (4, 4, *), 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4))))
                                   | 2 (4 (3 (4, 4, *), *), 4 (3 (4, 4, *), 3 (4, 4, 4)))
                                     | 4 (3 (4, 4, *), 3 (4, 4, 4))
                                       | 3 (4, 4, 4)
                                         | 4
                                           | 0

In that example, the notation "|" represents the cursor as it runs through the brackets shown above. The notation "*" represents parts of the state that are unnecessary to keep track of. The notation "4" by itself is shorthand for "4 ()", which shows a 0-element list as shorthand for the lowest-degree parts of a full 4-element list "4 (3 (*, *, *), 2 (*, *), 1 (*, *), 0 ())". Once fully expanded, the numbers are superfluous; they just represent the length of the list that follows, which corresponds with the degree of the current region in the syntax.

The algorithm proceeds by consuming a bracket, restoring the corresponding element of the history (counting from the right to the left in this example), and finally replacing each element of the looked-up state with the previous state if it's a slot of lower degree than the bracket is. (That's why so many parts of the history are "*"; if they're ever used, those parts will necessarily be overwritten anyway.)

If we introduce a shorthand ">" that means "this element is a duplicate of the element to the right," we can represent things more economically:

   | 4
       | 3 (>, >, 4)
           | 4 (>, 3 (>, >, 4))
               | 2 (>, 4 (>, 3 (>, >, 4)))
                  | 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))
                     | 3 (>, 4, 4 (3 (4, 4, *), 2 (>, 4 (>, 3 (>, >, 4)))))
                        | 4 (3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))))
                           | 1 (4 (3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4)))))))
                             | 4 (3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))))
                               | 3 (>, 4, 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4)))))
                                 | 4 (3 (>, 4, *), 2 (>, 4 (>, 3 (>, >, 4))))
                                   | 2 (>, 4 (>, 3 (>, >, 4)))
                                     | 4 (>, 3 (>, >, 4))
                                       | 3 (>, >, 4)
                                         | 4
                                           | 0

|#


(struct-easy "a hypersnippet"
  (hypersnippet degree initial-data closing-brackets)
  (#:guard-easy
    (unless (exact-nonnegative-integer? degree)
      (error "Expected degree to be an exact nonnegative integer"))
    ; NOTE: We don't validate `initial-data`.
    (unless (list? closing-brackets)
      (error "Expected closing-brackets to be a list"))
    (expect
      (list-foldl
        (build-list degree #/lambda (i)
          ; Whatever sub-histories we put here don't actually matter
          ; because they'll be overwritten whenever this history is
          ; used, so we just make them empty lists.
          (make-list i #/list))
        closing-brackets
      #/lambda (histories bracket-info)
        (w- degree (length histories)
        #/expect bracket-info (list bracket-degree data)
          (error "Expected each element of closing-brackets to be a two-element list")
        ; NOTE: We don't validate `data`.
        #/expect (exact-nonnegative-integer? bracket-degree) #t
          (error "Expected the degree of a closing bracket to be an exact nonnegative integer")
        #/expect (< bracket-degree degree) #t
          (error "Encountered a closing bracket of degree higher than the current region's degree")
        #/list-kv-map (list-ref histories bracket-degree)
        #/lambda (i subsubhistories)
          (if (< i bracket-degree)
            histories
            subsubhistories)))
      (list)
      (error "Expected closing-brackets to match up"))))

(define (dataless-brackets . degrees)
  (list-fmap degrees #/lambda (degree) (list degree #f)))

(define (dataless-hypersnippet degree . closing-bracket-degrees)
  (hypersnippet degree #f
  #/apply dataless-brackets closing-bracket-degrees))

(dataless-hypersnippet 0)
(dataless-hypersnippet 1 0)
(dataless-hypersnippet 2 1 0 0)
(dataless-hypersnippet 3 2 1 1 0 0 0 0)
(dataless-hypersnippet 4 3 2 2 1 1 1 1 0 0 0 0 0 0 0 0)
(dataless-hypersnippet
  5 4 3 3 2 2 2 2 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
