# Problem Set 4 (PS4): Does Selling Options Pay?

When you sell an option, the buyer pays you a premium today. If the option
expires worthless, you keep the whole premium. If the option expires in the
money, you pay the buyer the difference between the share price and the
strike, and that payment can be many times the premium. Buying a second option
of the same type, farther from the share price, caps that loss, but its price
comes out of your premium.

These trade-offs lead to the central question of PS4: **Does selling option
premium pay, and what does protection cost?**

You'll replay **174 historical trades**, six on each of 29 stocks and funds,
entered from April to September 2026. A trade is one ticker on one entry date.
On every trade you open four **structures**, sets of options held to
expiration about a month later:

- a [short straddle](https://www.fidelity.com/learning-center/investment-products/options/options-strategy-guide/short-straddle):
  sell an at-the-money call and put;
- a [short strangle](https://www.fidelity.com/learning-center/investment-products/options/options-strategy-guide/short-strangle):
  sell a call and a put farther from the share price;
- a **protected strangle**:
  a short strangle that also buys a call farther out, capping the loss if
  the stock rises;
- an [iron condor](https://www.fidelity.com/learning-center/investment-products/options/options-strategy-guide/short-iron-condor-spread):
  a short strangle that also buys a call and a put farther out, capping the
  loss either way.

For each structure you ask: did it make a profit as often as the option prices
implied, and did its **return on capital** (profit divided by the money a
broker requires you to set aside) beat cash, SPY, and the stock itself over
the same days?

PS4 has two tracks, and you choose one. **Standard** covers the four
structures above. **Advanced** adds four one-sided structures: a
[short put](https://www.fidelity.com/learning-center/investment-products/options/options-strategy-guide/shortput-uncovered),
a [short call](https://www.fidelity.com/learning-center/investment-products/options/options-strategy-guide/shortcall-uncovered),
a [put credit spread](https://www.fidelity.com/learning-center/investment-products/options/options-strategy-guide/bull-put-spread),
and a [call credit spread](https://www.fidelity.com/learning-center/investment-products/options/options-strategy-guide/bear-call-spread)
(Fidelity's bull put and bear call spreads). Together these make up the put
and call sides of the strangles and the condor, so Advanced also asks which
side made or lost the money.

## Course materials and mathematical companion

See the course materials for guidance on payoff and profit at expiration,
American contracts, implied volatility, and the probability of profit. The
[PS4 mathematical companion](docs/PS4-Mathematical-Companion.pdf) gives the
formulas, including the margin rule, which is new in PS4. Each function's
docstring names its companion slide.

## Dates and grading

- **Release:** Sunday, October 25, 2026.
- **Due:** Sunday, November 8, 2026 at 11:59 PM ET. Upload a ZIP of your
  project folder to Canvas.
- **Revisions:** Allowed until December 19, 2026 at 11:59 PM ET if your
  initial submission qualifies (below). We keep your highest score, even if
  you change tracks.
- **Score:** Out of 4 on either track. An Advanced score of 4, confirmed by
  the teaching team, also earns one Magic Point.

Submit a readable ZIP with attempted work by the deadline, even if it is
unfinished. A missing, empty, or unreadable submission receives a **Frozen
Zero** and cannot be revised. See the [grading rubric](RUBRIC.md).

## Getting started

Use Julia `1.12.7`. The trades and prices are supplied.

1. Download the `Source code (zip)` archive from the tagged
   [PS4 GitHub release](https://github.com/varnerlab/PS4-CHEME-4660-5660-Fall-2026/releases/tag/ps4-cheme-4660-5660-2026.1)
   and extract it.
2. In VS Code, open the extracted folder (the one containing
   [Project.toml](Project.toml)) and open a terminal there.
3. Install the packages (needs internet; may take several minutes):

   ```text
   julia --project=. --startup-file=no -e 'using Pkg; Pkg.instantiate()'
   ```

4. Set [TRACK.txt](TRACK.txt) to exactly `standard` or `advanced`:

   | Track | Code to complete | Questions to answer |
   |:--|:--|:--|
   | Standard | Six functions in [src/Standard.jl](src/Standard.jl): `trade_profit`, `probability_of_profit`, and a builder for each structure | [responses/Standard.md](responses/Standard.md) |
   | Advanced | All ten functions in [src/Advanced.jl](src/Advanced.jl): the same six plus a builder for each Advanced structure | [responses/Advanced.md](responses/Advanced.md) |
5. Before you write any code, answer Question 1a, your prediction.
6. Complete the functions as the sections below describe. Replace each
   `error("Complete ...")` with your calculation, following the TODO hint
   above it, then delete the TODO. Don't change the supplied signatures,
   docstrings, or return statements; some checks verify them.
7. Save your code and run the checker:

   ```text
   julia --project=. --startup-file=no check_submission.jl
   ```

   The checker runs the 24 Standard or 40 Advanced graded checks, then runs
   your functions on every trade and writes `results/Report.md`. Unfinished
   calculations show `UNAVAILABLE`. Run it as you work; the first run is slow.

Edit only `TRACK.txt`, your track's source and response files, `Include.jl`,
helper files you add, and `config/explore.toml`. Put helper functions in `.jl`
files under [src](src), load them from [Include.jl](Include.jl), and document
each one.

## Trades and data

### The trades

The trades come from the course options archive of end-of-day option quotes,
April 13 to October 16, 2026, on 29 tickers: AAPL, ABBV, AMD, AMGN, AVGO, BAC,
BMY, CVX, GOOG, GS, INTC, JNJ, JPM, LLY, MRNA, MSFT, MU, NVDA, OXY, PFE, QCOM,
QQQ, SPY, TGT, UNH, UPS, WFC, WMT, and XOM.

Each trade uses the expiration closest to 30 calendar days away (25 to 35) and
is held to it. The next trade on the ticker starts at that expiration, so
trades never overlap.

Each trade supplies six options, called legs, at three distances from the
entry share price:

- `atm_call`, `atm_put`: the **at-the-money** call and put, at the strike
  nearest the share price.
- `short_call`, `short_put`: the out-of-the-money call and put with delta
  nearest 0.25 in absolute value.
- `long_call`, `long_put`: the **wings**, a call and a put with delta
  nearest 0.10 in absolute value, farther out still, bought as protection.

Each leg holds its strike `K`, its implied volatility `IV`, and the prices at
which you sell it (`sell_price`) or buy it (`buy_price`). A structure's
**credit** is the premiums it receives minus the premiums it pays.

| Track | Structure | You sell | You buy |
|:--|:--|:--|:--|
| Both | Short straddle | `atm_call`, `atm_put` | nothing |
| Both | Short strangle | `short_call`, `short_put` | nothing |
| Both | Protected strangle | `short_call`, `short_put` | `long_call` |
| Both | Iron condor | `short_call`, `short_put` | `long_call`, `long_put` |
| Advanced | Short put | `short_put` | nothing |
| Advanced | Short call | `short_call` | nothing |
| Advanced | Put credit spread | `short_put` | `long_put` |
| Advanced | Call credit spread | `short_call` | `long_call` |

The [data notes](data/README.md) give the full selection rules.

### Prices and fills

The quotes come from the broker Alpaca's free-plan **indicative** feed, which
approximates the exchange quotes. Graded results fill each leg at its **mid
price**, halfway between the quoted bid and ask, so `sell_price` and
`buy_price` are equal.

The report's **Fill prices and dollars** table adds a comparison that sells at
the bid and buys at the ask; its gap from the mid-price results is a rough
cost of trading if real spreads were as wide as the quoted ones.

### Simplifications and benchmarks

- One contract per leg; every amount is in USD per share.
- Every trade is held to expiration and settled at the stock's closing price
  on the expiration date.
- The contracts are American, but PS4 assumes no early exercise and
  therefore no early assignment.
- No commissions, dividends, taxes, or interest on premiums.

The benchmarks cover each trade's days. **SPY** and **the stock** are bought
at the entry close and sold at the expiration close. **Cash** earns **3.76%
per year** (prorated), the mean 13-week Treasury bill rate from April 13 to
August 24, 2026 (`risk_free_rate` in
[config/defaults.toml](config/defaults.toml)).

### Return on capital

The report uses **return on capital**: the profit at expiration divided by the
capital a broker requires at entry. The capital follows a standard broker
margin rule:

- **Naked short option** (no protection): its premium plus a cushion. For a
  call, the cushion is 20% of the share price minus how far the strike is
  above it, but at least 10% of the share price. For a put, it is 20% of the
  share price minus how far the strike is below it, but at least 10% of the
  strike.
- **Straddle and strangle:** the larger of the call's and the put's capital,
  since only one side can lose.
- **Credit spread:** its maximum loss, the distance between its strikes minus
  its credit.
- **Iron condor:** the wider spread's strike distance minus the total credit.
- **Protected strangle:** the larger of the naked put's capital and the call
  spread's maximum loss.

A naked option can lose more than its capital, a return below −100%; PS4
ignores margin calls. The iron condor and credit spreads can lose at most
their capital. Companion slide 9 gives the formulas.

**A worked example** (the checks' made-up test trade, at mid prices). The
stock is at 100 USD/share with 30 days to expiration. The short strangle sells
the 110 USD `short_call` for 1.05 and the 90 USD `short_put` for 1.25, a
credit of 2.30 USD/share.

- **Call side:** 20% of 100 is 20; minus the 10 by which the 110 strike is
  above 100, the cushion is 10, equal to the 10% floor. Plus the 1.05 premium:
  11.05.
- **Put side:** 20 minus the 10 by which the 90 strike is below 100 is 10,
  above the floor of 9 (10% of the strike). Plus the 1.25 premium: 11.25.
- **Capital:** the larger, 11.25 USD/share, or 11.25% of the share price.

Its results at three closing prices:

| Close on the expiration date (USD/share) | Stock's own return | Profit (USD/share) | Return on capital |
|--:|--:|--:|--:|
| 100 | 0% | +2.30 | +20.4% |
| 115 | +15% | −2.70 | −24.0% |
| 130 | +30% | −17.70 | −157.3% |

Because the capital is a fraction of the share price, returns on capital swing
far more than the stock does.

Every average in the report weights each trade equally.

## Study 1: What does each structure promise?

At entry, each structure promises a credit and a probability of profit implied
by the option prices. This study builds the structures, computes that
probability, and shows how each bought leg changes that probability and the
capital.

1. **Complete the four builders.** `build_short_straddle`,
   `build_short_strangle`, `build_protected_strangle`, and `build_iron_condor`
   build each leg with the course `build` function and the American contract
   types, `MyAmericanCallContractModel` and `MyAmericanPutContractModel`. A
   sold leg has `sense = -1` and its `sell_price` as its premium; a bought leg
   has `sense = 1` and its `buy_price`. Every leg uses the trade's `DTE`, the
   time to expiration in years (days / 365), `copy = 1` (one contract), and
   its own `IV`.
2. **Complete `probability_of_profit`.** Given a structure's legs and 10,000
   simulated share prices at expiration, compute the profit at every price
   with the course `profit` function (total in its last column; leave out the
   optional `𝒟`) and return the share of prices with a profit above zero.
3. **Read the promise.** Run the checker. In `results/Report.md`, the table
   **Probability of profit: four models and what happened** shows each
   structure's average probability of profit (POP) under four models of the
   share price. Its `Won` column fills in after Study 2.

   | Report column | Drift of the share price | Volatility |
   |:--|:--|:--|
   | `Model POP: market (r, IV)` | the risk-free rate r | the average implied volatility of the trade's at-the-money call and put |
   | `Model POP: historical drift, IV` | the stock's historical drift | the same at-the-money implied volatility |
   | `Model POP: r, historical vol` | the risk-free rate r | the stock's historical volatility |
   | `Model POP: historical drift and vol` | the stock's historical drift | the stock's historical volatility |

   All four are geometric Brownian motion models. The **market** model uses
   the same inputs as option pricing, so its POP is the promise. Historical
   values come from the 252 daily price changes before entry. The simulation
   is supplied (companion slide 12).
4. **Answer Question 1b.** Capital is in the report's **Wins, losses, and
   capital** table; single trades are in `results/outcomes.csv`.

## Study 2: What happened?

A structure **wins** a trade when its profit at expiration is above zero; its
**win rate** (`Won`) is the share of trades it won. This study compares the
promise with what happened.

1. **Complete `trade_profit`.** Given a structure's legs and the closing price
   at expiration, return the total profit from the course `profit` function.
2. **Read the report.** Rerun the checker, then read these tables in
   `results/Report.md`:
   - **Probability of profit: four models and what happened**, now with the
     win rate. `historical drift, IV` changes only the market model's drift;
     `r, historical vol` changes only its volatility. The one closer to the
     win rate hints at which input explains the gap between the win rate and
     the market model's POP.
   - **Return on capital and benchmarks**: average and median return on
     capital, with the benchmarks as rows below.
   - **Wins, losses, and capital**: capital, average win and loss, worst
     trade, trades that lost more than their capital, and the change in value
     per 1% stock rise (companion slide 15).
   - **The worst trades** lists each structure's two worst trades, and
     **Dropping the worst trades** gives its average return on capital without
     its worst one to five trades.
3. **Answer Question 2.**

Keep three things distinct: the market model's POP (the promise), the win rate
(how often it won), and the average return on capital (how much it made).

## Study 3: What can we conclude?

Answer Question 3: compare the structures with the benchmarks and with each
other, and explain why the report gives returns per trade, never per year.
Standard students write no more code; Advanced students first complete the
section below.

## Advanced: The put side and the call side

Splitting the strangles and the condor into their put and call sides shows
which side made or lost the money.

1. **Complete the four Advanced builders.** `build_short_put`,
   `build_short_call`, `build_put_credit_spread`, and
   `build_call_credit_spread` follow the same rules as the Standard builders.
2. **Read the split.** Rerun the checker and read **Put side and call side**.
   Profits add (put side + call side = whole structure) but returns on capital
   do not, so compare the sides by average profit.
3. **Answer Question 3.**

## Explore on your own (optional)

You can rerun the experiment with your own settings. It does not affect your
grade.

1. Finish your functions first.
2. Edit [config/explore.toml](config/explore.toml). For example, set
   `fill = "bidask"` to sell at the bid and buy at the ask, or raise
   `short_delta` or `wing_delta` to move those legs closer to the share
   price.
3. Run the exploration script:

   ```text
   julia --project=. --startup-file=no explore.jl
   ```

   The first run downloads the 112 MB options archive.
4. Read `results/exploration/Exploration.md`.

Grading never uses your exploration settings. Do not edit
`config/defaults.toml`.

## Check and submit your work

1. Save your code and answers, then run the checker again:

   ```text
   julia --project=. --startup-file=no check_submission.jl
   ```

      It flags unanswered questions and writes `MANIFEST.txt`.
2. ZIP the whole project folder as `CHEME-5660-PS4-<your netid>.zip`.
3. Upload the ZIP to the PS4 assignment on Canvas.

You are graded on correct calculations and interpretation, not on which
structure does best. A 3 or 4 requires passing every check; the teaching team
then reviews your code and answers. See the [rubric](RUBRIC.md).
