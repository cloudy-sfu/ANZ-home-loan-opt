using DataFrames
using Serialization

mortgage_rate = deserialize("raw/mortgage_rate.jls")
official_cash_rate = deserialize("raw/official_cash_rate.jls")
wholesale_swap_rate = deserialize("raw/wholesale_swap_rate.jls")
