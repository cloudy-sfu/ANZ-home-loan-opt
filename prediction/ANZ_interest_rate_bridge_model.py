import os

import matplotlib.pyplot as plt
import pandas as pd
from sklearn.linear_model import MultiTaskLassoCV, LinearRegression
from sklearn.metrics import r2_score
from sqlalchemy import create_engine, text

from postgresql_upsert import upsert_dataframe

# %% Load data.
engine = create_engine(os.environ['NEON_DB'], pool_recycle=300)
with open("sqls/resample_avg_mortgage_rate.sql") as f:
    sql_avg = f.read()
with open("sqls/resample_ins_mortgage_rate.sql") as f:
    sql_ins = f.read()
with open("sqls/resample_ocr.sql") as f:
    sql_ocr = f.read()
with open("sqls/resample_wholesale_swap_rate.sql") as f:
    sql_swap = f.read()
with engine.connect() as c:
    avg = pd.read_sql(text(sql_avg), c)
    anz_standard = pd.read_sql(text(sql_ins), c, params={
        'bank': 'ANZ',
        'special': False
    })
    anz_special = pd.read_sql(text(sql_ins), c, params={
        'bank': 'ANZ',
        'special': True
    })
    ocr = pd.read_sql(text(sql_ocr), c)
    swap = pd.read_sql(text(sql_swap), c)

avg = avg.convert_dtypes()
anz_standard = anz_standard.convert_dtypes()
anz_special = anz_special.convert_dtypes()
ocr = ocr.convert_dtypes()
swap = swap.convert_dtypes()

anz_standard = anz_standard.dropna(axis=1, how='all')
anz_special = anz_special.dropna(axis=1, how='all')

avg.set_index('date', inplace=True)
anz_standard.set_index('date', inplace=True)
anz_special.set_index('date', inplace=True)
ocr.set_index('date', inplace=True)
swap.set_index('date', inplace=True)

# %% Fill missing value.
avg = avg.bfill()
anz_standard = anz_standard.bfill()
anz_special = anz_special.bfill()
ocr = ocr.bfill()
swap = swap.bfill()

# %% Make datasets.
# STANDARD
idx_train_standard = (anz_standard.index.intersection(avg.index).intersection(ocr.index)
                      .intersection(swap.index))
idx_test_standard = (avg.index.intersection(ocr.index).intersection(swap.index)
                     .difference(idx_train_standard))
x_standard_train = pd.concat([avg.loc[idx_train_standard], ocr.loc[idx_train_standard],
                              swap.loc[idx_train_standard]], axis=1)
y_standard_train = anz_standard.loc[idx_train_standard]
x_standard_test = pd.concat([avg.loc[idx_test_standard], ocr.loc[idx_test_standard],
                             swap.loc[idx_test_standard]], axis=1)
cols_standard = anz_standard.columns.difference(["date"])

# SPECIAL
idx_train_special = (anz_special.index.intersection(avg.index).intersection(ocr.index)
                     .intersection(swap.index))
idx_test_special = (avg.index.intersection(ocr.index).intersection(swap.index)
                    .difference(idx_train_special))
x_special_train = pd.concat([avg.loc[idx_train_special], ocr.loc[idx_train_special],
                             swap.loc[idx_train_special]], axis=1)
y_special_train = anz_special.loc[idx_train_special]
x_special_test = pd.concat([avg.loc[idx_test_special], ocr.loc[idx_test_special],
                            swap.loc[idx_test_special]], axis=1)
cols_special = anz_special.columns.difference(["date"])

# %% Train models.
model_standard = MultiTaskLassoCV(max_iter=2000)
model_standard.fit(x_standard_train, y_standard_train)
y_standard_train_hat = model_standard.predict(x_standard_train)
r2_standard = [
    r2_score(y_standard_train.iloc[:, i], y_standard_train_hat[:, i])
    for i in range(y_standard_train.shape[1])
]
r2_standard = pd.Series(data=r2_standard, index=y_standard_train.columns)

pd.to_pickle(model_standard, "raw/bridge_standard")

model_special = MultiTaskLassoCV(max_iter=2000)
model_special.fit(x_special_train, y_special_train)
y_special_train_hat = model_special.predict(x_special_train)
r2_special = [
    r2_score(y_special_train.iloc[:, i], y_special_train_hat[:, i])
    for i in range(y_special_train.shape[1])
]
r2_special = pd.Series(data=r2_special, index=y_special_train.columns)

pd.to_pickle(model_special, "raw/bridge_special")

r2 = pd.DataFrame({"standard_train": r2_standard, "special_train": r2_special})
r2 = r2.convert_dtypes()
r2.to_csv("results/bridge_r2.csv", index_label="term")

# %% Predict.
y_standard_test_hat = model_standard.predict(x_standard_test)
y_standard_test_hat = pd.DataFrame(
    data=y_standard_test_hat,
    index=x_standard_test.index,
    columns=y_standard_train.columns,
)
y_special_test_hat = model_special.predict(x_special_test)
y_special_test_hat = pd.DataFrame(
    data=y_special_test_hat,
    index=x_special_test.index,
    columns=y_special_train.columns,
)


# %% Visualization predictions.
fig, ax = plt.subplots(figsize=(11, 8))
colors = plt.get_cmap('tab10')
handles = []
labels = []
data_min = float('inf')
data_max = float('-inf')

for i, col in enumerate(y_standard_train.columns):
    y = y_standard_test_hat[col]
    x = avg.loc[idx_test_standard, [col]]

    model = LinearRegression()
    model.fit(x, y)
    intercept = model.intercept_
    slope = model.coef_[0]

    color = colors(i % 10)
    p1 = ax.scatter(x.iloc[:, 0], y, color=color, alpha=0.6)
    p2 = ax.axline(xy1=(0, intercept), slope=slope, color=color, linewidth=2)
    handles.extend([p1, p2])
    labels.extend([f'{col} (data)', f'{col} (fit)'])

    data_min = min(data_min, x.iloc[:, 0].min(), y.min())
    data_max = max(data_max, x.iloc[:, 0].max(), y.max())

ax.axline(xy1=(0, 0), slope=1, color='red', linestyle='--')
margin = (data_max - data_min) * 0.05
axis_lower_bound = data_min - margin
axis_upper_bound = data_max + margin
ax.set_aspect('equal', adjustable='box')
ax.set_xlim((axis_lower_bound, axis_upper_bound))
ax.set_ylim((axis_lower_bound, axis_upper_bound))
ax.set_xlabel('Average')
ax.set_ylabel('ANZ Standard')
ax.set_title("ANZ Standard")
ax.legend(handles, labels, bbox_to_anchor=(1.05, 1), loc='upper left')
plt.tight_layout()
plt.savefig("results/anz_standard_bridge.pdf")

fig, ax = plt.subplots(figsize=(11, 8))
colors = plt.get_cmap('tab10')
handles = []
labels = []
data_min = float('inf')
data_max = float('-inf')

for i, col in enumerate(y_special_train.columns):
    y = y_special_test_hat[col]
    x = avg.loc[idx_test_special, [col]]

    model = LinearRegression()
    model.fit(x, y)
    intercept = model.intercept_
    slope = model.coef_[0]

    color = colors(i % 10)
    p1 = ax.scatter(x.iloc[:, 0], y, color=color, alpha=0.6)
    p2 = ax.axline(xy1=(0, intercept), slope=slope, color=color, linewidth=2)
    handles.extend([p1, p2])
    labels.extend([f'{col} (data)', f'{col} (fit)'])

    data_min = min(data_min, x.iloc[:, 0].min(), y.min())
    data_max = max(data_max, x.iloc[:, 0].max(), y.max())

ax.axline(xy1=(0, 0), slope=1, color='red', linestyle='--')
margin = (data_max - data_min) * 0.05
axis_lower_bound = data_min - margin
axis_upper_bound = data_max + margin
ax.set_aspect('equal', adjustable='box')
ax.set_xlim((axis_lower_bound, axis_upper_bound))
ax.set_ylim((axis_lower_bound, axis_upper_bound))
ax.set_xlabel('Average')
ax.set_ylabel('ANZ Special')
ax.set_title("ANZ Special")
ax.legend(handles, labels, bbox_to_anchor=(1.05, 1), loc='upper left')
plt.tight_layout()
plt.savefig("results/anz_special_bridge.pdf")

# %% Export.
y_standard_test_hat.reset_index(inplace=True)
y_standard_test_hat['bank_product'] = 'anz_standard'
upsert_dataframe(
    engine, y_standard_test_hat,
    ["date", "bank_product"],
    "ins_mortgage_rate_pred"
)
y_special_test_hat.reset_index(inplace=True)
y_special_test_hat['bank_product'] = 'anz_special'
upsert_dataframe(
    engine, y_special_test_hat,
    ["date", "bank_product"],
    "ins_mortgage_rate_pred"
)
