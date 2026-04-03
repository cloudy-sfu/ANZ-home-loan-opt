# postgresql_ops.jl
#
# Ref: https://www.postgresql.org/docs/current/sql-insert.html#SQL-ON-CONFLICT
# Ref: https://github.com/invenia/LibPQ.jl

module PostgresqlOps
using LibPQ
using DataFrames
using Tables


"""
    _build_insert_sql(table_name, schema, col_names, num_rows)

Build `INSERT INTO ... VALUES (...), (...), ...` with \$-numbered placeholders
for `num_rows` rows, each having `length(col_names)` columns.

Returns `(sql_prefix, quoted_cols)` where `sql_prefix` is the string up to and
including the VALUES rows (without any ON CONFLICT clause).
"""
function _build_insert_sql(
    table_name::String,
    schema::String,
    col_names::Vector{String},
    num_rows::Int
)
    ncols = length(col_names)
    quoted_cols = [string('"', c, '"') for c in col_names]
    col_list = join(quoted_cols, ", ")

    # Build per-row placeholder tuples: ($1,$2,$3), ($4,$5,$6), ...
    row_placeholders = String[]
    for r in 1:num_rows
        offset = (r - 1) * ncols
        ph = join([string("\$", offset + i) for i in 1:ncols], ", ")
        push!(row_placeholders, string("(", ph, ")"))
    end
    values_list = join(row_placeholders, ", ")

    sql = """INSERT INTO "$(schema)"."$(table_name)" ($(col_list)) VALUES $(values_list)"""
    return sql, quoted_cols
end


"""
    _build_conflict_clause(unique_key_columns, col_names, do_update)

Return the `ON CONFLICT ...` suffix string.

- `do_update=true`  → `ON CONFLICT (...) DO UPDATE SET ...`
- `do_update=false` → `ON CONFLICT (...) DO NOTHING`
"""
function _build_conflict_clause(
    unique_key_columns::Vector{String},
    col_names::Vector{String},
    do_update::Bool
)
    conflict_cols = join([string('"', c, '"') for c in unique_key_columns], ", ")

    if !do_update
        return " ON CONFLICT ($(conflict_cols)) DO NOTHING"
    end

    update_cols = filter(c -> c ∉ unique_key_columns, col_names)
    if isempty(update_cols)
        return " ON CONFLICT ($(conflict_cols)) DO NOTHING"
    end

    set_clause = join(
        [string('"', c, '"', " = EXCLUDED.", '"', c, '"') for c in update_cols],
        ", "
    )
    return " ON CONFLICT ($(conflict_cols)) DO UPDATE SET $(set_clause)"
end


"""
    _execute_batched(conn, df, col_names, table_name, schema, conflict_suffix, batch_size)

Execute multi-row INSERT statements in batches of `batch_size`.
"""
function _execute_batched(
    conn::LibPQ.Connection,
    df::DataFrame,
    col_names::Vector{String},
    table_name::String,
    schema::String,
    conflict_suffix::String,
    batch_size::Int
)
    n = nrow(df)
    ncols = length(col_names)

    # Pre-build the SQL for full-size batches (reused for every full batch).
    full_sql = nothing
    if n >= batch_size
        base, _ = _build_insert_sql(table_name, schema, col_names, batch_size)
        full_sql = base * conflict_suffix
    end

    execute(conn, "BEGIN;")
    try
        idx = 1
        while idx <= n
            rows_remaining = n - idx + 1
            current_batch = min(batch_size, rows_remaining)

            if current_batch == batch_size && full_sql !== nothing
                sql = full_sql
            else
                # Last (possibly partial) batch — build a smaller SQL.
                base, _ = _build_insert_sql(table_name, schema, col_names, current_batch)
                sql = base * conflict_suffix
            end

            # Flatten parameters for the whole batch into a single vector.
            params = Vector{Any}(undef, current_batch * ncols)
            for r in 1:current_batch
                row = df[idx + r - 1, :]
                offset = (r - 1) * ncols
                for (j, c) in enumerate(col_names)
                    params[offset + j] = row[c]
                end
            end

            execute(conn, sql, params)
            idx += current_batch
        end
        execute(conn, "COMMIT;")
    catch e
        execute(conn, "ROLLBACK;")
        rethrow(e)
    end

    return nothing
end


"""
    upsert_dataframe(conn, df, unique_key_columns, table_name;
                     schema="public", batch_size=500)

Bulk INSERT … ON CONFLICT DO UPDATE (upsert) a DataFrame into PostgreSQL.

Every `batch_size` rows are combined into a single multi-row INSERT statement
to minimize round-trips.

# Arguments
- `conn::LibPQ.Connection`: An open LibPQ connection.
- `df::DataFrame`: The data to upsert.
- `unique_key_columns::Vector{String}`: Columns forming the unique constraint.
- `table_name::String`: Target table name.
- `schema::String`: Target schema name (default `"public"`).
- `batch_size::Int`: Rows per INSERT statement (default `500`).
"""
function upsert_dataframe(
    conn::LibPQ.Connection,
    df::DataFrame,
    unique_key_columns::Vector{String},
    table_name::String;
    schema::String = "public",
    batch_size::Int = 500
)
    nrow(df) == 0 && return nothing
    col_names = string.(names(df))
    suffix = _build_conflict_clause(unique_key_columns, col_names, true)
    _execute_batched(conn, df, col_names, table_name, schema, suffix, batch_size)
end


"""
    insert_if_not_exists(conn, df, unique_key_columns, table_name;
                         schema="public", batch_size=500)

Bulk INSERT … ON CONFLICT DO NOTHING a DataFrame into PostgreSQL.

Every `batch_size` rows are combined into a single multi-row INSERT statement
to minimize round-trips.

# Arguments
- `conn::LibPQ.Connection`: An open LibPQ connection.
- `df::DataFrame`: The data to insert.
- `unique_key_columns::Vector{String}`: Columns forming the unique constraint.
- `table_name::String`: Target table name.
- `schema::String`: Target schema name (default `"public"`).
- `batch_size::Int`: Rows per INSERT statement (default `500`).
"""
function insert_if_not_exists(
    conn::LibPQ.Connection,
    df::DataFrame,
    unique_key_columns::Vector{String},
    table_name::String;
    schema::String = "public",
    batch_size::Int = 500
)
    nrow(df) == 0 && return nothing
    col_names = string.(names(df))
    suffix = _build_conflict_clause(unique_key_columns, col_names, false)
    _execute_batched(conn, df, col_names, table_name, schema, suffix, batch_size)
end

export upsert_dataframe, insert_if_not_exists

end