-- Run only if your DB was created from the old database/schema.sql.
-- The my_project_db.sql dump you shared already has all of this.
ALTER TABLE users ADD COLUMN IF NOT EXISTS role ENUM('admin','staff','student') NOT NULL DEFAULT 'student';
