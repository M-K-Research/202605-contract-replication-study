* Re-generate the polynomial terms for the p=3 model
forvalues z = 1/3 {
    capture gen double b_`z' = bin^`z'
}

* Re-generate the round-number dummies (multiples of 1, 5, 10K)
foreach rnum of numlist 1000 5000 10000 {
    capture gen rnum`rnum' = 0
    forvalues r = 1/100 {
        local rnum_i = `rnum'*`r'
        local logRnum = log(`rnum_i') - log(25000)
        local rnumBin = 0.01*ceil(`logRnum'/0.01)
        replace rnum`rnum' = 1 if abs(bin - `rnumBin'*1000) < 1e-5
    }
}

foreach d in 0 1 {
    display " "
    display "--- Checking Stability for Group D = `d' ---"
    
    quietly summarize n_all1_D`d' if abs(bin) <= 120
    display "Mean contracts in window for D`d': " r(mean)
    
    * Check the fit using the same controls as the price search
    quietly reg n_all1_D`d' b_* rnum1000 rnum5000 rnum10000 if abs(bin) <= 750
    display "R-Squared for Group D`d' fit: " e(r2)
    
    * Check for 'Empty Bins' which make the bootstrap unstable
    quietly count if n_all1_D`d' == 0 & abs(bin) <= 120
    display "Number of empty bins in the +/- 12% window: " r(N)
}
