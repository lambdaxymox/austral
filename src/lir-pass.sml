(*
    Copyright 2018 Fernando Borretti <fernando@borretti.me>

    This file is part of Boreal.

    Boreal is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Boreal is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Boreal.  If not, see <http://www.gnu.org/licenses/>.
*)

structure LirPass :> LIR_PASS = struct
    type ty = LIR.ty
    structure L = LIR

    (* Tuples *)

    type tuple_types = (ty list, ty) Map.map

    val emptyTupleTypes =
        Map.empty

    fun getTuple tt tys =
        Map.get tt tys

    val count = ref 0
    fun freshId () =
        (count := !count + 1;
         !count)

    fun addTuple tt tys =
        case getTuple tt tys of
            (SOME ty) => (ty, tt)
          | NONE => let val id = freshId ()
                    in
                        let val ty = L.Tuple id
                        in
                            (ty, Map.iadd tt (tys, ty))
                        end
                    end

    (* Transform types *)

    val sizeType = L.Integer (Type.Unsigned, Type.Int64)

    fun transformType tt MIR.Bool =
        (L.Bool, tt)
      | transformType tt (MIR.Integer (s, w)) =
        (L.Integer (s, w), tt)
      | transformType tt (MIR.Float f) =
        (L.Float f, tt)
      | transformType tt (MIR.Tuple tys) =
        let val (tys', tt) = Util.foldThread (fn (ty, tt) =>
                                                 transformType tt ty)
                                             tys
                                             tt
        in
            addTuple tt tys'
        end
      | transformType tt (MIR.Pointer t) =
        let val (t', tt) = transformType tt t
        in
            (L.Pointer t', tt)
        end
      | transformType tt (MIR.StaticArray t) =
        let val (t', tt) = transformType tt t
        in
            addTuple tt [sizeType, t']
        end
      | transformType tt (MIR.Disjunction (name, id)) =
        (L.Disjunction (name, id), tt)

    (* Transform code *)

    fun transformOperand tt (MIR.BoolConstant b) =
        (L.BoolConstant b, tt)
      | transformOperand tt (MIR.IntConstant (i, ty)) =
        let val (ty, tt) = transformType tt ty
        in
            (L.IntConstant (i, ty), tt)
        end
      | transformOperand tt (MIR.FloatConstant (f, ty)) =
        let val (ty, tt) = transformType tt ty
        in
            (L.FloatConstant (f, ty), tt)
        end
      | transformOperand tt (MIR.StringConstant s) =
        (L.StringConstant s, tt)
      | transformOperand tt (MIR.RegisterOp r) =
        (L.RegisterOp r, tt)
      | transformOperand tt (MIR.VariableOp (var, ty)) =
        let val (ty, tt) = transformType tt ty
        in
            (L.VariableOp (var, ty), tt)
        end

    fun transformOperation tt (MIR.ArithOp (kind, oper, lhs, rhs)) =
        let val (lhs, tt) = transformOperand tt lhs
        in
            let val (rhs, tt) = transformOperand tt rhs
            in
                (L.ArithOp (kind, oper, lhs, rhs), tt)
            end
        end
      | transformOperation tt (MIR.TupleCreate opers) =
        let val (opers, tt) = transformOperands tt opers
        in
            (L.TupleCreate opers, tt)
        end
      | transformOperation tt (MIR.TupleProj (tup, idx)) =
        let val (tup, tt) = transformOperand tt tup
        in
            (L.TupleProj (tup, idx), tt)
        end
      | transformOperation tt (MIR.ArrayLength arr) =
        let val (arr, tt) = transformOperand tt arr
        in
            (L.ArrayLength arr, tt)
        end
      | transformOperation tt (MIR.ArrayPointer arr) =
        let val (arr, tt) = transformOperand tt arr
        in
            (L.ArrayPointer arr, tt)
        end
      | transformOperation _ _ =
        raise Fail "Not implemented yet"

    and transformOperands tt opers =
        Util.foldThread (fn (oper, tt) =>
                            transformOperand tt oper)
                        opers
                        tt
end
