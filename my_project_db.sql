-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Oct 10, 2026 at 02:14 PM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `my_project_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `attendance`
--

CREATE TABLE `attendance` (
  `id` int(10) UNSIGNED NOT NULL,
  `batch_subject_id` int(10) UNSIGNED NOT NULL,
  `student_id` int(10) UNSIGNED NOT NULL,
  `attendance_date` date NOT NULL,
  `status` enum('present','absent','late') NOT NULL DEFAULT 'present',
  `marked_by` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `attendance`
--

INSERT INTO `attendance` (`id`, `batch_subject_id`, `student_id`, `attendance_date`, `status`, `marked_by`, `created_at`, `updated_at`) VALUES
(1, 2, 7, '2026-10-10', 'present', 6, '2026-10-10 06:35:13', '2026-10-10 06:35:13'),
(2, 2, 2, '2026-10-10', 'present', 6, '2026-10-10 06:35:13', '2026-10-10 06:35:13');

-- --------------------------------------------------------

--
-- Table structure for table `batches`
--

CREATE TABLE `batches` (
  `id` int(10) UNSIGNED NOT NULL,
  `batch_name` varchar(150) NOT NULL,
  `course_id` int(10) UNSIGNED NOT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `capacity` int(10) UNSIGNED NOT NULL DEFAULT 30,
  `status` enum('Active','Inactive','Completed') NOT NULL DEFAULT 'Active',
  `created_by` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `batches`
--

INSERT INTO `batches` (`id`, `batch_name`, `course_id`, `start_date`, `end_date`, `capacity`, `status`, `created_by`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1, 'JAVA', 1, NULL, NULL, 30, 'Active', 1, '2026-10-07 07:08:32', '2026-10-07 07:08:32', 0),
(2, 'C++  Batch', 2, '2026-10-07', '2026-12-07', 5, 'Active', 1, '2026-10-07 10:57:48', '2026-10-07 10:57:48', 0);

-- --------------------------------------------------------

--
-- Table structure for table `batch_subjects`
--

CREATE TABLE `batch_subjects` (
  `id` int(10) UNSIGNED NOT NULL,
  `batch_id` int(10) UNSIGNED NOT NULL,
  `subject_name` varchar(150) NOT NULL,
  `staff_id` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `batch_subjects`
--

INSERT INTO `batch_subjects` (`id`, `batch_id`, `subject_name`, `staff_id`, `created_at`) VALUES
(1, 1, 'Java', 6, '2026-10-07 10:14:07'),
(2, 2, 'C++', 6, '2026-10-07 10:58:13');

-- --------------------------------------------------------

--
-- Table structure for table `courses`
--

CREATE TABLE `courses` (
  `id` int(10) UNSIGNED NOT NULL,
  `course_name` varchar(200) NOT NULL,
  `description` text DEFAULT NULL,
  `price` decimal(10,2) NOT NULL DEFAULT 0.00,
  `duration` varchar(100) DEFAULT NULL,
  `image_url` varchar(500) DEFAULT NULL,
  `status` enum('draft','published','inactive') NOT NULL DEFAULT 'draft',
  `created_by` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_deleted` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `courses`
--

INSERT INTO `courses` (`id`, `course_name`, `description`, `price`, `duration`, `image_url`, `status`, `created_by`, `created_at`, `updated_at`, `is_deleted`) VALUES
(1, 'Java full stack', NULL, 100000.00, '6', NULL, 'published', 1, '2026-10-07 07:08:01', '2026-10-07 07:08:01', 0),
(2, 'C++', NULL, 20000.00, '3', NULL, 'published', 1, '2026-10-07 10:57:03', '2026-10-07 10:57:09', 0);

-- --------------------------------------------------------

--
-- Table structure for table `exams`
--

CREATE TABLE `exams` (
  `id` int(10) UNSIGNED NOT NULL,
  `title` varchar(255) NOT NULL,
  `subject` varchar(255) DEFAULT NULL,
  `type` enum('quiz','paper') NOT NULL,
  `instructions` text DEFAULT NULL,
  `duration_minutes` int(11) DEFAULT NULL,
  `total_marks` decimal(8,2) NOT NULL DEFAULT 0.00,
  `pass_marks` decimal(8,2) DEFAULT NULL,
  `start_at` datetime DEFAULT NULL,
  `end_at` datetime DEFAULT NULL,
  `shuffle_questions` tinyint(1) NOT NULL DEFAULT 0,
  `question_paper` varchar(255) DEFAULT NULL,
  `status` enum('draft','published') NOT NULL DEFAULT 'published',
  `created_by` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `exams`
--

INSERT INTO `exams` (`id`, `title`, `subject`, `type`, `instructions`, `duration_minutes`, `total_marks`, `pass_marks`, `start_at`, `end_at`, `shuffle_questions`, `question_paper`, `status`, `created_by`, `created_at`, `updated_at`) VALUES
(1, 'C++ MCQ', 'C++', 'quiz', NULL, 30, 4.00, 2.00, '2026-10-10 15:08:00', '2026-10-11 15:08:00', 1, NULL, 'published', 1, '2026-10-10 09:43:03', NULL),
(2, 'C++ MCQ', 'C++', 'paper', NULL, NULL, 100.00, 40.00, '2026-10-10 15:30:00', '2026-10-11 15:30:00', 0, 'q_2d8b5d61ed1d9816673cab6de7667dfd.pdf', 'published', 6, '2026-10-10 10:01:19', '2026-10-10 15:31:19'),
(3, 'PREM', 'DEMO', 'paper', 'DEMO', NULL, 100.00, NULL, '2026-10-09 16:52:00', NULL, 0, 'q_7d31a7dcc61ce4690e6094689e09f564.pdf', 'published', 1, '2026-10-10 11:24:18', '2026-10-10 16:54:18');

-- --------------------------------------------------------

--
-- Table structure for table `exam_attempts`
--

CREATE TABLE `exam_attempts` (
  `id` int(10) UNSIGNED NOT NULL,
  `exam_id` int(10) UNSIGNED NOT NULL,
  `student_id` int(10) UNSIGNED NOT NULL,
  `status` enum('started','submitted','graded','published') NOT NULL DEFAULT 'started',
  `started_at` datetime DEFAULT NULL,
  `submitted_at` datetime DEFAULT NULL,
  `answers` longtext DEFAULT NULL,
  `marks` decimal(8,2) DEFAULT NULL,
  `correct_count` int(11) DEFAULT NULL,
  `wrong_count` int(11) DEFAULT NULL,
  `skipped_count` int(11) DEFAULT NULL,
  `remarks` varchar(1000) DEFAULT NULL,
  `graded_by` int(10) UNSIGNED DEFAULT NULL,
  `graded_at` datetime DEFAULT NULL,
  `published_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `exam_attempts`
--

INSERT INTO `exam_attempts` (`id`, `exam_id`, `student_id`, `status`, `started_at`, `submitted_at`, `answers`, `marks`, `correct_count`, `wrong_count`, `skipped_count`, `remarks`, `graded_by`, `graded_at`, `published_at`) VALUES
(1, 1, 2, 'published', '2026-10-10 15:13:51', '2026-10-10 15:14:19', '[{\"question_id\":1,\"selected_option\":1},{\"question_id\":2,\"selected_option\":1},{\"question_id\":3,\"selected_option\":1},{\"question_id\":4,\"selected_option\":3}]', 2.00, 2, 2, 0, NULL, NULL, NULL, '2026-10-10 15:14:19'),
(2, 2, 3, 'published', '2026-10-10 15:40:33', '2026-10-10 15:40:33', NULL, 50.00, NULL, NULL, NULL, NULL, 6, '2026-10-10 15:44:25', '2026-10-10 15:44:25'),
(3, 3, 9, 'submitted', '2026-10-10 17:03:01', '2026-10-10 17:03:01', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `exam_attempt_files`
--

CREATE TABLE `exam_attempt_files` (
  `id` int(10) UNSIGNED NOT NULL,
  `attempt_id` int(10) UNSIGNED NOT NULL,
  `sort_order` int(11) NOT NULL DEFAULT 0,
  `file_path` varchar(255) NOT NULL,
  `original_name` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `exam_attempt_files`
--

INSERT INTO `exam_attempt_files` (`id`, `attempt_id`, `sort_order`, `file_path`, `original_name`, `created_at`) VALUES
(1, 2, 0, 'a_1ad52bfae23761e3329f8e0c09434005.pdf', 'answer-sheets.pdf', '2026-10-10 10:10:33'),
(2, 3, 0, 'a_8f3bd3f1240fdfc6f1f3daeb8b496f48.jpg', 'scaled_6e051e46-ac33-43ca-a3fa-5262a4e6106c4922855024704343596.jpg', '2026-10-10 11:33:01');

-- --------------------------------------------------------

--
-- Table structure for table `exam_batches`
--

CREATE TABLE `exam_batches` (
  `exam_id` int(10) UNSIGNED NOT NULL,
  `batch_id` int(10) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `exam_batches`
--

INSERT INTO `exam_batches` (`exam_id`, `batch_id`) VALUES
(1, 2),
(2, 1),
(3, 1);

-- --------------------------------------------------------

--
-- Table structure for table `exam_questions`
--

CREATE TABLE `exam_questions` (
  `id` int(10) UNSIGNED NOT NULL,
  `exam_id` int(10) UNSIGNED NOT NULL,
  `sort_order` int(11) NOT NULL DEFAULT 0,
  `question_text` text NOT NULL,
  `options` longtext NOT NULL,
  `correct_option` int(11) NOT NULL,
  `marks` decimal(6,2) NOT NULL DEFAULT 1.00,
  `explanation` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `exam_questions`
--

INSERT INTO `exam_questions` (`id`, `exam_id`, `sort_order`, `question_text`, `options`, `correct_option`, `marks`, `explanation`) VALUES
(1, 1, 0, 'Who invented C++?', '[\"Dennis Ritchie\",\"Ken Thompson\",\"Brian Kernighan\",\"Bjarne Stroustrup\"]', 3, 1.00, 'Answer: d Explanation: Bjarne Stroustrup is the original creator of C++ in 1979 at AT&T Bell Labs.'),
(2, 1, 1, 'What is C++?', '[\"C++ is an object oriented programming language\",\"C++ is a procedural programming language\",\"C++ supports both procedural and object oriented programming language\",\"C++ is a functional programming language\"]', 2, 1.00, 'Answer: c Explanation: C++ supports both procedural(step by step instruction) and object oriented programming (using the concept of classes and objects).'),
(3, 1, 2, 'Which of the following is the correct syntax of including a user defined header files in C++?', '[\"#include [userdefined]\",\"#include “userdefined”\",\"#include <userdefined.h>\",\"#include <userdefined>\"]', 1, 1.00, 'Answer: b Explanation: C++ uses double quotes to include a user-defined header file. The correct syntax of including user-defined is #include “userdefinedname”.'),
(4, 1, 3, 'Which of the following is used for comments in C++?', '[\"\\/* comment *\\/\",\"\\/\\/ comment *\\/\",\"\\/\\/ comment\",\"both \\/\\/ comment or \\/* comment *\\/\"]', 3, 1.00, 'Answer: d Explanation: Both the ways are used for commenting in C++ programming. // is used for single line comments and /* … */ is used for multiple line comments.');

-- --------------------------------------------------------

--
-- Table structure for table `leave_requests`
--

CREATE TABLE `leave_requests` (
  `id` int(10) UNSIGNED NOT NULL,
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
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `leave_requests`
--

INSERT INTO `leave_requests` (`id`, `user_id`, `user_role`, `batch_id`, `from_date`, `to_date`, `reason`, `status`, `reviewed_by`, `review_note`, `reviewed_at`, `created_at`) VALUES
(1, 7, 'student', 2, '2026-10-08', '2026-10-08', 'Testing', 'approved', 6, 'ok', '2026-10-07 11:25:56', '2026-10-07 11:24:52');

-- --------------------------------------------------------

--
-- Table structure for table `payments`
--

CREATE TABLE `payments` (
  `id` int(10) UNSIGNED NOT NULL,
  `purchase_id` int(10) UNSIGNED NOT NULL,
  `razorpay_order_id` varchar(255) DEFAULT NULL,
  `razorpay_payment_id` varchar(255) DEFAULT NULL,
  `razorpay_signature` varchar(500) DEFAULT NULL,
  `amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `currency` varchar(10) NOT NULL DEFAULT 'INR',
  `status` enum('created','paid','failed','refunded') NOT NULL DEFAULT 'created',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `payments`
--

INSERT INTO `payments` (`id`, `purchase_id`, `razorpay_order_id`, `razorpay_payment_id`, `razorpay_signature`, `amount`, `currency`, `status`, `created_at`, `updated_at`) VALUES
(1, 1, 'order_Tky29V6hVHB4ic', 'pay_Tky2RW28z1k1VT', 'a09f7b20b6f885e804b1d14fe455f8965f25a99279d059ef0eac248f8cfc3ea5', 100000.00, 'INR', 'paid', '2026-10-07 09:22:53', '2026-10-07 09:23:30'),
(2, 2, 'order_TkysQgkyPL480q', NULL, NULL, 100000.00, 'INR', 'created', '2026-10-07 10:12:23', '2026-10-07 10:12:23'),
(3, 2, 'order_TkzDeDWk2nMPsc', NULL, NULL, 100000.00, 'INR', 'created', '2026-10-07 10:32:28', '2026-10-07 10:32:28'),
(4, 2, 'order_TkzRo1Mi7IQn4p', 'pay_TkzRxXw5uL1zPO', 'd441efb9b4753546c0eb0ad102c243739783a7096215e3dd5dee02358a8210b7', 100000.00, 'INR', 'paid', '2026-10-07 10:45:52', '2026-10-07 10:46:17'),
(5, 3, 'order_TkzgIHY76MQoWj', 'pay_TkzgMnUcoiwUAt', 'aa4ae9da616043765ffc800cdbac7cc6966b5ae52298639f888e1cba88e7df98', 20000.00, 'INR', 'paid', '2026-10-07 10:59:35', '2026-10-07 10:59:56'),
(6, 4, 'order_Tl06CZnrxTSGFY', 'pay_Tl06LtaXvUuMJy', '774be9ce60941a856c39b83729c5541d66463be313f37c5da3600deb84f3eefd', 20000.00, 'INR', 'paid', '2026-10-07 11:24:07', '2026-10-07 11:24:31'),
(7, 5, 'order_TmBbZzGi5uUFyJ', 'pay_TmBcCefGxcRsmh', '0ed25b31b81320deab7612f77647d0c981a91d5b16a7b811d26f361c18dc7c3d', 100000.00, 'INR', 'paid', '2026-10-10 11:18:27', '2026-10-10 11:19:09');

-- --------------------------------------------------------

--
-- Table structure for table `purchases`
--

CREATE TABLE `purchases` (
  `id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `course_id` int(10) UNSIGNED NOT NULL,
  `batch_id` int(10) UNSIGNED DEFAULT NULL,
  `amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `status` enum('pending','paid','failed','cancelled') NOT NULL DEFAULT 'pending',
  `payment_id` varchar(255) DEFAULT NULL,
  `purchased_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `purchases`
--

INSERT INTO `purchases` (`id`, `user_id`, `course_id`, `batch_id`, `amount`, `status`, `payment_id`, `purchased_at`, `created_at`, `updated_at`) VALUES
(1, 3, 1, 1, 100000.00, 'paid', 'pay_Tky2RW28z1k1VT', '2026-10-07 09:23:30', '2026-10-07 07:09:39', '2026-10-07 09:23:30'),
(2, 2, 1, 1, 100000.00, 'paid', 'pay_TkzRxXw5uL1zPO', '2026-10-07 10:46:17', '2026-10-07 10:12:23', '2026-10-07 10:46:17'),
(3, 2, 2, 2, 20000.00, 'paid', 'pay_TkzgMnUcoiwUAt', '2026-10-07 10:59:56', '2026-10-07 10:59:35', '2026-10-07 10:59:56'),
(4, 7, 2, 2, 20000.00, 'paid', 'pay_Tl06LtaXvUuMJy', '2026-10-07 11:24:31', '2026-10-07 11:24:07', '2026-10-07 11:24:31'),
(5, 9, 1, 1, 100000.00, 'paid', 'pay_TmBcCefGxcRsmh', '2026-10-10 11:19:09', '2026-10-10 11:18:27', '2026-10-10 11:19:09');

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(10) UNSIGNED NOT NULL,
  `name` varchar(100) NOT NULL,
  `email` varchar(150) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('admin','staff','student') NOT NULL DEFAULT 'student',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `auth_token` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `name`, `email`, `password`, `role`, `created_at`, `updated_at`, `auth_token`) VALUES
(1, 'admin', 'admin@gmail.com', '$2y$10$yGGHhgUz.SrUxWdWNyHyl.oogi8aYOkfaFgh3pBBWTqxmHkSNo2Fi', 'admin', '2026-10-06 07:36:24', '2026-10-10 11:33:21', NULL),
(2, 'prem', 'premanath2003@gmail.com', '$2y$10$rG4wW2Chw6vzNvh0vyXIAu4lV/MfuJ6BKHiNQuiA6k.HCVwEfuaAm', 'student', '2026-10-06 07:37:44', '2026-10-10 09:44:40', NULL),
(3, 'arun vengatesh', 'arunvengatesh66@gmail.com', '$2y$10$2vusEjK0zMbP9naTQEe8eOEGseKvmg9ni8HT.UasbanzFn65xcxFy', 'student', '2026-10-06 07:39:23', '2026-10-10 11:14:11', NULL),
(6, 'Siva', 'siva@gmail.com', '$2y$10$BcxyG/cQPTH/BjOjr1.JIO2TQAHcz/.TOnULdbk1Ml3VvnFCSKvXm', 'staff', '2026-10-07 07:24:14', '2026-10-10 11:33:28', '46ed72fbf5b74e23057395f0840b42d05681866a01074a9070272dc7341f3c8d'),
(7, 'ajay', 'er.sarabeshb@gmail.com', '$2y$10$9wFJuxd2eLemNWCTXsTHAuY8guQFOHdKWdp1qCXuVYqhgNcEzRdHm', 'student', '2026-10-07 10:56:28', '2026-10-07 11:24:55', NULL),
(8, 'Vengatesh', 'arunvengatesh06@gmail.com', '$2y$10$oXRsB0NrJEe/F/ptPM1QOukA/InyX9/8LL6bnxawJJi5FTcVCBAd2', 'student', '2026-10-10 08:27:18', '2026-10-10 10:08:01', NULL),
(9, 'Premanath S', 'premanathfreelancing@gmail.com', '$2y$10$.MVQLh7j.1bOq.vHspGfXu6Mdzky6z7UL0t6YXDXwBmjr8L5t4MG6', 'student', '2026-10-10 11:15:56', '2026-10-10 11:31:05', 'd99be167b88bd6c2b3c9458b40868ebd2e166d8aaa78c04f77002c7a3ce7dbd1');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `attendance`
--
ALTER TABLE `attendance`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_att` (`batch_subject_id`,`student_id`,`attendance_date`),
  ADD KEY `idx_att_student` (`student_id`);

--
-- Indexes for table `batches`
--
ALTER TABLE `batches`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_batches_course` (`course_id`),
  ADD KEY `fk_batches_created_by` (`created_by`);

--
-- Indexes for table `batch_subjects`
--
ALTER TABLE `batch_subjects`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_batch_subject` (`batch_id`,`subject_name`),
  ADD KEY `idx_bs_staff` (`staff_id`);

--
-- Indexes for table `courses`
--
ALTER TABLE `courses`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_courses_created_by` (`created_by`);

--
-- Indexes for table `exams`
--
ALTER TABLE `exams`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_exam_creator` (`created_by`);

--
-- Indexes for table `exam_attempts`
--
ALTER TABLE `exam_attempts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_exam_student` (`exam_id`,`student_id`),
  ADD KEY `idx_ea_student` (`student_id`);

--
-- Indexes for table `exam_attempt_files`
--
ALTER TABLE `exam_attempt_files`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_eaf_attempt` (`attempt_id`);

--
-- Indexes for table `exam_batches`
--
ALTER TABLE `exam_batches`
  ADD PRIMARY KEY (`exam_id`,`batch_id`),
  ADD KEY `idx_eb_batch` (`batch_id`);

--
-- Indexes for table `exam_questions`
--
ALTER TABLE `exam_questions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_eq_exam` (`exam_id`);

--
-- Indexes for table `leave_requests`
--
ALTER TABLE `leave_requests`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_leave_user` (`user_id`),
  ADD KEY `idx_leave_batch` (`batch_id`);

--
-- Indexes for table `payments`
--
ALTER TABLE `payments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_payments_purchase` (`purchase_id`);

--
-- Indexes for table `purchases`
--
ALTER TABLE `purchases`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_purchases_user` (`user_id`),
  ADD KEY `fk_purchases_course` (`course_id`),
  ADD KEY `fk_purchases_batch` (`batch_id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `email` (`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `attendance`
--
ALTER TABLE `attendance`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `batches`
--
ALTER TABLE `batches`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `batch_subjects`
--
ALTER TABLE `batch_subjects`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `courses`
--
ALTER TABLE `courses`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `exams`
--
ALTER TABLE `exams`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `exam_attempts`
--
ALTER TABLE `exam_attempts`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `exam_attempt_files`
--
ALTER TABLE `exam_attempt_files`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `exam_questions`
--
ALTER TABLE `exam_questions`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `leave_requests`
--
ALTER TABLE `leave_requests`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `payments`
--
ALTER TABLE `payments`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `purchases`
--
ALTER TABLE `purchases`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `attendance`
--
ALTER TABLE `attendance`
  ADD CONSTRAINT `fk_att_bs` FOREIGN KEY (`batch_subject_id`) REFERENCES `batch_subjects` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_att_student` FOREIGN KEY (`student_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `batches`
--
ALTER TABLE `batches`
  ADD CONSTRAINT `fk_batches_course` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_batches_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `batch_subjects`
--
ALTER TABLE `batch_subjects`
  ADD CONSTRAINT `fk_bs_batch` FOREIGN KEY (`batch_id`) REFERENCES `batches` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_bs_staff` FOREIGN KEY (`staff_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `courses`
--
ALTER TABLE `courses`
  ADD CONSTRAINT `fk_courses_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `exams`
--
ALTER TABLE `exams`
  ADD CONSTRAINT `fk_exam_creator` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `exam_attempts`
--
ALTER TABLE `exam_attempts`
  ADD CONSTRAINT `fk_ea_exam` FOREIGN KEY (`exam_id`) REFERENCES `exams` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_ea_student` FOREIGN KEY (`student_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `exam_attempt_files`
--
ALTER TABLE `exam_attempt_files`
  ADD CONSTRAINT `fk_eaf_attempt` FOREIGN KEY (`attempt_id`) REFERENCES `exam_attempts` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `exam_batches`
--
ALTER TABLE `exam_batches`
  ADD CONSTRAINT `fk_eb_batch` FOREIGN KEY (`batch_id`) REFERENCES `batches` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_eb_exam` FOREIGN KEY (`exam_id`) REFERENCES `exams` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `exam_questions`
--
ALTER TABLE `exam_questions`
  ADD CONSTRAINT `fk_eq_exam` FOREIGN KEY (`exam_id`) REFERENCES `exams` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `leave_requests`
--
ALTER TABLE `leave_requests`
  ADD CONSTRAINT `fk_leave_batch` FOREIGN KEY (`batch_id`) REFERENCES `batches` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_leave_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `payments`
--
ALTER TABLE `payments`
  ADD CONSTRAINT `fk_payments_purchase` FOREIGN KEY (`purchase_id`) REFERENCES `purchases` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `purchases`
--
ALTER TABLE `purchases`
  ADD CONSTRAINT `fk_purchases_batch` FOREIGN KEY (`batch_id`) REFERENCES `batches` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_purchases_course` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_purchases_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON UPDATE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
