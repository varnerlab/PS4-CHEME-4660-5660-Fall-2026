# The PS4 public checks for the Advanced track: the twenty-four Standard checks plus four
# checks for each Advanced builder. See test/public_standard_tests.jl for the check format.

"""
    advanced_public_checks() -> Vector{NamedTuple}

The forty Advanced public checks: the twenty-four Standard checks, then four for
each of the four Advanced builders.
"""
function advanced_public_checks()::Vector{NamedTuple}

    legs = ps4_check_legs();

    return vcat(
        standard_public_checks(),
        builder_checks("Short put", :build_short_put, [legs.short_put]),
        builder_checks("Short call", :build_short_call, [legs.short_call]),
        builder_checks("Put credit spread", :build_put_credit_spread, [legs.short_put, legs.long_put]),
        builder_checks("Call credit spread", :build_call_credit_spread, [legs.short_call, legs.long_call]));
end
