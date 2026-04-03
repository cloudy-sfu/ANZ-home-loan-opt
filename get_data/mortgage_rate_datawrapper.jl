# Ref: https://files.opespartners.co.nz/mortgage_interest_rates.csv
# Retail home loan rate (standard) of all 
include(joinpath(pwd(), "postgresql_ops.jl"))
using .PostgresqlOps
using Downloads
using CSV
using DataFrames
using LibPQ

const url = "https://files.opespartners.co.nz/mortgage_interest_rates.csv"
io = IOBuffer()
Downloads.download(url, io)
seekstart(io)
loan_rate = CSV.read(io, DataFrame;
    missingstring = ["", "NA", "N/A", "-"],
    normalizenames = true
)
select!(loan_rate, Not(:Column2))

const rate_cols = names(loan_rate, Not(:Bank))
for col in rate_cols
    loan_rate[!, col] = parse.(Float64, replace.(loan_rate[!, col], "%" => ""))
end
rename!(loan_rate, "floating" => "Floating")

const c = LibPQ.Connection(ENV["NEON_DB"])
upsert_dataframe(c, loan_rate, ["Date", "Bank"], "retail_rate")
close(c)
