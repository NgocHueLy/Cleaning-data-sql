/*
IMPORT DATA
*/
-- SET GLOBAL local_infile=1;
-- #. change column type


-- #. import data

-- LOAD DATA LOCAL INFILE 'D:/project/data cleaning/Nashville Housing Data for Data Cleaning.csv'
-- INTO TABLE housing.nashville_housing
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\r\n'
-- IGNORE 1 ROWS;

/* 
CLEANNING DATA WITH SQL QUERRIES
*/
SELECT * FROM housing.nashville_housing;

-- -----------------------------------------------------------------------------------------------

###. STANDARDIZE DATE FROMAT
select SaleDate, str_to_date(SaleDate,'%M %d, %Y') as SaleDate1
from housing.nashville_housing;

SET SQL_SAFE_UPDATES = 0;
update housing.nashville_housing
SET SaleDate = str_to_date(SaleDate,'%M %d, %Y');
SET SQL_SAFE_UPDATES = 1;

-- -----------------------------------------------------------------------------------------------

###. POPULATE PROPERTY ADDRESS

-- data with same ParcelID have the same address --> copy address to where Property Adddress is blank, base on ParcelID
select *
from housing.nashville_housing
-- where PropertyAddress = ''
order by ParcelID;


-- CREATE TEMP TABLE FOR UPDATE PROPERTY ADDRESS (using inner join takes so long)
drop table if exists temp_address;

create temporary table temp_address (
unique_id text,
new_address text);

insert into temp_address
select a.UniqueID, if(a.PropertyAddress='',b.PropertyAddress,a.PropertyAddress)
from housing.nashville_housing a
join housing.nashville_housing b
    on a.ParcelID = b.ParcelID
    and a.UniqueID <> b.UniqueID
where a.PropertyAddress = '';

select * from temp_address;

SET SQL_SAFE_UPDATES = 0;	
update housing.nashville_housing a
inner join temp_address b
	on a.UniqueID = b.unique_id
set a.new_address = if(a.PropertyAddress='',b.new_address,a.PropertyAddress);
SET SQL_SAFE_UPDATES = 1;    

-- add column new_address2
alter table housing.nashville_housing
add column new_address2 text after new_address;

-- populate column new_address2
SET SQL_SAFE_UPDATES = 0;
update housing.nashville_housing
set new_address2 = if(PropertyAddress='',new_address,PropertyAddress);
SET SQL_SAFE_UPDATES = 1; 

-- check results in new_address2
select PropertyAddress,new_address, new_address2
from housing.nashville_housing
where (PropertyAddress <> '' and new_address2 <> PropertyAddress)
or (PropertyAddress = '' and new_address2 <> new_address) ;
    
-- drop column Property Address, new_address; change new_address2 to PropertyAddress

alter table housing.nashville_housing
drop column PropertyAddress;

alter table housing.nashville_housing
drop column new_address;

alter table housing.nashville_housing
rename column new_address2 to PropertyAddress;

select PropertyAddress from housing.nashville_housing;

-- ------------------------------------------------------------------------------------------------------

###. BREAKING DOWN PROPERTY ADDRESS INTO INDIVIDUAL COLUMN (ADDRESS, CITY, STATE)

-- PROPERTY ADDRESS
select PropertyAddress, substring(PropertyAddress,1,locate(',',PropertyAddress)-1)as Address,
right(PropertyAddress,length(PropertyAddress)-locate(',',PropertyAddress)-1) as States 
from housing.nashville_housing;


alter table housing.nashville_housing
add column PropertySplitAddress char(255);

alter table housing.nashville_housing
add column PropertySplitState char(255);

SET SQL_SAFE_UPDATES = 0;
update housing.nashville_housing
set PropertySplitAddress = substring(PropertyAddress,1,locate(',',PropertyAddress)-1);

update housing.nashville_housing
set PropertySplitState = right(PropertyAddress,length(PropertyAddress)-locate(',',PropertyAddress)-1);

-- ---------------------
###. OWNER ADDRESS


select OwnerAddress, substring_index(OwnerAddress,',',1) as address, 
substring_index(OwnerAddress,', ',-1) as state,
left(substring_index(OwnerAddress,', ',-2),length(substring_index(OwnerAddress,', ',-2))-4 ) as city,
substring_index(substring_index(OwnerAddress,', ',-2),',',1) as city2
from housing.nashville_housing;


alter table housing.nashville_housing
add column OwnerSplitAddress char(255);
update housing.nashville_housing
set OwnerSplitAddress = substring_index(OwnerAddress,',',1);

alter table housing.nashville_housing
add column OwnerSplitCity char(255);
update housing.nashville_housing
set OwnerSplitCity = substring_index(substring_index(OwnerAddress,', ',-2),',',1);

alter table housing.nashville_housing
add column OwnerSplitState char(255);
update housing.nashville_housing
set OwnerSplitState = substring_index(OwnerAddress,', ',-1);

-- ----------------------------------------------------------------------------------------------------------

###. Change Y,N to Yes,No in SoldAsVacant

-- Yes/No are more populated than Y/N --> change to Yes/No
select SoldAsVacant, count(SoldAsVacant)
from housing.nashville_housing
group by SoldAsVacant
order by 2;


select SoldAsVacant,
	case when SoldAsVacant = 'N' then 'No'
	when SoldAsVacant = 'Y' then 'Yes'
	else SoldAsVacant
    end 
from housing.nashville_housing;

update housing.nashville_housing
set SoldAsVacant = case when SoldAsVacant = 'N' then 'No'
						when SoldAsVacant = 'Y' then 'Yes'
						else SoldAsVacant end;

select distinct SoldAsVacant
from housing.nashville_housing;

-- -----------------------------------------------------------------------------------------------------------

###. Remove Dupicates (on temporary table use for report, not delete from original data)


create temporary table nashville_housing_nodup like housing.nashville_housing;
alter table nashville_housing_nodup
add column row_num int;

insert into nashville_housing_nodup
select *,
	row_number() over (
    partition by ParcelID,
				PropertyAddress,
                SaleDate,
                SalePrice,
                LegalReference
                order by
                UniqueID
                ) row_num
from housing.nashville_housing;

delete
from nashville_housing_nodup
where row_num > 1;

-- ----------------------------------------------------------------------------------------------------------

SET SQL_SAFE_UPDATES = 1;



