Require Import VST.veric.juicy_extspec.
Require Import VST.floyd.proofauto.
Require Export VST.progs.io_events.
Require Import ITree.ITree.
Require Import ITree.Interp.Traces.
Require Export ITree.Eq.SimUpToTaus.
(* Import ITreeNotations. *) (* one piece conflicts with subp notation *)
Notation "t1 >>= k2" := (ITree.bind t1 k2)
  (at level 50, left associativity) : itree_scope.
Notation "x <- t1 ;; t2" := (ITree.bind t1 (fun x => t2))
  (at level 100, t1 at next level, right associativity) : itree_scope.
Notation "t1 ;; t2" := (ITree.bind t1 (fun _ => t2))
  (at level 100, right associativity) : itree_scope.
Notation "' p <- t1 ;; t2" :=
  (ITree.bind t1 (fun x_ => match x_ with p => t2 end))
(at level 100, t1 at next level, p pattern, right associativity) : itree_scope.

(* We need a layer of equivalence to allow us to use the monad laws. *)
Definition ITREE (tr : IO_itree) := EX tr' : _, !!(sutt eq tr tr') &&
  has_ext tr'.

Lemma has_ext_ITREE : forall tr, has_ext tr |-- ITREE tr.
Proof.
  intro; unfold ITREE.
  Exists tr; entailer!.
  apply eutt_sutt; reflexivity.
Qed.

Definition putchar_spec :=
  WITH c : int, k : IO_itree
  PRE [ 1%positive OF tint ]
    PROP ()
    LOCAL (temp 1%positive (Vint c))
    SEP (ITREE (write c ;; k))
  POST [ tint ]
   EX i : int,
    PROP (Int.signed i = -1 \/ i = Int.repr (Int.unsigned c mod 256))
    LOCAL (temp ret_temp (Vint i))
    SEP (ITREE (if eq_dec (Int.signed i) (-1) then (write c ;; k) else k)).

Definition getchar_spec :=
  WITH k : int -> IO_itree
  PRE [ ]
    PROP ()
    LOCAL ()
    SEP (ITREE (r <- read ;; k r))
  POST [ tint ]
   EX i : int,
    PROP (-1 <= Int.signed i <= two_p 8 - 1)
    LOCAL (temp ret_temp (Vint i))
    SEP (ITREE (if eq_dec (Int.signed i) (-1) then (r <- read ;; k r) else k i)).

Fixpoint write_list l : IO_itree :=
  match l with
  | nil => Ret tt
  | c :: rest => write c ;; write_list rest
  end.

Lemma ITREE_impl : forall tr tr', eutt eq tr tr' ->
  ITREE tr |-- ITREE tr'.
Proof.
  intros.
  unfold ITREE.
  Intros tr1; Exists tr1; entailer!.
  (* rewrite <- H; auto. *)
  rewrite trace_incl_iff_sutt in *.
  unfold trace_incl in *.
  intros; apply H0.
  eapply trace_incl_iff_sutt; eauto.
  eapply eutt_sutt; symmetry; auto.
Qed.

Lemma ITREE_ext : forall tr tr', eutt eq tr tr' ->
  ITREE tr = ITREE tr'.
Proof.
  intros; apply pred_ext; apply ITREE_impl; auto.
  symmetry; auto.
Qed.

Lemma write_list_app : forall l1 l2,
  eutt eq (write_list (l1 ++ l2)) (write_list l1;; write_list l2).
Proof.
  induction l1; simpl in *; intros.
  - rewrite Shallow.bind_ret; reflexivity.
  - rewrite Eq.bind_bind.
    setoid_rewrite IHl1; reflexivity.
Qed.

Definition char0 : Z := 48.
Definition newline := 10.

(* Build the external specification. *)
Definition IO_void_Espec : OracleKind := ok_void_spec IO_itree.

Definition IO_specs (ext_link : string -> ident) :=
  [(ext_link "putchar"%string, putchar_spec); (ext_link "getchar"%string, getchar_spec)].

Definition IO_Espec (ext_link : string -> ident) : OracleKind := add_funspecs IO_void_Espec ext_link (IO_specs ext_link).
