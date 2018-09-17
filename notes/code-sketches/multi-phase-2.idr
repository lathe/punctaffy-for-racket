--   Copyright 2017-2018 The Lathe Authors
--
--   Licensed under the Apache License, Version 2.0 (the "License");
--   you may not use this file except in compliance with the License.
--   You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
--   Unless required by applicable law or agreed to in writing,
--   software distributed under the License is distributed on an
--   "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
--   either express or implied. See the License for the specific
--   language governing permissions and limitations under the License.


nullMedium :
  (d : Nat) ->
  (is : mediumEdgeType d) ->
  (ts : towerEdgeType d is) ->
  Medium d is ts ->
  Medium d is ts
nullMedium d is ts (medium d' is' ts' contentType) =
  medium d' is' ts' ()

mediumEdgeType : (d : Nat) -> Type
mediumEdgeType d = case d of
  0 => () * () * ()
  1 + d' =>
    (is : mediumEdgeType d') *
    (ts : towerEdgeType d' is) *
    Medium d' is ts

towerEdgeType : (d : Nat) -> mediumEdgeType d -> Type
towerEdgeType d (is * ts * i) = case d of
  0 => ()
  1 + d' => Tower d' is ts i (nullMedium d' is ts i)

mediumContentType :
  (d : Nat) ->
  (is : mediumEdgeType d) ->
  (ts : towerEdgeType d is) ->
  Medium d is ts ->
  Type
mediumContentType d is ts (medium d' is' ts' contentType') =
  contentType'

type Medium (d : Nat) (is : mediumEdgeType d) (towerEdgeType d is)
where
  medium :
    (d : Nat) ->
    (is : mediumEdgeType d) ->
    (ts : towerEdgeType d is) ->
    Type ->
    Medium d is ts

type Tower
  (d : Nat)
  (is : mediumEdgeType d)
  (ts : towerEdgeType d is)
  (Medium d is ts)
  (Medium d is ts)
where
  towerZero :
    (d : Nat) ->
    (is : mediumEdgeType d) ->
    (ts : towerEdgeType d is) ->
    (i : Medium d is ts) ->
    (l : Medium d is ts) ->
    mediumContentType d is ts i ->
    Tower d is ts i l
  towerSucc :
    (d : Nat) ->
    let d' = 1 + d in
    (is' : mediumEdgeType d') ->
    (ts' : towerEdgeType d' is') ->
    (i' : Medium d' is' ts') ->
    (l' : Medium d' is' ts') ->
    let is * ts * i = is' in
    Tower d is ts i (medium d is ts (Tower d' is' ts' l' i')) ->
    mediumContentType d' is' ts' i' ->
    Tower d' is' ts' i' l'



nullMedium :
  (d : Nat) -> (e : mediumEdgeType d) -> Medium d e -> Medium d e
nullMedium d e m = case m of
  mediumZero contentType => mediumZero ()
  mediumSucc d' e' i t contentTypes => mediumSucc d' e' i t (\_ -> ())

towerEdgeType : (d : Nat) -> Type
towerEdgeType d = case d of
  0 => (() * ()) * ()
  1 + d' =>
    ((e * t) * l : mediumEdgeType d) *
    Tower d' (e * t) (nullMedium d' e l) l

mediumEdgeType : (d : Nat) -> Type
mediumEdgeType d = case d of
  0 => () * ()
  1 + d' => (me * t : towerEdgeType d') * Medium d' me

type Medium (d : Nat) (mediumEdgeType d) where
  mediumZero : Type -> Medium 0 ((() * ()) * ())
  mediumSucc :
    (d : Nat) ->
    (me * t : towerEdgeType d) ->
    (i : Medium d me) ->
    (Tower d (me * t) i (nullMedium d me i) -> Type) ->
    Medium (1 + d) ((me * t) * i)

type Tower
  (d : Nat)
  (me * t : towerEdgeType d)
  (Medium d me)
  (Medium d me)
where
  towerZero :
    (d : Nat) ->
    (me * t : towerEdgeType d) ->
    (i : Medium d me) ->
    (l : Medium d me) ->
    (case i of
      mediumZero contentType => contentType
      mediumSucc d' e' i' contentTypes =>
        -- note that e' * i' = me
        -- let (meme * met) * mel = me in
        -- t : Tower d' (meme * met) (nullMedium d' meme mel) mel
        -- contentTypes : Tower d' (meme * met) mel (nullMedium d' meme mel) -> Type
        (contentEdge : Tower d' e' i' (nullMedium d' e' l')) *
        contentTypes contentEdge) ->
    Tower d e i l




nullMedium :
  (d : Nat) -> (e : towerEdgeType d) -> Medium d e -> Medium d e
nullMedium d e m = case m of
  mediumZero c = mediumZero ()
  mediumSucc d' e' m' c = mediumSucc d' e' m' (\_ -> ())

towerEdgeType : (d : Nat) -> Type
towerEdgeType d = case d of
  0 => () * () * ()
  1 + d' =>
    (e : towerEdgeType d') *
    (l : Medium d' e) *
    Tower d' e (nullMedium l) l

-- TODO: mediumZero, mediumSucc, subtowerMedium, towerNullify

type Tower (d : Nat) (e : towerEdgeType d) (Medium d e) (Medium d e)
where
  nil :
    (d : Nat) ->
    (e : towerEdgeType d) ->
    (i : Medium d e) ->
    (l : Medium d e) ->
    (case i of
      mediumZero contentType => contentType
      mediumSucc d' e' contentTypes => contentTypes e) ->
    Tower d e i l
  cons
    (d : Nat) ->
    let d' = 1 + d in
    (e : towerEdgeType d') ->
    let ee * el * et = e in
    (i : Medium d' e) ->
    (l : Medium d' e) ->
    (subtowers : Tower d TODO el (subtowerMedium d e l i)) ->
    (case i of
      mediumSucc d'' e' contentTypes =>
        contentTypes
          (towerNullify d TODO e (subtowerMedium d e l i)
            subtowers) ->
        Tower d' e i l)

edgeLakeMedium :
  (d : Nat) -> (e : towerEdgeType d) -> Medium d e -> Medium d e
edgeLakeMedium d e i = case d of
  0 => mediumZero ()
  1 + d' => mediumSucc d' e i (\_ -> ())

edgeType : (d : Nat) -> (e : towerEdgeType d) -> Medium d e -> Type
edgeType d e i = Tower d e i (edgeLakeMedium d e i)

type Medium (d : Nat) (towerEdgeType d) where
  mediumZero : Type -> Medium 0 (() * () * ())
  mediumSucc :
    (d : Nat) ->
    (e : towerEdgeType (1 + d)) ->
    (m : Medium (1 + d) e) ->
    (edgeType (1 + d) e m -> Type) ->
    Medium (1 + d) e
