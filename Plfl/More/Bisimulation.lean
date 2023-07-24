-- https://plfa.github.io/Bisimulation/

import Plfl.Init
import Plfl.More

open More
open Subst Notation

-- https://plfa.github.io/Bisimulation/#simulation
inductive Sim : (Γ ⊢ a) → (Γ ⊢ a) → Prop where
| var : Sim (` x)  (` x)
| lam : Sim n n' → Sim (ƛ n) (ƛ n')
| ap : Sim l l' → Sim m m' → Sim (l □ m) (l' □ m')
| let : Sim l l' → Sim m m' → Sim (.let l m) (.let l' m')

namespace Sim
  scoped infix:40 " ~ " => Sim

  theorem refl_dec (t : Γ ⊢ a) : Decidable (t ~ t) := by
    cases t with try (apply isFalse; intro s; contradiction)
    | var i => exact isTrue .var
    | lam t =>
      if h : t ~ t
        then apply isTrue; exact .lam h
        else apply isFalse; intro (.lam s); exact h s
    | ap l m =>
      if h : (l ~ l) ∧ (m ~ m)
        then apply isTrue; exact .ap h.1 h.2
        else apply isFalse; intro (.ap s s'); exact h ⟨s, s'⟩
    | «let» m n =>
      if h : (m ~ m) ∧ (n ~ n)
        then apply isTrue; exact .let h.1 h.2
        else apply isFalse; intro (.let s s'); exact h ⟨s, s'⟩

  -- https://plfa.github.io/Bisimulation/#exercise-_-practice
  lemma of_eq {s : (m : Γ ⊢ a) ~ m'} : (m' = n) → (m ~ n) := by
    intro h; rwa [h] at s

  lemma to_eq {s : (m : Γ ⊢ a) ~ m'} : (m ~ n) → (m' = n) := by
    intro s'; match s, s' with
    | s, .var => cases s with
      | var => rfl
    | s, .lam s' => cases s with
      | lam s'' => simp only [to_eq (s := s'') s']
    | s, .ap sl sm => cases s with
      | ap sl' sm' => simp only [to_eq (s := sl') sl, to_eq (s := sm') sm]
    | s, .let sm sn => cases s with
      | «let» sm' sn' => simp only [to_eq (s := sm') sm, to_eq (s := sn') sn]

  -- https://plfa.github.io/Bisimulation/#simulation-commutes-with-values
  def commValue {m m' : Γ ⊢ a} : (m ~ m') → Value m → Value m' := by
    intro s v; cases v with try contradiction
    | lam => cases m' with try contradiction
      | lam => exact .lam

  -- https://plfa.github.io/Bisimulation/#exercise-val¹-practice
  def commValue' {m m' : Γ ⊢ a} : (m ~ m') → Value m' → Value m := by
    intro s v; cases v with try contradiction
    | lam => cases m with try contradiction
      | lam => exact .lam

  -- https://plfa.github.io/Bisimulation/#simulation-commutes-with-renaming
  def comm_rename (ρ : ∀ {a}, Γ ∋ a → Δ ∋ a) {m m' : Γ ⊢ a}
  : m ~ m' → rename ρ m ~ rename ρ m'
  := by intro
  | .var => exact .var
  | .lam s => apply lam; exact comm_rename (ext ρ) s
  | .ap sl sm => apply ap; repeat (apply comm_rename ρ; trivial)
  | .let sl sm => apply «let»; repeat
    first | apply comm_rename ρ | apply comm_rename (ext ρ)
    trivial

  -- https://plfa.github.io/Bisimulation/#simulation-commutes-with-substitution
  def comm_exts {σ σ' : ∀ {a}, Γ ∋ a → Δ ⊢ a}
  (gs : ∀ {a}, (x : Γ ∋ a) → σ x ~ σ' x)
  : (∀ {a b}, (x : Γ‚ b ∋ a) → exts σ x ~ exts σ' x)
  := by introv; match x with
  | .z => simp only [exts]; exact .var
  | .s x => simp only [exts]; apply comm_rename Lookup.s; apply gs

  def comm_subst {σ σ' : ∀ {a}, Γ ∋ a → Δ ⊢ a}
  (gs : ∀ {a}, (x : Γ ∋ a) → @σ a x ~ @σ' a x)
  {m m' : Γ ⊢ a}
  : m ~ m' → subst σ m ~ subst σ' m'
  := by intro
  | .var => apply gs
  | .lam s => apply lam; exact comm_subst (comm_exts gs) s
  | .ap sl sm => apply ap; repeat (apply comm_subst gs; trivial)
  | .let sm sn => apply «let»; repeat
    first | apply comm_subst gs | apply comm_subst (comm_exts gs)
    trivial

  def comm_subst₁ {m m' : Γ ⊢ b} {n n' : Γ‚ b ⊢ a}
  (sm : m ~ m') (sn : n ~ n') : n⟦m⟧ ~ n'⟦m'⟧
  := by
    let σ {a} : Γ‚ b ∋ a → Γ ⊢ a := subst₁σ m
    let σ' {a} : Γ‚ b ∋ a → Γ ⊢ a := subst₁σ m'
    let gs {a} (x : Γ‚ b ∋ a) : (@σ a x) ~ (@σ' a x) := match x with
    | .z => sm
    | .s x => .var
    simp only [subst₁];
    exact comm_subst (Γ := Γ‚ b) (Δ := Γ) (σ := σ) (σ' := σ') gs sn
end Sim

/-
Now we can actually prove that `Sim` is a real bisimulation by giving the construction
of the lower leg of the diagram from the upper leg and vice versa.
-/

open Sim Reduce

-- https://plfa.github.io/Bisimulation/#the-relation-is-a-simulation
/--
`Leg m' n` stands for the leg
```txt
          n
          |
          ~
          |
m' - —→ - n'
```
-/
inductive Leg (m' n : Γ ⊢ a) : Prop where
| intro (sim : n ~ n') (red : m' —→ n')

def Leg.fromLegInv {m m' n : Γ ⊢ a} (s : m ~ m') (r : m —→ n) : Leg m' n := by
  match s with
  | .ap sl sm => match r with
    | .lamβ v => cases sl with | lam sl =>
      constructor
      · apply comm_subst₁ <;> trivial
      · apply lamβ; exact commValue sm v
    | .apξ₁ r =>
      have ⟨s', r'⟩ := fromLegInv sl r; constructor
      · apply ap <;> trivial
      · apply apξ₁ r'
    | .apξ₂ v r =>
      have ⟨s', r'⟩ := fromLegInv sm r; constructor
      · apply ap <;> trivial
      · refine apξ₂ ?_ r'; exact commValue sl v
  | .let sm sn => match r with
    | .letξ r =>
      have ⟨s', r'⟩ := fromLegInv sm r; constructor
      · apply «let» <;> trivial
      · apply letξ; exact r'
    | .letβ v =>
      constructor
      · apply comm_subst₁ <;> trivial
      · apply letβ; exact commValue sm v

-- https://plfa.github.io/Bisimulation/#exercise-sim¹-practice
/--
`LegInv m n'` stands for the leg
```txt
m - —→ - n
         |
         ~
         |
         n'
```
-/
inductive LegInv (m n' : Γ ⊢ a) : Prop where
| intro (sim : n ~ n') (red : m —→ n)

def LegInv.fromLeg {m m' n' : Γ ⊢ a} (s : m ~ m') (r : m' —→ n') : LegInv m n' := by
  match s with
  | .ap sl sm => match r with
    | .lamβ v => cases sl with | lam sl =>
      constructor
      · apply comm_subst₁ <;> trivial
      · apply lamβ; exact commValue' sm v
    | .apξ₁ r =>
      have ⟨s', r'⟩ := fromLeg sl r; constructor
      · apply ap <;> trivial
      · apply apξ₁ r'
    | .apξ₂ v r =>
      have ⟨s', r'⟩ := fromLeg sm r; constructor
      · apply ap <;> trivial
      · refine apξ₂ ?_ r'; exact commValue' sl v
  | .let sm sn => match r with
    | .letξ r =>
      have ⟨s', r'⟩ := fromLeg sm r; constructor
      · apply «let» <;> trivial
      · apply letξ; exact r'
    | .letβ v =>
      constructor
      · apply comm_subst₁ <;> trivial
      · apply letβ; exact commValue' sm v
