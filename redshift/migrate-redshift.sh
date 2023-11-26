#!/usr/bin/bash

# Configuration variables
S3_BUCKET_PATH="s3://cs511-dataset/"
REDSHIFT_ENDPOINT="default-workgroup.051749418489.us-east-1.redshift-serverless.amazonaws.com"
REDSHIFT_PORT="5439"
REDSHIFT_USER="admin"
REDSHIFT_DB="dev"
REDSHIFT_ROLE_ARN="arn:aws:iam::051749418489:role/service-role/AmazonRedshift-CommandsAccessRole-20231118T162917"
REDSHIFT_TABLE_SCHEMA="CREATE TABLE Food_1 (
    \"Number of Records\" SMALLINT NOT NULL,
    \"activity_sec\" INT NOT NULL,
    \"application\" VARCHAR(28),
    \"device\" VARCHAR(40) NOT NULL,
    \"subscribers\" SMALLINT NOT NULL,
    \"volume_total_bytes\" DOUBLE PRECISION NOT NULL
);"

PGPASSWORD='CS511admin'  # Consider a more secure way to handle passwords

# Start timer
START_TIME=$(date +%s%3N)

# Export data from MySQL to Google Bucket
gcloud sql export csv mysql-instance gs://dropdb_sample1/redshift/output --database=FOOD --query="SELECT * FROM Food_1;"

# Upload CSV to S3
gsutil -m rsync -rd gs://dropdb_sample1/redshift/ s3://cs511-dataset

# Create Redshift table and import data from S3
export PGPASSWORD
psql -h $REDSHIFT_ENDPOINT -p $REDSHIFT_PORT -U $REDSHIFT_USER -d $REDSHIFT_DB -c "$REDSHIFT_TABLE_SCHEMA"
psql -h $REDSHIFT_ENDPOINT -p $REDSHIFT_PORT -U $REDSHIFT_USER -d $REDSHIFT_DB -c "COPY Food_1 FROM '$S3_BUCKET_PATH' IAM_ROLE '$REDSHIFT_ROLE_ARN' CSV"

# End timer and calculate duration
END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))
echo "Time taken: $DURATION milliseconds"

# Clean up
psql -h $REDSHIFT_ENDPOINT -p $REDSHIFT_PORT -U $REDSHIFT_USER -d $REDSHIFT_DB -c "DROP TABLE Food_1;"
aws s3 rm $S3_BUCKET_PATH --recursive
unset PGPASSWORD
