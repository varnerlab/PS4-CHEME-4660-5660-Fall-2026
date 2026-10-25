# PS4 price models: estimate a drift and a volatility from the closes before each entry,
# then simulate the share price at expiration under four geometric Brownian motion models.
using DataFrames, Dates, Random, Statistics, VLQuantitativeFinancePackage

# Trading days per year, used to annualize daily log returns.
const PS4_TRADING_DAYS = 252;

# Calendar days per year, used for the time to expiration and the simulation time step.
const PS4_CALENDAR_DAYS = 365;

"""
    price_history(tickers::Vector{String}) -> Dict{String,DataFrame}

Collect the daily closes of each ticker: the course market data for 2025 and
2026, then the options archive's closes after the last course date.

### Arguments

- `tickers`: The tickers to load.

### Returns

- A dictionary from ticker to a `DataFrame` with columns `date::Date` and
  `close::Float64`, sorted by date with one row per date.
"""
function price_history(tickers::Vector{String})::Dict{String,DataFrame}

    # Initialize -
    course_2025 = MyTestingMarketDataSet(year = 2025)["dataset"];
    course_2026 = MyTestingMarketDataSet(year = 2026)["dataset"];
    history = Dict{String,DataFrame}();

    for ticker in tickers

        # Course closes for 2025 and 2026 -
        prices = DataFrame(date = Date[], close = Float64[]);
        for course in (course_2025, course_2026)
            data = course[ticker];
            append!(prices, DataFrame(date = Date.(data.timestamp), close = Float64.(data.close)));
        end
        prices = sort(unique(prices, :date), :date);
        last_course_date = maximum(prices.date);

        # Archive closes after the last course date -
        archive = MyOptionsEODUnderlyingDataSet(ticker = ticker);
        extra = DataFrame(date = Date.(archive.date), close = Float64.(archive.close));
        extra = extra[extra.date .> last_course_date, :];
        extra = sort(unique(extra, :date), :date);

        history[ticker] = vcat(prices, extra);
    end

    return history;
end

"""
    trailing_parameters(closes::Vector{Float64}) -> NamedTuple

Estimate the annualized growth rate and volatility of the log price from a
series of daily closes.

### Arguments

- `closes`: Consecutive daily closes, oldest first.

### Returns

- `(ĝ, σ̂, μ)`: the mean daily log return times 252, the standard deviation of
  the daily log returns times the square root of 252, and the drift
  `μ = ĝ + σ̂^2/2`.
"""
function trailing_parameters(closes::Vector{Float64})::NamedTuple

    returns = diff(log.(closes));
    ĝ = mean(returns) * PS4_TRADING_DAYS;
    σ̂ = std(returns) * sqrt(PS4_TRADING_DAYS);
    μ = ĝ + σ̂^2 / 2;

    return (ĝ = ĝ, σ̂ = σ̂, μ = μ);
end

"""
    trade_parameters(trades::DataFrame, history, config::NamedTuple) -> DataFrame

Estimate the trailing parameters of every trade from the
`config.history_window + 1` closes before its entry date.

### Arguments

- `trades`: The trade table.
- `history`: The closes of each ticker, from `price_history`.
- `config`: The settings from `load_config`.

### Returns

- A `DataFrame` with columns `trade_id`, `ĝ`, `σ̂`, `μ`, and `n_obs` (the
  number of daily returns used).
"""
function trade_parameters(trades::DataFrame, history, config::NamedTuple)::DataFrame

    # Initialize -
    window = config.history_window;
    parameters = DataFrame(trade_id = Int[], ĝ = Float64[], σ̂ = Float64[], μ = Float64[], n_obs = Int[]);

    for row in eachrow(trades)

        # The closes before the entry date -
        prices = history[row.ticker];
        before = prices[prices.date .< row.entry, :];
        if nrow(before) < window + 1
            throw(ArgumentError("$(row.ticker) has only $(nrow(before)) closes before $(row.entry)"));
        end

        # Estimate from the last window + 1 of them -
        p = trailing_parameters(before.close[(end - window):end]);
        push!(parameters, (row.trade_id, p.ĝ, p.σ̂, p.μ, window));
    end

    return parameters;
end

"""
    gbm_models(row, params_row, r::Float64) -> NamedTuple

Build the four geometric Brownian motion models of a trade.

### Arguments

- `row`: The trade row, with `atm_iv`.
- `params_row`: The trade's row from `trade_parameters`, with `σ̂` and `μ`.
- `r`: The risk-free rate.

### Returns

- A `NamedTuple` with `market` (drift `r`, volatility `atm_iv`),
  `hist_drift_iv` (drift `μ`, volatility `atm_iv`), `rf_hist_vol` (drift `r`,
  volatility `σ̂`), and `historical` (drift `μ`, volatility `σ̂`).
"""
function gbm_models(row, params_row, r::Float64)::NamedTuple

    market = build(MyGeometricBrownianMotionEquityModel, (μ = r, σ = row.atm_iv));
    hist_drift_iv = build(MyGeometricBrownianMotionEquityModel, (μ = params_row.μ, σ = row.atm_iv));
    rf_hist_vol = build(MyGeometricBrownianMotionEquityModel, (μ = r, σ = params_row.σ̂));
    historical = build(MyGeometricBrownianMotionEquityModel, (μ = params_row.μ, σ = params_row.σ̂));

    return (market = market, hist_drift_iv = hist_drift_iv, rf_hist_vol = rf_hist_vol,
        historical = historical);
end

"""
    expiration_prices(model, row, config::NamedTuple) -> Vector{Float64}

Simulate the share price at expiration under one model. The random number
generator is reseeded with `config.seed + row.trade_id` first, so every model of
a trade uses the same random draws.

### Arguments

- `model`: A geometric Brownian motion model, from `gbm_models`.
- `row`: The trade row, with `trade_id`, `days`, and `S0`.
- `config`: The settings from `load_config`.

### Returns

- `config.number_of_paths` simulated prices at expiration (USD/share).
"""
function expiration_prices(model, row, config::NamedTuple)::Vector{Float64}

    # Initialize -
    T = row.days / PS4_CALENDAR_DAYS;
    Δt = 1 / PS4_CALENDAR_DAYS;
    Random.seed!(config.seed + row.trade_id);

    # Simulate daily steps to expiration; column 1 of paths is time -
    paths = VLQuantitativeFinancePackage.sample(model, (T₁ = 0.0, T₂ = T, Δt = Δt, Sₒ = row.S0);
        number_of_paths = config.number_of_paths);

    # Keep the last row, the prices at expiration -
    return Vector{Float64}(paths[end, 2:end]);
end

"""
    endpoint_samples(models::NamedTuple, row, config::NamedTuple) -> NamedTuple

Simulate the share price at expiration under each of a trade's four models.

### Arguments

- `models`: The models from `gbm_models`.
- `row`: The trade row, with `trade_id`, `days`, and `S0`.
- `config`: The settings from `load_config`.

### Returns

- A `NamedTuple` with the same keys as `models`, each a `Vector{Float64}` of
  prices at expiration from `expiration_prices`.
"""
function endpoint_samples(models::NamedTuple, row, config::NamedTuple)::NamedTuple

    return (market = expiration_prices(models.market, row, config),
        hist_drift_iv = expiration_prices(models.hist_drift_iv, row, config),
        rf_hist_vol = expiration_prices(models.rf_hist_vol, row, config),
        historical = expiration_prices(models.historical, row, config));
end
