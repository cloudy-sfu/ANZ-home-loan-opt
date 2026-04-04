# Ref: Translated from wholesale_swap_rate.py targeting https://www.interest.co.nz
include("get_interest.jl")
using .GetInterest
include(joinpath(pwd(), "postgresql_ops.jl"))
using .PostgresqlOps
using DataFrames
using Dates
using LibPQ

# Collect data.
chart_id, series_names_raw = get_chart_and_series(
    "https://www.interest.co.nz/charts/interest-rates/swap-rates"
)
swap_rate_all = get_chart_data(chart_id)

series_renamer = [
    "_1_year"  => r"^1 year",
    "_2_years"  => r"^2 year",
    "_3_years"  => r"^3 year",
    "_4_years"  => r"^4 year",
    "_5_years"  => r"^5 year",
    "_7_years"  => r"^7 year",
    "_10_years" => r"^10 year",
]

pieces = DataFrame[]
for (col_name, pat) in series_renamer
    idx = get_series_idx(series_names_raw, pat)
    df = list_to_df(swap_rate_all[idx+1], :day)
    # Remove duplicate dates, keep last
    df = combine(groupby(df, :date), :value => last => :value)
    rename!(df, :value => Symbol(col_name))
    push!(pieces, df)
end

swap_rate = pieces[1]
for i in 2:length(pieces)
    global swap_rate = outerjoin(swap_rate, pieces[i]; on=:date)
end
sort!(swap_rate, :date)

const c = LibPQ.Connection(ENV["NEON_DB"])
insert_if_not_exists(c, swap_rate, ["date"], "wholesale_swap_rate")
close(c)
