using HTTP
using Gumbo
using Cascadia
using DataFrames
using LibPQ
include(joinpath(pwd(), "postgresql_ops.jl"))
using .PostgresqlOps

response = HTTP.get("https://www.interest.co.nz/borrowing")
html = parsehtml(String(response.body))

h2_nodes = eachmatch(Selector("h2"), html.root)
banks = first(n for n in h2_nodes if strip(Gumbo.text(n)) == "Banks")
banks_parent = banks.parent
data_table = Cascadia.matchFirst(Selector("table#interest_financial_datatable"), banks_parent)

headers = Cascadia.matchFirst(Selector("thead tr"), data_table)
col_names = [strip(nodeText(col)) for col in eachmatch(Selector("th"), headers)]
n_cols = length(col_names)
rows = eachmatch(Selector("tbody tr"), data_table)
rows_1 = Vector{Dict{String,String}}()
current_bank = ""
for row in rows
    global current_bank
    cols = eachmatch(Selector("td"), row)
    n_cols_this_row = length(cols)

    # Detect bank name from primary_row (img title or link text)
    inst_cell = cols[1]
    img_nodes = eachmatch(Selector("img"), inst_cell)
    a_nodes = eachmatch(Selector("a"), inst_cell)
    if !isempty(img_nodes)
        current_bank = img_nodes[1].attributes["title"]
    elseif !isempty(a_nodes)
        current_bank = a_nodes[1].attributes["title"]
    end

    # Remove ads
    current_bank = replace(current_bank, "Home Loans %u2013 Apply now or find out more" => "")  # TSB
    current_bank = replace(current_bank, r"click.*contact" => "")  # SBS, BNZ
    current_bank = replace(current_bank, r" - .*" => "")  # ASB
    current_bank = strip(current_bank)
    if length(current_bank) > 32
        current_bank = current_bank[1:32]
    end
 
    if n_cols_this_row == n_cols  # Normal row
        rd = Dict{String,String}()
        for (i, col) in enumerate(cols)
            val = strip(nodeText(col))
            if col_names[i] == "Product" && length(val) > 32
                val = val[1:32]
            end
            rd[col_names[i]] = val
        end
        rd["Institution"] = current_bank  # Override with cleaned bank name
        push!(rows_1, rd)
    else  # Colspan row — merge 18-month value into previous row
        special_td = cols[3]
        value_spans = eachmatch(Selector(".interest_data-subcell-special_line_value"), special_td)
        if !isempty(value_spans) && !isempty(rows_1)
            rows_1[end]["18months"] = strip(nodeText(value_spans[1]))
        end
    end
end

parse_rate(s::AbstractString) = isempty(s) ? missing : parse(Float64, s)

col_rename = Dict(
    "Variable floating" => :Floating,
    "6months" => :_6_Months,
    "1year" => :_1_Year,
    "18months" => :_18_Months,
    "2years" => :_2_Years,
    "3years" => :_3_Years,
    "4years" => :_4_Years,
    "5years" => :_5_Years,
)

df = DataFrame(
    Bank = [r["Institution"] for r in rows_1],
    Product = [r["Product"] for r in rows_1],
)
for (src, dst) in col_rename
    df[!, dst] = [parse_rate(get(r, src, "")) for r in rows_1]
end

data_cols = collect(values(col_rename))
filter!(r -> any(!ismissing, [r[c] for c in data_cols]), df)
unique!(df, [:Bank, :Product])

const c = LibPQ.Connection(ENV["NEON_DB"])
insert_if_not_exists(c, df, ["Date", "Bank", "Product"], "ins_mortgage_rate")
close(c)
