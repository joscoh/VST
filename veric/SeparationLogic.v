Load loadpath.  

Require Export Axioms.
Require Import Coqlib.
Require Export AST.
Require Export Integers.
Require Export Floats.
Require Export Values.
Require Export Maps.
Require Export Ctypes.
Require Export Clight.
Require Export compositional_compcert.Address.
Require Export msl.eq_dec.
Require Export msl.shares.
Require Export msl.seplog.
Require Export msl.alg_seplog.
Require Export msl.log_normalize.
Require Export veric.expr.
(*Require Import veric.juicy_extspec.*)
Require veric.seplog.
Require veric.assert_lemmas.
Require msl.msl_standard.
Require Import compositional_compcert.Coqlib2.

Instance Nveric: NatDed mpred := algNatDed compcert_rmaps.RML.R.rmap.
Instance Sveric: SepLog mpred := algSepLog compcert_rmaps.RML.R.rmap.
Instance Cveric: ClassicalSep mpred := algClassicalSep compcert_rmaps.RML.R.rmap.
Instance Iveric: Indir mpred := algIndir compcert_rmaps.RML.R.rmap.
Instance Rveric: RecIndir mpred := algRecIndir compcert_rmaps.RML.R.rmap.
Instance SIveric: SepIndir mpred := algSepIndir compcert_rmaps.RML.R.rmap.
Instance SRveric: SepRec mpred := algSepRec compcert_rmaps.RML.R.rmap.

Instance LiftNatDed' T {ND: NatDed T}: NatDed (LiftEnviron T) := LiftNatDed _ _.
Instance LiftSepLog' T {ND: NatDed T}{SL: SepLog T}: SepLog (LiftEnviron T) := LiftSepLog _ _.
Instance LiftClassicalSep' T {ND: NatDed T}{SL: SepLog T}{CS: ClassicalSep T} :
           ClassicalSep (LiftEnviron T) := LiftClassicalSep _ _.
Instance LiftIndir' T {ND: NatDed T}{SL: SepLog T}{IT: Indir T} :
           Indir (LiftEnviron T) := LiftIndir _ _.
Instance LiftSepIndir' T {ND: NatDed T}{SL: SepLog T}{IT: Indir T}{SI: SepIndir T} :
           SepIndir (LiftEnviron T) := LiftSepIndir _ _.

Definition local:  (environ -> Prop) -> environ->mpred :=  lift1 prop.

Lemma extend_local: forall P, extensible (local P).
Proof.
intros. intro; intros.
intros w [? [? [? [? ?]]]].
unfold local in *.
apply H0.
Qed.

Definition func_ptr (f: funspec) : val -> mpred := 
 match f with mk_funspec fsig A P Q => res_predicates.fun_assert fsig A P Q end.

Lemma corable_func_ptr: forall f v, corable (func_ptr f v).
Proof.
intros. destruct f;  unfold func_ptr, corable.
intros.
simpl.
apply normalize.corable_andp_sepcon1.
apply assert_lemmas.corable_fun_assert.
Qed.

Global Opaque func_ptr.

Global Opaque mpred Nveric Sveric Cveric Iveric Rveric Sveric SIveric SRveric.

Hint Resolve any_environ : typeclass_instances.

Definition ret_assert := exitkind -> option val -> environ -> mpred.

Definition VALspec_range: Z -> Share.t -> Share.t -> address -> mpred := res_predicates.VALspec_range.

Definition address_mapsto: memory_chunk -> val -> Share.t -> Share.t -> address -> mpred := 
       res_predicates.address_mapsto.

Local Open Scope logic.

Bind Scope pred with mpred.
Local Open Scope pred.

Definition closed_wrt_vars {B} (S: ident -> Prop) (F: environ -> B) : Prop := 
  forall rho te',  
     (forall i, S i \/ Map.get (te_of rho) i = Map.get te' i) ->
     F rho = F (mkEnviron (ge_of rho) (ve_of rho) te').

Definition typed_true (t: type) (v: val)  : Prop := strict_bool_val v t
= Some true.

Definition typed_false (t: type)(v: val) : Prop := strict_bool_val v t =
Some false.

Definition subst {A} (x: ident) (v: environ -> val) (P: environ -> A) : environ -> A :=
   fun s => P (env_set s x (v s)).

Definition substopt {A} (ret: option ident) (v: environ -> val) (P: environ -> A)  : environ -> A :=
   match ret with
   | Some id => subst id v P
   | None => P
   end.

Definition cast_expropt (e: option expr) t : environ -> option val :=
 match e with Some e' => `Some (eval_expr (Ecast e' t))  | None => `None end.

Definition umapsto (sh: Share.t) (t: type) (v1 v2 : val): mpred :=
  match access_mode t with
  | By_value ch => 
    match v1 with
     | Vptr b ofs => 
          address_mapsto ch v2 (Share.unrel Share.Lsh sh) (Share.unrel Share.Rsh sh) (b, Int.unsigned ofs)
     | _ => FF
    end
  | _ => FF
  end. 


Definition tc_val t v := typecheck_val v t = true.

Definition mapsto sh t v1 v2 :=  !! tc_val t v2    && umapsto sh t v1 v2.

Definition mapsto_ sh t v1 := EX v2:val, umapsto sh t v1 v2.

Definition writable_share: share -> Prop := seplog.writable_share. 
Definition address_mapsto_zeros: 
   forall (n: Z) (rsh sh: Share.t) (l: address), mpred := seplog.address_mapsto_zeros.

Definition mapsto_zeros (n: Z) (sh: share) (a: val) : mpred :=
 match a with
  | Vptr b z => address_mapsto_zeros n 
                          (Share.unrel Share.Lsh sh) (Share.unrel Share.Rsh sh) 
                          (b, Int.unsigned z)
  | _ => TT
  end.

Definition offset_val (v: val) (ofs: int) : val :=
  match v with
  | Vptr b z => Vptr b (Int.add z ofs)
  | _ => Vundef
 end.
 
Definition init_data2pred (d: init_data)  (sh: share) (a: val) (rho: environ) : mpred :=
 match d with
  | Init_int8 i => umapsto sh (Tint I8 Unsigned noattr) a (Vint (Int.zero_ext 8 i))
  | Init_int16 i => umapsto sh (Tint I16 Unsigned noattr) a (Vint (Int.zero_ext 16 i))
  | Init_int32 i => umapsto sh (Tint I32 Unsigned noattr) a (Vint i)
  | Init_float32 r =>  umapsto sh (Tfloat F32 noattr) a (Vfloat ((Float.singleoffloat r)))
  | Init_float64 r =>  umapsto sh (Tfloat F64 noattr) a (Vfloat r)
  | Init_space n => mapsto_zeros n sh a
  | Init_addrof symb ofs =>
       match ge_of rho symb with
       | Some (v, Tarray t _ att) => umapsto sh (Tpointer t att) a (offset_val v ofs)
       | Some (v, Tvoid) => TT
       | Some (v, t) => umapsto sh (Tpointer t noattr) a (offset_val v ofs)
       | _ => TT
       end
 end.

Definition extern_retainer : share := Share.Lsh.

Definition init_data_size (i: init_data) : Z :=
  match i with
  | Init_int8 _ => 1
  | Init_int16 _ => 2
  | Init_int32 _ => 4
  | Init_float32 _ => 4
  | Init_float64 _ => 8
  | Init_addrof _ _ => 4
  | Init_space n => Zmax n 0
  end.

Fixpoint init_data_list_size (il: list init_data) {struct il} : Z :=
  match il with
  | nil => 0
  | i :: il' => init_data_size i + init_data_list_size il'
  end.

Fixpoint init_data_list2pred (dl: list init_data) 
                           (sh: share) (v: val)  (rho: environ) : mpred :=
  match dl with
  | d::dl' => 
      sepcon (init_data2pred d (Share.splice extern_retainer sh) v rho) 
                  (init_data_list2pred dl' sh (offset_val v (Int.repr (init_data_size d))) rho)
  | nil => emp
 end.

Definition readonly2share (rdonly: bool) : share :=
  if rdonly then Share.Lsh else Share.top.

Definition globvar2pred (idv: ident * globvar type) : environ->mpred :=
 fun rho =>
  match ge_of rho (fst idv) with
  | None => emp
  | Some (v, t) => if (gvar_volatile (snd idv))
                       then  TT
                       else    init_data_list2pred (gvar_init (snd idv))
                                   (readonly2share (gvar_readonly (snd idv))) v rho
 end.

Definition globvars2pred (vl: list (ident * globvar type)) : environ->mpred :=
  fold_right sepcon emp (map globvar2pred vl).

Definition initializer_aligned (z: Z) (d: init_data) : bool :=
  match d with
  | Init_int16 n => Zeq_bool (z mod 2) 0
  | Init_int32 n => Zeq_bool (z mod 4) 0
  | Init_float32 n =>  Zeq_bool (z mod 4) 0
  | Init_float64 n =>  Zeq_bool (z mod 8) 0
  | Init_addrof symb ofs =>  Zeq_bool (z mod 4) 0
  | _ => true
  end.
  
Fixpoint initializers_aligned (z: Z) (dl: list init_data) : bool :=
  match dl with 
  | nil => true 
  | d::dl' => andb (initializer_aligned z d) (initializers_aligned (z + init_data_size d) dl')
  end.

Definition writable_block (id: ident) (n: Z): environ->mpred :=
        EX v: val*type,  EX a: address, EX rsh: Share.t,
          (local(fun rho=> ge_of rho id = Some v /\ val2adr (fst v) a) && `(VALspec_range n rsh Share.top a)).

Fixpoint writable_blocks (bl : list (ident*Z)) : environ->mpred :=
 match bl with
  | nil => emp 
  | (b,n)::bl' => writable_block b n * writable_blocks bl'
 end.

Definition funsig := (list (ident*type) * type)%type. (* argument and result signature *)

Definition lvalue_block (rsh: Share.t) (e: Clight.expr) : environ->mpred :=
  fun rho => 
     match eval_lvalue e rho with 
     | Vptr b i => VALspec_range (sizeof (Clight.typeof e)) rsh Share.top (b, Int.unsigned i)
     | _ => FF
    end.

Definition var_block (rsh: Share.t) (idt: ident * type) : environ->mpred :=
         lvalue_block rsh (Clight.Evar (fst idt) (snd idt)).

Definition stackframe_of (f: Clight.function) : environ->mpred :=
  fold_right sepcon emp (map (var_block Share.top) (fn_vars f)).

Lemma  subst_extens {A}{NA: NatDed A}: 
 forall a v (P Q: environ -> A), P |-- Q -> subst a v P |-- subst a v Q.
Proof.
unfold subst, derives.
simpl;
auto.
Qed.

Definition type_of_funsig (fsig: funsig) := Tfunction (type_of_params (fst fsig)) (snd fsig).
Definition fn_funsig (f: function) : funsig := (fn_params f, fn_return f).

Definition bool_type (t: type) : bool :=
  match t with
  | Tint _ _ _ | Tpointer _ _ | Tarray _ _ _ | Tfunction _ _ | Tfloat _ _ => true
  | _ => false
  end.

Definition tc_formals (formals: list (ident * type)) : environ -> Prop :=
     fun rho => typecheck_vals (map (fun xt => (eval_id (fst xt) rho)) formals) (map (@snd _ _) formals) = true.

Definition globals_only (rho: environ) : environ :=
    mkEnviron (ge_of rho) (Map.empty _) (Map.empty _).

Fixpoint make_args (il: list ident) (vl: list val) (rho: environ)  :=
  match il, vl with 
  | nil, nil => globals_only rho
  | i::il', v::vl' => env_set (make_args il' vl' rho) i v
   | _ , _ => rho 
 end.
Definition make_args' (fsig: funsig) args rho :=
   make_args (map (@fst _ _) (fst fsig)) (args rho) rho.

Definition ret_temp : ident := 1%positive.

Definition get_result1 (ret: ident) (rho: environ) : environ :=
   make_args (ret_temp::nil) (eval_id ret rho :: nil) rho.

Definition get_result (ret: option ident) : environ -> environ :=
 match ret with 
 | None => make_args nil nil
 | Some x => get_result1 x
 end.

(* experiment... 
Canonical Structure Tassert  := 
    mkLift environ assert environ mpred assert
             (fun f x => f x)
       (fun f => f (fun z: environ => z)).
*)

Definition bind_ret (vl: option val) (t: type) (Q: environ -> mpred) : environ -> mpred :=
     match vl, t with
     | None, Tvoid =>`Q (make_args nil nil)
     | Some v, _ => @andp (environ->mpred) _ (!! (typecheck_val v t = true))
                             (`Q (make_args (ret_temp::nil) (v::nil)))
     | _, _ => FF
     end.

Definition overridePost  (Q: environ->mpred)  (R: ret_assert) := 
     fun ek vl => if eq_dec ek EK_normal then (!! (vl=None) && Q) else R ek vl.

Definition existential_ret_assert {A: Type} (R: A -> ret_assert) := 
  fun ek vl  => EX x:A, R x ek vl .

Definition normal_ret_assert (Q: environ->mpred) : ret_assert := 
   fun ek vl => !!(ek = EK_normal) && (!! (vl = None) && Q).

Definition with_ge (ge: genviron) (G: environ->mpred) : mpred :=
     G (mkEnviron ge (Map.empty _) (Map.empty _)).


Fixpoint prog_funct' {F V} (l: list (ident * globdef F V)) : list (ident * F) :=
 match l with nil => nil | (i,Gfun f)::r => (i,f):: prog_funct' r | _::r => prog_funct' r
 end.

Definition prog_funct (p: program) := prog_funct' (prog_defs p).

Fixpoint prog_vars' {F V} (l: list (ident * globdef F V)) : list (ident * globvar V) :=
 match l with nil => nil | (i,Gvar v)::r => (i,v):: prog_vars' r | _::r => prog_vars' r
 end.

Definition prog_vars (p: program) := prog_vars' (prog_defs p).

Definition all_initializers_aligned (prog: AST.program fundef type) := 
  forallb (fun idv => andb (initializers_aligned 0 (gvar_init (snd idv)))
                                 (Zlt_bool (init_data_list_size (gvar_init (snd idv))) Int.modulus))
                      (prog_vars prog) = true.

Definition frame_ret_assert (R: ret_assert) (F: environ->mpred) : ret_assert := 
      fun ek vl => R ek vl * F.
Lemma normal_ret_assert_derives:
 forall (P Q: environ->mpred) rho,
  P rho |-- Q rho ->
  forall ek vl, normal_ret_assert P ek vl rho |-- normal_ret_assert Q ek vl rho.
Proof.
 intros.
 unfold normal_ret_assert; intros; normalize.
 simpl.
 apply andp_derives.
 apply derives_refl.
 apply andp_derives.
 apply derives_refl.
 auto.
Qed.
Hint Resolve normal_ret_assert_derives.

Lemma normal_ret_assert_FF:
  forall ek vl, normal_ret_assert FF ek vl = FF.
Proof.
unfold normal_ret_assert. intros. normalize.
Qed.

Lemma frame_normal:
  forall P F, 
   frame_ret_assert (normal_ret_assert P) F = normal_ret_assert (P * F).
Proof.
intros.
extensionality ek vl.
unfold frame_ret_assert, normal_ret_assert.
normalize.
Qed.

Definition loop1_ret_assert (Inv: environ->mpred) (R: ret_assert) : ret_assert :=
 fun ek vl =>
 match ek with
 | EK_normal => Inv
 | EK_break => R EK_normal None
 | EK_continue => Inv
 | EK_return => R EK_return vl
 end.

Definition loop2_ret_assert (Inv: environ->mpred) (R: ret_assert) : ret_assert :=
 fun ek vl =>
 match ek with
 | EK_normal => Inv
 | EK_break => fun _ => FF
 | EK_continue => fun _ => FF 
 | EK_return => R EK_return vl
 end.

Lemma frame_for1:
  forall Q R F, 
   frame_ret_assert (loop1_ret_assert Q R) F = 
   loop1_ret_assert (Q * F) (frame_ret_assert R F).
Proof.
intros.
extensionality ek vl.
unfold frame_ret_assert, loop1_ret_assert.
destruct ek; normalize.
Qed.

Lemma frame_loop1:
  forall Q R F, 
   frame_ret_assert (loop2_ret_assert Q R) F = 
   loop2_ret_assert (Q * F) (frame_ret_assert R F).
Proof.
intros.
extensionality ek vl.
unfold frame_ret_assert, loop2_ret_assert.
destruct ek; normalize.
Qed.

Lemma overridePost_normal:
  forall P Q, overridePost P (normal_ret_assert Q) = normal_ret_assert P.
Proof.
intros; unfold overridePost, normal_ret_assert.
extensionality ek vl.
if_tac; normalize.
subst ek.
rewrite (prop_true_andp (EK_normal = _)) by auto.
auto.
apply pred_ext; normalize.
Qed.

Hint Rewrite normal_ret_assert_FF frame_normal frame_for1 frame_loop1 
                 overridePost_normal: normalize.

Definition function_body_ret_assert (ret: type) (Q: environ->mpred) : ret_assert := 
   fun (ek : exitkind) (vl : option val) =>
     match ek with
     | EK_return => bind_ret vl ret Q
     | _ => FF
     end.

Definition tc_environ (Delta: tycontext) : environ -> Prop :=
   fun rho => typecheck_environ Delta rho.

Definition tc_temp_id  (id: ident)  (ty: type) (Delta: tycontext) 
                       (e:expr): environ -> Prop := 
      denote_tc_assert (typecheck_temp_id id ty Delta e).

Definition tc_temp_id_load id tfrom Delta v : environ -> Prop  :=
fun rho => (exists tto, exists x, (temp_types Delta) ! id = Some (tto, x) /\ (allowedValCast (v rho) (tfrom) tto)= true).

Definition tc_expr (Delta: tycontext) (e: expr) : environ -> Prop := 
    denote_tc_assert (typecheck_expr Delta e).

Definition tc_exprlist (Delta: tycontext) (t: list type) (e: list expr)  : environ -> Prop := 
      denote_tc_assert (typecheck_exprlist Delta t e).

Definition tc_lvalue (Delta: tycontext) (e: expr) : environ -> Prop := 
     denote_tc_assert (typecheck_lvalue Delta e).

Definition tc_value (v:environ -> val) (t :type) : environ -> Prop :=
     fun rho => typecheck_val (v rho) t = true.

Definition tc_expropt Delta (e: option expr) (t: type) : environ -> Prop :=
   match e with None => `(t=Tvoid)
                     | Some e' => tc_expr Delta (Ecast e' t)
   end.

Fixpoint arglist (n: positive) (tl: typelist) : list (ident*type) :=
 match tl with 
  | Tnil => nil
  | Tcons t tl' => (n,t):: arglist (n+1)%positive tl'
 end.

Definition closed_wrt_modvars c (F: environ->mpred) : Prop :=
    closed_wrt_vars (modifiedvars c) F.

Definition exit_tycon (c: statement) (Delta: tycontext) (ek: exitkind) : tycontext :=
  match ek with 
  | EK_normal => update_tycon Delta c 
  | _ => Delta 
  end.

Definition initblocksize (V: Type)  (a: ident * globvar V)  : (ident * Z) :=
 match a with (id,l) => (id , init_data_list_size (gvar_init l)) end.

Definition main_pre (prog: program) : unit -> environ->mpred := 
  (fun tt => globvars2pred (prog_vars prog)).

Definition main_post (prog: program) : unit -> environ->mpred := 
  (fun tt => TT).

Definition match_globvars (gvs: list (ident * globvar type)) (V: varspecs) :=
  forall id t, In (id,t) V -> exists g: globvar type, gvar_info g = t /\ In (id,g) gvs.

(* Don't know why this next Hint doesn't work unless fully instantiated;
   perhaps because one needs both "contractive" and "typeclass_instances"
   Hint databases if this next line is not added. *)
Hint Resolve (@subp_sepcon mpred Nveric Iveric Sveric SIveric Rveric SRveric): contractive.

Module Type  CLIGHT_SEPARATION_LOGIC.

Local Open Scope pred.

Parameter semax:  tycontext -> (environ->mpred) -> statement -> ret_assert -> Prop.

(***************** SEMAX_LEMMAS ****************)

Axiom extract_exists:
  forall (A : Type)  (P : A -> environ->mpred) c (Delta: tycontext) (R: A -> ret_assert),
  (forall x, semax Delta (P x) c (R x)) ->
   semax Delta (EX x:A, P x) c (existential_ret_assert R).

Axiom semax_extensionality_Delta:
  forall Delta Delta' P c R,
       tycontext_eqv Delta Delta' ->
     semax Delta P c R -> semax Delta' P c R.

(** THESE RULES FROM semax_prog **)

Definition semax_body
       (V: varspecs) (G: funspecs) (f: function) (spec: ident * funspec) : Prop :=
  match spec with (_, mk_funspec _ A P Q) =>
    forall x,
      semax (func_tycontext f V G)
          (P x *  stackframe_of f)
          f.(fn_body)
          (frame_ret_assert (function_body_ret_assert (fn_return f) (Q x)) (stackframe_of f))
 end.

Parameter semax_func: forall (V: varspecs) (G: funspecs) (fdecs: list (ident * fundef)) (G1: funspecs), Prop.

Definition semax_prog 
     (prog: program) (V: varspecs) (G: funspecs) : Prop :=
  compute_list_norepet (prog_defs_names prog) = true /\
  all_initializers_aligned prog /\ 
  semax_func V G (prog_funct prog) G /\
   match_globvars (prog_vars prog) V /\
    In (prog.(prog_main), mk_funspec (nil,Tvoid) unit (main_pre prog ) (main_post prog)) G.

Axiom semax_func_nil: forall V G, semax_func V G nil nil.

Definition semax_body_params_ok f : bool :=
   andb 
        (compute_list_norepet (map (@fst _ _) (fn_params f) ++ map (@fst _ _) (fn_temps f)))
        (compute_list_norepet (map (@fst _ _) (fn_vars f))).

Axiom semax_func_cons: forall fs id f A P Q (V: varspecs)  (G G': funspecs),
      andb (id_in_list id (map (@fst _ _) G)) 
      (andb (negb (id_in_list id (map (@fst ident fundef) fs)))
        (semax_body_params_ok f)) = true ->
      semax_body V G f (id, mk_funspec (fn_funsig f) A P Q ) ->
      semax_func V G fs G' ->
      semax_func V G ((id, Internal f)::fs) 
           ((id, mk_funspec (fn_funsig f) A P Q ) :: G').

Parameter semax_external:
  forall (ef: external_function) (A: Type) (P Q: A -> environ->mpred),  Prop.

Axiom semax_external_FF:
  forall ef A Q, semax_external ef A FF Q.

Axiom semax_func_cons_ext: 
   forall (V: varspecs) (G: funspecs) fs id ef argsig retsig A P Q (G': funspecs),
      andb (id_in_list id (map (@fst _ _) G))
              (negb (id_in_list id (map (@fst _ _) fs))) = true ->
      semax_external ef A P Q ->
      semax_func V G fs G' ->
      semax_func V G ((id, External ef argsig retsig)::fs) 
           ((id, mk_funspec (arglist 1%positive argsig, retsig) A P Q)  :: G').

(* THESE RULES FROM semax_loop *)

Axiom semax_ifthenelse : 
   forall Delta P (b: expr) c d R,
      bool_type (typeof b) = true ->
     semax Delta (P && local (`(typed_true (typeof b)) (eval_expr b))) c R -> 
     semax Delta (P && local (`(typed_false (typeof b)) (eval_expr b))) d R -> 
     semax Delta (local (tc_expr Delta b) && P) (Sifthenelse b c d) R.

Axiom semax_seq:
forall Delta R P Q h t, 
    semax Delta P h (overridePost Q R) -> 
    semax (update_tycon Delta h) Q t R -> 
    semax Delta P (Ssequence h t) R.

Axiom seq_assoc:  
   forall Delta P s1 s2 s3 R,
        semax Delta P (Ssequence s1 (Ssequence s2 s3)) R <->
        semax Delta P (Ssequence (Ssequence s1 s2) s3) R.

Axiom semax_break:
   forall Delta Q,    semax Delta (Q EK_break None) Sbreak Q.

Axiom semax_continue:
   forall Delta Q,    semax Delta (Q EK_continue None) Scontinue Q.

Axiom semax_loop : 
forall Delta Q Q' incr body R,
     semax Delta  Q body (loop1_ret_assert Q' R) ->
     semax Delta Q' incr (loop2_ret_assert Q R) ->
     semax Delta Q (Sloop body incr) R.

(* THESE RULES FROM semax_call *)

Axiom semax_call : 
    forall Delta A (P Q: A -> environ -> mpred) (x: A) (F: environ -> mpred) ret argsig retsig a bl,
           Cop.classify_fun (typeof a) =
           Cop.fun_case_f (type_of_params argsig) retsig ->
           (retsig = Tvoid <-> ret = None) ->
  semax Delta
          (local (tc_expr Delta a) && local (tc_exprlist Delta (snd (split argsig)) bl)  && 
         (`(func_ptr (mk_funspec  (argsig,retsig) A P Q)) (eval_expr a) &&   
          (F * `(P x) (make_args' (argsig,retsig) (eval_exprlist (snd (split argsig)) bl)))))
         (Scall ret a bl)
         (normal_ret_assert  
          (EX old:val, substopt ret (`old) F * `(Q x) (get_result ret))).

Axiom  semax_return :
   forall Delta (R: ret_assert) ret ,
      semax Delta  
                (local (tc_expropt Delta ret (ret_type Delta)) &&
                `(R EK_return : option val -> environ -> mpred) (cast_expropt ret (ret_type Delta)) (@id environ))
                (Sreturn ret)
                R.

Axiom semax_fun_id:
      forall id f Delta P Q c,
    (var_types Delta) ! id = None ->
    (glob_types Delta) ! id = Some (Global_func f) ->
    semax Delta (P && `(func_ptr f) (eval_var id (globtype (Global_func f))))
                  c Q ->
    semax Delta P c Q.

Axiom semax_call_ext:
     forall Delta P Q ret a tl bl a' bl',
      typeof a = typeof a' ->
       local (tc_environ Delta) && P |-- 
                  local (`eq (eval_expr a) (eval_expr a')) &&
                  local (`eq (eval_exprlist tl bl) (eval_exprlist tl bl')) ->
  semax Delta P (Scall ret a bl) Q ->
  semax Delta P (Scall ret a' bl') Q.

(* THESE RULES FROM semax_straight *)

Axiom semax_set : 
forall (Delta: tycontext) (P: environ->mpred) id e,
    semax Delta 
        (|> (local (tc_expr Delta e) && 
            local (tc_temp_id id (typeof e) Delta e) &&
             subst id (eval_expr e) P))
          (Sset id e) (normal_ret_assert P).

Axiom semax_set_forward : 
forall (Delta: tycontext) (P: environ->mpred) id e,
    semax Delta 
        (|> (local (tc_expr Delta e) && 
            local (tc_temp_id id (typeof e) Delta e) && 
          P))
          (Sset id e) 
        (normal_ret_assert 
          (EX old:val, local (`eq (eval_id id) (subst id (`old) (eval_expr e))) &&
                            subst id (`old) P)).

Axiom semax_load : 
forall (Delta: tycontext) sh id P e1 v2,
    semax Delta 
       (|> (local (tc_lvalue Delta e1) && 
       local (tc_temp_id_load id (typeof e1) Delta v2) && 
       (`(mapsto sh (typeof e1)) (eval_lvalue e1) v2 * P)))
       (Sset id e1)
       (normal_ret_assert (EX old:val, local (`eq (eval_id id) (subst id (`old) v2)) &&
                                          (subst id (`old) (`(mapsto sh (typeof e1)) (eval_lvalue e1) v2 * P)))).

Axiom semax_store:
 forall Delta e1 e2 sh P,
   writable_share sh ->
   semax Delta 
          (|> (local (tc_lvalue Delta e1) && local (tc_expr Delta (Ecast e2 (typeof e1)))  && 
             (`(mapsto_ sh (typeof e1)) (eval_lvalue e1) * P)))
          (Sassign e1 e2) 
          (normal_ret_assert 
               (`(mapsto sh (typeof e1)) (eval_lvalue e1) (`(eval_cast (typeof e2) (typeof e1)) (eval_expr e2)) * P)).

(* THESE RULES FROM semax_lemmas *)

Axiom semax_skip:
   forall Delta P, semax Delta P Sskip (normal_ret_assert P).

Axiom semax_pre_post:
 forall P' (R': ret_assert) Delta P c (R: ret_assert) ,
    (local (tc_environ Delta) && P |-- P') ->
   (forall ek vl, local (tc_environ (exit_tycon c Delta ek)) &&  R' ek vl |-- R ek vl) ->
   semax Delta P' c R' -> semax Delta P c R.

(**************** END OF stuff from semax_rules ***********)

Axiom semax_frame:  forall Delta P s R F,
   closed_wrt_modvars s F ->
  semax Delta P s R ->
    semax Delta (P * F) s (frame_ret_assert R F).

Axiom semax_extract_prop:
  forall Delta (PP: Prop) P c Q, 
           (PP -> semax Delta P c Q) -> 
           semax Delta (!!PP && P) c Q.

End CLIGHT_SEPARATION_LOGIC.
