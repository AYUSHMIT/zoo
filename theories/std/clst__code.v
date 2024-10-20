From zoo Require Import
  prelude.
From zoo.language Require Import
  typeclasses
  notations.
From zoo.std Require Import
  clst__types.
From zoo Require Import
  options.

Definition clst_app : val :=
  rec: "app" "t1" "t2" =>
    match: "t1" with
    | ClstClosed =>
        Fail
    | ClstOpen =>
        "t2"
    | ClstCons "v" "t1" =>
        ‘ClstCons( "v", "app" "t1" "t2" )
    end.

Definition clst_rev_app : val :=
  rec: "rev_app" "t1" "t2" =>
    match: "t1" with
    | ClstClosed =>
        Fail
    | ClstOpen =>
        "t2"
    | ClstCons "v" "t1" =>
        "rev_app" "t1" ‘ClstCons( "v", "t2" )
    end.

Definition clst_iter : val :=
  rec: "iter" "t" "fn" =>
    match: "t" with
    | ClstClosed =>
        Fail
    | ClstOpen =>
        ()
    | ClstCons "v" "t" =>
        "fn" "v" ;;
        "iter" "t" "fn"
    end.
