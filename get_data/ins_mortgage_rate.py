import logging
import os
import re
import sys
from io import StringIO

import pandas as pd
from bs4 import BeautifulSoup
from requests import Session
from sqlalchemy import create_engine

from postgresql_upsert import insert_if_not_exists

# %% Initialization.
logging.basicConfig(
    level=logging.INFO,
    format="[%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
    ],
)
session = Session()

# %% Fetch borrowing page.
response = session.get("https://www.interest.co.nz/borrowing")
response.raise_for_status()
html = BeautifulSoup(response.text, "html.parser")
banks_h2 = html.find("h2", string=re.compile("Banks"))
data_table_raw = banks_h2.parent.find(
    "table", {"id": "interest_financial_datatable"})

# %% Get bank name.
rows = data_table_raw.find("tbody").find_all("tr")
bank_names = []
for row in rows:
    bank_col = row.find("td")  # Assume first column is bank logo
    container = bank_col.find("img") or bank_col.find("a") or bank_col
    bank_name = container.get('title') or container.text or pd.NA
    # Remove ads or suffixes
    if isinstance(bank_name, str):
        bank_name = re.sub(r"Home.*more", "", bank_name)  # TSB
        bank_name = re.sub(r"click.*contact", "", bank_name)  # SBS, BNZ
        bank_name = re.sub(r" - .*", "", bank_name)  # ASB
        bank_name = bank_name.strip()[:32]
    bank_names.append(bank_name)

# %% Get column names.
data_table = pd.read_html(StringIO(str(data_table_raw)))[0]
assert len(bank_names) == data_table.shape[0]
data_table['bank'] = bank_names
data_table['bank'] = data_table['bank'].ffill()

_18_months_rows = data_table.apply(
    lambda col: col.str.contains(r"18 months =", na=False, regex=True)
).any(axis=1)

table_1 = data_table.iloc[~_18_months_rows, :]
table_2 = data_table.iloc[_18_months_rows, :]
table_1['_18_months'] = (table_2.iloc[:, 2].str.extract(r'=\s*([0-9]*\.?[0-9]+)')
                         .astype(float))
table_1.rename(columns={
    "Product": "product",
    "Variable floating": "floating",
    "6 months": "_6_months",
    "1 year": "_1_year",
    "2 years": "_2_years",
    "3 years": "_3_years",
    "4 years": "_4_years",
    "5 years": "_5_years",
}, inplace=True)
del table_1['Institution']

# %% Export.
data_cols = table_1.columns.difference(['bank', 'product'])
table_1.dropna(subset=data_cols, how="all", inplace=True)
table_1.drop_duplicates(subset=["bank", "product"], inplace=True)
table_1['date'] = pd.Timestamp('now', tz='Pacific/Auckland').date()
table_1 = table_1.convert_dtypes()

engine = create_engine(os.environ["NEON_DB"])
insert_if_not_exists(
    engine, table_1,
    ["date", "bank", "product"],
    "ins_mortgage_rate"
)
