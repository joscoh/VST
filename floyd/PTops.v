Require Import compcert.lib.Maps.
Require Import ZArith.
Require Import VST.msl.Extensionality.
Require Import compcert.lib.Coqlib.
Require Import VST.msl.Coqlib2.
Require Import VST.veric.coqlib4.

Fixpoint PTree_map3 {A1 A2 A3 B} 
       (f: A1 -> A2 -> A3 -> B)
       (m1: PTree.t A1) (m2: PTree.t A2) (m3: PTree.t A3) : PTree.t B :=
match m1, m2, m3 with
| PTree.Node l1 o1 r1, PTree.Node l2 o2 r2, PTree.Node l3 o3 r3 =>
  let l := PTree_map3 f l1 l2 l3 in
  let r := PTree_map3 f r1 r2 r3 in
  let o := match o1,o2,o3 with
              | Some x1, Some x2, Some x3 => Some (f x1 x2 x3)
              | _,_,_ => None
              end
  in PTree.Node l o r
| PTree.Node l1 o1 r1, PTree.Node l2 o2 r2, PTree.Leaf =>
  let l := PTree_map3 f l1 l2 PTree.Leaf in
  let r := PTree_map3 f r1 r2 PTree.Leaf in
  PTree.Node l None r
| PTree.Node l1 o1 r1, PTree.Leaf, PTree.Node l3 o3 r3 =>
  let l := PTree_map3 f l1 PTree.Leaf l3 in
  let r := PTree_map3 f r1 PTree.Leaf r3 in
  PTree.Node l None r
| PTree.Node l1 o1 r1, _, _ =>
  let l := PTree_map3 f l1 PTree.Leaf PTree.Leaf in
  let r := PTree_map3 f r1 PTree.Leaf PTree.Leaf in
  PTree.Node l None r
| _, _, _ => PTree.Leaf
end.

Lemma PTree_gmap3:
  forall {A1 A2 A3 B} (f:  A1 -> A2 -> A3 -> B) i m1 m2 m3,
  (PTree_map3 f m1 m2 m3) ! i =
  match (m1 ! i), (m2 ! i), (m3 ! i) with
  | Some x1, Some x2, Some x3 => Some (f x1 x2 x3)
  | _, _, _ => None
  end.
Proof.
induction i; destruct m1,m2,m3; try destruct o; try destruct o0; simpl; auto;
try solve [rewrite IHi, !PTree.gempty; auto].
Qed.

Fixpoint PTree_Forall {A: Type} (F: A -> Prop) (m: PTree.t A): Prop :=
match m with
| PTree.Leaf => True
| PTree.Node l o r => match o with Some x => F x | None => True end /\
           PTree_Forall F l /\ PTree_Forall F r
end.

Definition PTree_Forall_get {A: Type} (F: A -> Prop) (m: PTree.t A): Prop :=
  forall i, match PTree.get i m with Some c => F c | None => True end.

Lemma PTree_Forall_get_eq: @PTree_Forall_get = @PTree_Forall.
Proof.
extensionality A F m.
unfold PTree_Forall_get.
apply prop_ext.
split; intro.
-
induction m.
  simpl. auto.
 simpl.
 split3.
 destruct o; auto. apply (H xH).
 apply IHm1.
 intro i. apply (H (xO i)). 
 apply IHm2.
 intro i. apply (H (xI i)).
-
 induction m.
 intro i.
 destruct i; simpl; auto.
 destruct H as [? [? ?]].
 specialize (IHm1 H0). specialize (IHm2 H1).
 destruct i; simpl in *; auto.
 apply IHm2. apply IHm1.
Qed.

Definition PTree_domain_eq {A B} (m1: PTree.t A) (m2: PTree.t B) :=
 forall i, isSome(m1 ! i)  <-> isSome (m2 ! i).

Lemma PTree_domain_eq_e {A B} {m1: PTree.t A} {m2: PTree.t B}:
   PTree_domain_eq m1 m2 -> 
  forall i, (exists x, m1 ! i = Some x) <-> (exists y, m2 ! i = Some y).
Proof.
intros.
specialize (H i).
unfold isSome in H.
destruct (m1 ! i), (m2 ! i); try tauto.
split; intros [? H0]; inv H0; eauto.
split; intros [? ?]; discriminate.
Qed.

Lemma PTree_Forall_elements:
 forall A (F: A -> Prop) (m: PTree.t A),
  PTree_Forall F m <-> Forall (fun ix => F (snd ix)) (PTree.elements m).
Proof.
intros.
rewrite <- PTree_Forall_get_eq.
split; intros.
-
red in H.
apply Forall_forall.
intros (i,y) ?.
simpl.
specialize (H i).
apply PTree.elements_complete in H0.
rewrite H0 in H.
auto.
-
intro i.
rewrite -> Forall_forall in H.
destruct (m ! i) eqn:?H; auto.
specialize (H (i,a)).
apply H.
apply PTree.elements_correct.
auto.
Qed.

Lemma PTree_elements_map1:
  forall {A B} (f: A -> B)  e, PTree.elements (PTree.map1 f e) =
                  map (fun ix => (fst ix, f (snd ix))) (PTree.elements e).
Proof.
intros.
unfold PTree.elements.
set (g := (fun ix : positive * A => (fst ix, f (snd ix)))).
change (@nil (positive * B)) with (map g (@nil (positive * A))).
forget (@nil (positive * A)) as r.
forget 1%positive as n.
revert r n.
induction e; intros.
simpl. auto.
simpl.
destruct o; simpl.
rewrite IHe2.
rewrite <- IHe1.
simpl.
reflexivity.
rewrite IHe2.
rewrite <- IHe1.
simpl.
reflexivity.
Qed.

Definition Some_e {A} (default: A) (o: option A) : A :=
 match o with Some x => x | None => default end.

Lemma xelements_empty:
  forall {A} (m: PTree.t A) n al, 
   (forall i, (m ! i) = None) ->
   PTree.xelements m n al = al.
Proof.
induction m; intros.
reflexivity.
simpl.
destruct o.
specialize (H 1%positive); inv H.
rewrite IHm1.
rewrite IHm2.
auto.
intro i; specialize (H (xI i)); inv H; auto.
intro i; specialize (H (xO i)); inv H; auto.
Qed.

Fixpoint map3 {A1 A2 A3 B} (f: A1 -> A2 -> A3 -> B) 
  (al1: list A1) 
  (al2: list A2) 
  (al3: list A3) :  list B :=
match al1, al2, al3 with
| a1::al1', a2::al2', a3::al3' => f a1 a2 a3 :: map3 f al1' al2' al3'
| _, _, _ => nil
end.

Lemma PTree_domain_eq_Leaf:
 forall {A B} a,
    @PTree_domain_eq A B a PTree.Leaf <->
    (forall i, a ! i = None).
Proof.
induction a; simpl; intros; split; intro.
apply PTree.gempty.
split; intro; hnf; rewrite PTree.gempty; auto.
hnf in H0; rewrite PTree.gempty in H0; auto.
hnf in H0; rewrite PTree.gempty in H0; auto.
destruct i; simpl.
specialize (proj1 (H (xI i))); simpl in *; destruct (a2!i); intro; auto. contradiction H0. apply I.
specialize (proj1 (H (xO i))); simpl in *; destruct (a1!i); intro; auto. contradiction H0. apply I.
specialize (proj1 (H xH)); simpl. destruct o; intro; auto. contradiction H0; hnf; auto.
split; rewrite PTree.gempty; intro; hnf in H0.
rewrite H in H0; auto.
contradiction.
Qed.

Lemma PTree_domain_empty_Node:
 forall {A} (a: PTree.t A) o b,
  (forall i, (PTree.Node a o b) ! i = None) ->
  (forall i, a ! i = None) /\ o = None /\ (forall i, b ! i = None).
Proof.
intros.
split3.
intro i. apply (H (xO i)).
apply (H xH).
intro i. apply (H (xI i)).
Qed.

Lemma PTree_domain_eq_Node_Node:
  forall {A1 A2} (a1: PTree.t A1) o1 b1 (a2: PTree.t A2) o2 b2,
  PTree_domain_eq (PTree.Node a1 o1 b1) (PTree.Node a2 o2 b2) <->
  (PTree_domain_eq a1 a2 /\ (isSome o1 <-> isSome o2) 
    /\ PTree_domain_eq b1 b2).
Proof.
intros.
split; intro.
split3; try intro.
apply (H (xO i)).
apply (H xH).
apply (H (xI i)).
destruct H as [? [? ?]].
intro i. destruct i; simpl.
apply H1.
apply H.
apply H0.
Qed.

Lemma PTree_elements_map3:
  forall {A1 A2 A3 B} (f: A1 -> A2 -> A3 -> B) e1 e2 e3, 
         PTree_domain_eq e1 e2 ->
         PTree_domain_eq e1 e3 ->
         PTree.elements (PTree_map3 f e1 e2 e3) =
             map3 (fun ix iy iz => (fst ix, f (snd ix) (snd iy) (snd iz)))
                  (PTree.elements e1) (PTree.elements e2) (PTree.elements e3).
Proof.
intros.
match goal with |- _ = map3 ?A _ _ _ => set (g := A) end.
unfold PTree.elements.
change (@nil (positive * B)) with (map3 g nil nil nil).
forget (@nil (positive * A1)) as r1.
forget (@nil (positive * A2)) as r2.
forget (@nil (positive * A3)) as r3.
forget 1%positive as n.
revert r1 r2 r3 n.
revert e2 e3 H H0; induction e1; intros.
-
simpl.
rewrite !xelements_empty; auto.
clear - H0. intro i.
destruct (H0 i) as [_ H]; unfold isSome in H; destruct (e3 ! i); auto; rewrite PTree.gempty in H; contradiction.
clear - H; rename H into H0. intro i.
destruct (H0 i) as [_ H]; unfold isSome in H; destruct (e2 ! i); auto; rewrite PTree.gempty in H; contradiction.
-
destruct e2; [destruct e3 | destruct e3];
simpl.
 +
  destruct (PTree_domain_empty_Node _ _ _ (proj1 (PTree_domain_eq_Leaf _) H))
   as [? [? ?]].
  subst o.
  rewrite IHe1_2 by (apply PTree_domain_eq_Leaf; auto).
  rewrite IHe1_1 by (apply PTree_domain_eq_Leaf; auto).
  reflexivity.
 +
  apply PTree_domain_eq_Node_Node in H0.
  destruct H0 as [? [? ?]].
  destruct (PTree_domain_empty_Node _ _ _ (proj1 (@PTree_domain_eq_Leaf A1 A2 _) H))
    as [? [? ?]].
  rewrite IHe1_2;  auto.
  rewrite IHe1_1; auto.
  destruct o.
  specialize (H xH); simpl in H; clear - H; tauto.
  destruct o0; try solve [elimtype False; clear - H1; simpl in H1; tauto].
  reflexivity.
  apply PTree_domain_eq_Leaf; auto.
  apply PTree_domain_eq_Leaf; auto.
 +
  apply PTree_domain_eq_Node_Node in H.
  destruct H as [? [? ?]].
  destruct (PTree_domain_empty_Node _ _ _ (proj1 (@PTree_domain_eq_Leaf A1 A3 _) H0))
    as [? [? ?]].
  subst o.
  destruct o0; try solve [elimtype False; clear - H1; simpl in H1; tauto].
  rewrite IHe1_2; auto.
  rewrite IHe1_1; auto.
  apply PTree_domain_eq_Leaf; auto.
  apply PTree_domain_eq_Leaf; auto.
 +
  apply PTree_domain_eq_Node_Node in H.
  destruct H as [? [? ?]].
  apply PTree_domain_eq_Node_Node in H0.
  destruct H0 as [? [? ?]].
  destruct o,o0; 
    try solve [elimtype False; clear - H1; simpl in H1; tauto];
    destruct o1;
    try solve [elimtype False; clear - H3; simpl in H3; tauto];
   clear H1 H3.
  rewrite IHe1_2; auto.
  rewrite <- IHe1_1; auto.
  rewrite IHe1_2; auto.
Qed.

Lemma PTree_domain_eq_sym:
  forall {A B}  (ma: PTree.t A) (mb: PTree.t B),
  PTree_domain_eq ma mb <-> PTree_domain_eq mb ma.
Proof.
intros.
unfold PTree_domain_eq.
split; split; apply H.
Qed.

Lemma PTree_domain_eq_elements:
 forall {A B} (ma: PTree.t A) (mb: PTree.t B),
  PTree_domain_eq ma mb ->
  map fst (PTree.elements ma) = map fst (PTree.elements mb).
Proof.
intros.
unfold PTree.elements.
forget 1%positive as n.
revert mb H n; induction ma; destruct mb; intros; auto.
-
rewrite PTree_domain_eq_sym in H.
rewrite -> PTree_domain_eq_Leaf in H.
forget (PTree.Node mb1 o mb2) as m.
destruct (PTree.xelements m n nil) as [ | [? ?]] eqn:?H; auto.
rewrite xelements_empty in H0 by auto. inv H0.
-
forget (PTree.Node ma1 o ma2) as m.
rewrite -> PTree_domain_eq_Leaf in H.
rewrite xelements_empty by auto. reflexivity.
-
apply PTree_domain_eq_Node_Node in H.
destruct H as [? [? ?]].
specialize (IHma1 _ H).
specialize (IHma2 _ H1).
clear H H1.
rewrite !PTree.xelements_node.
rewrite !map_app.
f_equal; auto.
destruct o,o0;  try solve [elimtype False; simpl in H0; tauto]; clear H0.
simpl. f_equal; auto.
simpl.
f_equal; auto.
Qed.

Lemma Some_inj: forall {A} (x y: A), Some x = Some y -> x=y.
Proof. intros. inv H; auto. Qed.
 
Require compcert.common.Errors.
Import ListNotations.

Fixpoint merge_PTrees {X} (merge: X -> X -> Errors.res X) (a b: PTree.t X) : Errors.res (PTree.t X) :=
 match a, b with
 | _, PTree.Leaf => Errors.OK a
 | PTree.Leaf, _ => Errors.OK b
 | PTree.Node al ao ar, PTree.Node bl bo br => 
    Errors.bind (merge_PTrees merge al bl) (fun l =>
    Errors.bind (merge_PTrees merge ar br) (fun r =>
    match ao, bo with
    | _, None => Errors.OK (PTree.Node l ao r)
    | None, _ => Errors.OK (PTree.Node l bo r)
    | Some x, Some y => Errors.bind (merge x y) (fun z => Errors.OK (PTree.Node l (Some z) r))
    end))
 end.

Definition merge_consistent_PTrees {X} (eqb: X -> X -> bool) (a b: PTree.t X) 
      : Errors.res (PTree.t X) :=
  merge_PTrees (fun x y => if eqb x y then Errors.OK x else Errors.Error [Errors.MSG "inconsistent PTrees"]) a b.

Lemma merge_PTrees_e:
 forall i {A} (p1 p2 p : PTree.t A) merge,
  merge_PTrees merge p1 p2 = Errors.OK p ->
  match PTree.get i p1, PTree.get i p2 with
  | None, None =>  PTree.get i p = None
  | Some x1, None => PTree.get i p = Some x1
  | None, Some x2 => PTree.get i p = Some x2
  | Some x1, Some x2 => exists x, merge x1 x2 = Errors.OK x
                                         /\ PTree.get i p = Some x
   end.
Proof.
clear.
intros.
revert p2 p H i.
induction p1; simpl; intros.
-
rewrite PTree.gempty.
destruct p2; inv H.
rewrite PTree.gempty.
auto.
destruct i; simpl.
destruct (p2_2 ! i); auto.
destruct (p2_1 ! i); auto.
destruct o; auto.
-
destruct i; simpl.
destruct p2.
inv H.
destruct (p1_2 ! i); auto.
Errors.monadInv H.
destruct o.
destruct o0.
Errors.monadInv EQ2.
specialize (IHp1_1 _ _ EQ i).
specialize (IHp1_2 _ _ EQ1 i).
auto.
inv EQ2.
specialize (IHp1_1 _ _ EQ i).
specialize (IHp1_2 _ _ EQ1 i).
auto.
destruct o0.
inv EQ2.
specialize (IHp1_1 _ _ EQ i).
specialize (IHp1_2 _ _ EQ1 i).
auto.
inv EQ2.
specialize (IHp1_1 _ _ EQ i).
specialize (IHp1_2 _ _ EQ1 i).
auto.
destruct p2.
inv H.
destruct (p1_1 ! i); auto.
Errors.monadInv H.
destruct o.
destruct o0.
Errors.monadInv EQ2.
specialize (IHp1_1 _ _ EQ i).
specialize (IHp1_2 _ _ EQ1 i).
auto.
inv EQ2.
specialize (IHp1_1 _ _ EQ i).
specialize (IHp1_2 _ _ EQ1 i).
auto.
destruct o0.
Errors.monadInv EQ2.
specialize (IHp1_1 _ _ EQ i).
specialize (IHp1_2 _ _ EQ1 i).
auto.
inv EQ2.
specialize (IHp1_1 _ _ EQ i).
specialize (IHp1_2 _ _ EQ1 i).
auto.
destruct p2.
inv H.
destruct o; auto.
Errors.monadInv H.
destruct o.
destruct o0.
Errors.monadInv EQ2.
eauto.
inv EQ2; auto.
destruct o0; inv EQ2; auto.
Qed.


Lemma merge_consistent_PTrees_e: forall {X} (eqX: X -> X -> bool)
  (eqX_prop: forall x y, eqX x y = true -> x=y)
  (eqX_refl: forall x, eqX x x = true)
  (m1 m2 m: PTree.t X),
  merge_consistent_PTrees eqX m1 m2 = Errors.OK m ->
  forall i, 
              match PTree.get i m1, PTree.get i m2 with
              | None, a => PTree.get i m = a
              | a, None => PTree.get i m = a
              | Some x, Some y => eqX x y = true /\ PTree.get i m = Some x
              end.
Proof.
intros.
apply (merge_PTrees_e i) in H.
destruct (m1 ! i).
destruct (m2 ! i).
destruct H as [x1 [? ?]].
destruct (eqX x x0) eqn:?H.
inv H; auto.
inv H.
auto.
destruct (m2 ! i); auto.
Qed.

Lemma merge_consistent_PTrees_e': forall {X} (eqX: X -> X -> bool)
  (eqX_prop: forall x y, eqX x y = true -> x=y)
  (eqX_refl: forall x, eqX x x = true)
  (m1 m2 m: PTree.t X),
  merge_consistent_PTrees eqX m1 m2 = Errors.OK m ->
  forall (i : positive) (x: X),
  m ! i = Some x <-> m1 ! i = Some x \/ m2 ! i = Some x.
Proof.
 intros. 
 apply merge_consistent_PTrees_e with (i0:=i) in H; auto.
 destruct (m1 ! i) eqn:?H.
 destruct (m2 ! i) eqn:?H.
 destruct H. apply eqX_prop in H; subst x1.
 rewrite H2. split; intro. inv H ;auto. destruct H; inv H; auto.
 rewrite H.  split; intro.  inv H2; auto. destruct H2; inv H2; auto.
 rewrite H.  split; intro.  inv H1; auto. destruct H1; inv H1; auto.
Qed.

Lemma merge_PTrees_map1:
 forall {A} (f: A -> A -> Errors.res A) m1 m2 m, 
     merge_PTrees f m1 m2 = Errors.OK m ->
   forall {B} (g: A -> B) (h: B -> B -> Errors.res B),
     (forall x y z, f x y = Errors.OK z -> h (g x) (g y) = Errors.OK (g z)) ->
    merge_PTrees h (PTree.map1 g m1) (PTree.map1 g m2) = 
      Errors.OK (PTree.map1 g m).
Proof.
induction m1; destruct m2, m; simpl; intros; auto; try discriminate.
-
inv H. auto.
-
inv H.
auto.
-
Errors.monadInv H.
destruct o,o0; inv EQ2.
Errors.monadInv H1.
-
Errors.monadInv H.
destruct o,o0; inv EQ2.
+
Errors.monadInv H1.
erewrite IHm1_1 by eauto.
erewrite IHm1_2 by eauto.
apply H0 in EQ0.
simpl.
rewrite EQ0.
reflexivity.
+
erewrite IHm1_1 by eauto.
erewrite IHm1_2 by eauto.
simpl.
reflexivity.
+
erewrite IHm1_1 by eauto.
erewrite IHm1_2 by eauto.
simpl.
reflexivity.
+
erewrite IHm1_1 by eauto.
erewrite IHm1_2 by eauto.
simpl.
reflexivity.
Qed.

Fixpoint PTree_samedom {A B} (m1: PTree.t A) (m2: PTree.t B) :=
 match m1, m2 with
 | PTree.Node l1 o1 r1, PTree.Node l2 o2 r2 => 
      match o1, o2 with Some _, Some _ => True | None, None => True | _, _ => False end 
    /\ PTree_samedom l1 l2 /\ PTree_samedom r1 r2
 | PTree.Leaf, PTree.Leaf => True
 | _, _ => False
end.

Lemma merge_PTrees_Leaf1:
  forall {X: Type} (merge: X -> X -> Errors.res X) m, merge_PTrees merge PTree.Leaf m = Errors.OK m.
Proof.
intros. destruct m; simpl; auto.
Qed.

Lemma merge_PTrees_Leaf2:
  forall {X: Type} (merge: X -> X -> Errors.res X) m, merge_PTrees merge m PTree.Leaf = Errors.OK m.
Proof.
intros. destruct m; simpl; auto.
Qed.

Definition PTree_filter_prune {A} (m: PTree.t A) :=
 match m with
 | PTree.Node PTree.Leaf None PTree.Leaf => PTree.Leaf
 | _ => m
 end.

Fixpoint PTree_filter' {A} (f: positive * A -> bool) (i: positive) (m: PTree.t A) : PTree.t A  :=
  match m with
  | PTree.Leaf => PTree.Leaf
  | PTree.Node  l (Some x) r => 
   PTree_filter_prune
      (PTree.Node (PTree_filter' f (xO i) l)
                   (if f (PTree.prev i,x) then (Some x) else None)
                   (PTree_filter' f (xI i) r))
  | PTree.Node l None r => 
   PTree_filter_prune
      (PTree.Node (PTree_filter' f (xO i) l) None (PTree_filter' f (xI i) r))
  end.

Definition PTree_filter {A} (f: positive * A -> bool)  := 
  PTree_filter' f xH.


Lemma PTree_samedom_domain_eq: (* move this to PTops.v *)
 forall {A B} (m1: PTree.t A) (m2: PTree.t B), PTree_samedom m1 m2 -> 
    PTree_domain_eq m1 m2.
Proof.
intros.
revert m2 H; induction m1; destruct m2; simpl; intros; try contradiction.
split; intro; auto.
rewrite PTree.gempty in H0; inv H0.
rewrite PTree.gempty in H0; inv H0.
destruct H as [? [? ?]].
intro i; simpl.
destruct i; simpl.
apply IHm1_2; auto.
apply IHm1_1; auto.
destruct o,o0; try contradiction; tauto.
Qed.


Lemma PTree_map1_map3:
 forall {A B C D E}  (g: D -> E) (f: A -> B -> C -> D)
(m1: PTree.t A) (m2: PTree.t B) (m3: PTree.t C),
  PTree.map1 g (PTree_map3 f m1 m2 m3) = 
  PTree_map3 (fun x1 x2 x3 => g (f x1 x2 x3)) m1 m2 m3.
Proof.
induction m1; destruct m2, m3; simpl; auto.
f_equal; auto.
f_equal; auto.
f_equal; auto.
f_equal; auto.
destruct o; auto.
destruct o0; auto.
destruct o1; auto.
Qed.

Lemma PTree_map3_2:
 forall {A B C}
(m1: PTree.t A) (m2: PTree.t B) (m3: PTree.t C),
  PTree_samedom m1 m2 ->
  PTree_samedom m1 m3 ->
  PTree_map3 (fun x1 x2 x3 => x2) m1 m2 m3 = m2.
Proof.
induction m1; destruct m2, m3; simpl; intros; auto; try contradiction.
destruct H as [? [? ?]].
destruct H0 as [? [? ?]].
f_equal; auto.
destruct o,o0,o1; try contradiction; auto.
Qed.

Lemma PTree_map3_1:
 forall {A B C}
(m1: PTree.t A) (m2: PTree.t B) (m3: PTree.t C),
  PTree_samedom m1 m2 ->
  PTree_samedom m1 m3 ->
  PTree_map3 (fun x1 x2 x3 => x1) m1 m2 m3 = m1.
Proof.
induction m1; destruct m2, m3; simpl; intros; auto; try contradiction.
destruct H as [? [? ?]].
destruct H0 as [? [? ?]].
f_equal; auto.
destruct o,o0,o1; try contradiction; auto.
Qed.

Lemma PTree_map3_3:
 forall {A B C}
(m1: PTree.t A) (m2: PTree.t B) (m3: PTree.t C),
  PTree_samedom m1 m2 ->
  PTree_samedom m1 m3 ->
  PTree_map3 (fun x1 x2 x3 => x3) m1 m2 m3 = m3.
Proof.
induction m1; destruct m2, m3; simpl; intros; auto; try contradiction.
destruct H as [? [? ?]].
destruct H0 as [? [? ?]].
f_equal; auto.
destruct o,o0,o1; try contradiction; auto.
Qed.

Definition sub_option {A} (x y : option A) :=
match x with
| Some x' => y = Some x'
| None => True
end.

Definition PTree_sub {A} (m1 m2 : PTree.t A) :=
  forall id, sub_option (m1 ! id) (m2 ! id).

