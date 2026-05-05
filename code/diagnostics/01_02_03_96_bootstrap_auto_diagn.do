* ==============================================================================
* LOUD DIAGNOSTIC: 5 Replications | No-Quiet | Error Exposure
* ==============================================================================

* 1. ENSURE WE ARE IN THE RIGHT PLACE
cd "C:/Users/Public/StataWork"

capture program drop run_bunching_diagnostic
program define run_bunching_diagnostic, rclass
    * A. Reload data (No preserve, fresh use)
    use "clean_input.dta", clear
    bsample 
    
    * B. Re-bin
    gen logAmount = log(amt) - log(25)
    gen bin = 1000 * (0.01 * ceil(logAmount / 0.01))
    
    * C. Collapse
    gen n_all1_D0 = (pub == 0) + 0.1
    gen n_all1_D1 = (pub == 1) + 0.1
    collapse (sum) n_all1_D0 n_all1_D1, by(bin)
    
    * D. Run priceFx LOUDLY 
    * We use the ONE starting value we know worked (-0.28)
    capture drop t_tilde*
    priceFx, bin(bin) n_observed_D0(n_all1_D0) n_observed_D1(n_all1_D1) ///
             p(2) binWidth(10) minB(-750) maxB(750) lB(-200) uB(600) ///
             gammaMin(-0.28) gammaStep(0.001) binFactor(1000) cfDensityName(t_tilde)
    
    * E. Capture results
    return scalar gamma = cond(r(gamma_best) != ., r(gamma_best), r(gamma))
    return scalar M_val = r(M)
end

* 2. EXECUTE 5 REPS AND PRINT EVERYTHING
* ------------------------------------------------------------------------------
forvalues r = 1/5 {
    display ""
    display "****************************************************"
    display "   STARTING DIAGNOSTIC REP `r' AT $S_TIME"
    display "****************************************************"
    
    run_bunching_diagnostic
    
    display ""
    display ">>> REP `r' RESULTS:"
    display "    Gamma: " r(gamma)
    display "    M:     " r(M_val)
    
    * This tells us exactly what priceFx leaves behind in memory
    return list
}
