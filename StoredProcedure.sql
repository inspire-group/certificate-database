DROP PROCEDURE IF EXISTS route_age;
DELIMITER //
CREATE PROCEDURE route_age
(IN hop INT, IN percentile FLOAT)
BEGIN
  

# crazy filtering command
#DELETE c.*
#FROM certificates c
#WHERE sqlId IN 
#(SELECT sqlId FROM (SELECT sqlId, processingTimestamp - certTimestamp AS processingDelay from certificates where resolvedIP IS NOT NULL) AS sub WHERE processingDelay > 864000);
  # Nice counting SQL to count the number of ASes involved. In here for reference.

  #SELECT COUNT(distinct originAS) FROM (
  #SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(resolvedAsPath, ' ', -2), ' ', 1) AS originAS From routeAges where resolvedAsPath is not null
  #) AS sub;
  # This algorithm needs to put the route not in DB case at the end and ignore the could not resolve ip cases.
  # Also routes that do not have enough hops should not be considered in the recordCount calculation.
  DECLARE recordCount INT unsigned;
  
  DECLARE percentileOffset INT unsigned;
  DECLARE counter INT unsigned DEFAULT hop + 1;
  
  # Get the total record count with the appropriate where clauses.
  # The where clause is designed to require that routes are not the -2 did not resolve IP case, 
  # they have enough hops to satisfy the required hop constraint or are the -1 route too old case.
  # The -1 case is valid to include in the false positive rate because they will never trigger the huristic even if they were in the DB.
  # When proper RIB seeding is used the inclusion of the -1 case is debateable because now every route should be in the DB. Every -1 is evidence of an experimental imperfections (similar to the -2 case) and should likely be ignored.
  # We have included it in the script to maintain the accuracy of the calculations even when RIB seeding is not used. The amount of -1 cases is small enough that it made no difference on final outcome if it is included or not.
  SET recordCount=(
  select count(*) FROM routeAges WHERE ages != '-2' 
      AND (LENGTH(ages) - LENGTH(REPLACE(ages, ' ', '')) >= hop OR ages = '-1')
   );
   
  SET percentileOffset=(FLOOR(recordCount * percentile));
  
  DROP TEMPORARY TABLE IF EXISTS singleHopAges;
  CREATE TEMPORARY TABLE singleHopAges SELECT CONVERT(hopAgeTable.hopAge, signed INT) AS age, certSqlId, recordCount FROM (
    SELECT 
    IF(ages = '-1', '-1',SUBSTRING_INDEX(SUBSTRING_INDEX(ages, ' ', -counter), ' ', 1)) 
    AS hopAge, certSqlId FROM routeAges 
    WHERE ages != '-2' 
      AND (LENGTH(ages) - LENGTH(REPLACE(ages, ' ', '')) >= hop  OR ages = '-1')
  ) AS hopAgeTable
  # There are 600 routes with the -1 case even when RIB seeding was used.
  # Whether these should be included at the front or back of the count is debateable. Arguably with RIB seeding these casees should never come up so they hilight an imperfection in our methods.
  ORDER BY age = -1, age = -3, age;
  SELECT * FROM singleHopAges LIMIT 1 OFFSET percentileOffset;
END //
DELIMITER ;