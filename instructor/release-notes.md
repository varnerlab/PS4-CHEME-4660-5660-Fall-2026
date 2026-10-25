# CHEME 5660 Problem Set 4

This is the Fall 2026 student release of PS4: *Does Selling Options Pay?*

Download **Source code (zip)** below, extract it, and begin with `README.md`. The release contains the starter code for both tracks, the option trades and parameters for 29 stocks and funds, the mathematical companion, public tests, response files, the submission checker, an exploration script, and the grading rubric. The reference solutions are not included.

Choose Standard or Advanced in `TRACK.txt`.
* __Standard__ sells four option structures on every trade (a short straddle, a short strangle, a protected strangle, and an iron condor) and compares what a model of the share price promised with what happened at expiration.
* __Advanced__ adds four simpler structures that split the Standard structures into a put side and a call side, and asks which side produced the result.

Write your prediction in Question 1a before you view any results.

Use **Julia 1.12.7** and follow the package setup in the README. `check_submission.jl` checks your code, prints the comparison report, and gives the instructions for building your ZIP.

The initial submission is due on Canvas by **11:59 PM ET on Sunday, November 8, 2026**. Eligible revisions are accepted until **December 19, 2026 at 11:59 PM ET**. An accepted Advanced score of 4 earns one Magic Point.
