import os

import matplotlib.pyplot as plt
import pandas as pd
import statsmodels.api as sm
from sqlalchemy import create_engine, text

# %% Load data.
engine = create_engine(os.environ['NEON_DB'], pool_recycle=300)
with open("sqls/resample_avg_mortgage_rate.sql") as f:
    sql_avg = f.read()
with open("sqls/resample_ins_mortgage_rate.sql") as f:
    sql_ins = f.read()
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

avg = avg.convert_dtypes()
anz_standard = anz_standard.convert_dtypes()
anz_special = anz_special.convert_dtypes()

anz_standard = anz_standard.dropna(axis=1, how='all')
anz_special = anz_special.dropna(axis=1, how='all')

avg.set_index('date', inplace=True)
anz_standard.set_index('date', inplace=True)
anz_special.set_index('date', inplace=True)

# %% Fill missing value.
avg = avg.bfill()
anz_standard = anz_standard.bfill()
anz_special = anz_special.bfill()

# %% Align average and instance.
xy_standard = pd.merge(avg, anz_standard, how='inner', left_index=True, right_index=True,
                       suffixes=('_avg', '_anz'))
xy_special = pd.merge(avg, anz_special, how='inner', left_index=True, right_index=True,
                      suffixes=('_avg', '_anz'))

# %% Hypothesis testing on ANZ standard.
slope_one = []
fig, ax = plt.subplots(figsize=(11, 8))
colors = plt.get_cmap('tab10')
handles = []
labels = []
data_min = float('inf')
data_max = float('-inf')

for i, col in enumerate(anz_standard.columns):
    y = xy_standard[f"{col}_anz"].astype(float)
    x = xy_standard[[f"{col}_avg"]].astype(float)
    x_0 = sm.add_constant(x)

    model = sm.OLS(y, x_0).fit()
    intercept = model.params.iloc[0]
    slope = model.params.iloc[1]
    hypothesis = f"{col}_avg = 1"
    t_test = model.t_test(hypothesis)
    slope_one.append({
        "special": False,
        "term": col,
        "slope": slope,
        "t": t_test.tvalue.item(),
        "p": t_test.pvalue.item(),
    })

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
plt.savefig("results/anz_standard_univariate.pdf")

# %% Hypothesis testing on ANZ special.
fig, ax = plt.subplots(figsize=(11, 8))
handles = []
labels = []
data_min = float('inf')
data_max = float('-inf')

for i, col in enumerate(anz_special.columns):
    y = xy_special[f"{col}_anz"].astype(float)
    x = xy_special[[f"{col}_avg"]].astype(float)
    x_0 = sm.add_constant(x)

    model = sm.OLS(y, x_0).fit()
    intercept = model.params.iloc[0]
    slope = model.params.iloc[1]
    hypothesis = f"{col}_avg = 1"
    t_test = model.t_test(hypothesis)
    slope_one.append({
        "special": True,
        "term": col,
        "slope": slope,
        "t": t_test.tvalue.item(),
        "p": t_test.pvalue.item(),
    })

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
plt.savefig("results/anz_special_univariate.pdf")

# %% Export.
slope_one = pd.DataFrame(slope_one)
slope_one.to_csv("results/slope_is_1_univariate.csv", index=False)
