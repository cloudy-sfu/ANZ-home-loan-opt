import os
from argparse import ArgumentParser

import pandas as pd
from requests import Session
from sqlalchemy import create_engine

from postgresql_upsert import insert_if_not_exists

parser = ArgumentParser()
parser.add_argument("--start_date", type=str, help="Start date in YYYY-MM-DD format")
parser.add_argument("--end_date", type=str, help="End date in YYYY-MM-DD format")
cmd, _ = parser.parse_known_args()

session = Session()
display_to_db_col_names = {
    "6 months": "_6_months",
    "1 year": "_1_year",
    "18 months": "_18_months",
    "2 years": "_2_years",
    "3 years": "_3_years",
    "4 years": "_4_years",
    "5 years": "_5_years",
    "Variable floating": "floating",
}

institutions = {
    "institution:anz": "ANZ",
    "institution:asb": "ASB",
    "institution:bnz": "BNZ",
    "institution:kiwibank": "Kiwibank",
    "institution:westpac": "Westpac",
}
loan_rates = []

for inst_id, bank_name in institutions.items():
    response = session.get(
        "https://ratesapi.nz/api/v1/mortgage-rates/time-series",
        params={
            "startDate": cmd.start_date,
            "endDate": cmd.end_date,
            "institutionId": inst_id,
        }
    )
    response.raise_for_status()
    time_series = response.json()['timeSeries']
    for k, v in time_series.items():
        products = v['data'][0]['products']
        for product in products:
            rates = product['rates']
            for rate in rates:
                rate['date'] = k
                rate['product'] = product['name']
                rate['bank'] = bank_name
                loan_rates.append(rate)
loan_rates = pd.DataFrame(loan_rates)
loan_rates = loan_rates.pivot(
    index=['date', 'product', 'bank'],
    columns='term',
    values='rate'
).reset_index()
loan_rates.rename(columns={
    "6 months": "_6_months",
    "1 year": "_1_year",
    "18 months": "_18_months",
    "2 years": "_2_years",
    "3 years": "_3_years",
    "4 years": "_4_years",
    "5 years": "_5_years",
    "Variable floating": "floating",
}, inplace=True)
data_cols = loan_rates.columns.difference(["date", 'bank', 'product'])
loan_rates.dropna(subset=data_cols, how="all", inplace=True)
loan_rates.drop_duplicates(subset=["date", "bank", "product"], inplace=True)
loan_rates = loan_rates.convert_dtypes()

# Database connection
engine = create_engine(os.environ['NEON_DB'], pool_recycle=300)
for i in range(0, loan_rates.shape[0], 500):
    insert_if_not_exists(
        engine, loan_rates.iloc[i:i+500, :],
        ["date", "bank", "product"],
        "ins_mortgage_rate"
    )
