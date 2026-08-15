-- One photo per required slot (frontal, trasera, etc.) so a re-upload replaces
-- it instead of piling up duplicates. 'otra' is excluded on purpose — REQ-PUB-001
-- recommends multiple extra photos beyond the 6 required slots.
create unique index listing_photos_unique_required_slot
  on public.listing_photos (listing_id, slot)
  where slot <> 'otra';
