CREATE TABLE raw.branches (
    branch_id INT PRIMARY KEY,
    state VARCHAR(50),
    region VARCHAR(50)
);
CREATE TABLE raw.agents (
    agent_id INT PRIMARY KEY,
    branch_id INT,
    hire_date DATE,
    active_flag BOOLEAN
);
CREATE TABLE raw.customers (
    customer_id INT PRIMARY KEY,
    gender CHAR(1),
    age INT,
    state VARCHAR(50),
    branch_id INT,
    registration_date DATE,
    risk_segment VARCHAR(20)
);
CREATE TABLE raw.loans (
    loan_id INT PRIMARY KEY,
    customer_id INT,
    agent_id INT,
    branch_id INT,
    disbursement_date DATE,
    loan_amount NUMERIC(10,2),
    term_weeks INT,
    interest_rate NUMERIC(5,2),
    expected_total_payment NUMERIC(10,2)
);
CREATE TABLE raw.repayments (
    repayment_id INT PRIMARY KEY,
    loan_id INT,
    payment_date DATE,
    amount_paid NUMERIC(10,2),
    days_past_due INT
);