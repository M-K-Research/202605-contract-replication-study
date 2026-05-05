foreach x in all1 {
    display "--- STARTING DIAGNOSTIC: WIDE SCAN (-50% to 0%) ---"
    
    foreach g in -0.50 -0.40 -0.30 -0.20 -0.10 -0.05 0.0 {
        display "Testing Gamma: `g'..."
        
        * THESE MUST BE ON TWO SEPARATE LINES:
        capture drop loop_tilde*
        gen loop_tilde = .
        
        cfDensities, bin(bin) n_observed_D0(n_`x'_D0) n_observed_D1(n_`x'_D1) ///
                     p(2) binWidth(10) minB(-1500) maxB(1500) ///
                     lB1(-150) uB1(200) lB0(-150) uB0(200) binFactor(1000) ///
                     gammaMean(`g') cfDensity(loop_tilde) ///
                     deltaMin(0) deltaStep(2) deltaMax(1000)
                     
        display "SUCCESS at `g'!"
        
        * Clean up again for the next iteration
        capture drop loop_tilde*
    }
}
