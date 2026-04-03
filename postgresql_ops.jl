# postgresql_upsert.jl
#
# Ref: https://www.postgresql.org/docs/current/sql-insert.html#SQL-ON-CONFLICT
# Ref: https://github.com/invenia/LibPQ.jl

module PostgresqlOps
using LibPQ
using DataFrames
using Tables


"""
    _build_insert_sql(table_name, schema, col_names)

Build the base `INSERT INTO ... VALUES ...` SQL string with \$-numbered placeholders,
returning (sql_prefix, column_names_quoted).
"""
function _build_insert_sql(table_name::String, schema::String, col_names::Vector{String})
    quoted_cols = [string('"', c, '"') for c in col_names]
    col_list = join(quoted_cols, ", ")
    placeholders = join([string("\$", i) for i in 1:length(col_names)], ", ")
    sql = """INSERT INTO "$(schema)"."$(table_name)" ($(col_list)) VALUES ($(placeholders))"""
    return sql, quoted_cols
end


"""
    upsert_dataframe(conn, df, unique_key_columns, table_name; schema="public")

Perform a bulk INSERT ... ON CONFLICT DO UPDATE (upsert) of a DataFrame
to a PostgreSQL table.

Rows that conflict on `unique_key_columns` are updated with the new values
for all non-key columns.

# Arguments
- `conn::LibPQ.Connection`: An open LibPQ connection.
- `df::DataFrame`: The data to upsert.
- `unique_key_columns::Vector{String}`: Columns forming the unique constraint.
- `table_name::String`: Target table name.
- `schema::String`: Target schema name (default `"public"`).
"""
function upsert_dataframe(
    conn::LibPQ.Connection,
    df::DataFrame,
    unique_key_columns::Vector{String},
    table_name::String;
    schema::String = "public"
)
    nrow(df) == 0 && return nothing

    col_names = string.(names(df))
    base_sql, quoted_cols = _build_insert_sql(table_name, schema, col_names)

    # ON CONFLICT (key_cols) DO UPDATE SET non_key = EXCLUDED.non_key
    conflict_cols = join([string('"', c, '"') for c in unique_key_columns], ", ")
    update_cols = filter(c -> c ∉ unique_key_columns, col_names)

    if isempty(update_cols)
        # Nothing to update — degenerate to DO NOTHING
        sql = base_sql * " ON CONFLICT ($(conflict_cols)) DO NOTHING"
    else
        set_clause = join(
            [string('"', c, '"', " = EXCLUDED.", '"', c, '"') for c in update_cols],
            ", "
        )
        sql = base_sql * " ON CONFLICT ($(conflict_cols)) DO UPDATE SET $(set_clause)"
    end

    # Execute row-by-row inside a single transaction for atomicity.
    # For large DataFrames, consider batching with COPY or multi-row VALUES.
    execute(conn, "BEGIN;")
    try
        for row in eachrow(df)
            params = [ismissing(row[c]) ? nothing : row[c] for c in col_names]
            execute(conn, sql, params)
        end
        execute(conn, "COMMIT;")
    catch e
        execute(conn, "ROLLBACK;")
        rethrow(e)
    end

    return nothing
end


"""
    insert_if_not_exists(conn, df, unique_key_columns, table_name; schema="public")

Perform a bulk INSERT ... ON CONFLICT DO NOTHING of a DataFrame
to a PostgreSQL table.

Rows that conflict on `unique_key_columns` are silently skipped.

# Arguments
- `conn::LibPQ.Connection`: An open LibPQ connection.
- `df::DataFrame`: The data to insert.
- `unique_key_columns::Vector{String}`: Columns forming the unique constraint.
- `table_name::String`: Target table name.
- `schema::String`: Target schema name (default `"public"`).
"""
function insert_if_not_exists(
    conn::LibPQ.Connection,
    df::DataFrame,
    unique_key_columns::Vector{String},
    table_name::String;
    schema::String = "public"
)
    nrow(df) == 0 && return nothing

    col_names = string.(names(df))
    base_sql, _ = _build_insert_sql(table_name, schema, col_names)

    conflict_cols = join([string('"', c, '"') for c in unique_key_columns], ", ")
    sql = base_sql * " ON CONFLICT ($(conflict_cols)) DO NOTHING"

    execute(conn, "BEGIN;")
    try
        for row in eachrow(df)
            params = [ismissing(row[c]) ? nothing : row[c] for c in col_names]
            execute(conn, sql, params)
        end
        execute(conn, "COMMIT;")
    catch e
        execute(conn, "ROLLBACK;")
        rethrow(e)
    end

    return nothing
end

export upsert_dataframe, insert_if_not_exists

end