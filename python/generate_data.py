"""
generate_data.py
Northstar Electronics — Procurement Spend & Vendor Performance Analytics
Synthetic raw data generator (Deliverable #1)

Produces:
    data/raw/fact_purchase_orders.csv
    data/raw/dim_vendor.csv
    data/raw/dim_product.csv
    data/raw/dim_department.csv
    data/raw/dim_date.csv

Design intent (per PROJECT_SPEC / DECISIONS):
- Business behavior is simulated (department->category affinity, vendor pricing
  tendencies, single-source situations, delivery reliability variance). We do NOT
  pre-write the analytical conclusions into the generator.
- Controlled DATA-QUALITY issues (duplicates, formatting noise, missing values,
  invalid values, invalid dates) are injected separately, at low target rates,
  and are clearly distinguishable in code from BUSINESS variation (pricing
  spread, lateness, concentration) which is left alone.
- Reproducible via a fixed random seed.
"""

import os
import random
import numpy as np
import pandas as pd
from datetime import date, timedelta

# --------------------------------------------------------------------------
# Config / reproducibility
# --------------------------------------------------------------------------
SEED = 42
random.seed(SEED)
np.random.seed(SEED)

START_DATE = date(2024, 1, 1)
END_DATE = date(2025, 12, 31)

TARGET_PO_LINES = 20000
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "raw")

# ==========================================================================
# 1. dim_date
# ==========================================================================
def build_dim_date():
    days = pd.date_range(START_DATE, END_DATE, freq="D")
    df = pd.DataFrame({"Date": days})
    df["Year"] = df["Date"].dt.year
    df["Quarter"] = "Q" + df["Date"].dt.quarter.astype(str)
    df["Month"] = df["Date"].dt.month
    df["Month Name"] = df["Date"].dt.strftime("%B")
    df["Year-Month"] = df["Date"].dt.strftime("%Y-%m")
    df["Week"] = df["Date"].dt.isocalendar().week.astype(int)
    df["Day Name"] = df["Date"].dt.strftime("%A")
    df["Date"] = df["Date"].dt.strftime("%Y-%m-%d")
    return df


# ==========================================================================
# 2. dim_department
# ==========================================================================
DEPARTMENTS = [
    ("D01", "IT", "Technology"),
    ("D02", "Operations", "Operations"),
    ("D03", "Finance", "Corporate"),
    ("D04", "Human Resources", "Corporate"),
    ("D05", "Facilities", "Operations"),
    ("D06", "Sales", "Revenue"),
    ("D07", "Marketing", "Revenue"),
    ("D08", "Engineering", "Product"),
    ("D09", "Manufacturing", "Production"),
]

# Relative purchasing VOLUME weight per department (per spec: Manufacturing/IT/
# Operations/Engineering higher; Facilities/Sales/Marketing medium; Finance/HR lower)
DEPT_VOLUME_WEIGHT = {
    "D01": 1.30, "D02": 1.30, "D09": 1.45, "D08": 1.20,
    "D05": 0.90, "D06": 0.90, "D07": 0.85,
    "D03": 0.60, "D04": 0.55,
}

# Department -> Category affinity (must sum to 1 per department; drives *what*
# a department buys, kept business-plausible per spec section 11)
DEPT_CATEGORY_WEIGHTS = {
    "D01": {"IT Equipment": 0.50, "Software": 0.35, "Professional Services": 0.10, "Office Supplies": 0.05},
    "D02": {"Logistics": 0.30, "Facilities": 0.20, "Office Supplies": 0.15, "Manufacturing": 0.15,
            "IT Equipment": 0.10, "Professional Services": 0.10},
    "D03": {"Software": 0.30, "Professional Services": 0.30, "Office Supplies": 0.25, "IT Equipment": 0.15},
    "D04": {"Software": 0.35, "Professional Services": 0.35, "Office Supplies": 0.20, "IT Equipment": 0.10},
    "D05": {"Facilities": 0.60, "Office Supplies": 0.20, "Professional Services": 0.10, "Manufacturing": 0.10},
    "D06": {"Software": 0.30, "Office Supplies": 0.25, "Professional Services": 0.25, "IT Equipment": 0.20},
    "D07": {"Professional Services": 0.35, "Software": 0.25, "Office Supplies": 0.25, "IT Equipment": 0.15},
    "D08": {"IT Equipment": 0.35, "Manufacturing": 0.25, "Software": 0.20, "Professional Services": 0.20},
    "D09": {"Manufacturing": 0.55, "Logistics": 0.20, "Facilities": 0.10, "Professional Services": 0.10,
            "IT Equipment": 0.05},
}


def build_dim_department():
    return pd.DataFrame(DEPARTMENTS, columns=["Department_ID", "Department", "Group"])


# ==========================================================================
# 3. dim_product
# ==========================================================================
# category -> subcategory -> (cost_low, cost_high, unit_of_measure, qty_low, qty_high,
#                              lead_low, lead_high, n_items)
CATEGORY_SPEC = {
    "IT Equipment": {
        "Laptops": (700, 2200, "Each", 1, 50, 5, 12, 6),
        "Monitors": (120, 600, "Each", 1, 40, 4, 10, 5),
        "Docking Stations": (60, 220, "Each", 1, 60, 3, 10, 4),
        "Networking Equipment": (150, 3500, "Each", 1, 20, 7, 21, 6),
        "Peripherals": (15, 150, "Each", 1, 100, 2, 7, 5),
    },
    "Software": {
        "Productivity Licenses": (50, 400, "License", 1, 500, 1, 5, 4),
        "Security Licenses": (80, 600, "License", 1, 300, 1, 5, 4),
        "Analytics Licenses": (200, 1500, "License", 1, 100, 1, 7, 3),
        "Project-Management Licenses": (40, 250, "License", 1, 200, 1, 5, 3),
    },
    "Office Supplies": {
        "Paper": (3, 12, "Case", 10, 500, 1, 5, 3),
        "Toner": (40, 180, "Each", 1, 100, 2, 7, 4),
        "Labels": (5, 40, "Box", 5, 200, 1, 5, 3),
        "Furniture": (80, 1200, "Each", 1, 40, 7, 21, 5),
    },
    "Facilities": {
        "HVAC Maintenance": (150, 3000, "Service", 1, 10, 2, 14, 3),
        "Electrical Repair": (100, 2500, "Service", 1, 10, 2, 14, 3),
        "Janitorial Services": (200, 5000, "Service", 1, 12, 1, 7, 3),
        "Facility Supplies": (10, 150, "Each", 5, 200, 2, 10, 4),
    },
    "Manufacturing": {
        "Components": (2, 500, "Each", 10, 5000, 7, 45, 8),
        "Production Supplies": (5, 300, "Each", 10, 2000, 3, 21, 6),
        "Equipment-Related Purchases": (500, 25000, "Each", 1, 10, 14, 60, 5),
    },
    "Professional Services": {
        "Consulting": (100, 350, "Hour", 1, 160, 1, 14, 4),
        "Technical Support": (60, 250, "Hour", 1, 120, 1, 10, 4),
        "Training": (500, 8000, "Session", 1, 5, 3, 30, 3),
    },
    "Logistics": {
        "Freight": (200, 8000, "Shipment", 1, 20, 1, 14, 3),
        "Shipping": (20, 500, "Shipment", 1, 50, 1, 7, 3),
        "Warehousing": (300, 6000, "Month", 1, 12, 1, 5, 3),
    },
}

PRODUCT_NAME_TOKENS = {
    "Laptops": ["ProBook 14", "ProBook 15", "EliteBook X1", "ThinkLine T4", "AeroBook Air", "WorkStation Mobile 17"],
    "Monitors": ["UltraView 24", "UltraView 27", "ClearScreen 32 Curved", "VisionPro 24", "VisionPro 27"],
    "Docking Stations": ["DockPro USB-C", "DockLink Dual HDMI", "DockMax Universal", "DockLite Compact"],
    "Networking Equipment": ["Switch 24-Port", "Switch 48-Port", "WiFi Access Point AX", "Firewall Appliance",
                              "Router Enterprise", "Network Cable Bundle Cat6"],
    "Peripherals": ["Wireless Mouse", "Mechanical Keyboard", "Webcam HD", "USB Headset", "Docking Cable Kit"],
    "Productivity Licenses": ["Office Suite Standard", "Office Suite Pro", "Cloud Storage Plan", "Email Platform Plan"],
    "Security Licenses": ["Endpoint Protection", "VPN License", "Identity Management Suite", "Firewall Software License"],
    "Analytics Licenses": ["BI Platform License", "Data Warehouse Add-on", "Reporting Suite License"],
    "Project-Management Licenses": ["PM Tool Standard", "PM Tool Enterprise", "Collaboration Suite License"],
    "Paper": ["Copy Paper Letter", "Copy Paper Legal", "Cardstock Paper"],
    "Toner": ["Toner Cartridge Black", "Toner Cartridge Color Set", "Drum Unit Replacement", "Ink Cartridge Set"],
    "Labels": ["Shipping Label Roll", "Barcode Label Set", "Address Label Pack"],
    "Furniture": ["Office Chair Ergonomic", "Standing Desk", "Filing Cabinet", "Conference Table", "Cubicle Panel Kit"],
    "HVAC Maintenance": ["HVAC Preventive Maintenance", "HVAC Filter Replacement Service", "HVAC Emergency Repair"],
    "Electrical Repair": ["Electrical Panel Repair", "Lighting Retrofit Service", "Wiring Inspection Service"],
    "Janitorial Services": ["Nightly Cleaning Service", "Deep Cleaning Service", "Window Cleaning Service"],
    "Facility Supplies": ["Cleaning Supplies Bundle", "Restroom Supplies Bundle", "Safety Signage Kit", "Break Room Supplies"],
    "Components": ["Circuit Board Assembly", "Resistor Pack", "Capacitor Pack", "Wiring Harness", "Fastener Kit",
                    "Sensor Module", "Power Supply Unit", "Connector Set"],
    "Production Supplies": ["Adhesive Bulk Pack", "Lubricant Drum", "Protective Packaging", "Assembly Line Tooling",
                              "Safety Gloves Case", "Cleanroom Supplies"],
    "Equipment-Related Purchases": ["CNC Machine Part", "Conveyor Belt System", "Industrial Robot Arm Component",
                                      "Assembly Press Unit", "Forklift Attachment"],
    "Consulting": ["Process Improvement Consulting", "Strategy Consulting", "Systems Integration Consulting",
                    "Compliance Consulting"],
    "Technical Support": ["IT Helpdesk Support", "Network Support Retainer", "Software Support Contract",
                            "On-site Technical Support"],
    "Training": ["Leadership Training Program", "Technical Skills Training", "Compliance Training Program"],
    "Freight": ["Domestic Freight Service", "International Freight Service", "Expedited Freight Service"],
    "Shipping": ["Ground Shipping Service", "Air Shipping Service", "Bulk Shipping Service"],
    "Warehousing": ["Warehouse Storage - Standard", "Warehouse Storage - Climate Controlled",
                     "Cross-Dock Handling Service"],
}


def build_dim_product():
    rows = []
    pid = 1
    for category, subcats in CATEGORY_SPEC.items():
        for subcat, (cost_lo, cost_hi, uom, qty_lo, qty_hi, lead_lo, lead_hi, n_items) in subcats.items():
            names = PRODUCT_NAME_TOKENS[subcat]
            for i in range(n_items):
                name = names[i % len(names)]
                if i >= len(names):
                    name = f"{name} v{i // len(names) + 1}"
                cost = round(np.random.uniform(cost_lo, cost_hi), 2)
                rows.append({
                    "Product_ID": f"P{pid:04d}",
                    "Product_Name": name,
                    "Product_Category": category,
                    "Subcategory": subcat,
                    "Standard_Cost": cost,
                    "Unit_of_Measure": uom,
                    "_qty_lo": qty_lo, "_qty_hi": qty_hi,
                    "_lead_lo": lead_lo, "_lead_hi": lead_hi,
                })
                pid += 1
    return pd.DataFrame(rows)


# ==========================================================================
# 4. dim_vendor
# ==========================================================================
REGIONS = ["Northeast US", "Southeast US", "Midwest US", "West US", "Southwest US", "International"]

VENDOR_COUNT_BY_CATEGORY = {
    "IT Equipment": 8,
    "Manufacturing": 8,
    "Software": 6,
    "Office Supplies": 5,
    "Facilities": 5,
    "Professional Services": 5,
    "Logistics": 4,
}

VENDOR_NAME_STEMS = [
    "Summit", "Meridian", "Vertex", "Anchor", "Keystone", "Beacon", "Ironclad", "Northgate",
    "Redwood", "Pioneer", "Crestline", "Union", "Harborview", "Sterling", "Bright Path",
    "Cascade", "Fieldstone", "Granite", "Lighthouse", "Overland", "Pinnacle", "Silverline",
    "Trailhead", "Westbrook", "Ashford", "Brookfield", "Copperline", "Dunmore", "Elmwood",
    "Fairview", "Greenway", "Highpoint", "Ivory Peak", "Juniper", "Kingsley", "Lakeside",
    "Marbleton", "Northfield", "Oakridge", "Palisade",
]

VENDOR_SUFFIX_BY_CATEGORY = {
    "IT Equipment": ["Technologies", "Systems", "Hardware Group", "Solutions"],
    "Software": ["Software Inc.", "Digital Solutions", "Software Group", "Cloud Systems"],
    "Office Supplies": ["Supply Co.", "Office Partners", "Business Supply", "Trading Co."],
    "Facilities": ["Facilities Services", "Maintenance Group", "Building Services", "Facility Partners"],
    "Manufacturing": ["Industrial Supply", "Manufacturing Co.", "Components Inc.", "Industrial Group"],
    "Professional Services": ["Consulting Group", "Advisory Partners", "Professional Services", "& Associates"],
    "Logistics": ["Logistics Inc.", "Freight Services", "Distribution Group", "Transport Co."],
}


def build_dim_vendor():
    rows = []
    vid = 1
    stem_pool = VENDOR_NAME_STEMS.copy()
    random.shuffle(stem_pool)
    stem_idx = 0
    for category, n in VENDOR_COUNT_BY_CATEGORY.items():
        for _ in range(n):
            stem = stem_pool[stem_idx % len(stem_pool)]
            stem_idx += 1
            suffix = random.choice(VENDOR_SUFFIX_BY_CATEGORY[category])
            name = f"{stem} {suffix}"
            start = START_DATE - timedelta(days=random.randint(365, 14 * 365))
            status = "Active" if random.random() > 0.05 else "Inactive"
            pricing_mult = float(np.clip(np.random.normal(1.0, 0.12), 0.75, 1.40))
            on_time_prob = float(np.clip(np.random.beta(6, 2), 0.55, 0.97))
            erraticism = float(np.random.uniform(3, 25))  # controls how bad the late tail is
            lead_bias = int(np.random.normal(0, 2))  # vendor tends to run early/late vs product baseline
            rows.append({
                "Vendor_ID": f"V{vid:03d}",
                "Vendor_Name": name,
                "Vendor_Category": category,
                "Region": random.choice(REGIONS),
                "Vendor_Start_Date": start.strftime("%Y-%m-%d"),
                "Vendor_Status": status,
                "_pricing_mult": pricing_mult,
                "_on_time_prob": on_time_prob,
                "_erraticism": erraticism,
                "_lead_bias": lead_bias,
            })
            vid += 1
    return pd.DataFrame(rows)


def assign_product_vendor_map(products_df, vendors_df):
    """
    For each product, pick a small pool of eligible vendors from the same category,
    with a weighted 'dominant supplier' and occasional true single-source products.
    """
    mapping = {}
    for _, prod in products_df.iterrows():
        cat_vendors = vendors_df[vendors_df["Vendor_Category"] == prod["Product_Category"]]
        cat_vendors = cat_vendors[cat_vendors["Vendor_Status"] == "Active"]
        available = cat_vendors["Vendor_ID"].tolist()
        if not available:
            available = vendors_df[vendors_df["Vendor_Category"] == prod["Product_Category"]]["Vendor_ID"].tolist()

        roll = random.random()
        if roll < 0.15 and len(available) >= 1:
            # single-source product
            pool = random.sample(available, 1)
            weights = [1.0]
        elif roll < 0.55:
            k = min(len(available), random.choice([2, 3]))
            pool = random.sample(available, k)
            # one dominant vendor
            weights = [0.55] + [0.45 / (k - 1)] * (k - 1) if k > 1 else [1.0]
        else:
            k = min(len(available), random.choice([3, 4, 5]))
            pool = random.sample(available, k)
            weights = [0.40] + [0.60 / (k - 1)] * (k - 1) if k > 1 else [1.0]

        mapping[prod["Product_ID"]] = (pool, weights)
    return mapping


# ==========================================================================
# 5. fact_purchase_orders
# ==========================================================================
# Business guardrail: even though cost and quantity ranges are drawn independently
# per product, a single PO line should not exceed a category-realistic ceiling
# (e.g. a "resistor pack" line item should never total $2M just because both the
# unit-cost roll and the quantity roll landed at the high end simultaneously).
CATEGORY_MAX_LINE_VALUE = {
    "IT Equipment": 100_000,
    "Software": 150_000,
    "Office Supplies": 50_000,
    "Facilities": 75_000,
    "Manufacturing": 100_000,
    "Professional Services": 100_000,
    "Logistics": 60_000,
}


def seasonal_date_weights(dates):
    """Subtle, non-cartoonish seasonality: modest uplift in Sep/Nov/Dec, modest dip in Jul."""
    months = pd.DatetimeIndex(dates).month
    weight_by_month = {1: 1.0, 2: 1.0, 3: 1.02, 4: 1.0, 5: 1.0, 6: 0.98,
                        7: 0.90, 8: 0.95, 9: 1.08, 10: 1.05, 11: 1.12, 12: 1.10}
    return np.array([weight_by_month[m] for m in months])


def build_fact_purchase_orders(dep_df, prod_df, vend_df, product_vendor_map):
    all_days = pd.date_range(START_DATE, END_DATE, freq="D")
    day_weights = seasonal_date_weights(all_days)
    day_weights = day_weights / day_weights.sum()

    dept_ids = [d[0] for d in DEPARTMENTS]
    dept_weights = np.array([DEPT_VOLUME_WEIGHT[d] for d in dept_ids])
    dept_weights = dept_weights / dept_weights.sum()

    # estimate number of POs to reach ~TARGET_PO_LINES lines (avg ~2.2 lines/PO)
    avg_lines_per_po = 2.25
    num_pos = int(TARGET_PO_LINES / avg_lines_per_po)

    line_count_choices = [1, 2, 3, 4, 5]
    line_count_probs = [0.35, 0.30, 0.20, 0.10, 0.05]

    prod_by_category = {c: prod_df[prod_df["Product_Category"] == c] for c in CATEGORY_SPEC}

    fact_rows = []
    po_line_seq = 1
    end_of_data = pd.Timestamp(END_DATE)

    for po_num in range(1, num_pos + 1):
        po_id = f"PO{po_num:06d}"

        dept_id = np.random.choice(dept_ids, p=dept_weights)
        cat_weights = DEPT_CATEGORY_WEIGHTS[dept_id]
        category = np.random.choice(list(cat_weights.keys()), p=list(cat_weights.values()))

        order_date = np.random.choice(all_days, p=day_weights)
        order_date = pd.Timestamp(order_date)

        days_from_end = (end_of_data - order_date).days
        # recent orders skew toward "Open" since they haven't had time to resolve
        if days_from_end < 20:
            status_probs = [0.35, 0.60, 0.05]
        elif days_from_end < 45:
            status_probs = [0.75, 0.20, 0.05]
        else:
            status_probs = [0.93, 0.04, 0.03]
        po_status = np.random.choice(["Completed", "Open", "Cancelled"], p=status_probs)

        n_lines = int(np.random.choice(line_count_choices, p=line_count_probs))
        cat_products = prod_by_category[category]

        vendor_id = None
        for _ in range(n_lines):
            product = cat_products.sample(1).iloc[0]
            pool, weights = product_vendor_map[product["Product_ID"]]
            if vendor_id is None or vendor_id not in pool:
                vendor_id = np.random.choice(pool, p=weights)

            vendor = vend_df[vend_df["Vendor_ID"] == vendor_id].iloc[0]

            qty_lo, qty_hi = product["_qty_lo"], product["_qty_hi"]
            quantity = int(np.clip(np.random.lognormal(mean=np.log((qty_lo + qty_hi) / 2 + 1), sigma=0.5),
                                    qty_lo, qty_hi))

            base_cost = product["Standard_Cost"]

            # guardrail: prevent unrealistic line totals when a high unit-cost roll
            # coincides with a high quantity roll for the same product
            max_line_value = CATEGORY_MAX_LINE_VALUE.get(category, 100_000)
            if base_cost * quantity > max_line_value:
                quantity = max(qty_lo, int(max_line_value / base_cost))

            vendor_mult = vendor["_pricing_mult"]
            qty_range = max(qty_hi - qty_lo, 1)
            qty_position = (quantity - qty_lo) / qty_range
            volume_discount = 1.0 - (0.08 * qty_position if qty_position > 0.6 else 0.0)
            year_inflation = 1.03 if order_date.year == 2025 else 1.0
            noise = np.random.normal(1.0, 0.04)
            unit_price = round(base_cost * vendor_mult * volume_discount * year_inflation * max(noise, 0.7), 2)

            lead_lo, lead_hi = product["_lead_lo"], product["_lead_hi"]
            base_lead = np.random.randint(lead_lo, lead_hi + 1)
            lead_days = max(1, base_lead + vendor["_lead_bias"])
            expected_delivery = order_date + pd.Timedelta(days=int(lead_days))

            actual_delivery = pd.NaT
            if po_status == "Completed":
                if random.random() < vendor["_on_time_prob"]:
                    # early/on-time delivery, but never before the order was even placed
                    delay = -min(3, lead_days - 1) if lead_days > 1 else 0
                    delay = random.randint(delay, 0)
                else:
                    delay = int(np.random.exponential(scale=vendor["_erraticism"])) + 1
                actual_delivery = expected_delivery + pd.Timedelta(days=delay)
            elif po_status == "Open":
                # sometimes an "open" order is actually overdue (realistic ops pain point)
                pass

            fact_rows.append({
                "PO_Line_ID": f"L{po_line_seq:06d}",
                "PO_ID": po_id,
                "Vendor_ID": vendor_id,
                "Product_ID": product["Product_ID"],
                "Department_ID": dept_id,
                "Order_Date": order_date.strftime("%Y-%m-%d"),
                "Expected_Delivery_Date": expected_delivery.strftime("%Y-%m-%d"),
                "Actual_Delivery_Date": actual_delivery.strftime("%Y-%m-%d") if pd.notna(actual_delivery) else "",
                "Quantity": quantity,
                "Unit_Price": unit_price,
                "Currency": "USD",
                "PO_Status": po_status,
            })
            po_line_seq += 1

    return pd.DataFrame(fact_rows)


# ==========================================================================
# 6. Controlled data-quality issue injection
#    (kept separate & clearly labeled — these are ERRORS, not business signal)
# ==========================================================================
def inject_quality_issues(fact_df):
    df = fact_df.copy()
    n = len(df)
    rng = np.random.default_rng(SEED)

    # --- duplicates (~0.5-1%): re-insert exact copies of random existing rows ---
    n_dupes = int(n * 0.007)
    dupe_rows = df.sample(n_dupes, random_state=SEED).copy()
    df = pd.concat([df, dupe_rows], ignore_index=True)

    # --- formatting inconsistencies (~1-2%): currency casing/variants, PO_Status casing ---
    n_fmt = int(n * 0.015)
    fmt_idx = rng.choice(df.index, size=n_fmt, replace=False)
    half = n_fmt // 2
    currency_variants = ["usd", "US Dollar", "Usd", " USD"]
    status_case_map = {"Completed": ["completed", "COMPLETED", "Completed "],
                        "Open": ["open", "OPEN"],
                        "Cancelled": ["cancelled", "CANCELLED", "Canceled"]}
    for i, idx in enumerate(fmt_idx):
        if i < half:
            df.at[idx, "Currency"] = random.choice(currency_variants)
        else:
            current = df.at[idx, "PO_Status"]
            variants = status_case_map.get(current, [current])
            df.at[idx, "PO_Status"] = random.choice(variants)

    # --- missing values (~1-2%) in selected fields: Unit_Price, Quantity, Expected_Delivery_Date ---
    n_missing = int(n * 0.015)
    miss_idx = rng.choice(df.index, size=n_missing, replace=False)
    fields = ["Unit_Price", "Quantity", "Expected_Delivery_Date"]
    for idx in miss_idx:
        field = random.choice(fields)
        df.at[idx, field] = np.nan if field != "Expected_Delivery_Date" else ""

    # --- invalid values (<0.5%): negative price, zero/negative quantity ---
    n_invalid = int(n * 0.004)
    inv_idx = rng.choice(df.index, size=n_invalid, replace=False)
    for i, idx in enumerate(inv_idx):
        if i % 2 == 0:
            try:
                df.at[idx, "Unit_Price"] = -abs(float(df.at[idx, "Unit_Price"]))
            except (ValueError, TypeError):
                df.at[idx, "Unit_Price"] = -10.0
        else:
            df.at[idx, "Quantity"] = 0

    # --- small number of invalid dates: actual delivery before order date, malformed string ---
    n_bad_dates = max(5, int(n * 0.0015))
    bd_idx = rng.choice(df.index, size=n_bad_dates, replace=False)
    for i, idx in enumerate(bd_idx):
        if i % 2 == 0 and df.at[idx, "Actual_Delivery_Date"]:
            try:
                od = pd.Timestamp(df.at[idx, "Order_Date"])
                df.at[idx, "Actual_Delivery_Date"] = (od - pd.Timedelta(days=random.randint(1, 10))).strftime("%Y-%m-%d")
            except Exception:
                pass
        else:
            df.at[idx, "Order_Date"] = "2024-13-45"  # malformed

    # shuffle rows so injected issues aren't clustered at the tail
    df = df.sample(frac=1.0, random_state=SEED).reset_index(drop=True)
    return df


# ==========================================================================
# Main
# ==========================================================================
def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("Building dim_date...")
    dim_date = build_dim_date()

    print("Building dim_department...")
    dim_department = build_dim_department()

    print("Building dim_product...")
    dim_product_full = build_dim_product()

    print("Building dim_vendor...")
    dim_vendor_full = build_dim_vendor()

    print("Mapping products to eligible vendors...")
    product_vendor_map = assign_product_vendor_map(dim_product_full, dim_vendor_full)

    print("Generating fact_purchase_orders (this simulates real business behavior)...")
    fact = build_fact_purchase_orders(dim_department, dim_product_full, dim_vendor_full, product_vendor_map)
    print(f"  Generated {len(fact)} PO lines before quality-issue injection.")

    print("Injecting controlled data-quality issues...")
    fact = inject_quality_issues(fact)
    print(f"  Final row count: {len(fact)}")

    # strip internal helper columns before writing
    dim_product = dim_product_full.drop(columns=[c for c in dim_product_full.columns if c.startswith("_")])
    dim_vendor = dim_vendor_full.drop(columns=[c for c in dim_vendor_full.columns if c.startswith("_")])

    dim_date.to_csv(os.path.join(OUTPUT_DIR, "dim_date.csv"), index=False)
    dim_department.to_csv(os.path.join(OUTPUT_DIR, "dim_department.csv"), index=False)
    dim_product.to_csv(os.path.join(OUTPUT_DIR, "dim_product.csv"), index=False)
    dim_vendor.to_csv(os.path.join(OUTPUT_DIR, "dim_vendor.csv"), index=False)
    fact.to_csv(os.path.join(OUTPUT_DIR, "fact_purchase_orders.csv"), index=False)

    print("\nDone. Files written to:", os.path.abspath(OUTPUT_DIR))


if __name__ == "__main__":
    main()
