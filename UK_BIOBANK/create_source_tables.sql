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
* Authors: Alexander Davydov, Oleg Zhuk
* Date: 2020
**************************************************************************/

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_ENCODING;
CREATE TABLE SOURCES.UK_BIOBANK_ENCODING
(
   ENCODING_ID  INT,
   TITLE        TEXT,
   AVAILABILITY INT2,
   CODED_AS     INT2,
   STRUCTURE    INT2,
   NUM_MEMBERS  INT,
   DESCRIPT     TEXT
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_CATEGORY;
CREATE TABLE SOURCES.UK_BIOBANK_CATEGORY
(
   CATEGORY_ID  INT,
   TITLE        TEXT,
   AVAILABILITY INT2,
   GROUP_TYPE   INT2,
   DESCRIPT     TEXT,
   NOTES        TEXT
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_EHIERINT;
CREATE TABLE SOURCES.UK_BIOBANK_EHIERINT
(
   ENCODING_ID    INT,
   CODE_ID        INT,
   PARENT_ID      INT,
   VALUE          TEXT,
   MEANING        TEXT,
   SELECTABLE     INT2,
   SHOWCASE_ORDER NUMERIC
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_EHIERSTRING;
CREATE TABLE SOURCES.UK_BIOBANK_EHIERSTRING
(
   ENCODING_ID    INT,
   CODE_ID        INT,
   PARENT_ID      INT,
   VALUE          TEXT,
   MEANING        TEXT,
   SELECTABLE     INT2,
   SHOWCASE_ORDER NUMERIC
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_ESIMPSTRING;
CREATE TABLE SOURCES.UK_BIOBANK_ESIMPSTRING
(
   ENCODING_ID    INT,
   VALUE          TEXT,
   MEANING        TEXT,
   SHOWCASE_ORDER NUMERIC
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_ESIMPREAL;
CREATE TABLE SOURCES.UK_BIOBANK_ESIMPREAL
(
   ENCODING_ID    INT,
   VALUE          TEXT,
   MEANING        TEXT,
   SHOWCASE_ORDER NUMERIC
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_ESIMPINT;
CREATE TABLE SOURCES.UK_BIOBANK_ESIMPINT
(
   ENCODING_ID    INT,
   VALUE          TEXT,
   MEANING        TEXT,
   SHOWCASE_ORDER NUMERIC
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_ESIMPDATE;
CREATE TABLE SOURCES.UK_BIOBANK_ESIMPDATE
(
   ENCODING_ID    INT,
   VALUE          TEXT,
   MEANING        TEXT,
   SHOWCASE_ORDER NUMERIC
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_FIELD;
CREATE TABLE SOURCES.UK_BIOBANK_FIELD
(
   FIELD_ID         INT,
   TITLE            TEXT,
   AVAILABILITY     INT2,
   STABILITY        INT2,
   PRIVATE          INT2,
   VALUE_TYPE       INT2,
   BASE_TYPE        INT2,
   ITEM_TYPE        INT2,
   STRATA           INT2,
   INSTANCED        INT2,
   ARRAYED          INT2,
   SEXED            INT2,
   UNITS            TEXT,
   MAIN_CATEGORY    INT,
   ENCODING_ID      INT,
   INSTANCE_ID      INT,
   INSTANCE_MIN     INT2,
   INSTANCE_MAX     INT2,
   ARRAY_MIN        INT2,
   ARRAY_MAX        INT2,
   NOTES            TEXT,
   DEBUT            DATE,
   VERSION          DATE,
   NUM_PARTICIPANTS INT,
   ITEM_COUNT       INT,
   SHOWCASE_ORDER   NUMERIC
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_FIELDSUM;
CREATE TABLE SOURCES.UK_BIOBANK_FIELDSUM
(
   FIELD_ID  INT,
   TITLE     TEXT,
   ITEM_TYPE INT2
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_INSTANCES;
CREATE TABLE SOURCES.UK_BIOBANK_INSTANCES
(
   INSTANCE_ID INT,
   DESCRIPT    TEXT,
   NUM_MEMBERS INT
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_INSVALUE;
CREATE TABLE SOURCES.UK_BIOBANK_INSVALUE
(
   INSTANCE_ID INT,
   INDEX       INT2,
   TITLE       TEXT,
   DESCRIPT    TEXT
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_RECOMMENDED;
CREATE TABLE SOURCES.UK_BIOBANK_RECOMMENDED
(
   CATEGORY_ID INT,
   FIELD_ID    INT
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_RETURNS;
CREATE TABLE SOURCES.UK_BIOBANK_RETURNS
(
   ARCHIVE_ID     INT,
   APPLICATION_ID INT,
   TITLE          TEXT,
   AVAILABILITY   INT2,
   PERSONAL       INT2,
   NOTES          TEXT
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_CATBROWSE;
CREATE TABLE SOURCES.UK_BIOBANK_CATBROWSE
(
   PARENT_ID      INT,
   CHILD_ID       INT,
   SHOWCASE_ORDER NUMERIC
);

DROP TABLE IF EXISTS SOURCES.UK_BIOBANK_HESDICTIONARY;
CREATE TABLE SOURCES.UK_BIOBANK_HESDICTIONARY
(
   TABLE_NAME    TEXT,
   FIELD         TEXT,
   DESCRIPTION   TEXT,
   DATA_TYPE     TEXT,
   DATA_CODING   TEXT,
   NOTES         TEXT,
   SUMMARY_FIELD TEXT
);