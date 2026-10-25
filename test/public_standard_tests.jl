# The PS4 public checks for the Standard track.
#
# Each check is a named tuple with four fields:
#   name    - what the check tests, as the checker prints it
#   test    - the function that runs the check; it returns true when the check passes
#   builder - for a builder check, the name of the student's builder; otherwise nothing
#   legs    - for a builder check, the legs the builder should make; otherwise nothing
# run_public_check in test/Rubric.jl runs one check.
#
# The builder checks use the test trade PS4_FIXTURE from test/Fixtures.jl. It is filled at the
# bid and ask, so every leg's sell price differs from its buy price. The profit and probability
# checks build their own contracts with the course build function, so an unfinished builder
# does not block them.
import Random # seeded samples for the lognormal probability check
import Distributions # closed-form lognormal probability

"""
    ps4_check_legs() -> NamedTuple

The legs the builders should make from `PS4_FIXTURE`.

### Returns

- One leg per role, each `(type, K, sense, premium, IV)`: `type` is `"call"` or
  `"put"`, `sense` is -1 for a sold leg and +1 for a bought leg, and `premium`
  is the sell price for a sold leg and the buy price for a bought leg
  (USD/share).
"""
function ps4_check_legs()::NamedTuple
    return (
        atm_call = (type = "call", K = 100.0, sense = -1, premium = 3.0, IV = 0.30),
        atm_put = (type = "put", K = 100.0, sense = -1, premium = 2.8, IV = 0.32),
        short_call = (type = "call", K = 110.0, sense = -1, premium = 1.0, IV = 0.28),
        short_put = (type = "put", K = 90.0, sense = -1, premium = 1.2, IV = 0.35),
        long_call = (type = "call", K = 120.0, sense = 1, premium = 0.4, IV = 0.27),
        long_put = (type = "put", K = 80.0, sense = 1, premium = 0.5, IV = 0.40));
end

"""
    ps4_contract_type(contract) -> String

Name a contract's type: `"call"`, `"put"`, or `"other"` for anything else.
"""
function ps4_contract_type(contract)::String
    if contract isa MyAmericanCallContractModel
        return "call";
    elseif contract isa MyAmericanPutContractModel
        return "put";
    end
    return "other";
end

"""
    ps4_contracts(legs::Vector) -> Vector

Build one course contract model per leg, with `DTE = 30/365` and `copy = 1`.

### Arguments

- `legs`: Legs from `ps4_check_legs`.

### Returns

- The contract models, in the order of `legs`.
"""
function ps4_contracts(legs::Vector)::Vector
    contracts = [];
    for leg in legs
        if leg.type == "call"
            model = MyAmericanCallContractModel;
        else
            model = MyAmericanPutContractModel;
        end
        contract = build(model, (K = leg.K, premium = leg.premium, DTE = 30/365, sense = leg.sense,
            copy = 1, IV = leg.IV));
        push!(contracts, contract);
    end

    # Give the vector the element type of its contracts, as a builder would -
    return [contract for contract in contracts];
end

"""
    ps4_strangle() -> Vector

The test trade's short strangle: the short call and the short put. Its
breakevens are 87.8 and 112.2 USD/share.
"""
function ps4_strangle()::Vector
    legs = ps4_check_legs();
    return ps4_contracts([legs.short_call, legs.short_put]);
end

"""
    ps4_contract_fields(contracts::Vector) -> Vector

Record every field of each contract, to check that a function did not change them.
"""
function ps4_contract_fields(contracts::Vector)::Vector
    fields = [];
    for contract in contracts
        push!(fields, (contract.K, contract.sense, contract.premium, contract.DTE, contract.IV, contract.copy));
    end
    return fields;
end

# --- Builder checks: each takes the student's builder and the legs it should make ---

"""
    check_builder_counts(builder::Function, legs::Vector) -> Bool

The builder returns a vector of contract models with the right number of calls
and puts.
"""
function check_builder_counts(builder::Function, legs::Vector)::Bool

    contracts = builder(PS4_FIXTURE);
    if !(contracts isa Vector{<:AbstractContractModel}) || length(contracts) != length(legs)
        return false;
    end

    # Count the calls and puts the builder made and the ones it should make -
    calls = 0;
    puts = 0;
    for contract in contracts
        if contract isa MyAmericanCallContractModel
            calls = calls + 1;
        elseif contract isa MyAmericanPutContractModel
            puts = puts + 1;
        end
    end
    expected_calls = 0;
    expected_puts = 0;
    for leg in legs
        if leg.type == "call"
            expected_calls = expected_calls + 1;
        else
            expected_puts = expected_puts + 1;
        end
    end

    return calls == expected_calls && puts == expected_puts;
end

"""
    check_builder_senses(builder::Function, legs::Vector) -> Bool

Each contract has the right type, strike, and sense, in any order.
"""
function check_builder_senses(builder::Function, legs::Vector)::Bool

    found = Set();
    for contract in builder(PS4_FIXTURE)
        push!(found, (ps4_contract_type(contract), contract.K, contract.sense));
    end
    expected = Set();
    for leg in legs
        push!(expected, (leg.type, leg.K, leg.sense));
    end
    return found == expected;
end

"""
    check_builder_premiums(builder::Function, legs::Vector) -> Bool

Each contract has the right premium: the sell price for a sold leg and the buy
price for a bought leg.
"""
function check_builder_premiums(builder::Function, legs::Vector)::Bool

    found = Set();
    for contract in builder(PS4_FIXTURE)
        push!(found, (ps4_contract_type(contract), contract.K, contract.premium));
    end
    expected = Set();
    for leg in legs
        push!(expected, (leg.type, leg.K, leg.premium));
    end
    return found == expected;
end

"""
    check_builder_fields(builder::Function, legs::Vector) -> Bool

Each contract has `DTE = 30/365`, `copy = 1`, and its leg's `IV`, and the
builder does not change the trade.
"""
function check_builder_fields(builder::Function, legs::Vector)::Bool

    # Build from a copy, so we can tell if the builder changed it -
    trade = deepcopy(PS4_FIXTURE);
    contracts = builder(trade);

    for contract in contracts
        if contract.DTE != 30/365 || contract.copy != 1
            return false;
        end
    end

    found = Set();
    for contract in contracts
        push!(found, (ps4_contract_type(contract), contract.K, contract.IV));
    end
    expected = Set();
    for leg in legs
        push!(expected, (leg.type, leg.K, leg.IV));
    end

    return found == expected && trade == PS4_FIXTURE;
end

"""
    builder_checks(label::String, builder::Symbol, legs::Vector) -> Vector{NamedTuple}

The four checks for one structure builder.

### Arguments

- `label`: The structure's name, which starts each check name.
- `builder`: The name of the student's builder, such as `:build_short_straddle`.
- `legs`: The legs the builder should make, from `ps4_check_legs`.

### Returns

- Four checks: the number of contracts, calls, and puts; strikes and senses;
  premiums from the right price; and `DTE`, `IV`, and `copy`, with the trade
  unchanged.
"""
function builder_checks(label::String, builder::Symbol, legs::Vector)::Vector{NamedTuple}

    # The check names depend on the number of legs and on whether the structure buys a leg -
    buys_a_leg = false;
    for leg in legs
        if leg.sense == 1
            buys_a_leg = true;
        end
    end
    if length(legs) == 1
        sense_name = "strike and sense";
        fill_name = "premium is the sell price";
    elseif buys_a_leg
        sense_name = "strikes and senses (order-independent)";
        fill_name = "short legs at the sell price, long legs at the buy price";
    else
        sense_name = "strikes and senses (order-independent)";
        fill_name = "short legs at the sell price";
    end

    return [
        (name = "$(label): number of contracts, calls, and puts", test = check_builder_counts,
            builder = builder, legs = legs),
        (name = "$(label): $(sense_name)", test = check_builder_senses, builder = builder, legs = legs),
        (name = "$(label): $(fill_name)", test = check_builder_premiums, builder = builder, legs = legs),
        (name = "$(label): DTE, IV, and copy fields; trade unchanged", test = check_builder_fields,
            builder = builder, legs = legs),
    ];
end

# --- Profit checks ---

"""
    check_profit_strangle() -> Bool

The strangle's profit at 100 (between its strikes), 115, and 85 (beyond them).
"""
function check_profit_strangle()::Bool
    contracts = ps4_strangle();
    return isapprox(trade_profit(contracts, 100.0), 2.2; atol = 1e-10) &&
        isapprox(trade_profit(contracts, 115.0), -2.8; atol = 1e-10) &&
        isapprox(trade_profit(contracts, 85.0), -2.8; atol = 1e-10);
end

"""
    check_profit_straddle() -> Bool

The straddle's profit at its strike (100) and away from it (110).
"""
function check_profit_straddle()::Bool
    legs = ps4_check_legs();
    contracts = ps4_contracts([legs.atm_call, legs.atm_put]);
    return isapprox(trade_profit(contracts, 100.0), 5.8; atol = 1e-10) &&
        isapprox(trade_profit(contracts, 110.0), -4.2; atol = 1e-10);
end

"""
    check_profit_long_legs() -> Bool

The long legs cap the losses of the protected strangle and the iron condor.
"""
function check_profit_long_legs()::Bool
    legs = ps4_check_legs();
    protected = ps4_contracts([legs.short_call, legs.short_put, legs.long_call]);
    condor = ps4_contracts([legs.short_call, legs.short_put, legs.long_call, legs.long_put]);
    return isapprox(trade_profit(protected, 130.0), -8.2; atol = 1e-10) &&
        isapprox(trade_profit(condor, 70.0), -8.7; atol = 1e-10) &&
        isapprox(trade_profit(condor, 130.0), -8.7; atol = 1e-10);
end

"""
    check_profit_type_and_inputs() -> Bool

`trade_profit` returns one `Float64` and does not change the contracts.
"""
function check_profit_type_and_inputs()::Bool
    contracts = ps4_strangle();
    before = ps4_contract_fields(contracts);
    value = trade_profit(contracts, 100.0);
    return value isa Float64 && isapprox(value, 2.2; atol = 1e-10) &&
        ps4_contract_fields(contracts) == before;
end

# --- Probability checks ---

"""
    check_pop_fraction() -> Bool

Three of these five prices lie between the strangle's breakevens, so the
probability of profit is 0.6.
"""
function check_pop_fraction()::Bool
    samples = [80.0, 88.0, 100.0, 112.0, 113.0];
    return isapprox(probability_of_profit(ps4_strangle(), samples), 0.6; atol = 1e-12);
end

"""
    check_pop_zero_profit() -> Bool

A price with exactly zero profit is not a win. One short call sold for 1.0 has
profit 1 at 100, exactly 0 at 111 (twice), and -9 at 120, so 1 of 4 wins.
"""
function check_pop_zero_profit()::Bool
    contracts = ps4_contracts([(type = "call", K = 110.0, sense = -1, premium = 1.0, IV = 0.28)]);
    samples = [100.0, 111.0, 120.0, 111.0];
    return isapprox(probability_of_profit(contracts, samples), 0.25; atol = 1e-12);
end

"""
    check_pop_lognormal() -> Bool

On 20,000 lognormal prices (GBM at T = 30/365 with drift 0.04 and volatility
0.30), the strangle's probability of profit is within five standard errors of
the exact value.
"""
function check_pop_lognormal()::Bool

    # The lognormal distribution of the price at expiration -
    d = Distributions.LogNormal(log(100) + (0.04 - 0.09/2)*30/365, 0.3*sqrt(30/365));
    Random.seed!(5660);
    samples = rand(d, 20_000);

    # The exact probability of a price between the breakevens -
    p = Distributions.cdf(d, 112.2) - Distributions.cdf(d, 87.8);

    return abs(probability_of_profit(ps4_strangle(), samples) - p) <= 5*sqrt(p*(1 - p)/20_000);
end

"""
    check_pop_type_and_inputs() -> Bool

`probability_of_profit` returns one `Float64` from unsorted, non-whole prices
and does not change them. Only 100.2 lies between the breakevens, so 1 of 5 wins.
"""
function check_pop_type_and_inputs()::Bool
    samples = [130.4, 85.6, 100.2, 70.8, 115.3];
    value = probability_of_profit(ps4_strangle(), samples);
    return value isa Float64 && isapprox(value, 0.2; atol = 1e-12) &&
        samples == [130.4, 85.6, 100.2, 70.8, 115.3];
end

"""
    standard_public_checks() -> Vector{NamedTuple}

The twenty-four Standard public checks: four for each builder, four for
`trade_profit`, and four for `probability_of_profit`.
"""
function standard_public_checks()::Vector{NamedTuple}

    legs = ps4_check_legs();

    profit_checks = [
        (name = "Profit: strangle between and beyond its strikes",
            test = check_profit_strangle, builder = nothing, legs = nothing),
        (name = "Profit: straddle at and away from the strike",
            test = check_profit_straddle, builder = nothing, legs = nothing),
        (name = "Profit: long legs cap the protected strangle and iron condor losses",
            test = check_profit_long_legs, builder = nothing, legs = nothing),
        (name = "Profit: the strangle at 100 as one Float64 number; contracts unchanged",
            test = check_profit_type_and_inputs, builder = nothing, legs = nothing),
    ];

    probability_checks = [
        (name = "Probability: fraction of samples where the strangle profits",
            test = check_pop_fraction, builder = nothing, legs = nothing),
        (name = "Probability: zero profit is not a win",
            test = check_pop_zero_profit, builder = nothing, legs = nothing),
        (name = "Probability: within five standard errors of the lognormal value",
            test = check_pop_lognormal, builder = nothing, legs = nothing),
        (name = "Probability: one Float64 from unsorted samples; samples unchanged",
            test = check_pop_type_and_inputs, builder = nothing, legs = nothing),
    ];

    return vcat(
        builder_checks("Short straddle", :build_short_straddle, [legs.atm_call, legs.atm_put]),
        builder_checks("Short strangle", :build_short_strangle, [legs.short_call, legs.short_put]),
        builder_checks("Protected strangle", :build_protected_strangle,
            [legs.short_call, legs.short_put, legs.long_call]),
        builder_checks("Iron condor", :build_iron_condor,
            [legs.short_call, legs.short_put, legs.long_call, legs.long_put]),
        profit_checks,
        probability_checks);
end
