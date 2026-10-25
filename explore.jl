# Optional and ungraded. Edit config/explore.toml, then run from the PS4 folder:
#   julia --project=. --startup-file=no explore.jl
# Reruns the experiment with your settings and your own functions (the TRACK.txt track).
# Results are written to results/exploration/Exploration.md; nothing here is submitted.

const _ROOT = @__DIR__;

"""
    load_message(caught) -> String

Explain in one line why loading stopped: the file and line, and the first line
of the error.

### Arguments

- `caught`: The error thrown while loading `Include.jl`.

### Returns

The message to print. An `ArgumentError` from the setup checks (such as a
wrong TRACK.txt) is returned as it is.
"""
function load_message(caught)::String

    # An error inside an included file is wrapped in a LoadError; keep the innermost file and line -
    place = "";
    while caught isa LoadError
        place = " ($(relpath(caught.file, _ROOT)), line $(caught.line))";
        caught = caught.error;
    end
    if caught isa ArgumentError
        return caught.msg;
    end

    # A syntax error names the problem after the ── mark; any other error gives its first line -
    text = sprint(showerror, caught);
    if caught isa Meta.ParseError
        detail = "syntax error";
        problem = match(r"── ([^\n]+)", text);
        if problem !== nothing
            detail = detail * ", " * problem.captures[1];
        end
    else
        detail = string(typeof(caught));
        for line in split(text, '\n')
            # Base.strip: the course package has its own strip -
            if !isempty(Base.strip(line))
                detail = String(Base.strip(line));
                break;
            end
        end
    end

    # Keep the message short -
    if length(detail) > 200
        detail = first(detail, 197) * "...";
    end
    return "Your code could not be loaded$(place): $(detail). Run check_submission.jl to see the full message.";
end

"""
    load_assignment(path::String) -> String

Load the same files as the checker with `Include.jl`, including your track's
source file.

### Arguments

- `path`: The path to `Include.jl`.

### Returns

An empty string when everything loads, or a one-line message from
`load_message` when loading stops.
"""
function load_assignment(path::String)::String
    try
        include(path);
    catch caught
        return load_message(caught);
    end
    return "";
end

"""
    run_exploration() -> Nothing

Rebuild the trades with the settings in config/explore.toml, then write the
report with your own functions to results/exploration/Exploration.md.

### Returns

`nothing`. Throws an `ArgumentError` when a ticker is not in the course
options archive or the settings find no trades.
"""
function run_exploration()::Nothing

    # Read your settings -
    config = load_config(joinpath(_ROOT, "config", "explore.toml"));

    # Check the tickers against the course options archive -
    println("Loading the course options archive. The first run downloads it (about 112 MB), which can take a few minutes.");
    known = unique(MyOptionsEODUnderlyingDataSet().ticker);
    unknown = setdiff(config.tickers, known);
    if !isempty(unknown)
        throw(ArgumentError("These tickers are not in the course options archive: " * join(unknown, ", ") * "."));
    end

    # Build the trades -
    built = build_trade_table(config);
    if nrow(built.trades) == 0
        throw(ArgumentError("No trades were found with these settings; try other tickers, deltas, or days to expiration."));
    end

    # Estimate each trade's model parameters, and load the daily closes of benchmark_ticker -
    history = price_history(config.tickers);
    parameters = trade_parameters(built.trades, history, config);
    benchmark = archive_closes(config.benchmark_ticker); # like data/benchmark.csv

    # Write the report -
    print_options_report(_TRACK, _ROOT; output_directory = "results/exploration", config_path = "config/explore.toml",
        title = "PS4 exploration (ungraded)", report_name = "Exploration.md", trades = built.trades,
        parameters = parameters, benchmark = benchmark);
    return nothing;
end

# Load your code; stop with a one-line message when it does not load -
const _EXPLORE_LOAD_ERROR = load_assignment(joinpath(_ROOT, "Include.jl"));
if !isempty(_EXPLORE_LOAD_ERROR)
    println(_EXPLORE_LOAD_ERROR);
    exit(1);
end

# Run the exploration; a problem with your settings stops it with a one-line message -
try
    run_exploration();
catch caught
    if caught isa ArgumentError
        println(caught.msg);
        exit(1);
    end
    rethrow();
end
