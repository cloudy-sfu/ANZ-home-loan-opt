# Ref: https://ratesapi.nz/api/v1/mortgage-rates/time-series
using HTTP, JSON3, DataFrames, Dates, LibPQ
include(joinpath(pwd(), "postgresql_ops.jl"))
using .PostgresqlOps

const TERM_TO_COL = Dict{String,Symbol}(
    "6 months"          => :_6_Months,
    "1 year"            => :_1_Year,
    "18 months"         => :_18_Months,
    "2 years"           => :_2_Years,
    "3 years"           => :_3_Years,
    "4 years"           => :_4_Years,
    "5 years"           => :_5_Years,
    "Variable floating" => :Floating,
)

const INSTITUTIONS = Dict{String,String}(
    "institution:anz" => "ANZ",
    "institution:asb" => "ASB",
    "institution:bnz" => "BNZ",
    "institution:kiwibank" => "Kiwibank",
    "institution:westpac" => "Westpac",
)

function fetch_mortgage_rates(start_date::String, end_date::String,
                              institutions::Dict{String,String} = INSTITUTIONS)
    url = "https://ratesapi.nz/api/v1/mortgage-rates/time-series"
    rate_cols = sort(collect(values(TERM_TO_COL)))
    col_types = [Date, String, String, (Union{Float64,Missing} for _ in rate_cols)...]

    df = DataFrame(
        [T[] for T in col_types],
        [:Date, :Bank, :Product, rate_cols...]
    )

    for (inst_id, bank_name) in institutions
        params = Dict(
            "startDate"     => start_date,
            "endDate"       => end_date,
            "institutionId" => inst_id,
        )
        resp = HTTP.get(url; query=params)
        json = JSON3.read(resp.body)

        for (date_str, daily) in json.timeSeries
            d = Date(String(date_str))
            for inst in daily.data
                for prod in inst.products
                    row = Dict{Symbol,Any}(
                        :Date    => d,
                        :Bank    => bank_name,
                        :Product => String(prod.name),
                    )
                    for col in rate_cols
                        row[col] = missing
                    end
                    for r in prod.rates
                        col = get(TERM_TO_COL, String(r.term), nothing)
                        isnothing(col) && continue
                        row[col] = Float64(r.rate)
                    end
                    push!(df, row)
                end
            end
        end
    end

    sort!(df, [:Date, :Bank, :Product])
    rate_col_set = rate_cols
    filter!(r -> any(!ismissing, [r[c] for c in rate_col_set]), df)
    return df
end

length(ARGS) >= 2 || error(
    "Usage: julia ins_mortgage_rate_historical.jl $start_date $end_date")
df = fetch_mortgage_rates(ARGS[1], ARGS[2])
unique!(df, [:Bank, :Product])

const c = LibPQ.Connection(ENV["NEON_DB"])
insert_if_not_exists(c, df, ["Date", "Bank", "Product"], "ins_mortgage_rate")
close(c)
