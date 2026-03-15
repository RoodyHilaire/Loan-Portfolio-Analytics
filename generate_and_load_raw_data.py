import pandas as pd
import numpy as np
import random
from faker import Faker
from datetime import datetime, timedelta
from sqlalchemy import create_engine

fake = Faker()

# ---------------------------
# DATABASE CONNECTION
# ---------------------------

DB_USER = "postgres"
DB_PASSWORD = "xxxxxxx"
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "loan_solution_analytics"

engine = create_engine(
    f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

# ---------------------------
# PARAMETERS
# ---------------------------

N_BRANCHES = 10
N_AGENTS = 80
N_CUSTOMERS = 15000
N_LOANS = 25000

states = ["Puebla","Oaxaca","Veracruz","Chiapas","Tabasco"]
regions = ["North","Central","South"]

# ---------------------------
# BRANCHES
# ---------------------------

branches = []

for i in range(1, N_BRANCHES + 1):
    branches.append({
        "branch_id": i,
        "state": random.choice(states),
        "region": random.choice(regions)
    })

df_branch = pd.DataFrame(branches)

# ---------------------------
# AGENTS
# ---------------------------

agents = []

for i in range(1, N_AGENTS + 1):
    agents.append({
        "agent_id": i,
        "branch_id": random.randint(1, N_BRANCHES),
        "hire_date": fake.date_between(start_date='-5y', end_date='today'),
        "active_flag": random.choice([True, True, True, False])
    })

df_agent = pd.DataFrame(agents)

# ---------------------------
# CUSTOMERS
# ---------------------------

risk_segments = ["Low","Medium","High"]

customers = []

for i in range(1, N_CUSTOMERS + 1):
    customers.append({
        "customer_id": i,
        "gender": random.choice(["M","F"]),
        "age": random.randint(18,70),
        "state": random.choice(states),
        "branch_id": random.randint(1, N_BRANCHES),
        "registration_date": fake.date_between(start_date='-4y', end_date='today'),
        "risk_segment": random.choices(risk_segments,weights=[0.5,0.35,0.15])[0]
    })

df_customer = pd.DataFrame(customers)

# ---------------------------
# LOANS
# ---------------------------

loans = []

for i in range(1, N_LOANS + 1):

    loan_amount = random.randint(1500,12000)
    term_weeks = random.choice([12,16,20,24,30,40])
    interest_rate = round(random.uniform(0.20,0.45),2)

    expected_total_payment = loan_amount * (1 + interest_rate)

    disbursement_date = fake.date_between(start_date='-2y', end_date='today')

    loans.append({
        "loan_id": i,
        "customer_id": random.randint(1,N_CUSTOMERS),
        "agent_id": random.randint(1,N_AGENTS),
        "branch_id": random.randint(1,N_BRANCHES),
        "disbursement_date": disbursement_date,
        "loan_amount": loan_amount,
        "term_weeks": term_weeks,
        "interest_rate": interest_rate,
        "expected_total_payment": round(expected_total_payment,2)
    })

df_loans = pd.DataFrame(loans)

# ---------------------------
# REPAYMENTS
# ---------------------------

repayments = []
repayment_id = 1

for _, loan in df_loans.iterrows():

    weekly_payment = loan.expected_total_payment / loan.term_weeks

    for week in range(loan.term_weeks):

        payment_date = loan.disbursement_date + timedelta(days=7*week)

        if payment_date > datetime.now().date():
            continue

        amount_paid = weekly_payment

        if random.random() < 0.05:
            amount_paid = 0

        days_past_due = random.choices(
            [0,random.randint(1,7),random.randint(8,30),random.randint(31,60)],
            weights=[0.7,0.15,0.1,0.05]
        )[0]

        repayments.append({
            "repayment_id": repayment_id,
            "loan_id": loan.loan_id,
            "payment_date": payment_date,
            "amount_paid": round(amount_paid,2),
            "days_past_due": days_past_due
        })

        repayment_id += 1

df_repayments = pd.DataFrame(repayments)

# ---------------------------
# LOAD INTO POSTGRESQL
# ---------------------------

df_branch.to_sql("branches", engine, schema="raw", if_exists="append", index=False)
df_agent.to_sql("agents", engine, schema="raw", if_exists="append", index=False)
df_customer.to_sql("customers", engine, schema="raw", if_exists="append", index=False)
df_loans.to_sql("loans", engine, schema="raw", if_exists="append", index=False)
df_repayments.to_sql("repayments", engine, schema="raw", if_exists="append", index=False)

print("Raw data successfully inserted into PostgreSQL.")