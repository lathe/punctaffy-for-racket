module Punctaffy.Hypersnippet.Dim where

open import Level using (Level; suc; _⊔_)
open import Algebra.Bundles using (IdempotentCommutativeMonoid)
open import Algebra.Morphism using (IsIdempotentCommutativeMonoidMorphism)


-- For all the purposes we have for it so far, a `DimSys` is a bounded
-- semilattice. The `agda-stdlib` library calls this an idempotent commutative
-- monoid.
record DimSys {n l : Level} : Set (suc (n ⊔ l)) where
  field
    dimIdempotentCommutativeMonoid : IdempotentCommutativeMonoid n l
  open IdempotentCommutativeMonoid dimIdempotentCommutativeMonoid public

record DimSysMorphism {n₀ n₁ l₀ l₁ : Level} : Set (suc (n₀ ⊔ n₁ ⊔ l₀ ⊔ l₁)) where
  field
    From : DimSys {n₀} {l₀}
    To : DimSys {n₁} {l₁}

  private
    module F = DimSys From
    module T = DimSys To

  field
    morphDim : F.Carrier → T.Carrier
    isIdempotentCommutativeMonoidMorphism :
      IsIdempotentCommutativeMonoidMorphism F.dimIdempotentCommutativeMonoid T.dimIdempotentCommutativeMonoid morphDim

dimLte : {n l : Level} → {ds : DimSys {n} {l}} → DimSys.Carrier ds → DimSys.Carrier ds → Set l
dimLte {n} {l} {ds} a b = DimSys._≈_ ds (DimSys._∙_ ds a b) b
