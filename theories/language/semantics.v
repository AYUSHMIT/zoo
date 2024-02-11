From stdpp Require Import
  gmap.

From iris.algebra Require Import
  ofe.

From zebre Require Import
  prelude.
From zebre.language Require Export
  syntax.
From zebre Require Import
  options.

Implicit Types b : bool.
Implicit Types x : binder.
Implicit Types n m : Z.
Implicit Types l : loc.
Implicit Types tag : constr_tag.
Implicit Types lit : literal.
Implicit Types e : expr.
Implicit Types es : list expr.
Implicit Types v w : val.
Implicit Types vs : list val.
Implicit Types br : branch.
Implicit Types brs : list branch.

Definition literal_physical lit :=
  match lit with
  | LiteralBool _
  | LiteralInt _
  | LiteralLoc _ =>
      True
  | LiteralProphecy _
  | LiteralPoison =>
      False
  end.
#[global] Arguments literal_physical !_ / : assert.

Definition literal_eq lit1 lit2 :=
  match lit1, lit2 with
  | LiteralBool b1, LiteralBool b2 =>
      b1 = b2
  | LiteralInt i1, LiteralInt i2 =>
      i1 = i2
  | LiteralLoc l1, LiteralLoc l2 =>
      l1 = l2
  | LiteralLoc _, _
  | _, LiteralLoc _ =>
      False
  | _, _ =>
      True
  end.
#[global] Arguments literal_eq !_ !_ / : assert.

#[global] Instance literal_eq_refl :
  Reflexive literal_eq.
Proof.
  intros []; done.
Qed.
#[global] Instance literal_eq_sym :
  Symmetric literal_eq.
Proof.
  do 2 intros []; done.
Qed.

Definition val_physical v :=
  match v with
  | ValLiteral lit =>
      literal_physical lit
  | _ =>
      True
  end.
#[global] Arguments val_physical !_ / : assert.
Class ValPhysical v :=
  val_physical' : val_physical v.

Definition val_neq v1 v2 :=
  match v1, v2 with
  | ValLiteral lit1, ValLiteral lit2 =>
      lit1 ≠ lit2
  | ValConstr tag1 [], ValConstr tag2 [] =>
      tag1.2 ≠ tag2.2
  | _, _ =>
      True
  end.
#[global] Arguments val_neq !_ !_ / : assert.

#[global] Instance val_neq_sym :
  Symmetric val_neq.
Proof.
  do 2 intros [| | ? []]; done.
Qed.

Definition val_eq v1 v2 :=
  match v1 with
  | ValLiteral lit1 =>
      match v2 with
      | ValLiteral lit2 =>
          literal_eq lit1 lit2
      | ValConstr _ [] =>
          match lit1 with
          | LiteralBool _
          | LiteralInt _ =>
              True
          | _ =>
              False
          end
      | _ =>
          False
      end
  | ValRec f1 x1 e1 =>
      match v2 with
      | ValRec f2 x2 e2 =>
          f1 = f2 ∧ x1 = x2 ∧ e1 = e2
      | _ =>
          False
      end
  | ValConstr tag1 [] =>
      match v2 with
      | ValLiteral (LiteralBool _)
      | ValLiteral (LiteralInt _) =>
          True
      | ValConstr tag2 [] =>
          tag1.2 = tag2.2
      | _ =>
          False
      end
  | ValConstr tag1 es1 =>
      match v2 with
      | ValConstr tag2 es2 =>
          tag1.2 = tag2.2 ∧ es1 = es2
      | _ =>
          False
      end
  end.
#[global] Arguments val_eq !_ !_ / : assert.

#[global] Instance val_eq_refl :
  Reflexive val_eq.
Proof.
  intros [[] | | ? []]; done.
Qed.
#[global] Instance val_eq_sym :
  Symmetric val_eq.
Proof.
  do 2 intros [| | ? []]; naive_solver congruence.
Qed.
Lemma eq_val_eq v1 v2 :
  v1 = v2 →
  val_eq v1 v2.
Proof.
  destruct v1 as [| | ? []]; naive_solver.
Qed.

Definition unop_eval op v :=
  match op, v with
  | UnopNeg, ValLiteral (LiteralBool b) =>
      Some $ ValLiteral $ LiteralBool (negb b)
  | UnopMinus, ValLiteral (LiteralInt n) =>
      Some $ ValLiteral $ LiteralInt (- n)
  | _, _ =>
      None
  end.
#[global] Arguments unop_eval !_ !_ / : assert.

Definition binop_eval_int op n1 n2 :=
  match op with
  | BinopPlus =>
      Some $ LiteralInt (n1 + n2)
  | BinopMinus =>
      Some $ LiteralInt (n1 - n2)
  | BinopMult =>
      Some $ LiteralInt (n1 * n2)
  | BinopQuot =>
      Some $ LiteralInt (n1 `quot` n2)
  | BinopRem =>
      Some $ LiteralInt (n1 `rem` n2)
  | BinopLe =>
      Some $ LiteralBool (bool_decide (n1 ≤ n2))
  | BinopLt =>
      Some $ LiteralBool (bool_decide (n1 < n2))
  | BinopGe =>
      Some $ LiteralBool (bool_decide (n1 >= n2))
  | BinopGt =>
      Some $ LiteralBool (bool_decide (n1 > n2))
  | _ =>
      None
  end%Z.
#[global] Arguments binop_eval_int !_ _ _ / : assert.
Definition binop_eval op v1 v2 :=
  match v1, v2 with
  | ValLiteral (LiteralInt n1), ValLiteral (LiteralInt n2) =>
      ValLiteral <$> binop_eval_int op n1 n2
  | ValLiteral (LiteralLoc l), ValLiteral (LiteralInt n) =>
      if decide (op = BinopOffset) then
        Some $ ValLiteral $ LiteralLoc (l +ₗ n)
      else
        None
  | _, _ =>
      None
  end.
#[global] Arguments binop_eval !_ !_ !_ / : assert.

Fixpoint subst (x : string) v e :=
  match e with
  | Val _ =>
      e
  | Var y =>
      if decide (x = y) then
        Val v
      else
        Var y
  | Rec f y e =>
     Rec f y
       ( if decide (BNamed x ≠ f ∧ BNamed x ≠ y) then
           subst x v e
         else
           e
       )
  | App e1 e2 =>
      App
        (subst x v e1)
        (subst x v e2)
  | Unop op e =>
      Unop op
        (subst x v e)
  | Binop op e1 e2 =>
      Binop op
        (subst x v e1)
        (subst x v e2)
  | Equal e1 e2 =>
      Equal
        (subst x v e1)
        (subst x v e2)
  | If e0 e1 e2 =>
      If
      (subst x v e0)
      (subst x v e1)
      (subst x v e2)
  | Constr tag es =>
      Constr tag
        (subst x v <$> es)
  | Proj i e =>
      Proj i
        (subst x v e)
  | Case e0 y e1 brs =>
      Case
        (subst x v e0)
        y
        (subst x v e1)
        ( ( λ br,
              ( br.1,
                if decide (
                  Forall (BNamed x ≠.) br.1.(pattern_fields) ∧
                  BNamed x ≠ br.1.(pattern_as)
                ) then
                  subst x v br.2
                else
                  br.2
              )
          ) <$> brs
        )
  | Record es =>
      Record
        (subst x v <$> es)
  | Alloc e1 e2 =>
      Alloc
        (subst x v e1)
        (subst x v e2)
  | Load e =>
      Load
        (subst x v e)
  | Store e1 e2 =>
      Store
        (subst x v e1)
        (subst x v e2)
  | Xchg e1 e2 =>
      Xchg
        (subst x v e1)
        (subst x v e2)
  | Cas e0 e1 e2 =>
      Cas
        (subst x v e0)
        (subst x v e1)
        (subst x v e2)
  | Faa e1 e2 =>
      Faa
        (subst x v e1)
        (subst x v e2)
  | Fork e =>
      Fork
        (subst x v e)
  | Proph =>
      Proph
  | Resolve e0 e1 e2 =>
      Resolve
        (subst x v e0)
        (subst x v e1)
        (subst x v e2)
  end.
#[global] Arguments subst _ _ !_ / : assert.
Definition subst' x v :=
  match x with
  | BNamed x =>
      subst x v
  | BAnon =>
      id
  end.
#[global] Arguments subst' !_ _ / _ : assert.
Fixpoint subst_list xs vs e :=
  match xs, vs with
  | x :: xs, v :: vs =>
      subst' x v (subst_list xs vs e)
  | _, _ =>
      e
  end.
#[global] Arguments subst_list !_ !_ _ / : assert.

Fixpoint case_apply tag vs x e brs :=
  match brs with
  | [] =>
      subst' x (ValConstr tag vs) e
  | br :: brs =>
      let pat := br.1 in
      if decide (pat.(pattern_tag).2 = tag.2) then
        subst_list pat.(pattern_fields) vs $
        subst' pat.(pattern_as) (ValConstr tag vs) br.2
      else
        case_apply tag vs x e brs
  end.
#[global] Arguments case_apply _ _ _ _ !_ / : assert.

Record state : Type := {
  state_heap : gmap loc val ;
  state_prophs : gset prophecy_id ;
}.
Implicit Types σ : state.

Canonical stateO :=
  leibnizO state.

Definition state_update_heap f σ : state :=
  {|state_heap := f σ.(state_heap) ;
    state_prophs := σ.(state_prophs) ;
  |}.
#[global] Arguments state_update_heap _ !_ / : assert.
Definition state_update_prophs f σ : state :=
  {|state_heap := σ.(state_heap) ;
    state_prophs := f σ.(state_prophs) ;
  |}.
#[global] Arguments state_update_prophs _ !_ / : assert.

#[global] Instance state_inhabited : Inhabited state :=
  populate
    {|state_heap := inhabitant ;
      state_prophs := inhabitant ;
    |}.

Fixpoint heap_array l vs : gmap loc val :=
  match vs with
  | [] =>
      ∅
  | v :: vs =>
      <[l := v]> (heap_array (l +ₗ 1) vs)
  end.

Lemma heap_array_singleton l v :
  heap_array l [v] = {[l := v]}.
Proof.
  rewrite /heap_array insert_empty //.
Qed.
Lemma heap_array_lookup l vs w k :
  heap_array l vs !! k = Some w ↔
    ∃ j,
    (0 ≤ j)%Z ∧
    k = l +ₗ j ∧
    vs !! (Z.to_nat j) = Some w.
Proof.
  revert k l; induction vs as [|v' vs IH]=> l' l /=.
  { rewrite lookup_empty. naive_solver lia. }
  rewrite lookup_insert_Some IH. split.
  - intros [[-> ?] | (Hl & j & ? & -> & ?)].
    { eexists 0. rewrite loc_add_0. naive_solver lia. }
    eexists (1 + j)%Z. rewrite loc_add_assoc !Z.add_1_l Z2Nat.inj_succ; auto with lia.
  - intros (j & ? & -> & Hil). destruct (decide (j = 0)); simplify_eq/=.
    { rewrite loc_add_0; eauto. }
    right. split.
    { rewrite -{1}(loc_add_0 l). intros ?%(inj (loc_add _)); lia. }
    assert (Z.to_nat j = S (Z.to_nat (j - 1))) as Hj.
    { rewrite -Z2Nat.inj_succ; last lia. f_equal; lia. }
    rewrite Hj /= in Hil.
    eexists (j - 1)%Z. rewrite loc_add_assoc Z.add_sub_assoc Z.add_simpl_l. auto with lia.
Qed.
Lemma heap_array_map_disjoint h l vs :
  ( ∀ i,
    (0 ≤ i)%Z →
    (i < length vs)%Z →
    h !! (l +ₗ i) = None
  ) →
  heap_array l vs ##ₘ h.
Proof.
  intros Hdisj. apply map_disjoint_spec=> l' v1 v2.
  intros (j & ? & ? & Hj%lookup_lt_Some%inj_lt)%heap_array_lookup.
  rewrite Z2Nat.id // in Hj. naive_solver.
Qed.

Definition state_init_heap l vs σ :=
  state_update_heap (λ h, heap_array l vs ∪ h) σ.

Definition observation : Set :=
  prophecy_id * (val * val).

Inductive base_step : expr → state → list observation → expr → state → list expr → Prop :=
  | base_step_rec f x e σ :
      base_step
        (Rec f x e)
        σ
        []
        (Val $ ValRec f x e)
        σ
        []
  | base_step_beta f x e v e' σ :
      e' = subst' f (ValRec f x e) (subst' x v e) →
      base_step
        (App (Val $ ValRec f x e) (Val v))
        σ
        []
        e'
        σ
        []
  | base_step_unop op v v' σ :
      unop_eval op v = Some v' →
      base_step
        (Unop op $ Val v)
        σ
        []
        (Val v')
        σ
        []
  | base_step_binop op v1 v2 v' σ :
      binop_eval op v1 v2 = Some v' →
      base_step
        (Binop op (Val v1) (Val v2))
        σ
        []
        (Val v')
        σ
        []
  | base_step_equal_fail v1 v2 σ :
      val_physical v1 →
      val_physical v2 →
      val_neq v1 v2 →
      base_step
        (Equal (Val v1) (Val v2))
        σ
        []
        (Val $ ValLiteral $ LiteralBool false)
        σ
        []
  | base_step_equal_suc v1 v2 σ :
      val_physical v1 →
      val_eq v1 v2 →
      base_step
        (Equal (Val v1) (Val v2))
        σ
        []
        (Val $ ValLiteral $ LiteralBool true)
        σ
        []
  | base_step_if_true e1 e2 σ :
      base_step
        (If (Val $ ValLiteral $ LiteralBool true) e1 e2)
        σ
        []
        e1
        σ
        []
  | base_step_if_false e1 e2 σ :
      base_step
        (If (Val $ ValLiteral $ LiteralBool false) e1 e2)
        σ
        []
        e2
        σ
        []
  | base_step_constr tag es vs σ :
      es = of_vals vs →
      base_step
        (Constr tag es)
        σ
        []
        (Val $ ValConstr tag vs)
        σ
        []
  | base_step_proj i tag vs v σ :
      vs !! i = Some v →
      base_step
        (Proj i $ Val $ ValConstr tag vs)
        σ
        []
        (Val v)
        σ
        []
  | base_step_case tag vs x e brs σ :
      base_step
        (Case (Val $ ValConstr tag vs) x e brs)
        σ
        []
        (case_apply tag vs x e brs)
        σ
        []
  | base_step_record es vs σ l :
      0 < length es →
      es = of_vals vs →
      ( ∀ i,
        (0 ≤ i < length es)%Z →
        σ.(state_heap) !! (l +ₗ i) = None
      ) →
      base_step
        (Record es)
        σ
        []
        (Val $ ValLiteral $ LiteralLoc l)
        (state_init_heap l vs σ)
        []
  | base_step_alloc n v σ l :
      (0 < n)%Z →
      ( ∀ i,
        (0 ≤ i < n)%Z →
        σ.(state_heap) !! (l +ₗ i) = None
      ) →
      base_step
        (Alloc (Val $ ValLiteral $ LiteralInt n) (Val v))
        σ
        []
        (Val $ ValLiteral $ LiteralLoc l)
        (state_init_heap l (replicate (Z.to_nat n) v) σ)
        []
  | base_step_load l v σ :
      σ.(state_heap) !! l = Some v →
      base_step
        (Load $ Val $ ValLiteral $ LiteralLoc l)
        σ
        []
        (Val v)
        σ
        []
  | base_step_store l v w σ :
      σ.(state_heap) !! l = Some w →
      base_step
        (Store (Val $ ValLiteral $ LiteralLoc l) (Val v))
        σ
        []
        (Val ValUnit)
        (state_update_heap <[l := v]> σ)
        []
  | base_step_xchg l v w σ :
      σ.(state_heap) !! l = Some w →
      base_step
        (Xchg (Val $ ValLiteral $ LiteralLoc l) (Val v))
        σ
        []
        (Val w)
        (state_update_heap <[l := v]> σ)
        []
  | base_step_cas_fail l v1 v2 v σ :
      σ.(state_heap) !! l = Some v →
      val_physical v →
      val_physical v1 →
      val_neq v v1 →
      base_step
        (Cas (Val $ ValLiteral $ LiteralLoc l) (Val v1) (Val v2))
        σ
        []
        (Val $ ValLiteral $ LiteralBool false)
        σ
        []
  | base_step_cas_suc l v1 v2 v σ :
      σ.(state_heap) !! l = Some v →
      val_physical v →
      val_eq v v1 →
      base_step
        (Cas (Val $ ValLiteral $ LiteralLoc l) (Val v1) (Val v2))
        σ
        []
        (Val $ ValLiteral $ LiteralBool true)
        (state_update_heap <[l := v2]> σ)
        []
  | base_step_faa l n m σ :
      σ.(state_heap) !! l = Some $ ValLiteral $ LiteralInt m →
      base_step
        (Faa (Val $ ValLiteral $ LiteralLoc l) (Val $ ValLiteral $ LiteralInt n))
        σ
        []
        (Val $ ValLiteral $ LiteralInt m)
        (state_update_heap <[l := ValLiteral $ LiteralInt (m + n)]> σ)
        []
  | base_step_fork e σ :
      base_step
        (Fork e)
        σ
        []
        (Val ValUnit)
        σ
        [e]
  | base_step_proph σ p :
      p ∉ σ.(state_prophs) →
      base_step
        Proph
        σ
        []
        (Val $ ValLiteral $ LiteralProphecy p)
        (state_update_prophs ({[p]} ∪.) σ)
        []
  | base_step_resolve e p v σ κ w σ' es :
      base_step e σ κ (Val w) σ' es →
      base_step
        (Resolve e (Val $ ValLiteral $ LiteralProphecy p) (Val v))
        σ
        (κ ++ [(p, (w, v))])
        (Val w)
        σ'
        es.

Lemma base_step_record' es vs σ :
  let l := loc_fresh (dom σ.(state_heap)) in
  0 < length es →
  es = of_vals vs →
  base_step
    (Record es)
    σ
    []
    (Val $ ValLiteral $ LiteralLoc l)
    (state_init_heap l vs σ)
    [].
Proof.
  intros. apply base_step_record; [done.. |].
  intros. apply not_elem_of_dom, loc_fresh_fresh. naive_solver.
Qed.
Lemma base_step_alloc' v n σ :
  let l := loc_fresh (dom σ.(state_heap)) in
  (0 < n)%Z →
  base_step
    (Alloc ((Val $ ValLiteral $ LiteralInt $ n)) (Val v))
    σ
    []
    (Val $ ValLiteral $ LiteralLoc l)
    (state_init_heap l (replicate (Z.to_nat n) v) σ)
    [].
Proof.
  intros. apply base_step_alloc; first done.
  intros. apply not_elem_of_dom, loc_fresh_fresh. naive_solver.
Qed.
Lemma base_step_proph' σ :
  let p := fresh σ.(state_prophs) in
  base_step
    Proph
    σ
    []
    (Val $ ValLiteral $ LiteralProphecy p)
    (state_update_prophs ({[p]} ∪.) σ)
    [].
Proof.
  constructor. apply is_fresh.
Qed.

Lemma val_base_stuck e1 σ1 κ e2 σ2 es :
  base_step e1 σ1 κ e2 σ2 es →
  to_val e1 = None.
Proof.
  destruct 1; naive_solver.
Qed.

Inductive ectxi :=
  | CtxAppL v2
  | CtxAppR e1
  | CtxUnop (op : unop)
  | CtxBinopL (op : binop) v2
  | CtxBinopR (op : binop) e1
  | CtxEqualL v2
  | CtxEqualR e1
  | CtxIf e1 e2
  | CtxConstr tag vs es
  | CtxProj (i : nat)
  | CtxCase x e1 brs
  | CtxRecord vs es
  | CtxAllocL v2
  | CtxAllocR e1
  | CtxLoad
  | CtxStoreL v2
  | CtxStoreR e1
  | CtxXchgL v2
  | CtxXchgR e1
  | CtxCasL v1 v2
  | CtxCasM e0 v2
  | CtxCasR e0 e1
  | CtxFaaL v2
  | CtxFaaR e1
  | CtxResolveL (k : ectxi) v1 v2
  | CtxResolveM e0 v2
  | CtxResolveR e0 e1.
Implicit Types k : ectxi.

Fixpoint ectxi_fill k e : expr :=
  match k with
  | CtxAppL v2 =>
      App e $ Val v2
  | CtxAppR e1 =>
      App e1 e
  | CtxUnop op =>
      Unop op e
  | CtxBinopL op v2 =>
      Binop op e $ Val v2
  | CtxBinopR op e1 =>
      Binop op e1 e
  | CtxEqualL v2 =>
      Equal e $ Val v2
  | CtxEqualR e1 =>
      Equal e1 e
  | CtxIf e1 e2 =>
      If e e1 e2
  | CtxConstr tag vs es =>
      Constr tag $ of_vals vs ++ e :: es
  | CtxProj i =>
      Proj i e
  | CtxCase x e1 brs =>
      Case e x e1 brs
  | CtxRecord vs es =>
      Record $ of_vals vs ++ e :: es
  | CtxAllocL v2 =>
      Alloc e $ Val v2
  | CtxAllocR e1 =>
      Alloc e1 e
  | CtxLoad =>
      Load e
  | CtxStoreL v2 =>
      Store e $ Val v2
  | CtxStoreR e1 =>
      Store e1 e
  | CtxXchgL v2 =>
      Xchg e $ Val v2
  | CtxXchgR e1 =>
      Xchg e1 e
  | CtxCasL v1 v2 =>
      Cas e (Val v1) (Val v2)
  | CtxCasM e0 v2 =>
      Cas e0 e $ Val v2
  | CtxCasR e0 e1 =>
      Cas e0 e1 e
  | CtxFaaL v2 =>
      Faa e $ Val v2
  | CtxFaaR e1 =>
      Faa e1 e
  | CtxResolveL k v1 v2 =>
      Resolve (ectxi_fill k e) (Val v1) (Val v2)
  | CtxResolveM e0 v2 =>
      Resolve e0 e $ Val v2
  | CtxResolveR e0 e1 =>
      Resolve e0 e1 e
  end.
#[global] Arguments ectxi_fill !_ _ / : assert.

#[global] Instance ectxi_fill_inj k :
  Inj (=) (=) (ectxi_fill k).
Proof.
  induction k; intros ? ? ?; simplify; auto with f_equal.
Qed.
Lemma ectxi_fill_val k e :
  is_Some (to_val (ectxi_fill k e)) →
  is_Some (to_val e).
Proof.
  intros (v & ?). induction k; simplify_option_eq; eauto.
Qed.
Lemma ectxi_fill_no_val_inj k1 e1 k2 e2 :
  to_val e1 = None →
  to_val e2 = None →
  ectxi_fill k1 e1 = ectxi_fill k2 e2 →
  k1 = k2.
Proof.
  move: k1. induction k2; intros k1; induction k1; try naive_solver eauto with f_equal.
  all: move=> /= H1 H2 H; injection H => {H} H' *; subst.
  all: apply app_inj_1 in H'; first naive_solver.
  all: clear- H1 H2 H'.
  all:
    match goal with |- length (of_vals ?vs1) = length (of_vals ?vs2) =>
      move: vs2 H'; induction vs1; intros []; naive_solver
    end.
Qed.
Lemma base_step_ectxi_fill_val k e σ1 κ e2 σ2 es :
  base_step (ectxi_fill k e) σ1 κ e2 σ2 es →
  is_Some (to_val e).
Proof.
  move: κ e2. induction k; try by (inversion_clear 1; simplify_option_eq; eauto).
  all: inversion_clear 1.
  all:
    match goal with H: of_vals ?vs' ++ _ = of_vals ?vs |- _ =>
      clear- H; move: vs H; induction vs'; intros []; naive_solver
    end.
Qed.

Definition ectx :=
  list ectxi.
