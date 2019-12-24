--
-- PostgreSQL database dump
--

-- Dumped from database version 10.6 (Ubuntu 10.6-0ubuntu0.18.04.1)
-- Dumped by pg_dump version 11.6

-- Started on 2019-12-24 12:29:58 GMT

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 5 (class 2615 OID 32215)
-- Name: frepple; Type: SCHEMA; Schema: -; Owner: sysadmin
--

CREATE SCHEMA frepple;


ALTER SCHEMA frepple OWNER TO sysadmin;

--
-- TOC entry 1040 (class 1259 OID 32216)
-- Name: end_item_selection; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.end_item_selection AS
 SELECT DISTINCT sti.id
   FROM (((public.so_lines sol
     JOIN public.so_product_lines sop ON ((sop.id = sol.productline_id)))
     JOIN public.so_product_lines_header soph ON ((soph.id = sop.productline_header_id)))
     JOIN public.st_items sti ON ((sti.id = soph.stitem_id)))
  WHERE ((sol.status)::text <> ALL (ARRAY[('X'::character varying)::text, ('I'::character varying)::text]));


ALTER TABLE frepple.end_item_selection OWNER TO sysadmin;

--
-- TOC entry 1041 (class 1259 OID 32221)
-- Name: item_selection; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.item_selection AS
 SELECT NULL::bigint AS id,
    NULL::integer AS uom_id,
    st_items.id AS item_id,
    st_items.id AS parent_id,
    NULL::character varying AS parent_item,
    st_items.item_code,
    st_items.description,
    NULL::double precision AS qty,
    NULL::character varying AS uom,
    st_items.comp_class
   FROM (public.st_items
     JOIN frepple.end_item_selection e ON ((e.id = st_items.id)))
UNION
( WITH RECURSIVE bom AS (
         SELECT mf_structures.id,
            mf_structures.stitem_id,
            mf_structures.ststructure_id,
            mf_structures.qty,
            mf_structures.uom_id,
            mf_structures.start_date,
            mf_structures.end_date
           FROM (public.mf_structures
             JOIN frepple.end_item_selection e ON ((e.id = mf_structures.stitem_id)))
        UNION ALL
         SELECT si.id,
            si.stitem_id,
            si.ststructure_id,
            si.qty,
            si.uom_id,
            si.start_date,
            si.end_date
           FROM (public.mf_structures si
             JOIN bom sp ON ((si.stitem_id = sp.ststructure_id)))
        )
 SELECT bom.id,
    bom.uom_id,
    bom.ststructure_id AS item_id,
    bom.stitem_id AS parent_id,
    psti.item_code AS parent_item,
    sti.item_code,
    sti.description,
    bom.qty,
    u.uom_name AS uom,
    sti.comp_class
   FROM (((bom
     LEFT JOIN public.st_items sti ON ((sti.id = bom.ststructure_id)))
     LEFT JOIN public.st_items psti ON ((psti.id = bom.stitem_id)))
     LEFT JOIN public.st_uoms u ON ((u.id = bom.uom_id)))
  WHERE (((bom.end_date > now()) OR (bom.end_date IS NULL)) AND (bom.start_date <= now())));


ALTER TABLE frepple.item_selection OWNER TO sysadmin;

--
-- TOC entry 1072 (class 1259 OID 347786)
-- Name: buffers; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.buffers AS
 SELECT
        CASE
            WHEN ((sum(stb.balance) IS NOT NULL) AND ((sti.comp_class)::text = 'M'::text)) THEN (((sti.item_code)::text || ' @ '::text) || (( SELECT whs_1.store_code
               FROM (((public.wh_transfer_rules wtr
                 LEFT JOIN public.wh_actions wha ON ((wha.id = wtr.whaction_id)))
                 LEFT JOIN public.wh_locations whl_1 ON ((whl_1.id = wtr.to_whlocation_id)))
                 LEFT JOIN public.wh_stores whs_1 ON ((whs_1.id = whl_1.whstore_id)))
              WHERE ((wha.type)::text = 'C'::text)
             LIMIT 1))::text)
            ELSE (((sti.item_code)::text || ' @ '::text) || (( SELECT whs_1.store_code
               FROM (((public.wh_transfer_rules wtr
                 LEFT JOIN public.wh_actions wha ON ((wha.id = wtr.whaction_id)))
                 LEFT JOIN public.wh_locations whl_1 ON ((whl_1.id = wtr.to_whlocation_id)))
                 LEFT JOIN public.wh_stores whs_1 ON ((whs_1.id = whl_1.whstore_id)))
              WHERE ((wha.type)::text = 'R'::text)
             LIMIT 1))::text)
        END AS name,
        CASE
            WHEN ((sti.comp_class)::text = 'M'::text) THEN ( SELECT whs_1.store_code
               FROM (((public.wh_transfer_rules wtr
                 LEFT JOIN public.wh_actions wha ON ((wha.id = wtr.whaction_id)))
                 LEFT JOIN public.wh_locations whl_1 ON ((whl_1.id = wtr.to_whlocation_id)))
                 LEFT JOIN public.wh_stores whs_1 ON ((whs_1.id = whl_1.whstore_id)))
              WHERE ((wha.type)::text = 'C'::text)
             LIMIT 1)
            ELSE ( SELECT whs_1.store_code
               FROM (((public.wh_transfer_rules wtr
                 LEFT JOIN public.wh_actions wha ON ((wha.id = wtr.whaction_id)))
                 LEFT JOIN public.wh_locations whl_1 ON ((whl_1.id = wtr.to_whlocation_id)))
                 LEFT JOIN public.wh_stores whs_1 ON ((whs_1.id = whl_1.whstore_id)))
              WHERE ((wha.type)::text = 'R'::text)
             LIMIT 1)
        END AS location,
    sti.item_code AS item,
        CASE
            WHEN (sum(stb.balance) IS NOT NULL) THEN sum(stb.balance)
            ELSE (0)::numeric
        END AS onhand,
    sti.min_qty AS minimum,
        CASE
            WHEN ((sti.comp_class)::text = 'M'::text) THEN '5 days'::interval
            ELSE NULL::interval
        END AS min_interval
   FROM (((public.st_items sti
     LEFT JOIN public.st_balances stb ON ((stb.stitem_id = sti.id)))
     LEFT JOIN public.wh_locations whl ON (((whl.id = stb.whlocation_id) AND (whl.has_balance = true))))
     LEFT JOIN public.wh_stores whs ON ((whl.whstore_id = whs.id)))
  WHERE ((sti.id IN ( SELECT item_selection.item_id
           FROM frepple.item_selection)) AND (sti.obsolete_date IS NULL))
  GROUP BY whs.store_code, sti.item_code, sti.min_qty, sti.comp_class
  ORDER BY sti.item_code;


ALTER TABLE frepple.buffers OWNER TO sysadmin;

--
-- TOC entry 1042 (class 1259 OID 32231)
-- Name: customers; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.customers AS
 SELECT company.name,
    company_types.name AS category
   FROM ((public.slmaster
     JOIN public.company ON ((company.id = slmaster.company_id)))
     LEFT JOIN public.company_types ON ((company_types.id = company.type_id)))
  WHERE (slmaster.date_inactive IS NULL);


ALTER TABLE frepple.customers OWNER TO sysadmin;

--
-- TOC entry 1043 (class 1259 OID 32236)
-- Name: item_suppliers; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.item_suppliers AS
 SELECT c.name AS supplier,
    i.item_code,
    (whs.store_code)::text AS location,
    ((i.lead_time)::integer * 86400) AS leadtime,
    i.batch_size AS size_multiple,
    0 AS size_minimum
   FROM ((((((((public.po_product_lines pl
     JOIN public.po_product_lines_header plh ON ((plh.id = pl.productline_header_id)))
     JOIN public.st_items i ON ((i.id = plh.stitem_id)))
     JOIN public.plmaster plm ON ((plm.id = pl.plmaster_id)))
     JOIN public.company c ON ((c.id = plm.company_id)))
     JOIN public.wh_actions action ON ((action.id = plm.receive_action)))
     JOIN public.wh_transfer_rules wtr ON ((wtr.whaction_id = action.id)))
     JOIN public.wh_locations whl ON ((whl.id = wtr.to_whlocation_id)))
     JOIN public.wh_stores whs ON ((whs.id = whl.whstore_id)))
  WHERE (((i.comp_class)::text = 'B'::text) AND (pl.start_date <= now()) AND ((pl.end_date > now()) OR (pl.end_date IS NULL)) AND (i.id IN ( SELECT item_selection.item_id
           FROM frepple.item_selection)))
  ORDER BY i.item_code;


ALTER TABLE frepple.item_suppliers OWNER TO sysadmin;

--
-- TOC entry 1044 (class 1259 OID 32241)
-- Name: items; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.items AS
 SELECT i.item_code AS name,
    i.description,
    i.comp_class AS category,
    (((p.product_group)::text || ' - '::text) || (p.description)::text) AS subcategory,
    i.latest_cost AS cost,
    i.id AS stitem_id
   FROM (public.st_items i
     JOIN public.st_productgroups p ON ((i.prod_group_id = p.id)))
  WHERE ((i.obsolete_date IS NULL) AND (i.id IN ( SELECT item_selection.item_id
           FROM frepple.item_selection)));


ALTER TABLE frepple.items OWNER TO sysadmin;

--
-- TOC entry 1045 (class 1259 OID 32246)
-- Name: locations; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.locations AS
 SELECT (whs.store_code)::text AS name,
    whs.description,
    'default'::text AS available
   FROM public.wh_stores whs;


ALTER TABLE frepple.locations OWNER TO sysadmin;

--
-- TOC entry 1046 (class 1259 OID 32250)
-- Name: manufacturing_orders; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.manufacturing_orders AS
 SELECT mfw.wo_number AS reference,
    'confirmed'::text AS status,
    sti.item_code AS item,
    ((mfw.start_date)::timestamp without time zone + (- '12:00:00'::interval)) AS startdate,
    ((mfw.required_by)::timestamp without time zone + (- '12:00:00'::interval)) AS enddate,
    (mfw.order_qty - mfw.made_qty) AS quantity,
    ('Make - '::text || (sti.item_code)::text) AS operation
   FROM (public.mf_workorders mfw
     JOIN public.st_items sti ON ((sti.id = mfw.stitem_id)))
  WHERE (((mfw.status)::text = ANY (ARRAY[('N'::character varying)::text, ('R'::character varying)::text])) AND (sti.id IN ( SELECT item_selection.item_id
           FROM frepple.item_selection)));


ALTER TABLE frepple.manufacturing_orders OWNER TO sysadmin;

--
-- TOC entry 1047 (class 1259 OID 32255)
-- Name: operation_materials; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.operation_materials AS
 SELECT ((mfo.op_no || ' - '::text) || (sti.item_code)::text) AS operation,
    bom.item_code AS item,
    ((0)::double precision - mfs.qty) AS quantity,
    'start'::text AS type
   FROM (((public.st_items sti
     JOIN public.mf_structures mfs ON ((mfs.stitem_id = sti.id)))
     JOIN public.st_items bom ON ((bom.id = mfs.ststructure_id)))
     JOIN public.mf_operations mfo ON ((mfo.id = ( SELECT mf_operations.id
           FROM public.mf_operations
          WHERE ((mf_operations.stitem_id = sti.id) AND (((mf_operations.end_date > now()) OR (mf_operations.end_date IS NULL)) AND (mf_operations.start_date <= now())))
          ORDER BY mf_operations.op_no
         LIMIT 1))))
  WHERE ((bom.obsolete_date IS NULL) AND (sti.obsolete_date IS NULL) AND ((mfs.end_date > now()) OR (mfs.end_date IS NULL)) AND (mfs.start_date <= now()) AND (((sti.comp_class)::text = 'M'::text) OR ((sti.comp_class)::text = 'S'::text)) AND (sti.id IN ( SELECT item_selection.item_id
           FROM frepple.item_selection)))
UNION
 SELECT ((mfo.op_no || ' - '::text) || (sti.item_code)::text) AS operation,
    sti.item_code AS item,
    1 AS quantity,
    'end'::text AS type
   FROM ((public.st_items sti
     JOIN public.mf_structures mfs ON ((mfs.stitem_id = sti.id)))
     JOIN public.mf_operations mfo ON ((mfo.id = ( SELECT mf_operations.id
           FROM public.mf_operations
          WHERE ((mf_operations.stitem_id = sti.id) AND (((mf_operations.end_date > now()) OR (mf_operations.end_date IS NULL)) AND (mf_operations.start_date <= now())))
          ORDER BY mf_operations.op_no DESC
         LIMIT 1))))
  WHERE ((sti.obsolete_date IS NULL) AND ((mfs.end_date > now()) OR (mfs.end_date IS NULL)) AND (mfs.start_date <= now()) AND (((sti.comp_class)::text = 'M'::text) OR ((sti.comp_class)::text = 'S'::text)) AND (sti.id IN ( SELECT item_selection.item_id
           FROM frepple.item_selection)));


ALTER TABLE frepple.operation_materials OWNER TO sysadmin;

--
-- TOC entry 1048 (class 1259 OID 32260)
-- Name: operation_resources; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.operation_resources AS
 SELECT (((o.op_no)::text || ' - '::text) || (s.item_code)::text) AS name,
    r.centre AS resource,
    1 AS quantity
   FROM ((public.mf_operations o
     JOIN public.st_items s ON ((o.stitem_id = s.id)))
     JOIN public.mf_centres r ON ((o.mfcentre_id = r.id)))
  WHERE ((s.obsolete_date IS NULL) AND ((o.end_date > now()) OR (o.end_date IS NULL)) AND (o.start_date <= now()) AND ((o.type)::text <> 'O'::text) AND (s.id IN ( SELECT item_selection.item_id
           FROM frepple.item_selection)));


ALTER TABLE frepple.operation_resources OWNER TO sysadmin;

--
-- TOC entry 1071 (class 1259 OID 341989)
-- Name: operations; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.operations AS
 SELECT (('Make'::text || ' - '::text) || (s.item_code)::text) AS name,
    s.item_code AS item,
    0 AS duration,
    0 AS duration_per,
    'routing'::text AS type,
    (( SELECT whs.store_code
           FROM (((public.wh_transfer_rules wtr
             LEFT JOIN public.wh_actions wha ON ((wha.id = wtr.whaction_id)))
             LEFT JOIN public.wh_locations whl ON ((whl.id = wtr.to_whlocation_id)))
             LEFT JOIN public.wh_stores whs ON ((whs.id = whl.whstore_id)))
          WHERE ((wha.type)::text = 'C'::text)
         LIMIT 1))::text AS location,
    ''::text AS description,
    s.batch_size,
    'default'::text AS available,
        CASE
            WHEN ((s.comp_class)::text = 'M'::text) THEN 'Work Order'::text
            ELSE 'Outside Operation'::text
        END AS category,
    ''::text AS owner
   FROM public.st_items s
  WHERE ((s.obsolete_date IS NULL) AND (((s.comp_class)::text = 'M'::text) OR ((s.comp_class)::text = 'S'::text)) AND (s.id IN ( SELECT item_selection.item_id
           FROM frepple.item_selection)))
UNION
 SELECT (((o.op_no)::text || ' - '::text) || (s.item_code)::text) AS name,
    s.item_code AS item,
        CASE
            WHEN ((o.type)::text = 'O'::text) THEN (round(((28800 * o.lead_time))::numeric, 0))::integer
            ELSE 0
        END AS duration,
        CASE
            WHEN ((o.type)::text = 'O'::text) THEN (0)::numeric
            ELSE
            CASE
                WHEN (((s.cost_basis)::text = 'TIME'::text) AND ((o.volume_period)::text = 'H'::text)) THEN round(((3600)::numeric * o.volume_target), 0)
                WHEN (((s.cost_basis)::text = 'TIME'::text) AND ((o.volume_period)::text = 'M'::text)) THEN round(((60)::numeric * o.volume_target), 0)
                WHEN (((s.cost_basis)::text = 'TIME'::text) AND ((o.volume_period)::text = 'S'::text)) THEN o.volume_target
                WHEN (((s.cost_basis)::text = 'VOLUME'::text) AND ((o.volume_period)::text = 'H'::text)) THEN round(((3600)::numeric / o.volume_target), 0)
                WHEN (((s.cost_basis)::text = 'VOLUME'::text) AND ((o.volume_period)::text = 'M'::text)) THEN round(((60)::numeric / o.volume_target), 0)
                WHEN (((s.cost_basis)::text = 'VOLUME'::text) AND ((o.volume_period)::text = 'S'::text)) THEN round(((1)::numeric / o.volume_target), 0)
                ELSE NULL::numeric
            END
        END AS duration_per,
        CASE
            WHEN ((o.type)::text = 'O'::text) THEN 'fixed_time'::text
            ELSE 'time_per'::text
        END AS type,
    (( SELECT whs.store_code
           FROM (((public.wh_transfer_rules wtr
             LEFT JOIN public.wh_actions wha ON ((wha.id = wtr.whaction_id)))
             LEFT JOIN public.wh_locations whl ON ((whl.id = wtr.to_whlocation_id)))
             LEFT JOIN public.wh_stores whs ON ((whs.id = whl.whstore_id)))
          WHERE ((wha.type)::text = 'C'::text)
         LIMIT 1))::text AS location,
    o.remarks AS description,
    s.batch_size,
        CASE
            WHEN ((o.type)::text = 'O'::text) THEN 'supplier'::text
            ELSE 'default'::text
        END AS available,
        CASE
            WHEN ((o.type)::text = 'O'::text) THEN 'Routing Outside Processing'::text
            ELSE 'Operation'::text
        END AS category,
    (('Make'::text || ' - '::text) || (s.item_code)::text) AS owner
   FROM ((((public.mf_operations o
     JOIN public.st_items s ON ((o.stitem_id = s.id)))
     JOIN public.st_uoms u ON ((o.volume_uom_id = u.id)))
     JOIN public.mf_centres c ON ((o.mfcentre_id = c.id)))
     JOIN public.mf_resources r ON ((o.mfresource_id = r.id)))
  WHERE ((s.obsolete_date IS NULL) AND ((o.end_date > now()) OR (o.end_date IS NULL)) AND (o.start_date <= now()) AND (s.id IN ( SELECT item_selection.item_id
           FROM frepple.item_selection)))
UNION
 SELECT (((((1000)::numeric + (o.op_no)::numeric))::text || ' - '::text) || (s.item_code)::text) AS name,
    s.item_code AS item,
    (round(((28800 * 7))::numeric, 0))::integer AS duration,
    0 AS duration_per,
    'fixed_time'::text AS type,
    (( SELECT whs.store_code
           FROM (((public.wh_transfer_rules wtr
             LEFT JOIN public.wh_actions wha ON ((wha.id = wtr.whaction_id)))
             LEFT JOIN public.wh_locations whl ON ((whl.id = wtr.to_whlocation_id)))
             LEFT JOIN public.wh_stores whs ON ((whs.id = whl.whstore_id)))
          WHERE ((wha.type)::text = 'C'::text)
         LIMIT 1))::text AS location,
    o.description,
    s.batch_size,
    'supplier'::text AS available,
    'Outside Processing'::text AS category,
    (('Make'::text || ' - '::text) || (s.item_code)::text) AS owner
   FROM (public.mf_outside_ops o
     JOIN public.st_items s ON ((o.stitem_id = s.id)))
  WHERE ((s.obsolete_date IS NULL) AND ((o.end_date > now()) OR (o.end_date IS NULL)) AND (o.start_date <= now()) AND (s.id IN ( SELECT item_selection.item_id
           FROM frepple.item_selection)));


ALTER TABLE frepple.operations OWNER TO sysadmin;

--
-- TOC entry 1049 (class 1259 OID 32270)
-- Name: purchase_orders; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.purchase_orders AS
 SELECT ((poh.order_number || '-'::text) || pol.line_number) AS reference,
    'confirmed'::text AS status,
    sti.item_code AS item,
    (whs.store_code)::text AS location,
    cmp.name AS supplier,
    ((pol.due_delivery_date)::timestamp without time zone + (- '12:00:00'::interval)) AS end_date,
    pol.os_qty AS quantity
   FROM ((((((((public.po_lines pol
     JOIN public.po_header poh ON ((pol.order_id = poh.id)))
     JOIN public.st_items sti ON ((sti.id = pol.stitem_id)))
     JOIN public.plmaster sup ON ((sup.id = poh.plmaster_id)))
     JOIN public.company cmp ON ((cmp.id = sup.company_id)))
     JOIN public.wh_actions act ON ((act.id = sup.receive_action)))
     JOIN public.wh_transfer_rules tr ON ((tr.whaction_id = act.id)))
     JOIN public.wh_locations whl ON ((whl.id = tr.from_whlocation_id)))
     JOIN public.wh_stores whs ON ((whs.id = whl.whstore_id)))
  WHERE (((pol.status)::text <> ALL (ARRAY['H'::text, 'X'::text, 'I'::text, 'R'::text])) AND ((poh.type)::text = 'O'::text) AND (sti.id IN ( SELECT item_selection.item_id
           FROM frepple.item_selection)));


ALTER TABLE frepple.purchase_orders OWNER TO sysadmin;

--
-- TOC entry 1050 (class 1259 OID 32275)
-- Name: resources; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.resources AS
 SELECT mf_centres.centre AS name,
    (( SELECT whs.store_code
           FROM (((public.wh_transfer_rules wtr
             LEFT JOIN public.wh_actions wha ON ((wha.id = wtr.whaction_id)))
             LEFT JOIN public.wh_locations whl ON ((whl.id = wtr.to_whlocation_id)))
             LEFT JOIN public.wh_stores whs ON ((whs.id = whl.whstore_id)))
          WHERE ((wha.type)::text = 'C'::text)
         LIMIT 1))::text AS location,
    'default'::text AS type,
    mf_centres.available_qty AS maximum,
    ''::text AS available
   FROM public.mf_centres;


ALTER TABLE frepple.resources OWNER TO sysadmin;

--
-- TOC entry 1051 (class 1259 OID 32279)
-- Name: sales_orders; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.sales_orders AS
 SELECT ((soh.order_number || '-'::text) || sol.line_number) AS name,
    sol.revised_qty AS quantity,
    sti.item_code AS item,
    (whs.store_code)::text AS location,
    ((sol.due_despatch_date)::timestamp without time zone + (- '12:00:00'::interval)) AS due,
    cmp.name AS customer,
    ''::text AS operation
   FROM ((((((((public.so_lines sol
     JOIN public.so_header soh ON ((sol.order_id = soh.id)))
     JOIN public.st_items sti ON ((sti.id = sol.stitem_id)))
     JOIN public.slmaster cust ON ((cust.id = soh.slmaster_id)))
     JOIN public.company cmp ON ((cmp.id = cust.company_id)))
     JOIN public.wh_actions act ON ((act.id = cust.despatch_action)))
     JOIN public.wh_transfer_rules tr ON ((tr.whaction_id = act.id)))
     JOIN public.wh_locations whl ON ((whl.id = tr.from_whlocation_id)))
     JOIN public.wh_stores whs ON ((whs.id = whl.whstore_id)))
  WHERE (((sol.status)::text = ANY (ARRAY[('N'::character varying)::text, ('P'::character varying)::text])) AND ((soh.type)::text = 'O'::text) AND (sti.id IN ( SELECT item_selection.item_id
           FROM frepple.item_selection)));


ALTER TABLE frepple.sales_orders OWNER TO sysadmin;

--
-- TOC entry 1052 (class 1259 OID 32289)
-- Name: suppliers; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.suppliers AS
 SELECT company.name,
    company_types.name AS category,
    plmaster.id AS plmaster_id
   FROM ((public.plmaster
     JOIN public.company ON ((company.id = plmaster.company_id)))
     LEFT JOIN public.company_types ON ((company_types.id = company.type_id)))
  WHERE (plmaster.date_inactive IS NULL);


ALTER TABLE frepple.suppliers OWNER TO sysadmin;

--
-- TOC entry 1053 (class 1259 OID 32294)
-- Name: uzerp_auth; Type: VIEW; Schema: frepple; Owner: sysadmin
--

CREATE VIEW frepple.uzerp_auth AS
 SELECT users.username,
    users.password
   FROM ((public.users
     LEFT JOIN public.hasrole ON (((hasrole.username)::text = (users.username)::text)))
     LEFT JOIN public.roles ON ((roles.id = hasrole.roleid)))
  WHERE ((roles.name)::text = 'frepple'::text);


ALTER TABLE frepple.uzerp_auth OWNER TO sysadmin;

--
-- TOC entry 5733 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA frepple; Type: ACL; Schema: -; Owner: sysadmin
--

GRANT USAGE ON SCHEMA frepple TO frepple;


--
-- TOC entry 5734 (class 0 OID 0)
-- Dependencies: 1040
-- Name: TABLE end_item_selection; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.end_item_selection TO frepple;


--
-- TOC entry 5735 (class 0 OID 0)
-- Dependencies: 1072
-- Name: TABLE buffers; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.buffers TO frepple;


--
-- TOC entry 5736 (class 0 OID 0)
-- Dependencies: 1042
-- Name: TABLE customers; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.customers TO frepple;


--
-- TOC entry 5737 (class 0 OID 0)
-- Dependencies: 1043
-- Name: TABLE item_suppliers; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.item_suppliers TO frepple;


--
-- TOC entry 5738 (class 0 OID 0)
-- Dependencies: 1044
-- Name: TABLE items; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.items TO frepple;


--
-- TOC entry 5739 (class 0 OID 0)
-- Dependencies: 1045
-- Name: TABLE locations; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.locations TO frepple;


--
-- TOC entry 5740 (class 0 OID 0)
-- Dependencies: 1046
-- Name: TABLE manufacturing_orders; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.manufacturing_orders TO frepple;


--
-- TOC entry 5741 (class 0 OID 0)
-- Dependencies: 1047
-- Name: TABLE operation_materials; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.operation_materials TO frepple;


--
-- TOC entry 5742 (class 0 OID 0)
-- Dependencies: 1048
-- Name: TABLE operation_resources; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.operation_resources TO frepple;


--
-- TOC entry 5743 (class 0 OID 0)
-- Dependencies: 1071
-- Name: TABLE operations; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.operations TO frepple;


--
-- TOC entry 5744 (class 0 OID 0)
-- Dependencies: 1049
-- Name: TABLE purchase_orders; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.purchase_orders TO frepple;


--
-- TOC entry 5745 (class 0 OID 0)
-- Dependencies: 1050
-- Name: TABLE resources; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.resources TO frepple;


--
-- TOC entry 5746 (class 0 OID 0)
-- Dependencies: 1051
-- Name: TABLE sales_orders; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.sales_orders TO frepple;


--
-- TOC entry 5747 (class 0 OID 0)
-- Dependencies: 1052
-- Name: TABLE suppliers; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.suppliers TO frepple;


--
-- TOC entry 5748 (class 0 OID 0)
-- Dependencies: 1053
-- Name: TABLE uzerp_auth; Type: ACL; Schema: frepple; Owner: sysadmin
--

GRANT SELECT ON TABLE frepple.uzerp_auth TO frepple;


-- Completed on 2019-12-24 12:29:59 GMT

--
-- PostgreSQL database dump complete
--

