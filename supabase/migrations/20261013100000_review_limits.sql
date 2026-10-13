-- Review free text is bounded like the other customer-written fields

create function public.review_comment_max_length() returns int
language sql immutable as $$ select 300 $$;

alter table public.reviews
  add constraint reviews_comment_length check (char_length(comment) <= review_comment_max_length()),
  add constraint reviews_tags_size check (cardinality(tags) <= 5 and char_length(array_to_string(tags, ',')) <= 100);
