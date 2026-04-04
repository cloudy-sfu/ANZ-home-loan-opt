# ANZ home loan opt
Optimize financial cost under ANZ home loan policy

![](https://shields.io/badge/dependencies-Julia_1.12-purple)

## Install

Install Julia 1.12 and activate the project.

Environment variables:

| Variable | Description                         |
| -------- | ----------------------------------- |
| NEON_DB  | Connection string to Neon database. |

*Define these variables in session level before running any Julia script.*

### Database

Create a [Neon](https://neon.com/) PostgreSQL 18.3 database. "Settings > Compute defaults > Scale to zero" must keep default (5 minutes) or longer.

Setup the database schema by `database_schema.sql`.

>   [!note]
>
>   Any other self-hosted or serverless PostgreSQL database release works, but not tested. If using other database, the connection string to Neon database should be replaced by the connection string of your own PostgreSQL database, which looks like `postgresql://<username>:<password>@<domain>/<database_name>?sslmode=require&channel_binding=require`.
>

### GitHub Actions

Deploy this program in GitHub and enable GitHub Actions for this repository. Manually run each scheduled job once, to initially save data into database and ensure all the GitHub Actions are active.

Add environment variables into GitHub repository settings "Secrets and variables > Actions > Secrets > Repository secrets".



## Usage

Fill the form and export the config at https://cloudy-sfu.github.io/ANZ-home-loan-opt/create_config.html



### Historical institution mortgage interest rate

>   Acknowledgement & dependency: https://github.com/simonbetton/ratesapi.nz

To collect historical institution mortgage interest rate one-off since 2025-03-08, use the following instruction.

Let `$start_date` be the first day (inclusive) of missing data, which must be no earlier than 2025-03-08.

Let `$end_date` be the last day (inclusive) of missing data.

Run the following command.

```
julia get_data/ins_mortgage_rate_historical.jl $start_date $end_date
```

It only covers partial of the banks.

