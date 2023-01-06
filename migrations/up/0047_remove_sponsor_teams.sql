CREATE TABLE IF NOT EXISTS public.deal_to_sponsor_associations
(
    id bigint NOT NULL GENERATED BY DEFAULT AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1 ),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deal_id bigint NOT NULL,
    sponsor_id uuid NOT NULL,
    order_index bigint,
    CONSTRAINT deal_to_sponsor_associations_pkey PRIMARY KEY (id),
    CONSTRAINT deal_to_sponsor_associations_deal_id_fkey FOREIGN KEY (deal_id)
        REFERENCES public.deals (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT deal_to_sponsor_associations_sponsor_id_fkey FOREIGN KEY (sponsor_id)
        REFERENCES auth.users (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.deal_to_sponsor_associations
    OWNER to supabase_admin;

ALTER TABLE IF EXISTS public.deal_to_sponsor_associations
    ENABLE ROW LEVEL SECURITY;

GRANT ALL ON TABLE public.deal_to_sponsor_associations TO anon;

GRANT ALL ON TABLE public.deal_to_sponsor_associations TO authenticated;

GRANT ALL ON TABLE public.deal_to_sponsor_associations TO postgres;

GRANT ALL ON TABLE public.deal_to_sponsor_associations TO service_role;

GRANT ALL ON TABLE public.deal_to_sponsor_associations TO supabase_admin;

CREATE TRIGGER deal_to_sponsor_associations_set_updated_at
    AFTER INSERT OR UPDATE 
    ON public.deal_to_sponsor_associations
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_set_updated_at();


CREATE OR REPLACE VIEW public.sponsor_deals_view
    AS
     SELECT user_profile.user_id,
    ( SELECT json_agg(deals.*) AS json_agg
           FROM ( SELECT deal.id,
                    deal.title,
                    deal.about,
                    deal.is_active,
                    deal.handle,
                    ( SELECT deal_image.image_url
                           FROM deal_images deal_image
                          WHERE deal.id = deal_image.deal_id
                          ORDER BY deal_image.order_index, deal_image.created_at
                         LIMIT 1) AS deal_image,
                    deal.interest_count,
                    ( SELECT dtsa.sponsor_id
                           FROM deal_to_sponsor_associations dtsa
                          WHERE dtsa.deal_id = deal.id
                          ORDER BY dtsa.order_index
                         LIMIT 1) AS leader_user_id
                   FROM deal_to_sponsor_associations
                     JOIN deals deal ON deal_to_sponsor_associations.deal_id = deal.id
                  WHERE deal_to_sponsor_associations.sponsor_id = user_profile.user_id) deals) AS deals
   FROM user_profiles user_profile;

CREATE OR REPLACE VIEW public.deal_dashboard_view
    AS
     SELECT user_profiles.user_id,
    ( SELECT json_agg(deals.*) AS json_agg
           FROM ( SELECT deals_1.id,
                    deals_1.handle,
                    deals_1.launch_date,
                    deals_1.title,
                    deals_1.is_active,
                    ( SELECT json_agg(other_sponsors.*) AS json_agg
                           FROM ( SELECT sponsor.user_id,
                                    sponsor.handle,
                                    sponsor.profile_pic_url,
                                    sponsor.subtitle,
                                    sponsor.first_name,
                                    sponsor.last_name
                                   FROM deal_to_sponsor_associations dtsa
                                     JOIN user_profiles sponsor ON dtsa.sponsor_id = sponsor.user_id
                                  WHERE sponsor.user_id <> user_profiles.user_id AND dtsa.deal_id = deals_1.id) other_sponsors) AS other_sponsors
                   FROM deal_to_sponsor_associations
                     JOIN deals deals_1 ON deal_to_sponsor_associations.deal_id = deals_1.id
                  WHERE deal_to_sponsor_associations.sponsor_id = user_profiles.user_id) deals) AS deals
   FROM user_profiles;

drop view public.deal_page_view;

CREATE OR REPLACE VIEW public.deal_page_view
    AS
     SELECT deal.id,
    deal.title,
    deal.highlight_1_name,
    deal.highlight_1_value,
    deal.highlight_2_name,
    deal.highlight_2_value,
    deal.highlight_3_name,
    deal.highlight_3_value,
    deal.highlight_4_name,
    deal.highlight_4_value,
    deal.handle,
    deal.about,
    ( SELECT json_agg(cur_deal_images.*) AS json_agg
           FROM ( SELECT deal_image.id,
                    deal_image.created_at,
                    deal_image.updated_at,
                    deal_image.deal_id,
                    deal_image.image_url,
                    deal_image.order_index
                   FROM deal_images deal_image
                  WHERE deal_image.deal_id = deal.id) cur_deal_images) AS deal_images,
    ( SELECT count(*) AS count
           FROM deal_views
          WHERE deal_views.deal_id = deal.id) AS deal_views,
    deal.interest_count,
    ( SELECT json_agg(cur_deal_interests.*) AS json_agg
           FROM ( SELECT user_profile.user_id,
                    user_profile.first_name,
                    user_profile.last_name,
                    user_profile.profile_pic_url,
                    user_profile.handle,
                    user_profile.subtitle
                   FROM deal_interest
                     JOIN user_profiles user_profile ON user_profile.user_id = deal_interest.user_id
                  WHERE deal_interest.deal_id = deal.id) cur_deal_interests) AS connections_deal_interest,
    ( SELECT json_agg(all_comments.*) AS json_agg
           FROM ( SELECT comment.id,
                    comment.created_at,
                    comment.updated_at,
                    comment.user_id,
                    commenting_user.handle,
                    commenting_user.first_name,
                    commenting_user.last_name,
                    commenting_user.profile_pic_url,
                    comment.comment,
                    comment.replying_to_comment_id,
                    comment.type,
                    comment.likes_count,
                    comment.is_private,
                    ( SELECT json_agg(comment_likes.*) AS json_agg
                           FROM ( SELECT comment_like.user_id,
                                    liking_user.first_name,
                                    liking_user.last_name,
                                    liking_user.profile_pic_url,
                                    liking_user.handle,
                                    liking_user.subtitle
                                   FROM deal_comment_likes comment_like
                                     JOIN user_profiles liking_user ON comment_like.user_id = liking_user.user_id
                                  WHERE comment_like.deal_comment_id = comment.id) comment_likes) AS likes
                   FROM deal_comments comment
                     JOIN user_profiles commenting_user ON commenting_user.user_id = comment.user_id
                  WHERE comment.deal_id = deal.id) all_comments) AS deal_comments,
    ( SELECT json_agg(sponsors.*) AS json_agg
           FROM ( SELECT sponsor.first_name,
                    sponsor.last_name,
                    sponsor.handle,
                    sponsor.subtitle,
                    sponsor.profile_pic_url,
                    sponsor.current_org_position,
                    sponsor_org.name AS current_org_name,
                    sponsor_deals_view.deals,
                    mutual_connections_view.mutual_connections,
                    sponsor.work_family_connections_count,
                    deal_to_sponsor_associations.order_index
                   FROM deal_to_sponsor_associations
                     JOIN sponsor_deals_view ON sponsor_deals_view.user_id = deal_to_sponsor_associations.sponsor_id
                     JOIN mutual_connections_view ON mutual_connections_view.user_id = deal_to_sponsor_associations.sponsor_id
                     JOIN user_profiles sponsor ON deal_to_sponsor_associations.sponsor_id = sponsor.user_id
                     LEFT JOIN organizations sponsor_org ON sponsor_org.id = sponsor.current_org_id
                  WHERE deal_to_sponsor_associations.deal_id = deal.id
                  ORDER BY deal_to_sponsor_associations.order_index) sponsors) AS deal_sponsors
   FROM deals deal;


DROP TABLE IF EXISTS public.sponsor_team_to_user_associations CASCADE;

DROP TABLE IF EXISTS public.sponsor_teams CASCADE;