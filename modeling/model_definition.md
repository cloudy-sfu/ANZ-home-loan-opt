# Variables

## Sets

$t \in \mathcal{T}$: Time steps (months) over the evaluation horizon.

$i, j \in \mathcal{N}$: Sub-loan slots $\{1, 2, \dots, N\}$ (implicitly enforces the maximum loan split limit).

$k \in \mathcal{K}$: Available rate product terms in **months** (e.g., $\mathcal{K} = \{0, 6, 12, 18, 24, 36, 48, 60\}$). The value $k=0$ designates the floating rate product.

## Parameters (Given & Projected Data)

$d \in \{1, 2, \dots, 31\}$: The designated monthly repayment date.

$s_t$: Disposable salary income at month $t$. (Pre-processed: modeled as a recursive step-function $s_t = s_{t-1} + \Delta s_t$ where $\Delta s_t$ is non-zero only during life events.)

$o_t$: Expected occasional one-off windfall income at month $t$.

$q_t$: Official Cash Rate (OCR) at month $t$. (Pre-processed: extracted as the latest central bank rate immediately prior to $d$.)

$g_{k,t} > 0$: The underlying wholesale base rate for product $k$ at month $t$. For non-standard remaining durations, values are pre-interpolated to provide a continuous integer lookup grid. Rates are assumed strictly positive to prevent zero-division in annuity calculations. Pre-processed:

-   For fixed terms $k \ge 12$: $g_{k,t}$ is the daily wholesale swap rate (or interpolated) matching term $k$ months. 
-   For the 6-month fixed product ($k = 6$): Modeled as a blend of the OCR and the 1-year swap rate, $g_{6,t} = \lambda q_t + (1 - \lambda) g_{12,t}$.

$\lambda \in[0, 1]$: Empirical weighting parameter used to interpolate the 0.5-year wholesale base rate, derived from historical regression of 6-month rates against the OCR and 1-year swap rates.

$\hat{\mu}_{k,t}$: Predicted bank margin applied over the wholesale base rate for product $k$ at month $t$.

$r_{k,t}$: Retail interest rate for product $k$ at month $t$, defined dynamically as $r_{k,t} = g_{k,t} + \hat{\mu}_{k,t}$. 

$\alpha$: Penalty-free lump-sum threshold (percentage of principal).

$\beta$: Penalty-free payment increase threshold (absolute monetary amount per payment period). The bank's policy defines this limit in its native payment frequency. When the model's time step differs from the policy's native frequency, $\beta$ must be converted accordingly.

$\phi$: Flat restructure/administration transaction fee.

$\gamma$: Cashback incentive percentage (percentage of initial total loan amount).

$\tau$: Cashback clawback period (months).

$\theta \in \{0, 1\}$: Clawback policy toggle ($0$ for full clawback, $1$ for pro-rata clawback).

$T \in \mathbb{Z}_{>0}$: The length of the rolling prediction horizon in months (e.g., $T=60$). The evaluation horizon $\mathcal{T}$ spans from $t=1$ to $t=T$.

$\zeta \in (0, 1)$: Amortization interest discount factor. Because principal decays over time in an amortizing loan, the total future interest is not simply $\text{Balance} \times \text{Rate} \times \text{Years}$. The remaining balance curve bows outward. Mathematically, a linear decay would have an area under the curve of $0.5$. For standard amortizing loans, $\zeta \approx 0.55$ to $0.60$ is a highly accurate proxy for the true area under the interest decay curve.

## Initial Conditions (Given at $t = 0$)

| Symbol                           | Description                                                  |
| -------------------------------- | ------------------------------------------------------------ |
| $b_{i,0} \ge 0$                  | Initial outstanding principal of sub-loan $i$. Must satisfy $\sum_{i} b_{i,0} > 0$ (non-trivial loan). |
| $c_0 \ge 0$                      | Initial savings pool balance. Typically $s_0$ user-supplied externally (last month's salary before lending). |
| $\rho_{i,0} > 0$                 | Initial locked retail interest rate for sub-loan $i$. For floating slots, set $\rho_{i,0} = r_{0,0}$. |
| $m_{i,0} \in \mathbb{Z}_{\ge 0}$   | Initial remaining scheduled loan life (months) for sub-loan $i$. Set to $0$ for inactive (empty) slots. |
| $f_{i,0} \in \mathbb{Z}_{\ge 0}$ | Initial remaining fixed-rate contract duration (months). $0$ if floating. |
| $\xi_{i,0} > 0$               | Wholesale swap rate locked at the inception of the current fixed contract. For floating slots, set to a sentinel (e.g., $\xi_{i,0} = g_{0,0}$ or $0$; immaterial since $f_{i,0}=0$ zeroes out all penalty terms). |
| $u_{i,0} \in \mathbb{Z}_{\ge 0}$ | Months elapsed since the current contract started.           |
| $A^L_{i,0} \ge 0$                | Accumulated penalty-free lump sums in the current anniversary year at inception. |
| $A^P_{i,0} \in \{0, 1\}$ | Whether the one-time payment increase allowance has already been consumed in the current anniversary year at inception. |
| $a_{i,0} \ge 0$                  | Principal locked at the start of the current anniversary year. Typically $a_{i,0} = b_{i,0}$ if the model starts at a contract anniversary; otherwise the historical value. |
| $p_{i,0} \ge 0$                | The scheduled payment in the month immediately preceding the optimization horizon. Required by the payment non-decrease constraint at $t = 1$: $C_{i,1} = 0 \implies p_{i,1} \ge (1 - y_{i,1} - z_{i,1}) \cdot p_{i,0}$. |
| $x_0 = 0$                     | Sentinel: the loan was not fully repaid before the horizon. Required by the clawback edge-detection formula $\kappa_1 = (x_1 - x_0) \cdot (\dots)$. |

## State Variables (System Dynamics)

$b_{i,t} \ge 0$: Outstanding principal balance of sub-loan $i$ at the start of $t$.

$c_t \ge 0$: Zero-interest savings pool balance at the start of $t$.

$\rho_{i,t}$: Retail interest rate in force for sub-loan $i$ during month $t$'s interest accrual. This is the rate established by the restructure decision (or lack thereof) at the end of month $t-1$'s cycle. It represents the outgoing rate from the previous period and is used exclusively for computing interest $\iota_{i,t}$. It is not the rate that would result from any restructure decision made at month $t$; that decision determines $\rho_{i,t+1}$.

$m_{i,t}$: Scheduled remaining life of sub-loan $i$ (months) at the start of $t$.

$f_{i,t}$: Remaining duration on the fixed-rate contract for $i$ at the start of $t$ ($0$ if floating).

$\xi_{i,t}$: Wholesale swap rate locked in at the start of the current fixed contract for $i$.

$u_{i,t} \in \mathbb{Z}_{\ge 0}$: The number of months elapsed since the current fixed-rate contract for sub-loan $i$ started. 

$A^L_{i,t}$: Accumulated penalty-free lump sum payments made on sub-loan $i$ during the current anniversary year.

$A^P_{i,t} \in \{0, 1\}$: Binary flag indicating whether the one-time penalty-free payment increase allowance ($\beta$) has already been consumed for sub-loan $i$ in the current anniversary year. $A^P_{i,t} = 1$ means the allowance is exhausted.

$a_{i,t}$: Principal balance of sub-loan $i$ locked at the start of its current anniversary year.

## Decision Variables (Control Actions at time $t$)

$\eta_t \ge 0$: Emergency cash shortfall (slack variable) injected at month $t$ to prevent model infeasibility when disposable salary ($s_t$) is heavily negative.

$l_{i,t} \ge 0$: Lump-sum principal reduction applied to sub-loan $i$.

$p_{i,t} \ge 0$: New scheduled regular monthly payment for sub-loan $i$.

$\delta_{i,t,k} \in \{0, 1\}$: Binary variable selecting rate product $k$ for sub-loan $i$.

$\Delta v_{i,t} \in \mathbb{R}$: Net principal repartitioned into (positive) or out of (negative) sub-loan $i$.

$n_{i,t} \in \mathbb{Z}_{\ge 0}$: The new scheduled loan term (remaining life in months) chosen for sub-loan $i$ at month $t$ (applied if $y_{i,t} = 1$).

$z_{i,t} \in \{0, 1\}$: Binary variable equal to $1$ if the scheduled loan term for sub-loan $i$ is restructured at month $t$, increased or decreased repayment, but didn't change the current rate product.

## Auxiliary Variables

$\iota_{i,t}$: Scheduled interest accrued.

$\epsilon^C_{i,t}$: Early repayment penalty from breaking a contract.

$\epsilon^L_{i,t}$: Early repayment penalty from excess lump-sum payments.

$\epsilon^P_{i,t}$: Early repayment penalty from excess payment increases.

$\psi_{i,t}$: Flat restructure fees triggered.

$\kappa_t$: Cashback clawback penalty.

$x_t \in \{0, 1\}$: Binary state indicator equal to $1$ if the *entire* loan balance is zero at month $t$ (Level Trigger).

$C_{i,t} \in \{0, 1\}$: Binary state indicator equal to $1$ if the specific sub-loan $i$ drops to a zero balance at month $t$.

$h_{i,t} \in \{0, 1\}$: Binary indicator equal to $1$ if a flat fee is triggered for sub-loan $i$ at month $t$ (due to a contract break, excess lump-sum, or excess payment increase).

$y_{i,t} \in \{0, 1\}$: Indicating if a contract is restructured, defined as 
$$
y_{i,t} = \sum_{k \in \mathcal{K}} \delta_{i,t,k} \in \{0, 1\} \quad \forall\, i \in \mathcal{N},\; t \in \mathcal{T}
$$

# Objective Function

The objective is to minimize total financial friction (interest plus all penalties, fees, and severe penalties for cash shortfalls) over the loan lifetime.

Let $\Omega$ be a sufficiently large penalty weight for forced debt.

Let $T$ be the horizon length; the model evaluates states up to $t = T$.
$$
\min \sum_{t=0}^{T-1} \left( \Omega \cdot \eta_t + \kappa_t + \sum_{i \in \mathcal{N}} \left[ \iota_{i,t} + \epsilon^C_{i,t} + \epsilon^L_{i,t} + \epsilon^P_{i,t} + \psi_{i,t} \right] \right) + \sum_{i \in \mathcal{N}} \mathcal{V}_{i,T}
$$
where the terminal future interest proxy $\mathcal{V}_{i,T}$ is defined as:
$$
\mathcal{V}_{i,T} = b_{i,T} \cdot \rho_{i,T} \cdot \left( \frac{m_{i,T}}{12} \right) \cdot \zeta
$$

# Constraints and Dynamics

## Savings Pool Cash Flow

The pool funds all scheduled payments, lump sums, and penalties. It must not drop below zero. If income and current pool balances are insufficient to cover mandatory deductions, the slack variable $\eta_t$ provides the exact required shortfall to maintain feasibility.

$$
c_0 = s_0 + \gamma \sum_i b_{i,0} \\

c_t = c_{t-1} + s_t + o_t + \eta_t - \kappa_t - \sum_{i \in \mathcal{N}}\!\left(p_{i,t} + l_{i,t} + \epsilon^C_{i,t} + \epsilon^L_{i,t} + \epsilon^P_{i,t} + \psi_{i,t}\right) \quad \forall\, t \in \{1, \dots, T\}
$$

$$
c_t \ge 0 \quad \forall t
$$

To detect the exact month $t$ where the total balance hits zero and trigger the penalty exactly once, we define the binary cleared state $x_t$. 

The state $x_t$ evaluates the effective post-action principal across all slots:

$$
x_t = 1 \implies \sum_{i \in \mathcal{N}} b_{i,t+1} \le 0
$$

$$
x_t = 0 \implies \sum_{i \in \mathcal{N}} b_{i,t+1} \ge 0.01
$$

Note: 0.01 means absolute value $0.01 (one cent). If principal value is scaled to 1K, this value should be adjusted correspondingly.

Because the model does not allow redrawing closed debt, the cleared state is monotonically non-decreasing. To ensure solver stability:
$$
x_t \ge x_{t-1} \quad \forall t
$$

We calculate the clawback penalty exactly on the transition month by evaluating the edge directly (for $t=0$, assume $x_{-1} = 0$):
$$
\kappa_t = (x_t - x_{t-1}) \cdot \mathbb{1}(t < \tau) \cdot \gamma \sum_{i \in \mathcal{N}} b_{i,0}  \cdot \left[ (1 - \theta) + \theta \left( \frac{\tau - t}{\tau} \right) \right]
$$
## Sub-loan Principal and Interest Dynamics

Conservation of total debt requires that net transfers sum to zero. 
$$
\sum_{i \in \mathcal{N}} \Delta v_{i,t} = 0 \quad \forall t
$$

Furthermore, a transfer strictly forces a restructure on any slot where the net change is non-zero:
$$
y_{i,t} = 0 \implies \Delta v_{i,t} = 0
$$
Timing convention:

Within month $t$, events occur in the following order: (1) lump sums and transfers adjust the principal; (2) interest accrues under the pre-decision rate $\rho_{i,t}$; (3) the scheduled payment is applied; (4) restructure decisions execute, determining the successor state $\rho_{i,t+1}$. Consequently, the interest formula below uses $\rho_{i,t}$ (the rate locked before this month's decisions), while the minimum amortization formula in §Loan Term and Amortization Dynamics uses $\rho_{i,t+1}$ (the rate that will govern the new amortization schedule going forward). This is not a discrepancy — they serve different purposes.

Interest is calculated monthly based strictly on the principal after immediate reductions and transfers, and the retail rate that takes effect for month $t$ (represented by state variable $\rho_{i,t}$):
$$
\iota_{i,t} = \left[ b_{i,t} - l_{i,t} + \Delta v_{i,t} \right] \left( \frac{\rho_{i,t}}{12} \right)
$$

The outstanding balance transitions to the start of the next month. The scheduled payment is strictly bounded to prevent unbounded overpayment (which would artificially mine the savings pool):
$$
b_{i,t+1} = \left[ b_{i,t} - l_{i,t} + \Delta v_{i,t} \right] + \iota_{i,t} - p_{i,t}
$$

$$
b_{i,t+1} \ge 0 \quad \forall i, t
$$

$$
p_{i,t} \le \left[ b_{i,t} - l_{i,t} + \Delta v_{i,t} \right] + \iota_{i,t} \quad \forall i, t
$$

## Rate and Fixed Term State Transitions

Post-decision rate determination:

The following transition defines the rate that will govern interest accrual in month $t+1$. If a restructure occurs at month $t$ ($y_{i,t}=1$), the selected product's rate takes effect. Otherwise, the rate either persists (mid-contract fixed) or floats to the current market rate (expired or floating). Note that this rate does **not** retroactively affect month $t$'s interest, which has already been settled under $\rho_{i,t}$.

The new locked parameters for month $t$ immediately establish the states at $t+1$. Crucially, if the current fixed duration has expired ($f_{i,t} = 0$) and no restructure occurs, the retail rate automatically dynamically floats with the market rate $r_{0,t}$:
$$
\rho_{i,t+1} = y_{i,t} \sum_{k \in \mathcal{K}} \delta_{i,t,k} r_{k,t} + (1 - y_{i,t}) \left[ \mathbb{1}(f_{i,t} > 0)\rho_{i,t} + \mathbb{1}(f_{i,t} = 0)r_{0,t} \right]
$$

$$
\xi_{i,t+1} = (1 - y_{i,t})\xi_{i,t} + y_{i,t} \sum_{k \in \mathcal{K}} \delta_{i,t,k} g_{k,t}
$$

$$
f_{i,t+1} = \begin{cases} \sum_k \delta_{i,t,k} \cdot k & \text{if } y_{i,t} = 1 \\ \max(0,\; f_{i,t} - 1) & \text{if } y_{i,t} = 0 \end{cases}
$$

Note: $\delta_{i,t,k}$ is a binary choice of a rate product. If no restructure happens, all $\delta_{i,t,k} = 0$; if restructure happens, $1 - y_{i,t} = 0$. Therefore, the sum evaluates to 0 on its own, and do not need to multiply the entire sum by $y_{i,t}$ again.

$$
u_{i,t+1} = (1 - y_{i,t})(u_{i,t} + 1)
$$

## Loan Term and Amortization Dynamics

A contract cannot undergo a pure term adjustment and a rate switch simultaneously:

$$
y_{i,t} + z_{i,t} \le 1 \quad \forall i, t
$$

To determine the minimum scheduled amortization payment $p^M_{i,t}$, we first define the effective post-action principal $\tilde{b}_{i,t}$ and the effective scheduled term $\tilde{m}_{i,t}$ active for month $t$:

$$
\tilde{b}_{i,t} = b_{i,t} - l_{i,t} + \Delta v_{i,t} \ge 0 \quad \forall\, i \in \mathcal{N},\; t \in \mathcal{T} \\
b_{i,t} = 0 \land \Delta v_{i,t} = 0 \implies l_{i,t} = 0,\; p_{i,t} = 0,\; y_{i,t} = 0,\; z_{i,t} = 0
$$

$$
\tilde{m}_{i,t} = (1 - y_{i,t} - z_{i,t})m_{i,t} + (y_{i,t} + z_{i,t}) n_{i,t}
$$

Rate for amortization schedule:

The minimum payment $p^M_{i,t}$ is the instalment that would fully amortize the post-action principal $\tilde{b}_{i,t}$ over the effective term $\tilde{m}_{i,t}$ at the **post-decision** rate $\rho_{i,t+1}$. This is intentional: the minimum payment establishes the forward-looking repayment schedule under the rate that will be in force starting next month. When no restructure occurs on a mid-contract fixed loan, $\rho_{i,t+1} = \rho_{i,t}$ and the distinction is immaterial. When a restructure occurs, $\rho_{i,t+1}$ reflects the newly locked rate, correctly calibrating the new amortization profile.

Let $\tilde{r}_{i,t} = \frac{\rho_{i,t+1}}{12}$ represent the effective monthly retail interest rate. Assuming retail rates remain strictly positive due to bank margins ($\tilde{r}_{i,t} > 0$), the minimum mandatory payment strictly follows the standard amortizing annuity formula:
$$
p^M_{i,t} = \begin{cases} 
\tilde{b}_{i,t} \cdot \left[ \frac{\tilde{r}_{i,t}}{1 - \left( 1 + \tilde{r}_{i,t} \right)^{-\tilde{m}_{i,t}}} \right] & \text{if } \tilde{m}_{i,t} > 0 \\ 
\tilde{b}_{i,t} & \text{if } \tilde{m}_{i,t} = 0
\end{cases} \quad \forall i
$$

The borrower's chosen payment must meet or exceed this scheduled minimum:
$$
p_{i,t} \ge p^M_{i,t} \quad \forall i, t
$$

The scheduled payment cannot be decreased from the previous month's value unless the contract is formally restructured, OR the sub-loan is naturally clearing to zero. We define $C_{i,t} \in \{0, 1\}$ to disable the lower bound during the final clearing month:
$$
C_{i,t} = 1 \implies \tilde{b}_{i,t} + \iota_{i,t} - p_{i,t} \le 0
$$
$$
C_{i,t} = 0 \implies p_{i,t} \ge (1 - y_{i,t} - z_{i,t}) \cdot p_{i,t-1}
$$

The remaining scheduled life of the sub-loan decays by exactly one month:
$$
m_{i,t+1} = \max\left(0, \tilde{m}_{i,t} - 1\right)
$$

## Anniversary Accumulators

If $y_{i,t} = 1$ OR $(u_{i,t} \bmod 12 = 0)$ (anniversary reset):
$$
A^L_{i,t} = 0, \quad A^P_{i,t} = 0, \quad a_{i,t} = b_{i,t}
$$
Otherwise ($y_{i,t} = 0$ and not an anniversary),

$$
A^L_{i,t} = A^L_{i,t-1} + l_{i,t-1}
$$

$$
A^P_{i,t} = A^P_{i,t-1} \lor \Big((1 - y_{i,t-1}) \land \left(p_{i,t-1} > p_{i,t-2}\right)\Big)
$$

$$
a_{i,t} = a_{i,t-1}
$$

## Penalties and Fees (Soft Constraints Evaluated as Costs)

Let $r^L_{i,t}$ be the locked monthly wholesale rate at the start of the contract for sub-loan $i$.
$$
r^L_{i,t} = \frac{\xi_{i,t}}{12} > 0
$$
Let $r^M_{i,t}$ be the current market monthly wholesale rate matching the remaining fixed duration $f_{i,t}$.
$$
r^M_{i,t} = \frac{g_{f_{i,t}, t}}{12} > 0
$$

Flat Restructure / Administration Fee:

Triggered whenever a contract is formally restructured/broken ($y_{i,t} = 1$), OR a pure term adjustment occurs ($z_{i,t} = 1$), OR when an excess lump-sum fee is triggered ($\epsilon^L_{i,t} > 0$), OR when an excess payment increase fee is triggered ($\epsilon^P_{i,t} > 0$).
$$
h_{i,t} = 0 \implies y_{i,t} = 0 \\
h_{i,t} = 0 \implies z_{i,t} = 0 \\
h_{i,t} = 0 \implies \epsilon^L_{i,t} \le 0 \\
h_{i,t} = 0 \implies \epsilon^P_{i,t} \le 0
$$

The flat fee evaluated as a cost is then:
$$
\psi_{i,t} = \phi \cdot h_{i,t}
$$

To calculate the bank's true Early Repayment Recovery (ERR) in alignment with the New Zealand CCCFA "safe harbor" methodology, we evaluate the Exact Present Value (PV) loss. We define the PV Annuity Discounting Factor $D_{i,t}$ over the remaining fixed term:
$$
D_{i,t} = \mathbb{1}(f_{i,t} > 0) \left[ \frac{1 - (1 + r^M_{i,t})^{-f_{i,t}}}{r^M_{i,t}} \right]
$$

Contract Break Fee (Triggered if $y_{i,t}=1$ and $f_{i,t}>0$):

The penalized principal is the remaining balance minus any unused penalty-free allowance.
$$
\epsilon^C_{i,t} = y_{i,t} \cdot \max\left(0, r^L_{i,t} - r^M_{i,t}\right) \cdot D_{i,t} \cdot \max\Big(0, b_{i,t} - \max(0, \alpha a_{i,t} - A^L_{i,t})\Big)
$$

Excess Lump-Sum Fee (Triggered only if the contract is maintained):

The penalized principal is the marginal excess lump-sum beyond the anniversary limit.
$$
\epsilon^L_{i,t} = (1 - y_{i,t}) \cdot \max\left(0, r^L_{i,t} - r^M_{i,t}\right) \cdot D_{i,t} \cdot \max\Big(0, l_{i,t} - \max\left(0, \alpha a_{i,t} - A^L_{i,t}\right)\Big)
$$

Excess Payment Increase Fee (Triggered only if the contract is maintained):

Standard Present Value of an Annuity formula applied to the difference in payment streams.
$$
\Delta p_{i,t} = (1 - y_{i,t}) \max(0, p_{i,t} - p_{i,t-1})
$$

$$
\Delta p^{E}_{i,t} = \max\!\Big(0,\; \Delta p_{i,t} - (1 - A^P_{i,t}) \cdot \beta\Big)
$$

$$
\epsilon^P_{i,t} = (1 - y_{i,t}) \cdot \mathbb{1}(f_{i,t} > 0) \cdot \max\left(0, \Delta p^{E}_{i,t} \cdot \left[ \frac{1 - (1 + r^M_{i,t})^{-f_{i,t}}}{r^M_{i,t}} - \frac{1 - (1 + r^L_{i,t})^{-f_{i,t}}}{r^L_{i,t}} \right] \right)
$$

