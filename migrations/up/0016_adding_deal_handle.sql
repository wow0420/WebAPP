-- This script was generated by the Schema Diff utility in pgAdmin 4
-- For the circular dependencies, the order in which Schema Diff writes the objects is not very sophisticated
-- and may require manual changes to the script to ensure changes are applied in the correct order.
-- Please report an issue for any failure with the reproduction steps.
ALTER TABLE IF EXISTS public.deals
    ADD COLUMN handle text COLLATE pg_catalog."default" NOT NULL;
ALTER TABLE IF EXISTS public.deals
    ADD CONSTRAINT deals_handle_key UNIQUE (handle);

-- Changing the columns in a view requires dropping and re-creating the view.
-- This may fail if other objects are dependent upon this view,
-- or may cause procedural functions to fail if they are not modified to
-- take account of the changes.
CREATE OR REPLACE VIEW public.sponsor_deals_view
    AS
     SELECT user_profile.user_id,
    ( SELECT json_agg(projects.*) AS json_agg
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
                    deal.interest_count
                   FROM deal_to_sponsor_associations dtsa
                     JOIN deals deal ON dtsa.deal_id = deal.id
                  WHERE dtsa.sponsor_id = user_profile.user_id) projects) AS deals
   FROM user_profiles user_profile;
GRANT ALL ON TABLE public.sponsor_deals_view TO postgres;

DROP VIEW public.deal_page_view;
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
    deal.interest_count,
    ( SELECT json_agg(cur_deal_interests.*) AS json_agg
           FROM ( SELECT user_profile.user_id,
                    user_profile.first_name,
                    user_profile.last_name,
                    user_profile.profile_pic_url,
                    user_profile.handle
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
                    ( SELECT json_agg(comment_likes.*) AS json_agg
                           FROM ( SELECT comment_like.user_id,
                                    liking_user.first_name,
                                    liking_user.last_name,
                                    liking_user.profile_pic_url,
                                    liking_user.handle
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
                    sponsor_deals_view.deals,
                    mutual_connections_view.mutual_connections
                   FROM deal_to_sponsor_associations
                     JOIN sponsor_deals_view ON sponsor_deals_view.user_id = deal_to_sponsor_associations.sponsor_id
                     JOIN mutual_connections_view ON mutual_connections_view.user_id = deal_to_sponsor_associations.sponsor_id
                     JOIN user_profiles sponsor ON deal_to_sponsor_associations.sponsor_id = sponsor.user_id
                  WHERE deal_to_sponsor_associations.deal_id = deal.id) sponsors) AS deal_sponsors
   FROM deals deal;

ALTER TABLE public.profile_page_view
    OWNER TO supabase_admin;

