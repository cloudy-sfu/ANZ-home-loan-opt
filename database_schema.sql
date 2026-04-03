--
-- PostgreSQL database dump
--

\restrict Ws24mbdRhaUUaZBGMczr9nPnyZjQI6tvY7CFIQJSY5weFqkaGZNCDn7kIA7Bqe8

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
    "Date" date CONSTRAINT avg_mortgage_rate_date_not_null NOT NULL,
    "Floating" double precision,
    "_6_Months" double precision,
    "_1_Year" double precision,
    "_18_Months" double precision,
    "_2_Years" double precision,
    "_3_Years" double precision,
    "_4_Years" double precision,
    "_5_Years" double precision
);


--
-- Name: ocr; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ocr (
    "Date" date CONSTRAINT ocr_date_not_null NOT NULL,
    "OCR" double precision
);


--
-- Name: retail_rate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.retail_rate (
    "Date" date DEFAULT ((CURRENT_TIMESTAMP AT TIME ZONE 'Pacific/Auckland'::text))::date NOT NULL,
    "Bank" character varying(8) NOT NULL,
    "_6_Months" double precision,
    "_1_Year" double precision,
    "_2_Years" double precision,
    "_3_Years" double precision,
    "_4_Years" double precision,
    "_5_Years" double precision,
    "Floating" double precision
);


--
-- Name: wholesale_swap_rate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wholesale_swap_rate (
    "Date" date CONSTRAINT wholesale_swap_rate_date_not_null NOT NULL,
    "_1_Year" double precision,
    "_2_Years" double precision,
    "_3_Years" double precision,
    "_4_Years" double precision,
    "_5_Years" double precision,
    "_7_Years" double precision,
    "_10_Years" double precision
);


--
-- Name: avg_mortgage_rate avg_mortgage_rate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.avg_mortgage_rate
    ADD CONSTRAINT avg_mortgage_rate_pkey PRIMARY KEY ("Date");


--
-- Name: retail_rate constraint_1; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.retail_rate
    ADD CONSTRAINT constraint_1 PRIMARY KEY ("Date", "Bank");


--
-- Name: ocr ocr_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ocr
    ADD CONSTRAINT ocr_pkey PRIMARY KEY ("Date");


--
-- Name: wholesale_swap_rate wholesale_swap_rate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wholesale_swap_rate
    ADD CONSTRAINT wholesale_swap_rate_pkey PRIMARY KEY ("Date");


--
-- PostgreSQL database dump complete
--

\unrestrict Ws24mbdRhaUUaZBGMczr9nPnyZjQI6tvY7CFIQJSY5weFqkaGZNCDn7kIA7Bqe8

