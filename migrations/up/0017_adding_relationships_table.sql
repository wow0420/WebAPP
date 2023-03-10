CREATE TABLE IF NOT EXISTS public.relationships
(
    id bigint NOT NULL GENERATED BY DEFAULT AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    author_user_id uuid NOT NULL,
    on_user_id uuid NOT NULL,
    private_notes text COLLATE pg_catalog."default",
    CONSTRAINT relationship_details_pkey PRIMARY KEY (id),
    CONSTRAINT relationships_author_user_id_fkey FOREIGN KEY (author_user_id)
        REFERENCES auth.users (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT relationships_on_user_id_fkey FOREIGN KEY (on_user_id)
        REFERENCES auth.users (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.relationships
    OWNER to supabase_admin;

GRANT ALL ON TABLE public.relationships TO anon;
GRANT ALL ON TABLE public.relationships TO authenticated;
GRANT ALL ON TABLE public.relationships TO postgres;
GRANT ALL ON TABLE public.relationships TO service_role;
GRANT ALL ON TABLE public.relationships TO supabase_admin;

ALTER TABLE IF EXISTS public.connections
    ADD CONSTRAINT connections_check CHECK (from_user_id < to_user_id);

