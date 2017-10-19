
edgeLakeMedium : (d : Nat) -> Medium d -> Medium d
edgeLakeMedium d i = case d of
  0 => mediumZero ()
  1 + d' => mediumSucc d' (mediumEdge i) (\_ -> ())

edgeType : (d : Nat) -> Medium d -> Type
edgeType d i = Tower d i (edgeLakeMedium d i) refl

type Medium (d : Nat) where
  mediumZero : Type -> Medium 0
  mediumSucc :
    (d : Nat) -> (e : Medium d) -> (edgeType d e -> Type) ->
    Medium (1 + d)

mediumEdge : (d : Nat) -> Medium (1 + d) -> Medium d
mediumEdge d m = case m of
  mediumSucc d' edge contentTypes => edge

edgeEqType : (d : Nat) -> Medium d -> Medium d -> Type
edgeEqType d i l = case d in
  0 => () = ()
  1 + d' => mediumEdge d' i = mediumEdge d' l

towerMap :
  (d : Nat) ->
  (ix : Medium d) -> (lx : Medium d) -> (eqx : edgeEqType d ix lx) ->
  (iy : Medium d) -> (ly : Medium d) -> (eqy : edgeEqType d iy ly) ->
  (eqxy : edgeEqType d ix iy) ->
  (case (ix, iy) of
    (mediumZero tx, mediumZero ty) => () -> tx -> ty
    (mediumSucc dx ex cx, mediumSucc dy ey cy) =>
      (e : edgeType dx ex) -> cx e -> cy e) ->
  (case (lx, ly) of
    (mediumZero tx, mediumZero ty) => () -> tx -> ty
    (mediumSucc dx ex cx, mediumSucc dy ey cy) =>
      (e : edgeType dx ex) -> cx e -> cy e) ->
  Tower d ix lx eqx ->
  Tower d iy ly eqy
towerMap d ix lx eqx iy ly eqy eqxy ifunc lfunc tower = case tower of
  nil d' i l eq content =>
    nil d iy ly eqy
      (case d of
        0 => ifunc content
        1 + d' => case content of
          contentEdge * contentVal => contentEdge * ifunc contentVal)
  cons d' i l eq subtowers content =>
    cons d iy ly eqy
      (towerMap d'
        (mediumEdge ix)
        (subtowerMedium d' (mediumEdge lx) lx ix)
        refl
        (mediumEdge iy)
        (subtowerMedium d' (mediumEdge ly) ly iy)
        refl
        refl
        (\islandEdge island -> island)
        (\lakeEdge lake -> case lake of
          inl lake' => inl (lfunc lake')
          inr (subtowers * compatible) =>
            inr
              (towerMap d iy ly eqy ix lx eqx refl lfunc ifunc *
                compatible))
        subtowers)
      (case d of
        0 => ifunc content
        1 + d' => case content of
          contentEdge * contentVal => contentEdge * ifunc contentVal)

towerNullify :
  (d : Nat) -> (i : Medium d) -> (l : Medium d) ->
  (eqx : edgeEqType d i l) ->
  (eqy : edgeEqType d i (edgeLakeMedium d i)) ->
  Tower d i l eqx ->
  Tower d i (edgeLakeMedium d i) eqy
towerNullify d i l eqx eqy tower =
  towerMap d i l eqx i (edgeLakeMedium d i) eqy refl
    (\islandEdge island -> island)
    (\lakeEdge lake -> ())
    tower

merge : (x : a) -> (y : a) -> x = y -> a
merge x y eq = x

towerAllType :
  (d : Nat) -> (i : Medium d) -> (l : Medium d) ->
  (eq : edgeEqType d i l) ->
  (case i of
    mediumZero t => () -> t -> Type
    mediumSucc d e c => (edge : edgeType d e) -> c edge -> Type) ->
  (case l of
    mediumZero t => () -> t -> Type
    mediumSucc d e c => (edge : edgeType d e) -> c edge -> Type) ->
  Tower d i l eq ->
  Type
towerAllType d i l eq itype ltype tower = case tower of
  nil d' i' l' eq content => itype content
  cons d' i' l' eq subtowers content =>
    let im = merge i i' refl in
    let lm = merge l l' refl in
    let e = merge (mediumEdge im) (mediumEdge lm) eq in
    let sublake = (subtowerMedium d' e lm im) in
    itype (towerNullify d' e sublake refl refl subtowers) content *
    towerAllLakesType d' e sublake refl
      (\lakeEdge lake -> case lake of
        inl lakeVal => ()
        inr subtower => towerAllType d l i refl ltype itype subtower)
      subtowers

towerAllLakesType :
  (d : Nat) -> (i : Medium d) -> (l : Medium d) ->
  (eq : edgeEqType d i l) ->
  (case l of
    mediumZero t => () -> t -> Type
    mediumSucc d e c => (edge : edgeType d e) -> c edge -> Type) ->
  Tower d i l eq ->
  Type
towerAllLakesType d i l eq ltype tower =
  towerAllType d i l eq (\islandEdge island -> ()) ltype tower

type Medium (d : Nat) where
  mediumZero : Type -> Medium 0
  mediumSucc :
    (d : Nat) -> (e : Medium d) -> (edgeType d e -> Type) ->
    Medium (1 + d)

mediumCons :
  (d : Nat) -> (a : Medium d) -> (b : Medium d) ->
  (eq : edgeEqType d a b) ->
  Medium d
mediumCons d a b eq = case (a, b) of
  (mediumZero ca, mediumZero cb) => mediumZero (ca, cb)
  (mediumSucc da ea ca, mediumSucc db eb cb) =>
    mediumSucc (merge da db refl) (merge ea eb eq)
      (\content -> (ca content, cb content))

towerCons :
  (d : Nat) ->
  (ia : Medium d) -> (la : Medium d) -> (eqa : edgeEqType d ia la) ->
  (ib : Medium d) -> (lb : Medium d) -> (eqb : edgeEqType d ib lb) ->
  (eqi : edgeEqType d ia ib) ->
  (eql : edgeEqType d la lb) ->
  (eqy :
    edgeEqType d (mediumCons d ia ib eqi) (mediumCons d la lb eql)) ->
  Tower d ia la eqa ->
  Tower d ib lb eqb ->
  Tower d (mediumCons d ia ib eqi) (mediumCons d la lb eql) eqy
towerCons d ia la eqa ib lb eqb eqi eql eqy a b = case (a, b) of
  (nil da ia' la' eqa' contenta, nil db ib' lb' eqb' contentb) =>
    nil d (mediumCons d ia la eqa) (mediumCons d ib lb eqb) refl
      (contenta, contentb)
  (cons da ia' la' eqa' subtowersa contenta,
    cons db ib' lb' eqb' subtowersb contentb) =>
    let d' = merge da db refl in
    let e = merge (mediumEdge ia) (mediumEdge ib) eqi in
    cons d (mediumCons d ia la eqa) (mediumCons d ib lb eqb) refl
      (towerMap d'
        (mediumCons d' e e refl)
        (mediumCons d'
          (subtowerMedium d' e la ia)
          (subtowerMedium d' e lb ib)
          refl)
        refl
        e
        (subtowerMedium d e
          (mediumCons d la lb eql)
          (mediumCons d ia ib eqi))
        refl
        (\islandEdge island -> case island of
          -- TODO: See if there's some way we should be merging these.
          (ca, cb) => ca)
        (\lakeEdge lake -> case lake of
          (inl ca, inl cb) => inl (ca, cb)
          (inr subtowera, inr subtowerb) =>
            inr
              (towerCons d la ia refl lb ib refl refl refl refl
                subtowera subtowerb)
          _ => error "Expected towers a and b to be compatible")
        (towerCons d
          e (subtowerMedium d e la ia) refl
          e (subtowerMedium d e la ia) refl
          refl refl refl
          subtowersa subtowersb))
      (contenta, contentb)

towerEdge t = TODO

towerCompatibleType :
  (d : Nat) ->
  (ia : Medium d) -> (la : Medium d) -> (eqa : edgeEqType d ia la) ->
  Tower d ia la eqa ->
  (ib : Medium d) -> (lb : Medium d) -> (eqb : edgeEqType d ib lb) ->
  Tower d ib lb eqb ->
  edgeEqType d ia ib ->
  Type
towerCompatibleType d ia la eqa a ib lb eqb b eqi = case (a, b) of
  (nil da' ia' la' eqa' contenta, nil db' ib' lb' eqb' contentb) -> ()
  (cons da' ia' la' eqa' subtowersa contenta,
    cons db' ib' lb' eqb' subtowersb contentb) ->
    let d' = merge da' db' refl in
    let ea = merge (mediumEdge ia) (mediumEdge la) eqa in
    let eb = merge (mediumEdge ib) (mediumEdge lb) eqb in
    towerCompatibleType d'
      ea (subtowerMedium d' ea la ia) refl subtowersa
      eb (subtowerMedium d' eb lb ib) refl subtowersb
      refl *
    towerAllLakesType d
      (mediumCons d ia ib eqi)
      (mediumCons d la lb refl)
      refl
      (\lakeEdge lake -> case lake of
        (inl ca, inl cb) => ()
        (inr subtowera, inr subtowerb) =>
          towerCompatibleType d
            la ia refl subtowera lb ib refl subtowerb refl
        _ => Bot)
      (towerCons d'
        ea (subtowerMedium d' ea la ia) refl
        eb (subtowerMedium d' eb lb ib) refl
        refl refl refl
        subtowersa subtowersb)
  _ -> Bot

subtowerMedium :
  (d : Nat) ->
  Medium d ->
  (subtowerIsland : Medium (1 + d)) ->
  (subtowerLake : Medium (1 + d)) ->
  edgeEqType (1 + d) subtowerIsland subtowerLake ->
  Medium d
subtowerMedium d main subtowerIsland subtowerLake eq = case main of
  mediumZero t => mediumZero t
  mediumSucc d' thisMediumEdge contentTypes =>
    mediumSucc d' thisMediumEdge
      (\contentEdge ->
        contentTypes contentEdge +
        (
          (subtowers : Tower (1 + d) subtowerIsland subtowerLake eq) *
          towerCompatibleType d'
            TODO TODO refl contentEdge
            TODO TODO refl (towerEdge (towerEdge subtowers))
            refl))

type Tower (d : Nat) (i : Medium d) (l : Medium d)
  (eq : edgeEqType d i l)
where
  nil :
    (d : Nat) -> (i : Medium d) -> (l : Medium d) ->
    (eq : edgeEqType d i l) ->
    (case i of
      mediumZero contentType => contentType
      mediumSucc d' thisMediumEdge contentTypes =>
        (contentEdge : edgeType d' thisMediumEdge) *
        contentTypes contentEdge) ->
    Tower d i l eq
  cons :
    (d : Nat) -> (i : Medium (1 + d)) -> (l : Medium (1 + d)) ->
    (eq : edgeEqType (1 + d) i l) ->
    let e = merge (mediumEdge i) (mediumEdge l) eq in
    (subtowers : Tower d e (subtowerMedium d e l i) refl) ->
    (case i of
      mediumSucc d' thisMediumEdge contentTypes =>
        contentTypes
          (towerNullfiy d e (subtowerMedium d e l i) refl refl
            subtowers) ->
        Tower (1 + d) i l eq)
