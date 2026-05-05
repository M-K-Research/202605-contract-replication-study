* ==============================================================================
* THE X-RAY DIAGNOSTIC: FINDING THE HIDDEN SCALARS
* ==============================================================================

* 1. Prep the environment
cd "C:/Users/Public/StataWork"
use "clean_input.dta", clear
bsample 

* 2. Re-bin
gen logAmount = log(amt) - log(25)
gen bin = 1000 * (0.01 * ceil(logAmount / 0.01))
gen n_all1_D0 = (pub == 0) + 0.1
gen n_all1_D1 = (pub == 1) + 0.1
collapse (sum) n_all1_D0 n_all1_D1, by(bin)

* 3. Run priceFx LOUDLY
display ">>> RUNNING PRICEFX..."
priceFx, bin(bin) n_observed_D0(n_all1_D0) n_observed_D1(n_all1_D1) ///
         p(2) binWidth(10) minB(-750) maxB(750) lB(-200) uB(600) ///
         gammaMin(-0.28) gammaStep(0.001) binFactor(1000) cfDensityName(t_tilde)

* 4. SCAN THE MEMORY
display ""
display "****************************************************"
display "             SCANNING STATA MEMORY"
display "****************************************************"

display ">>> CHECKING R-CLASS (Standard Returns):"
return list

display ""
display ">>> CHECKING E-CLASS (Estimation Returns):"
ereturn list

display ""
display ">>> CHECKING SCALARS (Custom Program Storage):"
scalar list _all
