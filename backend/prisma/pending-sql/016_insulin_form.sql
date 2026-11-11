-- Round 15 (owner, 2026-11-11): an "Insulin" medicine form, so the insulin
-- log can tell insulin from other injections. Reference data only.
INSERT INTO "medicine_forms" ("name") VALUES ('Insulin')
ON CONFLICT ("name") DO NOTHING;
