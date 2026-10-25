# Load the selected track and its helpers from paths relative to this file -
const _ROOT = @__DIR__;
include(joinpath(_ROOT, "reports", "Terminal.jl"));
include(joinpath(_ROOT, "test", "Rubric.jl"));

# A solution run (local instructor validation only) checks the instructor's code and writes to instructor/output -
const _USE_SOLUTION = "--solution" in ARGS;
if _USE_SOLUTION
    const _OUTPUT_ROOT = joinpath(_ROOT, "instructor", "output");
else
    const _OUTPUT_ROOT = _ROOT;
end
for argument in ARGS
    if argument != "--solution"
        throw(ArgumentError("The only optional argument is --solution."));
    end
end

# The track named in TRACK.txt, and its source file -
const _TRACK = String(strip(read(joinpath(_ROOT, "TRACK.txt"), String)));
if !(_TRACK in ("standard", "advanced"))
    throw(ArgumentError("TRACK.txt must contain standard or advanced."));
end
if _USE_SOLUTION
    const _SOURCE_PATH = joinpath(_ROOT, "instructor", "reference", titlecase(_TRACK)*".jl");
else
    const _SOURCE_PATH = joinpath(_ROOT, "src", titlecase(_TRACK)*".jl");
end

using VLQuantitativeFinancePackage # course contract models, build, and profit
using DataFrames # trade tables, as in the course notebooks
using Statistics # sample means and standard deviations
using Random # repeatable stock-price simulations
using Dates # dates and expiration times
using Printf # readable profit and probability tables

include(joinpath(_ROOT, "src", "Support.jl"));
include(joinpath(_ROOT, "reports", "Options.jl"));
include(joinpath(_ROOT, "test", "Fixtures.jl"));
include(joinpath(_ROOT, "test", "public_standard_tests.jl"));
include(joinpath(_ROOT, "test", "public_advanced_tests.jl"));

# The public checks of the selected track -
if _TRACK == "standard"
    const _PUBLIC_CHECKS = standard_public_checks();
else
    const _PUBLIC_CHECKS = advanced_public_checks();
end

# Load optional student helpers before the selected source file -
# Store helper files under src/. Document each helper's purpose, inputs, and output.
# include(joinpath(_ROOT, "src", "MyHelperFunctions.jl"));
if !isfile(_SOURCE_PATH)
    throw(ArgumentError("Selected source file is missing: $(_SOURCE_PATH)"));
end
include(_SOURCE_PATH);
