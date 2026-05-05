use "processed_data/densities.dta", clear

* 1. Check the range of your data
summarize bin if ns_all1_D0 > 0 | ns_all1_D1 > 0

* 2. Find the bin with the MOST contracts (The Peak)
gsort -ns_all1_D0
list bin ns_all1_D0 in 1/10

* 3. Check the area around the $25k threshold (Bin 0)
count if bin >= -100 & bin <= 100 & (ns_all1_D0 > 0 | ns_all1_D1 > 0)
