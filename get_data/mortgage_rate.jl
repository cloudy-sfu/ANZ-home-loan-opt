# Ref: Translated from mortgage_rate.py targeting https://www.interest.co.nz
include("get_interest.jl")
using .GetInterest
using Serialization
using DataFrames
using Dates
using Interpolations

# Collect data.
chart_id, series_names_raw = get_chart_and_series(
    "https://www.interest.co.nz/charts/interest-rates/mortgage-rates"
)
mortgage_all = get_chart_data(chart_id)

series_renamer = [
    0.0 => r"^Floating",
    0.5 => r"^6 months",
    1.0 => r"^1 year",
    1.5 => r"^18 months",
    2.0 => r"^2 year",
    3.0 => r"^3 year",
    4.0 => r"^4 year",
    5.0 => r"^5 year",
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

term_coord = [p.first for p in series_renamer]
term_syms  = [Symbol(p.first) for p in series_renamer]

# %% Fill missing values — term interpolation
mat = Matrix{Union{Missing,Float64}}(mortgage[:, term_syms])
nrow, ncol = size(mat)
term_filled = copy(mat)

for i in 1:nrow
    row = mat[i, :]
    valid = .!ismissing.(row)
    sum(valid) < 2 && continue
    xs = term_coord[valid]
    ys = Float64[row[j] for j in findall(valid)]
    for j in findall(.!valid)
        # Linear interpolation / extrapolation
        term_filled[i, j] = interp1(xs, ys, term_coord[j])
    end
end

# %% Fill missing values — time interpolation
date_vals = mortgage.date
time_coord = Dates.value.(date_vals .- date_vals[1])  # days as Int
max_gap_days = 30
time_filled = copy(mat)

for j in 1:ncol
    col = mat[:, j]
    mask = ismissing.(col)
    any(mask) || continue
    all(mask) && continue
    valid_idx = findall(.!mask)
    xs = Float64[time_coord[k] for k in valid_idx]
    ys = Float64[col[k] for k in valid_idx]

    # Find contiguous NaN blocks
    blocks = nan_blocks(mask)
    for (s, e) in blocks
        gap_dur = time_coord[e] - time_coord[s]
        gap_dur > max_gap_days && continue
        for k in s:e
            time_filled[k, j] = interp1(xs, ys, Float64(time_coord[k]))
        end
    end
end

# Average of two interpolations for missing cells
avg_filled = Matrix{Float64}(undef, nrow, ncol)
for i in 1:nrow, j in 1:ncol
    tf = ismissing(term_filled[i,j]) ? NaN : Float64(term_filled[i,j])
    ti = ismissing(time_filled[i,j]) ? NaN : Float64(time_filled[i,j])
    avg_filled[i,j] = (tf + ti) * 0.5
end

mortgage_filled = Matrix{Float64}(undef, nrow, ncol)
for i in 1:nrow, j in 1:ncol
    if ismissing(mat[i,j])
        mortgage_filled[i,j] = avg_filled[i,j]
    else
        mortgage_filled[i,j] = Float64(mat[i,j])
    end
end

# Build output DataFrame
result = DataFrame(date = mortgage.date)
for (k, sym) in enumerate(term_syms)
    result[!, sym] = mortgage_filled[:, k]
end

serialize("raw/mortgage_rate.jls", result)
