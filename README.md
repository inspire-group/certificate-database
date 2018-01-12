# certificate-database
This is a MySQL dump backup of a database of 1.8 million certificates and corresponding BGP data from when those certificates were issued.

database.sql.description.txt contains a description of the dataset.

SQL CREATE TABLE COMMAND.sql contains SQL commands to create the dataset schema. The dataset its self has create tables commands so this is not needed if restoring the existing dataset. It is simply used to create a new database.

StoredProcedure.sql contains a SQL stored procedure that computes false positive rates based on the data in the routeAge table.

temp resilience table commands.sql contains commands used to process the certificate database and extract useful statistics like the average resilience of domains in the database.
