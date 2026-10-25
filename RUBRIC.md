# PS4 grading rules

Your selected track is graded out of **4**. An Advanced score of 4, confirmed
by the teaching team, also earns **one Magic Point**, at most one for PS4.
Select your track in `TRACK.txt`.

| Score | Checks passed | Other requirements |
|:--:|:--|:--|
| 0 | None, or the selected source file cannot load | — |
| 1 | At least one, but no more than half | — |
| 2 | More than half, but fewer than all | — |
| 3 | All | At least one requirement for a 4 (below) is not met |
| 4 | All | Every requirement for a 4 is met |

The checks are the public checks that `check_submission.jl` runs. Standard has
**24 checks**, four for each function. Advanced has **40 checks**: the same 24
plus four for each Advanced builder, so completing only the shared work earns
at most 2. Standard cutoffs are 1–12 checks for score 1 and 13–23 for score 2;
Advanced cutoffs are 1–20 and 21–39. On either track, passing every check
gives a 3 or a 4, depending on the requirements for a 4.

Checks run separately, so an unfinished function does not block the others.
The builder checks use a test trade filled at the bid and ask, so every leg's
sell price differs from its buy price. Failed checks do not cause a Frozen
Zero: a readable ZIP with attempted work by the deadline still qualifies for
revisions.

## Requirements for a 4

- **Builders:** Build each structure's legs from the trade with the course
  `build` function and the American contract types,
  `MyAmericanCallContractModel` and `MyAmericanPutContractModel`. Give each
  sold leg `sense = -1` and its sell price, and each bought leg `sense = 1`
  and its buy price. Use the trade's `DTE`, `copy = 1`, and each leg's
  `IV`. Read strikes and prices from the trade; do not hard-code them.
- **Profit:** Calculate the profit at expiration with the course `profit`
  function and read the total from its last column. Do not grow the
  premiums with interest.
- **Probability of profit:** Count the simulated prices whose total profit is
  strictly positive, and divide by the number of simulated prices. Keep every
  sample in the denominator, and leave the samples unchanged.
- **Advanced:** Build the short put, short call, put credit spread, and call
  credit spread with the same rules, and complete the Advanced copies of the
  six Standard functions.
- **Documentation:** Keep the supplied docstrings. Document each helper's
  purpose, inputs, and output, and comment non-obvious steps. Load helper
  files under `src` through `Include.jl`.
- **Written work:** Answer every lettered part of all three questions in
  the selected response file with the requested numbers, units, and
  reasoning. Include the prediction and its reconsideration. Cite selected
  values rather than reproducing the tables. Use the mid-price results as
  the headline and the bid/ask fills only as a comparison. Distinguish the
  win rate, the average return on capital per trade, and the model
  probability of profit. For Advanced, compare the put side and the call side
  by average profit.
- **Finished work:** Remove completed TODOs and starter errors from the
  selected track's source and response files. Leave the other track unchanged.

We do not require any structure to make money, any model to match the
outcomes, or your prediction to be right. We assess the calculations and your
interpretation.

## How we check submissions

As in PS3, grading copies the selected source and response files, custom
helpers under `src`, `Include.jl`, and `TRACK.txt` into a fresh copy of the
assignment. Edits to any other file, such as the supplied data,
`config/defaults.toml`, the files in `test`, or the checker, are not used.
Helper files must not define functions with the same names as the track
functions or course functions such as `build` and `profit`.

The checker gives feedback; the teaching team assigns the grade. For work
that passes every check, the teaching team assigns 3 or 4 after reading the
documentation and answers.

## Initial submission and revisions

PS4 is released **October 25, 2026**. Submit a readable ZIP with attempted
work by **November 8, 2026 at 11:59 PM ET**. A missing, empty, or unreadable
submission receives a **Frozen Zero** and cannot be revised for credit or
earn a Magic Point. Incomplete attempted work and failed checks qualify
for revisions.

After a qualifying initial submission, revisions are allowed until **December
19, 2026 at 11:59 PM ET**, with no limit on attempts. Use **New Attempt** on
the same Canvas assignment. Revisions have no late penalty, even if Canvas
labels them late. We keep your highest score, even if you change tracks. An
Advanced score of 4 confirmed through a revision also earns the one-time Magic
Point.

## Independent work

You may discuss ideas and use course materials, books, documentation, the
internet, and AI tools. Submit your own work. Do not share code or solutions.

The reference solution will be released after the initial deadline. Use it
to understand errors and debug your work, but do not copy it. Copying it
results in a score of 0 for PS4 that revisions cannot change. These rules
also apply to revisions.
