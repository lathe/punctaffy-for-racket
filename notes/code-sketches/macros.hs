-- macros.hs

-- This file isn't meant to become a Haskell library (yet, anyway).
-- It's just a scratch area to help guide the design of macros.rkt.


{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE ScopedTypeVariables #-}

import Control.Monad (ap, join, liftM)
import Data.Bifunctor (bimap)
import Data.Functor.Identity (Identity(Identity))
import Data.Void (Void)



-- We aim to generalize the concepts of balanced parentheses and
-- balanced quasiquote/unquote operations, and we will collectively
-- call these operations "parens". In particular, we sometimes refer
-- to quasiquote as an opening paren and unquote as a closing paren.
-- We eventually hope to extend this analogy beyond the matching of
-- parentheses among text and beyond the matching of quasiquote and
-- unquote among s-expressions, toward what we'd like to call
-- "higher degrees of quasiquotation" or simply
-- "higher quasiquotation." While we may have already achieved this
-- goal with the definition of `opParenOpenQuasiquote` and
-- `opParenOpenUnquote`, we haven't put it to the test yet (TODO), so
-- we focus first on the simpler case of modeling
-- quasiquotation-matching among s-expressions and showing how it
-- generalizes paren-matching among text.
--
-- We define two main types, `SExpr` and `QQExpr`. Our goal with
-- `QQExpr` is to represent a data structure where quasiquote and
-- unquote are balanced by construction, while `SExpr` is the
-- corresponding freeform representation where the operations may or
-- may not be balanced.
--
-- Since we're generalizing, we simply refer to the generalized
-- quasiquotation and unquotation operations as opening and closing
-- parens, repsectively.
--
-- The point of all this is so that we can design a macro system where
-- symbols like "quasiquote", "unquote", "(", and ")" are within the
-- realm of what users can define, and so that they're defined in ways
-- that are analogous to each other, leading to a language with fewer
-- hardcoded symbols and gotchas.

data SExpr f lit
  = SExprLiteral lit
  | SExprList (f (SExpr f lit))

data QQExpr f lit
  = QQExprLiteral lit
  | QQExprList (f (QQExpr f lit))
  | QQExprQQ (QQExpr f (QQExpr f lit))


data ParensAdded f a = ParenOpen a | ParenClose a | ParenOther (f a)


-- We define a few type class instances related to those types.

instance (Functor f) => Functor (ParensAdded f) where
  fmap func parensAdded = case parensAdded of
    ParenOpen rest -> ParenOpen $ func rest
    ParenClose rest -> ParenClose $ func rest
    ParenOther rest -> ParenOther $ fmap func rest

instance (Functor f) => Monad (SExpr f) where
  return = SExprLiteral
  effects >>= func = case effects of
    SExprLiteral lit -> func lit
    SExprList list -> SExprList $ fmap (>>= func) list
instance (Functor f) => Applicative (SExpr f) where
  pure = return
  (<*>) = ap
instance (Functor f) => Functor (SExpr f) where
  fmap = liftM

instance (Functor f) => Monad (QQExpr f) where
  return = QQExprLiteral
  effects >>= func = case effects of
    QQExprLiteral lit -> func lit
    QQExprList list -> QQExprList $ fmap (>>= func) list
    QQExprQQ body -> body >>= \unquote -> unquote >>= func
instance (Functor f) => Applicative (QQExpr f) where
  pure = return
  (<*>) = ap
instance (Functor f) => Functor (QQExpr f) where
  fmap = liftM


-- This is the algorithm that justifies the data types we're using: A
-- `QQExpr` corresponds to the special case of `SExpr` where all
-- parens within are balanced. This correspondence is witnessed by
-- the total function `flattenQQ` and its partial function inverse
-- `nudgeNestQQ`.

flattenQQ :: (Functor f) => QQExpr f lit -> SExpr (ParensAdded f) lit
flattenQQ qqExpr = case qqExpr of
  QQExprLiteral lit -> SExprLiteral lit
  QQExprList list -> SExprList $ ParenOther $ fmap flattenQQ list
  QQExprQQ body ->
    SExprList $ ParenOpen $ flattenQQ body >>=
    (SExprList . ParenClose . flattenQQ)

nudgeNestQQ ::
  (Functor f) =>
  SExpr (ParensAdded f) lit -> QQExpr f (Either String lit)
nudgeNestQQ sExpr = flip fmap (loop sExpr) $ \litOrEsc ->
  case litOrEsc of
    Left lit -> lit
    Right esc -> Left "Encountered an unmatched closing paren"
  where
    loop ::
      (Functor f) =>
      SExpr (ParensAdded f) lit ->
        QQExpr f
          (Either (Either String lit) (SExpr (ParensAdded f) lit))
    loop sExpr = case sExpr of
      SExprLiteral lit -> QQExprLiteral $ Left $ Right lit
      SExprList list -> case list of
        ParenOpen list' ->
          QQExprQQ $ flip fmap (loop list') $ \errOrLitOrEsc ->
            case errOrLitOrEsc of
              Left errOrLit -> QQExprLiteral $ Left $ Left $
                case errOrLit of
                  Left err -> err
                  Right lit ->
                    "Encountered an unmatched opening paren"
              Right esc -> loop esc
        ParenClose list' -> QQExprLiteral $ Right list'
        ParenOther list' -> QQExprList $ fmap loop list'

insistNestQQ ::
  (Functor f) => SExpr (ParensAdded f) lit -> QQExpr f lit
insistNestQQ sExpr = flip fmap (nudgeNestQQ sExpr) $ \errOrLit ->
  case errOrLit of
    Left err -> error err
    Right lit -> lit


-- Here's the obvious inclusion from `SExpr` into `QQExpr`, along with
-- its partial function inverse. Together with `flattenQQ` and
-- `nudgeNestQQ`, we can nestle or flatten something over and over.
--
-- This doesn't achieve higher quasiquotation. What it means is that
-- we can parse "( [ { ... } ] )" interpreting only the square
-- brackets, and then run a parser recursively over that s-expression
-- to interpret the curly brackets, then repeat the process for the
-- parens, etc. In this example, at every stage we're still dealing
-- with matching parens, never matching quasiquotes with unquotes.

qqExprOfSExpr :: (Functor f) => SExpr f lit -> QQExpr f lit
qqExprOfSExpr sExpr = case sExpr of
  SExprLiteral lit -> QQExprLiteral lit
  SExprList list -> QQExprList $ fmap qqExprOfSExpr list

nudgeSExprFromQQExpr ::
  (Functor f) => QQExpr f lit -> SExpr f (Maybe lit)
nudgeSExprFromQQExpr qqExpr = case qqExpr of
  QQExprLiteral lit -> SExprLiteral $ Just lit
  QQExprList list -> SExprList $ fmap nudgeSExprFromQQExpr list
  QQExprQQ body -> SExprLiteral Nothing

insistSExprFromQQExpr :: (Functor f) => QQExpr f lit -> SExpr f lit
insistSExprFromQQExpr qqExpr =
  nudgeSExprFromQQExpr qqExpr >>= \litOrErr -> case litOrErr of
    Nothing -> error "Tried to insistSExprFromQQExpr a QQExprQQ"
    Just lit -> return lit



-- The form of `SExpr` and `QQExpr` is the most familiar when
-- `SExprList` and `QQExprList` refer to actual lists (and hence
-- `SExpr` refers to actual s-expressions), but we can use other
-- functors for `f`.
--
-- If we use the functor (Compose [] (Sum (Const a) Identity)), then
-- our s-expressions can contain literal values of type `a`. We can
-- put symbols or other atoms into our s-exprssions that way, giving
-- them an even closer resemblance to the the Lisp s-expression
-- tradition.
--
-- If we use the functor ((,) a), then `SExpr` is isomorphic to a
-- list, and `QQExpr` is isomorphic to a list of s-expressions, as we
-- show using the coercions below. So indeed, quasiquotation-matching
-- among s-expressions generalizes paren-matching among text, and our
-- generalized use of the term "paren" is well justified.

improperListAsSExpr :: ([a], end) -> SExpr ((,) a) end
improperListAsSExpr (list, end) = case list of
  [] -> SExprLiteral end
  x:xs -> SExprList (x, improperListAsSExpr (xs, end))

deImproperListAsSExpr :: SExpr ((,) a) end -> ([a], end)
deImproperListAsSExpr expr = case expr of
  SExprLiteral end -> ([], end)
  SExprList (x, xs) ->
    let (xs', end) = deImproperListAsSExpr xs in (x:xs', end)

listAsSExpr :: [a] -> SExpr ((,) a) ()
listAsSExpr list = improperListAsSExpr (list, ())

deListAsSExpr :: SExpr ((,) a) () -> [a]
deListAsSExpr expr =
  let (list, ()) = deImproperListAsSExpr expr in list

improperNestedListsAsQQExpr ::
  ([SExpr [] a], end) -> QQExpr ((,) a) end
improperNestedListsAsQQExpr (nestedLists, end) = case nestedLists of
  [] -> QQExprLiteral end
  x:xs ->
    let xs' = improperNestedListsAsQQExpr (xs, end) in
    case x of
      SExprLiteral x' -> QQExprList (x', xs')
      SExprList list ->
        QQExprQQ $ improperNestedListsAsQQExpr (list, xs')

deImproperNestedListsAsQQExpr ::
  QQExpr ((,) a) end -> ([SExpr [] a], end)
deImproperNestedListsAsQQExpr qqExpr = case qqExpr of
  QQExprLiteral end -> ([], end)
  QQExprList (x, xs) ->
    let (xs', end) = deImproperNestedListsAsQQExpr xs in
    (SExprLiteral x : xs', end)
  QQExprQQ body ->
    let (list, unquote) = deImproperNestedListsAsQQExpr body in
    let (xs, end) = deImproperNestedListsAsQQExpr unquote in
    (SExprList list : xs, end)

nestedListsAsQQExpr :: [SExpr [] a] -> QQExpr ((,) a) ()
nestedListsAsQQExpr nestedLists =
  improperNestedListsAsQQExpr (nestedLists, ())

deNestedListsAsQQExpr :: QQExpr ((,) a) () -> [SExpr [] a]
deNestedListsAsQQExpr qqExpr =
  let (list, ()) = deImproperNestedListsAsQQExpr qqExpr in list



-- Now instead of writing quasiquote-matching as a standalone
-- algorithm, we explore a macroexpansion technique where the
-- quasiquote and unquote operations are treated as user-definable
-- macros. The behavior of the quasiquote macro (`OpParenOpen`) is to
-- match itself with occurrences of the unquote macro (`OpParenClose`)
-- and pass the matched-up syntax through another operation to process
-- it. In the end, the macroexpander returns an s-expression in a
-- potentially different language from the s-expression it received.
--
-- To do macroexpansion at a high degree of quasiquotation, we take
-- the output of one macroexpansion pass and feed it in as the input
-- to another. This is analogous to the way the outputs of Common Lisp
-- or Racket reader macros (namely, s-expressions) are used as the
-- input to those languages' s-expression macroexpanders. We provide
-- `opParenOpenQuasiquote` and `opParenOpenUnquote` for this use case,
-- but we still need to put them to the test (TODO).

data EnvEsc esc f lit
  = EnvEscErr String
  | EnvEscLit lit
  | forall esc' fa lita fb litb eof. EnvEscSubexpr
      esc
      (Env esc' fa lita fb litb)
      (SExpr fa (EnvEsc (Maybe Void) fa (lita eof)))
      (SExpr fb (litb eof) -> SExpr f (EnvEsc esc f lit))

newtype Env esc fa lita fb litb = Env {
  callEnv ::
    forall eof.
    Env esc fa lita fb litb ->
    SExpr fa (lita eof) ->
      Maybe (SExpr fb (EnvEsc esc fb (litb eof)))
}

instance (Functor f) => Monad (EnvEsc esc f) where
  return = EnvEscLit
  effects >>= func = case effects of
    EnvEscErr err -> EnvEscErr err
    EnvEscLit lit -> func lit
    EnvEscSubexpr esc' env expr callback ->
      EnvEscSubexpr esc' env expr (fmap (>>= func) . callback)
instance (Functor f) => Applicative (EnvEsc esc f) where
  pure = return
  (<*>) = ap
instance (Functor f) => Functor (EnvEsc esc f) where
  fmap = liftM

processEsc ::
  (Functor f) =>
  (forall esc' fa lita fb litb eof'.
    esc ->
    Env esc' fa lita fb litb ->
    SExpr fa (EnvEsc (Maybe Void) fa (lita eof')) ->
    (SExpr fb (litb eof') -> SExpr f (EnvEsc esc'' f (lit eof))) ->
    EnvEsc esc'' f (lit eof)) ->
  EnvEsc esc f (lit eof) ->
    EnvEsc esc'' f (lit eof)
processEsc onSubexpr esc = case esc of
  EnvEscErr err -> EnvEscErr err
  EnvEscLit lit -> EnvEscLit lit
  EnvEscSubexpr esc' env expr func ->
    onSubexpr esc' env expr (fmap (processEsc onSubexpr) . func)

-- NOTE: There's a lot going on in the result type. The (Maybe ...)
-- part allows an environment to say that it has no binding for the
-- "operator" in this expression, rather than calling its provided
-- late-bound environment (eventually itself) over and over in an
-- infinite loop. The `EnvEscErr` result allows syntax errors to be
-- reported locally among the branches of the returned expression.
-- Finally, the `EnvEscSubexpr` result allows us to represent the
-- result of parsing a closing parenthesis/unquote, and it also allows
-- us invoke the macroexpander in a trampolined way, a way that
-- potentially lets us cache and recompute different areas of the
-- syntax without starting from scratch each time. The expression
-- parameter to `EnvEscSubexpr` includes (EnvEsc (Maybe Void) ...) so
-- that it can use a `Nothing` escape to trampoline to the
-- macroexpander like this.
--
-- TODO: We don't currently implement a cache like that. Should we? If
-- we could somehow guarantee that one macroexpansion step didnt't
-- peek at the internal structure of the `EnvEscSubexpr` values it
-- returned, we could have much more confidence in caching results. If
-- we start to formalize that, we'll likewise want to keep track of
-- what parts of the environment have been peeked at as well. We might
-- be able to make a little bit of headway on this if we use some more
-- explicit foralls in our types, but it's likely this will be much
-- more straightoforward to enforce if we make peeking a side effect
-- (so we'll want to treat expressions not as pure data structures but
-- as imperative streams).
--
interpret ::
  Env esc fa lita fb litb ->
  SExpr fa (lita eof) ->
    Maybe (SExpr fb (EnvEsc esc fb (litb eof)))
interpret env expr = callEnv env env expr

callSimpleEnv ::
  (forall eof.
    Env esc fa lita fb litb ->
    fa (SExpr fa (lita eof)) ->
      Maybe (SExpr fb (EnvEsc esc fb (litb eof)))
  ) ->
  Env esc fa lita fb litb ->
  SExpr fa (lita eof) ->
    Maybe (SExpr fb (EnvEsc esc fb (litb eof)))
callSimpleEnv func env expr = case expr of
  SExprLiteral lit -> Nothing
  SExprList list -> func env list

simpleEnv ::
  (forall eof.
    Env esc fa lita fb litb ->
    fa (SExpr fa (lita eof)) ->
      Maybe (SExpr fb (EnvEsc esc fb (litb eof)))
  ) ->
    Env esc fa lita fb litb
simpleEnv func = Env $ callSimpleEnv func

shadowSimpleEnv ::
  (Functor fb) =>
  Env esc fa lita fb litb ->
  (forall eof.
    Env esc fa lita fb litb ->
    fa (SExpr fa (lita eof)) ->
      Maybe (SExpr fb (EnvEsc esc fb (litb eof)))
  ) ->
    Env esc fa lita fb litb
shadowSimpleEnv env shadower = Env $ \lateEnv expr ->
  case callSimpleEnv shadower lateEnv expr of
    Just result -> Just result
    Nothing -> callEnv env lateEnv expr

qualifyEnv ::
  (Functor fb) =>
  (Env esc'' fa lita fb litb -> Env esc fa lita fb litb) ->
  (forall esc' fa' lita' fb' litb' eof' eof.
    esc ->
    Env esc' fa' lita' fb' litb' ->
    SExpr fa' (EnvEsc (Maybe Void) fa' (lita' eof')) ->
    (SExpr fb' (litb' eof') ->
      SExpr fb (EnvEsc esc'' fb (litb eof))) ->
    EnvEsc esc'' fb (litb eof)) ->
  Env esc fa lita fb litb ->
    Env esc'' fa lita fb litb
qualifyEnv super qualify env = Env $ \lateEnv expr ->
  fmap (fmap $ processEsc qualify) $ callEnv env (super lateEnv) expr

downEscEnv ::
  (Functor fb) =>
  Env (Maybe (Maybe esc)) fa lita fb litb ->
    Env (Maybe esc) fa lita fb litb
downEscEnv = qualifyEnv upEscEnv $ \esc env expr func -> case esc of
  -- If we have an escape that's supposed to be trampolined to the
  -- macroexpander (Nothing), it's still supposed to be trampolined.
  Nothing -> EnvEscSubexpr Nothing env expr func
  -- If we have an escape that's a closing paren (Just Nothing),
  -- trampoline the following syntax to the macroexpander (Nothing).
  Just esc' -> EnvEscSubexpr esc' env expr func

upEscEnv ::
  (Functor fb) =>
  Env (Maybe esc) fa lita fb litb ->
    Env (Maybe (Maybe esc)) fa lita fb litb
upEscEnv = qualifyEnv downEscEnv $ \esc env expr func -> case esc of
  -- If we have an escape that's supposed to be trampolined to the
  -- macroexpander (Nothing), it's still supposed to be trampolined.
  Nothing -> EnvEscSubexpr Nothing env expr func
  -- Otherwise, we at least know it's not a closing paren
  -- (Just Nothing).
  Just esc' -> EnvEscSubexpr (Just (Just esc')) env expr func

-- A good way to read this signature is to see that the operation
-- takes an interval enclosed by the parens (`SExpr fb (...)`), some
-- following syntax for which that bracketed section could itself be
-- an opening bracket (`EnvEsc (Maybe esc) (OpParen fa fb) (...)`),
-- and finally a past-the-end-of-the-file section which the operator
-- must ignore (`lita`). The operator returns a possible bracketed
-- section which may trampoline to the macroexpander
-- (`SExpr fb (EnvEsc (Maybe Void) fb (...))`) followed by some syntax
-- which has not been consumed
-- (`EnvEsc (Maybe esc) (OpParen fa fb) (...)`) followed by an
-- untouched past-the-end-of-the-file section (`lita`).
newtype OpParenOp fa fb = OpParenOp
  (forall esc lita.
    (Env (Maybe Void) (OpParen fa fb) Identity fb
      (EnvEsc (Maybe esc) (OpParen fa fb))) ->
    SExpr fb (EnvEsc (Maybe esc) (OpParen fa fb) lita) ->
      SExpr fb
        (EnvEsc (Maybe Void) fb
          (EnvEsc (Maybe esc) (OpParen fa fb) lita)))

data OpParen fa fb rest
  = OpParenOpen (OpParenOp fa fb) rest
  | OpParenClose rest
  | OpParenOther (fa rest)

mapLists ::
  (Functor f) =>
  (forall lit. f lit -> g lit) -> SExpr f lit -> SExpr g lit
mapLists func sexpr = case sexpr of
  SExprLiteral lit -> SExprLiteral lit
  SExprList list -> SExprList $ func (fmap (mapLists func) list)

opParenOpenQuasi ::
  forall fa fb lit. (Functor fa) =>
  (forall rest. rest -> fa rest) ->
  (forall rest. rest -> OpParen fb ((,) (SExpr fa lit)) rest)
opParenOpenQuasi op rest = flip OpParenOpen rest $ OpParenOp $
  \env expr -> case expr of
    SExprLiteral esc ->
      SExprLiteral $ EnvEscErr "Expected a quasiquoted expression"
    SExprList (resultExpr, rest) -> case rest of
      SExprList _ ->
        SExprLiteral $
          EnvEscErr "Expected no more than one quasiquoted expression"
      SExprLiteral rest' ->
        SExprList
          (SExprList $ op resultExpr, SExprLiteral $ EnvEscLit rest')
-- Here's an alternate implementation which would allow any number of
-- expressions to occur in the quasiquoted section.
--    mapLists (bimap (SExprList . op) id) $ fmap EnvEscLit expr

opParenOpenEmpty ::
  forall fa fb. (Functor fa, Functor fb) =>
  (forall rest. rest -> OpParen fa fb rest) ->
  (forall rest. rest -> OpParen fa fb rest)
opParenOpenEmpty op rest = flip OpParenOpen rest $ OpParenOp $
  \env expr -> SExprLiteral $ case expr of
    SExprLiteral esc -> case esc of
      EnvEscErr err -> EnvEscErr err
      EnvEscLit lit -> nonemptyErr
      EnvEscSubexpr esc' env' expr' func -> case esc' of
        Just esc'' -> nonemptyErr
        Nothing ->
          EnvEscSubexpr Nothing env' expr' $ \expr'' ->
          SExprLiteral $
            EnvEscSubexpr Nothing env
              (fmap (fmap Identity . putOff) $ SExprList $
                op $ func expr'') $
            fmap
              ((EnvEscLit ::
                 forall esc lita.
                 EnvEsc (Maybe esc) (OpParen fa fb) lita ->
                   EnvEsc (Maybe Void) fb
                     (EnvEsc (Maybe esc) (OpParen fa fb) lita)
              ) . join)
    _ -> nonemptyErr
  where
  
  nonemptyErr :: forall esc f lit. EnvEsc esc f lit
  nonemptyErr =
    EnvEscErr "Encountered a paren which held content within the paren itself"
  
  putOff ::
    forall esc f lit. (Functor f) =>
    EnvEsc (Maybe esc) f lit ->
      EnvEsc (Maybe Void) f (EnvEsc (Maybe esc) f lit)
  putOff esc = case esc of
    EnvEscErr err -> EnvEscErr err
    EnvEscLit lit -> EnvEscLit $ EnvEscLit lit
    EnvEscSubexpr esc' env expr func -> case esc' of
      Just esc'' ->
        EnvEscLit $ EnvEscSubexpr (Just esc'') env expr func
      Nothing -> EnvEscSubexpr Nothing env expr (fmap putOff . func)

-- These are four operators which reside on a use of `OpParenOpen`.
-- A properly matched call to `OpParenOpen` when the parens are among
-- text (rather than s-expressions) looks like
-- "(...bracketedBody...)...followingBody...". Two of these operators
-- require `bracketedBody` to form a single piece of higher-degree
-- syntax, which they then quasiquote and unquote respectively. The
-- other two require `bracketedBody` to be empty, and then they
-- behave like "(...followingBody..." and ")...followingBody...".
--
opParenOpenQuasiquote ::
  (Functor fa) =>
  OpParenOp fa fb ->
  rest ->
    OpParen fc ((,) (SExpr (OpParen fa fb) Void)) rest
opParenOpenQuasiquote op = opParenOpenQuasi $ OpParenOpen op
opParenOpenUnquote ::
  (Functor fa) =>
  rest -> OpParen fc ((,) (SExpr (OpParen fa fb) Void)) rest
opParenOpenUnquote = opParenOpenQuasi $ OpParenClose
opParenOpenEmptyOpen ::
  (Functor fa, Functor fb) =>
  OpParenOp fa fb -> rest -> OpParen fa fb rest
opParenOpenEmptyOpen op = opParenOpenEmpty $ OpParenOpen op
opParenOpenEmptyClose ::
  (Functor fa, Functor fb) => rest -> OpParen fa fb rest
opParenOpenEmptyClose = opParenOpenEmpty OpParenClose

instance (Functor fa) => Functor (OpParen fa ga) where
  fmap func x = case x of
    OpParenOpen parenFunc rest -> OpParenOpen parenFunc $ func rest
    OpParenClose rest -> OpParenClose $ func rest
    OpParenOther other -> OpParenOther $ fmap func other

-- NOTE: This environment expects at least one escape, namely
-- `Nothing`, with the meaning of trampolining to the macroexpander.
coreEnv ::
  (Functor fa, Functor fb) =>
  Env (Maybe Void) (OpParen fa fb) Identity fb
    (EnvEsc (Maybe esc) (OpParen fa fb))
coreEnv = simpleEnv coreEnv_

coreEnv_ ::
  -- We use `ScopedTypeVariables` and an explicit `forall` here so we
  -- can use these type variables in type annotations below. We're not
  -- doing this because we need to, but just as a sanity check and a
  -- form of documentation.
  forall esc fa fb eof. (Functor fa, Functor fb) =>
  Env (Maybe Void) (OpParen fa fb) Identity fb
    (EnvEsc (Maybe esc) (OpParen fa fb)) ->
  OpParen fa fb (SExpr (OpParen fa fb) (Identity eof)) ->
    Maybe
      (SExpr fb
        (EnvEsc (Maybe Void) fb
          (EnvEsc (Maybe esc) (OpParen fa fb) eof)))
coreEnv_ env call = case call of
  OpParenOpen (OpParenOp op) expr -> Just $ SExprLiteral $
    ((EnvEscSubexpr Nothing
      ((downEscEnv $ shadowSimpleEnv (upEscEnv env) $ \env' call'' ->
        case call'' of
          OpParenClose expr' -> Just $ SExprLiteral $
            -- We reset the environment to the environment that
            -- existed at the open paren.
            EnvEscSubexpr (Just Nothing) (upEscEnv env)
              (fmap
                (EnvEscLit ::
                  forall lita.
                  Identity lita ->
                    EnvEsc (Maybe Void) (OpParen fa fb)
                      (Identity lita))
                expr')
              (fmap
                (EnvEscLit ::
                  forall lita.
                  (EnvEsc (Maybe esc) (OpParen fa fb) lita) ->
                  EnvEsc (Maybe (Maybe Void)) fb
                    (EnvEsc (Maybe esc) (OpParen fa fb) lita)))
          _ -> Nothing
      ) ::
        Env (Maybe Void) (OpParen fa fb) Identity fb
          (EnvEsc (Maybe esc) (OpParen fa fb)))
      (fmap
        (EnvEscLit ::
          Identity eof ->
            EnvEsc (Maybe Void) (OpParen fa fb) (Identity eof))
        expr
        :: SExpr (OpParen fa fb)
             (EnvEsc (Maybe Void) (OpParen fa fb) (Identity eof)))
      ((\expr' ->
          -- We consult an operator determined by the matched opening
          -- and closing parens to determine what to do next. In this
          -- proof of concept, we determine the operation fully in
          -- terms of the opening paren.
          op env expr'
      ) ::
        SExpr fb (EnvEsc (Maybe esc) (OpParen fa fb) eof) ->
          SExpr fb
            (EnvEsc (Maybe Void) fb
              (EnvEsc (Maybe esc) (OpParen fa fb) eof)))
    ) :: EnvEsc (Maybe Void) fb
           (EnvEsc (Maybe esc) (OpParen fa fb) eof))
  OpParenClose expr ->
    Just $ SExprLiteral $
      EnvEscErr "Encountered an unmatched closing paren"
  _ -> Nothing
