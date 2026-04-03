# Ref: Translated from ocr.py targeting https://www.interest.co.nz
include("get_interest.jl")
using .GetInterest
include(joinpath(pwd(), "postgresql_ops.jl"))
using .PostgresqlOps
using DataFrames
using Dates
using LibPQ

chart_id, series_names = get_chart_and_series(
    "https://www.interest.co.nz/charts/interest-rates/ocr"
)
all_data = get_chart_data(chart_id)

ocr_idx = get_series_idx(series_names, r"^NZ Official")
ocr = list_to_df(all_data[ocr_idx+1], :day)  # +1 for 1-based indexing if needed
sort!(ocr, :date)

# Keep only rows where value changed
changed = [true; [ocr.value[i] != ocr.value[i-1] for i in 2:nrow(ocr)]]
ocr_1 = ocr[changed, :]
rename!(ocr_1, "date" => "Date", "value" => "OCR")

const c = LibPQ.Connection(ENV["NEON_DB"])
insert_if_not_exists(c, ocr_1, ["Date"], "ocr")
close(c)
