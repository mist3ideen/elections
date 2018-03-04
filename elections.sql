--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.7
-- Dumped by pg_dump version 9.6.7

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: simulation; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA simulation;


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: constituencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE constituencies (
    id integer NOT NULL,
    name character varying NOT NULL
);


--
-- Name: bigcircles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE bigcircles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bigcircles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE bigcircles_id_seq OWNED BY constituencies.id;


--
-- Name: candidate_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE candidate_categories (
    id integer NOT NULL,
    name character varying NOT NULL
);


--
-- Name: candidate_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE candidate_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: candidate_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE candidate_categories_id_seq OWNED BY candidate_categories.id;


--
-- Name: candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE candidates (
    id integer NOT NULL,
    name character varying NOT NULL,
    district_id integer NOT NULL,
    electoral_list_id integer NOT NULL,
    category_id integer NOT NULL
);


--
-- Name: candidates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE candidates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: candidates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE candidates_id_seq OWNED BY candidates.id;


--
-- Name: district_quotas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE district_quotas (
    district_id integer NOT NULL,
    category_id integer NOT NULL,
    value integer NOT NULL
);


--
-- Name: districts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE districts (
    id integer NOT NULL,
    name character varying NOT NULL,
    constituency_id integer NOT NULL
);


--
-- Name: constituency_list_size; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW constituency_list_size AS
 SELECT c.id AS constituency_id,
    sum(COALESCE(dq.value, 0)) AS list_size
   FROM (((districts d
     CROSS JOIN candidate_categories cc)
     JOIN constituencies c ON ((c.id = d.constituency_id)))
     JOIN ( SELECT d1.id AS district_id,
            cc1.id AS category_id,
            COALESCE(dq1.value, 0) AS value
           FROM ((districts d1
             CROSS JOIN candidate_categories cc1)
             LEFT JOIN district_quotas dq1 ON (((dq1.category_id = cc1.id) AND (dq1.district_id = d1.id))))) dq ON (((dq.category_id = cc.id) AND (dq.district_id = d.id))))
  GROUP BY c.id, c.name
  ORDER BY c.id;


--
-- Name: constituency_quota_list; Type: VIEW; Schema: public; Owner: -
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
     JOIN constituencies c ON ((c.id = d.constituency_id)))
     JOIN ( SELECT d1.id AS district_id,
            cc1.id AS category_id,
            COALESCE(dq1.value, 0) AS value
           FROM ((districts d1
             CROSS JOIN candidate_categories cc1)
             LEFT JOIN district_quotas dq1 ON (((dq1.category_id = cc1.id) AND (dq1.district_id = d1.id))))) dq ON (((dq.category_id = cc.id) AND (dq.district_id = d.id))))
  GROUP BY c.id, c.name, d.id, d.name
  ORDER BY c.id, d.id);


--
-- Name: votes_per_list; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE votes_per_list (
    constituency_id integer NOT NULL,
    electoral_list_id integer,
    value integer NOT NULL
);


--
-- Name: constituency_total_votes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW constituency_total_votes AS
 SELECT vpl.constituency_id,
    sum(vpl.value) AS total_votes
   FROM votes_per_list vpl
  GROUP BY vpl.constituency_id;


--
-- Name: electoral_lists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE electoral_lists (
    id integer NOT NULL,
    name character varying NOT NULL,
    constituency_id integer NOT NULL
);


--
-- Name: electoral_lists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE electoral_lists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: electoral_lists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE electoral_lists_id_seq OWNED BY electoral_lists.id;


--
-- Name: preferential_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE preferential_votes (
    constituency_id integer NOT NULL,
    candidate_id integer NOT NULL,
    value integer NOT NULL
);


--
-- Name: results_constituency_threshold; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW results_constituency_threshold AS
 SELECT ctv.constituency_id,
    ((1.0 * (ctv.total_votes)::numeric) / (cls.list_size)::numeric) AS list_threshold
   FROM (constituency_list_size cls
     JOIN constituency_total_votes ctv ON ((ctv.constituency_id = cls.constituency_id)));


--
-- Name: results_constituency_total_votes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW results_constituency_total_votes AS
 SELECT vpl.constituency_id,
    sum(vpl.value) AS total_votes
   FROM (votes_per_list vpl
     JOIN results_constituency_threshold rct ON ((rct.constituency_id = vpl.constituency_id)))
  WHERE ((vpl.value)::numeric > rct.list_threshold)
  GROUP BY vpl.constituency_id;


--
-- Name: results_list_allocations; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW results_list_allocations AS
 SELECT vpl.constituency_id,
    vpl.electoral_list_id,
    vpl.value,
    ((100.0 * (vpl.value)::numeric) / (ctv.total_votes)::numeric) AS votes_percentage_pre,
    ((vpl.value)::numeric > rct.list_threshold) AS passed_threshold,
    ((100.0 * (vpl.value)::numeric) / (rctv.total_votes)::numeric) AS votes_percentage_post,
    (((1.0 * (vpl.value)::numeric) / (rctv.total_votes)::numeric) * (cls.list_size)::numeric) AS allocated_seats,
    cls.list_size
   FROM ((((votes_per_list vpl
     JOIN constituency_total_votes ctv ON ((ctv.constituency_id = vpl.constituency_id)))
     JOIN results_constituency_threshold rct ON ((rct.constituency_id = vpl.constituency_id)))
     JOIN constituency_list_size cls ON ((cls.constituency_id = vpl.constituency_id)))
     JOIN results_constituency_total_votes rctv ON ((rctv.constituency_id = vpl.constituency_id)))
  ORDER BY vpl.value DESC;


--
-- Name: results_adjusted_list_allocations; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW results_adjusted_list_allocations AS
 WITH RECURSIVE rt(iteration, constituency_id, electoral_list_id, list_size, votes_percentage_post, data_a, data_b, data_c, data_d) AS (
         SELECT (0)::bigint AS int8,
            results_list_allocations.constituency_id,
            results_list_allocations.electoral_list_id,
            results_list_allocations.list_size,
            results_list_allocations.votes_percentage_post,
            floor(results_list_allocations.allocated_seats) AS floor,
            ((results_list_allocations.allocated_seats - floor(results_list_allocations.allocated_seats)) * (10)::numeric),
            results_list_allocations.votes_percentage_post,
            ((results_list_allocations.list_size)::numeric - sum(floor(results_list_allocations.allocated_seats)) OVER (PARTITION BY results_list_allocations.constituency_id ORDER BY results_list_allocations.votes_percentage_post DESC))
           FROM results_list_allocations
          WHERE (results_list_allocations.passed_threshold = true)
        UNION ALL
         SELECT (rt.iteration + 1),
            rt.constituency_id,
            rt.electoral_list_id,
            rt.list_size,
            rt.votes_percentage_post,
            floor(rt.data_b) AS floor,
            ((rt.data_b - floor(rt.data_b)) * (10)::numeric),
            0,
            (min(rt.data_d) OVER (PARTITION BY rt.constituency_id) - sum(floor(rt.data_b)) OVER (PARTITION BY rt.constituency_id ORDER BY rt.data_b DESC))
           FROM rt
          WHERE (rt.data_d > (0)::numeric)
        ), rt2 AS (
         SELECT rt.constituency_id,
            rt.electoral_list_id,
            rt.list_size,
            rt.data_d,
            (COALESCE(lag(rt.data_d) OVER (PARTITION BY rt.constituency_id ORDER BY rt.iteration, rt.data_a DESC), (rt.list_size)::numeric) - GREATEST(rt.data_d, (0)::numeric)) AS data_e
           FROM rt
        )
 SELECT rt2.constituency_id,
    rt2.electoral_list_id,
    sum(rt2.data_e) AS allocated_seats
   FROM rt2
  WHERE (rt2.data_e > (0)::numeric)
  GROUP BY rt2.constituency_id, rt2.electoral_list_id;


--
-- Name: results_total_preferential_votes; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW results_total_preferential_votes AS
 SELECT d.id AS district_id,
    sum(pv.value) AS total_votes
   FROM (((preferential_votes pv
     JOIN candidates ca ON ((ca.id = pv.candidate_id)))
     JOIN districts d ON ((d.id = ca.district_id)))
     JOIN results_list_allocations rla ON (((rla.passed_threshold = true) AND (rla.constituency_id = d.constituency_id) AND (ca.electoral_list_id = rla.electoral_list_id))))
  GROUP BY d.id;


--
-- Name: results_sorted_preferential_list; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW results_sorted_preferential_list AS
 SELECT rank() OVER (ORDER BY ((100.0 * (pv.value)::numeric) / (rtpv.total_votes)::numeric) DESC) AS rowno,
    co.id AS constituency_id,
    d.id AS district_id,
    ca.id AS candidate_id,
    ca.category_id,
    ca.electoral_list_id,
    COALESCE(dq.value, 0) AS district_category_quota,
    (rla.allocated_seats)::integer AS allocated_seats,
    ((100.0 * (pv.value)::numeric) / (rtpv.total_votes)::numeric) AS preferential_percentage
   FROM ((((((candidates ca
     JOIN districts d ON ((d.id = ca.district_id)))
     JOIN constituencies co ON ((co.id = d.constituency_id)))
     JOIN preferential_votes pv ON ((pv.candidate_id = ca.id)))
     JOIN results_total_preferential_votes rtpv ON ((rtpv.district_id = d.id)))
     LEFT JOIN district_quotas dq ON (((dq.category_id = ca.category_id) AND (dq.district_id = ca.district_id))))
     JOIN results_adjusted_list_allocations rla ON ((rla.electoral_list_id = ca.electoral_list_id)))
  ORDER BY ((100.0 * (pv.value)::numeric) / (rtpv.total_votes)::numeric) DESC;


--
-- Name: results_preferential; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW results_preferential AS
 WITH RECURSIVE allocations(iteration, rowno, constituency_id, district_id, candidate_id, category_id, electoral_list_id, district_category_quota, allocated_seats, preferential_percentage, data_a, data_b, data_c, debug_d) AS (
        ( SELECT (0)::bigint AS int8,
            results_sorted_preferential_list.rowno,
            results_sorted_preferential_list.constituency_id,
            results_sorted_preferential_list.district_id,
            results_sorted_preferential_list.candidate_id,
            results_sorted_preferential_list.category_id,
            results_sorted_preferential_list.electoral_list_id,
            results_sorted_preferential_list.district_category_quota,
            results_sorted_preferential_list.allocated_seats,
            results_sorted_preferential_list.preferential_percentage,
            (LEAST((results_sorted_preferential_list.district_category_quota - 0), (results_sorted_preferential_list.allocated_seats - 0)) > 0) AS data_a,
            (0 + ((LEAST((results_sorted_preferential_list.district_category_quota - 0), (results_sorted_preferential_list.allocated_seats - 0)) > 0))::integer) AS data_b,
            (0 + ((LEAST((results_sorted_preferential_list.district_category_quota - 0), (results_sorted_preferential_list.allocated_seats - 0)) > 0))::integer) AS data_c,
            (0)::bigint AS debug_d
           FROM results_sorted_preferential_list
         LIMIT 1)
        UNION ALL
         SELECT (allocations.iteration + 1),
            rspl.rowno,
                CASE
                    WHEN (allocations.rowno = rspl.rowno) THEN allocations.constituency_id
                    ELSE rspl.constituency_id
                END AS constituency_id,
                CASE
                    WHEN (allocations.rowno = rspl.rowno) THEN allocations.district_id
                    ELSE rspl.district_id
                END AS district_id,
                CASE
                    WHEN (allocations.rowno = rspl.rowno) THEN allocations.candidate_id
                    ELSE rspl.candidate_id
                END AS candidate_id,
                CASE
                    WHEN (allocations.rowno = rspl.rowno) THEN allocations.category_id
                    ELSE rspl.category_id
                END AS category_id,
                CASE
                    WHEN (allocations.rowno = rspl.rowno) THEN allocations.electoral_list_id
                    ELSE rspl.electoral_list_id
                END AS electoral_list_id,
                CASE
                    WHEN (allocations.rowno = rspl.rowno) THEN allocations.district_category_quota
                    ELSE rspl.district_category_quota
                END AS district_category_quota,
                CASE
                    WHEN (allocations.rowno = rspl.rowno) THEN allocations.allocated_seats
                    ELSE rspl.allocated_seats
                END AS allocated_seats,
                CASE
                    WHEN (allocations.rowno = rspl.rowno) THEN allocations.preferential_percentage
                    ELSE rspl.preferential_percentage
                END AS preferential_percentage,
                CASE
                    WHEN (allocations.rowno = rspl.rowno) THEN allocations.data_a
                    ELSE (LEAST((rspl.district_category_quota - lag(allocations.data_b, 1, 0) OVER (PARTITION BY rspl.constituency_id, rspl.district_id, rspl.category_id ORDER BY rspl.preferential_percentage DESC)), (rspl.allocated_seats - lag(allocations.data_c, 1, 0) OVER (PARTITION BY rspl.constituency_id, rspl.electoral_list_id ORDER BY rspl.preferential_percentage DESC))) > 0)
                END AS data_a,
                CASE
                    WHEN (allocations.rowno = rspl.rowno) THEN allocations.data_b
                    ELSE (lag(allocations.data_b, 1, 0) OVER (PARTITION BY rspl.constituency_id, rspl.district_id, rspl.category_id ORDER BY rspl.preferential_percentage DESC) + ((LEAST((rspl.district_category_quota - lag(allocations.data_b, 1, 0) OVER (PARTITION BY rspl.constituency_id, rspl.district_id, rspl.category_id ORDER BY rspl.preferential_percentage DESC)), (rspl.allocated_seats - lag(allocations.data_c, 1, 0) OVER (PARTITION BY rspl.constituency_id, rspl.electoral_list_id ORDER BY rspl.preferential_percentage DESC))) > 0))::integer)
                END AS data_b,
                CASE
                    WHEN (allocations.rowno = rspl.rowno) THEN allocations.data_c
                    ELSE (lag(allocations.data_c, 1, 0) OVER (PARTITION BY rspl.constituency_id, rspl.electoral_list_id ORDER BY rspl.preferential_percentage DESC) + ((LEAST((rspl.district_category_quota - lag(allocations.data_b, 1, 0) OVER (PARTITION BY rspl.constituency_id, rspl.district_id, rspl.category_id ORDER BY rspl.preferential_percentage DESC)), (rspl.allocated_seats - lag(allocations.data_c, 1, 0) OVER (PARTITION BY rspl.constituency_id, rspl.electoral_list_id ORDER BY rspl.preferential_percentage DESC))) > 0))::integer)
                END AS data_c,
            lag(allocations.data_b, 1, 0) OVER (PARTITION BY rspl.constituency_id, rspl.district_id, rspl.category_id ORDER BY rspl.preferential_percentage DESC) AS debug_d
           FROM (allocations
             LEFT JOIN results_sorted_preferential_list rspl ON (((rspl.rowno = allocations.rowno) OR ((rspl.rowno = (allocations.iteration + 2)) AND (rspl.rowno = (allocations.rowno + 1))))))
        ), ayret AS (
         SELECT allocations.iteration,
            allocations.rowno,
            allocations.constituency_id,
            allocations.district_id,
            allocations.candidate_id,
            allocations.category_id,
            allocations.electoral_list_id,
            allocations.district_category_quota,
            allocations.allocated_seats,
            allocations.preferential_percentage,
            allocations.data_a,
            allocations.data_b,
            allocations.data_c,
            allocations.debug_d
           FROM allocations
         LIMIT 1000
        )
 SELECT a.constituency_id,
    a.district_id,
    a.candidate_id,
    a.category_id,
    a.electoral_list_id,
    a.preferential_percentage
   FROM ayret a
  WHERE ((a.data_a IS TRUE) AND (a.iteration = ( SELECT (max(ayret.iteration) - 1) AS max_iteration
           FROM ayret)))
  ORDER BY a.rowno;


--
-- Name: results_preferential_illustrated; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW results_preferential_illustrated AS
 SELECT rspl.rowno,
    rspl.constituency_id,
    rspl.district_id,
    rspl.candidate_id,
    rspl.category_id,
    rspl.electoral_list_id,
    rspl.district_category_quota,
    rspl.allocated_seats,
    rspl.preferential_percentage,
    (rp.candidate_id IS NOT NULL) AS winning
   FROM (results_sorted_preferential_list rspl
     LEFT JOIN results_preferential rp ON ((rp.candidate_id = rspl.candidate_id)));


--
-- Name: smallcircles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE smallcircles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: smallcircles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE smallcircles_id_seq OWNED BY districts.id;


SET search_path = simulation, pg_catalog;

--
-- Name: simulations; Type: TABLE; Schema: simulation; Owner: -
--

CREATE TABLE simulations (
    id integer NOT NULL,
    schema_name character varying NOT NULL
);


--
-- Name: simulations_id_seq; Type: SEQUENCE; Schema: simulation; Owner: -
--

CREATE SEQUENCE simulations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: simulations_id_seq; Type: SEQUENCE OWNED BY; Schema: simulation; Owner: -
--

ALTER SEQUENCE simulations_id_seq OWNED BY simulations.id;


SET search_path = public, pg_catalog;

--
-- Name: candidate_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY candidate_categories ALTER COLUMN id SET DEFAULT nextval('candidate_categories_id_seq'::regclass);


--
-- Name: candidates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY candidates ALTER COLUMN id SET DEFAULT nextval('candidates_id_seq'::regclass);


--
-- Name: constituencies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY constituencies ALTER COLUMN id SET DEFAULT nextval('bigcircles_id_seq'::regclass);


--
-- Name: districts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY districts ALTER COLUMN id SET DEFAULT nextval('smallcircles_id_seq'::regclass);


--
-- Name: electoral_lists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY electoral_lists ALTER COLUMN id SET DEFAULT nextval('electoral_lists_id_seq'::regclass);


SET search_path = simulation, pg_catalog;

--
-- Name: simulations id; Type: DEFAULT; Schema: simulation; Owner: -
--

ALTER TABLE ONLY simulations ALTER COLUMN id SET DEFAULT nextval('simulations_id_seq'::regclass);


SET search_path = public, pg_catalog;

--
-- Name: bigcircles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('bigcircles_id_seq', 30, true);


--
-- Data for Name: candidate_categories; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO candidate_categories VALUES (1, 'سني');
INSERT INTO candidate_categories VALUES (2, 'شيعي');
INSERT INTO candidate_categories VALUES (3, 'درزي');
INSERT INTO candidate_categories VALUES (4, 'علوي');
INSERT INTO candidate_categories VALUES (5, 'ماروني');
INSERT INTO candidate_categories VALUES (6, 'روم كاثوليك');
INSERT INTO candidate_categories VALUES (7, 'روم ارثوذكس');
INSERT INTO candidate_categories VALUES (8, 'انجيلي');
INSERT INTO candidate_categories VALUES (9, 'أرمن كاثوليك');
INSERT INTO candidate_categories VALUES (10, 'أرمن ارثوذكس');
INSERT INTO candidate_categories VALUES (11, 'أقليات');


--
-- Name: candidate_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('candidate_categories_id_seq', 11, true);


--
-- Data for Name: candidates; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO candidates VALUES (1, 'A1', 1, 1, 5);
INSERT INTO candidates VALUES (2, 'A2', 1, 1, 6);
INSERT INTO candidates VALUES (3, 'A3', 1, 1, 7);
INSERT INTO candidates VALUES (4, 'A4', 1, 1, 9);
INSERT INTO candidates VALUES (5, 'A5', 1, 1, 10);
INSERT INTO candidates VALUES (6, 'A6', 1, 1, 10);
INSERT INTO candidates VALUES (7, 'A7', 1, 1, 10);
INSERT INTO candidates VALUES (8, 'A8', 1, 1, 11);
INSERT INTO candidates VALUES (9, 'B1', 1, 2, 5);
INSERT INTO candidates VALUES (10, 'B2', 1, 2, 6);
INSERT INTO candidates VALUES (11, 'B3', 1, 2, 7);
INSERT INTO candidates VALUES (12, 'B4', 1, 2, 9);
INSERT INTO candidates VALUES (13, 'B5', 1, 2, 10);
INSERT INTO candidates VALUES (14, 'B6', 1, 2, 10);
INSERT INTO candidates VALUES (15, 'B7', 1, 2, 10);
INSERT INTO candidates VALUES (16, 'B8', 1, 2, 11);
INSERT INTO candidates VALUES (17, 'C1', 1, 3, 5);
INSERT INTO candidates VALUES (18, 'C2', 1, 3, 6);
INSERT INTO candidates VALUES (19, 'C3', 1, 3, 7);
INSERT INTO candidates VALUES (20, 'C4', 1, 3, 9);
INSERT INTO candidates VALUES (21, 'C5', 1, 3, 10);
INSERT INTO candidates VALUES (22, 'C6', 1, 3, 10);
INSERT INTO candidates VALUES (23, 'C7', 1, 3, 10);
INSERT INTO candidates VALUES (24, 'C8', 1, 3, 11);
INSERT INTO candidates VALUES (25, 'D1', 1, 4, 5);
INSERT INTO candidates VALUES (26, 'D2', 1, 4, 6);
INSERT INTO candidates VALUES (27, 'D3', 1, 4, 7);
INSERT INTO candidates VALUES (28, 'D4', 1, 4, 9);
INSERT INTO candidates VALUES (29, 'D5', 1, 4, 10);
INSERT INTO candidates VALUES (30, 'D6', 1, 4, 10);
INSERT INTO candidates VALUES (31, 'D7', 1, 4, 10);
INSERT INTO candidates VALUES (32, 'D8', 1, 4, 11);


--
-- Name: candidates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('candidates_id_seq', 32, true);


--
-- Data for Name: constituencies; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO constituencies VALUES (16, 'بيروت الاولى');
INSERT INTO constituencies VALUES (17, 'بيروت الثانية');
INSERT INTO constituencies VALUES (18, 'الجنوب الاولى');
INSERT INTO constituencies VALUES (19, 'الجنوب الثانية');
INSERT INTO constituencies VALUES (20, 'الجنوب الثالثة');
INSERT INTO constituencies VALUES (21, 'البقاع الأولى');
INSERT INTO constituencies VALUES (22, 'البقاع الثانية');
INSERT INTO constituencies VALUES (23, 'البقاع الثالثة');
INSERT INTO constituencies VALUES (24, 'الشمال الأولى');
INSERT INTO constituencies VALUES (25, 'الشمال الثانية');
INSERT INTO constituencies VALUES (26, 'الشمال الثالثة');
INSERT INTO constituencies VALUES (27, 'جبل لبنان الأولى');
INSERT INTO constituencies VALUES (28, 'جبل لبنان الثانية');
INSERT INTO constituencies VALUES (29, 'جبل لبنان الثالثة');
INSERT INTO constituencies VALUES (30, 'جبل لبنان الرابعة');


--
-- Data for Name: district_quotas; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO district_quotas VALUES (1, 5, 1);
INSERT INTO district_quotas VALUES (1, 6, 1);
INSERT INTO district_quotas VALUES (1, 7, 1);
INSERT INTO district_quotas VALUES (1, 9, 1);
INSERT INTO district_quotas VALUES (1, 10, 3);
INSERT INTO district_quotas VALUES (1, 11, 1);
INSERT INTO district_quotas VALUES (2, 1, 6);
INSERT INTO district_quotas VALUES (2, 2, 2);
INSERT INTO district_quotas VALUES (2, 3, 1);
INSERT INTO district_quotas VALUES (2, 7, 1);
INSERT INTO district_quotas VALUES (2, 8, 1);
INSERT INTO district_quotas VALUES (3, 1, 2);
INSERT INTO district_quotas VALUES (4, 5, 2);
INSERT INTO district_quotas VALUES (4, 6, 1);
INSERT INTO district_quotas VALUES (5, 2, 4);
INSERT INTO district_quotas VALUES (6, 2, 2);
INSERT INTO district_quotas VALUES (6, 6, 1);
INSERT INTO district_quotas VALUES (7, 2, 3);
INSERT INTO district_quotas VALUES (8, 2, 3);
INSERT INTO district_quotas VALUES (9, 1, 1);
INSERT INTO district_quotas VALUES (9, 2, 2);
INSERT INTO district_quotas VALUES (9, 3, 1);
INSERT INTO district_quotas VALUES (9, 7, 1);
INSERT INTO district_quotas VALUES (10, 1, 1);
INSERT INTO district_quotas VALUES (10, 2, 1);
INSERT INTO district_quotas VALUES (10, 5, 1);
INSERT INTO district_quotas VALUES (10, 6, 2);
INSERT INTO district_quotas VALUES (10, 7, 1);
INSERT INTO district_quotas VALUES (10, 10, 1);
INSERT INTO district_quotas VALUES (11, 1, 2);
INSERT INTO district_quotas VALUES (11, 2, 1);
INSERT INTO district_quotas VALUES (11, 3, 1);
INSERT INTO district_quotas VALUES (11, 5, 1);
INSERT INTO district_quotas VALUES (11, 7, 1);
INSERT INTO district_quotas VALUES (13, 1, 3);
INSERT INTO district_quotas VALUES (13, 4, 1);
INSERT INTO district_quotas VALUES (13, 5, 1);
INSERT INTO district_quotas VALUES (13, 7, 2);
INSERT INTO district_quotas VALUES (12, 1, 2);
INSERT INTO district_quotas VALUES (12, 2, 6);
INSERT INTO district_quotas VALUES (12, 5, 1);
INSERT INTO district_quotas VALUES (12, 6, 1);
INSERT INTO district_quotas VALUES (14, 1, 5);
INSERT INTO district_quotas VALUES (14, 4, 1);
INSERT INTO district_quotas VALUES (14, 5, 1);
INSERT INTO district_quotas VALUES (14, 7, 1);
INSERT INTO district_quotas VALUES (15, 1, 1);
INSERT INTO district_quotas VALUES (16, 1, 2);
INSERT INTO district_quotas VALUES (17, 5, 3);
INSERT INTO district_quotas VALUES (18, 5, 2);
INSERT INTO district_quotas VALUES (19, 7, 3);
INSERT INTO district_quotas VALUES (20, 5, 2);
INSERT INTO district_quotas VALUES (21, 2, 1);
INSERT INTO district_quotas VALUES (21, 5, 2);
INSERT INTO district_quotas VALUES (22, 5, 5);
INSERT INTO district_quotas VALUES (23, 5, 4);
INSERT INTO district_quotas VALUES (23, 6, 1);
INSERT INTO district_quotas VALUES (23, 7, 2);
INSERT INTO district_quotas VALUES (23, 10, 1);
INSERT INTO district_quotas VALUES (24, 2, 2);
INSERT INTO district_quotas VALUES (24, 3, 1);
INSERT INTO district_quotas VALUES (24, 5, 3);
INSERT INTO district_quotas VALUES (25, 1, 2);
INSERT INTO district_quotas VALUES (25, 3, 2);
INSERT INTO district_quotas VALUES (25, 5, 3);
INSERT INTO district_quotas VALUES (25, 6, 1);
INSERT INTO district_quotas VALUES (26, 3, 2);
INSERT INTO district_quotas VALUES (26, 5, 2);
INSERT INTO district_quotas VALUES (26, 7, 1);


--
-- Data for Name: districts; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO districts VALUES (1, 'الأشرفية، الرميل، المدور، الصيفي', 16);
INSERT INTO districts VALUES (2, 'رأس بيروت، دار المريسة، ميناء الحصن، زقاق البلاط، المزرعة، المصيطبة، المرفأ، الباشورة', 17);
INSERT INTO districts VALUES (3, 'صيدا', 18);
INSERT INTO districts VALUES (4, 'جزين', 18);
INSERT INTO districts VALUES (5, 'صور', 19);
INSERT INTO districts VALUES (6, 'قرى صيدا (الزهراني)', 19);
INSERT INTO districts VALUES (7, 'بنت جبيل', 20);
INSERT INTO districts VALUES (8, 'النبطية', 20);
INSERT INTO districts VALUES (9, 'مرجعيون وحاصبيا', 20);
INSERT INTO districts VALUES (10, 'زحلة', 21);
INSERT INTO districts VALUES (11, 'راشيا والبقاع الغربي', 22);
INSERT INTO districts VALUES (12, 'بعلبك الهرمل', 23);
INSERT INTO districts VALUES (13, 'عكار', 24);
INSERT INTO districts VALUES (14, 'طرابلس', 25);
INSERT INTO districts VALUES (15, 'المنية', 25);
INSERT INTO districts VALUES (16, 'الضنية', 25);
INSERT INTO districts VALUES (17, 'زغرتا', 26);
INSERT INTO districts VALUES (18, 'بشري', 26);
INSERT INTO districts VALUES (19, 'الكورة', 26);
INSERT INTO districts VALUES (20, 'البترون', 26);
INSERT INTO districts VALUES (21, 'جبيل', 27);
INSERT INTO districts VALUES (22, 'كسروان', 27);
INSERT INTO districts VALUES (23, 'المتن', 28);
INSERT INTO districts VALUES (24, 'بعبدا', 29);
INSERT INTO districts VALUES (25, 'الشوف', 30);
INSERT INTO districts VALUES (26, 'عاليه', 30);


--
-- Data for Name: electoral_lists; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO electoral_lists VALUES (1, 'List A', 16);
INSERT INTO electoral_lists VALUES (2, 'List B', 16);
INSERT INTO electoral_lists VALUES (3, 'List C', 16);
INSERT INTO electoral_lists VALUES (4, 'List D', 16);


--
-- Name: electoral_lists_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('electoral_lists_id_seq', 4, true);


--
-- Data for Name: preferential_votes; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO preferential_votes VALUES (16, 1, 41);
INSERT INTO preferential_votes VALUES (16, 2, 97);
INSERT INTO preferential_votes VALUES (16, 3, 388);
INSERT INTO preferential_votes VALUES (16, 4, 318);
INSERT INTO preferential_votes VALUES (16, 5, 468);
INSERT INTO preferential_votes VALUES (16, 6, 204);
INSERT INTO preferential_votes VALUES (16, 7, 232);
INSERT INTO preferential_votes VALUES (16, 8, 264);
INSERT INTO preferential_votes VALUES (16, 9, 142);
INSERT INTO preferential_votes VALUES (16, 10, 512);
INSERT INTO preferential_votes VALUES (16, 11, 294);
INSERT INTO preferential_votes VALUES (16, 12, 419);
INSERT INTO preferential_votes VALUES (16, 13, 443);
INSERT INTO preferential_votes VALUES (16, 14, 489);
INSERT INTO preferential_votes VALUES (16, 15, 444);
INSERT INTO preferential_votes VALUES (16, 16, 480);
INSERT INTO preferential_votes VALUES (16, 17, 369);
INSERT INTO preferential_votes VALUES (16, 18, 392);
INSERT INTO preferential_votes VALUES (16, 19, 159);
INSERT INTO preferential_votes VALUES (16, 20, 376);
INSERT INTO preferential_votes VALUES (16, 21, 63);
INSERT INTO preferential_votes VALUES (16, 22, 110);
INSERT INTO preferential_votes VALUES (16, 23, 446);
INSERT INTO preferential_votes VALUES (16, 24, 511);
INSERT INTO preferential_votes VALUES (16, 25, 124);
INSERT INTO preferential_votes VALUES (16, 26, 81);
INSERT INTO preferential_votes VALUES (16, 27, 501);
INSERT INTO preferential_votes VALUES (16, 28, 491);
INSERT INTO preferential_votes VALUES (16, 29, 337);
INSERT INTO preferential_votes VALUES (16, 30, 339);
INSERT INTO preferential_votes VALUES (16, 31, 91);
INSERT INTO preferential_votes VALUES (16, 32, 368);


--
-- Name: smallcircles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('smallcircles_id_seq', 26, true);


--
-- Data for Name: votes_per_list; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO votes_per_list VALUES (16, 1, 10000);
INSERT INTO votes_per_list VALUES (16, 2, 15000);
INSERT INTO votes_per_list VALUES (16, 3, 1000);
INSERT INTO votes_per_list VALUES (16, 4, 30000);


SET search_path = simulation, pg_catalog;

--
-- Data for Name: simulations; Type: TABLE DATA; Schema: simulation; Owner: -
--

INSERT INTO simulations VALUES (2, 'public');


--
-- Name: simulations_id_seq; Type: SEQUENCE SET; Schema: simulation; Owner: -
--

SELECT pg_catalog.setval('simulations_id_seq', 2, true);


SET search_path = public, pg_catalog;

--
-- Name: constituencies bigcircles_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY constituencies
    ADD CONSTRAINT bigcircles_pk PRIMARY KEY (id);


--
-- Name: candidate_categories candidate_categories_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY candidate_categories
    ADD CONSTRAINT candidate_categories_pk PRIMARY KEY (id);


--
-- Name: candidates candidates_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY candidates
    ADD CONSTRAINT candidates_pk PRIMARY KEY (id);


--
-- Name: district_quotas district_quotas_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY district_quotas
    ADD CONSTRAINT district_quotas_pk PRIMARY KEY (district_id, category_id);


--
-- Name: electoral_lists electoral_lists_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY electoral_lists
    ADD CONSTRAINT electoral_lists_pk PRIMARY KEY (id);


--
-- Name: preferential_votes preferential_votes_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY preferential_votes
    ADD CONSTRAINT preferential_votes_pk PRIMARY KEY (constituency_id, candidate_id);


--
-- Name: districts smallcircles_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY districts
    ADD CONSTRAINT smallcircles_pk PRIMARY KEY (id);


--
-- Name: votes_per_list votes_per_list_un; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY votes_per_list
    ADD CONSTRAINT votes_per_list_un UNIQUE (constituency_id, electoral_list_id);


SET search_path = simulation, pg_catalog;

--
-- Name: simulations simulations_pkey; Type: CONSTRAINT; Schema: simulation; Owner: -
--

ALTER TABLE ONLY simulations
    ADD CONSTRAINT simulations_pkey PRIMARY KEY (id);


SET search_path = public, pg_catalog;

--
-- Name: candidates candidates_candidate_categories_FK; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY candidates
    ADD CONSTRAINT "candidates_candidate_categories_FK" FOREIGN KEY (category_id) REFERENCES candidate_categories(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: candidates candidates_districts_FK; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY candidates
    ADD CONSTRAINT "candidates_districts_FK" FOREIGN KEY (district_id) REFERENCES districts(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: candidates candidates_electoral_lists_FK; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY candidates
    ADD CONSTRAINT "candidates_electoral_lists_FK" FOREIGN KEY (electoral_list_id) REFERENCES electoral_lists(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: district_quotas district_quotas_candidate_categories_FK; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY district_quotas
    ADD CONSTRAINT "district_quotas_candidate_categories_FK" FOREIGN KEY (category_id) REFERENCES candidate_categories(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: district_quotas district_quotas_districts_FK; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY district_quotas
    ADD CONSTRAINT "district_quotas_districts_FK" FOREIGN KEY (district_id) REFERENCES districts(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: districts districts_consituencies_FK; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY districts
    ADD CONSTRAINT "districts_consituencies_FK" FOREIGN KEY (constituency_id) REFERENCES constituencies(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: electoral_lists electoral_lists_consituencies_FK; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY electoral_lists
    ADD CONSTRAINT "electoral_lists_consituencies_FK" FOREIGN KEY (constituency_id) REFERENCES constituencies(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: preferential_votes preferential_votes_candidates_FK; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY preferential_votes
    ADD CONSTRAINT "preferential_votes_candidates_FK" FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: preferential_votes preferential_votes_consituencies_FK; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY preferential_votes
    ADD CONSTRAINT "preferential_votes_consituencies_FK" FOREIGN KEY (constituency_id) REFERENCES constituencies(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: votes_per_list votes_per_list_consituencies_FK; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY votes_per_list
    ADD CONSTRAINT "votes_per_list_consituencies_FK" FOREIGN KEY (constituency_id) REFERENCES constituencies(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: votes_per_list votes_per_list_electoral_lists_FK; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY votes_per_list
    ADD CONSTRAINT "votes_per_list_electoral_lists_FK" FOREIGN KEY (electoral_list_id) REFERENCES electoral_lists(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

