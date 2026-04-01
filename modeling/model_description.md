# 1. Objective

The primary objective of this optimization problem is to determine the most cost-effective mortgage repayment strategy over the lifetime of the loan. This involves making dynamic decisions each month regarding interest rate structures (choosing between floating or various fixed terms), making occasional lump-sum principal reductions, adjusting the scheduled loan term, and determining how to partition the loan across multiple sub-loans. The goal is to minimize the total financial cost (total interest paid plus any penalty fees incurred) while strictly adhering to the borrower’s cash flow constraints.

# 2. Available Data and Sampling Frequencies

The model operates on a base monthly decision-making cycle, but integrates mixed-frequency historical and projected data:

-   Retail Interest Rates: Sampled weekly. This includes historical floating rates and fixed-term rates (for 0.5, 1, 1.5, 2~5 years terms) dating back to 2002.
-   Wholesale Swap Rates: Sampled daily. This represents the interbank rates for 1~5, 7, 10 years terms, dating back to 2007, used exclusively to estimate the bank's financial loss when a fixed rate is broken.
-   Occasional One-Off Income: A sparse time series aligned with the monthly base frequency. This represents unpredictable (but probabilistically forecastable) windfalls.
-   Disposable Salary Income: Aligned with the monthly base frequency. This represents the borrower's surplus income after taxes, necessities, and living expenses. It acts as a recursive step function: when a life event changes the salary or living costs, the new monthly disposable income value remains constant for all subsequent months until another adjustment event occurs. This value can be negative (indicating a cash shortfall).

# 3. Required Policy Constants (Parameters)

To evaluate bank policies without hardcoding specific numbers, the following mutable constants are defined for the model:

-   Monthly Repayment Date: A fixed integer (e.g., the 1st or 15th) representing the specific day of the month when the scheduled mortgage payment is deducted. This date acts as the anchor for point-in-time extraction of daily/weekly financial market data.
-   Penalty-Free Lump Sum Percentage Threshold: The fraction of the current loan amount that can be paid off as a lump sum annually without triggering early repayment penalties.
-   Penalty-Free Payment Increase Threshold: The maximum monetary amount by which the regular scheduled payment can be increased annually without triggering penalties.
-   Flat Restructure / Administration Fee: A fixed monetary transaction fee charged by the bank when manually breaking a contract or restructuring the loan, besides a dynamic breaking fee calculated based on wholesale swap rate.
-   Bank Margin: The percentage difference between the retail interest rate offered to the customer and the underlying wholesale swap rate.
-   Cashback Percentage: The percentage of the loan principal offered by the bank as a cash incentive upon drawdown or refinancing.
-   Cashback Clawback Period: The minimum time period (e.g., 36 months) the loan must remain active. If the loan is fully repaid before this period expires, a full or pro-rata clawback of the cashback incentive is enforced.
-   Maximum Loan Split Parts: The maximum number of concurrent sub-loan parts that the home loan may be divided into. This is a configurable constant (e.g., 4), and the model must enforce that the total number of active loan parts never exceeds this limit.

# 4. System Dynamics and Cash Flow

The system manages two primary balances: the outstanding loan principal and a zero-interest savings pool. Each month, the disposable salary income, any occasional one-off income, and any bank cashback incentives are deposited into the savings pool. The scheduled mortgage payment is deducted from this pool. Because the savings pool accrues zero interest, holding cash there is mathematically inefficient compared to reducing the loan principal. However, the borrower may dynamically choose to hold funds in the savings pool to weather negative disposable income months or to wait out a fixed-term contract to avoid break fees. Funds in the savings pool can be split at any time: a portion can be retained in the pool, a portion applied as a one-off lump-sum repayment to the principal, or a portion used to permanently subsidize increased scheduled monthly payments.

The outstanding mortgage itself may also be partitioned into multiple concurrent sub-loans, where each part can have its own rate type, fixed term, repayment profile, and remaining balance. This allows the model to represent common loan-structuring strategies such as staggering fixed-rate expiries. However, at all times, the number of active sub-loan parts must be less than or equal to the Maximum Loan Split Parts constant.

# 5. Decision Space and Penalty Mechanics

At each monthly interval (anchored by the Monthly Repayment Date), the model evaluates whether to maintain the current loan setup or execute a change. All bank penalty rules are treated as soft conditions: the model is permitted to violate penalty-free thresholds, break contracts, or trigger clawbacks entirely, provided the calculated long-term interest savings exceed the immediate penalty costs.

-   Rate Switching and Contract Breaking: The model can decide to break an existing fixed-term contract early to switch to a floating rate or a new fixed rate. Doing so triggers an early repayment penalty calculation. The penalty is estimated by comparing the daily wholesale swap rate locked in at the start of the contract against the daily wholesale swap rate on the day of the break, applied to the remaining fixed duration and the outstanding principal. The Flat Restructure Fee is also added to this cost.
-   Lump-Sum Repayments: The model can allocate funds from the savings pool to reduce the principal. If the loan is currently on a fixed rate and the lump sum exceeds the Penalty-Free Lump Sum Percentage Threshold, an early repayment penalty is calculated using the swap rate differential, applied strictly to the excess repayment amount. The Flat Restructure Fee is also added to this cost.
-   Loan Term Adjustment: The model can restructure the loan to shorten or extend the repayment years, thereby changing the scheduled monthly payment. If the loan is fixed and the payment increase exceeds the Penalty-Free Payment Increase Threshold, an early repayment penalty is calculated using the swap rate differential applied strictly to the delta (the excess payment amount), rather than treating the entire sub-loan as a completely broken contract. The Flat Restructure Fee may also apply.
-   Loan Splitting and Repartitioning: The model may split a home loan into multiple sub-loan parts or merge/repartition existing parts as part of a restructuring decision, subject to bank policy and any applicable restructuring costs. Each sub-loan part may independently carry a floating rate or a selected fixed-rate term. The total number of active sub-loan parts must never exceed the Maximum Loan Split Parts constant. Any decision that would create more than this number of parts is infeasible and must be excluded from the decision space.
-   Cashback Clawback Execution: If the model's optimization decisions result in the total outstanding principal being reduced to zero before the Cashback Clawback Period expires, a clawback penalty (full or pro-rated, depending on the model's policy configuration) equal to the original cashback incentive is added to the penalty costs for that month.

The ultimate output of the model is a monthly policy sequence prescribing the exact amount of cash to hold, the amount to apply as lump sums, the optimal scheduled loan term, the partition of the loan into sub-loan parts, and the specific rate type to lock in for each part to maximize the borrower’s net financial benefit.
