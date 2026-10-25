# PS4 assignment conventions

- Keep the README and response files free of equations, LaTeX commands, and
  math delimiters. Explain the task in plain language and link to the
  mathematical companion. Mathematics goes in
  `docs/PS4-Mathematical-Companion.tex`.
- Organize the assignment around its central question. Each study should state
  what students compare, why it matters, and how it leads to the next study.
  Preserve the agreed Standard and Advanced scope.
- Put mathematical details in `docs/PS4-Mathematical-Companion.tex` and its
  compiled PDF, using the supplied course lecture styling. Render and inspect
  changed slides before delivery. Rebuild with `make -C docs`.
- Keep response templates aligned with the studies. Keep instructor solutions
  and numerical results out of the student release.

- Every student function copies a named cell in a lecture example and uses
  course types. No student data wrangling.
- Default fill is mid. The README states the quotes are Alpaca's indicative
  free-plan feed and never calls them real bid/ask prices. Bid/ask fills
  appear only as a comparison column.
- Headline unit is return on capital per trade (about 1 month), with no
  annualized figures in the report. Benchmarks are rows under the structures:
  the risk-free return, SPY (`benchmark_ticker`), and the stock's own return
  over the same days; plus exposure per 1% stock move.
- Margin rule: naked call = premium + max(0.20*S - max(K - S, 0), 0.10*S);
  naked put = premium + max(0.20*S - max(S - K, 0), 0.10*K); straddle and
  strangle use the larger side; spreads and condor use maximum loss; the
  protected strangle uses max(naked put, call-spread maximum loss).
