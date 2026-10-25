# PS4 Standard: complete the 6 functions below.
# The report calls these functions for every trade and every structure.
# Use the American contract types, MyAmericanCallContractModel and
# MyAmericanPutContractModel; the checks reject any other contract type.
# Keep the function names, arguments, return types, and docstrings.
# Replace each error("Complete ...") expression with your calculation.
# The setup lines and return statements are supplied.
# Save your code, then run from the PS4 folder:
# julia --project=. --startup-file=no check_submission.jl
#
# Each docstring ends with Course references: a pointer to the course
# materials and the matching slide in the PS4 mathematical companion. Some
# course example cells wrap their calculation in a let ... end block. Copy
# only the lines you need and rename variables to match this file.

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

    # TODO 1: Build the short call.
    # Hint: build(MyAmericanCallContractModel, (K = ..., premium = ..., DTE = ..., sense = ..., copy = 1, IV = ...)).
    # Use K = call_leg.K, premium = call_leg.sell_price, sense = -1, DTE = trade.DTE, and IV = call_leg.IV.
    call_short = error("Complete build_short_straddle: build the short call.");

    # TODO 2: Build the short put.
    # Hint: build(MyAmericanPutContractModel, (K = ..., premium = ..., DTE = ..., sense = ..., copy = 1, IV = ...)).
    # Use K = put_leg.K, premium = put_leg.sell_price, sense = -1, DTE = trade.DTE, and IV = put_leg.IV.
    put_short = error("Complete build_short_straddle: build the short put.");

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

    # TODO 1: Build the short call.
    # Hint: build(MyAmericanCallContractModel, (K = ..., premium = ..., DTE = ..., sense = ..., copy = 1, IV = ...)).
    # Use K = call_leg.K, premium = call_leg.sell_price, sense = -1, DTE = trade.DTE, and IV = call_leg.IV.
    call_short = error("Complete build_short_strangle: build the short call.");

    # TODO 2: Build the short put.
    # Hint: build(MyAmericanPutContractModel, (K = ..., premium = ..., DTE = ..., sense = ..., copy = 1, IV = ...)).
    # Use K = put_leg.K, premium = put_leg.sell_price, sense = -1, DTE = trade.DTE, and IV = put_leg.IV.
    put_short = error("Complete build_short_strangle: build the short put.");

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

    # TODO 1: Build the short call.
    # Hint: build(MyAmericanCallContractModel, (K = ..., premium = ..., DTE = ..., sense = ..., copy = 1, IV = ...)).
    # Use K = call_leg.K, premium = call_leg.sell_price, sense = -1, DTE = trade.DTE, and IV = call_leg.IV.
    call_short = error("Complete build_protected_strangle: build the short call.");

    # TODO 2: Build the short put.
    # Hint: build(MyAmericanPutContractModel, (K = ..., premium = ..., DTE = ..., sense = ..., copy = 1, IV = ...)).
    # Use K = put_leg.K, premium = put_leg.sell_price, sense = -1, DTE = trade.DTE, and IV = put_leg.IV.
    put_short = error("Complete build_protected_strangle: build the short put.");

    # TODO 3: Build the long call.
    # Hint: build(MyAmericanCallContractModel, (K = ..., premium = ..., DTE = ..., sense = ..., copy = 1, IV = ...)).
    # Use K = wing_leg.K, premium = wing_leg.buy_price, sense = 1, DTE = trade.DTE, and IV = wing_leg.IV.
    call_long = error("Complete build_protected_strangle: build the long call.");

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

    # TODO 1: Build the short call.
    # Hint: build(MyAmericanCallContractModel, (K = ..., premium = ..., DTE = ..., sense = ..., copy = 1, IV = ...)).
    # Use K = call_leg.K, premium = call_leg.sell_price, sense = -1, DTE = trade.DTE, and IV = call_leg.IV.
    call_short = error("Complete build_iron_condor: build the short call.");

    # TODO 2: Build the short put.
    # Hint: build(MyAmericanPutContractModel, (K = ..., premium = ..., DTE = ..., sense = ..., copy = 1, IV = ...)).
    # Use K = put_leg.K, premium = put_leg.sell_price, sense = -1, DTE = trade.DTE, and IV = put_leg.IV.
    put_short = error("Complete build_iron_condor: build the short put.");

    # TODO 3: Build the long call.
    # Hint: build(MyAmericanCallContractModel, (K = ..., premium = ..., DTE = ..., sense = ..., copy = 1, IV = ...)).
    # Use K = call_wing.K, premium = call_wing.buy_price, sense = 1, DTE = trade.DTE, and IV = call_wing.IV.
    call_long = error("Complete build_iron_condor: build the long call.");

    # TODO 4: Build the long put.
    # Hint: build(MyAmericanPutContractModel, (K = ..., premium = ..., DTE = ..., sense = ..., copy = 1, IV = ...)).
    # Use K = put_wing.K, premium = put_wing.buy_price, sense = 1, DTE = trade.DTE, and IV = put_wing.IV.
    put_long = error("Complete build_iron_condor: build the long put.");

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

    # TODO 1: Compute the profit table at the one share price S_T.
    # Hint: profit(...) takes a vector of share prices, so pass [S_T] as the second argument.
    profit_array = error("Complete trade_profit: compute the profit table at S_T.");

    # TODO 2: Read the total profit: row 1, last column.
    # Hint: profit_array[1, end] picks the first row and the last column.
    value = error("Complete trade_profit: read the total profit.");

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

    # TODO 1: Compute the total profit at every sample: the last column of profit(...).
    # Hint: profit(contracts, endpoint_samples) has one row per sample; profit_array[:, end] is the last column.
    profit_array = error("Complete probability_of_profit: compute the profit table at every sample.");
    total_profit = error("Complete probability_of_profit: take the total profit column.");

    # TODO 2: Count the samples with a positive total profit and divide.
    # Hint: count(total_profit .> 0.0) counts the wins; divide by number_of_samples.
    POP = error("Complete probability_of_profit: count the wins and divide by the number of samples.");

    return POP;
end
