#!/usr/bin/bash

# Configuration variables
S3_BUCKET_PATH="s3://cs511-dataset/"
REDSHIFT_ENDPOINT="default-workgroup.051749418489.us-east-1.redshift-serverless.amazonaws.com"
REDSHIFT_PORT="5439"
REDSHIFT_USER="admin"
REDSHIFT_DB="dev"
REDSHIFT_ROLE_ARN="arn:aws:iam::051749418489:role/service-role/AmazonRedshift-CommandsAccessRole-20231118T162917"
REDSHIFT_TABLE_SCHEMA="CREATE TABLE IF NOT EXISTS \"nation\" (
  \"n_nationkey\"  INT,
  \"n_name\"       CHAR(25),
  \"n_regionkey\"  INT,
  \"n_comment\"    VARCHAR(152),
  \"n_dummy\"      VARCHAR(10),
  PRIMARY KEY (\"n_nationkey\"));
CREATE TABLE IF NOT EXISTS \"region\" (
  \"r_regionkey\"  INT,
  \"r_name\"       CHAR(25),
  \"r_comment\"    VARCHAR(152),
  \"r_dummy\"      VARCHAR(10),
  PRIMARY KEY (\"r_regionkey\"));
CREATE TABLE IF NOT EXISTS \"supplier\" (
  \"s_suppkey\"     INT,
  \"s_name\"        CHAR(25),
  \"s_address\"     VARCHAR(40),
  \"s_nationkey\"   INT,
  \"s_phone\"       CHAR(15),
  \"s_acctbal\"     DECIMAL(15,2),
  \"s_comment\"     VARCHAR(101),
  \"s_dummy\"       VARCHAR(10),
  PRIMARY KEY (\"s_suppkey\"));
CREATE TABLE IF NOT EXISTS \"customer\" (
  \"c_custkey\"     INT,
  \"c_name\"        VARCHAR(25),
  \"c_address\"     VARCHAR(40),
  \"c_nationkey\"   INT,
  \"c_phone\"       CHAR(15),
  \"c_acctbal\"     DECIMAL(15,2),
  \"c_mktsegment\"  CHAR(10),
  \"c_comment\"     VARCHAR(117),
  \"c_dummy\"       VARCHAR(10),
  PRIMARY KEY (\"c_custkey\"));
CREATE TABLE IF NOT EXISTS \"part\" (
  \"p_partkey\"     INT,
  \"p_name\"        VARCHAR(55),
  \"p_mfgr\"        CHAR(25),
  \"p_brand\"       CHAR(10),
  \"p_type\"        VARCHAR(25),
  \"p_size\"        INT,
  \"p_container\"   CHAR(10),
  \"p_retailprice\" DECIMAL(15,2) ,
  \"p_comment\"     VARCHAR(23) ,
  \"p_dummy\"       VARCHAR(10),
  PRIMARY KEY (\"p_partkey\"));
CREATE TABLE IF NOT EXISTS \"partsupp\" (
  \"ps_partkey\"     INT,
  \"ps_suppkey\"     INT,
  \"ps_availqty\"    INT,
  \"ps_supplycost\"  DECIMAL(15,2),
  \"ps_comment\"     VARCHAR(199),
  \"ps_dummy\"       VARCHAR(10),
  PRIMARY KEY (\"ps_partkey\"));
CREATE TABLE IF NOT EXISTS \"orders\" (
  \"o_orderkey\"       INT,
  \"o_custkey\"        INT,
  \"o_orderstatus\"    CHAR(1),
  \"o_totalprice\"     DECIMAL(15,2),
  \"o_orderdate\"      DATE,
  \"o_orderpriority\"  CHAR(15),
  \"o_clerk\"          CHAR(15),
  \"o_shippriority\"   INT,
  \"o_comment\"        VARCHAR(79),
  \"o_dummy\"          VARCHAR(10),
  PRIMARY KEY (\"o_orderkey\"));
CREATE TABLE IF NOT EXISTS \"lineitem\"(
  \"l_orderkey\"          INT,
  \"l_partkey\"           INT,
  \"l_suppkey\"           INT,
  \"l_linenumber\"        INT,
  \"l_quantity\"          DECIMAL(15,2),
  \"l_extendedprice\"     DECIMAL(15,2),
  \"l_discount\"          DECIMAL(15,2),
  \"l_tax\"               DECIMAL(15,2),
  \"l_returnflag\"        CHAR(1),
  \"l_linestatus\"        CHAR(1),
  \"l_shipdate\"          DATE,
  \"l_commitdate\"        DATE,
  \"l_receiptdate\"       DATE,
  \"l_shipinstruct\"      CHAR(25),
  \"l_shipmode\"          CHAR(10),
  \"l_comment\"           VARCHAR(44),
  \"l_dummy\"             VARCHAR(10));"

PGPASSWORD='CS511admin'  # Consider a more secure way to handle passwords
export PGPASSWORD

psql -h $REDSHIFT_ENDPOINT -p $REDSHIFT_PORT -U $REDSHIFT_USER -d $REDSHIFT_DB -c "$REDSHIFT_TABLE_SCHEMA"

for table in "nation" "region" "supplier" "customer" "part" "partsupp" "orders" "lineitem"; do
    echo $table;
    # Start timer
    START_TIME=$(date +%s%3N)

    # Export data from MySQL to Google Bucket
    gcloud sql export csv mysql-instance gs://dropdb_sample1/redshift/output --database=tpch1g --query="SELECT * FROM $table;"

    # Upload CSV to S3
    gsutil -m rsync -rd gs://dropdb_sample1/redshift/ s3://cs511-dataset

    # Create Redshift table and import data from S3
    psql -h $REDSHIFT_ENDPOINT -p $REDSHIFT_PORT -U $REDSHIFT_USER -d $REDSHIFT_DB -c "COPY $table FROM '$S3_BUCKET_PATH' IAM_ROLE '$REDSHIFT_ROLE_ARN' CSV"

    # End timer and calculate duration
    END_TIME=$(date +%s%3N)
    DURATION=$((END_TIME - START_TIME))
    echo "Time taken for $table: $DURATION milliseconds"

    # Clean up
    psql -h $REDSHIFT_ENDPOINT -p $REDSHIFT_PORT -U $REDSHIFT_USER -d $REDSHIFT_DB -c "DROP TABLE $table;"
    aws s3 rm $S3_BUCKET_PATH --recursive
    echo "*****************************************************************"
done
unset PGPASSWORD
