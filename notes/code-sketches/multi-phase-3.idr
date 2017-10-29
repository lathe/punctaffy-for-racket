Let's represent towers as towers of one less degree where the highest-degree holes are now contained in the islands.

So

  ^`( ~`( ,( ,( ) ) ) )

is to be represented like so:

  `( something ,( ) something )

Islands must have an overall balanced structure to them. The first "something" island opens the higher-degree hole, and the second "something" closes it. A single island may close and open many holes, and it may even dip into a hole without closing it, like the middle part of this:

  ^`( ~`( ,( ,( ) ) ,( ,( ) ) ) )
   `( ------ ,( ) ---- ,( ) --- )

As a lower-degree example,

  `( ,( ) )

is to be represented like so:

  ( something )

Clearly, everything at that degree will be represented as "( something )" for some value of "something," so that can be the base case of our representation.


exprOf : Nat -> Type -> Type
exprOf d i = Expr d 0 (\_ _ -> ()) i

exprBranchType :
  (d : Nat) -> (c : Nat -> Nat -> Type) -> (i : Type) -> Type
exprBranchType =
  (nextStartingDepth : Nat) *
  (i * exprOf d (Expr (1 + d) nextStartingDepth c i))

exprMap :
  (d : Nat) ->
  (startingDepth : Nat) ->
  (c : Nat -> Nat -> Type) ->
  (i : Type) ->
  (i' : type) ->
  (i -> i') ->
  Expr d startingDepth c i ->
  Expr d startingDepth c i'
exprMap d startingDepth c i i' f expr = case expr of
  exprNil d'' s'' c'' i'' content'' =>
    exprNil d'' s'' c'' i' content''
  exprCons d'' startingDepth'' c'' i'' branches'' content'' =>
    exprCons d'' startingDepth'' c'' i'
      (exprMap d'' startingDepth'' c''
        (exprBranchType d'' c'' i'')
        (exprBranchType d'' c'' i')
        (\(nextStartingDepth * (iVal * branches)) ->
          nextStartingDepth *
          (f iVal *
            exprMap d'' 0 (\_ _ -> ())
              (Expr d nextStartingDepth c'' i'')
              (Expr d nextStartingDepth c'' i')
              (exprMap d nextStartingDepth c'' i'' i' f)
              branches))
        branches'')

type Expr
  (degree : Nat)
  (startingDepth : Nat)
  (content : Nat -> exprOf d Nat -> Type)
  (interpolation : Type)
where
  exprNil :
    (d : Nat) ->
    (s : Nat) ->
    (c : Nat -> exprOf d Nat -> Type) ->
    (i : Type) ->
    c s (exprNil d 0 (\_ _ -> ()) Nat) ->
    Expr (1 + d) s c i
  exprCons :
    (d : Nat) ->
    (startingDepth : Nat) ->
    (c : Nat -> Nat -> Type) ->
    (i : Type) ->
    (branches : exprOf d (exprBranchType d c i)) ->
    c startingDepth
      (exprMap d 0 (\_ _ -> ()) (exprBranchType d c i) Nat
        (\(nextStartingDepth * _) -> nextStartingDepth)
        branches) ->
    Expr (1 + d) startingDepth c i

-- TODO: Whoops, the above `Expr` has no constructors for degree 0,
-- and its constructors for degrees greater than 0 aren't using island
-- content values to represent higher-degree holes. Finish making a
-- version of expr which does this, below.

vec : Nat -> Type -> Type
vec n t = case n of
  0 => () * ()
  1 + n' => t * vec n' t

exprInfoType : Nat -> Type
exprInfoType degree = case degree of
  0 =>
    (balanceStateType : Type) *
    let bl = List balanceStateType in
    (bl -> () -> Type) *
    (bl -> () -> Type) *
    ()
  1 + degree' =>
    (balanceStateType : Type) *
    let bl = List balanceStateType in
    (bl -> exprOf degree' bl -> Type) *
    (bl -> exprOf degree' bl -> Type) *
    exprInfoType degree'

type List (a : Type) where
  nil : (a : Type) -> List a
  cons : (a : Type) -> a -> List a -> List a

exprInfo :
  (degree : Nat) ->
  (balanceStateType0 : Type) ->
  (List balanceStateType0 -> Type) ->
  (List balanceStateType0 -> Type) ->
  exprInfoType degree
exprInfo degree balanceStateType0 i0 l0 = case degree of
  0 =>
    balanceStateType0 *
    (\currentBalance () -> i0 currentBalance) *
    (\currentBalance () -> l0 currentBalance) *
    ()
  1 + degree' =>
    let
      balanceStateTypeN * iN * lN * infoN =
        exprInfo degree' balanceStateType0 i0 l0
    in
    List balanceStateTypeN *
    (\currentBalance edge ->
      Expr degree' (balanceStateTypeN * iN * lN)
        (nil balanceStateTypeN)) *
    (\currentBalance edge -> ()) *
    (balanceStateTypeN * iN * lN * infoN)
    

island : Nat -> (balanceStateType : Type) -> balanceStateType -> Type
island degree balanceStateType startingBalance =
  Expr degree Nat c'
    
    

type Expr
  (degree : Nat)
  (balanceStateType * i * l * ti : exprInfoType degree)
  List balanceStateType
where
  expr :
    (d : Nat) ->
    (balanceStateType : Type) ->
    (balanceStateType * i * l * ti : exprInfoType d) ->
    (startingBalance : List balanceStateType) ->
    (case d of
      0 => () * i startingBalance ()
      1 + d' =>
        let balanceStateType' * i' * l' * ti' = ti in
        (e : Expr d' ti
          (
          -- TODO: Implement island.
          (island d' balanceStateType c (lakeType * lakeTypes)
            startingBalance)
          lakeTypes
          0) *
        i startingBalance
          -- TODO: Implement exprMap, and pass it whatever other
          -- arguments it needs here.
          (exprMap
            (\newStartingBalance lake -> newStartingBalance)
            e)) ->
    Expr d balanceStateType c (lakeType * lakeTypes) startingBalance



 that degree we only have a single "something" in the representation no 
