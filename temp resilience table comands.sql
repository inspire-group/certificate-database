CREATE TEMPORARY TABLE IF NOT EXISTS originASTable AS (SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(resolvedAsPath, ' ', -2), ' ', 1) AS originAS From routeAges where resolvedAsPath is not null);

CREATE TEMPORARY TABLE IF NOT EXISTS weightedResiliance AS (select ASN, resiliance from as_resiliance RIGHT JOIN originASTable ON ASN = originAS);

CREATE TEMPORARY TABLE IF NOT EXISTS groupedResilience AS (select ASN, avg(resiliance) as resiliance, count(ASN) as numberOfDomains from weightedResiliance group by ASN);





# Distinct origin table:
CREATE TEMPORARY TABLE IF NOT EXISTS distinctOrigin AS (SELECT DISTINCT originAS FROM originASTable);



# Output AS weights to CSV:
select ASN, count(ASN) from weightedResiliance group by ASN order by count(ASN) desc
INTO OUTFILE '/tmp/AS-weights.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';


# Partial code:
set @csum := 0;
select resiliance, numberOfDomains, ASN, 
       (@csum := @csum + numberOfDomains) as cumulative_sum 
       from groupedResilience
       order by resiliance
INTO OUTFILE '/tmp/cdf.txt';

# Full Histogram code:
set @csum := 0;
SELECT count(*) FROM weightedResiliance INTO @total;
select resiliance,
       (@csum := @csum + numberOfDomains) / @total as cumulative_sum
       from groupedResilience
       order by resiliance
INTO OUTFILE '/tmp/cdf.txt'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';



select ASN, count(ASN), AVG(resiliance) from weightedResiliance group by ASN ORDER BY count(ASN)
INTO OUTFILE '/tmp/resilianceout.csv'
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n';