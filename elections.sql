--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.6
-- Dumped by pg_dump version 9.6.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: consituencies; Type: TABLE; Schema: public; Owner: jkerry
--

CREATE TABLE consituencies (
    id integer NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE consituencies OWNER TO jkerry;

--
-- Name: bigcircles_id_seq; Type: SEQUENCE; Schema: public; Owner: jkerry
--

CREATE SEQUENCE bigcircles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bigcircles_id_seq OWNER TO jkerry;

--
-- Name: bigcircles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: jkerry
--

ALTER SEQUENCE bigcircles_id_seq OWNED BY consituencies.id;


--
-- Name: candidate_categories; Type: TABLE; Schema: public; Owner: jkerry
--

CREATE TABLE candidate_categories (
    id integer NOT NULL,
    name character varying NOT NULL
);


ALTER TABLE candidate_categories OWNER TO jkerry;

--
-- Name: candidate_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: jkerry
--

CREATE SEQUENCE candidate_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE candidate_categories_id_seq OWNER TO jkerry;

--
-- Name: candidate_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: jkerry
--

ALTER SEQUENCE candidate_categories_id_seq OWNED BY candidate_categories.id;


--
-- Name: candidates; Type: TABLE; Schema: public; Owner: jkerry
--

CREATE TABLE candidates (
    id integer NOT NULL,
    name character varying NOT NULL,
    district_id integer NOT NULL,
    electoral_list_id integer NOT NULL,
    category_id integer NOT NULL
);


ALTER TABLE candidates OWNER TO jkerry;

--
-- Name: candidates_id_seq; Type: SEQUENCE; Schema: public; Owner: jkerry
--

CREATE SEQUENCE candidates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE candidates_id_seq OWNER TO jkerry;

--
-- Name: candidates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: jkerry
--

ALTER SEQUENCE candidates_id_seq OWNED BY candidates.id;


--
-- Name: district_quotas; Type: TABLE; Schema: public; Owner: jkerry
--

CREATE TABLE district_quotas (
    district_id integer NOT NULL,
    category_id integer NOT NULL,
    value integer NOT NULL
);


ALTER TABLE district_quotas OWNER TO jkerry;

--
-- Name: districts; Type: TABLE; Schema: public; Owner: jkerry
--

CREATE TABLE districts (
    id integer NOT NULL,
    name character varying NOT NULL,
    constituency_id integer NOT NULL
);


ALTER TABLE districts OWNER TO jkerry;

--
-- Name: constituency_list_size; Type: VIEW; Schema: public; Owner: jkerry
--

CREATE VIEW constituency_list_size AS
 SELECT c.id AS constituency_id,
    sum(COALESCE(dq.value, 0)) AS list_size
   FROM (((districts d
     CROSS JOIN candidate_categories cc)
     JOIN consituencies c ON ((c.id = d.constituency_id)))
     JOIN ( SELECT d1.id AS district_id,
            cc1.id AS category_id,
            COALESCE(dq1.value, 0) AS value
           FROM ((districts d1
             CROSS JOIN candidate_categories cc1)
             LEFT JOIN district_quotas dq1 ON (((dq1.category_id = cc1.id) AND (dq1.district_id = d1.id))))) dq ON (((dq.category_id = cc.id) AND (dq.district_id = d.id))))
  GROUP BY c.id, c.name
  ORDER BY c.id;


ALTER TABLE constituency_list_size OWNER TO jkerry;

--
-- Name: constituency_quota_list; Type: VIEW; Schema: public; Owner: jkerry
--

CREATE VIEW constituency_quota_list AS
 SELECT 'Constituency'::character varying AS constituency_name,
    'District'::character varying AS district_name,
    'Total'::character varying AS total,
    array_agg(cc.name ORDER BY cc.id DESC) AS quota_arr
   FROM candidate_categories cc
UNION ALL
( SELECT c.name AS constituency_name,
    d.name AS district_name,
    (sum(COALESCE(dq.value, 0)))::character varying AS total,
    array_agg((COALESCE(dq.value, 0))::character varying ORDER BY dq.category_id) AS quota_arr
   FROM (((districts d
     CROSS JOIN candidate_categories cc)
     JOIN consituencies c ON ((c.id = d.constituency_id)))
     JOIN ( SELECT d1.id AS district_id,
            cc1.id AS category_id,
            COALESCE(dq1.value, 0) AS value
           FROM ((districts d1
             CROSS JOIN candidate_categories cc1)
             LEFT JOIN district_quotas dq1 ON (((dq1.category_id = cc1.id) AND (dq1.district_id = d1.id))))) dq ON (((dq.category_id = cc.id) AND (dq.district_id = d.id))))
  GROUP BY c.id, c.name, d.id, d.name
  ORDER BY c.id, d.id);


ALTER TABLE constituency_quota_list OWNER TO jkerry;

--
-- Name: electoral_lists; Type: TABLE; Schema: public; Owner: jkerry
--

CREATE TABLE electoral_lists (
    id integer NOT NULL,
    name character varying NOT NULL,
    constituency_id integer NOT NULL
);


ALTER TABLE electoral_lists OWNER TO jkerry;

--
-- Name: electoral_lists_id_seq; Type: SEQUENCE; Schema: public; Owner: jkerry
--

CREATE SEQUENCE electoral_lists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE electoral_lists_id_seq OWNER TO jkerry;

--
-- Name: electoral_lists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: jkerry
--

ALTER SEQUENCE electoral_lists_id_seq OWNED BY electoral_lists.id;


--
-- Name: preferential_votes; Type: TABLE; Schema: public; Owner: jkerry
--

CREATE TABLE preferential_votes (
    constituency_id integer NOT NULL,
    candidate_id integer NOT NULL,
    value integer NOT NULL
);


ALTER TABLE preferential_votes OWNER TO jkerry;

--
-- Name: smallcircles_id_seq; Type: SEQUENCE; Schema: public; Owner: jkerry
--

CREATE SEQUENCE smallcircles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE smallcircles_id_seq OWNER TO jkerry;

--
-- Name: smallcircles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: jkerry
--

ALTER SEQUENCE smallcircles_id_seq OWNED BY districts.id;


--
-- Name: votes_per_list; Type: TABLE; Schema: public; Owner: jkerry
--

CREATE TABLE votes_per_list (
    consituency_id integer NOT NULL,
    electoral_list_id integer,
    value integer NOT NULL
);


ALTER TABLE votes_per_list OWNER TO jkerry;

--
-- Name: candidate_categories id; Type: DEFAULT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY candidate_categories ALTER COLUMN id SET DEFAULT nextval('candidate_categories_id_seq'::regclass);


--
-- Name: candidates id; Type: DEFAULT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY candidates ALTER COLUMN id SET DEFAULT nextval('candidates_id_seq'::regclass);


--
-- Name: consituencies id; Type: DEFAULT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY consituencies ALTER COLUMN id SET DEFAULT nextval('bigcircles_id_seq'::regclass);


--
-- Name: districts id; Type: DEFAULT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY districts ALTER COLUMN id SET DEFAULT nextval('smallcircles_id_seq'::regclass);


--
-- Name: electoral_lists id; Type: DEFAULT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY electoral_lists ALTER COLUMN id SET DEFAULT nextval('electoral_lists_id_seq'::regclass);


--
-- Name: bigcircles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: jkerry
--

SELECT pg_catalog.setval('bigcircles_id_seq', 30, true);


--
-- Data for Name: candidate_categories; Type: TABLE DATA; Schema: public; Owner: jkerry
--

COPY candidate_categories (id, name) FROM stdin;
1	سني
2	شيعي
3	درزي
4	علوي
5	ماروني
6	روم كاثوليك
7	روم ارثوذكس
8	انجيلي
9	أرمن كاثوليك
10	أرمن ارثوذكس
11	أقليات
\.


--
-- Name: candidate_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: jkerry
--

SELECT pg_catalog.setval('candidate_categories_id_seq', 11, true);


--
-- Data for Name: candidates; Type: TABLE DATA; Schema: public; Owner: jkerry
--

COPY candidates (id, name, district_id, electoral_list_id, category_id) FROM stdin;
\.


--
-- Name: candidates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: jkerry
--

SELECT pg_catalog.setval('candidates_id_seq', 1, false);


--
-- Data for Name: consituencies; Type: TABLE DATA; Schema: public; Owner: jkerry
--

COPY consituencies (id, name) FROM stdin;
16	بيروت الاولى
17	بيروت الثانية
18	الجنوب الاولى
19	الجنوب الثانية
20	الجنوب الثالثة
21	البقاع الأولى
22	البقاع الثانية
23	البقاع الثالثة
24	الشمال الأولى
25	الشمال الثانية
26	الشمال الثالثة
27	جبل لبنان الأولى
28	جبل لبنان الثانية
29	جبل لبنان الثالثة
30	جبل لبنان الرابعة
\.


--
-- Data for Name: district_quotas; Type: TABLE DATA; Schema: public; Owner: jkerry
--

COPY district_quotas (district_id, category_id, value) FROM stdin;
1	5	1
1	6	1
1	7	1
1	9	1
1	10	3
1	11	1
2	1	6
2	2	2
2	3	1
2	7	1
2	8	1
3	1	2
4	5	2
4	6	1
5	2	4
6	2	2
6	6	1
7	2	3
8	2	3
9	1	1
9	2	2
9	3	1
9	7	1
10	1	1
10	2	1
10	5	1
10	6	2
10	7	1
10	10	1
11	1	2
11	2	1
11	3	1
11	5	1
11	7	1
13	1	3
13	4	1
13	5	1
13	7	2
12	1	2
12	2	6
12	5	1
12	6	1
14	1	5
14	4	1
14	5	1
14	7	1
15	1	1
16	1	2
17	5	3
18	5	2
19	7	3
20	5	2
21	2	1
21	5	2
22	5	5
23	5	4
23	6	1
23	7	2
23	10	1
24	2	2
24	3	1
24	5	3
25	1	2
25	3	2
25	5	3
25	6	1
26	3	2
26	5	2
26	7	1
\.


--
-- Data for Name: districts; Type: TABLE DATA; Schema: public; Owner: jkerry
--

COPY districts (id, name, constituency_id) FROM stdin;
1	الأشرفية، الرميل، المدور، الصيفي	16
2	رأس بيروت، دار المريسة، ميناء الحصن، زقاق البلاط، المزرعة، المصيطبة، المرفأ، الباشورة	17
3	صيدا	18
4	جزين	18
5	صور	19
6	قرى صيدا (الزهراني)	19
7	بنت جبيل	20
8	النبطية	20
9	مرجعيون وحاصبيا	20
10	زحلة	21
11	راشيا والبقاع الغربي	22
12	بعلبك الهرمل	23
13	عكار	24
14	طرابلس	25
15	المنية	25
16	الضنية	25
17	زغرتا	26
18	بشري	26
19	الكورة	26
20	البترون	26
21	جبيل	27
22	كسروان	27
23	المتن	28
24	بعبدا	29
25	الشوف	30
26	عاليه	30
\.


--
-- Data for Name: electoral_lists; Type: TABLE DATA; Schema: public; Owner: jkerry
--

COPY electoral_lists (id, name, constituency_id) FROM stdin;
\.


--
-- Name: electoral_lists_id_seq; Type: SEQUENCE SET; Schema: public; Owner: jkerry
--

SELECT pg_catalog.setval('electoral_lists_id_seq', 1, false);


--
-- Data for Name: preferential_votes; Type: TABLE DATA; Schema: public; Owner: jkerry
--

COPY preferential_votes (constituency_id, candidate_id, value) FROM stdin;
\.


--
-- Name: smallcircles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: jkerry
--

SELECT pg_catalog.setval('smallcircles_id_seq', 26, true);


--
-- Data for Name: votes_per_list; Type: TABLE DATA; Schema: public; Owner: jkerry
--

COPY votes_per_list (consituency_id, electoral_list_id, value) FROM stdin;
\.


--
-- Name: consituencies bigcircles_pk; Type: CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY consituencies
    ADD CONSTRAINT bigcircles_pk PRIMARY KEY (id);


--
-- Name: candidate_categories candidate_categories_pk; Type: CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY candidate_categories
    ADD CONSTRAINT candidate_categories_pk PRIMARY KEY (id);


--
-- Name: candidates candidates_pk; Type: CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY candidates
    ADD CONSTRAINT candidates_pk PRIMARY KEY (id);


--
-- Name: district_quotas district_quotas_pk; Type: CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY district_quotas
    ADD CONSTRAINT district_quotas_pk PRIMARY KEY (district_id, category_id);


--
-- Name: electoral_lists electoral_lists_pk; Type: CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY electoral_lists
    ADD CONSTRAINT electoral_lists_pk PRIMARY KEY (id);


--
-- Name: preferential_votes preferential_votes_pk; Type: CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY preferential_votes
    ADD CONSTRAINT preferential_votes_pk PRIMARY KEY (constituency_id, candidate_id);


--
-- Name: districts smallcircles_pk; Type: CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY districts
    ADD CONSTRAINT smallcircles_pk PRIMARY KEY (id);


--
-- Name: votes_per_list votes_per_list_un; Type: CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY votes_per_list
    ADD CONSTRAINT votes_per_list_un UNIQUE (consituency_id, electoral_list_id);


--
-- Name: candidates candidates_candidate_categories_FK; Type: FK CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY candidates
    ADD CONSTRAINT "candidates_candidate_categories_FK" FOREIGN KEY (category_id) REFERENCES candidate_categories(id);


--
-- Name: candidates candidates_districts_FK; Type: FK CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY candidates
    ADD CONSTRAINT "candidates_districts_FK" FOREIGN KEY (district_id) REFERENCES districts(id);


--
-- Name: candidates candidates_electoral_lists_FK; Type: FK CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY candidates
    ADD CONSTRAINT "candidates_electoral_lists_FK" FOREIGN KEY (electoral_list_id) REFERENCES electoral_lists(id);


--
-- Name: district_quotas district_quotas_candidate_categories_FK; Type: FK CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY district_quotas
    ADD CONSTRAINT "district_quotas_candidate_categories_FK" FOREIGN KEY (category_id) REFERENCES candidate_categories(id);


--
-- Name: district_quotas district_quotas_districts_FK; Type: FK CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY district_quotas
    ADD CONSTRAINT "district_quotas_districts_FK" FOREIGN KEY (district_id) REFERENCES districts(id);


--
-- Name: districts districts_consituencies_FK; Type: FK CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY districts
    ADD CONSTRAINT "districts_consituencies_FK" FOREIGN KEY (constituency_id) REFERENCES consituencies(id);


--
-- Name: preferential_votes preferential_votes_candidates_FK; Type: FK CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY preferential_votes
    ADD CONSTRAINT "preferential_votes_candidates_FK" FOREIGN KEY (candidate_id) REFERENCES candidates(id);


--
-- Name: preferential_votes preferential_votes_consituencies_FK; Type: FK CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY preferential_votes
    ADD CONSTRAINT "preferential_votes_consituencies_FK" FOREIGN KEY (constituency_id) REFERENCES consituencies(id);


--
-- Name: votes_per_list votes_per_list_consituencies_FK; Type: FK CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY votes_per_list
    ADD CONSTRAINT "votes_per_list_consituencies_FK" FOREIGN KEY (consituency_id) REFERENCES consituencies(id);


--
-- Name: votes_per_list votes_per_list_electoral_lists_FK; Type: FK CONSTRAINT; Schema: public; Owner: jkerry
--

ALTER TABLE ONLY votes_per_list
    ADD CONSTRAINT "votes_per_list_electoral_lists_FK" FOREIGN KEY (electoral_list_id) REFERENCES electoral_lists(id);


--
-- PostgreSQL database dump complete
--

