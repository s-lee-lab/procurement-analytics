# PROJECT_SPEC — Procurement Spend & Vendor Performance Analytics

## Career objective
Portfolio project supporting a transition from operations/general-affairs
background into Data Analyst / BI Analyst / Business Analyst / Operations-
Procurement Analyst roles. Demonstrates: business understanding → messy data →
data preparation → SQL analysis → BI modeling → decision support →
recommendations. Technically competent, but primarily business-relevant,
explainable, and defensible in an interview.

## Company (fictional)
**Northstar Electronics** — fictional U.S. electronics/technology company,
~1,000 employees, multiple U.S. offices, manufacturing/assembly operations
plus corporate functions (IT, Facilities, Procurement, Finance, etc). Not
based on, and never to be implied as based on, any real company's data.

## Business problem
Procurement leadership has visibility into overall spend but lacks a
consolidated view of supplier performance, purchasing trends, pricing
variation, supplier concentration, and delivery reliability. Goal: identify
vendors/categories that warrant further investigation for cost reduction or
operational improvement — **investigation candidates, not proven verdicts.**

## Stakeholders
- **Procurement Manager** (primary) — vendor performance, cost, concentration, negotiation.
- **Finance Manager** — total spend, trends, concentration, cost control.
- **Operations Manager** — delivery reliability, late deliveries, supplier issues.
- **Procurement Analyst** — vendor comparisons, pricing, purchasing patterns.

## Core business questions
1. How much are we spending, and how has it changed over time?
2. Which departments and categories drive spending?
3. Which vendors account for the most spend, and how concentrated is it?
4. Which vendors have the strongest/weakest delivery performance?
5. Which products show meaningful price variation, and is it linked to vendor or volume?
6. Where are delivery delays concentrated?
7. Which vendors/categories warrant further procurement investigation?

## Technology
Core: Excel/Power Query → SQL → Power BI. Supporting: Python (for realistic
synthetic data generation only — not the centerpiece of the portfolio story).

## Fact table grain
`fact_purchase_orders` is grain = **one row per purchase-order line item**.
A single PO (`PO_ID`) may span multiple rows. All KPIs below are defined
explicitly against this grain to avoid ambiguity — e.g. a PO can have some
lines delivered on time and others late, so "PO delivered on time" is not
a well-defined statement without specifying line-level vs. PO-level scope.

## KPI definitions (see DATA_DICTIONARY.md for calculated-field detail)
- **Total Procurement Spend** = Σ(Quantity × Unit_Price), Completed PO lines only.
- **PO Count** = COUNT(DISTINCT PO_ID) among Completed POs. Counts unique
  purchase orders, not line items — distinct from any line-level KPI below.
- **Active Vendors** = distinct vendors with Completed purchasing activity.
- **Average PO Value** = Total completed spend ÷ completed PO count.
- **On-Time Delivery %** = (number of Completed PO **lines** delivered on or
  before Expected_Delivery_Date) ÷ (number of Completed PO **lines** with
  valid Expected and Actual delivery dates). Calculated at PO-line grain,
  matching the fact table — not at the PO level.
- **Average Days Late** = average delay (Actual − Expected) among late
  Completed PO **lines** only, restricted to lines with valid dates.
- **Vendor Spend Share** = vendor completed spend ÷ total completed spend.
- **Price Variance** = observed unit price vs. a product-level benchmark
  (median-based benchmark preferred; final choice made after inspecting data).

## Inclusion rules
- Spend KPIs: **Completed** PO lines only.
- Delivery KPIs: **Completed** PO lines with valid Expected and Actual dates,
  evaluated at line grain (see On-Time Delivery % and Average Days Late above).
- Open/Cancelled orders excluded from spend & delivery KPIs but retained for
  separate operational analysis.

## Data philosophy
- **Data-quality errors** (negative price, invalid date, duplicate row, missing
  key, inconsistent casing) → candidates for cleaning.
- **Business anomalies** (a vendor pricing consistently higher, unusually late
  deliveries, large purchases, price variance) → NOT automatically cleaned;
  may be the actual finding.
- No predetermined findings — the generator creates realistic conditions; the
  analysis discovers and validates patterns, not the reverse.

## Limitations (to state explicitly in the final writeup)
Synthetic data has limits. A price difference doesn't automatically mean
overpayment — it could reflect contract terms, volume discounts, product
specs, service levels, shipping, negotiated pricing, or timing. Pricing
anomalies are investigation candidates, not confirmed savings.