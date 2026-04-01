# Variables

## Sets

$t \in \mathcal{T}$: Time steps (months) over the evaluation horizon.

$i, j \in \mathcal{N}$: Sub-loan slots $\{1, 2, \dots, N\}$ (implicitly enforces the maximum loan split limit).

$k \in \mathcal{K}$: Available rate product terms in **months** (e.g., $\mathcal{K} = \{0, 6, 12, 18, 24, 36, 48, 60\}$). The value $k=0$ designates the floating rate product.

## Parameters (Given & Projected Data)

$d \in \{1, 2, \dots, 31\}$: The designated monthly repayment date. 

$s_t$: Disposable salary income at month $t$. (Pre-processed: modeled as a recursive step-function $s_t = s_{t-1} + \Delta s_t$ where $\Delta s_t$ is non-zero only during life events).

$o_t$: Expected occasional one-off windfall income at month $t$.

$q_t$: Official Cash Rate (OCR) at month $t$. (Pre-processed: extracted as the latest central bank rate immediately prior to $d$).

$w_{k,t}$: The underlying wholesale base rate for product $k$ at month $t$.

-   For fixed terms $k \ge 12$: $w_{k,t}$ is the daily wholesale swap rate (or interpolated) matching term $k$ months.
-   For the 6-month fixed product ($k = 6$): Modeled as a blend of the OCR and the 1-year swap rate, $w_{6,t} = \lambda q_t + (1 - \lambda) w_{12,t}$.

$\lambda \in[0, 1]$: Empirical weighting parameter used to interpolate the 0.5-year wholesale base rate, derived from historical regression of 6-month rates against the OCR and 1-year swap rates.

$\hat{\mu}_{k,t}$: Predicted bank margin applied over the wholesale base rate for product $k$ at month $t$.

$r_{k,t}$: Retail interest rate for product $k$ at month $t$, defined dynamically as $r_{k,t} = w_{k,t} + \hat{\mu}_{k,t}$. 

$\alpha$: Penalty-free lump-sum threshold (percentage of principal).

$\beta$: Penalty-free payment increase threshold (absolute monetary amount).

$\phi$: Flat restructure/administration transaction fee.

$\gamma$: Cashback incentive percentage (percentage of initial total loan amount).

$\tau$: Cashback claw back period (months).

$\theta \in \{0, 1\}$: Claw back policy toggle ($0$ for full claw back, $1$ for pro-rata claw back).

$d_t \ge 0$: Emergency cash shortfall (slack variable) injected at month $t$ to prevent model infeasibility when disposable salary ($s_t$) is heavily negative.

$a_{i,t}$: Principal balance of sub-loan $i$ locked at the start of its current anniversary year.

## State Variables (System Dynamics)

$b_{i,t} \ge 0$: Outstanding principal balance of sub-loan $i$ at the start of $t$.

$c_t \ge 0$: Zero-interest savings pool balance at the start of $t$.

$\rho_{i,t}$: Locked retail interest rate for sub-loan $i$ at the start of $t$.

$m_{i,t}$: Scheduled remaining life of sub-loan $i$ (months) at the start of $t$.

$f_{i,t}$: Remaining duration on the fixed-rate contract for $i$ at the start of $t$ ($0$ if floating).

$\omega_{i,t}$: Wholesale swap rate locked in at the start of the current fixed contract for $i$.

$u_{i,t} \in \mathbb{Z}_{\ge 0}$: The number of months elapsed since the current fixed-rate contract for sub-loan $i$ started. 

$A^L_{i,t}$: Accumulated penalty-free lump sum payments made on sub-loan $i$ during the current anniversary year.

$A^P_{i,t}$: Accumulated scheduled payment increases made on sub-loan $i$ during the current anniversary year.

## Decision Variables (Control Actions at time $t$)

$l_{i,t} \ge 0$: Lump-sum principal reduction applied to sub-loan $i$.

$p_{i,t} \ge 0$: New scheduled regular monthly payment for sub-loan $i$.

$y_{i,t} \in \{0, 1\}$: Binary variable indicating if the contract for sub-loan $i$ is broken/restructured.

$w_{i,t,k} \in \{0, 1\}$: Binary variable selecting rate product $k$ for sub-loan $i$.

$v_{i,j,t} \ge 0$: Principal amount repartitioned from sub-loan $i$ to slot $j$.

$n_{i,t} \in \mathbb{Z}_{\ge 0}$: The new scheduled loan term (remaining life in months) chosen for sub-loan $i$ at month $t$ (applied if $y_{i,t} = 1$).

## Auxiliary Variables

$\iota_{i,t}$: Scheduled interest accrued.

$\epsilon^C_{i,t}$: Early repayment penalty from breaking a contract.

$\epsilon^L_{i,t}$: Early repayment penalty from excess lump-sum payments.

$\epsilon^P_{i,t}$: Early repayment penalty from excess payment increases.

$\psi_{i,t}$: Flat restructure fees triggered.

$\kappa_t$: Cashback claw back penalty.

# Objective Function

The objective is to minimize total financial friction (interest plus all penalties, fees, and severe penalties for cash shortfalls) over the loan lifetime. Let $\Omega$ be a sufficiently large penalty weight for forced debt:

$$
\min \sum_{t \in \mathcal{T}} \left( \Omega \cdot d_t + \kappa_t + \sum_{i \in \mathcal{N}} \left[ \iota_{i,t} + \epsilon^C_{i,t} + \epsilon^L_{i,t} + \epsilon^P_{i,t} + \psi_{i,t} \right] \right)
$$

# Constraints and Dynamics

## Savings Pool Cash Flow

The pool funds all scheduled payments, lump sums, and penalties. It must not drop below zero. If income and current pool balances are insufficient to cover mandatory deductions, the slack variable $d_t$ provides the exact required shortfall to maintain feasibility.

$$
c_{t+1} = c_t + s_t + o_t + d_t + \mathbb{1}(t=0) \left( \gamma \sum_{i \in \mathcal{N}} b_{i,0} \right) - \kappa_t - \sum_{i \in \mathcal{N}} \left( p_{i,t} + l_{i,t} + \epsilon^C_{i,t} + \epsilon^L_{i,t} + \epsilon^P_{i,t} + \psi_{i,t} \right)
$$
$$
c_t \ge 0 \quad \forall t
$$

## Sub-loan Principal and Interest Dynamics

Repartitioning out of slot $i$ is strictly bounded by its balance after lump-sum reductions to prevent drawing from an empty slot. Furthermore, any transfer of principal into or out of a sub-loan slot fundamentally alters the contract, strictly forcing a restructure on both the sending and receiving slots:
$$
\sum_{j \neq i} v_{i,j,t} \le b_{i,t} - l_{i,t} \quad \forall i, t
$$
$$
\sum_{j \neq i} v_{i,j,t} + \sum_{j \neq i} v_{j,i,t} \le M \cdot y_{i,t} \quad \forall i, t
$$

Interest is calculated monthly based strictly on the principal after immediate reductions and transfers, and the retail rate that takes effect for month $t$ (represented by state variable $\rho_{i,t+1}$):
$$
\iota_{i,t} = \left[ b_{i,t} - l_{i,t} + \sum_{j \neq i} (v_{j,i,t} - v_{i,j,t}) \right] \left( \frac{\rho_{i,t+1}}{12} \right)
$$

The outstanding balance transitions to the start of the next month. The scheduled payment is strictly bounded to prevent unbounded overpayment (which would artificially mine the savings pool):
$$
b_{i,t+1} = \left[ b_{i,t} - l_{i,t} + \sum_{j \neq i} (v_{j,i,t} - v_{i,j,t}) \right] + \iota_{i,t} - p_{i,t}
$$
$$
b_{i,t+1} \ge 0 \quad \forall i, t
$$
$$
p_{i,t} \le \left[ b_{i,t} - l_{i,t} + \sum_{j \neq i} (v_{j,i,t} - v_{i,j,t}) \right] + \iota_{i,t} \quad \forall i, t
$$

## Rate and Fixed Term State Transitions

When a restructure occurs ($y_{i,t} = 1$), the model must select exactly one rate product $k$:
$$
\sum_{k \in \mathcal{K}} w_{i,t,k} = y_{i,t} \quad \forall i, t
$$

The new locked parameters for month $t$ immediately establish the states at $t+1$. Crucially, if the current fixed duration has expired ($f_{i,t} = 0$) and no restructure occurs, the retail rate automatically dynamically floats with the market rate $r_{0,t}$:

$$
\rho_{i,t+1} = y_{i,t} \sum_{k \in \mathcal{K}} w_{i,t,k} r_{k,t} + (1 - y_{i,t}) \left[ \mathbb{1}(f_{i,t} > 0)\rho_{i,t} + \mathbb{1}(f_{i,t} = 0)r_{0,t} \right]
$$
$$
\omega_{i,t+1} = (1 - y_{i,t})\omega_{i,t} + y_{i,t} \sum_{k \in \mathcal{K}} w_{i,t,k} w_{k,t}
$$
$$
f_{i,t+1} = \max\left(0, (1 - y_{i,t})f_{i,t} + y_{i,t} \sum_{k \in \mathcal{K}} w_{i,t,k} \cdot k - 1\right)
$$
$$
u_{i,t+1} = (1 - y_{i,t})(u_{i,t} + 1) + y_{i,t}(1)
$$

## Loan Term and Amortization Dynamics

To determine the minimum scheduled amortization payment $p^M_{i,t}$, we first define the **effective post-action principal** $\tilde{b}_{i,t}$ and the **effective scheduled term** $\tilde{m}_{i,t}$ active for month $t$:

$$
\tilde{b}_{i,t} = b_{i,t} - l_{i,t} + \sum_{j \neq i} (v_{j,i,t} - v_{i,j,t})
$$
$$
\tilde{m}_{i,t} = (1 - y_{i,t})m_{i,t} + y_{i,t} n_{i,t}
$$

Let $\tilde{r}_{i,t} = \frac{\rho_{i,t+1}}{12}$ represent the effective monthly retail interest rate. Assuming retail rates remain strictly positive due to bank margins ($\tilde{r}_{i,t} > 0$), the minimum mandatory payment strictly follows the standard amortizing annuity formula:

$$
p^M_{i,t} = \begin{cases} 
\tilde{b}_{i,t} \cdot \left[ \frac{\tilde{r}_{i,t}}{1 - \left( 1 + \tilde{r}_{i,t} \right)^{-\tilde{m}_{i,t}}} \right] & \text{if } \tilde{m}_{i,t} > 0 \\ 
\tilde{b}_{i,t} & \text{if } \tilde{m}_{i,t} = 0
\end{cases} \quad \forall i
$$

The borrower's chosen payment must meet or exceed this scheduled minimum. Additionally, the scheduled payment cannot be decreased from the previous month's value unless the contract is formally restructured, except when the sub-loan is naturally fully paid off:
$$
p_{i,t} \ge p^M_{i,t} \quad \forall i, t
$$
$$
p_{i,t} \ge (1 - y_{i,t}) \cdot p_{i,t-1} \cdot \mathbb{1}(\tilde{b}_{i,t} > 0) \quad \forall i, t
$$

The remaining scheduled life of the sub-loan decays by exactly one month:
$$
m_{i,t+1} = \max\left(0, \tilde{m}_{i,t} - 1\right)
$$

## Anniversary Accumulators

If $y_{i,t} = 1$ OR $(u_{i,t} \bmod 12 = 0)$ (anniversary reset),

$$
A^L_{i,t} = 0, \quad A^P_{i,t} = 0, \quad a_{i,t} = b_{i,t}
$$

Otherwise ($y_{i,t} = 0$ and not an anniversary),

$$
A^L_{i,t} = A^L_{i,t-1} + l_{i,t-1}
$$
$$
A^P_{i,t} = A^P_{i,t-1} + (1 - y_{i,t-1}) \max(0, p_{i,t-1} - p_{i,t-2})
$$
$$
a_{i,t} = a_{i,t-1}
$$

## Penalties and Fees (Soft Constraints Evaluated as Costs)

Let the locked monthly wholesale rate be $r^{\omega}_{i,t} = \frac{\omega_{i,t}}{12}$, and the current market monthly wholesale rate be $r^{W}_{i,t} = \frac{r^W(f_{i,t}, t)}{12}$.

To calculate the bank's true Early Repayment Recovery (ERR) in alignment with the New Zealand CCCFA "safe harbor" methodology, we evaluate the Exact Present Value (PV) loss. We define the PV Annuity Discounting Factor $D_{i,t}$ over the remaining fixed term:

$$
D_{i,t} = \mathbb{1}(f_{i,t} > 0) \left[ \frac{1 - (1 + r^{W}_{i,t})^{-f_{i,t}}}{r^{W}_{i,t}} \right]
$$
Note: In MINLP solver, handle the limit case where $r^{W}_{i,t} = 0$ by setting $D_{i,t} = f_{i,t}$ to prevent zero-division errors.

Contract Break Fee (Triggered if $y_{i,t}=1$ and $f_{i,t}>0$):

The penalized principal is the remaining balance minus any unused penalty-free allowance.
$$
\epsilon^C_{i,t} = y_{i,t} \cdot \max\left(0, r^{\omega}_{i,t} - r^{W}_{i,t}\right) \cdot D_{i,t} \cdot \max\Big(0, b_{i,t} - \max(0, \alpha a_{i,t} - A^L_{i,t})\Big)
$$

Excess Lump-Sum Fee (Triggered only if the contract is maintained):

The penalized principal is the marginal excess lump-sum beyond the anniversary limit.
$$
\epsilon^L_{i,t} = (1 - y_{i,t}) \cdot \max\left(0, r^{\omega}_{i,t} - r^{W}_{i,t}\right) \cdot D_{i,t} \cdot \max\left(0, l_{i,t} - \max\left(0, \alpha a_{i,t} - A^L_{i,t}\right)\right)
$$

Standard Present Value of an Annuity formula applied to the difference in payment streams).

Excess Payment Increase Fee (Triggered only if the contract is maintained): 
$$
\Delta p_{i,t} = (1 - y_{i,t}) \max(0, p_{i,t} - p_{i,t-1})
$$
$$
\Delta p^{E}_{i,t} = \max\left(0, \Delta p_{i,t} - \max\left(0, \beta - A^P_{i,t}\right)\right)
$$
$$
\epsilon^P_{i,t} = (1 - y_{i,t}) \cdot \mathbb{1}(f_{i,t} > 0) \cdot \max\left(0, \Delta p^{E}_{i,t} \cdot \left[ \frac{1 - (1 + r^{W}_{i,t})^{-f_{i,t}}}{r^{W}_{i,t}} - \frac{1 - (1 + r^{\omega}_{i,t})^{-f_{i,t}}}{r^{\omega}_{i,t}} \right] \right)
$$

Flat Restructure Fee:
$$
\psi_{i,t} = \phi \cdot \mathbb{1}\Bigg( y_{i,t} = 1 \;\lor\; \Big(l_{i,t} > \max\big(0, \alpha a_{i,t} - A^L_{i,t}\big)\Big) \;\lor\; \Big(f_{i,t} > 0 \land \Delta p_{i,t} > \max\big(0, \beta - A^P_{i,t}\big)\Big) \Bigg)
$$

# Suggested Methodology

## Rolling Horizon MINLP (Model Predictive Control)
Formulate the expressions above into a deterministic Mixed-Integer Nonlinear Program. Due to the $\max()$ operators and binary indicators ($\mathbb{1}$), reformulate these using Big-M constraints. Solve over a prediction horizon (e.g., $T=60$ months to reduce computational load, assuming a terminal state value) using a solver like SCIP. Execute only the actions for month $t$, then advance the horizon when new rate data ($r_{k,t}, w_{k,t}$) arrives.

## Markov Decision Process (MDP) / Proximal Policy Optimization (PPO)
If computation time for the MINLP becomes prohibitive under Monte Carlo rate simulations, convert the dynamics into a simulation environment. The objective formulation above becomes the negative Reward function. Train a Reinforcement Learning agent using PPO to output continuous actions ($l_{i,t}, p_{i,t}, v_{i,j,t}$) and discrete actions ($y_{i,t}, w_{i,t,k}$). Use action-masking to strictly satisfy hard bounds like $c_t \ge 0$ and limits on principal payouts.