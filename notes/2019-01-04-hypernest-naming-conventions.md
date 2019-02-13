## Deciding how to name hypernest and hypertee utilities


At the time of writing, the exports of punctaffy-lib/hypersnippet/hypertee.rkt are as follows:

(provide
  hypertee-closing-bracket-degree
  (rename-out
    [-hypertee? hypertee?]
    [-hypertee-degree hypertee-degree])
  degree-and-closing-brackets->hypertee
  hypertee->degree-and-closing-brackets
  hypertee-promote
  hypertee-set-degree-maybe
  hypertee-set-degree
  hypertee-contour
  hypertee-drop1
  hypertee-dv-map-all-degrees
  hypertee-v-map-one-degree
  hypertee-v-map-highest-degree
  hypertee-fold
  (struct-out hypertee-join-selective-interpolation)
  (struct-out hypertee-join-selective-non-interpolation)
  hypertee-join-all-degrees-selective
  hypertee-map-all-degrees
  hypertee-map-one-degree
  hypertee-map-highest-degree
  hypertee-pure
  hypertee-get-hole-zero
  hypertee-plus1
  hypertee-join-all-degrees
  hypertee-bind-all-degrees
  hypertee-bind-one-degree
  hypertee-bind-pred-degree
  hypertee-join-one-degree
  hypertee-dv-any-all-degrees
  hypertee-dv-all-all-degrees
  hypertee-dv-each-all-degrees
  hypertee-v-each-one-degree
  hypertee-each-all-degrees
  hypertee-uncontour
  hypertee-filter
  hypertee-truncate
  hypertee-dv-fold-map-any-all-degrees
  hypertee-zip-selective
  hypertee-zip-low-degrees)

And here are the exports from punctaffy-lib/hypersnippet/hypernest.rkt:

(provide
  (struct-out hypernest-coil-zero)
  (struct-out hypernest-coil-hole)
  (struct-out hypernest-coil-bump)
  hypernest-bracket-degree
  (rename-out [-hypernest? hypernest?])
  hypernest-degree
  degree-and-brackets->hypernest
  hypernest->degree-and-brackets
  hypernest-promote
  hypernest-set-degree
  hypertee->hypernest
  hypernest->maybe-hypertee
  hypernest-truncate-to-hypertee
  hypernest-contour
  hypernest-zip
  hypernest-drop1
  hypernest-dv-map-all-degrees
  hypernest-v-map-one-degree
  (struct-out hypernest-join-selective-interpolation)
  (struct-out hypernest-join-selective-non-interpolation)
  hypernest-join-all-degrees-selective
  hypernest-map-all-degrees
  hypernest-pure
  hypernest-get-hole-zero
  hypernest-join-all-degrees
  hypernest-dv-bind-all-degrees
  hypernest-bind-all-degrees
  hypernest-bind-one-degree
  hypernest-join-one-degree
  hypernest-plus1)


In some ways this naming convention is inconvenient, in some ways it's imprecise, and in some ways it's arguably inconsistent. Let's come up with better names.


hypertee?
hypernest?
hypertee->hypernest        ; this and counterpart would both be considered hypernest tools
hypernest->maybe-hypertee  ; this and counterpart would both be considered hypernest tools
hypertee-degree
hypernest-degree
hypertee-degree</c
hypernest-degree</c
hypertee-increase-degree-to
hypernest-increase-degree-to
hypertee-set-degree-maybe
hypernest-set-degree-maybe
hypertee-hv-map
hypernest-holes-hv-map
hypertee-dv-map
hypernest-holes-dv-map
hypertee-hv-map-at
hypernest-holes-hv-map-at
hypertee-v-map-at
hypernest-holes-v-map-at
  ; NOTE: Utilities with "at" only process holes of a specific degree.
  ; Utilities with "holes" only process the holes, which leaves us
  ; room to develop other utilities which process the bumps as well.
(struct-out join-terp)     ; a hypertee tool with no counterpart
(struct-out join-nonterp)  ; a hypertee tool with no counterpart
  ; NOTE: In a way, `join-terp` and `join-nonterp` aren't even
  ; specific to hypertees, so they arguably belong in Lathe Comforts
  ; or something. But I think there are few monad-like data structures
  ; for which it makes such a drastic difference whether something is
  ; interpolated or not.
hypertee-join-selective
hypernest-holes-join-selective
hypertee-join
hypernest-holes-join
hypertee-join-at
hypernest-holes-join-at
hypertee-done
hypernest-holes-done
hypertee-hv-bind
hypernest-holes-hv-bind
hypertee-hv-bind-at
hypernest-holes-hv-bind-at
hypertee-zip-with-hypertee
hypernest-holes-zip-with-hypertee

(struct-out hypertee-coil-zero)
(struct-out hypernest-coil-zero)
(struct-out hypertee-coil-hole)
(struct-out hypernest-coil-hole)
(struct-out hypernest-coil-bump)  ; has no hypertee counterpart
hypertee-furl
hypernest-furl
hypertee-unfurl
hypernest-unfurl

hypertee-bracket-degree
hypernest-bracket-degree
brackets->hypertee
brackets->hypernest
hypertee->brackets
hypernest->brackets
hypertee-by-brackets
hypernest-by-brackets

; used in just a few places
hypertee-hv-each-unspecified-order
hypernest-holes-hv-each-unspecified-order
hypertee-dv-each-unspecified-order
hypernest-holes-dv-each-unspecified-order
hypertee-v-each-unspecified-order-at
hypernest-holes-v-each-unspecified-order-at
hypertee-get-hole-zero
hypernest-get-hole-zero
hypertee-contour
hypernest-contour
hypertee-contour?
hypernest-contour?
hypertee-uncontour
hypernest-uncountour

; never used
hypertee-dv-filter
hypernest-holes-dv-filter
hypertee-filter-degree-to
hypernest-holes-filter-degree-to
  ; NOTE: The "filter-degree-to" utilities first filter the holes that
  ; can't exist at that degree, then demote the data structure to that
  ; degree. These were called "truncate" before.
hypernest-filter-to-hypertee
  ; NOTE: This has no hypertee counterpart.
  ; TODO: Should we call this `hypernest-bumps-filter-all` instead?
hypertee-dv-any-unspecified-order
hypernest-holes-dv-any-unspecified-order
hypertee-dv-all-unspecified-order
hypernest-holes-dv-all-unspecified-order
hypertee-dv-map-unspecified-order
hypernest-holes-dv-map-unspecified-order


  notes on the naming of `hypertee-dv-map-unspecified-order`, which we
  were calling `hypertee-dv-fold-map-any-all-degrees` before:
  
  
  here's a right fold which passes a state from left to right and can
  exit early and be resumed:
  f a -> (s -> r) -> (a -> (s -> r) -> (s -> r)) -> (s -> r)
  
  here's a right fold which passes a state from left to right; can
  exit early and be resumed; and when exiting normally, can return a
  mapped structure:
  f a -> (f b -> s -> r) -> (a -> (b -> s -> r) -> (s -> r)) -> (s -> r)

  types isomorphic to those two:
  ((s -> r) -> (a -> s -> r)) -> ((s -> r) -> (f a -> s -> r))
  ((b -> s -> r) -> (a -> s -> r)) -> ((f b -> s -> r) -> (f a -> s -> r))
  
  here's a more traditional right fold and a type isomorphic to it:
  f a -> r -> (a -> r -> r) -> r
  (a -> r -> r) -> (f a -> r -> r)
    this is (f a -rr-> a) where -rr-> is the category of (_ -> r -> r)
  
  here's a similar summary of the above two:
  (f a -sr()-> a) where -sr()-> is the category of (_ -sr-> ()) where -sr-> is the category of (_ -> s -> r)
  (a -sr-> b) -> (f a -sr-> f b) where -sr-> is the category of (_ -> s -> r)
    or in other words something like (Identity -srF-> f) where -srF-> is the category(?) of (_ a -sr-> _ b)
  
  how do they change if we modify them to not have early exits?
  
  here's a right fold which passes a state from left to right:
  f a -> (s -> r) -> (a -> s -> (s * (r -> r))) -> (s -> r)
  (a -> s -> (s * (r -> r))) -> (f a -> s -> ((s -> r) -> r))
  
  that's not as symmetrical, but this variation is, and it's more
  expressive because it lets the final state be observed even if the
  caller doesn't specify the nil case (which I suppose counts as an
  early exit):
  f a -> s -> (a -> s -> (s * (r -> r))) -> (s * (r -> r))
  (a -> s -> (s * (r -> r))) -> (f a -> s -> (s * (r -> r))
  
  here's a (similarly symmetrical) right fold which passes a state
  from left to right and returns a mapped structure:
  f a -> s -> (a -> s -> (b * s * (r -> r))) -> (f b * s * (r -> r))
  (a -> s -> (b * s * (r -> r))) -> (f a -> s -> (f b * s * (r -> r)))
  
  well, that may as well be a left fold since we're probably only
  using it to get the (f b):
  f a -> s -> (a -> s -> (b * s)) -> (f b * s)
  ((a * s) -> (b * s)) -> ((f a * s) -> (f b * s))
  
  here's a right fold which passes a state from left to right and uses
  it to decide the nil case:
  s -> f a -> (s -> a -> s) -> (s -> r) -> (a -> r -> r) -> r
  (s -> a -> s) -> (a -> r -> r) -> ((s -> r) -> (f a -> s -> r))
  
  Anyway, the point of `hypertee-dv-fold-map-any` is to be a very
  expressive left-to-right traversal, so we probably want to upgrade
  it to the resumable one that returns a mapped structure:
  f a -> (f b -> s -> r) -> (a -> (b -> s -> r) -> (s -> r)) -> (s -> r)
  ((b -> s -> r) -> (a -> s -> r)) -> ((f b -> s -> r) -> (f a -> s -> r))
  (a -sr-> b) -> (f a -sr-> f b) where -sr-> is the category of (_ -> s -> r)
    or in other words something like (Identity -srF-> f) where -srF-> is the category(?) of (_ a -sr-> _ b)
  
  This is essentially a map in the *language* of programs with ambient
  state `s` and the ambient ability to terminate the computation with
  `r`. If we instantiate `s` with `()`, we just get an
  early-exit-capable map operation. Then if we instantiate `r` with
  the bottom type, I think we get something classically equivalent to
  map (which I suppose illustrates how classical typing with `call/cc`
  as the double negation elimination proof enables early exits).
  
  Anyhow, the most convenient calling convention for the Parendown
  style would be something like:
  
  (s * f a * ((s * f b) -> r) * ((s * a * ((s * b) -> r)) -> r)) -> r
  (a -> m (f b)) -> f a -> m (f b)
  
  Examples:
  
  ; Iterate over `ht`, a hypertee of numbers, constructing a `just` of
  ; a similar hypertee where each number is doubled. If the existing
  ; numbers total to over 100, then return a `nothing` instead.
  ;
  (hypertee-v-fold-map-any 0 ht (fn state mapped #/just mapped)
  #/fn state data then
    (w- new-state (+ data state)
    #/if (< 100 new-state) (nothing)
    #/then new-state (* 2 data)))
  
  ; Iterate over `ht`, a hypertee of maybe values. Return a `nothing`
  ; if any of them is a `nothing`. Otherwise, return a `just` of a
  ; hypertee where each one is replaced by its element (which must
  ; exist, since it's not a `nothing`).
  ;
  (hypertee-v-fold-map-any (trivial) ht
    (fn state mapped #/just mapped)
  #/fn state data then
    (maybe-bind data #/fn data
    #/then state data))
  
  The latter example demonstrates that this is capable of operating
  like Haskell's `mapM` operation. We can implement that operation for
  any monad like so:
  
  (define (hypertee-v-mapm monad-done monad-bind ht proc)
    (hypertee-v-fold-map-any (trivial) ht
      (fn state mapped #/monad-done mapped)
      (fn state data then
        (monad-bind (proc data) #/fn data
        #/then state data))))
  
  If on the other hand we start with `hypertee-v-mapm`, I'm pretty
  sure we can implement `hypertee-v-fold-map-any` using a combination
  of the state and continuation monads:
  
  (define (hypertee-v-fold-map-any state ht on-mapped on-hole)
    (define (run state traversal)
      (traversal state #/fn state result
        result))
    (define (trav-done result)
      (fn state then #/then state result))
    (define (trav-bind prefix get-suffix)
      (fn state then
        (prefix state #/fn state intermediate
        #/ (get-suffix intermediate) state then)))
    
    (run state
    #/trav-bind
      (hypertee-v-mapm trav-done trav-bind ht
      #/fn data #/fn state then
        (on-hole state data then))
    #/fn mapped #/fn state then
    #/then state #/on-mapped state mapped))
  
  However, even with an existing library of monadic tools, passing
  around the monadic return and bind operations is somewhat
  cumbersome without a type class system. The
  `hypertee-v-fold-map-any` interface captures the same features as
  `hypertee-v-mapm` with a more streamlined interface for untyped
  programming.
  
  We're actually dealing with `hypertee-dv-fold-map-any`, so each data
  value would also be accompanied by its degree:
  
  (hypertee-dv-fold-map-any state ht (fn state mapped ...)
  #/fn state d data then
    ...)
  
  Since this is essentially an effectful map operation for any monadic
  notion of side effects, we should probably emphasize "map" in the
  name as opposed to "fold" or "any." How about `hypertee-dv-mapl`,
  calling to mind "foldl" to say that this is a traversal in a
  specific order? When the temporal order is specified, then temporal
  concepts like state and early exits make sense.
  
  The letter L for "left" or "left to right" doesn't seem to be enough
  to specify the path we take through the hypertee or hypernest. We're
  taking a pre-order (as opposed to post-order) traversal of the
  holes, which is to say we visit each hole as soon as we first
  encounter it, but I think this can be a different order depending on
  whether we represent the data as a sequence of brackets (as we
  currently do for hypertees) or as an AST (as we currently do for
  hypernests). Specifically, in this case...
  
  (n-ht 4 '(3 a) 2 '(2 b) 1 1 '(1 c) 0 0 '(2 d) 0 0 0 0 0 '(0 e))
  
  The iteration order is "abcde" in the bracket representation, but in
  the ADT representation, holes "b" and "d" are each inside the same
  hole of hole "a", so I believe the iteration order would be "abdce".
  
  If we want to treat the use of brackets or ADTs as an implementation
  detail, then perhaps we shouldn't specify an order. Indeed, we only
  use this as an implementation detail of other hypertee and hypernest
  operations, so perhaps we should leave the order of most of our
  operations unspecified.
  
  But all right, we do make a particular choice in the names "furl"
  and "unfurl." If we ever use another representation for hypernests,
  we'll run into some trouble because it would be nice to use "furl"
  and "unfurl" for that representation too. So let's say that a name
  with "l" means that the timeline of state changes and early exits
  runs from the outer coils to the inner coils of the data as it's
  unfurled, and "r" means it runs from the inner coils to the outer
  coils. When we want to look at the order of unfurling the bracket
  representation, we specify that in a more specific way, such as
  "mapl-brackets".
  
  Hmm... But maybe there's a single most appropriate *generalization*
  of these various possible orderings. When the timeline propagates,
  it doesn't have to do so in a fully sequentialized way. We can
  follow branching timelines through the degree-2 holes while
  remaining oblivious to their degree-1 positioning relative to their
  peers. We can follow branching timelines through the degree-3 holes
  while remaining oblivious to their degree-2 ordering. Since we're
  already using a short name like "join" to mean composing in every
  dimension at once and "join-at" to pick a dimension, perhaps a name
  like "mapl" should propagate timelines in every dimension at once
  too, somehow. Maybe "map1-at-0" would mean "we're processing the
  data as a system of degree-0 bumps" (a sequence of brackets) and
  "map1-at-1" would mean "we're processing the data as a system of
  degree-1 bumps" (a tree).
  
  Would it ever make sense to represent hypertee data as a system of
  degree-2 bumps? Perhaps if we had degree-2 data annotations, like
  hyprids are designed to implement. Or perhaps if the representation
  was something like the "double-striped" data we were exploring as a
  potential hypermonad instance, where there were stripes (similar to
  hyprid stripes), and each stripe could count as "opening" or
  "closing" or "closing-then-opening" or "opening-then-closing."
  
  But our ADT-style hypernest representation is a first-class value in
  Racket. It's untyped, and it can represent a hypernest of any
  degree. Unlike hyprids, unlike double-striped hypermonads, and
  unlike the bracket representation, the ADT-style representation
  we're using doesn't seem very much inconvenienced as it implements
  high-dimensional structure out of low-dimensional expressions. If
  there is some tower of representations hypersnippet data can use
  when it's unfurled, which would yield different iteration orders we
  would want to differentiate, then this ADT-style representation is
  probably a limit case or an over-expressive approximation.
  
  Hmm, supposing we do have a "mapl" that propagates state variables
  *of each dimension* from outside to inside in a way that respects
  only their own dimension's notion of the unfurling direction, then
  it seems like those state variables would be kept in a hyperstack as
  the algorithm goes along. Yes... I imagine the "mapl" call would
  typically have a different (fn state d data then ...) behavior for
  every dimension `d`, and its `then` would be a hypertee containing
  different continuations for all the different nested expressions the
  traversal could proceed into (which would usually be invoked once
  each, but some may be skipped to exit early).
  
  I suppose early exits mean each dimension would really be doing its
  own traversal independent of the others. Maybe if there are no early
  exits, a hyperstack is the way to do all the traversals at once, but
  if there are, then the traversals might as well be performed
  individually.
