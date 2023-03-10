-- This script was generated by the Schema Diff utility in pgAdmin 4
-- For the circular dependencies, the order in which Schema Diff writes the objects is not very sophisticated
-- and may require manual changes to the script to ensure changes are applied in the correct order.
-- Please report an issue for any failure with the reproduction steps.

CREATE TRIGGER deal_interest_set_updated_at
    AFTER INSERT OR UPDATE 
    ON public.deal_interest
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_set_updated_at();

CREATE TRIGGER deal_comment_likes_set_updated_at
    AFTER INSERT OR UPDATE 
    ON public.deal_comment_likes
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_set_updated_at();

CREATE TRIGGER deal_images_set_updated_at
    AFTER INSERT OR UPDATE 
    ON public.deal_images
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_set_updated_at();

CREATE TRIGGER deal_to_sponsor_associations_set_updated_at
    AFTER INSERT OR UPDATE 
    ON public.deal_to_sponsor_associations
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_set_updated_at();

CREATE TRIGGER deal_comments_set_updated_at
    AFTER INSERT OR UPDATE 
    ON public.deal_comments
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_set_updated_at();

