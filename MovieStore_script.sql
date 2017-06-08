--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.2
-- Dumped by pg_dump version 9.6.2

-- Started on 2017-06-08 23:46:02

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 1 (class 3079 OID 12387)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2298 (class 0 OID 0)
-- Dependencies: 1
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 207 (class 1255 OID 16867)
-- Name: close_position(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION close_position(posname text) RETURNS void
    LANGUAGE sql
    AS $$
update "Guide positions" set "Date of end" = now() where "Id_Position" in
(select id_position from get_available_positions() where position_name = posname limit 1);
$$;


ALTER FUNCTION public.close_position(posname text) OWNER TO postgres;

--
-- TOC entry 227 (class 1255 OID 16921)
-- Name: fact_sum_interval(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fact_sum_interval(integer, date) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
declare
x interval;
result integer := 0;
begin

if (SELECT EXTRACT(EPOCH FROM (select * from fact_timetable($1,$2) limit 1)) is null) then
	return -1;
end if;
for x in select * from fact_timetable($1, $2)
loop
	result := result + (SELECT EXTRACT(EPOCH FROM x))/3600;
end loop;

return result;
end
$_$;


ALTER FUNCTION public.fact_sum_interval(integer, date) OWNER TO postgres;

--
-- TOC entry 226 (class 1255 OID 16917)
-- Name: fact_timetable(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION fact_timetable(integer, date) RETURNS TABLE(x interval)
    LANGUAGE sql
    AS $_$
select age("Datetime_to", "Datetime_from") from "Presence/Absence" where "Id" = $1 and "Datetime_from" between ($2 + time '00:00') and ($2 + time '23:59');
$_$;


ALTER FUNCTION public.fact_timetable(integer, date) OWNER TO postgres;

--
-- TOC entry 222 (class 1255 OID 16858)
-- Name: get_available_positions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_available_positions() RETURNS TABLE(id_position integer, position_name text)
    LANGUAGE sql
    AS $$

SELECT "Id_Position", "Positions' name" FROM "Position" x WHERE
(

SELECT count(*) FROM "Person on position" WHERE "Person on position"."Id_Position" = x."Id_Position"
AND "Date of dismissal" is NULL

) = 0 AND

(

SELECT count(*) FROM "Guide positions" WHERE "Guide positions"."Id_Position" = x."Id_Position"
AND "Date of end" is not NULL

) = 0;

$$;


ALTER FUNCTION public.get_available_positions() OWNER TO postgres;

--
-- TOC entry 223 (class 1255 OID 16904)
-- Name: holiday(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION holiday(date) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$


declare
xx timestamp;
x_month integer;
x_day integer;
b boolean;

begin
select $1 + time '00:00' into xx;
select EXTRACT(MONTH FROM xx) into x_month;
select extract(day from xx) into x_day;
select 
(x_day = 1 and x_month = 1) or 
(x_day = 7 and x_month = 1) or 
(x_day = 8 and x_month = 3) or 
(x_day = 1 and x_month = 5) or
(x_day = 2 and x_month = 5) or
(x_day = 9 and x_month = 5) or
(x_day = 7 and x_month = 7) or
(x_day = 24 and x_month = 8) or
(x_day = 14 and x_month = 10) or
(x_day = 6 and x_month = 12) or
(x_day = 19 and x_month = 12) into b;
return b;
end
$_$;


ALTER FUNCTION public.holiday(date) OWNER TO postgres;

--
-- TOC entry 221 (class 1255 OID 16833)
-- Name: insert_depinfo(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_depinfo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ 
BEGIN
	IF NEW."Department's name" IS NULL THEN
		RAISE EXCEPTION 'Department`s name cannot be null';
	END IF;
	INSERT INTO "Contragent" VALUES (nextval('IDs'));
	new."Id" := currval('IDs');
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.insert_depinfo() OWNER TO postgres;

--
-- TOC entry 220 (class 1255 OID 16831)
-- Name: insert_personinfo(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION insert_personinfo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ 
BEGIN
	IF NEW."First name" IS NULL THEN
		RAISE EXCEPTION 'First name cannot be null';
	END IF;
	IF NEW."Last name" IS NULL THEN
		RAISE EXCEPTION 'Last name cannot be null';
	END IF;
	IF NEW."Middle name" IS NULL THEN
		RAISE EXCEPTION 'Middle name cannot be null';
	END IF;
	IF NEW."Adress" IS NULL THEN
		RAISE EXCEPTION 'Adress of % cannot be null', NEW."Last name";
	END IF; 
	IF NEW."Phone number" IS NULL THEN
		RAISE EXCEPTION 'Phone number of % cannot be null', NEW."Last name";
	END IF;
	IF NEW."Date of birth" IS NULL THEN
		RAISE EXCEPTION 'Date of birth of % cannot be null', NEW."Last name";
	END IF;
	INSERT INTO "Contragent" VALUES (nextval('IDs'));
	new."Id" := currval('IDs');
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.insert_personinfo() OWNER TO postgres;

--
-- TOC entry 206 (class 1255 OID 16847)
-- Name: search_staff(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION search_staff(keyword text) RETURNS TABLE(id integer, lastname text, firstname text, middlename text, positionname text, department text, employment date, dismissal date, address text, phone bigint, birth date)
    LANGUAGE sql
    AS $$
select * from staff where lower(concat("Id", "Last name", "First name", "Middle name", "Positions' name", "Department's name", "Date of employment", "Date of dismissal", "Adress", "Phone number", "Date of birth"))
LIKE lower(concat('%', keyword, '%'));
$$;


ALTER FUNCTION public.search_staff(keyword text) OWNER TO postgres;

--
-- TOC entry 224 (class 1255 OID 16915)
-- Name: sum_interval(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION sum_interval(integer, date) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
declare
x interval;
result integer := 0;
begin

for x in select * from timetable($1, $2)
loop
	result = result + (SELECT EXTRACT(EPOCH FROM x))/3600;
end loop;
return result;

end
$_$;


ALTER FUNCTION public.sum_interval(integer, date) OWNER TO postgres;

--
-- TOC entry 225 (class 1255 OID 16906)
-- Name: timetable(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION timetable(integer, date) RETURNS TABLE(x interval)
    LANGUAGE sql
    AS $_$
select age($2 + "Time of end", $2 + "Time of start") from 
(
select * from "Timetable" where "Id_Timetable" in (select "Id_Timetable" from "Person on work" where "Id" = $1 and EXTRACT(DOW FROM $2 + time '00:00:00') between "Start of work" and "End of work")
) as foo;

$_$;


ALTER FUNCTION public.timetable(integer, date) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 185 (class 1259 OID 16409)
-- Name: Article in order; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Article in order" (
    "Id_Article in order" integer NOT NULL,
    "Amount" integer NOT NULL,
    "Price" double precision NOT NULL,
    "Id_Article" integer
);


ALTER TABLE "Article in order" OWNER TO postgres;

--
-- TOC entry 186 (class 1259 OID 16414)
-- Name: Catalog; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Catalog" (
    "Id_Article" integer NOT NULL,
    "Article" text NOT NULL,
    "Id_Type of article" integer
);


ALTER TABLE "Catalog" OWNER TO postgres;

--
-- TOC entry 187 (class 1259 OID 16422)
-- Name: Causes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Causes" (
    "Id_Causes" integer NOT NULL,
    "Cause" text
);


ALTER TABLE "Causes" OWNER TO postgres;

--
-- TOC entry 188 (class 1259 OID 16430)
-- Name: Contragent; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Contragent" (
    "Id" integer NOT NULL
);


ALTER TABLE "Contragent" OWNER TO postgres;

--
-- TOC entry 189 (class 1259 OID 16435)
-- Name: Department; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Department" (
    "Id" integer NOT NULL,
    "Department's name" text NOT NULL
);


ALTER TABLE "Department" OWNER TO postgres;

--
-- TOC entry 190 (class 1259 OID 16443)
-- Name: Entity; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Entity" (
    "Id" integer NOT NULL,
    "Company's name" text NOT NULL,
    "USREOU" bigint
);


ALTER TABLE "Entity" OWNER TO postgres;

--
-- TOC entry 191 (class 1259 OID 16451)
-- Name: Guide positions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Guide positions" (
    "Id_Position" integer NOT NULL,
    "Id_Payment type" integer NOT NULL,
    "Salary" double precision NOT NULL,
    "Date of start" date NOT NULL,
    "Date of end" date
);


ALTER TABLE "Guide positions" OWNER TO postgres;

--
-- TOC entry 192 (class 1259 OID 16456)
-- Name: Individual; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Individual" (
    "Id" integer NOT NULL,
    "First name" text NOT NULL,
    "Last name" text NOT NULL,
    "Middle name" text NOT NULL,
    "Adress" text NOT NULL,
    "Phone number" bigint NOT NULL,
    "Date of birth" date NOT NULL
);


ALTER TABLE "Individual" OWNER TO postgres;

--
-- TOC entry 193 (class 1259 OID 16464)
-- Name: Order; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Order" (
    "Id_Order" integer NOT NULL,
    "Status" text NOT NULL,
    "Id" integer,
    "Date of order" date NOT NULL,
    "Id_Reason for order" integer,
    "Id_Type of order" integer,
    "Id_Article in order" integer
);


ALTER TABLE "Order" OWNER TO postgres;

--
-- TOC entry 194 (class 1259 OID 16472)
-- Name: Payment type; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Payment type" (
    "Id_Payment type" integer NOT NULL,
    "Types' name" text NOT NULL
);


ALTER TABLE "Payment type" OWNER TO postgres;

--
-- TOC entry 195 (class 1259 OID 16480)
-- Name: Person on position; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Person on position" (
    "Id_Person on position" integer NOT NULL,
    "Id_Position" integer,
    "Id" integer,
    "Date of employment" date NOT NULL,
    "Date of dismissal" date
);


ALTER TABLE "Person on position" OWNER TO postgres;

--
-- TOC entry 196 (class 1259 OID 16485)
-- Name: Person on work; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Person on work" (
    "Id_Person on work" integer NOT NULL,
    "Start of work" integer NOT NULL,
    "End of work" integer,
    "Id" integer,
    "Id_Timetable" integer
);


ALTER TABLE "Person on work" OWNER TO postgres;

--
-- TOC entry 197 (class 1259 OID 16490)
-- Name: Position; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Position" (
    "Id_Position" integer NOT NULL,
    "Positions' name" text NOT NULL,
    "Id" integer
);


ALTER TABLE "Position" OWNER TO postgres;

--
-- TOC entry 198 (class 1259 OID 16498)
-- Name: Presence/Absence; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Presence/Absence" (
    "Id_Presence/Absence" integer NOT NULL,
    "Datetime_from" timestamp without time zone,
    "Datetime_to" timestamp without time zone,
    "Id_Causes" integer,
    "Id" integer
);


ALTER TABLE "Presence/Absence" OWNER TO postgres;

--
-- TOC entry 199 (class 1259 OID 16503)
-- Name: Reason for order; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Reason for order" (
    "Id_Reason for order" integer NOT NULL,
    "Reason" text NOT NULL
);


ALTER TABLE "Reason for order" OWNER TO postgres;

--
-- TOC entry 200 (class 1259 OID 16511)
-- Name: Timetable; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Timetable" (
    "Id_Timetable" integer NOT NULL,
    "Time of start" time without time zone NOT NULL,
    "Time of end" time without time zone
);


ALTER TABLE "Timetable" OWNER TO postgres;

--
-- TOC entry 201 (class 1259 OID 16516)
-- Name: Type of Article; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Type of Article" (
    "Id_Type of article" integer NOT NULL,
    "Type's name" text NOT NULL
);


ALTER TABLE "Type of Article" OWNER TO postgres;

--
-- TOC entry 202 (class 1259 OID 16524)
-- Name: Type of order; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE "Type of order" (
    "Id_Type of order" integer NOT NULL,
    "Type's name" text NOT NULL
);


ALTER TABLE "Type of order" OWNER TO postgres;

--
-- TOC entry 203 (class 1259 OID 16829)
-- Name: ids; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE ids
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ids OWNER TO postgres;

--
-- TOC entry 205 (class 1259 OID 16862)
-- Name: positions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW positions AS
 SELECT "Position"."Positions' name",
    count(*) AS count,
    "Department"."Department's name",
    "Guide positions"."Date of start",
    "Guide positions"."Salary",
    "Payment type"."Types' name",
    "Guide positions"."Date of end"
   FROM "Guide positions",
    "Position",
    "Payment type",
    "Department"
  WHERE (("Position"."Id_Position" = "Guide positions"."Id_Position") AND ("Guide positions"."Id_Payment type" = "Payment type"."Id_Payment type") AND ("Position"."Id" = "Department"."Id"))
  GROUP BY "Position"."Positions' name", "Department"."Department's name", "Guide positions"."Date of start", "Guide positions"."Salary", "Payment type"."Types' name", "Guide positions"."Date of end";


ALTER TABLE positions OWNER TO postgres;

--
-- TOC entry 204 (class 1259 OID 16841)
-- Name: staff; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW staff AS
 SELECT "Individual"."Id",
    "Individual"."Last name",
    "Individual"."First name",
    "Individual"."Middle name",
    "Position"."Positions' name",
    "Department"."Department's name",
    "Person on position"."Date of employment",
    "Person on position"."Date of dismissal",
    "Individual"."Adress",
    "Individual"."Phone number",
    "Individual"."Date of birth"
   FROM "Individual",
    "Position",
    "Person on position",
    "Department"
  WHERE (("Individual"."Id" = "Person on position"."Id") AND ("Department"."Id" = "Position"."Id") AND ("Position"."Id_Position" = "Person on position"."Id_Position"));


ALTER TABLE staff OWNER TO postgres;

--
-- TOC entry 2273 (class 0 OID 16409)
-- Dependencies: 185
-- Data for Name: Article in order; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Article in order" ("Id_Article in order", "Amount", "Price", "Id_Article") FROM stdin;
\.


--
-- TOC entry 2274 (class 0 OID 16414)
-- Dependencies: 186
-- Data for Name: Catalog; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Catalog" ("Id_Article", "Article", "Id_Type of article") FROM stdin;
\.


--
-- TOC entry 2275 (class 0 OID 16422)
-- Dependencies: 187
-- Data for Name: Causes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Causes" ("Id_Causes", "Cause") FROM stdin;
90	Допрацювання звіту
92	Запізнення
94	Важливий клієнт
105	Відпрацювання
107	Хвороба
137	Сімейні обставини
150	Прохання менеджера
\.


--
-- TOC entry 2276 (class 0 OID 16430)
-- Dependencies: 188
-- Data for Name: Contragent; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Contragent" ("Id") FROM stdin;
1
2
4
5
6
7
8
9
10
11
12
16
17
19
25
49
50
51
53
78
129
156
168
174
180
186
192
198
204
210
216
221
229
\.


--
-- TOC entry 2277 (class 0 OID 16435)
-- Dependencies: 189
-- Data for Name: Department; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Department" ("Id", "Department's name") FROM stdin;
2	Відділ продажів
12	Відділ забезпечення
25	Відділ управління
\.


--
-- TOC entry 2278 (class 0 OID 16443)
-- Dependencies: 190
-- Data for Name: Entity; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Entity" ("Id", "Company's name", "USREOU") FROM stdin;
\.


--
-- TOC entry 2279 (class 0 OID 16451)
-- Dependencies: 191
-- Data for Name: Guide positions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Guide positions" ("Id_Position", "Id_Payment type", "Salary", "Date of start", "Date of end") FROM stdin;
30	23	3500	2017-05-07	\N
34	14	3500	2016-01-24	\N
35	14	3500	2016-01-24	\N
3	14	3500	2016-01-24	2017-05-10
77	23	3500	2017-05-07	\N
41	23	1600	2017-05-07	2017-05-09
42	23	1600	2017-05-07	\N
43	14	4300	2017-05-10	\N
44	14	4300	2017-05-10	\N
27	14	6000	2015-05-07	\N
134	14	4300	2017-05-18	\N
228	23	3200	2017-05-25	\N
\.


--
-- TOC entry 2280 (class 0 OID 16456)
-- Dependencies: 192
-- Data for Name: Individual; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Individual" ("Id", "First name", "Last name", "Middle name", "Adress", "Phone number", "Date of birth") FROM stdin;
9	Оксана	Вершиніна	Григорівна	м. Біла Церква, вул. Шевченка 112/а, кв.24	380509802168	1973-11-26
19	Тетяна	Косташ	Володимирівна	м. Київ, Дарницький бульвар 8	380937631093	1997-01-24
11	Костянтин	Вершинін	Олександрович	м. Біла Церква, вул. Шевченка 112/а, кв.24	380976598746	1971-06-03
49	Валерія	Снігірьова	Юр*ївна	м. Київ, вул. Саперна 8	380672694382	1996-10-18
50	Валерія	Снігірьова	Юр*ївна	м. Київ, вул. Саперна 8	380679876543	1996-10-18
51	Валерія	Снігірьова	Юр*ївна	м. Київ, вул. Саперна 8	380978765434	1996-10-18
53	Володимир	Меденцій	Анатолійович	м. Київ, вул. Авеню 5	380632201666	1996-09-01
78	Владислав	Шрам	Юрійович	м. Київ, пров. Ковальський 5	380978654567	1997-06-28
129	Андрій	Мороз	Ярославович	м. Київ, пров. Ковальський, 5	380967493945	1996-12-10
156	Ніна	Кудіна	Юр*ївна	м. Київ, пров. Ковальський 5	380976543456	1998-07-21
17	Дмитро	Задохін	Володимирович	м. Біла Церква, вул. Вокзальна 11, кв.137	380970809841	1997-11-08
216	Тетяна	Руденко	Володимирівна	м. Київ, Дарницький бульвар 8	380937631093	1997-01-24
221	Олена	Мусієнко	Степанівна	м. Київ, вул. Прорізна, 6	380978765674	1987-06-07
229	Віталій	Кінда	Валерійович	м. Вишневе, пров. Весняний, 3	380678541287	1997-01-03
\.


--
-- TOC entry 2281 (class 0 OID 16464)
-- Dependencies: 193
-- Data for Name: Order; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Order" ("Id_Order", "Status", "Id", "Date of order", "Id_Reason for order", "Id_Type of order", "Id_Article in order") FROM stdin;
\.


--
-- TOC entry 2282 (class 0 OID 16472)
-- Dependencies: 194
-- Data for Name: Payment type; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Payment type" ("Id_Payment type", "Types' name") FROM stdin;
14	Безготівкова оплата
23	Готівка
\.


--
-- TOC entry 2283 (class 0 OID 16480)
-- Dependencies: 195
-- Data for Name: Person on position; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Person on position" ("Id_Person on position", "Id_Position", "Id", "Date of employment", "Date of dismissal") FROM stdin;
31	27	9	2015-05-07	\N
18	34	17	2017-05-06	2017-05-10
15	3	11	2016-01-24	2017-05-10
46	43	17	2017-05-12	\N
52	34	51	2017-05-13	\N
54	35	53	2017-05-13	\N
79	77	78	2017-05-13	\N
130	42	129	2017-05-18	\N
157	134	156	2017-05-20	\N
45	30	19	2017-05-10	2017-05-20
20	35	19	2017-05-06	2017-05-10
217	30	216	2017-05-20	\N
222	44	221	2017-05-25	\N
230	228	229	2017-06-08	\N
\.


--
-- TOC entry 2284 (class 0 OID 16485)
-- Dependencies: 196
-- Data for Name: Person on work; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Person on work" ("Id_Person on work", "Start of work", "End of work", "Id", "Id_Timetable") FROM stdin;
67	1	3	51	63
68	1	3	51	64
70	1	3	53	48
120	1	6	9	119
122	1	6	9	121
83	1	3	78	48
124	1	3	19	123
126	1	3	19	125
128	4	6	19	127
69	4	6	51	48
71	4	6	53	63
72	4	6	53	64
84	4	6	78	63
85	4	6	78	64
148	1	6	129	147
164	1	3	156	127
165	1	3	156	127
166	4	6	156	127
218	1	3	216	123
219	1	3	216	125
220	4	6	216	127
224	1	5	221	118
225	1	5	221	109
\.


--
-- TOC entry 2285 (class 0 OID 16490)
-- Dependencies: 197
-- Data for Name: Position; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Position" ("Id_Position", "Positions' name", "Id") FROM stdin;
3	Касир	2
30	Консультант	2
34	Касир	2
35	Касир	2
77	Консультант	2
41	Охоронець	12
42	Охоронець	12
43	Оптовий торговець	12
44	Оптовий торговець	12
27	Менеджер	25
134	Маркетолог	2
228	Прибиральник	12
\.


--
-- TOC entry 2286 (class 0 OID 16498)
-- Dependencies: 198
-- Data for Name: Presence/Absence; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Presence/Absence" ("Id_Presence/Absence", "Datetime_from", "Datetime_to", "Id_Causes", "Id") FROM stdin;
95	2017-05-15 10:00:00	2017-05-15 11:00:00	94	19
96	2017-05-15 12:00:00	2017-05-15 19:00:00	94	19
97	2017-05-13 12:00:00	2017-05-13 13:00:00	92	78
98	2017-05-13 14:00:00	2017-05-13 18:00:00	92	78
99	2017-05-08 09:00:00	2017-05-08 14:00:00	90	9
100	2017-05-08 18:00:00	2017-05-08 23:00:00	94	9
101	2017-05-16 09:00:00	2017-05-16 10:00:00	90	17
102	2017-05-16 11:00:00	2017-05-16 18:00:00	90	17
103	2017-05-15 11:00:00	2017-05-15 12:00:00	92	51
104	2017-05-15 13:00:00	2017-05-15 18:00:00	92	51
106	2017-05-12 17:00:00	2017-05-12 22:00:00	105	51
108	2017-04-20 18:00:00	2017-04-20 20:00:00	107	51
91	2017-05-08 13:00:00	2017-05-08 18:00:00	92	17
114	2017-05-17 10:00:00	2017-05-17 11:00:00	92	17
115	2017-05-17 12:00:00	2017-05-17 17:00:00	92	17
116	2017-05-17 08:00:00	2017-05-17 09:00:00	105	51
117	2017-05-17 10:00:00	2017-05-17 18:00:00	105	51
138	2017-05-10 10:00:00	2017-05-10 11:00:00	137	51
139	2017-05-10 12:00:00	2017-05-10 17:00:00	137	51
149	2017-05-19 10:00:00	2017-05-19 21:00:00	137	129
151	2017-05-18 09:00:00	2017-05-18 22:00:00	150	129
153	2017-05-19 00:01:00	2017-05-19 00:01:00	137	53
154	2017-05-12 00:01:00	2017-05-12 00:01:00	94	17
226	2017-05-16 09:00:00	2017-05-16 10:00:00	150	51
227	2017-05-16 11:00:00	2017-05-16 18:00:00	150	51
\.


--
-- TOC entry 2287 (class 0 OID 16503)
-- Dependencies: 199
-- Data for Name: Reason for order; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Reason for order" ("Id_Reason for order", "Reason") FROM stdin;
\.


--
-- TOC entry 2288 (class 0 OID 16511)
-- Dependencies: 200
-- Data for Name: Timetable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Timetable" ("Id_Timetable", "Time of start", "Time of end") FROM stdin;
48	18:00:00	22:00:00
63	10:00:00	13:00:00
64	14:00:00	18:00:00
86	12:00:00	18:00:00
87	09:00:00	12:00:00
88	13:00:00	17:00:00
109	14:00:00	17:00:00
118	09:00:00	13:00:00
119	15:00:00	18:00:00
121	09:00:00	13:00:00
123	10:00:00	13:00:00
125	14:00:00	18:00:00
127	18:00:00	22:00:00
142	10:00:00	22:00:00
144	10:00:00	22:00:00
145	10:00:00	22:00:00
147	10:00:00	22:00:00
155	10:00:00	17:00:00
161	14:00:00	17:00:00
223	14:00:00	17:00:00
\.


--
-- TOC entry 2289 (class 0 OID 16516)
-- Dependencies: 201
-- Data for Name: Type of Article; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Type of Article" ("Id_Type of article", "Type's name") FROM stdin;
\.


--
-- TOC entry 2290 (class 0 OID 16524)
-- Dependencies: 202
-- Data for Name: Type of order; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY "Type of order" ("Id_Type of order", "Type's name") FROM stdin;
\.


--
-- TOC entry 2313 (class 0 OID 0)
-- Dependencies: 203
-- Name: ids; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ids', 230, true);


--
-- TOC entry 2099 (class 2606 OID 16413)
-- Name: Article in order pkArticle in order; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Article in order"
    ADD CONSTRAINT "pkArticle in order" PRIMARY KEY ("Id_Article in order");


--
-- TOC entry 2101 (class 2606 OID 16421)
-- Name: Catalog pkCatalog; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Catalog"
    ADD CONSTRAINT "pkCatalog" PRIMARY KEY ("Id_Article");


--
-- TOC entry 2103 (class 2606 OID 16429)
-- Name: Causes pkCauses; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Causes"
    ADD CONSTRAINT "pkCauses" PRIMARY KEY ("Id_Causes");


--
-- TOC entry 2105 (class 2606 OID 16434)
-- Name: Contragent pkContragent; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Contragent"
    ADD CONSTRAINT "pkContragent" PRIMARY KEY ("Id");


--
-- TOC entry 2107 (class 2606 OID 16442)
-- Name: Department pkDepartment; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Department"
    ADD CONSTRAINT "pkDepartment" PRIMARY KEY ("Id");


--
-- TOC entry 2109 (class 2606 OID 16450)
-- Name: Entity pkEntity; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Entity"
    ADD CONSTRAINT "pkEntity" PRIMARY KEY ("Id");


--
-- TOC entry 2111 (class 2606 OID 16455)
-- Name: Guide positions pkGuide positions; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Guide positions"
    ADD CONSTRAINT "pkGuide positions" PRIMARY KEY ("Id_Position");


--
-- TOC entry 2113 (class 2606 OID 16463)
-- Name: Individual pkIndividual; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Individual"
    ADD CONSTRAINT "pkIndividual" PRIMARY KEY ("Id");


--
-- TOC entry 2115 (class 2606 OID 16471)
-- Name: Order pkOrder; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Order"
    ADD CONSTRAINT "pkOrder" PRIMARY KEY ("Id_Order");


--
-- TOC entry 2117 (class 2606 OID 16479)
-- Name: Payment type pkPayment type; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Payment type"
    ADD CONSTRAINT "pkPayment type" PRIMARY KEY ("Id_Payment type");


--
-- TOC entry 2119 (class 2606 OID 16484)
-- Name: Person on position pkPerson on position; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Person on position"
    ADD CONSTRAINT "pkPerson on position" PRIMARY KEY ("Id_Person on position");


--
-- TOC entry 2121 (class 2606 OID 16489)
-- Name: Person on work pkPerson on work; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Person on work"
    ADD CONSTRAINT "pkPerson on work" PRIMARY KEY ("Id_Person on work");


--
-- TOC entry 2123 (class 2606 OID 16497)
-- Name: Position pkPosition; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Position"
    ADD CONSTRAINT "pkPosition" PRIMARY KEY ("Id_Position");


--
-- TOC entry 2125 (class 2606 OID 16502)
-- Name: Presence/Absence pkPresence/Absence; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Presence/Absence"
    ADD CONSTRAINT "pkPresence/Absence" PRIMARY KEY ("Id_Presence/Absence");


--
-- TOC entry 2127 (class 2606 OID 16510)
-- Name: Reason for order pkReason for order; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Reason for order"
    ADD CONSTRAINT "pkReason for order" PRIMARY KEY ("Id_Reason for order");


--
-- TOC entry 2129 (class 2606 OID 16515)
-- Name: Timetable pkTimetable; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Timetable"
    ADD CONSTRAINT "pkTimetable" PRIMARY KEY ("Id_Timetable");


--
-- TOC entry 2131 (class 2606 OID 16523)
-- Name: Type of Article pkType of Article; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Type of Article"
    ADD CONSTRAINT "pkType of Article" PRIMARY KEY ("Id_Type of article");


--
-- TOC entry 2133 (class 2606 OID 16531)
-- Name: Type of order pkType of order; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Type of order"
    ADD CONSTRAINT "pkType of order" PRIMARY KEY ("Id_Type of order");


--
-- TOC entry 2152 (class 2620 OID 16859)
-- Name: Department insert_depinfo; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER insert_depinfo BEFORE INSERT ON "Department" FOR EACH ROW EXECUTE PROCEDURE insert_depinfo();


--
-- TOC entry 2153 (class 2620 OID 16860)
-- Name: Individual insert_personinfo; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER insert_personinfo BEFORE INSERT ON "Individual" FOR EACH ROW EXECUTE PROCEDURE insert_personinfo();


--
-- TOC entry 2134 (class 2606 OID 16537)
-- Name: Article in order fk_Article in order_Catalog; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Article in order"
    ADD CONSTRAINT "fk_Article in order_Catalog" FOREIGN KEY ("Id_Article") REFERENCES "Catalog"("Id_Article");


--
-- TOC entry 2135 (class 2606 OID 16542)
-- Name: Catalog fk_Catalog_Type of Article; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Catalog"
    ADD CONSTRAINT "fk_Catalog_Type of Article" FOREIGN KEY ("Id_Type of article") REFERENCES "Type of Article"("Id_Type of article");


--
-- TOC entry 2136 (class 2606 OID 16547)
-- Name: Department fk_Department_Contragent; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Department"
    ADD CONSTRAINT "fk_Department_Contragent" FOREIGN KEY ("Id") REFERENCES "Contragent"("Id");


--
-- TOC entry 2137 (class 2606 OID 16552)
-- Name: Entity fk_Entity_Contragent; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Entity"
    ADD CONSTRAINT "fk_Entity_Contragent" FOREIGN KEY ("Id") REFERENCES "Contragent"("Id");


--
-- TOC entry 2138 (class 2606 OID 16557)
-- Name: Guide positions fk_Guide positions_Payment type; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Guide positions"
    ADD CONSTRAINT "fk_Guide positions_Payment type" FOREIGN KEY ("Id_Payment type") REFERENCES "Payment type"("Id_Payment type");


--
-- TOC entry 2139 (class 2606 OID 16562)
-- Name: Guide positions fk_Guide positions_Position; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Guide positions"
    ADD CONSTRAINT "fk_Guide positions_Position" FOREIGN KEY ("Id_Position") REFERENCES "Position"("Id_Position");


--
-- TOC entry 2140 (class 2606 OID 16567)
-- Name: Individual fk_Individual_Contragent; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Individual"
    ADD CONSTRAINT "fk_Individual_Contragent" FOREIGN KEY ("Id") REFERENCES "Contragent"("Id");


--
-- TOC entry 2141 (class 2606 OID 16572)
-- Name: Order fk_Order_Contragent; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Order"
    ADD CONSTRAINT "fk_Order_Contragent" FOREIGN KEY ("Id") REFERENCES "Contragent"("Id");


--
-- TOC entry 2142 (class 2606 OID 16577)
-- Name: Order fk_Order_Goods in order; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Order"
    ADD CONSTRAINT "fk_Order_Goods in order" FOREIGN KEY ("Id_Article in order") REFERENCES "Article in order"("Id_Article in order");


--
-- TOC entry 2143 (class 2606 OID 16582)
-- Name: Order fk_Order_Reason for order; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Order"
    ADD CONSTRAINT "fk_Order_Reason for order" FOREIGN KEY ("Id_Reason for order") REFERENCES "Reason for order"("Id_Reason for order");


--
-- TOC entry 2144 (class 2606 OID 16587)
-- Name: Order fk_Order_Type of order; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Order"
    ADD CONSTRAINT "fk_Order_Type of order" FOREIGN KEY ("Id_Type of order") REFERENCES "Type of order"("Id_Type of order");


--
-- TOC entry 2145 (class 2606 OID 16592)
-- Name: Person on position fk_Person on position_Guide positions; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Person on position"
    ADD CONSTRAINT "fk_Person on position_Guide positions" FOREIGN KEY ("Id_Position") REFERENCES "Guide positions"("Id_Position");


--
-- TOC entry 2146 (class 2606 OID 16597)
-- Name: Person on position fk_Person on position_Individual; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Person on position"
    ADD CONSTRAINT "fk_Person on position_Individual" FOREIGN KEY ("Id") REFERENCES "Individual"("Id");


--
-- TOC entry 2147 (class 2606 OID 16602)
-- Name: Person on work fk_Person on work_Individual; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Person on work"
    ADD CONSTRAINT "fk_Person on work_Individual" FOREIGN KEY ("Id") REFERENCES "Individual"("Id");


--
-- TOC entry 2148 (class 2606 OID 16607)
-- Name: Person on work fk_Person on work_Timetable; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Person on work"
    ADD CONSTRAINT "fk_Person on work_Timetable" FOREIGN KEY ("Id_Timetable") REFERENCES "Timetable"("Id_Timetable");


--
-- TOC entry 2149 (class 2606 OID 16612)
-- Name: Position fk_Position_Department; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Position"
    ADD CONSTRAINT "fk_Position_Department" FOREIGN KEY ("Id") REFERENCES "Department"("Id");


--
-- TOC entry 2150 (class 2606 OID 16617)
-- Name: Presence/Absence fk_Presence/Absence_Causes; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Presence/Absence"
    ADD CONSTRAINT "fk_Presence/Absence_Causes" FOREIGN KEY ("Id_Causes") REFERENCES "Causes"("Id_Causes");


--
-- TOC entry 2151 (class 2606 OID 16622)
-- Name: Presence/Absence fk_Presence/Absence_Individual; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY "Presence/Absence"
    ADD CONSTRAINT "fk_Presence/Absence_Individual" FOREIGN KEY ("Id") REFERENCES "Individual"("Id");


--
-- TOC entry 2299 (class 0 OID 0)
-- Dependencies: 187
-- Name: Causes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "Causes" TO manager;
GRANT ALL ON TABLE "Causes" TO cashier;


--
-- TOC entry 2300 (class 0 OID 0)
-- Dependencies: 188
-- Name: Contragent; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "Contragent" TO manager;


--
-- TOC entry 2301 (class 0 OID 0)
-- Dependencies: 189
-- Name: Department; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "Department" TO manager;
GRANT SELECT ON TABLE "Department" TO cashier;


--
-- TOC entry 2302 (class 0 OID 0)
-- Dependencies: 191
-- Name: Guide positions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "Guide positions" TO manager;


--
-- TOC entry 2303 (class 0 OID 0)
-- Dependencies: 192
-- Name: Individual; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "Individual" TO manager;


--
-- TOC entry 2304 (class 0 OID 0)
-- Dependencies: 194
-- Name: Payment type; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "Payment type" TO manager;
GRANT SELECT ON TABLE "Payment type" TO cashier;


--
-- TOC entry 2305 (class 0 OID 0)
-- Dependencies: 195
-- Name: Person on position; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "Person on position" TO manager;


--
-- TOC entry 2306 (class 0 OID 0)
-- Dependencies: 196
-- Name: Person on work; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "Person on work" TO manager;


--
-- TOC entry 2307 (class 0 OID 0)
-- Dependencies: 197
-- Name: Position; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "Position" TO manager;


--
-- TOC entry 2308 (class 0 OID 0)
-- Dependencies: 198
-- Name: Presence/Absence; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "Presence/Absence" TO manager;


--
-- TOC entry 2309 (class 0 OID 0)
-- Dependencies: 200
-- Name: Timetable; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE "Timetable" TO manager;
GRANT ALL ON TABLE "Timetable" TO cashier;


--
-- TOC entry 2310 (class 0 OID 0)
-- Dependencies: 203
-- Name: ids; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE ids TO manager;


--
-- TOC entry 2311 (class 0 OID 0)
-- Dependencies: 205
-- Name: positions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE positions TO manager;
GRANT SELECT ON TABLE positions TO cashier;


--
-- TOC entry 2312 (class 0 OID 0)
-- Dependencies: 204
-- Name: staff; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE staff TO manager;
GRANT ALL ON TABLE staff TO cashier;


-- Completed on 2017-06-08 23:46:04

--
-- PostgreSQL database dump complete
--

