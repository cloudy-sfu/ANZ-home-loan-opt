# Variables

## Sets

$t \in \mathcal{T}$: Time steps (months) over the evaluation horizon.

$i, j \in \mathcal{N}$: Sub-loan slots $\{1, 2, \dots, N\}$ (implicitly enforces the maximum loan split limit).

$k \in \mathcal{K}$: Available rate product terms in **months** (e.g., $\mathcal{K} = \{0, 6, 12, 18, 24, 36, 48, 60\}$). The value $k=0$ designates the floating rate product.

## Parameters (Given & Projected Data)

$d \in \{1, 2, \dots, 31\}$: The designated monthly repayment date. 

$s_t$: Disposable salary income at month $t$. (Pre-processed: modeled as a recursive step-function $s_t = s_{t-1} + \Delta s_t$ where $\Delta s_t$ is non-zero only during life events).

$o_t$: Expected occasional one-off windfall income at month $t$. (Modeled as the expected value $\mathbb{E}[o_t]$ derived from probabilistic forecasts).

$q_t$: Official Cash Rate (OCR) at month $t$. (Pre-processed: extracted as the latest central bank rate immediately prior to $d$).

$w_{k,t}$: The underlying wholesale base rate for product $k$ at month $t$.

-   For fixed terms $k \ge 12$: $w_{k,t}$ is the daily wholesale swap rate matching term $k$ months.
-   For the floating product ($k = 0$): The base rate is strictly the OCR, meaning $w_{0,t} = q_t$.
-   For the 6-month fixed product ($k = 6$): Modeled as a blend of the OCR and the 1-year swap rate, $w_{6,t} = \lambda q_t + (1 - \lambda) w_{12,t}$.

$\lambda \in [0, 1]$: Empirical weighting parameter used to interpolate the 0.5-year wholesale base rate, derived from historical regression of 6-month rates against the OCR and 1-year swap rates.

$\hat{\mu}_{k,t}$: Predicted bank margin applied over the wholesale base rate for product $k$ at month $t$ (an additive percentage point spread, e.g., 0.02 for 200 bps). It is forecasted using historical data $r_{k,t}$ and $w_{k,t}$.

$r_{k,t}$: Retail interest rate for product $k$ at month $t$, defined dynamically as $r_{k,t} = w_{k,t} + \hat{\mu}_{k,t}$. (Pre-processed: For historical periods, extracted directly from weekly market data; for future horizons, projected using this formula).

$\alpha$: Penalty-free lump-sum threshold (percentage of principal).

$\beta$: Penalty-free payment increase threshold (absolute monetary amount).

$\phi$: Flat restructure/administration transaction fee.

$\gamma$: Cashback incentive percentage (percentage of initial total loan amount).

$\tau$: Cashback claw back period (months).

$\theta \in \{0, 1\}$: Claw back policy toggle ($0$ for full claw back, $1$ for pro-rata claw back).

$d_t \ge 0$: Emergency cash shortfall (slack variable) injected at month $t$ to prevent model infeasibility when disposable salary ($s_t$) is heavily negative.

$a_{i,t}$: Principal balance of sub-loan $i$ locked at the start of its current anniversary year.

## State Variables (System Dynamics)

$b_{i,t}$: Outstanding principal balance of sub-loan $i$ at the start of $t$.

$c_t$: Zero-interest savings pool balance at the start of $t$.

$\rho_{i,t}$: Currently locked retail interest rate for sub-loan $i$.

$m_{i,t}$: Remaining scheduled life of sub-loan $i$ (months).

$f_{i,t}$: Remaining duration on the fixed-rate contract for $i$ ($0$ if floating).

$\omega_{i,t}$: Wholesale swap rate locked in at the start of the current fixed contract for $i$.

$u_{i,t} \in \mathbb{Z}_{\ge 0}$: The number of months elapsed since the current fixed-rate contract for sub-loan $i$ started. 

$A^L_{i,t}$: Accumulated penalty-free lump sum payments made on sub-loan $i$ during the current anniversary year.

$A^P_{i,t}$: Accumulated scheduled payment increases made on sub-loan $i$ during the current anniversary year.

## Decision Variables (Control Actions at time $t$)

$l_{i,t} \ge 0$: Lump-sum principal reduction applied to sub-loan $i$.

$p_{i,t} \ge 0$: New scheduled regular monthly payment for sub-loan $i$.

$y_{i,t} \in \{0, 1\}$: Binary variable indicating if the contract for sub-loan $i$ is broken/restructured.

$w_{i,t,k} \in \{0, 1\}$: Binary variable selecting rate product $k$ for sub-loan $i$ (if $y_{i,t} = 1$).

$v_{i,j,t} \ge 0$: Principal amount repartitioned from sub-loan $i$ to slot $j$.

## Auxiliary Cost Variables

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

## Interest Accrual

Interest is calculated monthly based on the locked retail rate.
$$
\iota_{i,t} = b_{i,t} \left( \frac{\rho_{i,t}}{12} \right)
$$

## Savings Pool Cash Flow

The pool funds all scheduled payments, lump sums, and penalties. It must not drop below zero. If income and current pool balances are insufficient to cover mandatory deductions, the slack variable $d_t$ provides the exact required shortfall to maintain feasibility.

$$
c_{t+1} = c_t + s_t + o_t + d_t + \mathbb{1}(t=0) \left( \gamma \sum_{i \in \mathcal{N}} b_{i,0} \right) - \kappa_t - \sum_{i \in \mathcal{N}} \left( p_{i,t} + l_{i,t} + \epsilon^C_{i,t} + \epsilon^L_{i,t} + \epsilon^P_{i,t} + \psi_{i,t} \right)
$$
$$
c_t \ge 0 \quad \forall t
$$

$\mathbb{1}(t=0)$ acts as a Kronecker delta, equal to 1 only in the first period and 0 otherwise..

## Sub-loan Principal Dynamics

Balances are updated by interest, payments, and any cross-slot repartitioning.
$$
b_{i,t+1} = b_{i,t} + \iota_{i,t} - p_{i,t} - l_{i,t} + \sum_{j \neq i} (v_{j,i,t} - v_{i,j,t})
$$
$$
b_{i,t} \ge 0 \quad \forall i, t
$$

Principal repartitioning (transferring balance from slot $i$ to slot $j$) is only permitted if both the source and destination sub-loans are actively in a restructure state. Where $M$ is a sufficiently large Big-M constant:
$$
v_{i,j,t} \le M \cdot y_{i,t} \quad \forall i, j, t
$$
$$
v_{i,j,t} \le M \cdot y_{j,t} \quad \forall i, j, t
$$

## Rate and Fixed Term State Transitions

The locked retail rate, wholesale rate, and remaining fixed duration evolve based on whether a contract is maintained ($y_{i,t} = 0$) or restructured ($y_{i,t} = 1$).

For months where the loan is not restructured ($y_{i,t} = 0$):
$$
\rho_{i,t+1} = \rho_{i,t}
$$

$$
\omega_{i,t+1} = \omega_{i,t}
$$

$$
f_{i,t+1} = \max(0, f_{i,t} - 1)
$$

For months where the loan is restructured ($y_{i,t} = 1$):
$$
\sum_{k \in \mathcal{K}} w_{i,t,k} = 1 \quad \forall i \text{ where } y_{i,t} = 1
$$

$$
\rho_{i,t+1} = \sum_{k \in \mathcal{K}} w_{i,t,k} r_{k,t}
$$

$$
\omega_{i,t+1} = \sum_{k \in \mathcal{K}} w_{i,t,k} w_{k,t}
$$

$$
f_{i,t+1} = \sum_{k \in \mathcal{K}} w_{i,t,k} k
$$

To enforce ANZ's "anniversary year" policies, we track the contract age $u_{i,t}$ in months.
For months where the loan is not restructured ($y_{i,t} = 0$):
$$
u_{i,t+1} = u_{i,t} + 1
$$
For months where the loan is restructured ($y_{i,t} = 1$):
$$
u_{i,t+1} = 1
$$
Unused sub-loan slots (where no principal is allocated) simply maintain $b_{i,t} = 0$, implicitly enforcing the maximum loan split parameter $N$.



## Loan Term and Amortization Dynamics

When a sub-loan contract is restructured or a new scheduled payment is established ($y_{i,t} = 1$), the new scheduled regular monthly payment $p_{i,t}$ must satisfy the standard loan amortization formula. Crucially, this must be calculated on the **effective principal balance** $\tilde{b}_{i,t}$, which accounts for any lump-sum reductions and cross-slot repartitioning executed in the current month.

Let $\tilde{b}_{i,t}$ be the effective principal balance to be amortized:
$$
\tilde{b}_{i,t} = b_{i,t} - l_{i,t} + \sum_{j \neq i} (v_{j,i,t} - v_{i,j,t}) \quad \forall i \text{ where } y_{i,t} = 1
$$

The new scheduled monthly payment is defined as:
$$
p_{i,t} = \frac{\tilde{b}_{i,t} \left( \frac{\rho_{i,t}}{12} \right)}{1 - \left( 1 + \frac{\rho_{i,t}}{12} \right)^{-m_{i,t}}} \quad \forall i \text{ where } y_{i,t} = 1
$$

For months where the loan is not restructured and no new payment schedule is set ($y_{i,t} = 0$), the scheduled monthly payment remains constant, and the remaining scheduled life decrements by 1 month.

$$
p_{i,t} = p_{i,t-1} \quad \forall i \text{ where } y_{i,t} = 0
$$
$$
m_{i,t} = m_{i,t-1} - 1 \quad \forall i \text{ where } y_{i,t} = 0
$$

Note: In an MINLP framework, the nonlinear amortization equality constraint above is usually modeled using Big-M formulations or by discretizing $m_{i,t}$ into integer years to manage the exponentiation. If $\tilde{b}_{i,t} = 0$ (an empty or fully paid-off sub-loan slot), the formula cleanly evaluates $p_{i,t} = 0$.

## Penalty Mechanics (Soft Constraints Evaluated as Costs)

Note: $\max()$, modulo operators, and indicator functions require Big-M linearization in standard MINLP.

Let $r^W(f_{i,t}, t)$ be an auxiliary function that returns the wholesale swap rate at month $t$ (extracted prior to $d$) whose term exactly matches the remaining fixed duration $f_{i,t}$. (e.g., if 18 months remain, it fetches the 1.5-year swap rate).

Anniversary Accumulators: 

According to bank policies, penalty-free thresholds reset on the anniversary of the contract start date.

If $y_{i,t} = 1$ OR $(u_{i,t} \bmod 12 = 0)$ (anniversary reset),
$$
A^L_{i,t} = 0, \quad A^P_{i,t} = 0, \quad a_{i,t} = b_{i,t}
$$
Otherwise ($y_{i,t} = 0$ and not an anniversary),
$$
A^L_{i,t} = A^L_{i,t-1} + l_{i,t-1}
$$
$$
A^P_{i,t} = A^P_{i,t-1} + \Delta p_{i,t-1}
$$
$$
a_{i,t} = a_{i,t-1}
$$

Contract break fee (triggered if $y_{i,t}=1$ and $f_{i,t}>0$):
$$
\epsilon^C_{i,t} = y_{i,t} \max\left(0, \omega_{i,t} - r^W(f_{i,t}, t)\right) \left( \frac{f_{i,t}}{12} \right) b_{i,t}
$$

Excess lump-sum fee (Triggered only if the contract is maintained, applying to the marginal excess beyond the anniversary limit):
$$
\epsilon^L_{i,t} = (1 - y_{i,t}) \max\left(0, \omega_{i,t} - r^W(f_{i,t}, t)\right) \left( \frac{f_{i,t}}{12} \right) \max\left(0, l_{i,t} - \max\left(0, \alpha a_{i,t} - A^L_{i,t}\right)\right)
$$

Excess payment increase fee (Triggered only if the contract is maintained, applying the rate differential to the principal equivalent of the excess payment delta):
$$
\Delta p_{i,t} = \max(0, p_{i,t} - p_{i,t-1})
$$
$$
\epsilon^P_{i,t} = (1 - y_{i,t}) \max\left(0, \omega_{i,t} - r^W(f_{i,t}, t)\right) \left( \frac{f_{i,t}}{12} \right) \left[ \max\left(0, \Delta p_{i,t} - \max\left(0, \beta - A^P_{i,t}\right)\right) \times f_{i,t} \right]
$$

Note: Because $p_{i,t}$ represents principal plus interest, multiplying the excess payment by the remaining fixed term $f_{i,t}$ acts as a simplified proxy for the present-value principal delta. This avoids introducing a complex, non-linear discount-rate formulation into the MINLP.

Flat restructure fee (Applies when a restructure occurs, or when the *marginal* action pushes the current anniversary accumulation over the thresholds):
$$
\psi_{i,t} = \phi \cdot \mathbb{1}\Bigg( y_{i,t} = 1 \;\lor\; \Big(l_{i,t} > \max\big(0, \alpha b_{i,t} - A^L_{i,t}\big)\Big) \;\lor\; \Big(\Delta p_{i,t} > \max\big(0, \beta - A^P_{i,t}\big)\Big) \Bigg)
$$

Cashback claw back penalty (Triggered if the total loan is fully repaid before the claw back period $\tau$ expires):

Let $B_t = \sum_{i \in \mathcal{N}} b_{i,t}$ be the total outstanding principal at month $t$. 

Let $Z_t \in \{0, 1\}$ be an indicator variable that triggers exactly when the total principal drops to zero:

$$
Z_t = \mathbb{1}(B_{t-1} > 0 \;\land\; B_t = 0)
$$

The claw back penalty applies the original cashback amount multiplied by a factor depending on the policy toggle $\theta$ ($0$ for full claw back, $1$ for pro-rata):
$$
\kappa_t = Z_t \cdot \mathbb{1}(t \le \tau) \cdot \left( \gamma \sum_{i \in \mathcal{N}} b_{i,0} \right) \cdot \left[ (1 - \theta) + \theta \left( \frac{\tau - t}{\tau} \right) \right]
$$

Note: Big-M constraints or logical indicator constraints will be needed to linearize the conditions for $Z_t$ and the time boundary $\mathbb{1}(t \le \tau)$ in standard MINLP.

# Suggested Methodology

## Rolling Horizon MINLP (Model Predictive Control)

Formulate the expressions above into a deterministic Mixed-Integer Nonlinear Program. Due to the $\max()$ operators and binary indicators ($\mathbb{1}$), reformulate these using Big-M constraints. Solve over a prediction horizon (e.g., $T=60$ months to reduce computational load, assuming a terminal state value) using a solver like SCIP. Execute only the actions for month $t$, then advance the horizon when new rate data ($r_{k,t}, w_{k,t}$) arrives.

## Markov Decision Process (MDP) / Proximal Policy Optimization (PPO)

If computation time for the MINLP becomes prohibitive under Monte Carlo rate simulations, convert the dynamics into a simulation environment. The objective formulation above becomes the negative Reward function. Train a Reinforcement Learning agent using PPO to output continuous actions ($l_{i,t}, p_{i,t}, v_{i,j,t}$) and discrete actions ($y_{i,t}, w_{i,t,k}$). Use action-masking to strictly satisfy hard bounds like $c_t \ge 0$ and $b_{i,t} \ge 0$.