From stdpp Require Import
  countable.
From stdpp Require Export
  binders.

From iris.algebra Require Import
  ofe.

From zebre Require Import
  prelude.
From zebre.language Require Export
  loc.
From zebre Require Import
  options.

Implicit Types b : bool.
Implicit Types n : Z.
Implicit Types l : loc.
Implicit Types f x : binder.

Definition prophecy_id :=
  positive.
Implicit Types p : prophecy_id.

Inductive literal :=
  | LiteralBool b
  | LiteralInt n
  | LiteralLoc l
  | LiteralProphecy p
  | LiteralPoison.
Implicit Types lit : literal.

#[global] Instance literal_eq_dec : EqDecision literal :=
  ltac:(solve_decision).
#[global] Instance literal_countable :
  Countable literal.
Proof.
  pose encode lit :=
    match lit with
    | LiteralBool b =>
        inl $ inl $ inl $ inl b
    | LiteralInt n =>
        inl $ inl $ inl $ inr n
    | LiteralLoc l =>
        inl $ inl $ inr l
    | LiteralProphecy p =>
        inl $ inr p
    | LiteralPoison =>
        inr ()
    end.
  pose decode _lit :=
    match _lit with
    | inl (inl (inl (inl b))) =>
        LiteralBool b
    | inl (inl (inl (inr n))) =>
        LiteralInt n
    | inl (inl (inr l)) =>
        LiteralLoc l
    | inl (inr p) =>
        LiteralProphecy p
    | inr () =>
        LiteralPoison
    end.
  refine (inj_countable' encode decode _); intros []; done.
Qed.

Inductive unop :=
  | UnopNeg
  | UnopMinus.

#[global] Instance unop_eq_dec : EqDecision unop :=
  ltac:(solve_decision).
#[global] Instance unop_countable :
  Countable unop.
Proof.
  pose encode op :=
    match op with
    | UnopNeg => 0
    | UnopMinus => 1
    end.
  pose decode op :=
    match op with
    | 0 => UnopNeg
    | _ => UnopMinus
    end.
  refine (inj_countable' encode decode _); intros []; done.
Qed.

Inductive binop :=
  | BinopPlus | BinopMinus | BinopMult | BinopQuot | BinopRem
  | BinopLe | BinopLt | BinopGe | BinopGt
  | BinopOffset.

#[global] Instance binop_eq_dec : EqDecision binop :=
  ltac:(solve_decision).
#[global] Instance binop_countable :
  Countable binop.
Proof.
  pose encode op :=
    match op with
    | BinopPlus => 0
    | BinopMinus => 1
    | BinopMult => 2
    | BinopQuot => 3
    | BinopRem => 4
    | BinopLe => 5
    | BinopLt => 6
    | BinopGe => 7
    | BinopGt => 8
    | BinopOffset => 9
  end.
  pose decode op :=
    match op with
    | 0 => BinopPlus
    | 1 => BinopMinus
    | 2 => BinopMult
    | 3 => BinopQuot
    | 4 => BinopRem
    | 5 => BinopLe
    | 6 => BinopLt
    | 7 => BinopGe
    | 8 => BinopGt
    | _ => BinopOffset
  end.
  refine (inj_countable' encode decode _); intros []; done.
Qed.

Unset Elimination Schemes.
Inductive expr :=
  | Val (v : val)
  | Var (x : string)
  | Rec f x (e : expr)
  | App (e1 e2 : expr)
  | Unop (op : unop) (e : expr)
  | Binop (op : binop) (e1 e2 : expr)
  | Equal (e1 e2 : expr)
  | If (e0 e1 e2 : expr)
  | Tuple (es : list expr)
  | Proj (i : nat) (e : expr)
  | Constr b (e : expr)
  | Case (e0 e1 e2 : expr)
  | Record (es : list expr)
  | Alloc (e1 e2 : expr)
  | Load (e : expr)
  | Store (e1 e2 : expr)
  | Xchg (e1 e2 : expr)
  | Cas (e0 e1 e2 : expr)
  | Faa (e1 e2 : expr)
  | Fork (e : expr)
  | Proph
  | Resolve (e0 e1 e2 : expr)
with val :=
  | ValLiteral lit
  | ValRec f x (e : expr)
  | ValTuple (vs : list val)
  | ValConstr b (v : val).
Set Elimination Schemes.
Implicit Types e : expr.
Implicit Types v : val.
Implicit Types vs : list val.

Section val_ind.
  Variable P : val → Prop.

  Variable HValLiteral : ∀ lit,
    P (ValLiteral lit).
  Variable HValRec : ∀ f x e,
    P (ValRec f x e).
  Variable HValTuple :
    ∀ vs, Forall P vs →
    P (ValTuple vs).
  Variable HValConstr : ∀ b,
    ∀ v, P v →
    P (ValConstr b v).

  Fixpoint val_ind v :=
    match v with
    | ValLiteral lit =>
        HValLiteral lit
    | ValRec f x e =>
        HValRec f x e
    | ValTuple vs =>
        HValTuple
          vs (Forall_true P vs val_ind)
    | ValConstr b v =>
        HValConstr b
          v (val_ind v)
    end.
End val_ind.

Section expr_ind.
  Variable P : expr → Prop.

  Variable HVal : ∀ v,
    P (Val v).
  Variable HVar : ∀ (x : string),
    P (Var x).
  Variable HRec : ∀ f x,
    ∀ e, P e →
    P (Rec f x e).
  Variable HApp :
    ∀ e1, P e1 →
    ∀ e2, P e2 →
    P (App e1 e2).
  Variable HUnop : ∀ op,
    ∀ e, P e →
    P (Unop op e).
  Variable HBinop : ∀ op,
    ∀ e1, P e1 →
    ∀ e2, P e2 →
    P (Binop op e1 e2).
  Variable HEqual :
    ∀ e1, P e1 →
    ∀ e2, P e2 →
    P (Equal e1 e2).
  Variable HIf :
    ∀ e0, P e0 →
    ∀ e1, P e1 →
    ∀ e2, P e2 →
    P (If e0 e1 e2).
  Variable HTuple :
    ∀ es, Forall P es →
    P (Tuple es).
  Variable HProj : ∀ i,
    ∀ e, P e →
    P (Proj i e).
  Variable HConstr : ∀ b,
    ∀ e, P e →
    P (Constr b e).
  Variable HCase :
    ∀ e0, P e0 →
    ∀ e1, P e1 →
    ∀ e2, P e2 →
    P (Case e0 e1 e2).
  Variable HRecord :
    ∀ es, Forall P es →
    P (Record es).
  Variable HAlloc :
    ∀ e1, P e1 →
    ∀ e2, P e2 →
    P (Alloc e1 e2).
  Variable HLoad :
    ∀ e, P e →
    P (Load e).
  Variable HStore :
    ∀ e1, P e1 →
    ∀ e2, P e2 →
    P (Store e1 e2).
  Variable HXchg :
    ∀ e1, P e1 →
    ∀ e2, P e2 →
    P (Xchg e1 e2).
  Variable HCas :
    ∀ e0, P e0 →
    ∀ e1, P e1 →
    ∀ e2, P e2 →
    P (Cas e0 e1 e2).
  Variable HFaa :
    ∀ e1, P e1 →
    ∀ e2, P e2 →
    P (Faa e1 e2).
  Variable HFork :
    ∀ e, P e →
    P (Fork e).
  Variable HProph :
    P Proph.
  Variable HResolve :
    ∀ e0, P e0 →
    ∀ e1, P e1 →
    ∀ e2, P e2 →
    P (Resolve e0 e1 e2).

  Fixpoint expr_ind e :=
    match e with
    | Val v =>
        HVal v
    | Var x =>
        HVar x
    | Rec f x e =>
        HRec f x
          e (expr_ind e)
    | App e1 e2 =>
        HApp
          e1 (expr_ind e1)
          e2 (expr_ind e2)
    | Unop op e =>
        HUnop op
          e (expr_ind e)
    | Binop op e1 e2 =>
        HBinop op
          e1 (expr_ind e1)
          e2 (expr_ind e2)
    | Equal e1 e2 =>
        HEqual
          e1 (expr_ind e1)
          e2 (expr_ind e2)
    | If e0 e1 e2 =>
        HIf
          e0 (expr_ind e0)
          e1 (expr_ind e1)
          e2 (expr_ind e2)
    | Tuple es =>
        HTuple
          es (Forall_true P es expr_ind)
    | Proj i e =>
        HProj i
          e (expr_ind e)
    | Constr b e =>
        HConstr b
          e (expr_ind e)
    | Case e0 e1 e2 =>
        HCase
          e0 (expr_ind e0)
          e1 (expr_ind e1)
          e2 (expr_ind e2)
    | Record es =>
        HRecord
          es (Forall_true P es expr_ind)
    | Alloc e1 e2 =>
        HAlloc
          e1 (expr_ind e1)
          e2 (expr_ind e2)
    | Load e =>
        HLoad
          e (expr_ind e)
    | Store e1 e2 =>
        HStore
          e1 (expr_ind e1)
          e2 (expr_ind e2)
    | Xchg e1 e2 =>
        HXchg
          e1 (expr_ind e1)
          e2 (expr_ind e2)
    | Cas e0 e1 e2 =>
        HCas
          e0 (expr_ind e0)
          e1 (expr_ind e1)
          e2 (expr_ind e2)
    | Faa e1 e2 =>
        HFaa
          e1 (expr_ind e1)
          e2 (expr_ind e2)
    | Fork e =>
        HFork
          e (expr_ind e)
    | Proph =>
        HProph
    | Resolve e0 e1 e2 =>
        HResolve
          e0 (expr_ind e0)
          e1 (expr_ind e1)
          e2 (expr_ind e2)
    end.
End expr_ind.

Canonical valO :=
  leibnizO val.
Canonical exprO :=
  leibnizO expr.

Notation Injl := (
  Constr true
).
Notation Injr := (
  Constr false
).

Notation ValUnit := (
  ValTuple []
).
Notation ValInjl := (
  ValConstr true
).
Notation ValInjr := (
  ValConstr false
).

Notation of_val :=
  Val
( only parsing
).
Definition to_val e :=
  match e with
  | Val v =>
      Some v
  | _ =>
      None
  end.

Lemma to_of_val v :
  to_val (of_val v) = Some v.
Proof.
  by destruct v.
Qed.
Lemma of_to_val e v :
  to_val e = Some v →
  of_val v = e.
Proof.
  destruct e => //=. by intros [= <-].
Qed.
#[global] Instance of_val_inj :
  Inj (=) (=) of_val.
Proof.
  intros ?*. congruence.
Qed.

Definition of_vals vs :=
  of_val <$> vs.
Fixpoint to_vals es :=
  match es with
  | [] =>
      Some []
  | e :: es =>
      v ← to_val e ;
      es ← to_vals es ;
      mret $ v :: es
  end.

Lemma to_of_vals vs :
  to_vals (of_vals vs) = Some vs.
Proof.
  induction vs as [| v vs IH]; first done.
  rewrite /= IH. naive_solver.
Qed.
Lemma of_to_vals es vs :
  to_vals es = Some vs →
  of_vals vs = es.
Proof.
  revert vs. induction es as [| e es IH]; first naive_solver. move=> [| v vs] /= H.
  all: destruct (to_val e) eqn:Heq, (to_vals es); try done.
  invert H.
  f_equal; last naive_solver.
  destruct e; naive_solver.
Qed.
#[global] Instance of_vals_inj :
  Inj (=) (=) of_vals.
Proof.
  apply _.
Qed.
Lemma of_vals_length vs :
  length (of_vals vs) = length vs.
Proof.
  rewrite map_length //.
Qed.

#[global] Instance val_inhabited : Inhabited val :=
  populate ValUnit.
#[global] Instance expr_inhabited : Inhabited expr :=
  populate (Val inhabitant).
#[global] Instance expr_eq_dec : EqDecision expr.
Proof.
  unshelve refine (
    fix go e1 e2 : Decision (e1 = e2) :=
      let fix go_list es1 es2 : Decision (es1 = es2) :=
        match es1, es2 with
        | [], [] =>
            left _
        | e1 :: es1, e2 :: es2 =>
            cast_if_and
              (decide (e1 = e2))
              (decide (es1 = es2))
        | _, _ =>
            right _
        end
      in
      match e1, e2 with
      | Val v1, Val v2 =>
          cast_if
            (decide (v1 = v2))
      | Var x1, Var x2 =>
          cast_if
            (decide (x1 = x2))
      | Rec f1 x1 e1, Rec f2 x2 e2 =>
         cast_if_and3
           (decide (f1 = f2))
           (decide (x1 = x2))
           (decide (e1 = e2))
      | App e11 e12, App e21 e22 =>
          cast_if_and
            (decide (e11 = e21))
            (decide (e12 = e22))
      | Unop op1 e1, Unop op2 e2 =>
          cast_if_and
            (decide (op1 = op2))
            (decide (e1 = e2))
      | Binop op1 e11 e12, Binop op2 e21 e22 =>
         cast_if_and3
           (decide (op1 = op2))
           (decide (e11 = e21))
           (decide (e12 = e22))
      | Equal e11 e12, Equal e21 e22 =>
          cast_if_and
            (decide (e11 = e21))
            (decide (e12 = e22))
      | If e10 e11 e12, If e20 e21 e22 =>
         cast_if_and3
           (decide (e10 = e20))
           (decide (e11 = e21))
           (decide (e12 = e22))
      | Tuple es1, Tuple es2 =>
          cast_if
            (decide (es1 = es2))
      | Proj i1 e1, Proj i2 e2 =>
          cast_if_and
            (decide (i1 = i2))
            (decide (e1 = e2))
      | Constr b1 e1, Constr b2 e2 =>
          cast_if_and
            (decide (b1 = b2))
            (decide (e1 = e2))
      | Case e10 e11 e12, Case e20 e21 e22 =>
          cast_if_and3
            (decide (e10 = e20))
            (decide (e11 = e21))
            (decide (e12 = e22))
      | Record es1, Record es2 =>
          cast_if
            (decide (es1 = es2))
      | Alloc e11 e12, Alloc e21 e22 =>
         cast_if_and
           (decide (e11 = e21))
           (decide (e12 = e22))
      | Load e1, Load e2 =>
          cast_if
            (decide (e1 = e2))
      | Store e11 e12, Store e21 e22 =>
         cast_if_and
           (decide (e11 = e21))
           (decide (e12 = e22))
      | Xchg e11 e12, Xchg e21 e22 =>
          cast_if_and
            (decide (e11 = e21))
            (decide (e12 = e22))
      | Cas e10 e11 e12, Cas e20 e21 e22 =>
         cast_if_and3
           (decide (e10 = e20))
           (decide (e11 = e21))
           (decide (e12 = e22))
      | Faa e11 e12, Faa e21 e22 =>
         cast_if_and
           (decide (e11 = e21))
           (decide (e12 = e22))
      | Fork e1, Fork e2 =>
          cast_if
            (decide (e1 = e2))
      | Proph, Proph =>
          left _
      | Resolve e10 e11 e12, Resolve e20 e21 e22 =>
         cast_if_and3
           (decide (e10 = e20))
           (decide (e11 = e21))
           (decide (e12 = e22))
      | _, _ =>
          right _
      end
    with go_val v1 v2 : Decision (v1 = v2) :=
      let fix go_list vs1 vs2 : Decision (vs1 = vs2) :=
        match vs1, vs2 with
        | [], [] =>
            left _
        | v1 :: vs1, v2 :: vs2 =>
            cast_if_and
              (decide (v1 = v2))
              (decide (vs1 = vs2))
        | _, _ =>
            right _
        end
      in
      match v1, v2 with
      | ValLiteral l1, ValLiteral l2 =>
          cast_if
            (decide (l1 = l2))
      | ValRec f1 x1 e1, ValRec f2 x2 e2 =>
          cast_if_and3
            (decide (f1 = f2))
            (decide (x1 = x2))
            (decide (e1 = e2))
      | ValTuple vs1, ValTuple vs2 =>
          cast_if
            (decide (vs1 = vs2))
      | ValConstr b1 e1, ValConstr b2 e2 =>
          cast_if_and
            (decide (b1 = b2))
            (decide (e1 = e2))
      | _, _ =>
          right _
      end
    for go
  );
  clear go go_val go_list; abstract intuition congruence.
Defined.
#[global] Instance val_eq_dec : EqDecision val.
Proof.
  unshelve refine (
    fix go_val v1 v2 : Decision (v1 = v2) :=
      let fix go_list vs1 vs2 : Decision (vs1 = vs2) :=
        match vs1, vs2 with
        | [], [] =>
            left _
        | v1 :: vs1, v2 :: vs2 =>
            cast_if_and
              (decide (v1 = v2))
              (decide (vs1 = vs2))
        | _, _ =>
            right _
        end
      in
      match v1, v2 with
      | ValLiteral l1, ValLiteral l2 =>
          cast_if
            (decide (l1 = l2))
      | ValRec f1 x1 e1, ValRec f2 x2 e2 =>
          cast_if_and3
            (decide (f1 = f2))
            (decide (x1 = x2))
            (decide (e1 = e2))
      | ValTuple vs1, ValTuple vs2 =>
          cast_if
            (decide (vs1 = vs2))
      | ValConstr b1 e1, ValConstr b2 e2 =>
          cast_if_and
            (decide (b1 = b2))
            (decide (e1 = e2))
      | _, _ =>
          right _
      end
  );
  clear go_val go_list; abstract intuition congruence.
Defined.
Variant encode_leaf :=
  | EncodeString (x : string)
  | EncodeBinder x
  | EncodeUnop (op : unop)
  | EncodeBinop (op : binop)
  | EncodeNat (i : nat)
  | EncodeBool b
  | EncodeLiteral lit.
#[local] Instance encode_leaf_eq_dec : EqDecision encode_leaf :=
  ltac:(solve_decision).
#[local] Instance encode_leaf_countable :
  Countable encode_leaf.
Proof.
  pose encode leaf :=
    match leaf with
    | EncodeString x =>
        inl $ inl $ inl $ inl $ inl $ inl x
    | EncodeBinder x =>
        inl $ inl $ inl $ inl $ inl $ inr x
    | EncodeUnop op =>
        inl $ inl $ inl $ inl $ inr op
    | EncodeBinop op =>
        inl $ inl $ inl $ inr op
    | EncodeNat i =>
        inl $ inl $ inr i
    | EncodeBool b =>
        inl $ inr b
    | EncodeLiteral lit =>
        inr lit
    end.
  pose decode leaf :=
    match leaf with
    | inl (inl (inl (inl (inl (inl x))))) =>
        EncodeString x
    | inl (inl (inl (inl (inl (inr x))))) =>
        EncodeBinder x
    | inl (inl (inl (inl (inr op)))) =>
        EncodeUnop op
    | inl (inl (inl (inr op))) =>
        EncodeBinop op
    | inl (inl (inr i)) =>
        EncodeNat i
    | inl (inr b) =>
        EncodeBool b
    | inr lit =>
        EncodeLiteral lit
    end.
  refine (inj_countable' encode decode _); intros []; done.
Qed.
#[global] Instance expr_countable :
  Countable expr.
Proof.
  Notation tag_Val :=
    0.
  Notation tag_Rec :=
    1.
  Notation tag_App :=
    2.
  Notation tag_Unop :=
    3.
  Notation tag_Binop :=
    4.
  Notation tag_Equal :=
    5.
  Notation tag_If :=
    6.
  Notation tag_Tuple :=
    7.
  Notation tag_Proj :=
    8.
  Notation tag_Constr :=
    9.
  Notation tag_Case :=
    10.
  Notation tag_Record :=
    11.
  Notation tag_Alloc :=
    12.
  Notation tag_Load :=
    13.
  Notation tag_Store :=
    14.
  Notation tag_Xchg :=
    15.
  Notation tag_Cas :=
    16.
  Notation tag_Faa :=
    17.
  Notation tag_Fork :=
    18.
  Notation tag_Proph :=
    19.
  Notation tag_Resolve :=
    20.
  Notation tag_ValRec :=
    0.
  Notation tag_ValTuple :=
    1.
  Notation tag_ValConstr :=
    2.
  pose encode :=
    fix go e :=
      match e with
      | Val v =>
          GenNode tag_Val [go_val v]
      | Var x =>
          GenLeaf (EncodeString x)
      | Rec f x e =>
          GenNode tag_Rec [GenLeaf (EncodeBinder f); GenLeaf (EncodeBinder x); go e]
      | App e1 e2 =>
          GenNode tag_App [go e1; go e2]
      | Unop op e =>
          GenNode tag_Unop [GenLeaf (EncodeUnop op); go e]
      | Binop op e1 e2 =>
          GenNode tag_Binop [GenLeaf (EncodeBinop op); go e1; go e2]
      | Equal e1 e2 =>
          GenNode tag_Equal [go e1; go e2]
      | If e0 e1 e2 =>
          GenNode tag_If [go e0; go e1; go e2]
      | Tuple es =>
          GenNode tag_Tuple (map go es)
      | Proj i e =>
          GenNode tag_Proj [GenLeaf (EncodeNat i); go e]
      | Constr b e =>
          GenNode tag_Constr [GenLeaf (EncodeBool b); go e]
      | Case e0 e1 e2 =>
          GenNode tag_Case [go e0; go e1; go e2]
      | Record es =>
          GenNode tag_Record (map go es)
      | Alloc e1 e2 =>
          GenNode tag_Alloc [go e1; go e2]
      | Load e =>
          GenNode tag_Load [go e]
      | Store e1 e2 =>
          GenNode tag_Store [go e1; go e2]
      | Xchg e1 e2 =>
          GenNode tag_Xchg [go e1; go e2]
      | Cas e0 e1 e2 =>
          GenNode tag_Cas [go e0; go e1; go e2]
      | Faa e1 e2 =>
          GenNode tag_Faa [go e1; go e2]
      | Fork e =>
          GenNode tag_Fork [go e]
      | Proph =>
          GenNode tag_Proph []
      | Resolve e0 e1 e2 =>
          GenNode tag_Resolve [go e0; go e1; go e2]
      end
    with go_val v :=
      match v with
      | ValLiteral lit =>
          GenLeaf (EncodeLiteral lit)
      | ValRec f x e =>
         GenNode tag_ValRec [GenLeaf (EncodeBinder f); GenLeaf (EncodeBinder x); go e]
      | ValTuple vs =>
          GenNode tag_ValTuple (map go_val vs)
      | ValConstr b v =>
          GenNode tag_ValConstr [GenLeaf (EncodeBool b); go_val v]
      end
    for go.
  pose decode :=
    fix go _e :=
      match _e with
      | GenNode tag_Val [v] =>
          Val (go_val v)
      | GenLeaf (EncodeString x) =>
          Var x
      | GenNode tag_Rec [GenLeaf (EncodeBinder f); GenLeaf (EncodeBinder x); e] =>
          Rec f x (go e)
      | GenNode tag_App [e1; e2] =>
          App (go e1) (go e2)
      | GenNode tag_Unop [GenLeaf (EncodeUnop op); e] =>
          Unop op (go e)
      | GenNode tag_Binop [GenLeaf (EncodeBinop op); e1; e2] =>
          Binop op (go e1) (go e2)
      | GenNode tag_Equal [e1; e2] =>
          Equal (go e1) (go e2)
      | GenNode tag_If [e0; e1; e2] =>
          If (go e0) (go e1) (go e2)
      | GenNode tag_Tuple es =>
          Tuple (map go es)
      | GenNode tag_Proj [GenLeaf (EncodeNat i); e] =>
          Proj i (go e)
      | GenNode tag_Constr [GenLeaf (EncodeBool b); e] =>
          Constr b (go e)
      | GenNode tag_Case [e0; e1; e2] =>
          Case (go e0) (go e1) (go e2)
      | GenNode tag_Record es =>
          Record (map go es)
      | GenNode tag_Alloc [e1; e2] =>
          Alloc (go e1) (go e2)
      | GenNode tag_Load [e] =>
          Load (go e)
      | GenNode tag_Store [e1; e2] =>
          Store (go e1) (go e2)
      | GenNode tag_Xchg [e1; e2] =>
          Xchg (go e1) (go e2)
      | GenNode tag_Cas [e0; e1; e2] =>
          Cas (go e0) (go e1) (go e2)
      | GenNode tag_Faa [e1; e2] =>
          Faa (go e1) (go e2)
      | GenNode tag_Fork [e] =>
          Fork (go e)
      | GenNode tag_Proph [] =>
          Proph
      | GenNode tag_Resolve [e0; e1; e2] =>
          Resolve (go e0) (go e1) (go e2)
      | _ =>
          Val ValUnit
      end
    with go_val _v :=
      match _v with
      | GenLeaf (EncodeLiteral lit) =>
          ValLiteral lit
      | GenNode tag_ValRec [GenLeaf (EncodeBinder f); GenLeaf (EncodeBinder x); e] =>
          ValRec f x (go e)
      | GenNode tag_ValTuple vs =>
          ValTuple (map go_val vs)
      | GenNode tag_ValConstr [GenLeaf (EncodeBool b); v] =>
          ValConstr b (go_val v)
      | _ =>
          ValUnit
      end
    for go.
  refine (inj_countable' encode decode _).
  refine (fix go e := _ with go_val v := _ for go).
  - destruct e; simpl; f_equal; try done.
    1:
      match goal with |- _ = ?v =>
        exact (go_val v)
      end.
    all:
      match goal with |- _ = ?es =>
        rewrite /map; induction es as [| ? ? ->]; simpl; f_equal; done
      end.
  - destruct v; simpl; f_equal; try done.
    match goal with |- _ = ?vs =>
      rewrite /map; induction vs as [| ? ? ->]; simpl; f_equal; done
    end.
Qed.
#[global] Instance val_countable :
  Countable val.
Proof.
  refine (inj_countable of_val to_val _); auto using to_of_val.
Qed.
