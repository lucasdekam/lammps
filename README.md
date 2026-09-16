# LAMMPS with charge-conditioned GRACE

Branch `grace`, forked from [yury-lysogorskiy/lammps](https://github.com/yury-lysogorskiy/lammps).
The stock LAMMPS README is in [`README`](README); this file covers only what
this fork adds.

A charge-conditioned (FiLM) GRACE model takes a per-structure total charge as
an input and exports the work function dE/dq alongside energy and forces. This
fork wires both through `pair_style grace`, so constant-charge MD of a charged
electrode/electrolyte interface can run in LAMMPS instead of through ASE.

Both are optional and detected from the saved model's signature: a model with
neither tensor is driven exactly as before. The reference documentation is
[`doc/src/pair_grace.rst`](doc/src/pair_grace.rst).

## Setting the charge

```
pair_style  grace q -0.5
pair_coeff  * * /path/to/saved_model O H Pt
```

`q` is the total charge in e, negative for excess electrons, matching GPAW-SJM
and the usual training-data convention. It combines with the existing keywords
(`padding`, `pad_verbose`, `pair_forces`, …).

Giving `q` to a model whose compute signature has no `total_charge` input is an
**error, not a warning**. The charge would otherwise be ignored and every
number downstream would be the q = 0 answer wearing a charge label.

The charge is also mutable mid-run through `Pair::extract("total_charge")`,
which is how a Python driver can ramp or step it without rebuilding.

## Reading the work function

dE/dq is published as the pair style's one global extra quantity (`pvector`) —
the standard LAMMPS mechanism for a scalar a pair style computes that is not an
energy. `compute pair` exposes it:

```
compute       wf all pair grace
thermo_style  custom step temp pe c_wf[1]
```

It is then an ordinary thermo value, so `fix ave/time`, `dump`, `print` and
variables all work on it. No separate output file is needed. It is also
readable through `Pair::extract("work_function")`.

Three things to know about the value:

- **`ComputePair` MPI_SUM-reduces `pvector` across ranks**, so the pair style
  contributes from rank 0 only. Without that a multi-rank run would report
  nprocs times the work function — and would look perfectly plausible when
  tested on one rank.
- **It starts as `NaN`** and stays NaN unless a charge-conditioned model
  actually produces one, so reading it off an ordinary GRACE model is obvious
  rather than a believable zero.
- **It is dE/dq of the _padded_ system.** Padded atoms map to structure 0, so
  FiLM conditions them on the real charge and they contribute. Unlike the
  padded energy this is *not* a constant offset, because the contribution is
  itself charge dependent. Run with `padding 0` where the absolute dE/dq has to
  be exact; padding is otherwise a speed/recompilation trade-off, not a
  correctness one.

## Building

```bash
bash configure.sh      # ON THE LOGIN NODE — it downloads
sbatch srun_build.sh   # compile only
```

The split is not cosmetic. CMake configure downloads three things for ML-PACE —
the PACE evaluator library, cppflow, and TensorFlow itself — and compute nodes
on many clusters have no outbound network.

Two traps in the TensorFlow discovery, both of which cost a build here:

- **Do not pass `-DTF_LIB_FILE`.** It takes a branch of
  [`cmake/Modules/Packages/ML-PACE.cmake`](cmake/Modules/Packages/ML-PACE.cmake)
  that sets the library but never `TF_INCLUDE_PATH`, so cppflow cannot find
  `tensorflow/c/tf_tensor.h` and the compile dies about 2000 objects in. Only
  the Python-discovery branch sets both.
- **Do pass `-DPACE_PYTHON_EXEC=$(which python3)`.** CMake's own
  `find_program(python3)` picks the system or module python rather than the
  active virtualenv, and if that interpreter has no TensorFlow, discovery
  returns nothing and CMake silently downloads TensorFlow and builds against it
  — a different TensorFlow from the one loaded at run time, with nothing in the
  log to say so.

`configure.sh` does both, then verifies the library CMake found actually lives
inside the virtualenv rather than trusting the message.

Kokkos is deliberately not built: the Kokkos pair styles read a `.npz` exported
by `grace_utils export_kokkos`, which rejects non-standard instruction graphs,
and FiLM conditioning is one.

## Verifying

[`test_grace_q/`](test_grace_q) checks that the charge reaches the model and
the work function comes back out, against the ASE `TPCalculator` on the same
structure. On a 108-atom Pt(111)/water frame:

| q (e) | ASE E (eV) | LAMMPS `PotEng` (eV) | ASE Φ (V) | LAMMPS `c_wf[1]` (V) |
| ----: | ---------: | -------------------: | --------: | -------------------: |
|  −0.5 |  −1.717353 |           −1.7173532 |  8.049153 |            8.0491536 |
|  +0.5 |  +7.715367 |             7.715367 |  9.665489 |            9.6654887 |

Every digit printed, both quantities, both charges — and the two charges differ
by 9.43 eV and 1.62 V, so the charge is read rather than ignored.
