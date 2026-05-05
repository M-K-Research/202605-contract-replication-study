* 1. Check if the performance data actually merged
tabulate _merge

* 2. Check how many contracts have complexity data vs. how many are empty
count if missing(mean4_overruns_rel)
count if !missing(mean4_overruns_rel)

* 3. See the final distribution of your complexity quartiles
tabulate pc4_complex, missing

* 4. Look at the raw numbers to ensure they make sense
summarize mean4_overruns_rel, detail
