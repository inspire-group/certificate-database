#SQL CREATE TABLE COMMAND

CREATE USER IF NOT EXISTS 'routeages'@'localhost' IDENTIFIED BY 'routeages';
GRANT ALL PRIVILEGES ON *.* TO 'routeages'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;

CREATE DATABASE IF NOT EXISTS routeagescalc;
USE routeagescalc;


CREATE TABLE IF NOT EXISTS certificates
(
sqlId int NOT NULL AUTO_INCREMENT,
webCertId int NOT NULL UNIQUE,
shaOne varchar(255),
commonName varchar(1000),
certTimestamp int,
processingTimestamp int,
resolvedIP varchar(255),
issuerOrganizationName varchar(255),
source varchar(255),
PRIMARY KEY (sqlId)
);

#Alter table commands to make certificates table consistant.
#ALTER TABLE certificates ADD source varchar(255);
#ALTER TABLE certificates ADD COLUMN shaOne varchar(255);


CREATE TABLE IF NOT EXISTS routeAges
(
sqlId int NOT NULL AUTO_INCREMENT,
certSqlId int NOT NULL UNIQUE,
ages varchar(1000),
processingTime int,
resolvedPrefix varchar(255),
resolvedAsPath varchar(1000),
PRIMARY KEY (sqlId),
FOREIGN KEY certConstraint(certSqlId)
   REFERENCES certificates(sqlId)
);

CREATE TABLE IF NOT EXISTS bgpPrefixUpdates
(
prefix varchar(255) NOT NULL PRIMARY KEY,
asPath varchar(1000),
timeList varchar(1000),
updateTime int,
previousASPath varchar(1000),
addedTime int
);

# ALTER TABLE bgpPrefixUpdates ADD previousASPath varchar(1000);
# ALTER TABLE bgpPrefixUpdates ADD addedTime int;

CREATE TABLE IF NOT EXISTS metadata
(
name varchar(255) NOT NULL PRIMARY KEY,
intVal int,
stringVal varchar(255)
);


CREATE TABLE IF NOT EXISTS as_resiliance
(
ASN varchar(255) NOT NULL PRIMARY KEY,
resiliance FLOAT
);

DROP PROCEDURE IF EXISTS route_age;
DELIMITER //
CREATE PROCEDURE route_age
(IN hop INT, IN percentile FLOAT)
BEGIN
  # This algorithm needs to put the route not in DB case at the end and ignore the could not resolve ip cases.
  # Also routes that do not have enough hops should not be considered in the recordCount calculation.
  DECLARE recordCount INT unsigned;
  
  
  DECLARE percentileOffset INT unsigned;
  DECLARE counter INT unsigned DEFAULT hop + 1;
  
  # Get the total record count with the appropriate where clauses.
  # The where clause is designed to require that routes are not the -2 did not resolve IP case, 
  # they have enough hops to satisfy the required hop constraint or are the -1 route too old case.
  # The -1 case is valid to include in the false positive rate because they will never trigger the huristic even if they were in the DB.
  SET recordCount=(
  select count(*) FROM routeAges WHERE ages != '-2' 
      AND (LENGTH(ages) - LENGTH(REPLACE(ages, ' ', '')) >= hop OR ages = '-1')
   );
   
  SET percentileOffset=(FLOOR(recordCount * percentile));
  
  SELECT CONVERT(hopAgeTable.hopAge, signed INT) AS age, recordCount FROM (
    SELECT 
    IF(ages = '-1', '-1',SUBSTRING_INDEX(SUBSTRING_INDEX(ages, ' ', -counter), ' ', 1)) 
    AS hopAge FROM routeAges 
    WHERE ages != '-2' 
      AND (LENGTH(ages) - LENGTH(REPLACE(ages, ' ', '')) >= hop  OR ages = '-1')
  ) AS hopAgeTable
  # This is using string ordering on integers. Might not be the best (or might be faster).
  ORDER BY age = -1, age LIMIT 1 OFFSET percentileOffset;
END //
DELIMITER ;