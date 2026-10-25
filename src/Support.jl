# Supplied code for PS4: the settings, the trade table, the price models, and the
# inputs, capital, and exposure of each structure on each trade.
include(joinpath(@__DIR__, "Config.jl"));
include(joinpath(@__DIR__, "Trades.jl"));
include(joinpath(@__DIR__, "Models.jl"));

# The four Standard structures: (name, report label, builder function).
const STANDARD_STRUCTURES = [
    (:short_straddle, "Short straddle", :build_short_straddle),
    (:short_strangle, "Short strangle", :build_short_strangle),
    (:protected_strangle, "Protected strangle", :build_protected_strangle),
    (:iron_condor, "Iron condor", :build_iron_condor)];

# The Advanced track adds four one-sided structures to the Standard four.
const ADVANCED_STRUCTURES = vcat(STANDARD_STRUCTURES, [
    (:short_put, "Short put", :build_short_put),
    (:short_call, "Short call", :build_short_call),
    (:put_credit_spread, "Put credit spread", :build_put_credit_spread),
    (:call_credit_spread, "Call credit spread", :build_call_credit_spread)]);

# The legs of each structure as (leg, sense) pairs: sense is -1 for a sold leg and +1 for a
# bought leg. The capital and the exposure are computed from this table.
const PS4_STRUCTURE_LEGS = Dict{Symbol,Vector{Tuple{Symbol,Int}}}(
    :short_straddle => [(:atm_call, -1), (:atm_put, -1)],
    :short_strangle => [(:short_call, -1), (:short_put, -1)],
    :protected_strangle => [(:short_call, -1), (:short_put, -1), (:long_call, +1)],
    :iron_condor => [(:short_call, -1), (:short_put, -1), (:long_call, +1), (:long_put, +1)],
    :short_put => [(:short_put, -1)],
    :short_call => [(:short_call, -1)],
    :put_credit_spread => [(:short_put, -1), (:long_put, +1)],
    :call_credit_spread => [(:short_call, -1), (:long_call, +1)]);

# Exposure is reported per 1% rise in the stock price.
const PS4_EXPOSURE_STEP = 0.01;

"""
    leg_inputs(row, role::Symbol, fill::String) -> NamedTuple

Read one leg of a trade from a row of the trade table.

### Arguments

- `row`: One row of the trade table.
- `role`: The leg, one of `PS4_ROLES`, such as `:short_call`.
- `fill`: `"mid"` sells and buys at the mid price; `"bidask"` sells at the bid
  and buys at the ask.

### Returns

- `(K, IV, sell_price, buy_price)`: the strike (USD/share), the implied
  volatility, and the sell and buy prices (USD/share). A missing implied
  volatility is replaced by the trade's at-the-money value `atm_iv`.
"""
function leg_inputs(row, role::Symbol, fill::String)::NamedTuple

    # Strike and implied volatility -
    K = row[Symbol(role, "_K")];
    IV = row[Symbol(role, "_iv")];
    if ismissing(IV)
        IV = row.atm_iv;
    end

    # Prices: both at the mid, or sell at the bid and buy at the ask -
    if fill == "mid"
        sell_price = row[Symbol(role, "_mid")];
        buy_price = row[Symbol(role, "_mid")];
    else
        sell_price = row[Symbol(role, "_bid")];
        buy_price = row[Symbol(role, "_ask")];
    end

    return (K = K, IV = IV, sell_price = sell_price, buy_price = buy_price);
end

"""
    trade_inputs(row; fill::String) -> NamedTuple

Turn one row of the trade table into the `trade` a structure builder receives.

### Arguments

- `row`: One row of the trade table.
- `fill`: `"mid"` sells and buys every leg at its mid price; `"bidask"` sells
  at the bid and buys at the ask.

### Returns

- A `NamedTuple` with `ticker`, `entry`, `expiration`, `DTE` (years to
  expiration, `days / 365`), `Sₒ` (the share price at entry), and the six legs
  `atm_call`, `atm_put`, `short_call`, `short_put`, `long_call`, `long_put`,
  each from `leg_inputs`. Throws an `ArgumentError` when `fill` is neither
  `"mid"` nor `"bidask"`.
"""
function trade_inputs(row; fill::String)::NamedTuple

    # Check the fill -
    if !(fill in ("mid", "bidask"))
        throw(ArgumentError("The fill must be \"mid\" or \"bidask\"."));
    end

    return (ticker = row.ticker, entry = row.entry, expiration = row.expiration,
        DTE = row.days / 365, Sₒ = row.S0,
        atm_call = leg_inputs(row, :atm_call, fill),
        atm_put = leg_inputs(row, :atm_put, fill),
        short_call = leg_inputs(row, :short_call, fill),
        short_put = leg_inputs(row, :short_put, fill),
        long_call = leg_inputs(row, :long_call, fill),
        long_put = leg_inputs(row, :long_put, fill));
end

"""
    structure_credit(structure::Symbol, trade::NamedTuple) -> Float64

Cash a structure collects at entry, in USD per share: each sold leg brings in
its `sell_price`, and each bought leg costs its `buy_price`.

### Arguments

- `structure`: One of the names in `ADVANCED_STRUCTURES`.
- `trade`: The inputs from `trade_inputs`.

### Returns

- The credit in USD per share.
"""
function structure_credit(structure::Symbol, trade::NamedTuple)::Float64

    credit = 0.0;
    for (role, sense) in PS4_STRUCTURE_LEGS[structure]
        if sense == -1
            credit = credit + trade[role].sell_price;
        else
            credit = credit - trade[role].buy_price;
        end
    end
    return credit;
end

"""
    naked_call_capital(leg::NamedTuple, S::Float64, config::NamedTuple) -> Float64

Capital for a short call with no protection: the premium plus
max(`margin_rate`·S − max(K − S, 0), `margin_floor`·S).

### Arguments

- `leg`: The call, from `leg_inputs`.
- `S`: The share price at entry (USD/share).
- `config`: The settings from `load_config`.

### Returns

- The capital in USD per share.
"""
function naked_call_capital(leg::NamedTuple, S::Float64, config::NamedTuple)::Float64

    out_of_the_money = max(leg.K - S, 0);
    cushion = max(config.margin_rate * S - out_of_the_money, config.margin_floor * S);
    return leg.sell_price + cushion;
end

"""
    naked_put_capital(leg::NamedTuple, S::Float64, config::NamedTuple) -> Float64

Capital for a short put with no protection: the premium plus
max(`margin_rate`·S − max(S − K, 0), `margin_floor`·K).

### Arguments

- `leg`: The put, from `leg_inputs`.
- `S`: The share price at entry (USD/share).
- `config`: The settings from `load_config`.

### Returns

- The capital in USD per share.
"""
function naked_put_capital(leg::NamedTuple, S::Float64, config::NamedTuple)::Float64

    out_of_the_money = max(S - leg.K, 0);
    cushion = max(config.margin_rate * S - out_of_the_money, config.margin_floor * leg.K);
    return leg.sell_price + cushion;
end

"""
    capital_required(structure::Symbol, trade::NamedTuple, config::NamedTuple) -> Float64

Capital a broker requires to hold one share of a structure, in USD per share.

- Naked call or naked put: `naked_call_capital` or `naked_put_capital`.
- Straddle and strangle: the larger of the call side and the put side.
- Credit spread: the strike width minus the credit.
- Iron condor: the wider of the two spreads' widths minus the total credit.
- Protected strangle: the larger of the naked put and the call spread's width
  minus its credit.

### Arguments

- `structure`: One of the names in `ADVANCED_STRUCTURES`.
- `trade`: The inputs from `trade_inputs`.
- `config`: The settings from `load_config`.

### Returns

- The capital in USD per share. Throws a `DomainError` when it is not positive
  and finite.
"""
function capital_required(structure::Symbol, trade::NamedTuple, config::NamedTuple)::Float64

    # Check the structure name -
    if !haskey(PS4_STRUCTURE_LEGS, structure)
        throw(ArgumentError("Unknown structure $structure."));
    end

    # Initialize -
    S = trade.Sₒ;
    call_width = trade.long_call.K - trade.short_call.K;
    put_width = trade.short_put.K - trade.long_put.K;
    call_spread = call_width - structure_credit(:call_credit_spread, trade);
    put_spread = put_width - structure_credit(:put_credit_spread, trade);

    # Apply the margin rule for this structure -
    if structure == :short_straddle
        capital = max(naked_call_capital(trade.atm_call, S, config),
            naked_put_capital(trade.atm_put, S, config));
    elseif structure == :short_strangle
        capital = max(naked_call_capital(trade.short_call, S, config),
            naked_put_capital(trade.short_put, S, config));
    elseif structure == :protected_strangle
        capital = max(naked_put_capital(trade.short_put, S, config), call_spread);
    elseif structure == :iron_condor
        capital = max(call_width, put_width) - structure_credit(:iron_condor, trade);
    elseif structure == :short_put
        capital = naked_put_capital(trade.short_put, S, config);
    elseif structure == :short_call
        capital = naked_call_capital(trade.short_call, S, config);
    elseif structure == :put_credit_spread
        capital = put_spread;
    else
        capital = call_spread;
    end

    # Capital must be positive and finite -
    if !(isfinite(capital) && capital > 0)
        throw(DomainError(capital, "The capital required for $structure must be positive and finite."));
    end

    return Float64(capital);
end

"""
    exposure_per_percent(structure::Symbol, row, capital::Float64) -> Float64

Change in a structure's value for a 1% rise in the stock, as a fraction of
capital: the sum over the legs of sense × delta × 1% of the entry price `S0`,
divided by `capital`.

### Arguments

- `structure`: One of the names in `ADVANCED_STRUCTURES`.
- `row`: One row of the trade table, with the leg deltas and `S0`.
- `capital`: The capital from `capital_required`.

### Returns

- The exposure as a fraction of capital. Throws an `ArgumentError` when a
  leg's delta is missing.
"""
function exposure_per_percent(structure::Symbol, row, capital::Float64)::Float64

    # Check the structure name -
    if !haskey(PS4_STRUCTURE_LEGS, structure)
        throw(ArgumentError("Unknown structure $structure."));
    end

    # Add up the deltas of the legs, with their senses -
    delta = 0.0;
    for (role, sense) in PS4_STRUCTURE_LEGS[structure]
        leg_delta = row[Symbol(role, "_delta")];
        if ismissing(leg_delta)
            throw(ArgumentError("The delta of $role is missing."));
        end
        delta = delta + sense * leg_delta;
    end

    # Change in value for a 1% rise, as a fraction of capital -
    return delta * PS4_EXPOSURE_STEP * row.S0 / capital;
end
