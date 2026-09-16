# test_grace_q

Regression test for the charge conditioning added to `pair_style grace`: does
the total charge reach a FiLM-conditioned model, does the work function dE/dq
come back out, and does LAMMPS agree with the ASE calculator on the same
structure?

`frame.data` and the model are deliberately **not** committed — the model is a
trained checkpoint and the frame comes from an unpublished dataset. Generate
the frame from any structure whose species are O/H/Pt:

```python
from ase.io import read, write
a = read("<structures>.xyz", index=0); a.wrap()
write("frame.data", a, format="lammps-data", specorder=["O","H","Pt"], masses=True)
```

Then, with the grace venv active, `bash run_test.sh`.

`padding 0` is deliberate: it disables the fake-atom padding, so the energy and
dE/dq are those of the real system and compare to ASE atom for atom.

## Reading the work function

The pair style publishes dE/dq as its one global extra quantity, so it goes
into the normal thermo output:

```
compute      wf all pair grace
thermo_style custom step pe c_wf[1]
```

`ComputePair` MPI_SUM-reduces `pvector` across ranks, so the pair style
contributes from rank 0 only — otherwise a multi-rank run would report nprocs
times the work function. The value is NaN until a charge-conditioned model
produces one, so reading it off a model without a `work_function` output is
obvious rather than a plausible zero.

## What it showed

On a 108-atom Pt(111)/water frame with the razor-grace model, LAMMPS reproduced
the ASE `TPCalculator` to every digit printed — energy on the model's own raw
scale, before the per-element E0 that `reference_energy: auto` subtracts from
the labels:

| q (e) | ASE E (eV) | LAMMPS PotEng (eV) | ASE Φ (V) | LAMMPS `c_wf[1]` (V) |
| ---: | ---: | ---: | ---: | ---: |
| −0.5 | −1.717353 | −1.7173532 | 8.049153 | 8.0491536 |
| +0.5 | +7.715367 | 7.715367 | 9.665489 | 9.6654887 |

The two charges differ by 9.43 eV and 1.62 V, so the charge is read rather than
ignored.
