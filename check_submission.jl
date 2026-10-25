# Run from the PS4 folder: julia --project=. --startup-file=no check_submission.jl
import Dates # record when this local check ran
using SHA: sha256 # record which files were checked

const _CHECK_ROOT = @__DIR__;

"""
    load_assignment(path::String) -> String

Load the assignment files with `Include.jl`: the supplied code, the checks, and
the selected source file.

### Arguments

- `path`: The path to `Include.jl`.

### Returns

An empty string when everything loads, or the error message when loading
stops. The checker reports the error instead of crashing.
"""
function load_assignment(path::String)::String
    try
        include(path);
    catch caught
        return sprint(showerror, caught);
    end
    return "";
end

"""
    clear_previous_results(root::String) -> Nothing

Remove the generated tables and Markdown report from the previous run. Clear them before
running checks or reporting results, even when loading the source failed.

### Arguments

- `root`: Assignment folder, or its local `instructor/output` folder for a solution run.

### Returns

`nothing`. Skips files that do not exist.

### Errors

Raises an error if an existing file cannot be removed. The checker reports
this as a setup error.
"""
function clear_previous_results(root::String)::Nothing
    for name in ("outcomes.csv", "summary.csv", "benchmarks.csv", "worst-trades.csv", "drop-worst.csv", "groups.csv",
            "sides.csv", "Report.md")
        path = joinpath(root, "results", name);
        if isfile(path)
            rm(path);
        end
    end
    return nothing;
end

"""
    checker_setup(load_error::String) -> NamedTuple

Collect the settings that `Include.jl` defined, then clear the previous
results. When `Include.jl` stopped early, use a fallback for each setting it
did not reach.

### Arguments

- `load_error`: The message from `load_assignment`; empty when loading worked.

### Returns

A `NamedTuple` with:

- `track`: `standard`, `advanced`, or `unavailable` when TRACK.txt could not be used.
- `checks`: The track's public checks, or an empty list.
- `tests_ran`: `true` when there was no loading or setup error.
- `detail`: The loading or setup error message; empty when there was none.
- `source_path`: The selected source file, or an empty string.
- `solution`: `true` for a local solution run.
- `output_root`: The folder for `MANIFEST.txt` and `results/`.
"""
function checker_setup(load_error::String)::NamedTuple

    # The track, or "unavailable" -
    track = "unavailable";
    if isdefined(Main, :_TRACK) && _TRACK in ("standard", "advanced")
        track = _TRACK;
    end

    # The public checks and the source file -
    checks = NamedTuple[];
    if isdefined(Main, :_PUBLIC_CHECKS)
        checks = _PUBLIC_CHECKS;
    end
    source_path = "";
    if isdefined(Main, :_SOURCE_PATH)
        source_path = _SOURCE_PATH;
    end

    # A solution run writes to instructor/output instead of the assignment folder -
    if isdefined(Main, :_USE_SOLUTION)
        solution = _USE_SOLUTION;
    else
        solution = "--solution" in ARGS;
    end
    if isdefined(Main, :_OUTPUT_ROOT)
        output_root = _OUTPUT_ROOT;
    elseif solution
        output_root = joinpath(_CHECK_ROOT, "instructor", "output");
    else
        output_root = _CHECK_ROOT;
    end

    # Clear the previous results; an error here is added to the loading error -
    detail = load_error;
    try
        clear_previous_results(output_root);
    catch caught
        if isempty(detail)
            detail = sprint(showerror, caught);
        else
            detail = detail * "\n" * sprint(showerror, caught);
        end
    end

    return (track = track, checks = checks, tests_ran = isempty(detail), detail = detail,
        source_path = source_path, solution = solution, output_root = output_root);
end

"""
    write_file_record(io::IO, root::String, track::String, source_path::String) -> Nothing

Record the contents of TRACK.txt, Include.jl, config/defaults.toml, all files under src/, and the
selected response file. Also record the actual selected source, including
when it is a local solution.

### Arguments

- `io`: Open output stream for the submission record.
- `root`: Assignment folder.
- `track`: Selected track, or `unavailable` after a setup error.
- `source_path`: Actual selected source file, or an empty string after an early setup error.

### Returns

`nothing`. Writes a SHA-256 value that identifies each file's contents.
Marks missing required files as MISSING.

### Errors

Raises an error if a file cannot be read or the record cannot be written.
"""
function write_file_record(io::IO, root::String, track::String, source_path::String)::Nothing

    # The files to record -
    paths = String[];
    for name in ("TRACK.txt", "Include.jl", "Project.toml", "Manifest.toml", "config/defaults.toml")
        push!(paths, joinpath(root, name));
    end
    if !isempty(source_path)
        push!(paths, source_path);
    end
    if isdir(joinpath(root, "src"))
        for (folder, _, names) in walkdir(joinpath(root, "src"))
            for name in names
                push!(paths, joinpath(folder, name));
            end
        end
    end
    if track in ("standard", "advanced")
        push!(paths, joinpath(root, "src", titlecase(track)*".jl"));
        push!(paths, joinpath(root, "responses", titlecase(track)*".md"));
    end

    # One line per file: its SHA-256 value (or MISSING) and its path -
    for path in sort(unique(paths))
        relative = replace(relpath(path, root), '\\' => '/');
        if isfile(path)
            value = bytes2hex(open(sha256, path));
        else
            value = "MISSING";
        end
        println(io, value, "  ", relative);
    end
    return nothing;
end

"""
    write_manifest(path::String, record::NamedTuple) -> Nothing

Write the submission record, `MANIFEST.txt`: the check results, then the
SHA-256 value of each recorded file from `write_file_record`.

### Arguments

- `path`: Where to write the record.
- `record`: The results to record, collected by `main`.

### Returns

`nothing`.

### Errors

Raises an error if a file cannot be read or the record cannot be written.
"""
function write_manifest(path::String, record::NamedTuple)::Nothing

    io = open(path, "w");
    println(io, "PS4 CHEME 4/5660 Fall 2026 submission record");
    println(io, "generated: ", Dates.now());
    println(io, "track: ", record.track);
    println(io, "source file: ", record.source_name);
    println(io, "local solution: ", record.solution);
    println(io, "tests ran: ", record.tests_ran);
    println(io, "public tests passed: $(record.passed)/$(record.total)");
    println(io, "required function docstrings present: ", record.documented);
    println(io, "three answer blocks contain text without TODO: ", record.answers);
    println(io, "local rubric feedback: ", record.feedback);
    println(io, "defaults.toml changed: ", record.defaults_changed);
    if record.defaults_changed
        println(io, "defaults.toml sha256: ", record.defaults_hash);
    end
    if !isempty(record.detail)
        println(io, "setup/source error: ", record.detail);
    end
    write_file_record(io, _CHECK_ROOT, record.track, record.source_path);
    close(io);
    return nothing;
end

"""
    print_next_steps() -> Nothing

Print how to package and submit the assignment.
"""
function print_next_steps()::Nothing
    print_terminal_section("Next steps");
    print_terminal_text("Save your code and answers, then rerun the checker."; prefix="1. ", continuation="   ");
    print_terminal_text("Create a ZIP of the entire PS4 folder, using this filename:"; prefix="2. ", continuation="   ");
    println("   CHEME-5660-PS4-<your netid>.zip");
    println("   Replace <your netid> with your own NetID.");
    print_terminal_text("Upload the ZIP to the PS4 assignment on Canvas."; prefix="3. ", continuation="   ");
    println();
    print_terminal_text("Submit attempted work by the initial deadline even if checks fail or cannot run.");
    print_terminal_text("For eligible revisions, use New Attempt on the same Canvas assignment.");
    return nothing;
end

"""
    main(setup::NamedTuple) -> Nothing

Run the public checks, display available calculations, and write the
submission record.

### Arguments

- `setup`: The selected track, source file, checks, output folder, and any
  loading error, from `checker_setup`.

### Returns

`nothing`. Prints results and next steps, and writes `MANIFEST.txt` in the
assignment folder. A local solution run writes under `instructor/output` instead.
After all student checks pass, the teaching team must still review the
code, documentation, and answers.

### Notes

Prints errors from individual checks and report calculations. An error reading
the selected response file or writing the submission record stops the checker.
Does not upload files or edit the student's code or answers.
"""
function main(setup::NamedTuple)::Nothing

    # Initialize -
    track = setup.track;
    tests_ran = setup.tests_ran;
    track_known = track in ("standard", "advanced");
    if isempty(setup.source_path)
        source_name = "unavailable";
    else
        source_name = relpath(setup.source_path, _CHECK_ROOT);
    end
    println("Source file: ", source_name);

    # Stop when Include.jl failed before it loaded the checks -
    if !isdefined(Main, :evaluate_public_checks)
        println("Setup error: ", setup.detail);
        println("Fix Include.jl and run the checker again. No submission record was written.");
        return nothing;
    end

    # Run the public checks; every check fails when the source did not load -
    if tests_ran
        results = evaluate_public_checks(setup.checks);
    else
        results = failed_public_checks(setup.checks, setup.detail);
    end
    print_public_test_report(results, "PS4 $(titlecase(track)) checks"; tests_ran=tests_ran);
    if !tests_ran
        print_terminal_section("Setup or source error");
        print_terminal_detail(replace(setup.detail, _CHECK_ROOT * "/" => ""));
    end
    passed = number_passed(results);
    all_passed = tests_ran && !isempty(results) && passed == length(results);

    # Check the docstrings -
    if track == "standard"
        documented_functions = STANDARD_DOCUMENTED_FUNCTIONS;
    else
        documented_functions = ADVANCED_DOCUMENTED_FUNCTIONS;
    end
    missing_docs = Symbol[];
    if tests_ran
        missing_docs = missing_docstrings(documented_functions);
    end
    documented = tests_ran && isempty(missing_docs);

    # Check the answers -
    response_path = joinpath("responses", titlecase(track)*".md");
    answer_issues = String[];
    if track_known
        answer_issues = response_issues(joinpath(_CHECK_ROOT, response_path));
    end
    answers = track_known && isempty(answer_issues);

    # The local rubric feedback -
    if all_passed
        feedback = "pending completion review";
    else
        feedback = string(rubric_score(results; tests_ran=tests_ran, completion=false));
    end

    # Compare the settings file with the shipped copy (config_hash needs a loaded Include.jl) -
    defaults_path = joinpath(_CHECK_ROOT, "config", "defaults.toml");
    defaults_hash = "MISSING";
    defaults_changed = false;
    if tests_ran
        if isfile(defaults_path)
            defaults_hash = config_hash(defaults_path);
        end
        defaults_changed = defaults_hash != PS4_DEFAULTS_SHA256;
    end
    if defaults_changed
        print_terminal_text("Warning: config/defaults.toml differs from the shipped copy; the report uses your edited settings, but grading uses the shipped file.");
    end

    # Calculate the report results -
    if tests_ran
        try
            print_options_report(track, _CHECK_ROOT;
                output_directory=joinpath(setup.output_root, "results"));
        catch caught
            print_terminal_section("Report error");
            print_terminal_detail(sprint(showerror, caught));
        end
    end

    # Write the submission record -
    mkpath(setup.output_root);
    record_path = joinpath(setup.output_root, "MANIFEST.txt");
    record = (track = track, source_name = source_name, solution = setup.solution, tests_ran = tests_ran,
        passed = passed, total = length(results), documented = documented, answers = answers,
        feedback = feedback, defaults_changed = defaults_changed, defaults_hash = defaults_hash,
        detail = setup.detail, source_path = setup.source_path);
    write_manifest(record_path, record);

    # Show what to finish before submitting -
    if setup.solution
        print_terminal_section("Local solution check"; major=true);
    else
        print_terminal_section("Submission check"; major=true);
    end
    println("Track: ", track);
    println("Public tests: $(passed)/$(length(results)) passed");
    if !tests_ran
        print_terminal_text("Docstrings were not checked. Fix the setup or source error above, then run the checker again.");
    elseif documented
        println("Docstrings: All required functions have docstrings.");
    else
        print_terminal_text("Docstrings: Restore the supplied documentation for " * join(string.(missing_docs), ", ") * ".");
    end
    if setup.solution
        println("Wrote ", relpath(record_path, _CHECK_ROOT), ".");
        println("This run used the local solution. Student source files were not changed.");
        return nothing;
    end
    if track_known
        println("Answers: ", response_path);
        if answers
            print_terminal_text("All three answer blocks contain text without TODO. The teaching team will review the answers.");
        else
            for issue in answer_issues
                print_terminal_text(issue; prefix="  - ", continuation="    ");
            end
            println("Save your answers and run the checker again.");
        end
    else
        print_terminal_text("Answers were not checked. Fix the setup error above and run the checker again.");
    end
    println();
    println("Local rubric feedback: ", feedback);
    if all_passed
        println("The teaching team must still review your code, documentation, and answers.");
    end
    println("Wrote MANIFEST.txt. This script has not uploaded your work.");
    print_next_steps();
    return nothing;
end

# Load the assignment, collect its settings, and run the checks -
const _CHECK_LOAD_ERROR = load_assignment(joinpath(_CHECK_ROOT, "Include.jl"));
const _CHECK_SETUP = checker_setup(_CHECK_LOAD_ERROR);
main(_CHECK_SETUP);
