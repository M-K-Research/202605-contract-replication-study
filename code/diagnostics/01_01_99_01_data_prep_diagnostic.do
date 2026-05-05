use "processed_data/densities.dta", clear
replace bin = round(bin*1000,1)

* 1. Where is the actual peak?
summarize bin if ns_all1_D0 > 0 [aw=ns_all1_D0]
summarize bin if ns_all1_D1 > 0 [aw=ns_all1_D1]

* 2. Look at the bins around the 'Zero Zone'
list bin ns_all1_D0 ns_all1_D1 if bin > -200 & bin < 200
