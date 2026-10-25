# PS4 settings: read a TOML settings file and check every value.
using TOML, SHA

# Tickers in the course options archive.
const PS4_ARCHIVE_TICKERS = ["AAPL", "ABBV", "AMD", "AMGN", "AVGO", "BAC", "BMY", "CVX",
    "GOOG", "GS", "INTC", "IWM", "JNJ", "JPM", "LLY", "META", "MRNA", "MSFT", "MU", "NVDA",
    "OXY", "PFE", "QCOM", "QQQ", "SPY", "TGT", "UNH", "UPS", "WFC", "WMT", "XOM"];

# Archive tickers with no course daily price history, so their models cannot be estimated.
const PS4_NO_PRICE_HISTORY = ["IWM", "META"];

# Archive tickers that also have course daily price history.
const PS4_PRICE_HISTORY_TICKERS = [t for t in PS4_ARCHIVE_TICKERS if !(t in PS4_NO_PRICE_HISTORY)];

"""
    config_setting(settings::Dict, key::String, T::Type)

Read one setting from a parsed TOML file and convert it to type `T`.

### Arguments

- `settings`: The parsed TOML file, from `TOML.parsefile`.
- `key`: The name of the setting.
- `T`: The type the setting must have, such as `Float64`, `Int`, or `String`.

### Returns

- The setting converted to `T`. Throws an `ArgumentError` when the setting is
  missing or cannot be converted. An integer setting must be written as a whole
  number (`30`, not `30.0`).
"""
function config_setting(settings::Dict, key::String, T::Type)

    # Is the setting in the file?
    if !haskey(settings, key)
        throw(ArgumentError("Setting '$key' is missing from the config file."));
    end
    value = settings[key];

    # Integer settings must be written as whole numbers -
    if T <: Integer && !(value isa Integer)
        throw(ArgumentError("Setting '$key' must be of type $T."));
    end

    # Convert the value to T -
    try
        return T(value);
    catch
        throw(ArgumentError("Setting '$key' must be of type $T."));
    end
end

"""
    check_setting(ok::Bool, message::String)

Throw an `ArgumentError` with `message` when a setting fails a check.

### Arguments

- `ok`: The result of the check.
- `message`: A one-sentence explanation shown when the check fails.

### Returns

- `nothing` when the check passes.
"""
function check_setting(ok::Bool, message::String)
    if !ok
        throw(ArgumentError(message));
    end
    return nothing;
end

"""
    load_config(path::AbstractString) -> NamedTuple

Read a TOML settings file and check every value.

### Arguments

- `path`: Location of the settings file, such as `config/defaults.toml`.

### Returns

- A `NamedTuple` with the fields `risk_free_rate`, `fill`, `margin_rate`,
  `margin_floor`, `number_of_paths`, `seed`, `short_delta`, `wing_delta`,
  `target_dte`, `dte_window`, `quote_screen_multiple`, `quote_screen_min_width`,
  `history_window`, `tickers`, and `benchmark_ticker`. Throws an
  `ArgumentError` with a one-sentence message when a setting is missing or
  invalid.
"""
function load_config(path::AbstractString)::NamedTuple

    # Read the file -
    settings = nothing;
    try
        settings = TOML.parsefile(path);
    catch
        throw(ArgumentError("The config file could not be read as TOML."));
    end

    # Read each setting with its type -
    risk_free_rate = config_setting(settings, "risk_free_rate", Float64);
    fill = config_setting(settings, "fill", String);
    margin_rate = config_setting(settings, "margin_rate", Float64);
    margin_floor = config_setting(settings, "margin_floor", Float64);
    number_of_paths = config_setting(settings, "number_of_paths", Int);
    seed = config_setting(settings, "seed", Int);
    short_delta = config_setting(settings, "short_delta", Float64);
    wing_delta = config_setting(settings, "wing_delta", Float64);
    target_dte = config_setting(settings, "target_dte", Int);
    dte_window = config_setting(settings, "dte_window", Int);
    quote_screen_multiple = config_setting(settings, "quote_screen_multiple", Float64);
    quote_screen_min_width = config_setting(settings, "quote_screen_min_width", Float64);
    history_window = config_setting(settings, "history_window", Int);

    # The tickers are a list of names -
    if !haskey(settings, "tickers") || !(settings["tickers"] isa AbstractVector)
        throw(ArgumentError("Setting 'tickers' must be a list of ticker names."));
    end
    tickers = String[];
    for ticker in settings["tickers"]
        push!(tickers, string(ticker));
    end
    benchmark_ticker = config_setting(settings, "benchmark_ticker", String);

    # Check that each value makes sense -
    check_setting(risk_free_rate >= 0, "The risk_free_rate must not be negative.");
    check_setting(fill in ("mid", "bidask"), "The fill must be \"mid\" or \"bidask\".");
    check_setting(margin_rate > 0, "The margin_rate must be positive.");
    check_setting(margin_floor > 0, "The margin_floor must be positive.");
    check_setting(number_of_paths >= 1000, "The number_of_paths must be at least 1000.");
    check_setting(0 < wing_delta < short_delta < 0.5,
        "The deltas must satisfy 0 < wing_delta < short_delta < 0.5.");
    check_setting(dte_window >= 1, "The dte_window must be at least 1 day.");
    check_setting(target_dte > dte_window, "The target_dte must be larger than dte_window.");
    check_setting(quote_screen_multiple > 1, "The quote_screen_multiple must be larger than 1.");
    check_setting(quote_screen_min_width >= 0, "The quote_screen_min_width must not be negative.");
    check_setting(history_window >= 20, "The history_window must be at least 20 days.");
    check_setting(!isempty(tickers), "The tickers list must not be empty.");
    check_setting(length(unique(tickers)) == length(tickers), "The tickers list must not repeat a ticker.");

    # Every ticker must be in the archive and have course price history -
    for ticker in tickers
        check_setting(ticker in PS4_ARCHIVE_TICKERS,
            "Ticker '$(ticker)' is not in the course options archive.");
    end
    for ticker in tickers
        check_setting(ticker in PS4_PRICE_HISTORY_TICKERS,
            "Ticker '$(ticker)' has no course price history, so its models cannot be estimated.");
    end

    # The benchmark needs only the archive's daily closes, not course price history -
    check_setting(benchmark_ticker in PS4_ARCHIVE_TICKERS,
        "The benchmark_ticker '$(benchmark_ticker)' is not in the course options archive.");

    return (risk_free_rate = risk_free_rate, fill = fill, margin_rate = margin_rate,
        margin_floor = margin_floor, number_of_paths = number_of_paths, seed = seed,
        short_delta = short_delta, wing_delta = wing_delta, target_dte = target_dte,
        dte_window = dte_window, quote_screen_multiple = quote_screen_multiple,
        quote_screen_min_width = quote_screen_min_width, history_window = history_window,
        tickers = tickers, benchmark_ticker = benchmark_ticker);
end

"""
    config_hash(path::AbstractString) -> String

Fingerprint a settings file, so a run records exactly which settings it used.

### Arguments

- `path`: Location of the settings file.

### Returns

- The SHA-256 digest of the file as a 64-character hex string. Windows line
  endings are changed to `\\n` first, so a copy saved on Windows has the same
  fingerprint.
"""
function config_hash(path::AbstractString)::String

    # Read the file and use Unix line endings -
    text = read(path, String);
    text = replace(text, "\r\n" => "\n");

    # Hash the text -
    return bytes2hex(sha256(text));
end
