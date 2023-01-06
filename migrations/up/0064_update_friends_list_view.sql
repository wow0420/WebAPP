DROP view deal_page_view;
DROP view profile_page_view;
DROP view mutual_connections_view;
DROP view autocomplete_users_view;
DROP view friends_list_view;

CREATE view friends_list_view AS
SELECT
  person.from_user_id,
  person.to_user_id,
  friend.profile_pic_url,
  friend.first_name,
  friend.last_name,
  friend.handle,
  friend.subtitle
FROM
  (
    SELECT
      connections.from_user_id,
      connections.to_user_id
    FROM
      connections
    UNION
    SELECT
      connections.to_user_id,
      connections.from_user_id
    FROM
      connections
  ) person
  JOIN user_profiles friend ON person.to_user_id = friend.user_id;

CREATE view autocomplete_users_view AS
SELECT
  friends_list_view.from_user_id,
  friends_list_view.to_user_id,
  friends_list_view.profile_pic_url,
  friends_list_view.first_name,
  friends_list_view.last_name,
  friends_list_view.handle,
  friends_list_view.subtitle
FROM
  friends_list_view
UNION
SELECT
  user_profiles.user_id AS from_user_id,
  user_profiles.user_id AS to_user_id,
  user_profiles.profile_pic_url,
  user_profiles.first_name,
  user_profiles.last_name,
  user_profiles.handle,
  user_profiles.subtitle
FROM
  user_profiles;

CREATE view mutual_connections_view AS
SELECT
  user_profile.user_id,
  (
    SELECT
      json_agg(mutual_connections.*) AS json_agg
    FROM
      (
        SELECT
          your_friend.to_user_id AS user_id,
          your_friend.handle,
          your_friend.profile_pic_url,
          your_friend.first_name,
          your_friend.last_name
        FROM
          friends_list_view their_friend
          JOIN friends_list_view your_friend ON their_friend.to_user_id = your_friend.to_user_id
        WHERE
          their_friend.from_user_id = user_profile.user_id
          AND your_friend.from_user_id = auth.uid()
      ) mutual_connections
  ) AS mutual_connections
FROM
  user_profiles user_profile;

CREATE view profile_page_view AS
SELECT
  user_profile.user_id,
  user_profile.handle,
  user_profile.profile_pic_url,
  user_profile.cover_photo_url,
  user_profile.first_name,
  user_profile.last_name,
  user_profile.is_verified,
  user_profile.subtitle,
  user_profile.is_sponsor,
  user_profile.is_investor,
  user_profile.current_org_id,
  user_profile.current_org_position,
  org.profile_pic_url AS current_org_profile_pic_url,
  org.name AS current_org_name,
  user_profile.created_at,
  user_profile.nominated_by_user_id,
  nominated_by_user_profile.profile_pic_url AS nominated_by_user_profile_pic_url,
  nominated_by_user_profile.first_name AS nominated_by_user_first_name,
  nominated_by_user_profile.last_name AS nominated_by_user_last_name,
  nominated_by_user_profile.handle AS nominated_by_user_handle,
  user_profile.about,
  user_profile.connections_count,
  mutual_connections_view.mutual_connections,
  user_profile.linkedin_url,
  user_profile.facebook_url,
  user_profile.instagram_url,
  user_profile.twitter_url,
  sponsor_deals_view.deals,
  (
    SELECT
      json_agg(endorsements.*) AS json_agg
    FROM
      (
        SELECT
          endorsing_user.handle AS endorsing_user_handle,
          endorsing_user.user_id AS endorsing_user_user_id,
          endorsing_user.profile_pic_url AS endorsing_user_profile_pic_url,
          endorsing_user.first_name AS endorsing_user_first_name,
          endorsing_user.last_name AS endorsing_user_last_name,
          endorsement.created_at,
          endorsement.subtitle,
          endorsement.text,
          deal.title AS subtitle_deal_title
        FROM
          endorsements endorsement
          JOIN user_profiles endorsing_user ON endorsement.author_user_id = endorsing_user.user_id
          LEFT JOIN deals deal ON endorsement.deal_id = deal.id
        WHERE
          endorsement.to_user_id = user_profile.user_id
      ) endorsements
  ) AS endorsements
FROM
  user_profiles user_profile
  LEFT JOIN organizations org ON user_profile.current_org_id = org.id
  LEFT JOIN user_profiles nominated_by_user_profile ON user_profile.nominated_by_user_id = nominated_by_user_profile.user_id
  LEFT JOIN sponsor_deals_view ON sponsor_deals_view.user_id = user_profile.user_id
  LEFT JOIN mutual_connections_view ON mutual_connections_view.user_id = user_profile.user_id;

CREATE view deal_page_view AS
SELECT
  deal.id,
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
  deal.is_active,
  deal.launch_date,
  (
    SELECT
      json_agg(cur_deal_images.*) AS json_agg
    FROM
      (
        SELECT
          deal_image.id,
          deal_image.created_at,
          deal_image.updated_at,
          deal_image.deal_id,
          deal_image.image_url,
          deal_image.order_index
        FROM
          deal_images deal_image
        WHERE
          deal_image.deal_id = deal.id
      ) cur_deal_images
  ) AS deal_images,
  (
    SELECT
      COUNT(*) AS COUNT
    FROM
      deal_views
    WHERE
      deal_views.deal_id = deal.id
  ) AS deal_views,
  deal.interest_count,
  (
    SELECT
      json_agg(cur_deal_interests.*) AS json_agg
    FROM
      (
        SELECT
          user_profile.user_id,
          user_profile.first_name,
          user_profile.last_name,
          user_profile.profile_pic_url,
          user_profile.handle,
          user_profile.subtitle
        FROM
          deal_interest
          JOIN user_profiles user_profile ON user_profile.user_id = deal_interest.user_id
        WHERE
          deal_interest.deal_id = deal.id
      ) cur_deal_interests
  ) AS connections_deal_interest,
  (
    SELECT
      json_agg(all_comments.*) AS json_agg
    FROM
      (
        SELECT
          comment.id,
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
          (
            SELECT
              json_agg(comment_likes.*) AS json_agg
            FROM
              (
                SELECT
                  comment_like.user_id,
                  liking_user.first_name,
                  liking_user.last_name,
                  liking_user.profile_pic_url,
                  liking_user.handle,
                  liking_user.subtitle
                FROM
                  deal_comment_likes comment_like
                  JOIN user_profiles liking_user ON comment_like.user_id = liking_user.user_id
                WHERE
                  comment_like.deal_comment_id = comment.id
              ) comment_likes
          ) AS likes
        FROM
          deal_comments comment
          JOIN user_profiles commenting_user ON commenting_user.user_id = comment.user_id
        WHERE
          comment.deal_id = deal.id
      ) all_comments
  ) AS deal_comments,
  (
    SELECT
      json_agg(deal_faqs.*) AS deal_faqs
    FROM
      (
        SELECT
          faq.id,
          faq.created_at,
          faq.updated_at,
          faq.question,
          faq.answer
        FROM
          deal_faqs faq
        WHERE
          faq.deal_id = deal.id
      ) deal_faqs
  ) AS deal_faqs,
  (
    SELECT
      json_agg(sponsors.*) AS json_agg
    FROM
      (
        SELECT
          sponsor.user_id,
          sponsor.first_name,
          sponsor.last_name,
          sponsor.handle,
          sponsor.subtitle,
          sponsor.profile_pic_url,
          sponsor.current_org_position,
          sponsor_org.name AS current_org_name,
          sponsor_deals_view.deals,
          mutual_connections_view.mutual_connections,
          deal_to_sponsor_associations.order_index,
          deal_to_sponsor_associations.id AS deal_to_sponsor_association_id,
          (
            SELECT
              json_agg(org_members.*) AS org_members
            FROM
              (
                SELECT
                  org_member.user_id,
                  org_member.first_name,
                  org_member.last_name,
                  org_member.profile_pic_url,
                  org_member.handle,
                  org_member.current_org_position
                FROM
                  user_profiles org_member
                WHERE
                  org_member.current_org_id = sponsor.current_org_id
                  AND org_member.user_id <> sponsor.user_id
              ) org_members
          ) AS org_members
        FROM
          deal_to_sponsor_associations
          JOIN sponsor_deals_view ON sponsor_deals_view.user_id = deal_to_sponsor_associations.sponsor_id
          JOIN mutual_connections_view ON mutual_connections_view.user_id = deal_to_sponsor_associations.sponsor_id
          JOIN user_profiles sponsor ON deal_to_sponsor_associations.sponsor_id = sponsor.user_id
          LEFT JOIN organizations sponsor_org ON sponsor_org.id = sponsor.current_org_id
        WHERE
          deal_to_sponsor_associations.deal_id = deal.id
        ORDER BY
          deal_to_sponsor_associations.order_index
      ) sponsors
  ) AS deal_sponsors
FROM
  deals deal;


