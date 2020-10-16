module Punctaffy.Hypersnippet.Hyperstack where

open import Level using (Level; _⊔_)

open import Punctaffy.Hypersnippet.Dim using (DimSys; dimLte)

data DimList {n l : Level} : DimSys {n} {l} → Set (n ⊔ l) → Set (n ⊔ l) where
  makeDimList : {ds : DimSys} → {a : Set (n ⊔ l)} → (len : DimSys.Carrier ds) → ((i : DimSys.Carrier ds) → dimLte {n} {l} {ds} i len → a) → DimList ds a
