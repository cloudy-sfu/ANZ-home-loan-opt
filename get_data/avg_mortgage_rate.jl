# Ref: Translated from mortgage_rate.py targeting https://www.interest.co.nz
include("get_interest.jl")
using .GetInterest
include(joinpath(pwd(), "postgresql_ops.jl"))
using .PostgresqlOps
using DataFrames
using Dates
using LibPQ

# Collect data.
chart_id, series_names_raw = get_chart_and_series(
    "https://www.interest.co.nz/charts/interest-rates/mortgage-rates"
)
mortgage_all = get_chart_data(chart_id)

series_renamer = [
    "Floating" => r"^Floating",
    "_6_Months" => r"^6 months",
    "_1_Year" => r"^1 year",
    "_18_Months" => r"^18 months",
    "_2_Years" => r"^2 year",
    "_3_Years" => r"^3 year",
    "_4_Years" => r"^4 year",
    "_5_Years" => r"^5 year",
]

# Build a DataFrame with date index and one column per term
pieces = DataFrame[]
for (col_name, pat) in series_renamer
    idx = get_series_idx(series_names_raw, pat)
    df = list_to_df(mortgage_all[idx+1], :day)  # Julia is 1-indexed; adjust if API returns Dict
    rename!(df, :value => Symbol(col_name))
    push!(pieces, df)
end

mortgage = pieces[1]
for i in 2:length(pieces)
    global mortgage = outerjoin(mortgage, pieces[i]; on=:date)
end
sort!(mortgage, :date)
rename!(mortgage, "date" => "Date")

const c = LibPQ.Connection(ENV["NEON_DB"])
insert_if_not_exists(c, mortgage, ["Date"], "avg_mortgage_rate")
close(c)
