-- Databricks notebook source
-- MAGIC %md
-- MAGIC ## Reset the Catalog
-- MAGIC We reset the Catalog to show how it get's created when the share is done

-- COMMAND ----------

DROP CATALOG bdl_2023_delta_share_demo CASCADE

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Access to the Data
-- MAGIC Show that depending on what the provider does I get access to flight data from 2007 or 2008

-- COMMAND ----------

SELECT DISTINCT(year) FROM bdl_2023_delta_share_demo.bdl_sharing_airlinedata.flights

-- COMMAND ----------

SELECT DISTINCT(UniqueCarrier) FROM bdl_2023_delta_share_demo.bdl_sharing_airlinedata.flights

-- COMMAND ----------

SELECT * FROM bdl_2023_delta_share_demo.bdl_sharing_airlinedata.flights

-- COMMAND ----------


