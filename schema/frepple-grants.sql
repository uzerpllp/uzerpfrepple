---
--- Grants required for exports back to uzERP from frepple
---
GRANT SELECT ON public.st_items TO frepple;
GRANT SELECT ON TABLE public.mf_structures TO frepple;
GRANT SELECT, INSERT ON TABLE public.mf_wo_structures TO frepple;
GRANT SELECT, INSERT ON TABLE public.mf_workorders TO frepple;
GRANT USAGE ON SEQUENCE public.mf_wo_structures_id_seq TO frepple;
GRANT USAGE ON SEQUENCE public.mf_workorders_id_seq TO frepple;
GRANT INSERT ON TABLE public.po_planned TO frepple;
GRANT USAGE ON SEQUENCE public.po_planned_id_seq TO frepple;
