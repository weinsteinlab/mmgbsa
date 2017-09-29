
# Selection for the whole complex
set complex_sel_text " protein or (chain S T U L M N and not lipid) "
# Must be the same as given to setup_charmm.csh 

# Selection text for part A
# transport domain A
set A_sel_text "  chain A and ( (resid 223 to 417) or (chain S L and not lipid) )  "

# Selection text for part B
# trimerization domains and transport domains ABC
set B_sel_text "   chain A and (resid 34 to 74)   "

# Cutoff to choose residues within each part, for which the decomposition will be made. 
set cutoff_residues 0


# Selection text for interesting residues of part A
set Aresidues_sel_text  "( $A_sel_text ) and ( chain A and resid 351 to 353  )"

# Selection text for interesting residues of part B
set Bresidues_sel_text  " ( $B_sel_text ) and ( chain A and resid 51 to 53  )"

