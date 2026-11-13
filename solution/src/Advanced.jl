# PS4 Advanced Track - Reference Solution
#
# The report calls these ten functions for every trade and every structure.
# The first six are the same as the Standard functions.
#
# - build_short_straddle, build_short_strangle, build_protected_strangle, and
#   build_iron_condor: the contract models (legs) of each Standard structure.
# - trade_profit: the total profit at expiration for one share price.
# - probability_of_profit: the fraction of simulated share prices at
#   expiration where the total profit is positive.
# - build_short_put, build_short_call, build_put_credit_spread, and
#   build_call_credit_spread: the legs of each Advanced structure. These four
#   structures are the put sides and the call sides of the strangles and the
#   iron condor.
#
# Every builder uses the course build function once per leg. A leg we sell has
# sense = -1 and its sell_price as the premium. A leg we buy has sense = 1 and
# its buy_price as the premium.
#
# The docstrings are unchanged from the assignment. To run the checks and the
# report, open a terminal in the PS4 folder and run:
# julia --project=. --startup-file=no check_submission.jl

"""
    build_short_straddle(trade::NamedTuple) -> Vector{AbstractContractModel}

Build the short straddle for one trade: sell the at-the-money call and the
at-the-money put.

### Arguments

- `trade`: One trade from the supplied trade table. `trade.DTE` is the time to
  expiration (years). Each leg, such as `trade.atm_call`, holds its strike `K`
  (USD/share), implied volatility `IV` (decimal), `sell_price` (USD/share),
  and `buy_price` (USD/share).

### Returns

- `contracts`: Two contract models, a short call on `trade.atm_call` and a
  short put on `trade.atm_put`, in either order.

### Method

Build each leg with the course `build` function. A short leg has
`sense = -1`, and its premium is the leg's `sell_price`. Every leg has
`DTE = trade.DTE`, `copy = 1`, and the leg's own `IV`.

### Course references

- See the course materials for guidance on building call and put contract
  models and their profit at expiration.
- PS4 companion: slide 4, 'Building a structure from legs'.
"""
function build_short_straddle(trade::NamedTuple)::Vector{AbstractContractModel}

    # Initialize: the two legs this structure sells -
    call_leg = trade.atm_call; # (K, IV, sell_price, buy_price)
    put_leg = trade.atm_put;

    # Build the short call -
    # We sell this leg, so sense = -1 and the premium is the leg's sell_price.
    call_short = build(MyAmericanCallContractModel, (
        K = call_leg.K, # strike price (USD/share)
        premium = call_leg.sell_price, # premium we receive (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = -1, # short contract
        copy = 1, # one contract
        IV = call_leg.IV # implied volatility (decimal)
    ));

    # Build the short put -
    # We sell this leg, so sense = -1 and the premium is the leg's sell_price.
    put_short = build(MyAmericanPutContractModel, (
        K = put_leg.K, # strike price (USD/share)
        premium = put_leg.sell_price, # premium we receive (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = -1, # short contract
        copy = 1, # one contract
        IV = put_leg.IV # implied volatility (decimal)
    ));

    # Return the contracts in a vector -
    return [call_short, put_short];
end

"""
    build_short_strangle(trade::NamedTuple) -> Vector{AbstractContractModel}

Build the short strangle for one trade: sell the out-of-the-money call and the
out-of-the-money put at the short strikes.

### Arguments

- `trade`: One trade from the supplied trade table. `trade.DTE` is the time to
  expiration (years). Each leg, such as `trade.short_call`, holds its strike
  `K` (USD/share), implied volatility `IV` (decimal), `sell_price`
  (USD/share), and `buy_price` (USD/share).

### Returns

- `contracts`: Two contract models, a short call on `trade.short_call` and a
  short put on `trade.short_put`, in either order.

### Method

Build each leg with the course `build` function. A short leg has
`sense = -1`, and its premium is the leg's `sell_price`. Every leg has
`DTE = trade.DTE`, `copy = 1`, and the leg's own `IV`.

### Course references

- See the course materials for guidance on building call and put contract
  models and their profit at expiration.
- PS4 companion: slide 4, 'Building a structure from legs'.
"""
function build_short_strangle(trade::NamedTuple)::Vector{AbstractContractModel}

    # Initialize: the two legs this structure sells -
    call_leg = trade.short_call; # (K, IV, sell_price, buy_price)
    put_leg = trade.short_put;

    # Build the short call -
    # We sell this leg, so sense = -1 and the premium is the leg's sell_price.
    call_short = build(MyAmericanCallContractModel, (
        K = call_leg.K, # strike price (USD/share)
        premium = call_leg.sell_price, # premium we receive (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = -1, # short contract
        copy = 1, # one contract
        IV = call_leg.IV # implied volatility (decimal)
    ));

    # Build the short put -
    # We sell this leg, so sense = -1 and the premium is the leg's sell_price.
    put_short = build(MyAmericanPutContractModel, (
        K = put_leg.K, # strike price (USD/share)
        premium = put_leg.sell_price, # premium we receive (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = -1, # short contract
        copy = 1, # one contract
        IV = put_leg.IV # implied volatility (decimal)
    ));

    # Return the contracts in a vector -
    return [call_short, put_short];
end

"""
    build_protected_strangle(trade::NamedTuple) -> Vector{AbstractContractModel}

Build the protected strangle for one trade: the short strangle plus a long
call above the short call.

### Arguments

- `trade`: One trade from the supplied trade table. `trade.DTE` is the time to
  expiration (years). Each leg, such as `trade.long_call`, holds its strike
  `K` (USD/share), implied volatility `IV` (decimal), `sell_price`
  (USD/share), and `buy_price` (USD/share).

### Returns

- `contracts`: Three contract models, in any order: a short call on
  `trade.short_call`, a short put on `trade.short_put`, and a long call on
  `trade.long_call`.

### Method

Build each leg with the course `build` function. A short leg has
`sense = -1`, and its premium is the leg's `sell_price`. A long leg has
`sense = 1`, and its premium is the leg's `buy_price`. Every leg has
`DTE = trade.DTE`, `copy = 1`, and the leg's own `IV`.

### Course references

- See the course materials for guidance on building call and put contract
  models and their profit at expiration.
- PS4 companion: slide 4, 'Building a structure from legs'.
"""
function build_protected_strangle(trade::NamedTuple)::Vector{AbstractContractModel}

    # Initialize: two legs this structure sells and one it buys -
    call_leg = trade.short_call; # (K, IV, sell_price, buy_price)
    put_leg = trade.short_put;
    wing_leg = trade.long_call;

    # Build the short call -
    # We sell this leg, so sense = -1 and the premium is the leg's sell_price.
    call_short = build(MyAmericanCallContractModel, (
        K = call_leg.K, # strike price (USD/share)
        premium = call_leg.sell_price, # premium we receive (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = -1, # short contract
        copy = 1, # one contract
        IV = call_leg.IV # implied volatility (decimal)
    ));

    # Build the short put -
    # We sell this leg, so sense = -1 and the premium is the leg's sell_price.
    put_short = build(MyAmericanPutContractModel, (
        K = put_leg.K, # strike price (USD/share)
        premium = put_leg.sell_price, # premium we receive (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = -1, # short contract
        copy = 1, # one contract
        IV = put_leg.IV # implied volatility (decimal)
    ));

    # Build the long call -
    # We buy this leg, so sense = 1 and the premium is the leg's buy_price.
    call_long = build(MyAmericanCallContractModel, (
        K = wing_leg.K, # strike price (USD/share)
        premium = wing_leg.buy_price, # premium we pay (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = 1, # long contract
        copy = 1, # one contract
        IV = wing_leg.IV # implied volatility (decimal)
    ));

    # Return the contracts in a vector -
    return [call_short, put_short, call_long];
end

"""
    build_iron_condor(trade::NamedTuple) -> Vector{AbstractContractModel}

Build the iron condor for one trade: the short strangle plus a long call above
the short call and a long put below the short put.

### Arguments

- `trade`: One trade from the supplied trade table. `trade.DTE` is the time to
  expiration (years). Each leg, such as `trade.long_put`, holds its strike `K`
  (USD/share), implied volatility `IV` (decimal), `sell_price` (USD/share),
  and `buy_price` (USD/share).

### Returns

- `contracts`: Four contract models, in any order: a short call on
  `trade.short_call`, a short put on `trade.short_put`, a long call on
  `trade.long_call`, and a long put on `trade.long_put`.

### Method

Build each leg with the course `build` function. A short leg has
`sense = -1`, and its premium is the leg's `sell_price`. A long leg has
`sense = 1`, and its premium is the leg's `buy_price`. Every leg has
`DTE = trade.DTE`, `copy = 1`, and the leg's own `IV`.

### Course references

- See the course materials for guidance on building call and put contract
  models and their profit at expiration.
- PS4 companion: slide 4, 'Building a structure from legs'.
"""
function build_iron_condor(trade::NamedTuple)::Vector{AbstractContractModel}

    # Initialize: two legs this structure sells and two it buys -
    call_leg = trade.short_call; # (K, IV, sell_price, buy_price)
    put_leg = trade.short_put;
    call_wing = trade.long_call;
    put_wing = trade.long_put;

    # Build the short call -
    # We sell this leg, so sense = -1 and the premium is the leg's sell_price.
    call_short = build(MyAmericanCallContractModel, (
        K = call_leg.K, # strike price (USD/share)
        premium = call_leg.sell_price, # premium we receive (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = -1, # short contract
        copy = 1, # one contract
        IV = call_leg.IV # implied volatility (decimal)
    ));

    # Build the short put -
    # We sell this leg, so sense = -1 and the premium is the leg's sell_price.
    put_short = build(MyAmericanPutContractModel, (
        K = put_leg.K, # strike price (USD/share)
        premium = put_leg.sell_price, # premium we receive (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = -1, # short contract
        copy = 1, # one contract
        IV = put_leg.IV # implied volatility (decimal)
    ));

    # Build the long call -
    # We buy this leg, so sense = 1 and the premium is the leg's buy_price.
    call_long = build(MyAmericanCallContractModel, (
        K = call_wing.K, # strike price (USD/share)
        premium = call_wing.buy_price, # premium we pay (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = 1, # long contract
        copy = 1, # one contract
        IV = call_wing.IV # implied volatility (decimal)
    ));

    # Build the long put -
    # We buy this leg, so sense = 1 and the premium is the leg's buy_price.
    put_long = build(MyAmericanPutContractModel, (
        K = put_wing.K, # strike price (USD/share)
        premium = put_wing.buy_price, # premium we pay (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = 1, # long contract
        copy = 1, # one contract
        IV = put_wing.IV # implied volatility (decimal)
    ));

    # Return the contracts in a vector -
    return [call_short, put_short, call_long, put_long];
end

"""
    trade_profit(contracts::Vector{<:AbstractContractModel}, S_T::Float64) -> Float64

Compute the profit at expiration of a structure for one share price.

### Arguments

- `contracts`: The structure's contract models, from one of the builders.
- `S_T`: Share price at expiration (USD/share).

### Returns

- `value`: Total profit of all the contracts at `S_T` (USD/share).

### Method

Call the course `profit` function with the one share price `S_T`. Its result
has one row per share price; the last column is the total over the
contracts. Leave `𝒟` at its default, so premiums are not grown to their
future value.

### Course references

- See the course materials for guidance on profit at expiration.
- PS4 companion: slide 6, 'Profit at expiration'.
"""
function trade_profit(contracts::Vector{<:AbstractContractModel}, S_T::Float64)::Float64

    # Compute the profit table at the one share price S_T -
    # profit(...) takes a vector of share prices, so we pass [S_T]. The table
    # has one row. Its columns are the share price, the profit of each
    # contract, and the total profit.
    profit_array = profit(contracts, [S_T]);

    # Read the total profit: row 1, last column -
    value = profit_array[1, end];

    return value;
end

"""
    probability_of_profit(contracts::Vector{<:AbstractContractModel},
        endpoint_samples::Vector{Float64}) -> Float64

Estimate a structure's probability of profit from simulated share prices at
expiration.

### Arguments

- `contracts`: The structure's contract models, from one of the builders.
- `endpoint_samples`: Simulated share prices at expiration (USD/share).

### Returns

- `POP`: The fraction of samples where the total profit is positive, from 0
  to 1.

### Method

Compute the total profit at every sample with the course `profit` function,
then count the samples where it is greater than zero and divide by the number
of samples. A sample with exactly zero profit is not a win. Count positive
total profits rather than prices beyond one breakeven, because a structure
can have two breakevens.

### Course references

- See the course materials for guidance on the probability of profit.
- PS4 companion: slide 11, 'Probability of profit by counting'.
"""
function probability_of_profit(contracts::Vector{<:AbstractContractModel},
    endpoint_samples::Vector{Float64})::Float64

    # Initialize -
    number_of_samples = length(endpoint_samples);

    # Compute the total profit at every sample -
    # The profit table has one row per sample. Its last column is the total
    # profit of the contracts.
    profit_array = profit(contracts, endpoint_samples);
    total_profit = profit_array[:, end];

    # Count the samples with a positive total profit and divide by the number of samples -
    # total_profit .> 0.0 is true for each sample with a profit above zero, and
    # count(...) counts the true entries. A profit of exactly zero is not a win.
    POP = count(total_profit .> 0.0)/number_of_samples;

    return POP;
end

"""
    build_short_put(trade::NamedTuple) -> Vector{AbstractContractModel}

Build the short put for one trade: sell the out-of-the-money put at the short
put strike.

### Arguments

- `trade`: One trade from the supplied trade table. `trade.DTE` is the time to
  expiration (years). Each leg, such as `trade.short_put`, holds its strike
  `K` (USD/share), implied volatility `IV` (decimal), `sell_price`
  (USD/share), and `buy_price` (USD/share).

### Returns

- `contracts`: One contract model, a short put on `trade.short_put`, in a
  vector.

### Method

Build the leg with the course `build` function. A short leg has
`sense = -1`, and its premium is the leg's `sell_price`. Set
`DTE = trade.DTE`, `copy = 1`, and the leg's `IV`.

### Course references

- See the course materials for guidance on building call and put contract
  models and their profit at expiration.
- PS4 companion: slide 4, 'Building a structure from legs'.
"""
function build_short_put(trade::NamedTuple)::Vector{AbstractContractModel}

    # Initialize: the one leg this structure sells -
    put_leg = trade.short_put; # (K, IV, sell_price, buy_price)

    # Build the short put -
    # We sell this leg, so sense = -1 and the premium is the leg's sell_price.
    put_short = build(MyAmericanPutContractModel, (
        K = put_leg.K, # strike price (USD/share)
        premium = put_leg.sell_price, # premium we receive (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = -1, # short contract
        copy = 1, # one contract
        IV = put_leg.IV # implied volatility (decimal)
    ));

    # Return the contracts in a vector -
    return [put_short];
end

"""
    build_short_call(trade::NamedTuple) -> Vector{AbstractContractModel}

Build the short call for one trade: sell the out-of-the-money call at the
short call strike.

### Arguments

- `trade`: One trade from the supplied trade table. `trade.DTE` is the time to
  expiration (years). Each leg, such as `trade.short_call`, holds its strike
  `K` (USD/share), implied volatility `IV` (decimal), `sell_price`
  (USD/share), and `buy_price` (USD/share).

### Returns

- `contracts`: One contract model, a short call on `trade.short_call`, in a
  vector.

### Method

Build the leg with the course `build` function. A short leg has
`sense = -1`, and its premium is the leg's `sell_price`. Set
`DTE = trade.DTE`, `copy = 1`, and the leg's `IV`.

### Course references

- See the course materials for guidance on building call and put contract
  models and their profit at expiration.
- PS4 companion: slide 4, 'Building a structure from legs'.
"""
function build_short_call(trade::NamedTuple)::Vector{AbstractContractModel}

    # Initialize: the one leg this structure sells -
    call_leg = trade.short_call; # (K, IV, sell_price, buy_price)

    # Build the short call -
    # We sell this leg, so sense = -1 and the premium is the leg's sell_price.
    call_short = build(MyAmericanCallContractModel, (
        K = call_leg.K, # strike price (USD/share)
        premium = call_leg.sell_price, # premium we receive (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = -1, # short contract
        copy = 1, # one contract
        IV = call_leg.IV # implied volatility (decimal)
    ));

    # Return the contracts in a vector -
    return [call_short];
end

"""
    build_put_credit_spread(trade::NamedTuple) -> Vector{AbstractContractModel}

Build the put credit spread for one trade: sell the put at the short put
strike and buy the put at the lower wing strike.

### Arguments

- `trade`: One trade from the supplied trade table. `trade.DTE` is the time to
  expiration (years). Each leg, such as `trade.long_put`, holds its strike `K`
  (USD/share), implied volatility `IV` (decimal), `sell_price` (USD/share),
  and `buy_price` (USD/share).

### Returns

- `contracts`: Two contract models, a short put on `trade.short_put` and a
  long put on `trade.long_put`, in either order.

### Method

Build each leg with the course `build` function. A short leg has
`sense = -1`, and its premium is the leg's `sell_price`. A long leg has
`sense = 1`, and its premium is the leg's `buy_price`. Every leg has
`DTE = trade.DTE`, `copy = 1`, and the leg's own `IV`.

### Course references

- See the course materials for guidance on building call and put contract
  models and their profit at expiration.
- PS4 companion: slide 4, 'Building a structure from legs'.
"""
function build_put_credit_spread(trade::NamedTuple)::Vector{AbstractContractModel}

    # Initialize: one leg this structure sells and one it buys -
    put_leg = trade.short_put; # (K, IV, sell_price, buy_price)
    put_wing = trade.long_put;

    # Build the short put -
    # We sell this leg, so sense = -1 and the premium is the leg's sell_price.
    put_short = build(MyAmericanPutContractModel, (
        K = put_leg.K, # strike price (USD/share)
        premium = put_leg.sell_price, # premium we receive (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = -1, # short contract
        copy = 1, # one contract
        IV = put_leg.IV # implied volatility (decimal)
    ));

    # Build the long put -
    # We buy this leg, so sense = 1 and the premium is the leg's buy_price.
    put_long = build(MyAmericanPutContractModel, (
        K = put_wing.K, # strike price (USD/share)
        premium = put_wing.buy_price, # premium we pay (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = 1, # long contract
        copy = 1, # one contract
        IV = put_wing.IV # implied volatility (decimal)
    ));

    # Return the contracts in a vector -
    return [put_short, put_long];
end

"""
    build_call_credit_spread(trade::NamedTuple) -> Vector{AbstractContractModel}

Build the call credit spread for one trade: sell the call at the short call
strike and buy the call at the higher wing strike.

### Arguments

- `trade`: One trade from the supplied trade table. `trade.DTE` is the time to
  expiration (years). Each leg, such as `trade.long_call`, holds its strike
  `K` (USD/share), implied volatility `IV` (decimal), `sell_price`
  (USD/share), and `buy_price` (USD/share).

### Returns

- `contracts`: Two contract models, a short call on `trade.short_call` and a
  long call on `trade.long_call`, in either order.

### Method

Build each leg with the course `build` function. A short leg has
`sense = -1`, and its premium is the leg's `sell_price`. A long leg has
`sense = 1`, and its premium is the leg's `buy_price`. Every leg has
`DTE = trade.DTE`, `copy = 1`, and the leg's own `IV`.

### Course references

- See the course materials for guidance on building call and put contract
  models and their profit at expiration.
- PS4 companion: slide 4, 'Building a structure from legs'.
"""
function build_call_credit_spread(trade::NamedTuple)::Vector{AbstractContractModel}

    # Initialize: one leg this structure sells and one it buys -
    call_leg = trade.short_call; # (K, IV, sell_price, buy_price)
    call_wing = trade.long_call;

    # Build the short call -
    # We sell this leg, so sense = -1 and the premium is the leg's sell_price.
    call_short = build(MyAmericanCallContractModel, (
        K = call_leg.K, # strike price (USD/share)
        premium = call_leg.sell_price, # premium we receive (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = -1, # short contract
        copy = 1, # one contract
        IV = call_leg.IV # implied volatility (decimal)
    ));

    # Build the long call -
    # We buy this leg, so sense = 1 and the premium is the leg's buy_price.
    call_long = build(MyAmericanCallContractModel, (
        K = call_wing.K, # strike price (USD/share)
        premium = call_wing.buy_price, # premium we pay (USD/share)
        DTE = trade.DTE, # time to expiration (years)
        sense = 1, # long contract
        copy = 1, # one contract
        IV = call_wing.IV # implied volatility (decimal)
    ));

    # Return the contracts in a vector -
    return [call_short, call_long];
end
