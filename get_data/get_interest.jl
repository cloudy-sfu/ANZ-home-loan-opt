# Ref: Translated from Python scraper targeting https://www.interest.co.nz
module GetInterest

using HTTP, Gumbo, Cascadia, JSON3, DataFrames, Dates

function get_chart_and_series(url::String)
    resp = HTTP.get(url)
    html = parsehtml(String(resp.body))
    # Find div with id matching "chart-wrapper-{digits}"
    wrappers = eachmatch(sel"div[id^='chart-wrapper-']", html.root)
    isempty(wrappers) && error("No chart-wrapper div found")
    wrapper = first(wrappers)
    wrapper_id = getattr(wrapper, "id")
    m = match(r"^chart-wrapper-(\d+)$", wrapper_id)
    m === nothing && error("Unexpected wrapper id: $wrapper_id")
    chart_id = m.captures[1]

    # Find select with class "chart-selector"
    selects = eachmatch(sel"select.chart-selector", html.root)
    isempty(selects) && error("No chart-selector found")
    options = eachmatch(sel"option", first(selects))
    series_pat = Regex("^chart-$(chart_id)-(\\d+)\$")
    series_names = Dict{String,String}()
    for opt in options
        val = getattr(opt, "value", "")
        m2 = match(series_pat, val)
        m2 === nothing && continue
        series_names[m2.captures[1]] = nodeText(opt)
    end
    return chart_id, series_names
end

function get_series_idx(series_names::Dict{String,String}, regex::Regex)
    for (id_, name) in series_names
        if occursin(regex, name)
            return parse(Int, id_)
        end
    end
    error("No series name satisfies regex $regex")
end

function get_chart_data(chart_id::AbstractString)
    resp = HTTP.post(
        "https://www.interest.co.nz/chart-data/get-csv-data",
        ["Content-Type" => "application/x-www-form-urlencoded"],
        HTTP.URIs.escapeuri("nids[]") * "=" * chart_id
    )
    body = JSON3.read(String(resp.body))
    return body[Symbol(chart_id)]["csv_data"]
end

function list_to_df(series, freq::Symbol)
    timestamps = [Float64(row[1]) for row in series]
    values     = [Float64(row[2]) for row in series]
    datetimes  = unix2datetime.(timestamps ./ 1000)

    if freq == :year
        return DataFrame(year=year.(datetimes), value=values)
    elseif freq == :quarter
        return DataFrame(year=year.(datetimes),
                         quarter=quarterofyear.(datetimes), value=values)
    elseif freq == :month
        return DataFrame(year=year.(datetimes),
                         month=month.(datetimes), value=values)
    elseif freq == :day
        return DataFrame(date=Date.(datetimes), value=values)
    else
        error("freq must be :year, :quarter, :month, or :day")
    end
end

# Helper: extract attribute from Gumbo element
function getattr(elem, attr, default="")
    for (k, v) in elem.attributes
        k == attr && return v
    end
    return default
end

# Get text content of a node
function nodeText(node)
    buf = IOBuffer()
    _collecttext(buf, node)
    return strip(String(take!(buf)))
end
function _collecttext(buf, node::HTMLElement)
    for c in node.children
        _collecttext(buf, c)
    end
end
function _collecttext(buf, node::HTMLText)
    write(buf, node.text)
end
_collecttext(buf, node) = nothing

function interp1(xs::Vector{Float64}, ys::Vector{Float64}, x::Float64)
    # Simple piecewise-linear interpolation with flat extrapolation
    n = length(xs)
    x <= xs[1] && return ys[1]
    x >= xs[n] && return ys[n]
    for i in 1:n-1
        if xs[i] <= x <= xs[i+1]
            t = (x - xs[i]) / (xs[i+1] - xs[i])
            return ys[i] + t * (ys[i+1] - ys[i])
        end
    end
    return ys[n]
end

function nan_blocks(mask::AbstractVector{Bool})
    blocks = Tuple{Int,Int}[]
    i = 1
    n = length(mask)
    while i <= n
        if mask[i]
            s = i
            while i <= n && mask[i]
                i += 1
            end
            push!(blocks, (s, i - 1))
        else
            i += 1
        end
    end
    return blocks
end

export get_chart_and_series, get_series_idx, get_chart_data, list_to_df, interp1, nan_blocks

end # module