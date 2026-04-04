--
-- PostgreSQL database dump
--

\restrict ZidQ6CwJUTkMcas6wgBhhf3uDpif4iwgRT75nV02TbaLWmmGIvYXRR6Q5h1QzvB

-- Dumped from database version 18.2 (94b8da0)
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_table_access_method = heap;

--
-- Name: avg_mortgage_rate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.avg_mortgage_rate (
    date date NOT NULL,
    floating double precision,
    _6_months double precision,
    _1_year double precision,
    _18_months double precision,
    _2_years double precision,
    _3_years double precision,
    _4_years double precision,
    _5_years double precision
);


--
-- Name: ins_mortgage_rate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ins_mortgage_rate (
    date date DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'Pacific/Auckland'::text) CONSTRAINT "ins_mortgage_rate_Date_not_null" NOT NULL,
    bank character varying(32) CONSTRAINT "ins_mortgage_rate_Bank_not_null" NOT NULL,
    product character varying(32) CONSTRAINT "ins_mortgage_rate_Product_not_null" NOT NULL,
    _6_months double precision,
    _1_year double precision,
    _2_years double precision,
    _3_years double precision,
    _4_years double precision,
    _5_years double precision,
    _18_months double precision,
    floating double precision
);


--
-- Name: ocr; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ocr (
    date date NOT NULL,
    ocr double precision
);


--
-- Name: wholesale_swap_rate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wholesale_swap_rate (
    date date NOT NULL,
    _1_year double precision,
    _2_years double precision,
    _3_years double precision,
    _4_years double precision,
    _5_years double precision,
    _7_years double precision,
    _10_years double precision
);


--
-- Name: avg_mortgage_rate avg_mortgage_rate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avg_mortgage_rate
    ADD CONSTRAINT avg_mortgage_rate_pkey PRIMARY KEY (date);


--
-- Name: ins_mortgage_rate constraint_1; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ins_mortgage_rate
    ADD CONSTRAINT constraint_1 PRIMARY KEY (date, bank, product);


--
-- Name: ocr ocr_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ocr
    ADD CONSTRAINT ocr_pkey PRIMARY KEY (date);


--
-- Name: wholesale_swap_rate wholesale_swap_rate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wholesale_swap_rate
    ADD CONSTRAINT wholesale_swap_rate_pkey PRIMARY KEY (date);


--
-- PostgreSQL database dump complete
--

\unrestrict ZidQ6CwJUTkMcas6wgBhhf3uDpif4iwgRT75nV02TbaLWmmGIvYXRR6Q5h1QzvB

