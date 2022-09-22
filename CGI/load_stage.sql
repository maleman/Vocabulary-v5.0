/**************************************************************************
* Copyright 2016 Observational Health Data Sciences and Informatics (OHDSI)
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
* Authors: Varvara Savitskaya, Vlad Korsik
* Date: 2022
**************************************************************************/

DO $_$
BEGIN
	PERFORM VOCABULARY_PACK.SetLatestUpdate(
	pVocabularyName			=> 'CGI',
	pVocabularyDate			=> current_date,
	pVocabularyVersion		=> 'CGI'||TO_CHAR(CURRENT_DATE,'YYYYMMDD'),
	pVocabularyDevSchema	=> 'dev_cgi',
	pAppendVocabulary		=> FALSE
);
END $_$;


truncate concept_stage;
truncate concept_relationship_stage;
truncate concept_synonym_stage;

drop table cgi_source_new;
create table cgi_source_new as (
select distinct concat(gene, ':', regexp_replace(protein, 'p.', '')) as concept_name, 'CGI' as vocabulary_id,  concat(gene, ':', regexp_replace(protein, 'p.', '')) as concept_code,gdna as hgvs
from dev_cgi.genomic_cgi_new
where gdna != ''
and protein != '.');


--insert into concept_stage
insert into concept_stage
with s as (SELECT DISTINCT
       COALESCE(c.concept_id, NULL::int)  as concept_id,
       trim(substr(n.concept_name,1,255)) AS concept_name,
       'Measurement' AS domain_id,
       n.vocabulary_id AS vocabulary_id,
       'Variant' AS concept_class_id,
       NULL AS standard_concept,
       n.concept_code AS concept_code,
      COALESCE(c.valid_start_date, v.latest_update)   as valid_start_date, -- defines valid_start_date  based on previous vocabulary run
       COALESCE(c.valid_end_date,TO_DATE('20991231', 'yyyymmdd'))  as valid_end_date -- defines valid_end_date  based on previous vocabulary run
FROM cgi_source_new n
JOIN vocabulary v ON v.vocabulary_id = 'CGI'
LEFT JOIN concept c ON c.concept_code = n.concept_code -- already existing LOINC concepts
    	AND c.vocabulary_id = 'CGI')

SELECT distinct
       s.concept_id,
       s.concept_name,
       s.domain_id,
       s.vocabulary_id,
       s.concept_class_id,
       s.standard_concept,
       s.concept_code,
       s.valid_start_date,
       s.valid_end_date ,
      CASE WHEN s.concept_code is null then 'D' else null end as invalid_reason
from s
FULL OUTER JOIN concept c ON c.concept_code = s.concept_code -- already existing LOINC concepts
    	and c.vocabulary_id = 'CGI'
where s.concept_code is not null
;


-- insert synonyms
insert into concept_synonym_stage
select *
from (
select
DISTINCT NULL::INT as synonym_concept_id,
hgvs AS synonym_name,
cs.concept_code as synonym_concept_code,
cs.vocabulary_id AS synonym_vocabulary_id,
4180186 as language_concept_id
from cgi_source_new a
join concept_stage cs on cs.concept_code = a.concept_code
) r
where synonym_name is not null
;
