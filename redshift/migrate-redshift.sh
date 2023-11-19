#!/usr/bin/bash

# Configuration variables
MYSQL_OUTPUT_PATH="/var/lib/mysql-files/output.csv"
LOCAL_CSV_PATH="/home/yw101/cs511FinalProject/redshift/output.csv"
S3_BUCKET_PATH="s3://cs511-dataset/"
REDSHIFT_ENDPOINT="default-workgroup.051749418489.us-east-1.redshift-serverless.amazonaws.com"
REDSHIFT_PORT="5439"
REDSHIFT_USER="admin"
REDSHIFT_DB="dev"
REDSHIFT_ROLE_ARN="arn:aws:iam::051749418489:role/service-role/AmazonRedshift-CommandsAccessRole-20231118T162917"
REDSHIFT_TABLE_SCHEMA="CREATE TABLE countries (
    ISO CHAR(2),
    ISO3 CHAR(3),
    ISO_Numeric INT,
    fips CHAR(2),
    Country VARCHAR(200),
    Capital VARCHAR(200),
    Area_km2 BIGINT,
    Population BIGINT,
    Continent CHAR(2),
    tld VARCHAR(10),
    CurrencyCode CHAR(3),
    CurrencyName VARCHAR(50),
    Phone CHAR(5),
    Postal_Code_Format VARCHAR(100),
    Postal_Code_Regex VARCHAR(200),
    Languages VARCHAR(200),
    geonameid INT,
    neighbours VARCHAR(100),
    EquivalentFipsCode CHAR(2)
);"
PGPASSWORD='CS511admin'  # Consider a more secure way to handle passwords

# Start timer
START_TIME=$(date +%s)

# Export data from MySQL and move to a local directory
sudo mysql -e "SELECT * INTO OUTFILE '$MYSQL_OUTPUT_PATH' FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\n' FROM countries" geonames
sudo mv $MYSQL_OUTPUT_PATH $LOCAL_CSV_PATH
sudo chmod +r $LOCAL_CSV_PATH

# Upload CSV to S3
aws s3 cp $LOCAL_CSV_PATH $S3_BUCKET_PATH

# Create Redshift table and import data from S3
export PGPASSWORD
psql -h $REDSHIFT_ENDPOINT -p $REDSHIFT_PORT -U $REDSHIFT_USER -d $REDSHIFT_DB -c "$REDSHIFT_TABLE_SCHEMA"
psql -h $REDSHIFT_ENDPOINT -p $REDSHIFT_PORT -U $REDSHIFT_USER -d $REDSHIFT_DB -c "COPY countries FROM '$S3_BUCKET_PATH' IAM_ROLE '$REDSHIFT_ROLE_ARN' CSV"

# End timer and calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "Time taken: $DURATION seconds"

# Clean up
psql -h $REDSHIFT_ENDPOINT -p $REDSHIFT_PORT -U $REDSHIFT_USER -d $REDSHIFT_DB -c "DROP TABLE countries;"
aws s3 rm $S3_BUCKET_PATH --recursive
unset PGPASSWORD
