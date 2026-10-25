# SHA-256 of the shipped config/defaults.toml; the checker warns when a student edits the file -
const PS4_DEFAULTS_SHA256 = "0ba760e9b9be2397f1fe25ce5e6f1a44a4ee1e9825c06900fee718d023c82029";

"""
    run_public_check(check::NamedTuple)

Run one public check (see `test/public_standard_tests.jl` for the check format).

### Arguments

- `check`: A check with `name`, `test`, `builder`, and `legs` fields.

### Returns

- What the check's `test` function returns: `true` when the check passes. A
  builder check looks up the student's builder by name when it runs, because
  the checks are made before the student's source file is loaded.
"""
function run_public_check(check::NamedTuple)
    if check.builder === nothing
        return check.test();
    end
    builder = getfield(Main, check.builder); # the student's builder function
    return check.test(builder, check.legs);
end

"""
    evaluate_public_checks(checks) -> Vector{NamedTuple}

Run each public check and record its result. An error in one check does not
stop the others.

### Arguments

- `checks`: The public checks, from `standard_public_checks` or
  `advanced_public_checks`.

### Returns

One record per check, with its `name`, a `passed` value of `true` or `false`,
and an error message in `detail`. An empty message means the check passed.
"""
function evaluate_public_checks(checks::AbstractVector{<:NamedTuple})::Vector{NamedTuple}

    results = NamedTuple[];
    for check ∈ checks
        passed = false;
        detail = "";
        try
            value = run_public_check(check);
            passed = value === true;
            if !passed
                detail = "check returned $(repr(value))";
            end
        catch error
            detail = sprint(showerror, error);
        end
        push!(results, (name = check.name, passed = passed, detail = detail));
    end

    return results;
end

"""
    number_passed(results) -> Int

Count the check results that passed.
"""
function number_passed(results::AbstractVector{<:NamedTuple})::Int
    passed = 0;
    for result in results
        if result.passed
            passed = passed + 1;
        end
    end
    return passed;
end

"""
    failed_public_checks(checks, detail) -> Vector{NamedTuple}

Mark every check as failed when the student's source file cannot be loaded.

### Arguments

- `checks`: The selected track's checks, each with a `name` field.
- `detail`: Error message explaining why the source could not be loaded.

### Returns

One failed result per check, each with the supplied error message.
"""
function failed_public_checks(checks::AbstractVector{<:NamedTuple},
    detail::String)::Vector{NamedTuple}
    return [(name = check.name, passed = false, detail = detail) for check ∈ checks];
end


"""
    print_public_test_report(results, title; tests_ran=true) -> Nothing

Print aligned pass/fail labels and a summary. Number repeated errors and
print each distinct diagnostic once after the checks.

### Arguments

- `results`: Check records with `name`, `passed`, and `detail` fields.
- `title`: Heading to print above the checks.
- `tests_ran`: If false, explain that loading prevented the checks from running.
  The caller displays the loading error once instead of repeating it per check.

### Returns

`nothing`. The report is printed to the terminal.
"""
function print_public_test_report(results::AbstractVector{<:NamedTuple},
    title::String; tests_ran::Bool=true)::Nothing

    print_terminal_section(title; major=true);
    if !tests_ran
        print_terminal_text("Checks could not run because a setup or source file did not load. Fix the error below and run the checker again.");
        print_terminal_text("Public tests: 0/$(length(results)) passed. Checks that cannot run count as failed.");
        return nothing;
    end

    # The distinct error messages of the failed checks, each printed once -
    details = String[];
    for result in results
        if !result.passed && !isempty(result.detail) && !(result.detail in details)
            push!(details, result.detail);
        end
    end
    if !isempty(details)
        println("Numbers in brackets refer to the error messages in Check details.");
        println();
    end

    # One line per check; a failed check points to its error message -
    for result ∈ results
        if result.passed
            status = "PASS";
            reference = "";
        else
            status = "FAIL";
            reference = "";
            for (index, detail) in enumerate(details)
                if detail == result.detail
                    reference = " [$(index)]";
                end
            end
        end
        print_terminal_text(result.name * reference; prefix="[$(status)] ", continuation="       ");
    end

    passed = number_passed(results);
    println("\nPublic tests: $(passed)/$(length(results)) passed");

    # The error messages -
    if !isempty(details)
        print_terminal_section("Check details");
        for (index, detail) in enumerate(details)
            println("Error $(index)");
            print_terminal_detail(detail);
            if index < length(details)
                println();
            end
        end
    end
    return nothing;
end


"""
    missing_docstrings(function_names::Vector{Symbol}) -> Vector{Symbol}

Find required functions that have no Julia docstring.

### Arguments

- `function_names`: Names of the functions required for the selected track.

### Returns

The names that are not defined or have no docstring in `Main`.
"""
function missing_docstrings(function_names::Vector{Symbol})::Vector{Symbol}

    # Julia keeps the docstrings of each module in a table; student code is loaded into Main -
    docstrings = Base.Docs.meta(Main);

    missing_names = Symbol[];
    for name in function_names
        has_docstring = isdefined(Main, name) && haskey(docstrings, Base.Docs.Binding(Main, name));
        if !has_docstring
            push!(missing_names, name);
        end
    end
    return missing_names;
end


"""
    code_is_documented(function_names::Vector{Symbol}) -> Bool

Check whether all required functions have docstrings.

### Arguments

- `function_names`: Names of the functions required for the selected track.

### Returns

`true` when every named function is defined and has a docstring in `Main`.
"""
function code_is_documented(function_names::Vector{Symbol})::Bool
    return isempty(missing_docstrings(function_names));
end


"""
    response_issues(path::String) -> Vector{String}

Find missing or unfinished answers and describe how to fix them.

### Arguments

- `path`: Selected track's Markdown response file.

### Returns

A list of messages for missing files, incorrect answer markers, empty answers,
or answers that contain TODO. An empty list means no issues were found.
The check ignores HTML comments inside answers. It checks for text, not
whether an answer is correct; the teaching team reviews the answers.

### Errors

An unreadable file raises a file-read error.
"""
function response_issues(path::String)::Vector{String}

    if !isfile(path)
        return ["Response file is missing. Restore it from the PS4 ZIP and answer all three questions."];
    end
    text = read(path, String);
    issues = String[];
    for index in 1:3
        start_marker = "<!-- answer-$(index):start -->";
        end_marker = "<!-- answer-$(index):end -->";
        pattern = Regex("<!-- answer-$(index):start -->(.*?)<!-- answer-$(index):end -->", "s");
        blocks = collect(eachmatch(pattern, text));
        if count(start_marker, text) != 1 || count(end_marker, text) != 1 || length(blocks) != 1
            push!(issues, "Question $(index): Keep one $(start_marker) before your answer and one $(end_marker) after it.");
            continue;
        end
        # Remove HTML comments, then surrounding space (Base.strip: the course package has its own strip) -
        answer = replace(blocks[1].captures[1], r"<!--.*?-->"s => "");
        answer = Base.strip(answer);
        if !occursin(r"[\p{L}\p{N}]", answer)
            push!(issues, "Question $(index) has no answer. Write your response between its answer markers.");
        elseif occursin(r"\bTODO\b"i, answer)
            push!(issues, "Question $(index) still contains TODO. Replace the placeholder with your response.");
        end
    end
    return issues;
end


"""
    response_is_complete(path::String) -> Bool

Check whether all three answer blocks contain text without TODO.

### Arguments

- `path`: Selected track's Markdown response file.

### Returns

`true` when `response_issues` returns an empty list. This checks that answers
are present; the teaching team reviews whether they meet the requirements.

### Errors

An unreadable file raises a file-read error.
"""
function response_is_complete(path::String)::Bool
    return isempty(response_issues(path));
end


"""
    rubric_score(results; tests_ran, completion) -> Int

Calculate the rubric score from the check results and completion review.

### Arguments

- `results`: A vector of check records with Boolean `passed` fields.
- `tests_ran`: Whether the student's source file loaded; `false` gives 0.
- `completion`: Set to `true` only when the teaching team has reviewed the
  code, documentation, and answers and found that all requirements are met.

### Returns

An integer from 0 to 4. A submission with no passing checks receives 0.
Passing at least one check but no more than half gives 1; passing more than
half but fewer than all gives 2.
When all checks pass, return 3 if `completion` is `false` and 4 if it is `true`.

### Notes

Standard has 24 checks: passing 1–12 gives 1, 13–23 gives 2, and all 24 gives
3 or 4. Advanced has 40 checks: passing 1–20 gives 1, 21–39 gives 2, and all
40 gives 3 or 4. The local checker prints pending review when all checks pass.
It leaves the choice between 3 and 4 to the teaching team.
"""
function rubric_score(results::AbstractVector{<:NamedTuple};
    tests_ran::Bool, completion::Bool)::Int

    passed = number_passed(results);
    total = length(results);

    if !tests_ran || passed == 0
        return 0;
    elseif 2*passed <= total
        return 1;
    elseif passed < total
        return 2;
    elseif !completion
        return 3;
    else
        return 4;
    end
end


# Functions that must have docstrings -
const STANDARD_DOCUMENTED_FUNCTIONS = [
    :build_short_straddle, :build_short_strangle, :build_protected_strangle, :build_iron_condor,
    :trade_profit, :probability_of_profit,
];

const ADVANCED_DOCUMENTED_FUNCTIONS = vcat(STANDARD_DOCUMENTED_FUNCTIONS, [
    :build_short_put, :build_short_call, :build_put_credit_spread, :build_call_credit_spread,
]);
