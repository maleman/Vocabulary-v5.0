-- 1. Update latest_update field to new date 
BEGIN
   EXECUTE IMMEDIATE 'ALTER TABLE vocabulary DROP COLUMN latest_update';
EXCEPTION WHEN OTHERS THEN NULL;
END;
ALTER TABLE vocabulary ADD latest_update DATE;
UPDATE vocabulary SET latest_update=to_date('20150511','yyyymmdd'), vocabulary_version='2015 Release' WHERE vocabulary_id='MeSH'; 
COMMIT;

-- 2. Truncate all working tables and remove indices
TRUNCATE TABLE concept_stage;
TRUNCATE TABLE concept_relationship_stage;
TRUNCATE TABLE concept_synonym_stage;
ALTER SESSION SET SKIP_UNUSABLE_INDEXES = TRUE; --disables error reporting of indexes and index partitions marked UNUSABLE
ALTER INDEX idx_cs_concept_code UNUSABLE;
ALTER INDEX idx_cs_concept_id UNUSABLE;
ALTER INDEX idx_concept_code_1 UNUSABLE;
ALTER INDEX idx_concept_code_2 UNUSABLE;

--3. Load CONCEPT_STAGE from the existing one. The reason is that there is no good source for these concepts
-- Build Main Heading (Descriptors)
INSERT /*+ APPEND */ INTO CONCEPT_STAGE (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
	select distinct 
		null as concept_id,
		mh.str as concept_name,
		-- Pick the domain from existing mapping in UMLS with the following order of predence:
		first_value(c.domain_id) over (partition by mh.code order by decode(c.vocabulary_id, 'RxNorm', 1, 'SNOMED', 2, 'LOINC', 3, 'CPT4', 4, 9)) as domain_id,
		'MeSH' as vocabulary_id,
		'Main Heading' as concept_class_id,
		null as standard_concept,
		mh.code as concept_code,
		TO_DATE ('19700101', 'yyyymmdd') as valid_start_date,
		TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
		null as invalid_reason 
	from umls.mrconso mh
	-- join to umls cpt4, hcpcs and rxnorm concepts
	join umls.mrconso m on mh.cui=m.cui and m.sab in ('CPT', 'HCPCS', 'HCPT', 'RXNORM', 'SNOMEDCT_US') and m.suppress='N' and m.tty<>'SY'
	join concept c on c.concept_code=m.code and c.standard_concept = 'S' and c.vocabulary_id=decode(m.sab, 'CPT', 'CPT4', 'HCPT', 'CPT4', 'RXNORM', 'RxNorm', 'SNOMEDCT_US', 'SNOMED', 'LNC', 'LOINC', m.sab) and domain_id in ('Condition', 'Procedure', 'Drug', 'Measurement')
	where mh.suppress='N'
	and mh.sab='MSH' 
	and mh.lat='ENG' 
	and mh.tty='MH';
COMMIT;	

-- Build Supplementary Concepts
INSERT /*+ APPEND */ INTO CONCEPT_STAGE (concept_id,
                           concept_name,
                           domain_id,
                           vocabulary_id,
                           concept_class_id,
                           standard_concept,
                           concept_code,
                           valid_start_date,
                           valid_end_date,
                           invalid_reason)
	select distinct 
		null as concept_id,
		mh.str as concept_name,
		-- Pick the domain from existing mapping in UMLS with the following order of predence:
		first_value(c.domain_id) over (partition by mh.code order by decode(c.vocabulary_id, 'RxNorm', 1, 'SNOMED', 2, 'LOINC', 3, 'CPT4', 4, 9)) as domain_id,
		'MeSH' as vocabulary_id,
		'Suppl Concept' as concept_class_id,
		null as standard_concept,
		mh.code as concept_code,
		TO_DATE ('19700101', 'yyyymmdd') as valid_start_date,
		TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
		null as invalid_reason 
	from umls.mrconso mh
	-- join to umls cpt4, hcpcs and rxnorm concepts
	join umls.mrconso m on mh.cui=m.cui and m.sab in ('CPT', 'HCPCS', 'HCPT', 'RXNORM', 'SNOMEDCT_US') and m.suppress='N' and m.tty<>'SY'
	join concept c on c.concept_code=m.code and c.standard_concept = 'S' and c.vocabulary_id=decode(m.sab, 'CPT', 'CPT4', 'HCPT', 'CPT4', 'RXNORM', 'RxNorm', 'SNOMEDCT_US', 'SNOMED', 'LNC', 'LOINC', m.sab) and domain_id in ('Condition', 'Procedure', 'Drug', 'Measurement')
	where mh.suppress='N'
	and mh.sab='MSH' 
	and mh.lat='ENG' 
	and mh.tty='NM';
COMMIT;	

--4. Create concept_relationship_stage
INSERT /*+ APPEND */ INTO  concept_relationship_stage (concept_code_1,
                                        concept_code_2,
                                        vocabulary_id_1,
                                        vocabulary_id_2,
                                        relationship_id,
                                        valid_start_date,
                                        valid_end_date,
                                        invalid_reason)
	select distinct 
		mh.code as concept_code_1,
		-- Pick existing mapping from UMLS with the following order of predence:
		first_value(c.concept_code) over (partition by mh.code order by decode(c.vocabulary_id, 'RxNorm', 1, 'SNOMED', 2, 'LOINC', 3, 'CPT4', 4, 9)) as concept_code_2,
		'MeSH' as vocabulary_id_1,  
		first_value(c.vocabulary_id) over (partition by mh.code order by decode(c.vocabulary_id, 'RxNorm', 1, 'SNOMED', 2, 'LOINC', 3, 'CPT4', 4, 9)) as vocabulary_id_2,
		'Maps to' as relationship_id,
		TO_DATE ('19700101', 'yyyymmdd') as valid_start_date,
		TO_DATE ('20991231', 'yyyymmdd') as valid_end_date,
		null as invalid_reason   
	from umls.mrconso mh
	-- join to umls cpt4, hcpcs and rxnorm concepts
	join umls.mrconso m on mh.cui=m.cui and m.sab in ('CPT', 'HCPCS', 'HCPT', 'RXNORM', 'SNOMEDCT_US') and m.suppress='N' and m.tty<>'SY'
	join concept c on c.concept_code=m.code and c.standard_concept = 'S' and c.vocabulary_id=decode(m.sab, 'CPT', 'CPT4', 'HCPT', 'CPT4', 'RXNORM', 'RxNorm', 'SNOMEDCT_US', 'SNOMED', 'LNC', 'LOINC', m.sab) and domain_id in ('Condition', 'Procedure', 'Drug', 'Measurement')
	where mh.suppress='N'
	and mh.sab='MSH' 
	and mh.lat='ENG' 
	and mh.tty in ('NM', 'MH');
COMMIT;	 

--5. Add synonyms
INSERT /*+ APPEND */ INTO  concept_synonym_stage (synonym_concept_code,
                                   synonym_vocabulary_id,
                                   synonym_name,
                                   language_concept_id)
                                  
	select c.concept_code as synonym_concept_code,
		'MeSH' as synonym_vocabulary_id,
		 u.str as synonym_name, 
		4093769 AS language_concept_id                    -- English 
	from concept_stage c
	join umls.mrconso u on u.code=c.concept_code and u.sab = 'MSH' and u.suppress = 'N' and u.lat='ENG';
COMMIT;

--6 Update concept_id in concept_stage from concept for existing concepts
UPDATE concept_stage cs
    SET cs.concept_id=(SELECT c.concept_id FROM concept c WHERE c.concept_code=cs.concept_code AND c.vocabulary_id=cs.vocabulary_id)
    WHERE cs.concept_id IS NULL;


--7 Reinstate constraints and indices
ALTER INDEX idx_cs_concept_code REBUILD NOLOGGING;
ALTER INDEX idx_cs_concept_id REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_1 REBUILD NOLOGGING;
ALTER INDEX idx_concept_code_2 REBUILD NOLOGGING;

-- At the end, the three tables concept_stage, concept_relationship_stage and concept_synonym_stage should be ready to be fed into the generic_update.sql script		