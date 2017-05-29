--creating separate lists for each class of concepts, then for branded drugs and clinical drug original code will be used (PFC_code) and for OMOP created concepts codes will be created just using sequence 
--create list of all ingredients separating by '+' to separate rows
drop table ingr;
create table ingr as (
SELECT ingred AS concept_name, 'Ingredient' as concept_class_id from (
select distinct
trim(regexp_substr(t.molecule, '[^\+]+', 1, levels.column_value))  as ingred
from france t,
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(t.molecule, '[^\+]+'))  + 1) as sys.OdciNumberList)) levels)where ingred !='NULL')
;
--create list of all Brands 
drop table Brand;
CREATE TABLE Brand AS (
SELECT product_desc AS concept_name ,
'Brand Name' as concept_class_id
 FROM (
select distinct product_desc from france where pfc not in (
select pfc from ingr c join france on replace (PRODUCT_DESC, ' DCI', '') =  upper(c.concept_name) ) --we found out that all product descriptions containing DCI are not a Brands but a Clinical Drugs 
and PRODUCT_DESC not like '%DCI%'
and english != 'Non Human Usage Products')) -- 'Non Human Usage Products' means that's not a drug
;
--forms, LB_NFC_3 represents form and route so it's unique identifier for Drug Form
drop TABLE Forms;
CREATE TABLE Forms AS (
SELECT LB_NFC_3 AS concept_name, 'Dose Form' as concept_class_id
FROM (
select distinct LB_NFC_3 from france where "LB_NFC_3" is not null and LB_NFC_3 !='NULL'
)
)
;
-- units, take units used for volume and strength definition
drop table unit;
CREATE TABLE UNIT AS (
SELECT strg_meas AS concept_name, strg_meas  as concept_CODE, 'Unit' as concept_class_id
FROM (
select distinct strg_meas from france union select distinct regexp_replace (volume, '[[:digit:]\.]') from france ) WHERE strg_meas !='NULL'
)
;
--Branded Drug with simple names, 
drop table Branded_Drug ; 
create table Branded_Drug as (
select trim( regexp_replace (replace ((volume||' '||substr ((replace (molecule, '+', ' / ')),1, 185) --To avoid names length more than 255
||'  '||c.DOSE_FORM_NAME||' ['||PRODUCT_DESC||']'||' Box of '||a.packsize), 'NULL', ''), '\s+', ' '))
 as concept_name, pfc as concept_code, case when a.volume = 'NULL' then 'Branded Drug Box'  else  'Quant Branded Box' end as concept_class_id
from france a
join  Brand d on d.CONCEPT_NAME = a.PRODUCT_DESC
and  english != 'Non Human Usage Products'
left outer join  france_names_translation c on a.LB_NFC_3 = c.dose_form  -- france_names_translation is munually created table containing Form translation to English 
)
;
drop table Clinical_drug;
create table Clinical_drug as (
 --' / ' is a standard delimeter between two separate ingredients in RxNorm
select trim( regexp_replace (replace ((volume||' '||substr ((replace (molecule, '+', ' / ')),1, 185) --To avoid names length more than 255
||' '||c.DOSE_FORM_NAME||' Box of '||a.packsize), 'NULL', ''), '\s+', ' '))
as concept_name, pfc as concept_code, case when a.volume = 'NULL' then 'Clinical Drug Box'  else  'Quant Clinical Box' end as concept_class_id
from france a
left outer join france_names_translation c on a.LB_NFC_3 = c.dose_form -- france_names_translation is munually created table containing Form translation to English 
where  english != 'Non Human Usage Products'
and pfc not in (select concept_code from Branded_Drug)
)

;
DROP TABLE drug_concept_STAGE;
-- ��� �������
create table DRUG_concept_STAGE (
concept_name	varchar(255),
vocabulary_id	varchar(20),
concept_class_id	varchar(20),
standard_concept	varchar(1),
concept_code	varchar(50),
possible_excipient	varchar(1),
valid_start_date	date,
valid_end_date	date,
invalid_reason	varchar(1)
)
;
--SEQUENCE FOR OMOP-GENERATED CODES
drop sequence conc_stage_seq ;
create sequence conc_stage_seq 
MINVALUE 100
  MAXVALUE 1000000
  START WITH 100
  INCREMENT BY 1
  CACHE 20;

  ;
  --TABLE WITH OMOP-GENERATED CODES
drop table list_temp;
create table list_temp as (
select a.*, conc_stage_seq.NEXTVAL as concept_code from ( select * from 
(select * from ingr
union 
select * from brand
union 
select * from forms)) a)
;
--CONCEPT-STAGE CREATION - NEED TO UPDATE NAMES IN THE FUTURE
insert into DRUG_concept_STAGE (CONCEPT_NAME,VOCABULARY_ID,CONCEPT_CLASS_ID,STANDARD_CONCEPT,CONCEPT_CODE,POSSIBLE_EXCIPIENT,VALID_START_DATE,VALID_END_DATE,INVALID_REASON)
select CONCEPT_NAME, 'DA_France', CONCEPT_CLASS_ID, '', CONCEPT_CODE, '', TO_DATE('2015/12/12', 'yyyy/mm/dd') as valid_start_date,
TO_DATE('2099/12/30', 'yyyy/mm/dd') as valid_end_date, ''
 from 
(
select CONCEPT_NAME,CONCEPT_CLASS_ID,CONCEPT_CODE from  Clinical_drug
union 
select CONCEPT_NAME,CONCEPT_CLASS_ID,CONCEPT_CODE from  Branded_drug
union 
select CONCEPT_NAME,CONCEPT_CLASS_ID,CONCEPT_CODE from unit
union
select CONCEPT_NAME, CONCEPT_CLASS_ID, 'OMOP'||CONCEPT_CODE from list_temp ) --ADD 'OMOP' to all OMOP-generated concepts
;

-- INTERNRAL_RELATIONSHIP table creation - building different classes combinations based on their appearence in original table
--drug_to_brnd_name_v2
drop table drug_to_brnd_name;
create table drug_to_brnd_name as (
select
a.concept_code as CONCEPT_CODE_1,  b.concept_code as  CONCEPT_CODE_2
from DRUG_concept_stage a join
dRUG_concept_stage b
on a.concept_class_id like  '%Branded%' and b.concept_class_id = 'Brand Name'
join france c on a.concept_code = c.pfc
and c.product_desc = b.concept_name)
;
drop table drug_to_form;
create table drug_to_form as (
select a.concept_code as drug_code,  b.concept_code as Form_code from drug_concept_stage a join
drug_concept_stage b
on (a.concept_class_id LIKE '%Branded%' OR a.concept_class_id LIKE '%Clinical%') and b.concept_class_id = 'Dose Form'
join france c on a.concept_code = c.pfc
and c.LB_NFC_3 = b.concept_name)
;
--c ������ ������������ �������
drop table BRAND_TO_CLIN;
CREATE TABLE BRAND_TO_CLIN AS (
select  a.concept_code AS BRAND_CODE,  b.concept_code AS CLIN_CODE -- 12914 ����� ��� ������������ �� package size, 6875 ����� package size ����������
from drug_concept_stage a join
drug_concept_stage b
on a.concept_class_id LIKE '%Branded%' and b.concept_class_id LIKE  '%Clinical%'
join france c on a.concept_code = c.pfc
join france d on b.concept_code = d.pfc
and d.molecule = c.molecule
and d.dosage = c.dosage
and d.lb_nfc_3= c.lb_nfc_3
and d.packsize= c.packsize
and d.volume = c.volume)
;
--����� drug_to_ingredient
drop table drug_to_ingr_name;
create table drug_to_ingr_name as (
select distinct
trim(regexp_substr(t.molecule, '[^\+]+', 1, levels.column_value))  as ingred, pfc
from france t,
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(t.molecule, '[^\+]+'))  + 1) as sys.OdciNumberList)) levels 
where trim(regexp_substr(t.molecule, '[^\+]+', 1, levels.column_value)) !='NULL')
;
--drug_to_ingred
drop table drug_to_ingred;
create table drug_to_ingred as (
select a.pfc as concept_code_1, b.concept_code as concept_code_2 from drug_to_ingr_name a join drug_concept_stage b on a.ingred = b.concept_name)
;
--brand_to_ingred
drop table brand_to_ingr;
create table brand_to_ingr as (
select distinct a.concept_code_2 as concept_code_1, b.concept_code_2 from drug_to_brnd_name a join drug_to_ingred b on a.concept_code_1 = b.concept_code_1
)
;
drop table quant_to_drg;
create table quant_to_drg as (
select  a.concept_code AS concept_code_1, b.concept_code as concept_code_2
from drug_concept_stage a join
drug_concept_stage b
on (a.concept_class_id LIKE '%Quant Brand%' and b.concept_class_id LIKE  '%Branded Drug%' 
or a.concept_class_id LIKE '%Quant Clin%' and b.concept_class_id LIKE  '%Clinical Drug%' )
join france c on a.concept_code = c.pfc
join france d on b.concept_code = d.pfc
and d.molecule = c.molecule
and d.dosage = c.dosage
and d.lb_nfc_3= c.lb_nfc_3
and d.packsize= c.packsize
and c.PRODUCT_DESC = d.PRODUCT_DESC)
;
--internal_relationship itself
drop table internal_relationship_stage;
create table internal_relationship_stage
(
concept_code_1		varchar(255)	,
vocabulary_id_1		varchar(20)	,
concept_code_2		varchar(255)	,
vocabulary_id_2		varchar(20)
)
;
insert into  internal_relationship_stage 
(CONCEPT_CODE_1,VOCABULARY_ID_1,CONCEPT_CODE_2,VOCABULARY_ID_2)
select concept_code_1, 'DA_France' as VOCABULARY_ID_1, CONCEPT_CODE_2,'DA_France' as VOCABULARY_ID_2
from 
(select * from quant_to_drg union
select * from drug_to_ingred union
select * from BRAND_TO_CLIN union
select * from drug_to_form union
select * from drug_to_brnd_name union
select * from brand_to_ingr
)
;
drop table RELATIONSHIP_TO_CONCEPT ;
create table RELATIONSHIP_TO_CONCEPT (
concept_code_1		varchar(255)	,
vocabulary_id_1	varchar(20)	,
concept_id_2		integer	,
precedence		integer	 ,
conversion_factor		float	
)
;

--ingredients mapping as a mix of automacaly and munualy created mappings
drop table ingredients_mapping;
create table ingredients_mapping as (
select a.concept_code as concept_code_1,c.concept_id as concept_id_2  from drug_concept_stage a join devv5.concept c on upper (c.concept_name) = a.concept_name and c.concept_class_id = 'Ingredient' and c.vocabulary_id = 'RxNorm' and c.invalid_reason is null 
where a.concept_class_id = 'Ingredient'
union
select b.concept_code,c.concept_id from INGR_NEED_TO_MAP_DONE a --munualy created table of ingredients mapping
join devv5.concept c on RN_CONCEPT_NAME = cast (c.concept_id as varchar (250)) 
join drug_concept_stage b on b.concept_name = a.concept_name
where RN_CONCEPT_NAME !='0')
--1450
;
--Brands mapping as a mix of automacaly and munualy created mappings
drop table Brand_names_mapping;
create table Brand_names_mapping as (
select a.concept_code as concept_code_1,c.concept_id as concept_id_2 from drug_concept_stage a join devv5.concept c on upper (c.concept_name) = a.concept_name and c.concept_class_id = 'Brand Name' and c.vocabulary_id = 'RxNorm' and c.invalid_reason is null 
where a.concept_class_id = 'Brand Name'
union
select b.concept_code,c.concept_id from BRAND_NEED_TO_MAP_DONE  a --munualy created table of brands mapping
join devv5.concept c on a.concept_id = c.concept_id
join drug_concept_stage b on b.concept_name = a.sourcename
where a.concept_id !=0)
;
--Units mapping
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('%', 'DA_France',8554,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('G', 'DA_France',8587,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('G', 'DA_France',8576,2,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IU', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('IU', 'DA_France',8718,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('K', 'DA_France',8510,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('K', 'DA_France',8718,2,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('KG', 'DA_France',8587,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('KG', 'DA_France',8576,2,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('L', 'DA_France',8587,1,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('L', 'DA_France',8576,2,1000000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('M', 'DA_France',8510,1,1000000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('M', 'DA_France',9439,2,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MCG', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MG', 'DA_France',8576,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('MG', 'DA_France',8587,2,0.001);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ML', 'DA_France',8587,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('ML', 'DA_France',8576,2,1000);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('U', 'DA_France',8510,1,1);
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor) values ('Y', 'DA_France',8576,1,0.001)
;
--insert forms mapping
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor)
select cast (CONCEPT_CODE_1 as varchar (250)) ,cast (VOCABULARY_ID_1 as varchar (20)),cast (CONCEPT_ID_2 as integer),cast (PRECEDENCE as integer),'' 
from form_mapping --munualy created table 
;
--insert Brand_mapping
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor)
select CONCEPT_CODE_1,'DA_France', CONCEPT_ID_2, 1, '' from Brand_names_mapping
;
--insert ingredients_mapping
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor)
select CONCEPT_CODE_1,'DA_France', CONCEPT_ID_2, 1, '' from ingredients_mapping
;
--insert additional ingredients mapping
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor)
select b.concept_code,'DA_France', a.concept_id, a.precedence, '' from add_ingr a join drug_concept_stage  b on a.source_name = b.concept_name
;
--insert addition form mapping
insert into relationship_to_concept (concept_code_1, vocabulary_id_1, concept_id_2, precedence, conversion_factor)
select b.concept_code,'DA_France', a.rn_id, a.precedence, '' from add_forms a left outer join drug_concept_stage  b on regexp_replace (a.france_name, '\s+', ' ') = b.concept_name
;
--Got some non-standard concepts during automation algorithm of concept-name equivalence selection so need to update using 'Form of'
update relationship_to_concept a set CONCEPT_ID_2 = (
select
  c2.concept_id as c2_id
from devv5.concept c1
join devv5.concept_relationship r on r.concept_id_1=c1.concept_id and r.invalid_reason is null and r.relationship_id='Form of'
join devv5.concept c2 on c2.concept_id=r.concept_id_2
--where c1.concept_id=46274851;
join relationship_to_concept rc on rc.concept_id_2 = c1.concept_id
where a.concept_code_1 = rc.concept_code_1 and rc.precedence = 1)
where exists 
(
 select rc.concept_code_1,  
  c2.concept_id as c2_id
from devv5.concept c1
join devv5.concept_relationship r on r.concept_id_1=c1.concept_id and r.invalid_reason is null and r.relationship_id='Form of'
join devv5.concept c2 on c2.concept_id=r.concept_id_2
--where c1.concept_id=46274851;
join relationship_to_concept rc on rc.concept_id_2 = c1.concept_id
where a.concept_code_1 = rc.concept_code_1 and rc.precedence = 1)
;
--drug strength
DROP TABLE DRUG_STRENGTH_STAGE;
CREATE TABLE DRUG_STRENGTH_STAGE
(
drug_concept_code		varchar(255)	,
ingredient_concept_code		varchar(255)	,
amount_value		float	,
amount_unit		varchar(255)	,
numerator_value		float	,
numerator_unit		varchar(255)	,
denominator_value		float	,
denominator_unit		varchar(255)	,
box_size	integer
)
;
--insert there concepts info step by step moving from easiest to more complicated cases
--doesn't have a volume and drug has only one ingredient
insert into DRUG_STRENGTH_STAGE (drug_concept_code, ingredient_concept_code	, amount_value, amount_unit,BOX_SIZE 	)
select a.concept_code_1, a.concept_code_2, strg_unit, STRG_MEAS, packsize
 from  internal_relationship_stage a join drug_concept_stage b on a.concept_code_1 = b.concept_code and b.concept_class_iD like '%Box%'
join drug_concept_stage c on a.concept_code_2 = c.concept_code and c.concept_class_id = 'Ingredient'
join france d on pfc = a.concept_code_1 and volume ='NULL' AND strg_unit !='NULL' AND MOLECULE NOT LIKE '%+%' AND strg_meas != '%'
;
--��� ���� ����� � ��� ��������� ���������
insert into DRUG_STRENGTH_STAGE (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE, NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT,BOX_SIZE)
select a.concept_code_1, a.concept_code_2, REPLACE (strg_unit, 'NULL'), replace( STRG_MEAS, 'NULL'), regexp_substr (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as denominator_value,
regexp_replace (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as denominator_unit,  packsize
 from  internal_relationship_stage a join drug_concept_stage b on a.concept_code_1 = b.concept_code and b.concept_class_iD like '%Box%'
join drug_concept_stage c on a.concept_code_2 = c.concept_code and c.concept_class_id = 'Ingredient'
join france d on pfc = a.concept_code_1 and (volume !='NULL' OR strg_meas = '%' ) AND MOLECULE NOT LIKE '%+%'
;
--����������� - ����������� ���������
drop table ingr_w_dos_1;
create table ingr_w_dos_1 as (
select distinct
trim(regexp_substr(t.molecule, '[^\+]+', 1, levels.column_value))  as ingred,
trim(regexp_substr(t.descr_pck, '[^/]+', 1, levels.column_value))  as concentr,
pfc
from
(select * from france  where molecule like '%+%' and descr_pck like '%/%'  ) t,
table(cast(multiset(select level from dual connect by  level <= length (regexp_replace(t.molecule, '[^\+]+'))  + 1) as sys.OdciNumberList)) levels)
;	
drop table  ingr_w_dos_3;
--������� � ��������� ����������� - ����� ��������� � ������� � ������������ ������. �������� ����-���� �������
create table ingr_w_dos_3 as (
select PFC, INGRED, CONCENTR, 
case when regexp_substr(concentr,'\d+\.\d+') is not null then regexp_substr(concentr,'\d+\.\d+')
when regexp_substr(concentr,'\d+\.\d+') is null then regexp_substr(concentr,'\d+') else null end as STRength,
case when regexp_substr(regexp_replace (concentr, '\s[[:digit:]\.]+\z'), '([^[:digit:]])+\z') IN (select concept_code from drug_concept_stage where concept_class_id = 'Unit') then  
regexp_substr(regexp_replace (concentr, '\s[[:digit:]\.]+\z'), '([^[:digit:]])+\z') 
else null end as UNIT
 from ingr_w_dos_1
)
;
--munually adding some dosages and units
UPDATE INGR_W_DOS_3
   SET STRENGTH = '0.025'
WHERE PFC = '2913501'
AND   INGRED = 'GESTODENE'
AND   STRENGTH = '025';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '0.025'
WHERE PFC = '2913601'
AND   INGRED = 'GESTODENE'
AND   STRENGTH = '025';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '0.050'
WHERE PFC = '2913603'
AND   INGRED = 'GESTODENE'
AND   STRENGTH = '050';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '0.050'
WHERE PFC = '2913503'
AND   INGRED = 'GESTODENE'
AND   STRENGTH = '050';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '4522701'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '2628206'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '2630601'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '1968116'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '2695203'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '1968111'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '2764506'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '2695208'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '2628207'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '2630602'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '4522702'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '2764507'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET STRENGTH = '125',
       UNIT = 'MG'
WHERE PFC = '3813708'
AND   INGRED = 'AMOXICILLIN'
AND   STRENGTH = '1.57';
UPDATE INGR_W_DOS_3
   SET UNIT = 'U'
WHERE PFC = '4083105'
AND   INGRED = 'COLECALCIFEROL'
AND   STRENGTH = '5600';
UPDATE INGR_W_DOS_3
   SET UNIT = 'U'
WHERE PFC = '3611504'
AND   INGRED = 'COLECALCIFEROL'
AND   STRENGTH = '5600';
UPDATE INGR_W_DOS_3
   SET UNIT = 'U'
WHERE PFC = '4083104'
AND   INGRED = 'COLECALCIFEROL'
AND   STRENGTH = '5600';
UPDATE INGR_W_DOS_3
   SET UNIT = 'Y'
WHERE PFC = '1714903'
AND   INGRED = 'DICLOFENAC'
AND   STRENGTH = '75'
;
update  ingr_w_dos_3 a 
set UNIT = (select unit from ingr_w_dos_3 b where a.pfc = b.pfc and a.ingred!=b.ingred and a.unit is null and b.unit is not null and a.strength is not null and a.concentr != '5600UI 4')
where exists (select unit from ingr_w_dos_3 b where a.pfc = b.pfc and a.ingred!=b.ingred and a.unit is null and b.unit is not null and a.strength is not null and a.concentr != '5600UI 4')
;

--where is no volume but has complex drug, dosages were taken from descr_pck column
insert into DRUG_STRENGTH_STAGE (drug_concept_code, ingredient_concept_code, amount_value, amount_unit,BOX_SIZE)
select a.pfc, c.concept_code as concept_code_2, STRENGTH , UNIT,  d.packsize 
from ingr_w_dos_3 a join drug_concept_stage c on a.INGRED = c.concept_name and c.concept_class_id = 'Ingredient'
join france d on a.pfc = d.pfc and volume ='NULL' AND MOLECULE LIKE '%+%' 

;
--where volume info but has complex drug, dosages were taken from descr_pck column. So we need to use numerator and denominator values
insert into DRUG_STRENGTH_STAGE (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE, NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT,BOX_SIZE)
select a.pfc, c.concept_code as concept_code_2, STRENGTH , UNIT, regexp_substr (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as denominator_value,
regexp_replace (volume, '[[:digit:]]+(\.[[:digit:]]+)?') as denominator_unit, d.packsize 
from ingr_w_dos_3 a join drug_concept_stage c on a.INGRED = c.concept_name and c.concept_class_id = 'Ingredient'
join france d on a.pfc = d.pfc and volume !='NULL' AND MOLECULE LIKE '%+%' 
;

--DRUG_STRENGTH_STAGE almost done, add drugs not having dosage
insert into  DRUG_STRENGTH_STAGE (DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE, DENOMINATOR_VALUE, DENOMINATOR_UNIT, BOX_SIZE)
select CAST (concept_code_1 AS VARCHAR (250)), CAST (concept_CODE_2 AS VARCHAR (250)), replace (regexp_substr (volume, '[[:digit:]]+(\.[[:digit:]]+)?'), 'NULL',''),
replace (regexp_replace (volume, '[[:digit:]]+(\.[[:digit:]]+)?'), 'NULL',''),  REPLACE (packsize, ' ', '')  from drug_to_ingred a  join france b on cAST (b.PFC AS VARCHAR (250))= a.concept_code_1
where concept_code_1 not in (select drug_concept_code from DRUG_STRENGTH_STAGE  )
;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '2558101'

AND   AMOUNT_VALUE = 160
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '2558101'

AND   AMOUNT_VALUE = 5
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '2558101'

AND   AMOUNT_VALUE = 12.5
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '2558103'

AND   AMOUNT_VALUE = 25
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '2558103'

AND   AMOUNT_VALUE = 160
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '2558103'

AND   AMOUNT_VALUE = 5
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '2558105'

AND   AMOUNT_VALUE = 25
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '2558105'

AND   AMOUNT_VALUE = 160
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '2558105'

AND   AMOUNT_VALUE = 10
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '2558107'

AND   AMOUNT_VALUE = 160
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '2558107'

AND   AMOUNT_VALUE = 10
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '2558107'

AND   AMOUNT_VALUE = 12.5
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '4697701'

AND   AMOUNT_VALUE = 245
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '4697701'

AND   AMOUNT_VALUE = 25
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '4697701'

AND   AMOUNT_VALUE = 200
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '5351701'

AND   AMOUNT_VALUE = 12.5
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '5351701'

AND   AMOUNT_VALUE = 160
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '5351701'

AND   AMOUNT_VALUE = 10
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '5351704'

AND   AMOUNT_VALUE = 12.5
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '5351704'

AND   AMOUNT_VALUE = 5
AND   AMOUNT_UNIT IS NULL;
UPDATE DRUG_STRENGTH_STAGE
   SET AMOUNT_UNIT = 'MG'
WHERE DRUG_CONCEPT_CODE = '5351704'

AND   AMOUNT_VALUE = 160
AND   AMOUNT_UNIT IS NULL
;
UPDATE DRUG_STRENGTH_STAGE
   SET NUMERATOR_VALUE =''
WHERE DRUG_CONCEPT_CODE = '4241801'
;
UPDATE DRUG_STRENGTH_STAGE
   SET DENOMINATOR_UNIT =''
WHERE DENOMINATOR_UNIT = 'NULL'
;
--we have several duplicate values because of structure source table 
--delete them using select DISTINCT statement
CREATE TABLE  DRUG_STRENGTH_STAGE_V3 AS (
SELECT DISTINCT DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT,BOX_SIZE FROM  DRUG_STRENGTH_STAGE)
;
DROP TABLE  DRUG_STRENGTH_STAGE
;
CREATE TABLE DRUG_STRENGTH_STAGE AS (SELECT * FROM DRUG_STRENGTH_STAGE_V3)
;
drop table DRUG_STRENGTH_STAGE_V3
;
--based on tables we already have create normal names 
--create ranked DRUG_STRENGTH_STAGE to define bind each ingredient with dosage corresponding
drop table drug_strength_rank ;
create table drug_strength_rank as 
 (select DRUG_CONCEPT_CODE,INGREDIENT_CONCEPT_CODE,AMOUNT_VALUE,AMOUNT_UNIT,NUMERATOR_VALUE,NUMERATOR_UNIT,DENOMINATOR_VALUE,DENOMINATOR_UNIT,BOX_SIZE,
RANK() OVER (PARTITION BY drug_concept_code ORDER BY INGREDIENT_CONCEPT_CODE) as rank1
from DRUG_STRENGTH_STAGE)
;
--create new drug names to update drug_concept_stage table
drop table clinical_name_0;
create table Clinical_name_0 as (
select distinct 
--using different cases for different number of ingredients
case when sc.cnt = 1 then 
--if drug contains only one ingredient 
case when s1.amount_value is not null then d1.concept_name||' '||s1.amount_value||' '||s1.amount_unit
when s1.numerator_value is not null and s1.numerator_unit !='%' then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name||' '||round (s1.numerator_value/s1.denominator_value, 3)||' '||s1.numerator_unit||'/'||s1.denominator_unit
when s1.numerator_value is not null and s1.numerator_unit ='%'  then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name||' '||s1.numerator_value||' '||s1.numerator_unit
when s1.numerator_value is null and s1.amount_value is null and s1.denominator_value is not null then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name
else d1.concept_name end 

||' '||c.dose_form_name||' Box of '||a.packsize
--if drug contains 2 ingredients
when sc.cnt = 2 then 
case when s1.amount_value is not null then d1.concept_name||' '||s1.amount_value||' '||s1.amount_unit
when s1.numerator_value is not null and s1.numerator_unit !='%' then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name||' '||round (s1.numerator_value/s1.denominator_value, 3)||' '||s1.numerator_unit||'/'||s1.denominator_unit
when s1.numerator_value is not null and s1.numerator_unit ='%'  then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name||' '||s1.numerator_value||' '||s1.numerator_unit
when s1.numerator_value is null and s1.amount_value is null and s1.denominator_value is not null then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name
else d1.concept_name end 
||' / '||
case when s2.amount_value is not null then d2.concept_name||' '||s2.amount_value||' '||s2.amount_unit
when s2.numerator_value is not null and s2.numerator_unit !='%' then d2.concept_name||' '||round (s2.numerator_value/s2.denominator_value, 3)||' '||s2.numerator_unit||'/'||s2.denominator_unit
when s2.numerator_value is not null and s2.numerator_unit ='%'  then d2.concept_name||' '||s2.numerator_value||' '||s2.numerator_unit||' '||s2.denominator_value||' '||s2.denominator_unit
when s2.numerator_value is null and s2.amount_value is null and s2.denominator_value is not null then d2.concept_name
else d2.concept_name end 
||' '||c.dose_form_name||' Box of '||a.packsize
--if drug contains 3 ingredients
when sc.cnt = 3 then 
case when s1.amount_value is not null then d1.concept_name||' '||s1.amount_value||' '||s1.amount_unit
when s1.numerator_value is not null and s1.numerator_unit !='%' then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name||' '||round (s1.numerator_value/s1.denominator_value, 3)||' '||s1.numerator_unit||'/'||s1.denominator_unit
when s1.numerator_value is not null and s1.numerator_unit ='%'  then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name||' '||s1.numerator_value||' '||s1.numerator_unit
when s1.numerator_value is null and s1.amount_value is null and s1.denominator_value is not null then s1.denominator_value||' '||s1.denominator_unit||' '|| d1.concept_name
else d1.concept_name end ||' / '||
case when s2.amount_value is not null then d2.concept_name||' '||s2.amount_value||' '||s2.amount_unit
when s2.numerator_value is not null and s2.numerator_unit !='%' then d2.concept_name||' '||round (s2.numerator_value/s2.denominator_value, 3)||' '||s2.numerator_unit||'/'||s2.denominator_unit
when s2.numerator_value is not null and s2.numerator_unit ='%'  then d2.concept_name||' '||s2.numerator_value||' '||s2.numerator_unit||' '||s2.denominator_value||' '||s2.denominator_unit
when s2.numerator_value is null and s2.amount_value is null and s2.denominator_value is not null then d2.concept_name
else d2.concept_name end ||' / '||
case when s3.amount_value is not null then d3.concept_name||' '||s3.amount_value||' '||s3.amount_unit
when s3.numerator_value is not null and s3.numerator_unit !='%' then d3.concept_name||' '||round (s3.numerator_value/s3.denominator_value, 3)||' '||s3.numerator_unit||'/'||s3.denominator_unit
when s3.numerator_value is not null and s3.numerator_unit ='%'  then d3.concept_name||' '||s3.numerator_value||' '||s3.numerator_unit||' '||s3.denominator_value||' '||s3.denominator_unit
when s3.numerator_value is null and s3.amount_value is null and s3.denominator_value is not null then d3.concept_name
else d3.concept_name end 
||' '||c.dose_form_name||' Box of '||a.packsize
--if drug has more than 3 ingredients, we don't have exact information about dosage used, so we don't include here drug_strength information
else substr ((replace (molecule, '+', ' / ')),1, 185) -- cut names if concept name length is more than 255, 70 is a maximal length of obligative info such as dose form, volume, Brand name, package size, so we can cut list of ingredients
||' '||a.volume||' '||c.dose_form_name||' Box of '||a.packsize
end
 as concept_name
,pfc as concept_code
from france a

 join  france_names_translation  c -- France form descriptions translated to English
on a.LB_NFC_3 = c.dose_form 
--joining with drug_strength table taking into account number of ingredients
left join (select * from drug_strength_rank  where rank1 = 1) s1
on s1.drug_concept_code = a.pfc
left join drug_concept_stage d1 on d1.concept_code = s1.INGREDIENT_CONCEPT_CODE
 
left join (select * from drug_strength_rank  where rank1 = 2) s2
on s2.drug_concept_code = a.pfc 
left join drug_concept_stage d2 on d2.concept_code = s2.INGREDIENT_CONCEPT_CODE

left join (select * from drug_strength_rank  where rank1 = 3)  s3
on s3.drug_concept_code = a.pfc 
left join drug_concept_stage d3 on d3.concept_code = s3.INGREDIENT_CONCEPT_CODE

join ( select drug_concept_code, count(1) as cnt from  drug_strength_stage group by drug_concept_code) sc on sc.drug_concept_code =a.pfc 
join drug_concept_stage f on  f.concept_code = a.pfc and f.concept_class_id like '%Clinical%'
)
;
drop table Branded_name_0;
create table Branded_name_0 as (
select distinct 
--using different cases for different number of ingredients
case when sc.cnt = 1 then 
-- if drug has only 1 ingredient
case when s1.amount_value is not null then d1.concept_name||' '||s1.amount_value||' '||s1.amount_unit
when s1.numerator_value is not null and s1.numerator_unit !='%' then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name||' '||round (s1.numerator_value/s1.denominator_value, 3)||' '||s1.numerator_unit||'/'||s1.denominator_unit
when s1.numerator_value is not null and s1.numerator_unit ='%'  then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name||' '||s1.numerator_value*1||' '||s1.numerator_unit
when s1.numerator_value is null and s1.amount_value is null and s1.denominator_value is not null then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name
else d1.concept_name end 

||' '||c.dose_form_name||' '||' ['||PRODUCT_DESC||']'||' Box of '||a.packsize
-- if drug has 2 ingredients
when sc.cnt = 2 then 
case when s1.amount_value is not null then d1.concept_name||' '||s1.amount_value||' '||s1.amount_unit
when s1.numerator_value is not null and s1.numerator_unit !='%' then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name||' '||round (s1.numerator_value/s1.denominator_value, 3)||' '||s1.numerator_unit||'/'||s1.denominator_unit
when s1.numerator_value is not null and s1.numerator_unit ='%'  then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name||' '||s1.numerator_value||' '||s1.numerator_unit
when s1.numerator_value is null and s1.amount_value is null and s1.denominator_value is not null then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name
else d1.concept_name end 
||' / '||
case when s2.amount_value is not null then d2.concept_name||' '||s2.amount_value||' '||s2.amount_unit
when s2.numerator_value is not null and s2.numerator_unit !='%' then d2.concept_name||' '||round (s2.numerator_value/s2.denominator_value, 3)||' '||s2.numerator_unit||'/'||s2.denominator_unit
when s2.numerator_value is not null and s2.numerator_unit ='%'  then d2.concept_name||' '||s2.numerator_value||' '||s2.numerator_unit||' '||s2.denominator_value||' '||s2.denominator_unit
when s2.numerator_value is null and s2.amount_value is null and s2.denominator_value is not null then d2.concept_name
else d2.concept_name end 
||' '||c.dose_form_name||' '||' ['||PRODUCT_DESC||']'||' Box of '||a.packsize
-- if drug has only 3 ingredients
when sc.cnt = 3 then 
case when s1.amount_value is not null then d1.concept_name||' '||s1.amount_value||' '||s1.amount_unit
when s1.numerator_value is not null and s1.numerator_unit !='%' then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name||' '||round (s1.numerator_value/s1.denominator_value, 3)||' '||s1.numerator_unit||'/'||s1.denominator_unit
when s1.numerator_value is not null and s1.numerator_unit ='%'  then s1.denominator_value||' '||s1.denominator_unit||' '||d1.concept_name||' '||s1.numerator_value||' '||s1.numerator_unit
when s1.numerator_value is null and s1.amount_value is null and s1.denominator_value is not null then s1.denominator_value||' '||s1.denominator_unit||' '|| d1.concept_name
else d1.concept_name end ||' / '||
case when s2.amount_value is not null then d2.concept_name||' '||s2.amount_value||' '||s2.amount_unit
when s2.numerator_value is not null and s2.numerator_unit !='%' then d2.concept_name||' '||round (s2.numerator_value/s2.denominator_value, 3)||' '||s2.numerator_unit||'/'||s2.denominator_unit
when s2.numerator_value is not null and s2.numerator_unit ='%'  then d2.concept_name||' '||s2.numerator_value||' '||s2.numerator_unit||' '||s2.denominator_value||' '||s2.denominator_unit
when s2.numerator_value is null and s2.amount_value is null and s2.denominator_value is not null then d2.concept_name
else d2.concept_name end ||' / '||
case when s3.amount_value is not null then d3.concept_name||' '||s3.amount_value||' '||s3.amount_unit
when s3.numerator_value is not null and s3.numerator_unit !='%' then d3.concept_name||' '||round (s3.numerator_value/s3.denominator_value, 3)||' '||s3.numerator_unit||'/'||s3.denominator_unit
when s3.numerator_value is not null and s3.numerator_unit ='%'  then d3.concept_name||' '||s3.numerator_value||' '||s3.numerator_unit||' '||s3.denominator_value||' '||s3.denominator_unit
when s3.numerator_value is null and s3.amount_value is null and s3.denominator_value is not null then d3.concept_name
else d3.concept_name end 
||' '||c.dose_form_name||' ['||PRODUCT_DESC||']'||' Box of '||a.packsize
--if drug has more than 3 ingredients
else substr ((replace (molecule, '+', ' / ')),1, 185)||' '||a.volume||' '||c.dose_form_name||' '||' ['||PRODUCT_DESC||']'||' Box of '||a.packsize
end
 as concept_name
,pfc as concept_code
from france a

 join  france_names_translation  c --France forms descriptions translated to English
on a.LB_NFC_3 = c.dose_form

left join (select * from drug_strength_rank  where rank1 = 1) s1
on s1.drug_concept_code = a.pfc
left join drug_concept_stage d1 on d1.concept_code = s1.INGREDIENT_CONCEPT_CODE
 
left join (select * from drug_strength_rank  where rank1 = 2) s2
on s2.drug_concept_code = a.pfc 
left join drug_concept_stage d2 on d2.concept_code = s2.INGREDIENT_CONCEPT_CODE

left join (select * from drug_strength_rank  where rank1 = 3)  s3
on s3.drug_concept_code = a.pfc 
left join drug_concept_stage d3 on d3.concept_code = s3.INGREDIENT_CONCEPT_CODE

join ( select drug_concept_code, count(1) as cnt from  drug_strength_stage group by drug_concept_code) sc on sc.drug_concept_code =a.pfc 
join drug_concept_stage f on  f.concept_code = a.pfc and f.concept_class_id like '%Branded%'
)
;
;
--inaccuracy occured in names such as '0.001' turned to '.001', and several spaces in a row because some entries in name could be null
--replace those inaccuaries
drop table clinical_name_1;
create table clinical_name_1 as (
select trim (regexp_replace (replace(( replace (concept_name, ' .', ' 0.')), '/.', '/0.'), '\s+', ' ')) as concept_name, CONCEPT_CODE from clinical_name_0)
;
--inaccuracy occured in names such as '0.001' turned to '.001', and several spaces in a row because some entries in name could be null
--replace those inaccuaries
drop table branded_name_1;
create table branded_name_1 as (
select trim( regexp_replace (replace(( replace (concept_name, ' .', ' 0.')), '/.', '/0.'), '\s+', ' ')) as concept_name, CONCEPT_CODE from branded_name_0)
;
--due to issues in source table we have several Brand names for the same Brand drug, so we need to remain only one
-- creating list of duplicates having longer length of concept name
drop table dubl_names;
create table dubl_names as (
select a.* from branded_name_1 a join  (
select concept_code, max(length (concept_name)) as lngth from branded_name_1 group by concept_code having count (1) >1) b on a.concept_code = b.concept_code and lngth = length (a.concept_name)
)
;
--deleting all rows where were duplicates
delete from  branded_name_1 where concept_code in (select concept_code from dubl_names )
;
--adding rows only where length was longer
insert into branded_name_1(CONCEPT_CODE, CONCEPT_NAME)
select concept_code, concept_name from dubl_names 
;
--both variants had the same length so delete this entry munually
DELETE FROM BRANDED_NAME_1
WHERE CONCEPT_NAME = 'SULFAMETHOXAZOLE 800 MG / TRIMETHOPRIM 160 MG Oral Tablet [COTRIMOXAZOLE RAT.] Box of 10'
AND   CONCEPT_CODE = '2098501';
;
--update drug_concept_stage with Branded drugs
update drug_concept_stage a 
set concept_name = (select concept_name from branded_name_1 b where a.concept_code = b.concept_code)
where exists (select concept_name from branded_name_1 b where a.concept_code = b.concept_code)
;
--update drug_concept_stage with Clinical drugs  
update drug_concept_stage a 
set concept_name = (select concept_name from clinical_name_1 b where a.concept_code = b.concept_code)
where exists (select concept_name from clinical_name_1 b where a.concept_code = b.concept_code)
;
update drug_concept_stage a 
set concept_name = (select '0'||concept_name from drug_concept_stage b where concept_name like '.%' and a.concept_code = b.concept_code)
where  exists (select '0'||concept_name from drug_concept_stage b where concept_name like '.%' and a.concept_code = b.concept_code)
;
/*
1. ������� ������� ��� ���������� - done
2. �������� � dose forms ������������ ����� - ��� ������ ���������
3. ���������� ������ update, ������� � ����������� ��� ������������� ������ done
4. �������� ����������� �����*/ 
;
--due to issues in source table we have several Brand names for the same Brand drug, so we need to remain only one
-- creating list of duplicates having longer length of concept name
--don't have duplicates anymore:)
/*drop table dubl_names;
create table dubl_names as (
select a.* from branded_name_1 a join  (
select concept_code, max(length (concept_name)) as lngth from branded_name_1 group by concept_code having count (1) >1) b on a.concept_code = b.concept_code and lngth = length (a.concept_name)
)
;
--deleting all rows where were duplicates
delete from  branded_name_1 where concept_code in (select concept_code from dubl_names )
;
--adding rows only where length was longer
insert into branded_name_1(CONCEPT_CODE, CONCEPT_NAME)
select concept_code, concept_name from dubl_names 
;
--both variants had the same length so delete this entry munually
DELETE FROM BRANDED_NAME_1
WHERE CONCEPT_NAME = 'SULFAMETHOXAZOLE 800 MG / TRIMETHOPRIM 160 MG Oral Tablet [COTRIMOXAZOLE RAT.] Box of 10'
AND   CONCEPT_CODE = '2098501';
;*/
