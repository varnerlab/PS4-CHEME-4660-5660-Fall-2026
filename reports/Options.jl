# Supplied evaluation and report for PS4. Runs the selected student functions over every trade
# and structure, then writes the tables in return-on-capital units: Report.md to read, and CSV
# files to explore. Exported fractions are decimals; displayed tables use percentages.
using CSV, DataFrames, Dates, Printf, Statistics, VLQuantitativeFinancePackage

# The outcome column that holds each model's probability of profit, keyed like `gbm_models`.
const PS4_POP_COLUMNS = (market = :pop_market, hist_drift_iv = :pop_hist_drift_iv,
    rf_hist_vol = :pop_rf_hist_vol, historical = :pop_historical);

# Column labels of the four models in the displayed tables.
const PS4_POP_LABELS = ["Model POP: market (r, IV)", "Model POP: historical drift, IV",
    "Model POP: r, historical vol", "Model POP: historical drift and vol"];

# Structures that split into an Advanced put side and call side: (whole, put side, call side).
const PS4_SIDES = [(:short_strangle, :short_put, :short_call),
    (:protected_strangle, :short_put, :call_credit_spread),
    (:iron_condor, :put_credit_spread, :call_credit_spread)];

# Display order of the ticker groups; any other group follows in alphabetical order.
const PS4_GROUP_ORDER = ["Technology", "Healthcare", "Financials", "Energy",
    "Retail and transport", "Exchange-traded funds"];

# A spread at its maximum loss returns exactly -100% up to rounding; only a loss beyond this
# margin counts as larger than the capital set aside.
const PS4_LOSS_MARGIN = 1e-9;

"""
    ps4_structures(track) -> Vector

Return the structures of a track, `STANDARD_STRUCTURES` or `ADVANCED_STRUCTURES`, in report
order. Throws an `ArgumentError` for any track other than "standard" or "advanced".
"""
function ps4_structures(track::AbstractString)
    track == "standard" && return STANDARD_STRUCTURES;
    track == "advanced" && return ADVANCED_STRUCTURES;
    throw(ArgumentError("The track must be \"standard\" or \"advanced\"."));
end

# First line of an error message, shortened so one issue stays one readable line.
function _issue_text(caught)::String
    lines = filter(!isempty, Base.strip.(split(sprint(showerror, caught), '\n')));
    text = isempty(lines) ? string(typeof(caught)) : String(first(lines));
    return length(text) > 300 ? first(text, 297) * "..." : text;
end

# Checks on what student functions return, so a wrong value is reported like an error.
function _check_contracts(c)
    c isa AbstractVector && !isempty(c) && all(x -> x isa AbstractContractModel, c) ||
        throw(ArgumentError("it returned $(typeof(c)), not a non-empty vector of contract models"));
    return c;
end
function _check_profit(v)
    v isa Real && isfinite(v) ||
        throw(ArgumentError("it returned $(repr(v)), not a finite number"));
    return Float64(v);
end
function _check_probability(p)
    p isa Real && isfinite(p) && 0 <= p <= 1 ||
        throw(ArgumentError("it returned $(repr(p)), not a probability from 0 to 1"));
    return Float64(p);
end

# Call one student function by name. On an error, record it against the function and the
# trade, keep the first message, and return `nothing` so the other calculations continue.
function _call_student(calls, lookup::Function, name::Symbol, row, check::Function, args...)
    if !haskey(calls.log, name)
        calls.log[name] = (called = Set{Int}(), failed = Set{Int}(), first = String[]);
        push!(calls.order, name);
    end
    record = calls.log[name];
    push!(record.called, row.trade_id);
    try
        return check(Base.invokelatest(lookup(name), args...));
    catch caught
        push!(record.failed, row.trade_id);
        isempty(record.first) && push!(record.first,
            "($(row.ticker), entry $(row.entry)): " * _issue_text(caught));
        return nothing;
    end
end

# One line per student function that failed at least once.
function _call_issues(calls)::Vector{String}
    issues = String[];
    for name in calls.order
        record = calls.log[name];
        isempty(record.failed) && continue;
        n, m = length(record.failed), length(record.called);
        scope = n == m ? "all $m trades" : "$n of $m trades";
        push!(issues, "$(name) failed on $(scope). First error $(only(record.first))");
    end
    return issues;
end

# Empty outcome columns: one row per trade and structure. Student results may be missing.
function _empty_outcomes()
    maybe() = Union{Missing,Float64}[];
    return (trade_id = Int[], ticker = String[], group = String[], entry = Date[],
        expiration = Date[], structure = Symbol[], credit = Float64[], capital = Float64[],
        capital_bidask = Float64[], built = Bool[], profit = maybe(), roc = maybe(),
        profit_bidask = maybe(), roc_bidask = maybe(),
        won = Union{Missing,Bool}[], pop_market = maybe(), pop_hist_drift_iv = maybe(),
        pop_rf_hist_vol = maybe(), pop_historical = maybe(), stock_return = Float64[],
        rf_return = Float64[], exposure = maybe(), days = Int[], S0 = Float64[], ST = Float64[],
        atm_iv = Float64[]);
end

"""
    evaluate_trades(track, trades, parameters, config; lookup) -> NamedTuple

Run the student's builders, `trade_profit`, and `probability_of_profit` on every trade and
every structure of a track. Each call is caught on its own, so a broken function leaves its
own results missing and the rest of the report intact.

# Arguments
- `track::String`: "standard" or "advanced".
- `trades::DataFrame`: the trade table (`load_trade_table` or `build_trade_table`).
- `parameters::DataFrame`: the trailing parameters, one row per `trade_id`.
- `config::NamedTuple`: the settings from `load_config`.
- `lookup::Function`: finds a student function by name; defaults to `getfield(Main, name)`.

# Returns
`(outcomes, issues)`. `outcomes` is a `DataFrame` with one row per trade and structure:
`trade_id, ticker, group, entry, expiration, structure` (a `Symbol`), `credit` and `capital`
(USD/share, at the configured fill), `capital_bidask` (the capital with short legs sold at the
bid and long legs bought at the ask), `built` (`true` when the student's builder returned
contracts at the configured fill), `profit` and `roc` (profit divided by capital),
`profit_bidask` and `roc_bidask` (at bid/ask fills, divided by `capital_bidask`), `won`
(profit above zero), the four probabilities of profit
`pop_market, pop_hist_drift_iv, pop_rf_hist_vol, pop_historical`, `stock_return` (ST/S0 - 1),
`rf_return` (r·days/365), and `exposure` (value change per 1% stock rise, as a fraction of
capital), followed by `days, S0, ST, atm_iv`. Student results are `missing` when the call
failed. A trade and structure whose capital at either fill is not positive and finite is
left out.
`issues` holds one line per student function that failed, then one line per left-out pair.
"""
function evaluate_trades(track::String, trades::DataFrame, parameters::DataFrame, config;
    lookup::Function = name -> getfield(Main, name))::NamedTuple
    structures = ps4_structures(track);
    by_id = Dict(p.trade_id => p for p in eachrow(parameters));
    absent = setdiff(trades.trade_id, collect(keys(by_id)));
    isempty(absent) || throw(ArgumentError("Trade $(first(absent)) has no row in the parameter table."));
    r = config.risk_free_rate;
    columns = _empty_outcomes();
    calls = (log = Dict{Symbol,Any}(), order = Symbol[]);
    skipped = String[];
    for row in eachrow(trades)
        trade = trade_inputs(row; fill = config.fill);
        trade_bidask = trade_inputs(row; fill = "bidask");
        # Simulate the four models once per trade, only when a structure needs them -
        samples, simulated = nothing, false;
        for (key, label, builder) in structures
            capital, capital_bidask = try
                (capital_required(key, trade, config), capital_required(key, trade_bidask, config));
            catch caught
                detail = caught isa DomainError ? "the capital required is not positive and finite ($(caught.val) USD/share)" :
                    _issue_text(caught);
                push!(skipped, "Left out the $(lowercase(label)) on $(row.ticker) entered $(row.entry): $(detail).");
                continue;
            end
            credit = sum(sense == -1 ? trade[role].sell_price : -trade[role].buy_price
                for (role, sense) in PS4_STRUCTURE_LEGS[key]);
            contracts = _call_student(calls, lookup, builder, row, _check_contracts, trade);
            contracts_bidask = _call_student(calls, lookup, builder, row, _check_contracts, trade_bidask);
            profit = contracts === nothing ? missing :
                something(_call_student(calls, lookup, :trade_profit, row, _check_profit, contracts, row.ST), missing);
            profit_bidask = contracts_bidask === nothing ? missing :
                something(_call_student(calls, lookup, :trade_profit, row, _check_profit, contracts_bidask, row.ST), missing);
            pops = Dict{Symbol,Union{Missing,Float64}}(c => missing for c in values(PS4_POP_COLUMNS));
            if contracts !== nothing
                if !simulated
                    simulated = true;
                    samples = try
                        endpoint_samples(gbm_models(row, by_id[row.trade_id], r), row, config);
                    catch caught
                        push!(skipped, "No simulated prices for $(row.ticker) entered $(row.entry): $(_issue_text(caught)).");
                        nothing;
                    end
                end
                if samples !== nothing
                    for (model, c) in pairs(PS4_POP_COLUMNS)
                        # A copy, so a function that changes its input cannot affect other structures -
                        pops[c] = something(_call_student(calls, lookup, :probability_of_profit, row,
                            _check_probability, contracts, copy(samples[model])), missing);
                    end
                end
            end
            exposure = try
                value = exposure_per_percent(key, row, capital);
                isfinite(value) ? value : missing;
            catch
                missing;
            end
            push!(columns.trade_id, row.trade_id); push!(columns.ticker, row.ticker);
            push!(columns.group, row.group); push!(columns.entry, row.entry);
            push!(columns.expiration, row.expiration); push!(columns.structure, key);
            push!(columns.credit, credit); push!(columns.capital, capital);
            push!(columns.capital_bidask, capital_bidask); push!(columns.built, contracts !== nothing);
            push!(columns.profit, profit); push!(columns.roc, profit / capital);
            push!(columns.profit_bidask, profit_bidask); push!(columns.roc_bidask, profit_bidask / capital_bidask);
            push!(columns.won, ismissing(profit) ? missing : profit > 0);
            for c in values(PS4_POP_COLUMNS)
                push!(getproperty(columns, c), pops[c]);
            end
            push!(columns.stock_return, row.ST / row.S0 - 1); push!(columns.rf_return, r * row.days / PS4_CALENDAR_DAYS);
            push!(columns.exposure, exposure); push!(columns.days, row.days);
            push!(columns.S0, row.S0); push!(columns.ST, row.ST); push!(columns.atm_iv, row.atm_iv);
        end
    end
    return (outcomes = DataFrame(columns), issues = [_call_issues(calls); skipped]);
end

# Summary helpers: an empty selection gives `missing` instead of an error or NaN.
_mean(v) = isempty(v) ? missing : mean(v);
_median(v) = isempty(v) ? missing : median(v);
_worst(v) = isempty(v) ? missing : minimum(v);
_present(v) = collect(Float64, skipmissing(v));

# Rows of one structure whose return on capital is available.
_available(d::AbstractDataFrame) = d[.!ismissing.(d.roc), :];

"""
    summary_table(outcomes, structures) -> DataFrame

Summarize each structure in return-on-capital units, one row per structure in registry order.
Columns: `structure, label, trades` (with a profit), `capital_over_price` (average capital as a
fraction of the share price, over the trades the builder built), `won` (fraction of trades
with a profit above zero), the four average probabilities of profit, `avg_roc, median_roc,
avg_roc_bidask, avg_win, avg_loss` (average return of the winning and the losing trades),
`worst_roc`, `lost_more_than_capital` (number of trades with a return below -100%), the
benchmarks `avg_rf_return` and `avg_stock_return`, `avg_exposure` (over the trades the
builder built), and `avg_profit, avg_profit_bidask` (USD/share). Fractions are decimals. A
value with no trades behind it is `missing`. The capital and exposure come from the supplied
code, so they need only a working builder, not `trade_profit`.
"""
function summary_table(outcomes::DataFrame, structures)::DataFrame
    rows = NamedTuple[];
    for (key, label, _) in structures
        d = outcomes[outcomes.structure .== key, :];
        ok = _available(d);
        made = d[d.built, :];
        roc = Float64.(ok.roc);
        won = Bool.(ok.won);
        n = nrow(ok);
        push!(rows, (structure = key, label = label, trades = n,
            capital_over_price = _mean(made.capital ./ made.S0), won = _mean(won),
            pop_market = _mean(_present(d.pop_market)), pop_hist_drift_iv = _mean(_present(d.pop_hist_drift_iv)),
            pop_rf_hist_vol = _mean(_present(d.pop_rf_hist_vol)), pop_historical = _mean(_present(d.pop_historical)),
            avg_roc = _mean(roc), median_roc = _median(roc), avg_roc_bidask = _mean(_present(d.roc_bidask)),
            avg_win = _mean(roc[won]), avg_loss = _mean(roc[.!won]), worst_roc = _worst(roc),
            lost_more_than_capital = n == 0 ? missing : count(roc .< -1 - PS4_LOSS_MARGIN),
            avg_rf_return = _mean(ok.rf_return), avg_stock_return = _mean(ok.stock_return),
            avg_exposure = _mean(_present(made.exposure)), avg_profit = _mean(Float64.(ok.profit)),
            avg_profit_bidask = _mean(_present(d.profit_bidask))));
    end
    return DataFrame(rows);
end

"""
    worst_trades(outcomes, structures; n=2) -> DataFrame

Each structure's `n` lowest returns on capital, structures in registry order and each
structure's trades worst first. Columns: `structure,
label, trade_id, ticker, entry, expiration, stock_return` (share-price move from entry to
expiration), `atm_iv` (at-the-money implied volatility at entry), `roc`, and `profit`
(USD/share).
"""
function worst_trades(outcomes::DataFrame, structures; n::Int = 2)::DataFrame
    labels = Dict(key => label for (key, label, _) in structures);
    ok = _available(outcomes);
    top = vcat([first(sort(ok[ok.structure .== key, :], [:roc, :trade_id]), n) for (key, _, _) in structures]...);
    return DataFrame(structure = top.structure, label = [labels[s] for s in top.structure],
        trade_id = top.trade_id, ticker = top.ticker, entry = top.entry, expiration = top.expiration,
        stock_return = top.stock_return, atm_iv = top.atm_iv, roc = Float64.(top.roc),
        profit = Float64.(top.profit));
end

"""
    drop_worst_table(outcomes, structures; k=0:5) -> DataFrame

Average return on capital per trade after dropping each structure's `j` worst trades, for
each `j` in `k`. Columns: `structure, label, trades`, then `all_trades` for `j = 0` and
`without_worst_j` for the others. A column is `missing` when no trade would remain.
"""
function drop_worst_table(outcomes::DataFrame, structures; k = 0:5)::DataFrame
    columns = Tuple(Symbol(j == 0 ? "all_trades" : "without_worst_$j") for j in k);
    rows = NamedTuple[];
    for (key, label, _) in structures
        roc = sort(Float64.(_available(outcomes[outcomes.structure .== key, :]).roc));
        averages = Tuple(length(roc) > j ? mean(roc[j+1:end]) : missing for j in k);
        push!(rows, merge((structure = key, label = label, trades = length(roc)),
            NamedTuple{columns}(averages)));
    end
    return DataFrame(rows);
end

# Groups present in the outcomes, in display order.
function _group_order(outcomes::DataFrame)::Vector{String}
    present = unique(outcomes.group);
    return [filter(in(present), PS4_GROUP_ORDER); sort(setdiff(present, PS4_GROUP_ORDER))];
end

"""
    group_table(outcomes, structures) -> DataFrame

Results by ticker group, one row per group and structure. Columns: `group, structure, label,
trades, won, avg_roc, median_roc, avg_stock_return` (the stock's own return over the same
windows), and `avg_profit` (USD/share).
"""
function group_table(outcomes::DataFrame, structures)::DataFrame
    rows = NamedTuple[];
    for g in _group_order(outcomes), (key, label, _) in structures
        ok = _available(outcomes[(outcomes.group .== g) .& (outcomes.structure .== key), :]);
        push!(rows, (group = g, structure = key, label = label, trades = nrow(ok),
            won = _mean(Bool.(ok.won)), avg_roc = _mean(Float64.(ok.roc)),
            median_roc = _median(Float64.(ok.roc)), avg_stock_return = _mean(ok.stock_return),
            avg_profit = _mean(Float64.(ok.profit))));
    end
    return isempty(rows) ? DataFrame(group = String[], structure = Symbol[], label = String[],
        trades = Int[], won = Float64[], avg_roc = Float64[], median_roc = Float64[],
        avg_stock_return = Float64[], avg_profit = Float64[]) : DataFrame(rows);
end

"""
    side_table(outcomes) -> DataFrame

Advanced only: split the short strangle, protected strangle, and iron condor into a put side
and a call side, on the trades where all three parts have a profit. Profits in USD/share add
up: whole = put side + call side, trade by trade. Columns: `structure, part` ("Whole
structure", "Put side", or "Call side"), `part_structure, trades, avg_profit, won` (fraction of
trades with a profit above zero), and `pop_market`. Empty, with these columns, when the
outcomes have no put-side and call-side structures (Standard track).
"""
function side_table(outcomes::DataFrame)::DataFrame
    table = DataFrame(structure = Symbol[], part = String[], part_structure = Symbol[], trades = Int[],
        avg_profit = Union{Missing,Float64}[], won = Union{Missing,Float64}[],
        pop_market = Union{Missing,Float64}[]);
    present = Set(outcomes.structure);
    for (whole, put, call) in PS4_SIDES
        all(in(present), (whole, put, call)) || continue;
        parts = [("Whole structure", whole), ("Put side", put), ("Call side", call)];
        frames = Dict(s => outcomes[(outcomes.structure .== s) .& .!ismissing.(outcomes.profit), :] for (_, s) in parts);
        common = intersect((Set(frames[s].trade_id) for (_, s) in parts)...);
        for (part, s) in parts
            d = frames[s][in.(frames[s].trade_id, Ref(common)), :];
            profit = Float64.(d.profit);
            push!(table, (whole, part, s, nrow(d), _mean(profit), _mean(profit .> 0), _mean(_present(d.pop_market))));
        end
    end
    return table;
end

"""
    benchmark_closes(table, ticker, trades; source) -> Dict{Date,Float64}

Check the daily closes of the market benchmark and return them by date. `table` has the
columns `ticker, date, close`, as in `data/benchmark.csv`; `ticker` is the config's
`benchmark_ticker`. Throws an `ArgumentError` with one sentence when the closes are for
another ticker, or when a trade's entry or expiration date has no positive close. `source`
names the closes in that sentence.
"""
function benchmark_closes(table::DataFrame, ticker::AbstractString, trades::DataFrame;
    source::AbstractString = "The benchmark closes")::Dict{Date,Float64}
    issubset(["ticker", "date", "close"], names(table)) ||
        throw(ArgumentError("$(source) must have the columns ticker, date, and close."));
    found = sort(unique(string.(table.ticker)));
    found == [ticker] || throw(ArgumentError("$(source) are for " *
        "$(isempty(found) ? "no ticker" : join(found, " and ")), but benchmark_ticker in the config file is $(ticker)."));
    closes = Dict{Date,Float64}(d => Float64(c) for (d, c) in zip(table.date, table.close)
        if d isa Date && c isa Real && isfinite(c) && c > 0);
    for d in sort(unique([trades.entry; trades.expiration]))
        haskey(closes, d) || throw(ArgumentError("$(source) have no $(ticker) close on $(d), " *
            "the entry or expiration date of a trade."));
    end
    return closes;
end

# Labels of the benchmark rows, in display order.
_benchmark_labels(ticker::AbstractString) = ["Cash at the risk-free rate (same days)",
    "$(ticker), bought and held (same days)", "The stock itself, bought and held (same days)"];

"""
    benchmark_table(outcomes, closes, ticker) -> DataFrame

What the same money would have earned over the same days as each trade, without options: in
cash at the risk-free rate (`rf_return`), in the market benchmark `ticker` bought at the close
on the entry date and sold at the close on the expiration date (`closes` by date, from
`benchmark_closes`), and in the trade's own stock (`stock_return`). Each trade in `outcomes`
counts once. Columns: `benchmark` (the row label), `trades`, `avg_return`, and
`median_return`, per trade, as decimal fractions; `missing` when there are no trades.
"""
function benchmark_table(outcomes::DataFrame, closes::AbstractDict, ticker::AbstractString)::DataFrame
    windows = unique(outcomes[:, [:trade_id, :entry, :expiration, :rf_return, :stock_return]], :trade_id);
    market = Float64[closes[x] / closes[e] - 1 for (e, x) in zip(windows.entry, windows.expiration)];
    returns = [Float64.(windows.rf_return), market, Float64.(windows.stock_return)];
    return DataFrame(benchmark = _benchmark_labels(ticker), trades = fill(nrow(windows), 3),
        avg_return = [_mean(v) for v in returns], median_return = [_median(v) for v in returns]);
end

"""
    write_table_csv(path, table) -> Nothing

Write a table as CSV at full Float64 precision, every cell quoted. Missing values are written
as UNAVAILABLE. A table without rows writes only its header.
"""
function write_table_csv(path::AbstractString, table::DataFrame)::Nothing
    cell(x) = "\"" * replace(ismissing(x) ? "UNAVAILABLE" : string(x), '"' => "\"\"") * "\"";
    open(path, "w") do io
        println(io, join(names(table), ','));
        for row in eachrow(table)
            println(io, join([cell(row[c]) for c in names(table)], ','));
        end
    end
    return nothing;
end

# Display formats: rates and returns in percent with one decimal, profits in USD/share.
_shown(x::Real, digits::Int) = (v = round(x; digits = digits); v == 0 ? zero(v) : v);
# `_text` columns align left; every other format, `_count` included, aligns right.
_text(x) = ismissing(x) ? "UNAVAILABLE" : string(x);
_count(x) = ismissing(x) ? "UNAVAILABLE" : string(x);
_rate(x) = ismissing(x) ? "UNAVAILABLE" : @sprintf("%.1f%%", _shown(100 * x, 1));
_return(x) = ismissing(x) ? "UNAVAILABLE" : x isa AbstractString ? x : @sprintf("%+.1f%%", _shown(100 * x, 1));
_usd(x) = ismissing(x) ? "UNAVAILABLE" : @sprintf("%+.2f", _shown(x, 2));

# The summary for display: a structure with results but no winning (or no losing) trade shows
# "none" for its average win (or loss), not UNAVAILABLE.
function _summary_view(summary::DataFrame)::DataFrame
    view = copy(summary);
    for c in (:avg_win, :avg_loss)
        view[!, c] = Any[n > 0 && ismissing(v) ? "none" : v for (n, v) in zip(view.trades, view[!, c])];
    end
    return view;
end

# A displayed table: headers, formatted rows, and the right-aligned (numeric) columns.
function _display(table::AbstractDataFrame, spec)
    headers = [h for (h, _, _) in spec];
    rows = [[f(row[c]) for (_, c, f) in spec] for row in eachrow(table)];
    right = [j for (j, (_, _, f)) in enumerate(spec) if f !== _text];
    return (headers = headers, rows = rows, right = right);
end

# Write one Markdown table, with numeric columns aligned right.
function _markdown_table(io, shown)
    println(io, "| ", join(shown.headers, " | "), " |");
    println(io, "|", join([j in shown.right ? " --: " : " :-- " for j in eachindex(shown.headers)], "|"), "|");
    for row in shown.rows
        println(io, "| ", join(row, " | "), " |");
    end
    isempty(shown.rows) && println(io, "\nNo rows. See the calculations that could not run.");
    println(io);
    return nothing;
end

# The headline column. A trade lasts about a month, and the header says so.
const _HEADLINE = "Avg return on capital per trade (about 1 month)";

# Columns of the displayed tables, as (header, column, format). The headline table adds the
# benchmark rows (`_headline_display`).
const _RETURN_COLUMNS = [("Structure", :label, _text), ("Trades", :trades, _count), ("Won", :won, _rate),
    (_HEADLINE, :avg_roc, _return), ("Median", :median_roc, _return)];
const _LOSS_COLUMNS = [("Structure", :label, _text), ("Capital (% of share price)", :capital_over_price, _rate),
    ("Avg win", :avg_win, _return), ("Avg loss", :avg_loss, _return), ("Worst trade", :worst_roc, _return),
    ("Lost more than capital", :lost_more_than_capital, _count),
    ("Change in value per 1% stock rise", :avg_exposure, _return)];
const _FILL_COLUMNS = [("Structure", :label, _text), (_HEADLINE, :avg_roc, _return),
    ("Avg return at bid/ask fills", :avg_roc_bidask, _return), ("Avg profit (USD/share)", :avg_profit, _usd),
    ("Avg profit at bid/ask fills (USD/share)", :avg_profit_bidask, _usd)];
const _POP_COLUMNS = [("Structure", :label, _text), ("Won", :won, _rate),
    [(PS4_POP_LABELS[j], c, _rate) for (j, c) in enumerate(values(PS4_POP_COLUMNS))]...];
const _WORST_COLUMNS = [("Structure", :label, _text), ("Ticker", :ticker, _text), ("Entry", :entry, _text),
    ("Expiration", :expiration, _text), ("Share-price move", :stock_return, _return),
    ("ATM implied vol", :atm_iv, _rate), ("Return on capital", :roc, _return)];
const _SIDE_COLUMNS = [("Structure", :label, _text), ("Part", :part, _text), ("Trades", :trades, _count),
    ("Avg profit (USD/share)", :avg_profit, _usd), ("Won", :won, _rate),
    ("Model POP: market (r, IV)", :pop_market, _rate)];

# The sensitivity table: one column per number of dropped trades.
function _drop_display(table::DataFrame)
    spec = Any[("Structure", :label, _text)];
    for c in propertynames(table)[4:end]
        j = c == :all_trades ? 0 : parse(Int, last(split(string(c), '_')));
        push!(spec, (j == 0 ? "All trades" : "Without the worst $j", c, _return));
    end
    return _display(table, spec);
end

# The group table: one row per group, with the average return of each structure as a column.
function _group_display(groups::DataFrame, outcomes::DataFrame, structures)
    headers = vcat(["Group", "Trades", "Stock's own return"], [label for (_, label, _) in structures]);
    rows = Vector{String}[];
    for g in unique(groups.group)
        windows = unique(outcomes[outcomes.group .== g, [:trade_id, :stock_return]]);
        cells = [g, string(nrow(windows)), _return(_mean(windows.stock_return))];
        for (key, _, _) in structures
            hit = groups[(groups.group .== g) .& (groups.structure .== key), :];
            push!(cells, _return(nrow(hit) == 1 ? hit.avg_roc[1] : missing));
        end
        push!(rows, cells);
    end
    return (headers = headers, rows = rows, right = collect(2:length(headers)));
end

# Labels for the side table: the part's own structure after "Put side" or "Call side".
function _side_rows(sides::DataFrame)
    labels = Dict(key => label for (key, label, _) in ADVANCED_STRUCTURES);
    return DataFrame(label = [labels[s] for s in sides.structure],
        part = [p == "Whole structure" ? p : "$(p): $(lowercase(labels[s]))" for (p, s) in zip(sides.part, sides.part_structure)],
        trades = sides.trades, avg_profit = sides.avg_profit, won = sides.won, pop_market = sides.pop_market);
end

# The headline table of Report.md: one row per structure, then the benchmark rows under their
# own heading, with — in the Won column.
function _headline_display(summary::DataFrame, benchmarks::DataFrame)
    shown = _display(summary, _RETURN_COLUMNS);
    rows = Vector{String}[shown.rows; [["**Benchmarks (not option trades)**", "", "", "", ""]]];
    for b in eachrow(benchmarks)
        push!(rows, [b.benchmark, _count(b.trades), "—", _return(b.avg_return), _return(b.median_return)]);
    end
    return (headers = shown.headers, rows = rows, right = shown.right);
end

# A benchmark label longer than this breaks before "(same days)" in the terminal, so the
# headline table fits in 78 columns.
const _TERMINAL_LABEL_WIDTH = 33;

# The terminal headline: the structures with results, then a rule and the benchmark rows. The
# long header and labels break across lines.
function _terminal_headline(ready::DataFrame, benchmarks::DataFrame)
    headers = ["Structure", "Won", "Avg return on capital\nper trade\n(about 1 month)", "Median"];
    rows = Vector{String}[[r.label, _rate(r.won), _return(r.avg_roc), _return(r.median_roc)] for r in eachrow(ready)];
    rules = isempty(rows) ? Int[] : [length(rows) + 1];
    for b in eachrow(benchmarks)
        label = textwidth(b.benchmark) > _TERMINAL_LABEL_WIDTH ?
            replace(b.benchmark, " (same days)" => "\n  (same days)") : b.benchmark;
        push!(rows, [label, "—", _return(b.avg_return), _return(b.median_return)]);
    end
    return (headers = headers, rows = rows, right = [2, 3, 4], rules = rules);
end

# The note under the headline table, in Report.md and in the terminal.
_headline_note(ticker::AbstractString) = "Every row shows returns over one trade of about 30 days, not per " *
    "year. The benchmark rows are what the same money would have earned over the same days: in cash at the " *
    "risk-free rate, in $(ticker), or in the stock itself ($(ticker) and the stock bought at the close on the " *
    "entry date and sold at the close on the expiration date).";

# One sentence describing the trades, and one listing the settings.
function _run_description(track::AbstractString, trades::DataFrame, config, config_name::AbstractString)
    fill_text = config.fill == "mid" ? "filled at the mid price" :
        "sold at the bid and bought at the ask";
    days = nrow(trades) == 0 ? "" : " held to expiration, $(minimum(trades.days)) to $(maximum(trades.days)) days later";
    dates = nrow(trades) == 0 ? "" : ", entered from $(minimum(trades.entry)) to $(maximum(trades.entry)) and";
    trades_text = "$(titlecase(track)) track. $(nrow(trades)) trades on $(length(unique(trades.ticker))) tickers$(dates)$(days). " *
        "Each trade uses one contract per leg, $(fill_text), and counts equally in every average.";
    paths = replace(string(config.number_of_paths), r"(?<=\d)(?=(\d{3})+$)" => ",");
    settings = "Settings ($(config_name)): short legs near $(@sprintf("%.2f", config.short_delta)) delta, wings near " *
        "$(@sprintf("%.2f", config.wing_delta)) delta, expirations near $(config.target_dte) days (within $(config.dte_window)), " *
        "risk-free rate $(@sprintf("%.2f", 100 * config.risk_free_rate))% per year, margin rate " *
        "$(@sprintf("%.0f", 100 * config.margin_rate))% with a $(@sprintf("%.0f", 100 * config.margin_floor))% floor, " *
        "$(paths) simulated prices per trade and model, seed $(config.seed), market benchmark $(config.benchmark_ticker).";
    return (trades = trades_text, settings = settings, benchmark = config.benchmark_ticker);
end

# The note on losses larger than the capital, in Report.md and in the terminal.
const _LOSS_NOTE = "Lost more than capital: the number of trades whose loss was larger than the capital set " *
    "aside, a return on capital below -100%. Only a structure with a naked short option can do this; " *
    "a credit spread or an iron condor can lose at most its capital.";

# Plain-language notes printed under the summary tables.
const _SUMMARY_NOTES = [
    "A trade lasts about a month, so every return here is for one trade, not for a year.",
    "Won: the share of trades with a profit above zero at expiration.",
    _LOSS_NOTE,
    "Change in value per 1% stock rise: how much a small rise in the stock changes the trade's value, as a " *
        "share of its capital, from the option deltas at entry. It measures exposure to the direction of the " *
        "stock. For structures with short options on both sides it is near zero, because the two sides " *
        "offset; their risk is a large move in either direction, which the worst trades show.",
    "Bid/ask fills: the same trades, with short legs sold at the bid and long legs bought at the ask, and " *
        "the capital recomputed at those prices. The quotes come from an indicative data feed, so read this as what a spread of that size " *
        "would cost, not as prices a trader paid.",
    "Avg profit (USD/share) is a secondary unit: expensive stocks dominate averages in dollars."];

# The Report.md text.
function _report_markdown(title, track, description, result, tables, structures)::String
    io = IOBuffer();
    println(io, "# ", title, "\n");
    println(io, description.trades, "\n");
    println(io, description.settings, "\n");
    isempty(result.issues) || println(io, "Some calculations could not run. They show UNAVAILABLE; ",
        "the last section says why.\n");

    println(io, "## 1. Summary: return on capital per trade\n");
    println(io, "Return on capital is a trade's profit at expiration divided by the capital a broker ",
        "would require you to set aside for it.\n");
    println(io, "### Return on capital and benchmarks\n");
    summary = _summary_view(tables.summary);
    _markdown_table(io, _headline_display(summary, tables.benchmarks));
    println(io, _headline_note(description.benchmark), "\n");
    println(io, "### Wins, losses, and capital\n");
    _markdown_table(io, _display(summary, _LOSS_COLUMNS));
    println(io, "### Fill prices and dollars\n");
    _markdown_table(io, _display(summary, _FILL_COLUMNS));
    println(io, "How to read these tables:\n");
    for note in _SUMMARY_NOTES
        println(io, "- ", note);
    end
    println(io);
    println(io, "### Probability of profit: four models and what happened\n");
    _markdown_table(io, _display(summary, _POP_COLUMNS));
    println(io, "Each model simulates the share price at expiration as geometric Brownian motion and ",
        "counts the share of simulated prices with a profit above zero. r is the risk-free rate and IV the ",
        "at-the-money implied volatility at entry. The historical drift and vol come from the year of daily ",
        "closes before entry. Won is what happened.\n");

    println(io, "## 2. The worst trades\n");
    println(io, "Each structure's 2 lowest returns on capital, worst first. Compare the structures that ",
        "buy protection with those that do not.\n");
    _markdown_table(io, _display(tables.worst, _WORST_COLUMNS));
    println(io, "Share-price move: the change from the entry price to the close on the expiration date. ",
        "ATM implied vol: the at-the-money implied volatility at entry, quoted per year as usual.\n");

    println(io, "## 3. Dropping the worst trades\n");
    println(io, "Average return on capital per trade after removing each structure's worst trades.\n");
    _markdown_table(io, _drop_display(tables.drop_worst));

    println(io, "## 4. Results by ticker group\n");
    println(io, "Average return on capital per trade within each group. Stock's own return is the ",
        "average share-price change over the same trade windows.\n");
    _markdown_table(io, _group_display(tables.groups, result.outcomes, structures));

    if track == "advanced"
        println(io, "## 5. Put side and call side\n");
        println(io, "Each structure split into a put side and a call side, on the same trades. ",
            "Profits in USD/share add up: the put side plus the call side equals the whole structure, ",
            "trade by trade. Returns on capital do not add, because each part has its own capital.\n");
        _markdown_table(io, _display(_side_rows(tables.sides), _SIDE_COLUMNS));
    end

    if !isempty(result.issues)
        println(io, "## Calculations that could not run\n");
        for issue in result.issues
            println(io, "- ", replace(issue, '\n' => " "));
        end
        println(io);
    end
    return String(take!(io));
end

# The terminal summary: the headline tables and where to find the rest.
function _print_terminal_report(title, description, result, tables, report_path)
    print_terminal_section(title * ": return on capital per trade"; major = true);
    print_terminal_text(description.trades);
    # Structures without results are named in one line, so the tables stay narrow. The
    # benchmark rows need no student function, so they show from the first run -
    summary = _summary_view(tables.summary);
    ready = summary[summary.trades .> 0, :];
    shown = _terminal_headline(ready, tables.benchmarks);
    print_terminal_section("Return on capital per trade");
    print_terminal_table(shown.headers, shown.rows; right_columns = shown.right, rules = shown.rules);
    println();
    print_terminal_text(_headline_note(description.benchmark));
    if nrow(ready) > 0
        shown = _display(ready, [("Structure", :label, _text), ("Avg win", :avg_win, _return),
            ("Avg loss", :avg_loss, _return), ("Worst trade", :worst_roc, _return),
            ("Lost more than capital", :lost_more_than_capital, _count)]);
        print_terminal_section("Wins and losses");
        print_terminal_table(shown.headers, shown.rows; right_columns = shown.right);
        println();
        print_terminal_text(_LOSS_NOTE);
    end
    # A structure whose builder never worked has no results at all; one without profits yet
    # still has its capital and, when probability_of_profit works, its probabilities -
    built = [any(result.outcomes.built[result.outcomes.structure .== key]) for key in summary.structure];
    waiting = summary.label[.!built];
    unpriced = summary.label[built .& (summary.trades .== 0)];
    isempty(waiting) && isempty(unpriced) || println();
    isempty(waiting) || print_terminal_text("UNAVAILABLE (no results yet): " * join(waiting, ", ") *
        ". The calculations that could not run are listed below.");
    isempty(unpriced) || print_terminal_text("Returns on capital UNAVAILABLE (no profit results yet): " *
        join(unpriced, ", ") * ". The full report shows the results they do have, such as the capital.");
    if !isempty(result.issues)
        print_terminal_section("Calculations that could not run");
        for issue in result.issues
            print_terminal_text(issue; prefix = "- ", continuation = "  ");
        end
    end
    println();
    print_terminal_text("Full report, with benchmarks, probabilities, the worst trades, and results " *
        "by group: $(report_path)");
    return nothing;
end

# The benchmark closes saved as CSV, read relative to root unless the path is absolute.
function _read_benchmark(root::AbstractString, path::AbstractString)::DataFrame
    full = joinpath(root, path);
    isfile(full) || throw(ArgumentError("The benchmark file $(path) is missing; restore it from the PS4 release."));
    return CSV.read(full, DataFrame; stringtype = String);
end

"""
    print_options_report(track, root; output_directory, config_path, trades_path,
        parameters_path, benchmark_path, title, report_name, trades, parameters,
        benchmark) -> NamedTuple

Run the selected student functions over every trade, print the headline tables, and write
the report and its CSV tables to `output_directory`: `Report.md` (or `report_name`),
`outcomes.csv`, `summary.csv`, `benchmarks.csv`, `worst-trades.csv`, `drop-worst.csv`,
`groups.csv`, and `sides.csv` (header only on the Standard track). Every path,
`output_directory` (default "results") included, is relative to `root` unless absolute,
whatever the working directory. When `trades`, `parameters`, or `benchmark` (the market
benchmark's daily closes, columns `ticker, date, close`) is a `DataFrame`, it is used instead
of the file. The benchmark closes must be for the config's `benchmark_ticker` and cover every
entry and expiration date; otherwise the report stops with a one-sentence `ArgumentError`.
Unfinished student functions show UNAVAILABLE rather than stopping the report. CSV fractions
are decimals; displayed tables use percentages.

# Returns
`(outcomes, issues, tables, report, seconds)`: the outcomes and issues from
`evaluate_trades`, the tables `(summary, worst, drop_worst, groups, sides, benchmarks)`, the
path of the written report, and the run time in seconds.
"""
function print_options_report(track::AbstractString, root::AbstractString;
    output_directory::AbstractString = "results",
    config_path::AbstractString = "config/defaults.toml",
    trades_path::AbstractString = "data/trades.csv",
    parameters_path::AbstractString = "data/parameters.csv",
    benchmark_path::AbstractString = "data/benchmark.csv",
    title::AbstractString = "PS4 report", report_name::AbstractString = "Report.md",
    trades::Union{Nothing,DataFrame} = nothing,
    parameters::Union{Nothing,DataFrame} = nothing,
    benchmark::Union{Nothing,DataFrame} = nothing)::NamedTuple
    started = time();
    track = lowercase(String(track));
    output_directory = isabspath(output_directory) ? output_directory : joinpath(root, output_directory);
    structures = ps4_structures(track);
    config = load_config(joinpath(root, config_path));
    trades = trades === nothing ? load_trade_table(joinpath(root, trades_path)) : trades;
    parameters = parameters === nothing ? CSV.read(joinpath(root, parameters_path), DataFrame) : parameters;
    # Check the benchmark closes before the student functions run, so a bad file stops at once -
    closes = benchmark === nothing ?
        benchmark_closes(_read_benchmark(root, benchmark_path), config.benchmark_ticker, trades;
            source = "The benchmark closes in $(benchmark_path)") :
        benchmark_closes(benchmark, config.benchmark_ticker, trades);

    result = evaluate_trades(track, trades, parameters, config);
    outcomes = result.outcomes;
    tables = (summary = summary_table(outcomes, structures), worst = worst_trades(outcomes, structures),
        drop_worst = drop_worst_table(outcomes, structures), groups = group_table(outcomes, structures),
        sides = side_table(outcomes), benchmarks = benchmark_table(outcomes, closes, config.benchmark_ticker));

    mkpath(output_directory);
    for (name, table) in (("outcomes", outcomes), ("summary", tables.summary), ("benchmarks", tables.benchmarks),
            ("worst-trades", tables.worst), ("drop-worst", tables.drop_worst), ("groups", tables.groups),
            ("sides", tables.sides))
        write_table_csv(joinpath(output_directory, name * ".csv"), table);
    end
    description = _run_description(track, trades, config, config_path);
    report_path = joinpath(output_directory, report_name);
    write(report_path, _report_markdown(title, track, description, result, tables, structures));
    shown_path = startswith(abspath(report_path), abspath(root)) ? relpath(report_path, root) : report_path;
    _print_terminal_report(title, description, result, tables, shown_path);
    return (outcomes = outcomes, issues = result.issues, tables = tables, report = report_path,
        seconds = time() - started);
end
