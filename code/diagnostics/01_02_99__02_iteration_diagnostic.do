* Check how many contracts are actually in the "Price Effect" window
count if abs(bin) <= 120 & (n_all1_D0 > 0 | n_all1_D1 > 0)

* Check the raw counts in the bunching zone
list bin n_all1_D0 n_all1_D1 if abs(bin) <= 50 & (n_all1_D0 > 0 | n_all1_D1 > 0)
