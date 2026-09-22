--
-- PostgreSQL database dump
--

\restrict S3NGxWJACoixbmnoe09BhOWNZOrt4hIFlufzsI6PH4r1eizYVqdlNPAJJxYbfKl

-- Dumped from database version 14.24
-- Dumped by pg_dump version 18.6

-- Started on 2026-09-22 22:11:47

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

--
-- TOC entry 4 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 210 (class 1259 OID 16425)
-- Name: bird; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bird (
    bird_id integer NOT NULL,
    common_name text,
    scientific_name text,
    wikipedia_url text,
    image_url text,
    description text
);


ALTER TABLE public.bird OWNER TO postgres;

--
-- TOC entry 213 (class 1259 OID 16478)
-- Name: bird_category; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bird_category (
    bird_id integer,
    category_id integer
);


ALTER TABLE public.bird_category OWNER TO postgres;

--
-- TOC entry 212 (class 1259 OID 16461)
-- Name: category; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.category (
    category_id integer NOT NULL,
    name text,
    description text,
    parent_category_id integer
);


ALTER TABLE public.category OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 16530)
-- Name: classifies; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.classifies (
    bird_id integer NOT NULL,
    category_id integer NOT NULL,
    sound_id integer NOT NULL
);


ALTER TABLE public.classifies OWNER TO postgres;

--
-- TOC entry 215 (class 1259 OID 16510)
-- Name: has; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.has (
    bird_id integer,
    sound_id integer
);


ALTER TABLE public.has OWNER TO postgres;

--
-- TOC entry 214 (class 1259 OID 16491)
-- Name: identified_as; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.identified_as (
    model_version text,
    identified_at timestamp without time zone,
    recording_id integer NOT NULL,
    bird_id integer NOT NULL
);


ALTER TABLE public.identified_as OWNER TO postgres;

--
-- TOC entry 209 (class 1259 OID 16395)
-- Name: recording; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.recording (
    recording_id integer NOT NULL,
    file_url character varying(255),
    duration numeric,
    recorded_at timestamp without time zone,
    location character varying(255),
    status character varying(255),
    confidence numeric
);


ALTER TABLE public.recording OWNER TO postgres;

--
-- TOC entry 211 (class 1259 OID 16441)
-- Name: sound; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sound (
    sound_id integer NOT NULL,
    title text,
    file_url text,
    type text,
    source text,
    description text,
    recorded_at timestamp without time zone,
    category_id integer,
    duration integer
);


ALTER TABLE public.sound OWNER TO postgres;

--
-- TOC entry 3362 (class 0 OID 16425)
-- Dependencies: 210
-- Data for Name: bird; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bird (bird_id, common_name, scientific_name, wikipedia_url, image_url, description) FROM stdin;
\.


--
-- TOC entry 3365 (class 0 OID 16478)
-- Dependencies: 213
-- Data for Name: bird_category; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bird_category (bird_id, category_id) FROM stdin;
\.


--
-- TOC entry 3364 (class 0 OID 16461)
-- Dependencies: 212
-- Data for Name: category; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.category (category_id, name, description, parent_category_id) FROM stdin;
\.


--
-- TOC entry 3368 (class 0 OID 16530)
-- Dependencies: 216
-- Data for Name: classifies; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.classifies (bird_id, category_id, sound_id) FROM stdin;
\.


--
-- TOC entry 3367 (class 0 OID 16510)
-- Dependencies: 215
-- Data for Name: has; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.has (bird_id, sound_id) FROM stdin;
\.


--
-- TOC entry 3366 (class 0 OID 16491)
-- Dependencies: 214
-- Data for Name: identified_as; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.identified_as (model_version, identified_at, recording_id, bird_id) FROM stdin;
\.


--
-- TOC entry 3361 (class 0 OID 16395)
-- Dependencies: 209
-- Data for Name: recording; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.recording (recording_id, file_url, duration, recorded_at, location, status, confidence) FROM stdin;
\.


--
-- TOC entry 3363 (class 0 OID 16441)
-- Dependencies: 211
-- Data for Name: sound; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sound (sound_id, title, file_url, type, source, description, recorded_at, category_id, duration) FROM stdin;
\.


--
-- TOC entry 3204 (class 2606 OID 16509)
-- Name: identified_as bird_id; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.identified_as
    ADD CONSTRAINT bird_id UNIQUE (bird_id);


--
-- TOC entry 3194 (class 2606 OID 16431)
-- Name: bird bird_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bird
    ADD CONSTRAINT bird_pkey PRIMARY KEY (bird_id);


--
-- TOC entry 3196 (class 2606 OID 16551)
-- Name: bird bird_scientific_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bird
    ADD CONSTRAINT bird_scientific_name_key UNIQUE (scientific_name);


--
-- TOC entry 3200 (class 2606 OID 16469)
-- Name: category category_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT category_name_key UNIQUE (name);


--
-- TOC entry 3202 (class 2606 OID 16467)
-- Name: category category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT category_pkey PRIMARY KEY (category_id);


--
-- TOC entry 3210 (class 2606 OID 16534)
-- Name: classifies classifies_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classifies
    ADD CONSTRAINT classifies_pkey PRIMARY KEY (bird_id, category_id, sound_id);


--
-- TOC entry 3208 (class 2606 OID 16524)
-- Name: has has_bird_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.has
    ADD CONSTRAINT has_bird_id_key UNIQUE (bird_id);


--
-- TOC entry 3206 (class 2606 OID 16497)
-- Name: identified_as identified_as_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.identified_as
    ADD CONSTRAINT identified_as_pkey PRIMARY KEY (recording_id, bird_id);


--
-- TOC entry 3192 (class 2606 OID 16401)
-- Name: recording recording_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recording
    ADD CONSTRAINT recording_pkey PRIMARY KEY (recording_id);


--
-- TOC entry 3198 (class 2606 OID 16447)
-- Name: sound sound_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sound
    ADD CONSTRAINT sound_pkey PRIMARY KEY (sound_id);


--
-- TOC entry 3213 (class 2606 OID 16481)
-- Name: bird_category bird_category_bird_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bird_category
    ADD CONSTRAINT bird_category_bird_id_fkey FOREIGN KEY (bird_id) REFERENCES public.bird(bird_id);


--
-- TOC entry 3214 (class 2606 OID 16486)
-- Name: bird_category bird_category_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bird_category
    ADD CONSTRAINT bird_category_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.category(category_id);


--
-- TOC entry 3212 (class 2606 OID 16470)
-- Name: category category_parent_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.category
    ADD CONSTRAINT category_parent_category_id_fkey FOREIGN KEY (parent_category_id) REFERENCES public.category(category_id);


--
-- TOC entry 3219 (class 2606 OID 16535)
-- Name: classifies classifies_bird_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classifies
    ADD CONSTRAINT classifies_bird_id_fkey FOREIGN KEY (bird_id) REFERENCES public.bird(bird_id);


--
-- TOC entry 3220 (class 2606 OID 16540)
-- Name: classifies classifies_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classifies
    ADD CONSTRAINT classifies_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.category(category_id);


--
-- TOC entry 3221 (class 2606 OID 16545)
-- Name: classifies classifies_sound_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classifies
    ADD CONSTRAINT classifies_sound_id_fkey FOREIGN KEY (sound_id) REFERENCES public.sound(sound_id);


--
-- TOC entry 3217 (class 2606 OID 16513)
-- Name: has has_bird_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.has
    ADD CONSTRAINT has_bird_id_fkey FOREIGN KEY (bird_id) REFERENCES public.bird(bird_id);


--
-- TOC entry 3218 (class 2606 OID 16518)
-- Name: has has_sound_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.has
    ADD CONSTRAINT has_sound_id_fkey FOREIGN KEY (sound_id) REFERENCES public.sound(sound_id);


--
-- TOC entry 3215 (class 2606 OID 16503)
-- Name: identified_as identified_as_bird_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.identified_as
    ADD CONSTRAINT identified_as_bird_id_fkey FOREIGN KEY (bird_id) REFERENCES public.bird(bird_id);


--
-- TOC entry 3216 (class 2606 OID 16498)
-- Name: identified_as identified_as_recording_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.identified_as
    ADD CONSTRAINT identified_as_recording_id_fkey FOREIGN KEY (recording_id) REFERENCES public.recording(recording_id);


--
-- TOC entry 3211 (class 2606 OID 16525)
-- Name: sound sound_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sound
    ADD CONSTRAINT sound_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.category(category_id);


--
-- TOC entry 3374 (class 0 OID 0)
-- Dependencies: 4
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


-- Completed on 2026-09-22 22:11:47

--
-- PostgreSQL database dump complete
--

\unrestrict S3NGxWJACoixbmnoe09BhOWNZOrt4hIFlufzsI6PH4r1eizYVqdlNPAJJxYbfKl

