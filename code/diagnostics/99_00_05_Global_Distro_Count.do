use "processed_data/densities.dta", clear

* 1. Check the RAW counts (n_) instead of the smooth counts (ns_)
* We sort descending but tell Stata to ignore the missing values
gsort -n_all1_D0

* 2. List the bins with the most UNPUBLICIZED contracts
list bin n_all1_D0 n_all1_D1 if !missing(n_all1_D0) in 1/10

* 3. Check the "Red Zone" (Around the $25k threshold)
* This tells us if anyone is actually playing near the line
count if abs(bin) < 0.1 & (n_all1_D0 > 0 | n_all1_D1 > 0)
