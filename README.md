# ANZ home loan opt
Optimize financial cost under ANZ home loan policy

![](https://shields.io/badge/dependencies-Python_3.14-blue)

## Install

Create a Python virtual environment and activate.

Add the following variables to the environment variables in session level.

| Variable | Description                         |
| -------- | ----------------------------------- |
| NEON_DB  | Connection string to Neon database. |



### Database

Create a [Neon](https://neon.com/) PostgreSQL 18.3 database. "Settings > Compute defaults > Scale to zero" must keep default (5 minutes) or longer.

Setup the database schema by `database_schema.sql`.

>   [!note]
>
>   Any other PostgreSQL database release may work, but is not tested. If using other database, replace the [connection string](https://neon.com/docs/connect/connect-from-any-app) to Neon database by the [connection string](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING) to your own PostgreSQL database.

### GitHub Actions

Deploy this program in GitHub and enable GitHub Actions for this repository. Manually run each scheduled job once, to initially save data into database and ensure all the GitHub Actions are active.

Add environment variables into GitHub repository settings "Secrets and variables > Actions > Secrets > Repository secrets".

### Historical institution mortgage interest rate

>   Acknowledgement & dependency: https://github.com/simonbetton/ratesapi.nz

To collect historical institution mortgage interest rate one-off since 2025-03-08, use the following instruction.

Let `$start_date` be the first day (inclusive) of missing data, which must be no earlier than 2025-03-08.

Let `$end_date` be the last day (inclusive) of missing data.

Run the following command.

```
python get_data/ins_mortgage_rate_historical.py $start_date $end_date
```

It only covers partial of the banks.



## Usage

Fill the form and export the config at https://cloudy-sfu.github.io/ANZ-home-loan-opt/create_config.html



