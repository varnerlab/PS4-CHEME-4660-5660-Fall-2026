# PS4 Reference Solution: Does Selling Options Pay?

This archive contains completed code and worked answers for both tracks of
CHEME 4660/5660 Problem Set 4, Fall 2026. Use it to check your calculations,
find your mistakes, and debug your own work. Do not copy it: copying the
reference solution results in a score of 0 for PS4 that revisions cannot
change. See the [rubric](RUBRIC.md) for the full rules. The original
instructions are in [ASSIGNMENT.md](ASSIGNMENT.md).

## Run the solution

The solution uses **Julia 1.12.7** and the same package versions as the
student release.

1. Extract the solution ZIP and open the extracted folder in VS Code. Open a
   terminal in the folder containing [Project.toml](Project.toml).
2. Install the recorded package versions once:

   ```text
   julia --project=. --startup-file=no -e 'using Pkg; Pkg.instantiate()'
   ```

3. Set [TRACK.txt](TRACK.txt) to `standard` or `advanced`, then run the
   [checker](check_submission.jl):

   ```text
   julia --project=. --startup-file=no check_submission.jl
   ```

The archive starts with `standard` selected. Standard passes **24/24** public
checks and Advanced passes **40/40**. To see the other track, change
`TRACK.txt` and run the checker again. The checker prints a summary of the
report and saves the full report in `results/Report.md`.

The checker also prints its usual submission steps. Those steps are for your
own submission. Compare your work with the solution and make your own
revisions before you submit.

## Read the code and answers

| Track | Completed code | Worked answers |
|:--|:--|:--|
| Standard | [src/Standard.jl](src/Standard.jl) | [responses/Standard.md](responses/Standard.md) |
| Advanced | [src/Advanced.jl](src/Advanced.jl) | [responses/Advanced.md](responses/Advanced.md) |

The Advanced file contains the same six functions as the Standard file, plus
the four Advanced builders. The docstrings are unchanged from the assignment,
and the comments in each function explain every step.

| Function | How the solution calculates it |
|:--|:--|
| The four Standard builders and the four Advanced builders | Each builder calls the course `build` function once per leg, with `MyAmericanCallContractModel` for a call and `MyAmericanPutContractModel` for a put. A leg we sell has `sense = -1` and the leg's `sell_price` as its premium. A leg we buy has `sense = 1` and the leg's `buy_price` as its premium. Every leg uses the trade's `DTE`, `copy = 1`, and the leg's own `IV`. |
| `trade_profit` | Call the course `profit` function with the one share price in a vector, then read the total profit from row 1, last column. |
| `probability_of_profit` | Call the course `profit` function with all the simulated share prices, take the total profit from the last column, count the totals above zero, and divide by the number of simulated prices. |

The data, checker, tests, and report code are unchanged from the student
release.

## What the results show

Selling option premium without protection did not pay in this experiment. The
short straddle won 65.5% of its trades and the short strangle won 73.0%, but
both lost money on average, because a few large losses outweighed many small
wins. Buying the call wing capped the largest losses and raised the average
return on capital from −6.4% to +3.8% per trade. Buying the put wing as well
lowered the average return to +2.1% per trade. No structure beat buying the
stock itself, which averaged +4.6% per trade over the same days. The worked
answers give the numbers and explain why an average return per trade should
not be multiplied by twelve.
