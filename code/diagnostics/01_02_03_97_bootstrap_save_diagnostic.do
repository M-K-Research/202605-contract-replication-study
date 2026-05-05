* 1. Load the clean data
use "$BOOT_DATA_PATH", clear

* 2. Run a manual bootstrap draw
set seed 123
bsample 

* 3. Re-bin
gen logAmount = log(amt) - log(25)
gen bin = 1000 * (0.01 * ceil(logAmount / 0.01))

* 4. Count observations in the window (Critical Check)
count if bin >= -200 & bin <= 600

* 5. Collapse
gen n_all1_D0 = (pub == 0) + 0.1
gen n_all1_D1 = (pub == 1) + 0.1
collapse (sum) n_all1_D0 n_all1_D1, by(bin)

* 6. Run priceFx LOUDLY (No capture, no quietly)
priceFx, bin(bin) n_observed_D0(n_all1_D0) n_observed_D1(n_all1_D1) ///
         p(2) binWidth(20) minB(-750) maxB(750) lB(-200) uB(600) ///
         gammaMin(-0.50) gammaMax(0.10) gammaStep(0.01) ///
         binFactor(1000) cfDensityName(t_tilde)

* 7. Check the return scalars
return list
