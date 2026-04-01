# Ref: Translated from wholesale_swap_rate.py targeting https://www.interest.co.nz
include("get_interest.jl")
using .GetInterest
using DataFrames
using Dates
using Arrow
using Serialization

# Collect data.
chart_id, series_names_raw = get_chart_and_series(
    "https://www.interest.co.nz/charts/interest-rates/swap-rates"
)
swap_rate_all = get_chart_data(chart_id)

series_renamer = [
    1  => r"^1 year",
    2  => r"^2 year",
    3  => r"^3 year",
    4  => r"^4 year",
    5  => r"^5 year",
    7  => r"^7 year",
    10 => r"^10 year",
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

term_coord = Float64[p.first for p in series_renamer]
term_syms  = [Symbol(p.first) for p in series_renamer]

# %% Fill missing values (same logic as mortgage_rate.jl)
mat = Matrix{Union{Missing,Float64}}(swap_rate[:, term_syms])
nrow_, ncol_ = size(mat)

# -- term interpolation
term_filled = copy(mat)
for i in 1:nrow_
    row = mat[i, :]
    valid = .!ismissing.(row)
    sum(valid) < 2 && continue
    xs = term_coord[valid]
    ys = Float64[row[j] for j in findall(valid)]
    for j in findall(.!valid)
        term_filled[i, j] = interp1(xs, ys, term_coord[j])
    end
end

# -- time interpolation
date_vals = swap_rate.date
time_coord = Dates.value.(date_vals .- date_vals[1])
max_gap_days = 30
time_filled = copy(mat)

for j in 1:ncol_
    col = mat[:, j]
    mask = ismissing.(col)
    any(mask) || continue
    all(mask) && continue
    valid_idx = findall(.!mask)
    xs = Float64[time_coord[k] for k in valid_idx]
    ys = Float64[col[k] for k in valid_idx]
    for (s, e) in nan_blocks(mask)
        (time_coord[e] - time_coord[s]) > max_gap_days && continue
        for k in s:e
            time_filled[k, j] = interp1(xs, ys, Float64(time_coord[k]))
        end
    end
end

# -- combine
swap_rate_filled = Matrix{Float64}(undef, nrow_, ncol_)
for i in 1:nrow_, j in 1:ncol_
    if ismissing(mat[i,j])
        tf = ismissing(term_filled[i,j]) ? NaN : Float64(term_filled[i,j])
        ti = ismissing(time_filled[i,j]) ? NaN : Float64(time_filled[i,j])
        swap_rate_filled[i,j] = (tf + ti) * 0.5
    else
        swap_rate_filled[i,j] = Float64(mat[i,j])
    end
end

result = DataFrame(date = swap_rate.date)
for (k, sym) in enumerate(term_syms)
    result[!, sym] = swap_rate_filled[:, k]
end

serialize("raw/wholesale_swap_rate.jls", result)
