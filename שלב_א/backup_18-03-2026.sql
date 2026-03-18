--
-- PostgreSQL database dump
--

-- Dumped from database version 17.1 (Debian 17.1-1.pgdg120+1)
-- Dumped by pg_dump version 17.1 (Debian 17.1-1.pgdg120+1)

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ORDER; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public."ORDER" (
    order_id integer NOT NULL,
    table_id integer NOT NULL,
    customer_id integer,
    waiter_id integer NOT NULL,
    order_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    order_status character varying(20) NOT NULL,
    CONSTRAINT check_order_status CHECK (((order_status)::text = ANY ((ARRAY['Pending'::character varying, 'In Progress'::character varying, 'Completed'::character varying, 'Cancelled'::character varying])::text[])))
);


ALTER TABLE public."ORDER" OWNER TO admin;

--
-- Name: bill; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.bill (
    bill_id integer NOT NULL,
    order_id integer NOT NULL,
    total_amount numeric(10,2) NOT NULL,
    tax numeric(10,2) NOT NULL,
    discount_amount numeric(10,2) DEFAULT 0,
    final_amount numeric(10,2) NOT NULL,
    bill_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT check_discount_amt CHECK ((discount_amount >= (0)::numeric)),
    CONSTRAINT check_final CHECK ((final_amount >= (0)::numeric)),
    CONSTRAINT check_tax CHECK ((tax >= (0)::numeric)),
    CONSTRAINT check_total CHECK ((total_amount >= (0)::numeric))
);


ALTER TABLE public.bill OWNER TO admin;

--
-- Name: bill_discount; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.bill_discount (
    bill_discount_id integer NOT NULL,
    bill_id integer NOT NULL,
    discount_id integer NOT NULL
);


ALTER TABLE public.bill_discount OWNER TO admin;

--
-- Name: discount; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.discount (
    discount_id integer NOT NULL,
    discount_name character varying(100) NOT NULL,
    percentage numeric(5,2) NOT NULL,
    valid_from date NOT NULL,
    valid_to date NOT NULL,
    CONSTRAINT check_dates CHECK ((valid_to >= valid_from)),
    CONSTRAINT check_percentage CHECK (((percentage >= (0)::numeric) AND (percentage <= (100)::numeric)))
);


ALTER TABLE public.discount OWNER TO admin;

--
-- Name: order_item; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.order_item (
    order_item_id integer NOT NULL,
    order_id integer NOT NULL,
    menu_item_id integer NOT NULL,
    quantity integer NOT NULL,
    special_request text,
    CONSTRAINT check_quantity CHECK ((quantity > 0))
);


ALTER TABLE public.order_item OWNER TO admin;

--
-- Name: payment; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.payment (
    payment_id integer NOT NULL,
    bill_id integer NOT NULL,
    payment_method character varying(30) NOT NULL,
    payment_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    amount numeric(10,2) NOT NULL,
    CONSTRAINT check_payment_amount CHECK ((amount > (0)::numeric)),
    CONSTRAINT check_payment_method CHECK (((payment_method)::text = ANY ((ARRAY['Cash'::character varying, 'Credit Card'::character varying, 'Debit Card'::character varying, 'Mobile Payment'::character varying])::text[])))
);


ALTER TABLE public.payment OWNER TO admin;

--
-- Data for Name: ORDER; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public."ORDER" (order_id, table_id, customer_id, waiter_id, order_time, order_status) FROM stdin;
101	5	1	10	2023-10-25 12:30:00	Completed
102	8	2	11	2023-10-25 13:00:00	Completed
103	3	3	10	2023-10-25 19:15:00	In Progress
\.


--
-- Data for Name: bill; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.bill (bill_id, order_id, total_amount, tax, discount_amount, final_amount, bill_time) FROM stdin;
501	101	40.00	4.00	8.00	36.00	2023-10-25 13:45:00
502	102	15.00	1.50	0.00	16.50	2023-10-25 14:10:00
\.


--
-- Data for Name: bill_discount; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.bill_discount (bill_discount_id, bill_id, discount_id) FROM stdin;
1	501	1
\.


--
-- Data for Name: discount; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.discount (discount_id, discount_name, percentage, valid_from, valid_to) FROM stdin;
1	Happy Hour	20.00	2023-01-01	2025-12-31
2	Student Discount	10.00	2023-01-01	2025-12-31
3	Welcome Offer	15.00	2023-01-01	2025-12-31
\.


--
-- Data for Name: order_item; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.order_item (order_item_id, order_id, menu_item_id, quantity, special_request) FROM stdin;
1	101	50	2	Sans oignons sur une pizza
2	101	75	2	Glaçons à part
3	102	55	1	Cuit à point
\.


--
-- Data for Name: payment; Type: TABLE DATA; Schema: public; Owner: admin
--

COPY public.payment (payment_id, bill_id, payment_method, payment_time, amount) FROM stdin;
901	501	Credit Card	2023-10-25 13:50:00	36.00
902	502	Cash	2023-10-25 14:15:00	16.50
\.


--
-- Name: ORDER ORDER_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public."ORDER"
    ADD CONSTRAINT "ORDER_pkey" PRIMARY KEY (order_id);


--
-- Name: bill_discount bill_discount_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.bill_discount
    ADD CONSTRAINT bill_discount_pkey PRIMARY KEY (bill_discount_id);


--
-- Name: bill bill_order_id_key; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT bill_order_id_key UNIQUE (order_id);


--
-- Name: bill bill_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT bill_pkey PRIMARY KEY (bill_id);


--
-- Name: discount discount_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.discount
    ADD CONSTRAINT discount_pkey PRIMARY KEY (discount_id);


--
-- Name: order_item order_item_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT order_item_pkey PRIMARY KEY (order_item_id);


--
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (payment_id);


--
-- Name: bill_discount fk_bd_bill; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.bill_discount
    ADD CONSTRAINT fk_bd_bill FOREIGN KEY (bill_id) REFERENCES public.bill(bill_id);


--
-- Name: bill_discount fk_bd_discount; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.bill_discount
    ADD CONSTRAINT fk_bd_discount FOREIGN KEY (discount_id) REFERENCES public.discount(discount_id);


--
-- Name: bill fk_bill_order; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.bill
    ADD CONSTRAINT fk_bill_order FOREIGN KEY (order_id) REFERENCES public."ORDER"(order_id);


--
-- Name: order_item fk_order_item_order; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.order_item
    ADD CONSTRAINT fk_order_item_order FOREIGN KEY (order_id) REFERENCES public."ORDER"(order_id) ON DELETE CASCADE;


--
-- Name: payment fk_payment_bill; Type: FK CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.payment
    ADD CONSTRAINT fk_payment_bill FOREIGN KEY (bill_id) REFERENCES public.bill(bill_id);


--
-- PostgreSQL database dump complete
--

