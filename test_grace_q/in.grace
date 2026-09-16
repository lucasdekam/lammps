units           metal
boundary        p p f
atom_style      atomic
read_data       frame.data
# padding 0 disables the fake-atom padding, so the energy and dE/dq are those
# of the real system and comparable to ASE atom for atom
pair_style      grace padding 0 q ${Q}
pair_coeff      * * ${MODEL} O H Pt
thermo_style    custom step pe
run             0
