use "processed_data/density_analysis.dta", clear

* 1. Look at the range where the bunching should happen (-50 to 10)
list bin ns_all1_D0 n_tilde_all1_D0 excessB_all1 if bin >= -50 & bin <= 50

* 2. Check the Gamma (the price effect) result
display "THE FINAL GAMMA IS: " mean_gamma_all1[1]

* 3. Check if we have ANY non-missing values for the counterfactual
count if !missing(n_tilde_all1_D0)
