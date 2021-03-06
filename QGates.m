(* Abort for old, unsupported versions of Mathematica *)
If[$VersionNumber < 10,
  Print["QGates requires Mathematica 10.0 or later."];
  Abort[]
];

BeginPackage["QM`QGates`", {"QM`"}];

(* Unprotect all package symbols *)
Unprotect @@ Names["QM`QGates`*"];
ClearAll @@ Names["QM`QGates`*"];

(* Define all exposed symbols *)
ProjectionMatrix;
CPhase;
CNot::usage = "\
CNot[numQubits, control, target] is the CNOT gate applied between `control` and `target`, operating over `numQubits` qubits.";

Hadamard;
PauliX::usage = "\
PauliX[numQubits, target] returns the matrix representing the Pauli X matrix \
acting on the `target`-th qubit in the Hilbert space generated by numQubits \
qubits.";
PauliY::usage = "\
PauliY[numQubits, target] returns the matrix representing the Pauli Y matrix \
acting on the `target`-th qubit in the Hilbert space generated by numQubits \
qubits.";
PauliZ::usage = "\
PauliZ[numQubits, target] returns the matrix representing the Pauli Z matrix \
acting on the `target`-th qubit in the Hilbert space generated by numQubits \
qubits.";

PauliProduct::usage = "\
PauliProduct[index] is equivalent to PauliMatrix[index].";
PauliProduct::usage = "\
PauliProduct[indices] returns the KroneckerProduct product of the Pauli \
matrices corresponding to the given indices.";

QOneQubitGate::usage = "\
QOneQubitGate[numQubits, target, matrix] returns the matrix representing the \
action of the one qubit gate `matrix` on the target qubit.";
QTwoQubitGate::usage = "\
QTwoQubitGate[numQubits, control, target, matrix] returns the matrix representing the gate `matrix` between the control and the target qubit.";
QThreeQubitGate::usage = "\
QThreeQubitGate[numQubits, q1, q2, q3, matrix] returns the matrix representing the gate `matrix` between the three qubits q1, q2 and q3.";

QControlledGate;

Swap;
Toffoli;
Fredkin;

Begin["`Private`"];

KP[x_] := x;
KP[x___] := KroneckerProduct @ x;

ProjectionMatrix[numQubits_Integer, y_, x_] := Normal @ SparseArray[
  {{y, x} -> 1},
  {2 ^ numQubits, 2 ^ numQubits}
];

p11 = ProjectionMatrix[1, 1, 1];
p22 = ProjectionMatrix[1, 2, 2];


QOneQubitGate[numQubits_Integer, target_Integer, matrix_] := Block[
  {identities},
  identities = ConstantArray[
    IdentityMatrix @ 2, numQubits
  ];
  identities[[target]] = matrix;

  (* Return result *)
  KP @@ identities
];


(* To compute a two qubit gate between any pair of qubits,
   we first write the matrix describing the two-qubit gate
   acting on the last two qubits, and then permute the indices
   appropriately.*)
QTwoQubitGate[numQubits_Integer,
              control_Integer,
              target_Integer,
              matrix_
  ] := Block[{tp, matrixAsTP, transposedBigTP},
  (* Convert matrix to a TensorProduct structure *)
  matrixAsTP = Transpose[
    ArrayReshape[matrix, {2, 2, 2, 2}],
    {1, 3, 2, 4}
    ];
  (* Make the rest of the identity matrices comprising the total matrix of the
     gate, and then put everything (identity matrices and restructured `matrix`)
     together with TensorProduct *)
  tp = TensorProduct[
    TensorProduct @@ ConstantArray[IdentityMatrix @ 2, numQubits - 2],
    matrixAsTP
  ];
  (* Transpose the nested List produced by TensorProduct to make `matrix`
     operate on the control and target qubits *)
  transposedBigTP = Transpose[tp,
    Sequence @@ {2 # - 1, 2 #} & /@
        {
          Sequence @@ Complement[Range @ numQubits, {control, target}],
          control,
          target
        }
  ];
  (* Rearrange and flatten indices to convert the TensorProduct into a matrix
     compatible with the output of a KroneckerProduct operation *)
  Flatten[transposedBigTP,
    {
      Range[1, 2 numQubits, 2],
      Range[2, 2 numQubits, 2]
    }
  ]
];

QThreeQubitGate[numQubits_Integer,
                q1_Integer,
                q2_Integer,
                q3_Integer,
                matrix_
  ] /; numQubits >= 3 := Block[{tp, matrixAsTP, transposedBigTP},
  (* Convert matrix to a TensorProduct structure *)
  matrixAsTP = Transpose[
    ArrayReshape[matrix, {2, 2, 2, 2, 2, 2}],
    {1, 3, 5, 2, 4, 6}
  ];
  (* Make the rest of the identity matrices comprising the total matrix of the
     gate, and then put everything (identity matrices and restructured `matrix`)
     together with TensorProduct *)
  tp = TensorProduct[
    TensorProduct @@ ConstantArray[IdentityMatrix @ 2, numQubits - 3],
    matrixAsTP
  ];
  (* Transpose the nested List produced by TensorProduct to make `matrix`
     operate on the control and target qubits *)
  transposedBigTP = Transpose[tp,
    Sequence @@ {2 # - 1, 2 #} & /@
        {
          Sequence @@ Complement[Range @ numQubits, {q1, q2, q3}],
          q1, q2, q3
        }
  ];
  (* Rearrange and flatten indices to convert the TensorProduct into a matrix
     compatible with the output of a KroneckerProduct operation *)
  Flatten[transposedBigTP,
    {
      Range[1, 2 numQubits, 2],
      Range[2, 2 numQubits, 2]
    }
  ]
];


QControlledGate[numQubits_Integer,
                controlQubit_Integer,
                targetQubits_List,
                gateMatrix_] /; (
  And[
    1 <= controlQubit <= numQubits,
    Sequence @@ Thread[1 <= targetQubits <= numQubits],
    Sequence @@ Thread[targetQubits != controlQubit]
  ]
) := Module[{gate},
  gate = Plus[
    KP[ProjectionMatrix[1, 1, 1], IdentityMatrix[2 ^ Length @ targetQubits]],
    KP[ProjectionMatrix[1, 2, 2], gateMatrix]
  ];
  gate = KP[gate, IdentityMatrix[2 ^ (numQubits - Length @ targetQubits - 1)]];

  QBasePermutation[gate,
    ConstantArray[2, numQubits],
    {controlQubit, Sequence @@ targetQubits,
      Sequence @@ Complement[
        Range @ numQubits, Append[targetQubits, controlQubit]
      ]
    }
  ]
];

QControlledGate[
  numQubits_Integer,
  controlQubit_Integer,
  targetQubits_Integer,
  gateMatrix_
] := QControlledGate[numQubits, controlQubit, {targetQubits}, gateMatrix];

(*
  For example,
    PauliProduct[1, 2] == KP[PauliX[], PauliY[]],
    PauliProduct[0, 3] == KP[PauliMatrix[0], PauliZ[]],
    PauliProduct[2] == PauliY[] == PauliMatrix[2].
*)
PauliProduct[idx_] := PauliMatrix[idx];
PauliProduct[indices__Integer] /; And @@ Thread[0 <= {indices} <= 3] :=
  KP @@ PauliMatrix /@ {indices};


(* defineOneQubitGateFunctions is a "macro" to easily create the downvalues
   associated functions defining one qubit gates *)
Attributes[defineOneQubitGateFunctions] = {HoldRest};
defineOneQubitGateFunctions[name_Symbol, matrix_] := (
  name[] = matrix;
  name[numQubits_Integer, target_Integer] := QOneQubitGate[
    numQubits, target, name[]
  ];
  name[numQubits_Integer, {target_Integer}] := name[numQubits, target];
  name[numQubits_Integer] := name[numQubits, numQubits];
);

Attributes[defineTwoQubitGateFunctions] = HoldRest;
defineTwoQubitGateFunctions[name_Symbol, matrix_] := (
  name[] := matrix;
  name[numQubits_Integer, q1_Integer, q2_Integer] := QTwoQubitGate[
    numQubits, q1, q2, name[]
  ];
  name[numQubits_Integer, {q1_, q2_}] := name[numQubits, q1, q2];
  name[q1_Integer, q2_Integer] := name[Max @ {q1, q2}, q1, q2];
);

Attributes[defineThreeQubitGateFunctions] = HoldRest;
defineThreeQubitGateFunctions[name_Symbol, matrix_] := (
  name[] := matrix;
  name[numQubits_Integer,
       q1_Integer, q2_Integer, q3_Integer
    ] /; TrueQ @ And[
      And @@ Thread[1 <= {q1, q2, q3} <= numQubits],
      Length @ Union @ {q1, q2, q3} == 3
    ] := QThreeQubitGate[numQubits, q1, q2, q3, name[]];
  name[numQubits_Integer, {q1_, q2_, q3_}] := name[numQubits, q1, q2, q3];
  name[q1_Integer, q2_Integer, q3_Integer] := name[
    Max @ {q1, q2, q3}, q1, q2, q3
  ];
  (* Error handling *)
  name::badArgs = "Incorrect inputs.";
  name[args___] /; Message[name::badArgs] := Null;
);


defineOneQubitGateFunctions[Hadamard, HadamardMatrix @ 2];
defineOneQubitGateFunctions[PauliX, PauliMatrix @ 1];
defineOneQubitGateFunctions[PauliY, PauliMatrix @ 2];
defineOneQubitGateFunctions[PauliZ, PauliMatrix @ 3];


(* -------- TWO QUBIT GATES -------- *)

defineTwoQubitGateFunctions[CPhase,
  Plus[
    KP[{{1, 0}, {0, 0}}, IdentityMatrix @ 2],
    KP[{{0, 0}, {0, 1}}, PauliZ[]]
  ]
];

defineTwoQubitGateFunctions[CNot,
  Plus[
    KP[{{1, 0}, {0, 0}}, IdentityMatrix @ 2],
    KP[{{0, 0}, {0, 1}}, PauliX[]]
  ]
];

defineTwoQubitGateFunctions[Swap,
  {{1, 0, 0, 0},
   {0, 0, 1, 0},
   {0, 1, 0, 0},
   {0, 0, 0, 1}}
];

(* -------- THREE QUBIT GATES -------- *)

defineThreeQubitGateFunctions[Toffoli,
  SparseArray[
    {
      {i_, i_} /; i <= 6 -> 1,
      {7, 8} -> 1, {8, 7} -> 1
    },
    {8, 8}
  ]
];

defineThreeQubitGateFunctions[Fredkin,
  SparseArray[
    {
      {i_, i_} /; i < 6 -> 1,
      {6, 7} -> 1, {7, 6} -> 1,
      {8, 8} -> 1
    },
    {8, 8}
  ]
];



(* Protect all package symbols *)
With[{syms = Names["QM`QGates`*"]},
  SetAttributes[syms, {Protected, ReadProtected}]
];


End[];
EndPackage[];
