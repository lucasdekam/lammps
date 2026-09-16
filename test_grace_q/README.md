# test_grace_q

Regression test for the `q` keyword added to `pair_style grace`: does the total
charge actually reach a charge-conditioned (FiLM) model, and does LAMMPS agree
with the ASE calculator on the same structure?

`frame.data` and the model are deliberately **not** committed — the model is a
trained checkpoint and the frame comes from an unpublished dataset. Generate
the frame from any structure whose species are O/H/Pt:

```python
from ase.io import read, write
a = read("<structures>.xyz", index=0); a.wrap()
write("frame.data", a, format="lammps-data", specorder=["O","H","Pt"], masses=True)
```

Then, with the grace venv active:

```bash
for q in -0.5 0.5; do
  lmp -var Q $q -var MODEL /path/to/final_model_fixed -in in.grace
done
```

`padding 0` is deliberate: it disables the fake-atom padding, so the energy and
dE/dq are those of the real system and compare to ASE atom for atom.

## What it showed

On a 108-atom Pt(111)/water frame with the razor-grace model, LAMMPS reproduced
the ASE `TPCalculator` raw energy — the model's own scale, before the
per-element E0 that `reference_energy: auto` subtracts from the labels:

| q (e) | ASE (eV) | LAMMPS (eV) |
| ---: | ---: | ---: |
| −0.5 | −1.717353 | −1.7173532 |
| +0.5 | +7.715367 | 7.715367 |

Every digit printed, and 9.43 eV apart — so the charge is read, not ignored.
