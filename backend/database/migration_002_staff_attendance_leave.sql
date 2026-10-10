-- Run ONCE in phpMyAdmin on my_project_db (SQL tab). Safe to re-run: uses IF NOT EXISTS.

-- 1. Which staff teaches which subject in which batch (set by admin)
CREATE TABLE IF NOT EXISTS `batch_subjects` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `batch_id` int(10) UNSIGNED NOT NULL,
  `subject_name` varchar(150) NOT NULL,
  `staff_id` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_batch_subject` (`batch_id`,`subject_name`),
  KEY `idx_bs_staff` (`staff_id`),
  CONSTRAINT `fk_bs_batch` FOREIGN KEY (`batch_id`) REFERENCES `batches` (`id`) ON UPDATE CASCADE,
  CONSTRAINT `fk_bs_staff` FOREIGN KEY (`staff_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 2. Attendance: one row per student, per subject class, per date
CREATE TABLE IF NOT EXISTS `attendance` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `batch_subject_id` int(10) UNSIGNED NOT NULL,
  `student_id` int(10) UNSIGNED NOT NULL,
  `attendance_date` date NOT NULL,
  `status` enum('present','absent','late') NOT NULL DEFAULT 'present',
  `marked_by` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_att` (`batch_subject_id`,`student_id`,`attendance_date`),
  KEY `idx_att_student` (`student_id`),
  CONSTRAINT `fk_att_bs` FOREIGN KEY (`batch_subject_id`) REFERENCES `batch_subjects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_att_student` FOREIGN KEY (`student_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 3. Leave requests
--    student leave -> goes to the staff handling that batch AND to admin
--    staff leave   -> goes to admin (batch_id is NULL)
CREATE TABLE IF NOT EXISTS `leave_requests` (
  `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int(10) UNSIGNED NOT NULL,
  `user_role` enum('student','staff') NOT NULL,
  `batch_id` int(10) UNSIGNED DEFAULT NULL,
  `from_date` date NOT NULL,
  `to_date` date NOT NULL,
  `reason` varchar(1000) NOT NULL,
  `status` enum('pending','approved','rejected','cancelled') NOT NULL DEFAULT 'pending',
  `reviewed_by` int(10) UNSIGNED DEFAULT NULL,
  `review_note` varchar(500) DEFAULT NULL,
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_leave_user` (`user_id`),
  KEY `idx_leave_batch` (`batch_id`),
  CONSTRAINT `fk_leave_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_leave_batch` FOREIGN KEY (`batch_id`) REFERENCES `batches` (`id`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
