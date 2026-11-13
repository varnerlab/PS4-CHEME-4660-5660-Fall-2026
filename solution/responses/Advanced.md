# PS4 Advanced responses: worked answers

**Central question:** Does selling option premium pay, and what does
protection cost?

These are the worked answers for the Advanced track. The numbers come from
`results/Report.md`, the report the checker writes for the completed
[Advanced code](../src/Advanced.jl). To get the same numbers, set
[TRACK.txt](../TRACK.txt) to `advanced` and run the checker as described in
the [solution guide](../README.md).

Each question is shown as assigned, followed by its answer. Every return is a
return on capital for one trade of about a month, at mid-price fills. A point
is one percentage point. Your wording can differ. An answer is correct if it
cites the right numbers and gives the same reasoning.

## 1. What does each structure promise?

**a. Predict** (before writing code; accuracy is not graded). Which Standard
structure will have the highest win rate, which the highest average return on
capital, and which side of the short strangle the higher average profit? Why?

**b. What does each wing change?** Adding the call wing turns the short
strangle into the protected strangle; adding the put wing to that gives the
iron condor. By how many percentage points does each wing change the average
`Model POP: market (r, IV)` and `Capital (% of share price)`, and why?

<!-- answer-1:start -->
**a. Example prediction.** I expect the short strangle to have the highest win
rate. The strangle's short strikes are farther from the share price than the
straddle's strikes, so the share price must move farther before the strangle
loses money. The strangle also buys no wings, so it keeps more premium than
the protected strangle or the iron condor. I expect the short straddle to have
the highest average return on capital, because at-the-money options have the
largest premiums. I expect the call side of the short strangle to have the
higher average profit, because share prices tend to fall faster than they
rise, so the short put should have the largest losses.

**b. What each wing changes.** Adding the call wing lowers the market model's
POP from 67.2% to 64.9%, a drop of 2.3 points. Adding the put wing lowers the
POP from 64.9% to 61.7%, a drop of 3.2 points. Each wing costs a premium, so
the structure keeps a smaller credit. With a smaller credit, a smaller move in
the share price turns the profit into a loss, so fewer simulated prices give a
profit.

Adding the call wing raises the capital from 15.9% to 16.4% of the share
price, a rise of 0.5 points. The short put is still naked, so in most trades
the broker still requires the naked put's capital. The capital rises in the
trades where the call spread's maximum loss is larger than the naked put's
capital.

Adding the put wing lowers the capital from 16.4% to 6.4%, a drop of 10.0
points. The iron condor has no naked option, so the broker requires only the
condor's maximum loss.
<!-- answer-1:end -->

## 2. What happened?

**a. Promise versus outcome.** Did each Standard structure's win rate
(`Won`) beat or fall short of the market model's POP? Of the two models that
change only the drift or only the volatility, which came closer to the win
rates, and what does that suggest about the gap?

**b. Winning often versus making money.** For the Standard structure with
the highest win rate, compare its average win and average loss, and use
**Dropping the worst trades** to show how much its average return on
capital changes without its worst trades. Why does a high win rate not
guarantee a high average return on capital?

<!-- answer-2:start -->
**a. Promise versus outcome.** Every Standard structure won more often than
the market model promised. The short straddle won 65.5% of its trades against
a POP of 57.5%. The short strangle won 73.0% against 67.2%, the protected
strangle 70.7% against 64.9%, and the iron condor 69.0% against 61.7%.

The model that changes only the volatility (`r, historical vol`) came closer
to the win rate for all four structures. For the short strangle, the market
model's POP is 67.2% and the win rate is 73.0%. Changing only the volatility
raises the POP to 70.1%. Changing only the drift (`historical drift, IV`)
lowers the POP to 64.7%.

Volatility therefore explains part of the gap. These structures win when the
share price moves little, so a lower volatility gives a higher POP. The
historical volatility gave the higher POP, so on average the implied
volatility at entry was higher than the historical volatility. The option
prices allowed for larger moves than the stocks had made in the year before
entry. Volatility does not explain the whole gap, because 70.1% is still below
73.0%.

**b. Winning often versus making money.** The short strangle had the highest
win rate of the Standard structures, 73.0%. The strangle's average win was
+18.8% and its average loss was −74.5%, so one average loss cancels about four
average wins. Over all 174 trades, the strangle's average return on capital
was −6.4%. Without the worst trade the average is −1.0%, and without the worst
two trades the average is +1.5%. Removing two trades out of 174 turns an
average loss into an average gain. The worst trade was on MRNA: the share
price rose 146.1%, and the strangle lost 939.1% of its capital.

The win rate counts how often a structure makes money, not how much. The most
a short strangle can win is its credit. The strangle's loss grows with every
dollar the share price moves beyond a short strike, so a few large losses can
outweigh many small wins.
<!-- answer-2:end -->

## 3. What can we conclude, and which side made the money?

**a. Answer the central question.** Compare each Standard structure's
average return on capital with the benchmark rows: did selling premium beat
them? How did each wing change the average return and the `Worst trade`? Did
your win-rate and return predictions hold?

**b. Which side?** In **Put side and call side**, which side had the higher
average profit (USD/share) in each split structure? What does that say about
the direction the stocks moved, and did your short-strangle prediction
hold?

**c. Why per trade?** Citing the report, give two reasons why multiplying an
average return per trade by twelve would mislead.

<!-- answer-3:start -->
**a. The central question.** Without protection, selling premium did not pay.
The short straddle averaged −2.3% per trade and the short strangle averaged
−6.4%. Both are below all three benchmarks: cash at +0.3%, SPY at +1.9%, and
the stock itself at +4.6%. With protection, selling premium paid, but it paid
less than buying the stock. The protected strangle averaged +3.8% and the iron
condor averaged +2.1%. Both beat cash and SPY, and neither beat the stock
itself.

The call wing raised the average return from −6.4% to +3.8% and changed the
worst trade from −939.1% to −78.9%. The call wing paid back more than it cost,
because the largest losses came from share prices that rose sharply. The put
wing lowered the average return from +3.8% to +2.1%. For the four Standard
structures, the share price rose in every trade listed in **The worst
trades**, so the put wing had little to protect against, and its premium was
mostly a cost.

The put wing changed the worst trade from −78.9% to −100.0%. The capital a
broker requires for an iron condor is the condor's maximum loss: the wider
spread's strike distance minus the total credit. In the worst trade, the share
price rose above the long call's strike, so the condor lost its maximum loss,
which is all of its capital. The protected strangle lost less than its capital
in the same trade, because the short put's premium offset part of the call
spread's maximum loss.

My win-rate prediction held: the short strangle had the highest win rate of
the Standard structures, 73.0%. My return prediction did not hold. The short
straddle averaged −2.3%, and the protected strangle had the highest average
return of the Standard structures, +3.8%. My prediction counted the premium
the straddle collects and ignored the size of the straddle's losses.

**b. Which side.** The put side had the higher average profit in all three
split structures. In the short strangle, the short put averaged +4.28
USD/share and the short call averaged −3.10. In the protected strangle, the
short put averaged +4.28 and the call credit spread averaged −0.99. In the
iron condor, the put credit spread averaged +2.59 and the call credit spread
averaged −0.99.

The stocks moved up: the stock itself averaged +4.6% per trade. A short put
keeps its whole premium when the share price stays above the put's strike. A
short call loses money when the share price rises above the call's strike by
more than the call's premium. My short-strangle prediction did not hold. I
expected the largest losses on the put side, but in these months the largest
moves in the share price were rises.

**c. Why per trade.** First, a few trades decide the average. The short
strangle averaged −6.4% per trade, which is about −77% when multiplied by
twelve. Without its two worst trades, the strangle averaged +1.5%, which is
+18% when multiplied by twelve. An average that changes sign when two of 174
trades are removed is not a return to expect every month.

Second, all the trades happened between April and October 2026, about six
months in which the stocks rose. The stock itself averaged +4.6% per trade.
The put credit spread gains when the stock rises: on average, a 1% rise in the
stock raises the spread's value by 3.0% of its capital. The spread averaged
+10.3% per trade, which is about 124% when multiplied by twelve. Multiplying
by twelve assumes that every month of a year is like those six months.

Other reasons from the report are also correct. For example, the short
strangle lost more than its capital in 8 trades. After such a loss, the
capital set aside for the trade is gone, so the trade cannot be repeated with
the same capital.
<!-- answer-3:end -->
