units           metal
boundary        p p f
atom_style      atomic
read_data       frame.data

# padding 0 disables the fake-atom padding, so the energy and dE/dq are those
# of the real system and compare to ASE atom for atom
pair_style      grace padding 0 q ${Q}
pair_coeff      * * ${MODEL} O H Pt

# the work function dE/dq, published as the pair style's global extra quantity
compute         wf all pair grace
thermo_style    custom step pe c_wf[1]
run             0
