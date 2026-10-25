# Shared test trade for PS4: one row in the trade-table layout, and the inputs built from it.
# Load after src/Support.jl.
using DataFrames, Dates

# Strike, bid (the sell price), ask (the buy price), implied volatility, and delta of each leg.
const PS4_FIXTURE_LEGS = Dict(
    :atm_call => (K = 100.0, sell = 3.0, buy = 3.2, iv = 0.30, delta = 0.52),
    :atm_put => (K = 100.0, sell = 2.8, buy = 3.0, iv = 0.32, delta = -0.48),
    :short_call => (K = 110.0, sell = 1.0, buy = 1.1, iv = 0.28, delta = 0.25),
    :short_put => (K = 90.0, sell = 1.2, buy = 1.3, iv = 0.35, delta = -0.25),
    :long_call => (K = 120.0, sell = 0.3, buy = 0.4, iv = 0.27, delta = 0.10),
    :long_put => (K = 80.0, sell = 0.4, buy = 0.5, iv = 0.40, delta = -0.10));

PS4_FIXTURE_ROW = DataFrame(trade_id = 0, ticker = "TEST", group = "Test", entry = Date(2026, 5, 1),
    expiration = Date(2026, 5, 31), days = 30, S0 = 100.0, ST = 100.0, atm_iv = 0.31);
for role in PS4_ROLES
    leg = PS4_FIXTURE_LEGS[role];
    PS4_FIXTURE_ROW[!, Symbol(role, "_K")] = [leg.K];
    PS4_FIXTURE_ROW[!, Symbol(role, "_bid")] = [leg.sell];
    PS4_FIXTURE_ROW[!, Symbol(role, "_ask")] = [leg.buy];
    PS4_FIXTURE_ROW[!, Symbol(role, "_mid")] = [(leg.sell + leg.buy) / 2];
    PS4_FIXTURE_ROW[!, Symbol(role, "_iv")] = [leg.iv];
    PS4_FIXTURE_ROW[!, Symbol(role, "_delta")] = [leg.delta];
end
PS4_FIXTURE_ROW[!, :screened] = [0];

# The test trade with distinct sell and buy prices, as the public checks need.
PS4_FIXTURE = trade_inputs(PS4_FIXTURE_ROW[1, :]; fill = "bidask");
