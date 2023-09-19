-- Databricks notebook source
-- MAGIC %md
-- MAGIC
-- MAGIC # B2B Data Exchange with Delta Sharing
-- MAGIC
-- MAGIC On this notebook, we'll explore how to create a SHARE to share data with another organization.
-- MAGIC
-- MAGIC
-- MAGIC ##  Discovering the data
-- MAGIC To Illustrate let's consider us a company like **TripActions**, a Corporate Travel & Spend Management Platform. 
-- MAGIC
-- MAGIC We have already adopted a <b> Delta Lakehouse Architecture </b> for servicing all of our data internally. 
-- MAGIC
-- MAGIC A few of our largest partnered airlines, <b>American Airlines</b> & <b>Southwest</b> just let us know that they are looking to partner to add reward and recommendation programs to airline customers using TripActions data. In order to pilot this new feature, they need daily data of scheduled and results of flights taking within TripActions.
-- MAGIC
-- MAGIC We'll leverage Delta Sharing to grant data access to Americal Airlines and Southwest without data duplication and replication. 
-- MAGIC
-- MAGIC <img width="1px" src="https://www.google-analytics.com/collect?v=1&gtm=GTM-NKQ8TT7&tid=UA-163989034-1&aip=1&t=event&ec=dbdemos&ea=VIEW&dp=%2F_dbdemos%2Fgovernance%2Fdelta-sharing-airlines%2F02-provider-delta-sharing-demo&cid=7996683259228224&uid=6520804900677964">

-- COMMAND ----------

-- MAGIC %python
-- MAGIC dbutils.widgets.dropdown("reset_all_data", "false", ["true", "false"], "Reset all data")

-- COMMAND ----------

-- MAGIC %run ./_resources/00-setup $reset_all_data=$reset_all_data

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Delta Sharing
-- MAGIC
-- MAGIC Delta Sharing let you share data with external recipient without creating copy of the data. Once they're authorized, recipients can access and download your data directly.
-- MAGIC
-- MAGIC In Delta Sharing, it all starts with a Delta Lake table registered in the Delta Sharing Server by the data provider. <br/>
-- MAGIC This is done with the following steps:
-- MAGIC - Create a RECIPIENT and share activation link with your recipient 
-- MAGIC - Create a SHARE
-- MAGIC - Add your Delta tables to the given SHARE
-- MAGIC - GRANT SELECT on your SHARE to your RECIPIENT
-- MAGIC  
-- MAGIC Once this is done, your customer will be able to download the credential files and use it to access the data directly:
-- MAGIC
-- MAGIC - Client authenticates to Sharing Server
-- MAGIC - Client requests a table (including filters)
-- MAGIC - Server checks access permissions
-- MAGIC - Server generates and returns pre-signed short-lived URLs
-- MAGIC - Client uses URLs to directly read files from object storage
-- MAGIC <br>
-- MAGIC <img src="https://raw.githubusercontent.com/QuentinAmbard/databricks-demo/main/product_demos/delta-sharing-flow.png" width="1000" />
-- MAGIC
-- MAGIC ## Unity Catalog
-- MAGIC Databricks Unity Catalog is the central place to administer your data governance and security.<br/>
-- MAGIC Unity Catalog’s security model is based on standard ANSI SQL, to grant permissions at the level of databases, tables, views, rows and columns<br/>
-- MAGIC Using Databricks, we'll leverage the Unity Catalog to easily share data with our customers.

-- COMMAND ----------

-- DBTITLE 1,Unity Catalog’s security model is based on standard ANSI SQL, to grant permissions at the level of databases, tables, views, rows and columns 
-- the catalog has been created for your user and is defined as default. All shares will be created inside.
-- make sure you run the 00-setup cell above to init the catalog to your user.---
SELECT CURRENT_CATALOG();

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### Step 1: Create a Share
-- MAGIC
-- MAGIC <img src="https://raw.githubusercontent.com/QuentinAmbard/databricks-demo/main/product_demos/delta-sharing-flow-1.png" width="700" style="float:right" />
-- MAGIC
-- MAGIC We'll use the UNITY catalog to create 2 shares:
-- MAGIC - One for American Airlines data
-- MAGIC - One for Southwest Airlines data

-- COMMAND ----------

CREATE SHARE IF NOT EXISTS americanairlines 
COMMENT 'Daily Flight Data provided by Tripactions to American Airlines for Extended Rewards';

CREATE SHARE IF NOT EXISTS southwestairlines 
COMMENT 'Daily Flight Data provided by Tripactions to Southwest Airlines for Extended Rewards';

-- For the demo we'll grant ownership to all users. Typical deployments wouls have admin groups or similar.
ALTER SHARE americanairlines OWNER TO `account users`;
ALTER SHARE southwestairlines OWNER TO `account users`;

-- COMMAND ----------

-- DBTITLE 1,View a Share’s Metadata
DESCRIBE SHARE southwestairlines;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC
-- MAGIC <img src="https://github.com/QuentinAmbard/databricks-demo/raw/main/product_demos/delta-sharing-create-recipient.png" width="500" style="float:right" />
-- MAGIC
-- MAGIC **Did you know?** Delta Sharing isn't about SQL only. 
-- MAGIC
-- MAGIC You can visualize all your Delta Sharing Shares using Databricks Data Explorer UI!
-- MAGIC
-- MAGIC You can also create your share and recipient with just a few click.<br/>
-- MAGIC Select "Delta Sharing" in the Data Explorer menu, then "Create Share", "Create recipient" ...

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### Step 2: Add the tables to the SHARES
-- MAGIC
-- MAGIC <img src="https://raw.githubusercontent.com/QuentinAmbard/databricks-demo/main/product_demos/delta-sharing-flow-2.png" width="700" style="float:right" />
-- MAGIC
-- MAGIC We'll add our main table `airlinedata.lookupcodes` to the 2 SHARES:

-- COMMAND ----------

-- DBTITLE 1,Add our airlines tables to the SHARE
ALTER SHARE americanairlines  ADD TABLE bdl_sharing_airlinedata.lookupcodes ;
ALTER SHARE southwestairlines ADD TABLE bdl_sharing_airlinedata.lookupcodes;

-- COMMAND ----------

-- DBTITLE 1,Get In-House Unique Carrier Codes to Filter Specifically to Only the Relevant Airlines
SELECT * FROM bdl_sharing_airlinedata.lookupcodes WHERE Description = "Southwest Airlines Co." OR Description = "American Airlines Inc."

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Sharing a subset of a table to a SHARE
-- MAGIC We shouldn't share all the historical flights to all Airline. It might be private information and we don't want all our consumers accessing the entire `flights` table. 
-- MAGIC <br>
-- MAGIC #### Partition Specification & Renaming Tables with Alias for Customized Consumer Experience
-- MAGIC To restrict the data access, we can leverage the Delta Table Partition. Because this table is partitioned by `UniqueCarrier` and `year` we can enforce them in the share
-- MAGIC
-- MAGIC 1. Let's filter data to each specific carrier
-- MAGIC 1. And add a filter on 2008 using the LIKE operator to make sure we only access to data from 2008

-- COMMAND ----------

SELECT DISTINCT(year) FROM bdl_sharing_airlinedata.flights 

-- COMMAND ----------

-- DBTITLE 1,Add Partition Filter to Only Share a Portion of the Flights Table Using "=" & LIKE Operators AND Customized Aliases
ALTER SHARE americanairlines 
  ADD TABLE bdl_sharing_airlinedata.flights 
  PARTITION (UniqueCarrier = "AA") as bdl_sharing_airlinedata.`2008_flights`;

ALTER SHARE southwestairlines 
  ADD TABLE bdl_sharing_airlinedata.flights 
  PARTITION (UniqueCarrier = "WN", year = "2008")

-- COMMAND ----------

-- DBTITLE 1,Display all Tables Inside a Share
SHOW ALL IN SHARE southwestairlines;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### Step 3: Create a Recipient(s)
-- MAGIC
-- MAGIC <img src="https://raw.githubusercontent.com/QuentinAmbard/databricks-demo/main/product_demos/delta-sharing-flow-3.png" width="700" style="float:right" />
-- MAGIC
-- MAGIC Our next step is now to create the `RECIPIENT`.
-- MAGIC
-- MAGIC We can have multiple RECIPIENT, and assign them to multiple SHARE.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Sharing data with customers using Databricks
-- MAGIC
-- MAGIC Sharing data within Databricks is even simpler. All you need to do is get the Metastore ID from your recipient and create the share using it. <br/>
-- MAGIC You won't need any credential file doing so, Databricks Unity Catalog does all the security for you.
-- MAGIC
-- MAGIC `CREATE RECIPIENT IF NOT EXISTS southwestairlines_recipient USING ID 'aws:us-west-2:<the_reciever_recipient>' COMMENT 'Recipient for my external customer using Databricks';`
-- MAGIC
-- MAGIC For more details, open the [Sharing data within Databricks]($./04-share-data-within-databricks) demo.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC spark.sql(f"CREATE RECIPIENT IF NOT EXISTS southwestairlines_databricks USING ID '{dbutils.secrets.get('bdl_2023', 'southwestairlines_databricks_recipient')}' COMMENT 'Soutwest Airlines Databricks Recipient'")

-- COMMAND ----------

CREATE RECIPIENT IF NOT EXISTS americanairlines_open_delta COMMENT "American Airlines Open Delta Recipient";

-- For the demo we'll grant ownership to all users. Typical deployments wouls have admin groups or similar.
ALTER RECIPIENT southwestairlines_databricks OWNER TO `account users`;
ALTER RECIPIENT americanairlines_open_delta OWNER TO `account users`;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### Step 4: Share the activation link with external consumers
-- MAGIC
-- MAGIC
-- MAGIC <img src="https://raw.githubusercontent.com/QuentinAmbard/databricks-demo/main/product_demos/delta-sharing-flow-5.png" width="700" style="float:right" />
-- MAGIC
-- MAGIC Each Recipient has an activation link that the consumer can use to download it's credential.
-- MAGIC
-- MAGIC <img src="https://raw.githubusercontent.com/QuentinAmbard/databricks-demo/main/product_demos/delta-sharing-credential.png" width=400>
-- MAGIC
-- MAGIC The credentials are typically saved as a file containing. The Delta Server identify and authorize consumer based on these identifiants.<br/>
-- MAGIC Note that the activation link is single use. You can only access it once (it'll return null if already used)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### Step 5: Define which Data to Share, and Access Level 
-- MAGIC
-- MAGIC <img src="https://raw.githubusercontent.com/QuentinAmbard/databricks-demo/main/product_demos/delta-sharing-flow-4.png" width="600" style="float:right" />
-- MAGIC
-- MAGIC We now have RECIPIENT and SHARE.
-- MAGIC
-- MAGIC The next logical step is to make sure our RECIPIENT can have SELECT access to our SHARE.
-- MAGIC
-- MAGIC As usual, this is done using standard SQL:

-- COMMAND ----------



-- COMMAND ----------

GRANT SELECT ON SHARE southwestairlines TO RECIPIENT southwestairlines_databricks;
GRANT SELECT ON SHARE americanairlines TO RECIPIENT americanairlines_open_delta;

-- COMMAND ----------

-- DBTITLE 1,Step 9: Audit Who has Access to a Share
SHOW GRANT ON SHARE southwestairlines;

-- COMMAND ----------

-- DBTITLE 1,Audit Recipient Level of Access
SHOW GRANT TO RECIPIENT southwestairlines_databricks;

-- COMMAND ----------

ALTER SHARE southwestairlines 
  ALTER TABLE bdl_sharing_airlinedata.flights 
  PARTITION (UniqueCarrier = "WN", year = "2007")

-- COMMAND ----------

-- DBTITLE 1,Revoke Access if Needed
REVOKE SELECT ON SHARE southwestairlines FROM RECIPIENT southwestairlines_databricks;

-- COMMAND ----------

-- DBTITLE 1,View Shares tables
SHOW ALL IN SHARE southwestairlines;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC # Accessing the data as a Consumer
-- MAGIC
-- MAGIC In the previous notebook, we shared our data and granted read access to our RECIPIENT.
-- MAGIC
-- MAGIC Let's now see how external consumers can directly access the data.
-- MAGIC
-- MAGIC <img src="https://github.com/QuentinAmbard/databricks-demo/raw/main/delta-sharing/resources/images/delta-sharing-flow.png" width="900px"/>
-- MAGIC
-- MAGIC <img width="1px" src="https://www.google-analytics.com/collect?v=1&gtm=GTM-NKQ8TT7&tid=UA-163989034-1&aip=1&t=event&ec=dbdemos&ea=VIEW&dp=%2F_dbdemos%2Fgovernance%2Fdelta-sharing-airlines%2F03-receiver-delta-sharing-demo&cid=7996683259228224&uid=6520804900677964">

-- COMMAND ----------

-- MAGIC %md 
-- MAGIC
-- MAGIC ## Let's now see how a Receiver can access the data
-- MAGIC
-- MAGIC We saw how to create the 
-- MAGIC
-- MAGIC
-- MAGIC
-- MAGIC Next: Discover how an external [receiver can your access]($./03-receiver-delta-sharing-demo) or easily [share data within Databricks with Unity Catalog]($./04-share-data-within-databricks)
-- MAGIC
-- MAGIC [Back to Overview]($./01-Delta-Sharing-presentation)
