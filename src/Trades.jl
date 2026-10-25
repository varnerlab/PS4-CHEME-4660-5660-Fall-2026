# PS4 trade table: walk each ticker's end-of-day options archive, pick the expiration and the
# six option legs of every trade, and record why any candidate trade was skipped.
using CSV, DataFrames, Dates, Statistics, VLQuantitativeFinancePackage

# The six option legs recorded for every trade. Each structure uses some of them.
const PS4_ROLES = (:atm_call, :atm_put, :short_call, :short_put, :long_call, :long_put);

# The archive's group for each ticker, from the coverage table of the options archive README.
const PS4_GROUPS = Dict{String,String}(
    "AAPL" => "Technology", "AMD" => "Technology", "AVGO" => "Technology",
    "GOOG" => "Technology", "INTC" => "Technology", "META" => "Technology",
    "MSFT" => "Technology", "MU" => "Technology", "NVDA" => "Technology",
    "QCOM" => "Technology",
    "ABBV" => "Healthcare", "AMGN" => "Healthcare", "BMY" => "Healthcare",
    "JNJ" => "Healthcare", "LLY" => "Healthcare", "MRNA" => "Healthcare",
    "PFE" => "Healthcare", "UNH" => "Healthcare",
    "BAC" => "Financials", "GS" => "Financials", "JPM" => "Financials", "WFC" => "Financials",
    "CVX" => "Energy", "OXY" => "Energy", "XOM" => "Energy",
    "TGT" => "Retail and transport", "UPS" => "Retail and transport",
    "WMT" => "Retail and transport",
    "IWM" => "Exchange-traded funds", "QQQ" => "Exchange-traded funds",
    "SPY" => "Exchange-traded funds");

"""
    trade_columns() -> Vector{Pair{String,Type}}

List the columns of the trade table in order, with the type of each.

### Returns

- Pairs `name => type`: `trade_id`, `ticker`, `group`, `entry`, `expiration`,
  `days`, `S0`, `ST`, `atm_iv`, then `<leg>_K`, `<leg>_bid`, `<leg>_ask`,
  `<leg>_mid`, `<leg>_iv`, and `<leg>_delta` for each leg in `PS4_ROLES`, then
  `screened`. The implied volatility and delta may be `missing`.
"""
function trade_columns()::Vector{Pair{String,Type}}

    # Trade columns -
    columns = Pair{String,Type}["trade_id" => Int, "ticker" => String, "group" => String,
        "entry" => Date, "expiration" => Date, "days" => Int, "S0" => Float64, "ST" => Float64,
        "atm_iv" => Float64];

    # Six columns for each leg -
    for role in PS4_ROLES
        push!(columns, "$(role)_K" => Float64);
        push!(columns, "$(role)_bid" => Float64);
        push!(columns, "$(role)_ask" => Float64);
        push!(columns, "$(role)_mid" => Float64);
        push!(columns, "$(role)_iv" => Union{Missing,Float64});
        push!(columns, "$(role)_delta" => Union{Missing,Float64});
    end

    push!(columns, "screened" => Int);
    return columns;
end

"""
    choose_expiration(expirations::AbstractVector{Date}, session::Date, config::NamedTuple) -> Union{Nothing,Date}

Pick the expiration whose days to expiration is closest to `config.target_dte`,
among those no more than `config.dte_window` days from it. A tie goes to the
earlier expiration.

### Arguments

- `expirations`: The expirations quoted on the session.
- `session`: The trading session (the entry date).
- `config`: The settings from `load_config`.

### Returns

- The chosen expiration, or `nothing` when no expiration is inside the window.
"""
function choose_expiration(expirations::AbstractVector{Date}, session::Date,
    config::NamedTuple)::Union{Nothing,Date}

    # Initialize -
    best = nothing;
    best_gap = 0;

    # Check the expirations from earliest to latest, so a tie keeps the earlier one -
    for expiration in sort(unique(expirations))
        days = Dates.value(expiration - session);
        gap = abs(days - config.target_dte);
        if gap <= config.dte_window && (best === nothing || gap < best_gap)
            best = expiration;
            best_gap = gap;
        end
    end

    return best;
end

"""
    bid_ask_spread(side::DataFrame, i::Int) -> Float64

The bid-ask spread, `ask - bid`, of the contract in row `i` (USD/share).
"""
function bid_ask_spread(side::DataFrame, i::Int)::Float64
    return side.ask[i] - side.bid[i];
end

"""
    quote_is_erratic(side::DataFrame, i::Int, multiple::Real, min_width::Real) -> Bool

Quote screen: decide whether the contract in row `i` has a bid-ask spread far
wider than its neighbors'. The neighbors are the two nearest strikes on each
side of it (fewer at the edge of the chain), with the same type and expiration.

### Arguments

- `side`: One type (calls or puts) of one expiration on one session, sorted by
  strike.
- `i`: The row to check.
- `multiple`: How many times the neighbors' median spread a spread must exceed
  (`config.quote_screen_multiple`).
- `min_width`: A spread no wider than this (USD/share) is never erratic
  (`config.quote_screen_min_width`).

### Returns

- `true` when the spread is larger than `multiple` times the neighbors' median
  spread and also larger than `min_width`. A contract with no neighbors is
  never erratic.
"""
function quote_is_erratic(side::DataFrame, i::Int, multiple::Real, min_width::Real)::Bool

    # The neighbors: up to two rows on each side of row i -
    neighbor_spreads = Float64[];
    for j in (i - 2):(i + 2)
        if j != i && 1 <= j <= nrow(side)
            push!(neighbor_spreads, bid_ask_spread(side, j));
        end
    end
    if isempty(neighbor_spreads)
        return false;
    end

    # Erratic: much wider than the neighbors, and wider than the minimum width -
    spread = bid_ask_spread(side, i);
    return spread > multiple * median(neighbor_spreads) && spread > min_width;
end

"""
    leg_candidates(side::DataFrame, target::Real, lower::Real, upper::Real) -> Vector{Int}

List the rows that could be a short leg or a wing: contracts with a delta and a
positive bid whose strike is strictly between `lower` and `upper`.

### Arguments

- `side`: One type (calls or puts) of one expiration on one session, sorted by
  strike.
- `target`: The delta the leg should have, such as `0.25` for the short call or
  `-0.25` for the short put.
- `lower`, `upper`: Strike limits (USD/share). Use `-Inf` and `Inf` for no limit.

### Returns

- The candidate rows, nearest the target delta first. Candidates equally near
  the target are ordered by strike.
"""
function leg_candidates(side::DataFrame, target::Real, lower::Real, upper::Real)::Vector{Int}

    # Collect (distance from the target delta, strike, row) for each candidate -
    ranked = Tuple{Float64,Float64,Int}[];
    for i in 1:nrow(side)
        if !ismissing(side.delta[i]) && side.bid[i] > 0 && lower < side.strike[i] < upper
            push!(ranked, (abs(side.delta[i] - target), side.strike[i], i));
        end
    end

    # Sort by distance, then by strike, and return the rows -
    sort!(ranked);
    rows = Int[];
    for (distance, strike, i) in ranked
        push!(rows, i);
    end
    return rows;
end

"""
    screen_leg(side::DataFrame, rows::Vector{Int}, config::NamedTuple) -> Tuple{Int,Bool}

Apply the quote screen to a leg. The leg is the first of the candidate `rows`.
If its quote is erratic, it moves to the first later candidate that passes the
screen and has a strictly narrower spread; if there is none, it is kept.

### Arguments

- `side`: One type (calls or puts) of one expiration on one session, sorted by
  strike.
- `rows`: The candidate rows, best first, from `leg_candidates`.
- `config`: The settings from `load_config`.

### Returns

- `(row, moved)`: the row chosen, and `true` when the screen moved the leg.
"""
function screen_leg(side::DataFrame, rows::Vector{Int}, config::NamedTuple)::Tuple{Int,Bool}

    # Keep the first candidate if its quote is not erratic -
    original = rows[1];
    if !quote_is_erratic(side, original, config.quote_screen_multiple, config.quote_screen_min_width)
        return (original, false);
    end

    # Otherwise move to the first candidate that passes and is narrower -
    for i in rows
        passes = !quote_is_erratic(side, i, config.quote_screen_multiple, config.quote_screen_min_width);
        if passes && bid_ask_spread(side, i) < bid_ask_spread(side, original)
            return (i, true);
        end
    end
    return (original, false);
end

"""
    select_legs(chain::DataFrame, S0::Real, config::NamedTuple) -> NamedTuple

Pick the six legs of one trade from one expiration of one session's chain.

- At the money: the strike nearest `S0` where both the call and the put have a
  positive bid.
- Short legs: the call and the put whose delta is nearest `+config.short_delta`
  and `-config.short_delta`.
- Wings: the call and the put whose delta is nearest `+config.wing_delta` and
  `-config.wing_delta`, strictly beyond the short strike, with a mid price below
  the mid of the short leg they protect (a wing priced at or above it is an
  impossible quote).

Short legs and wings are chosen only from contracts with a delta and a positive
bid. Each leg then goes through the quote screen (`screen_leg`). The
at-the-money pair moves only to the next-nearest strike where both the call and
the put pass and the wider of the two spreads is narrower than the wider of the
original pair's; a move counts as two moved legs.

### Arguments

- `chain`: The archive rows of one session and one expiration (calls and puts).
- `S0`: The share price on the session (USD/share).
- `config`: The settings from `load_config`.

### Returns

- A `NamedTuple` with `legs`, a `Dict` from each leg in `PS4_ROLES` to its
  archive row, or `nothing` when a leg cannot be found; `screened`, the number
  of legs the quote screen moved; `impossible`, the number of wings passed over
  because their mid was at or above the short leg's mid; and `reason`, an empty
  string, or why the trade has no legs.
"""
function select_legs(chain::DataFrame, S0::Real, config::NamedTuple)::NamedTuple

    # Initialize -
    calls = sort(chain[chain.type .== "call", :], :strike);
    puts = sort(chain[chain.type .== "put", :], :strike);
    multiple = config.quote_screen_multiple;
    min_width = config.quote_screen_min_width;
    legs = Dict{Symbol,DataFrameRow}();
    screened = 0;
    impossible = 0;

    # At the money: map each strike to its row, for calls and puts with a positive bid -
    call_row = Dict{Float64,Int}();
    for i in 1:nrow(calls)
        if calls.bid[i] > 0
            call_row[calls.strike[i]] = i;
        end
    end
    put_row = Dict{Float64,Int}();
    for i in 1:nrow(puts)
        if puts.bid[i] > 0
            put_row[puts.strike[i]] = i;
        end
    end

    # Strikes where both the call and the put have a positive bid, nearest S0 first -
    ranked = Tuple{Float64,Float64}[];
    for K in keys(call_row)
        if haskey(put_row, K)
            push!(ranked, (abs(K - S0), K));
        end
    end
    if isempty(ranked)
        return (legs = nothing, screened = screened, impossible = impossible,
            reason = "no strike has a positive bid on both the call and the put");
    end
    sort!(ranked);
    strikes = Float64[];
    for (distance, K) in ranked
        push!(strikes, K);
    end

    # Screen the at-the-money pair; move it if either quote is erratic -
    atm_K = strikes[1];
    atm_passes = !quote_is_erratic(calls, call_row[atm_K], multiple, min_width) &&
        !quote_is_erratic(puts, put_row[atm_K], multiple, min_width);
    if !atm_passes
        atm_width = max(bid_ask_spread(calls, call_row[atm_K]), bid_ask_spread(puts, put_row[atm_K]));
        for K in strikes
            passes = !quote_is_erratic(calls, call_row[K], multiple, min_width) &&
                !quote_is_erratic(puts, put_row[K], multiple, min_width);
            width = max(bid_ask_spread(calls, call_row[K]), bid_ask_spread(puts, put_row[K]));
            if passes && width < atm_width
                atm_K = K;
                screened = screened + 2;
                break;
            end
        end
    end
    legs[:atm_call] = calls[call_row[atm_K], :];
    legs[:atm_put] = puts[put_row[atm_K], :];

    # Short call: delta nearest +short_delta -
    rows = leg_candidates(calls, config.short_delta, -Inf, Inf);
    if isempty(rows)
        return (legs = nothing, screened = screened, impossible = impossible,
            reason = "no call has a delta and a positive bid");
    end
    (i, moved) = screen_leg(calls, rows, config);
    legs[:short_call] = calls[i, :];
    if moved
        screened = screened + 1;
    end

    # Short put: delta nearest -short_delta -
    rows = leg_candidates(puts, -config.short_delta, -Inf, Inf);
    if isempty(rows)
        return (legs = nothing, screened = screened, impossible = impossible,
            reason = "no put has a delta and a positive bid");
    end
    (i, moved) = screen_leg(puts, rows, config);
    legs[:short_put] = puts[i, :];
    if moved
        screened = screened + 1;
    end

    # Long call: above the short call strike, cheaper than the short call -
    K = legs[:short_call].strike;
    mid = legs[:short_call].mid;
    rows = leg_candidates(calls, config.wing_delta, K, Inf);
    if isempty(rows)
        return (legs = nothing, screened = screened, impossible = impossible,
            reason = "no long_call candidate lies beyond the short_call strike $(K)");
    end
    priced = Int[];
    for i in rows
        if calls.mid[i] < mid
            push!(priced, i);
        end
    end
    if isempty(priced)
        return (legs = nothing, screened = screened, impossible = impossible,
            reason = "every long_call candidate has a mid at or above the short_call mid $(mid)");
    end
    if priced[1] != rows[1]
        impossible = impossible + 1;
    end
    (i, moved) = screen_leg(calls, priced, config);
    legs[:long_call] = calls[i, :];
    if moved
        screened = screened + 1;
    end

    # Long put: below the short put strike, cheaper than the short put -
    K = legs[:short_put].strike;
    mid = legs[:short_put].mid;
    rows = leg_candidates(puts, -config.wing_delta, -Inf, K);
    if isempty(rows)
        return (legs = nothing, screened = screened, impossible = impossible,
            reason = "no long_put candidate lies beyond the short_put strike $(K)");
    end
    priced = Int[];
    for i in rows
        if puts.mid[i] < mid
            push!(priced, i);
        end
    end
    if isempty(priced)
        return (legs = nothing, screened = screened, impossible = impossible,
            reason = "every long_put candidate has a mid at or above the short_put mid $(mid)");
    end
    if priced[1] != rows[1]
        impossible = impossible + 1;
    end
    (i, moved) = screen_leg(puts, priced, config);
    legs[:long_put] = puts[i, :];
    if moved
        screened = screened + 1;
    end

    return (legs = legs, screened = screened, impossible = impossible, reason = "");
end

"""
    enter_trade(ticker, session, day, close_on, last_session, config) -> Union{Nothing,String,Vector{Any}}

Try to open one trade on one session.

### Arguments

- `ticker::String`: The ticker.
- `session::Date`: The trading session (the candidate entry date).
- `day::AbstractDataFrame`: The archive rows of the ticker on that session.
- `close_on::Dict{Tuple{String,Date},Float64}`: The ticker's close on each date,
  keyed by `(ticker, date)`.
- `last_session::Date`: The last session in the archive.
- `config::NamedTuple`: The settings from `load_config`.

### Returns

- The trade-table row as a vector of values (with `trade_id` set to 0) when a
  trade opens; a `String` giving the reason when the candidate is skipped; or
  `nothing` when the expiration would fall after the archive ends, so the trade
  could never be settled.
"""
function enter_trade(ticker::String, session::Date, day::AbstractDataFrame,
    close_on::Dict{Tuple{String,Date},Float64}, last_session::Date, config::NamedTuple)

    # Initialize -
    lo = config.target_dte - config.dte_window;
    hi = config.target_dte + config.dte_window;

    # No expiration in the window can settle inside the archive -
    if session + Day(lo) > last_session
        return nothing;
    end

    # Choose the expiration -
    expiration = choose_expiration(day.expiration, session, config);
    if isnothing(expiration)
        return "no expiration between $lo and $hi days";
    end
    if expiration > last_session
        return nothing;
    end

    # The share price on the entry date and on the expiration date -
    if !haskey(close_on, (ticker, session))
        return "no underlying close on the entry date";
    end
    if !haskey(close_on, (ticker, expiration))
        return "expiration $expiration has no underlying close in the archive";
    end
    S0 = close_on[(ticker, session)];
    ST = close_on[(ticker, expiration)];

    # Pick the six legs -
    chain = DataFrame(day[day.expiration .== expiration, :]);
    picked = select_legs(chain, S0, config);
    if isnothing(picked.legs)
        return "expiration $expiration: $(picked.reason)";
    end

    # The trade's implied volatility: the mean of the at-the-money call's and put's -
    ivs = Float64[];
    for role in (:atm_call, :atm_put)
        iv = picked.legs[role].implied_vol;
        if !ismissing(iv)
            push!(ivs, iv);
        end
    end
    if isempty(ivs)
        return "expiration $expiration: both at-the-money implied volatilities are missing";
    end

    # Assemble the row in the order of trade_columns() -
    days = Dates.value(expiration - session);
    values = Any[0, ticker, PS4_GROUPS[ticker], session, expiration, days, S0, ST, mean(ivs)];
    for role in PS4_ROLES
        leg = picked.legs[role];
        append!(values, [leg.strike, leg.bid, leg.ask, leg.mid, leg.implied_vol, leg.delta]);
    end
    push!(values, picked.screened);

    return values;
end

"""
    build_trade_table(config::NamedTuple) -> NamedTuple

Build the table of trades from the course options archive.

For each ticker, start at its first archive session. On a session, choose the
expiration whose days to expiration is closest to `config.target_dte` (within
`config.dte_window` days), pick the legs with `select_legs`, and hold to that
expiration. The next entry is the first session on or after that expiration, so
trades never overlap within a ticker. A candidate is skipped, with a log line,
when no expiration lies inside the window, the entry or expiration has no
underlying close, a leg is missing, or both at-the-money implied volatilities
are missing; the walk then tries the next session. Candidates whose expiration
falls (or would fall) after the archive's last session cannot be settled; they
end the ticker's trades and are not logged.

### Arguments

- `config`: The settings from `load_config` (uses `tickers`, `target_dte`,
  `dte_window`, `short_delta`, `wing_delta`, `quote_screen_multiple`, and
  `quote_screen_min_width`).

### Returns

- A `NamedTuple` with `trades`, a `DataFrame` with one row per trade and the
  columns of `trade_columns()`, numbered 1, 2, ... by ticker and then entry
  date; and `log`, one line per skipped candidate, starting with the ticker and
  date.
"""
function build_trade_table(config::NamedTuple)::NamedTuple

    # Initialize: every ticker's close on every archive date -
    underlying = MyOptionsEODUnderlyingDataSet();
    close_on = Dict{Tuple{String,Date},Float64}();
    for row in eachrow(underlying)
        close_on[(row.ticker, row.date)] = row.close;
    end
    last_session = maximum(underlying.date);

    # An empty trade table with the right columns, and an empty log -
    trades = DataFrame();
    for (name, T) in trade_columns()
        trades[!, name] = T[];
    end
    log = String[];

    for ticker in sort(config.tickers)

        # The ticker's quotes, split by session -
        chain = MyOptionsEODDataSet(ticker = ticker);
        chain_on = Dict{Date,DataFrame}();
        for group in groupby(chain, :date)
            chain_on[group.date[1]] = DataFrame(group);
        end
        sessions = sort(collect(keys(chain_on)));

        # Walk the sessions, opening back-to-back trades -
        i = 1;
        while i <= length(sessions)
            session = sessions[i];
            outcome = enter_trade(ticker, session, chain_on[session], close_on, last_session, config);

            if outcome isa Vector
                # A trade opened: record it and jump to the first session on or after its expiration -
                push!(trades, outcome);
                expiration = trades.expiration[end];
                next_i = length(sessions) + 1;
                for j in eachindex(sessions)
                    if sessions[j] >= expiration
                        next_i = j;
                        break;
                    end
                end
                i = next_i;
            else
                # No trade: log the reason (if any) and try the next session -
                if outcome isa String
                    push!(log, "$ticker $session: $outcome");
                end
                i = i + 1;
            end
        end
    end

    trades.trade_id = collect(1:nrow(trades));
    return (trades = trades, log = log);
end

"""
    load_trade_table(path::AbstractString) -> DataFrame

Read a trade table saved as CSV, such as the supplied `data/trades.csv`.

### Arguments

- `path`: Location of the CSV file.

### Returns

- The trade table with the columns and types of `trade_columns()`. Throws an
  `ArgumentError` when the file's columns differ from the trade-table columns.
"""
function load_trade_table(path::AbstractString)::DataFrame

    # Read the file with the column types of the trade table -
    columns = trade_columns();
    table = CSV.read(path, DataFrame; stringtype = String, types = Dict(columns));

    # Check the column names and order -
    expected = String[];
    for (name, T) in columns
        push!(expected, name);
    end
    if names(table) != expected
        throw(ArgumentError("The file does not have the trade-table columns in the expected order."));
    end

    return table;
end

"""
    archive_closes(ticker::String) -> DataFrame

Read the daily closes of one ticker from the options archive, for the report's
market benchmark. `instructor/build_data.jl` saves them as `data/benchmark.csv`
for graded runs; `explore.jl` reads them for the `benchmark_ticker` of
`config/explore.toml`.

### Arguments

- `ticker`: A ticker in the course options archive, such as `"SPY"`.

### Returns

- A `DataFrame` with columns `ticker::String`, `date::Date`, and
  `close::Float64` (USD), one row per archive session, sorted by date.
"""
function archive_closes(ticker::String)::DataFrame

    archive = MyOptionsEODUnderlyingDataSet(ticker = ticker);
    closes = DataFrame(ticker = fill(ticker, nrow(archive)), date = Date.(archive.date),
        close = Float64.(archive.close));
    return sort(unique(closes, :date), :date);
end
